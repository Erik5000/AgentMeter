import Foundation

/// Flattened usage values for the menu-bar icon and its tooltip.
struct MenuBarUsageSnapshot: Equatable, Sendable {
    let displayedPercentage: Double
    let weeklyPercentage: Double
    let status: UsageStatus
    let isLoading: Bool
    let isStale: Bool
    let showsCodex: Bool
    let claudeSession: Double?
    let claudeWeekly: Double?
    let claudeDisplayedPercentage: Double?
    let claudeStatus: UsageStatus?
    let codexSession: Double?
    let codexWeekly: Double?
    let codexDisplayedPercentage: Double?
    let codexStatus: UsageStatus?
    let tooltip: String

    static func make(
        claude: UsageData?,
        codex: CodexUsageData?,
        isCodexUsageShown: Bool,
        isLoading: Bool
    ) -> MenuBarUsageSnapshot {
        let claudeSession = claude?.sessionUsage.percentage
        let claudeWeekly = claude?.weeklyUsage.percentage
        let claudeDisplayedPercentage = claude.map {
            max($0.sessionUsage.percentage, $0.weeklyUsage.percentage)
        }
        let claudeStatus = claudeDisplayedPercentage.map(UsageStatus.forPercentage)
        let showsCodex = isCodexUsageShown
        let codexSession = showsCodex ? codex?.sessionUsage.percentage : nil
        let codexWeekly = showsCodex ? codex?.weeklyUsage?.percentage : nil
        let codexDisplayedPercentage: Double? = {
            guard showsCodex, let codex else { return nil }
            return max(codex.sessionUsage.percentage, codex.weeklyUsage?.percentage ?? 0)
        }()
        let codexStatus = codexDisplayedPercentage.map(UsageStatus.forPercentage)

        var candidates: [(percentage: Double, status: UsageStatus)] = []
        if let claudeDisplayedPercentage, let claudeStatus {
            candidates.append((claudeDisplayedPercentage, claudeStatus))
        }
        if let codexDisplayedPercentage, let codexStatus {
            candidates.append((codexDisplayedPercentage, codexStatus))
        }

        let leading = candidates.max { lhs, rhs in
            if lhs.percentage == rhs.percentage {
                return lhs.status.rank < rhs.status.rank
            }
            return lhs.percentage < rhs.percentage
        }

        let claudeStale = claude?.isStale ?? false
        let codexStale = showsCodex && (codex?.isStale ?? false)

        return MenuBarUsageSnapshot(
            displayedPercentage: leading?.percentage ?? 0,
            weeklyPercentage: claudeWeekly ?? 0,
            status: leading?.status ?? .safe,
            isLoading: isLoading,
            isStale: claudeStale || codexStale,
            showsCodex: showsCodex,
            claudeSession: claudeSession,
            claudeWeekly: claudeWeekly,
            claudeDisplayedPercentage: claudeDisplayedPercentage,
            claudeStatus: claudeStatus,
            codexSession: codexSession,
            codexWeekly: codexWeekly,
            codexDisplayedPercentage: codexDisplayedPercentage,
            codexStatus: codexStatus,
            tooltip: tooltip(
                showsCodex: showsCodex,
                claudeDisplayedPercentage: claudeDisplayedPercentage,
                claudeSession: claudeSession,
                claudeWeekly: claudeWeekly,
                codexDisplayedPercentage: codexDisplayedPercentage,
                codexSession: codexSession,
                codexWeekly: codexWeekly,
                hasCodexData: codex != nil
            )
        )
    }

    private static func tooltip(
        showsCodex: Bool,
        claudeDisplayedPercentage: Double?,
        claudeSession: Double?,
        claudeWeekly: Double?,
        codexDisplayedPercentage: Double?,
        codexSession: Double?,
        codexWeekly: Double?,
        hasCodexData: Bool
    ) -> String {
        var blocks: [String] = [
            providerBlock(
                name: "Claude",
                session: claudeSession,
                weekly: claudeWeekly,
                hasAnyValue: claudeDisplayedPercentage != nil
            )
        ]

        if showsCodex {
            blocks.append(
                providerBlock(
                    name: "Codex",
                    session: codexSession,
                    weekly: codexWeekly,
                    hasAnyValue: hasCodexData && codexDisplayedPercentage != nil
                )
            )
        }

        return blocks.joined(separator: "\n")
    }

    private static func providerBlock(
        name: String,
        session: Double?,
        weekly: Double?,
        hasAnyValue: Bool
    ) -> String {
        var lines = [name]
        if !hasAnyValue {
            lines.append("Can't load")
            return lines.joined(separator: "\n")
        }
        if let session {
            lines.append("Session \(Int(session))%")
        }
        if let weekly {
            lines.append("Week \(Int(weekly))%")
        }
        return lines.joined(separator: "\n")
    }
}
