//
//  KeychainRepository.swift
//  ClaudeMeter
//
//  Created by Edd on 2025-11-14.
//

import Foundation
import Security

/// Actor-isolated repository for secure Keychain operations.
///
/// Session keys are stored in the data-protection keychain so macOS does not
/// show the file-based login-keychain ACL prompt on every read.
actor KeychainRepository: KeychainRepositoryProtocol {
    private let secItem: any SecItemClient
    private let serviceName: String
    private let legacyServices: [String]
    private var cachedSessionKeys: [String: String] = [:]

    init(
        secItem: any SecItemClient = SystemSecItemClient(),
        serviceName: String = AppIdentity.keychainService,
        legacyServices: [String] = AppIdentity.legacyKeychainServices
    ) {
        self.secItem = secItem
        self.serviceName = serviceName
        self.legacyServices = legacyServices
    }

    func save(sessionKey: String, account: String) async throws {
        try persistModern(sessionKey: sessionKey, account: account)
        cachedSessionKeys[account] = sessionKey
        deleteSilently(account: account, service: serviceName, dataProtection: false)
    }

    func retrieve(account: String) async throws -> String {
        if let cached = cachedSessionKeys[account] {
            return cached
        }

        if let value = copyString(account: account, service: serviceName, dataProtection: true) {
            cachedSessionKeys[account] = value
            return value
        }

        if let value = copyString(account: account, service: serviceName, dataProtection: false) {
            try? persistModern(sessionKey: value, account: account)
            deleteSilently(account: account, service: serviceName, dataProtection: false)
            cachedSessionKeys[account] = value
            return value
        }

        for service in legacyServices {
            let value = copyString(account: account, service: service, dataProtection: false)
                ?? copyString(account: account, service: service, dataProtection: true)
            if let value {
                try? persistModern(sessionKey: value, account: account)
                cachedSessionKeys[account] = value
                return value
            }
        }

        throw KeychainError.notFound
    }

    func update(sessionKey: String, account: String) async throws {
        try persistModern(sessionKey: sessionKey, account: account)
        cachedSessionKeys[account] = sessionKey
        deleteSilently(account: account, service: serviceName, dataProtection: false)
    }

    func delete(account: String) async throws {
        cachedSessionKeys[account] = nil
        let dataProtectionStatus = secItem.delete(
            KeychainItemQuery.password(account: account, service: serviceName, dataProtection: true)
        )
        let fileBasedStatus = secItem.delete(
            KeychainItemQuery.password(account: account, service: serviceName, dataProtection: false)
        )

        let statuses = [dataProtectionStatus, fileBasedStatus]
        guard statuses.allSatisfy({ $0 == errSecSuccess || $0 == errSecItemNotFound }) else {
            throw KeychainError.deleteFailed(
                OSStatus: statuses.first { $0 != errSecSuccess && $0 != errSecItemNotFound } ?? errSecUnimplemented
            )
        }
    }

    func exists(account: String) async -> Bool {
        (try? await retrieve(account: account)) != nil
    }

    private func persistModern(sessionKey: String, account: String) throws {
        guard let data = sessionKey.data(using: .utf8) else {
            throw KeychainError.saveFailed(OSStatus: errSecParam)
        }

        let addStatus = secItem.add(KeychainItemQuery.add(account: account, service: serviceName, data: data))
        if addStatus == errSecDuplicateItem {
            let updateStatus = secItem.update(
                query: KeychainItemQuery.password(
                    account: account,
                    service: serviceName,
                    dataProtection: true
                ),
                attributes: [kSecValueData as String: data]
            )
            guard updateStatus == errSecSuccess else {
                throw KeychainError.updateFailed(OSStatus: updateStatus)
            }
        } else if addStatus != errSecSuccess {
            throw KeychainError.saveFailed(OSStatus: addStatus)
        }
    }

    private func copyString(account: String, service: String, dataProtection: Bool) -> String? {
        let query = KeychainItemQuery.lookup(
            account: account,
            service: service,
            returnData: true,
            dataProtection: dataProtection
        )
        let (status, data) = secItem.copyMatching(query)
        guard status == errSecSuccess, let data, let value = String(data: data, encoding: .utf8) else {
            return nil
        }
        return value
    }

    private func deleteSilently(account: String, service: String, dataProtection: Bool) {
        _ = secItem.delete(
            KeychainItemQuery.password(account: account, service: service, dataProtection: dataProtection)
        )
    }
}
