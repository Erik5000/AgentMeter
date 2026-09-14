import Foundation

/// Usage limits reported by the locally installed Codex app server.
struct CodexUsageData: Equatable, Sendable {
    let sessionUsage: UsageLimit
    let sessionWindowMinutes: Double?
    let weeklyUsage: UsageLimit?
    let weeklyWindowMinutes: Double?
    let planType: String?
    let lastUpdated: Date
}

extension CodexUsageData {
    var sessionWindowDuration: TimeInterval? {
        sessionWindowMinutes.map { $0 * 60 }
    }

    var weeklyWindowDuration: TimeInterval? {
        weeklyWindowMinutes.map { $0 * 60 }
    }

    var isStale: Bool {
        Date().timeIntervalSince(lastUpdated) > Constants.Refresh.stalenessThreshold
    }
}
