import Foundation

/// One independently metered Codex quota, which may apply to a model or mode.
struct CodexUsageBucket: Equatable, Identifiable, Sendable {
    let id: String
    let limitName: String?
    let modelSlug: String?
    let sessionUsage: UsageLimit?
    let sessionWindowMinutes: Double?
    let longTermUsage: UsageLimit?
    let longTermWindowMinutes: Double?

    var modeName: String? {
        if let limitName = Self.nonEmpty(limitName) {
            let normalizedName = limitName.lowercased()
            if normalizedName != "codex", normalizedName != "default", normalizedName != "shared" {
                return limitName
            }
        }
        if let modelSlug = Self.nonEmpty(modelSlug) {
            return CodexModelDisplay.formatted(modelSlug)
        }

        let normalizedID = id.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !normalizedID.isEmpty, normalizedID != "codex", normalizedID != "default" else {
            return nil
        }
        return CodexModelDisplay.formatted(id)
    }

    var sessionWindowDuration: TimeInterval? {
        sessionWindowMinutes.map { $0 * 60 }
    }

    var longTermWindowDuration: TimeInterval? {
        longTermWindowMinutes.map { $0 * 60 }
    }

    var usageLimits: [UsageLimit] {
        [sessionUsage, longTermUsage].compactMap { $0 }
    }

    private static func nonEmpty(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

/// Usage limits reported by the locally installed Codex app server.
struct CodexUsageData: Equatable, Sendable {
    let buckets: [CodexUsageBucket]
    let planType: String?
    let lastUpdated: Date

    init(
        buckets: [CodexUsageBucket],
        planType: String?,
        lastUpdated: Date
    ) {
        self.buckets = buckets
        self.planType = planType
        self.lastUpdated = lastUpdated
    }

    /// Compatibility initializer for callers that have the historical single Codex quota.
    init(
        sessionUsage: UsageLimit,
        sessionWindowMinutes: Double?,
        weeklyUsage: UsageLimit?,
        weeklyWindowMinutes: Double?,
        planType: String?,
        lastUpdated: Date
    ) {
        buckets = [
            CodexUsageBucket(
                id: "codex",
                limitName: nil,
                modelSlug: nil,
                sessionUsage: sessionUsage,
                sessionWindowMinutes: sessionWindowMinutes,
                longTermUsage: weeklyUsage,
                longTermWindowMinutes: weeklyWindowMinutes
            )
        ]
        self.planType = planType
        self.lastUpdated = lastUpdated
    }

    var sessionUsage: UsageLimit? {
        preferredBucket(for: \CodexUsageBucket.sessionUsage)?.sessionUsage
    }

    var sessionWindowMinutes: Double? {
        preferredBucket(for: \CodexUsageBucket.sessionUsage)?.sessionWindowMinutes
    }

    var weeklyUsage: UsageLimit? {
        preferredBucket(for: \CodexUsageBucket.longTermUsage)?.longTermUsage
    }

    var weeklyWindowMinutes: Double? {
        preferredBucket(for: \CodexUsageBucket.longTermUsage)?.longTermWindowMinutes
    }

    var sessionWindowDuration: TimeInterval? {
        sessionWindowMinutes.map { $0 * 60 }
    }

    var weeklyWindowDuration: TimeInterval? {
        weeklyWindowMinutes.map { $0 * 60 }
    }

    var usageLimits: [UsageLimit] {
        buckets.flatMap(\.usageLimits)
    }

    var isStale: Bool {
        Date().timeIntervalSince(lastUpdated) > Constants.Refresh.stalenessThreshold
    }

    private func preferredBucket(
        for keyPath: KeyPath<CodexUsageBucket, UsageLimit?>
    ) -> CodexUsageBucket? {
        buckets.first { $0.id.caseInsensitiveCompare("codex") == .orderedSame && $0[keyPath: keyPath] != nil }
            ?? buckets.first { $0[keyPath: keyPath] != nil }
    }
}

enum CodexModelDisplay {
    static func formatted(_ rawValue: String) -> String {
        let components = rawValue
            .replacingOccurrences(of: "_", with: "-")
            .split(separator: "-")
        guard components.count > 1, components[0].lowercased() == "gpt" else {
            return components.map(formatComponent).joined(separator: " ")
        }

        let family = "GPT-\(formatComponent(components[1]))"
        let suffix = components.dropFirst(2).map(formatComponent)
        return ([family] + suffix).joined(separator: " ")
    }

    private static func formatComponent(_ component: Substring) -> String {
        let value = String(component)
        switch value.lowercased() {
        case "gpt":
            return "GPT"
        case "codex":
            return "Codex"
        default:
            if value.rangeOfCharacter(from: .decimalDigits) != nil {
                return value.uppercased()
            }
            return value.localizedCapitalized
        }
    }
}
