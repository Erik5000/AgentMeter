//
//  UsageData.swift
//  AgentMeter
//
//  Created by Edd on 2025-11-14.
//

import Foundation

/// Complete usage data across all limit types
struct UsageData: Codable, Equatable, Sendable {
    /// 5-hour rolling session usage
    let sessionUsage: UsageLimit

    /// 7-day weekly usage across all models
    let weeklyUsage: UsageLimit

    /// 7-day Sonnet-specific usage (nil if not used)
    let sonnetUsage: UsageLimit?

    /// 7-day Fable-specific usage (nil if not reported by the account)
    let fableUsage: UsageLimit?

    /// Timestamp of when this data was fetched
    let lastUpdated: Date

    init(
        sessionUsage: UsageLimit,
        weeklyUsage: UsageLimit,
        sonnetUsage: UsageLimit?,
        fableUsage: UsageLimit? = nil,
        lastUpdated: Date
    ) {
        self.sessionUsage = sessionUsage
        self.weeklyUsage = weeklyUsage
        self.sonnetUsage = sonnetUsage
        self.fableUsage = fableUsage
        self.lastUpdated = lastUpdated
    }

    enum CodingKeys: String, CodingKey {
        case sessionUsage = "session_usage"
        case weeklyUsage = "weekly_usage"
        case sonnetUsage = "sonnet_usage"
        case fableUsage = "fable_usage"
        case lastUpdated = "last_updated"
    }
}

extension UsageData {
    /// Returns the primary usage level for menu bar display
    var primaryStatus: UsageStatus {
        sessionUsage.status
    }

    /// Human-readable staleness indicator
    func freshnessDescription(now: Date = Date()) -> String {
        RelativeTimestamp.age(since: lastUpdated, now: now)
    }

    var isStale: Bool {
        Date().timeIntervalSince(lastUpdated) > Constants.Refresh.stalenessThreshold
    }
}
