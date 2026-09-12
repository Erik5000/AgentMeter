import Foundation

/// Flattened usage values for the menu-bar icon and its tooltip.
struct MenuBarUsageSnapshot: Equatable, Sendable {
    let displayedPercentage: Double
    let weeklyPercentage: Double
    let status: UsageStatus
    let isLoading: Bool
    let isStale: Bool
    let showsCodex: Bool
    let claudeSession: Double
    let claudeWeekly: Double
    let claudeDisplayedPercentage: Double
    let claudeStatus: UsageStatus
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
        let claudeSession = claude?.sessionUsage.percentage ?? 0
        let claudeWeekly = claude?.weeklyUsage.percentage ?? 0
        let claudeDisplayedPercentage = max(claudeSession, claudeWeekly)
        let claudeStatus = UsageStatus.forPercentage(claudeDisplayedPercentage)
        let showsCodex = isCodexUsageShown
        let codexSession = showsCodex ? (codex?.sessionUsage.percentage ?? 0) : nil
        let codexWeekly = showsCodex ? (codex?.weeklyUsage?.percentage ?? 0) : nil
        let codexDisplayedPercentage = showsCodex ? max(codexSession ?? 0, codexWeekly ?? 0) : nil
        let codexStatus = codexDisplayedPercentage.map(UsageStatus.forPercentage)

        var candidates: [(percentage: Double, status: UsageStatus)] = [
            (claudeDisplayedPercentage, claudeStatus)
        ]
        if let codexDisplayedPercentage, let codexStatus {
            candidates.append((codexDisplayedPercentage, codexStatus))
        }

        let leading = candidates.max { lhs, rhs in
            if lhs.percentage == rhs.percentage {
                return lhs.status.rank < rhs.status.rank
            }
            return lhs.percentage < rhs.percentage
        }

        var tooltipParts = [
            "Claude \(Int(claudeDisplayedPercentage))%",
            "Claude session \(Int(claudeSession))%",
            "Claude weekly \(Int(claudeWeekly))%"
        ]
        if showsCodex {
            tooltipParts.insert("Codex \(Int(codexDisplayedPercentage ?? 0))%", at: 1)
            tooltipParts.append("Codex session \(Int(codexSession ?? 0))%")
            tooltipParts.append("Codex weekly \(Int(codexWeekly ?? 0))%")
        }

        return MenuBarUsageSnapshot(
            displayedPercentage: leading?.percentage ?? 0,
            weeklyPercentage: claudeWeekly,
            status: leading?.status ?? .safe,
            isLoading: isLoading,
            isStale: claude?.isStale ?? false,
            showsCodex: showsCodex,
            claudeSession: claudeSession,
            claudeWeekly: claudeWeekly,
            claudeDisplayedPercentage: claudeDisplayedPercentage,
            claudeStatus: claudeStatus,
            codexSession: codexSession,
            codexWeekly: codexWeekly,
            codexDisplayedPercentage: codexDisplayedPercentage,
            codexStatus: codexStatus,
            tooltip: tooltipParts.joined(separator: ", ")
        )
    }
}
