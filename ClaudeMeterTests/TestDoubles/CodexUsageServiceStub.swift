import Foundation
@testable import ClaudeMeter

actor CodexUsageServiceStub: CodexUsageServiceProtocol {
    let result: Result<CodexUsageData, Error>

    init(result: Result<CodexUsageData, Error>) {
        self.result = result
    }

    func fetchUsage() async throws -> CodexUsageData {
        switch result {
        case .success(let data):
            return data
        case .failure(let error):
            throw error
        }
    }
}
