//
//  KeychainRepository.swift
//  AgentMeter
//
//  Created by Edd on 2025-11-14.
//

import Foundation
import Security

/// Actor-isolated repository for secure Keychain operations.
///
/// Prefers the data-protection keychain so macOS cannot show the ACL password
/// dialog for a file-based item. Unsigned local Debug builds lack that
/// entitlement (`errSecMissingEntitlement` / -34018) and fall back once.
actor KeychainRepository: KeychainRepositoryProtocol {
    private let secItem: any SecItemClient
    private let serviceName: String
    private var cachedSessionKeys: [String: String] = [:]
    private var usesDataProtectionKeychain = true

    init(
        secItem: any SecItemClient = SystemSecItemClient(),
        serviceName: String = AppIdentity.keychainService
    ) {
        self.secItem = secItem
        self.serviceName = serviceName
    }

    func save(sessionKey: String, account: String) async throws {
        try persist(sessionKey: sessionKey, account: account)
        cachedSessionKeys[account] = sessionKey
    }

    func retrieve(account: String) async throws -> String {
        if let cached = cachedSessionKeys[account] {
            return cached
        }

        if let value = copyString(account: account) {
            cachedSessionKeys[account] = value
            return value
        }

        throw KeychainError.notFound
    }

    func update(sessionKey: String, account: String) async throws {
        try persist(sessionKey: sessionKey, account: account)
        cachedSessionKeys[account] = sessionKey
    }

    func delete(account: String) async throws {
        cachedSessionKeys[account] = nil
        var status = secItem.delete(passwordQuery(account: account))
        if shouldRetryWithoutDataProtection(status) {
            status = secItem.delete(passwordQuery(account: account))
        }
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.deleteFailed(OSStatus: status)
        }
    }

    func exists(account: String) async -> Bool {
        (try? await retrieve(account: account)) != nil
    }

    private func persist(sessionKey: String, account: String) throws {
        guard let data = sessionKey.data(using: .utf8) else {
            throw KeychainError.saveFailed(OSStatus: errSecParam)
        }

        var addStatus = secItem.add(addQuery(account: account, data: data))
        if shouldRetryWithoutDataProtection(addStatus) {
            addStatus = secItem.add(addQuery(account: account, data: data))
        }

        if addStatus == errSecDuplicateItem {
            var updateStatus = secItem.update(
                query: passwordQuery(account: account),
                attributes: [kSecValueData as String: data]
            )
            if shouldRetryWithoutDataProtection(updateStatus) {
                updateStatus = secItem.update(
                    query: passwordQuery(account: account),
                    attributes: [kSecValueData as String: data]
                )
            }
            guard updateStatus == errSecSuccess else {
                throw KeychainError.updateFailed(OSStatus: updateStatus)
            }
        } else if addStatus != errSecSuccess {
            throw KeychainError.saveFailed(OSStatus: addStatus)
        }
    }

    private func copyString(account: String) -> String? {
        var (status, data) = secItem.copyMatching(lookupQuery(account: account))
        if shouldRetryWithoutDataProtection(status) {
            (status, data) = secItem.copyMatching(lookupQuery(account: account))
        }
        guard status == errSecSuccess, let data, let value = String(data: data, encoding: .utf8) else {
            return nil
        }
        return value
    }

    private func shouldRetryWithoutDataProtection(_ status: OSStatus) -> Bool {
        guard status == errSecMissingEntitlement, usesDataProtectionKeychain else {
            return false
        }
        usesDataProtectionKeychain = false
        return true
    }

    private func passwordQuery(account: String) -> [String: Any] {
        KeychainItemQuery.password(
            account: account,
            service: serviceName,
            usesDataProtectionKeychain: usesDataProtectionKeychain
        )
    }

    private func lookupQuery(account: String) -> [String: Any] {
        KeychainItemQuery.lookup(
            account: account,
            service: serviceName,
            returnData: true,
            usesDataProtectionKeychain: usesDataProtectionKeychain
        )
    }

    private func addQuery(account: String, data: Data) -> [String: Any] {
        KeychainItemQuery.add(
            account: account,
            service: serviceName,
            data: data,
            usesDataProtectionKeychain: usesDataProtectionKeychain
        )
    }
}
