//
//  KeychainRepositoryFake.swift
//  AgentMeterTests
//
//  Created by Edd on 2026-01-09.
//

import Foundation
@testable import AgentMeter

actor KeychainRepositoryFake: KeychainRepositoryProtocol {
    var sessionKey: String?
    var hasSessionKey: Bool = false

    func save(sessionKey: String, account: String) async throws {
        self.sessionKey = sessionKey
        hasSessionKey = true
    }

    func retrieve(account: String) async throws -> String {
        guard let sessionKey else {
            throw KeychainError.notFound
        }
        return sessionKey
    }

    func update(sessionKey: String, account: String) async throws {
        self.sessionKey = sessionKey
        hasSessionKey = true
    }

    func delete(account: String) async throws {
        sessionKey = nil
        hasSessionKey = false
    }

    func exists(account: String) async -> Bool {
        hasSessionKey
    }
}
