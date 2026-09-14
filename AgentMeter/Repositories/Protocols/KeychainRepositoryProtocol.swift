//
//  KeychainRepositoryProtocol.swift
//  ClaudeMeter
//
//  Created by Edd on 2025-11-14.
//

import Foundation

/// Protocol for secure keychain operations
protocol KeychainRepositoryProtocol: Actor {
    /// Save session key to keychain
    func save(sessionKey: String, account: String) async throws

    /// Retrieve session key from keychain
    func retrieve(account: String) async throws -> String

    /// Update existing session key
    func update(sessionKey: String, account: String) async throws

    /// Delete session key from keychain
    func delete(account: String) async throws

    /// Check if session key exists for account
    func exists(account: String) async -> Bool
}
