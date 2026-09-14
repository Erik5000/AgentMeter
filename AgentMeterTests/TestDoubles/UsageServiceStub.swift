//
//  UsageServiceStub.swift
//  ClaudeMeterTests
//
//  Created by Edd on 2026-01-09.
//

import Foundation
@testable import ClaudeMeter

actor UsageServiceStub: UsageServiceProtocol {
    let fetchUsageResult: Result<UsageData, Error>
    let isSessionKeyValid: Bool
    let organizations: [Organization]
    let fetchDelay: Duration?
    private(set) var fetchWasCancelled = false
    private(set) var fetchCallCount = 0
    private var fetchStarted = false
    private var fetchStartedWaiters: [CheckedContinuation<Void, Never>] = []

    init(
        fetchUsageResult: Result<UsageData, Error>,
        organizations: [Organization] = [],
        isSessionKeyValid: Bool = true,
        fetchDelay: Duration? = nil
    ) {
        self.fetchUsageResult = fetchUsageResult
        self.organizations = organizations
        self.isSessionKeyValid = isSessionKeyValid
        self.fetchDelay = fetchDelay
    }

    func waitUntilFetchStarted() async {
        if fetchStarted { return }
        await withCheckedContinuation { continuation in
            fetchStartedWaiters.append(continuation)
        }
    }

    func didCancelFetch() -> Bool {
        fetchWasCancelled
    }

    func fetchUsage(forceRefresh: Bool) async throws -> UsageData {
        fetchCallCount += 1
        fetchStarted = true
        let waiters = fetchStartedWaiters
        fetchStartedWaiters = []
        waiters.forEach { $0.resume() }

        if let fetchDelay {
            do {
                try await Task.sleep(for: fetchDelay)
            } catch {
                fetchWasCancelled = true
                throw error
            }
        }

        switch fetchUsageResult {
        case .success(let data):
            return data
        case .failure(let error):
            throw error
        }
    }

    func fetchOrganizations() async throws -> [Organization] {
        organizations
    }

    func fetchOrganizations(sessionKey: SessionKey) async throws -> [Organization] {
        organizations
    }

    func validateSessionKey(_ sessionKey: SessionKey) async throws -> Bool {
        isSessionKeyValid
    }
}
