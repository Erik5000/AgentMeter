import Foundation
@testable import ClaudeMeter

actor CodexUsageServiceStub: CodexUsageServiceProtocol {
    let result: Result<CodexUsageData, Error>
    let fetchDelay: Duration?
    private(set) var fetchWasCancelled = false
    private var fetchStarted = false
    private var fetchStartedWaiters: [CheckedContinuation<Void, Never>] = []

    init(result: Result<CodexUsageData, Error>, fetchDelay: Duration? = nil) {
        self.result = result
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

    func fetchUsage() async throws -> CodexUsageData {
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

        switch result {
        case .success(let data):
            return data
        case .failure(let error):
            throw error
        }
    }
}
