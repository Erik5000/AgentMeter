import Foundation

protocol CodexUsageServiceProtocol: Actor {
    func fetchUsage() async throws -> CodexUsageData
}
