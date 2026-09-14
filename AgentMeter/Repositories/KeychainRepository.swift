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
/// Session keys live only in the data-protection keychain. The file-based
/// login keychain is never queried, so macOS cannot show the ACL password
/// dialog for `com.claudemeter.sessionkey`.
actor KeychainRepository: KeychainRepositoryProtocol {
    private let secItem: any SecItemClient
    private let serviceName: String
    private var cachedSessionKeys: [String: String] = [:]

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
        let status = secItem.delete(KeychainItemQuery.password(account: account, service: serviceName))
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

        let addStatus = secItem.add(KeychainItemQuery.add(account: account, service: serviceName, data: data))
        if addStatus == errSecDuplicateItem {
            let updateStatus = secItem.update(
                query: KeychainItemQuery.password(account: account, service: serviceName),
                attributes: [kSecValueData as String: data]
            )
            guard updateStatus == errSecSuccess else {
                throw KeychainError.updateFailed(OSStatus: updateStatus)
            }
        } else if addStatus != errSecSuccess {
            throw KeychainError.saveFailed(OSStatus: addStatus)
        }
    }

    private func copyString(account: String) -> String? {
        let query = KeychainItemQuery.lookup(account: account, service: serviceName, returnData: true)
        let (status, data) = secItem.copyMatching(query)
        guard status == errSecSuccess, let data, let value = String(data: data, encoding: .utf8) else {
            return nil
        }
        return value
    }
}
