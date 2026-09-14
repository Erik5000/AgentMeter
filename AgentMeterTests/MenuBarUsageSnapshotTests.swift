import XCTest
@testable import ClaudeMeter

final class MenuBarUsageSnapshotTests: XCTestCase {
    func test_withoutCodex_displaysClaudeSessionAndUsesClaudeWeeklyForDualBar() {
        let claude = makeClaudeUsage(session: 1, weekly: 62)
        let snapshot = MenuBarUsageSnapshot.make(
            claude: claude,
            codex: nil,
            isCodexUsageShown: false,
            isLoading: false
        )

        XCTAssertEqual(snapshot.displayedPercentage, 62)
        XCTAssertEqual(snapshot.claudeDisplayedPercentage, 62)
        XCTAssertNil(snapshot.codexDisplayedPercentage)
        XCTAssertEqual(snapshot.status, .warning)
        XCTAssertEqual(snapshot.weeklyPercentage, 62)
        XCTAssertFalse(snapshot.showsCodex)
        XCTAssertNil(snapshot.codexSession)
        XCTAssertNil(snapshot.codexWeekly)
        XCTAssertEqual(
            snapshot.tooltip,
            """
            Claude
            Session 1%
            Week 62%
            """
        )
    }

    func test_withCodex_displaysTheHighestOfAllFourLimits() {
        let snapshot = MenuBarUsageSnapshot.make(
            claude: makeClaudeUsage(session: 1, weekly: 62),
            codex: makeCodexUsage(session: 13, weekly: 24),
            isCodexUsageShown: true,
            isLoading: false
        )

        XCTAssertEqual(snapshot.displayedPercentage, 62)
        XCTAssertEqual(snapshot.claudeDisplayedPercentage, 62)
        XCTAssertEqual(snapshot.codexDisplayedPercentage, 24)
        XCTAssertEqual(snapshot.claudeStatus, .warning)
        XCTAssertEqual(snapshot.codexStatus, .safe)
        XCTAssertEqual(snapshot.status, .warning)
        XCTAssertTrue(snapshot.showsCodex)
        XCTAssertEqual(snapshot.claudeSession, 1)
        XCTAssertEqual(snapshot.claudeWeekly, 62)
        XCTAssertEqual(snapshot.codexSession, 13)
        XCTAssertEqual(snapshot.codexWeekly, 24)
        XCTAssertEqual(
            snapshot.tooltip,
            """
            Claude
            Session 1%
            Week 62%
            Codex
            Session 13%
            Week 24%
            """
        )
    }

    func test_withCodex_usesCodexWhenItIsTheHighestLimit() {
        let snapshot = MenuBarUsageSnapshot.make(
            claude: makeClaudeUsage(session: 10, weekly: 20),
            codex: makeCodexUsage(session: 13, weekly: 91),
            isCodexUsageShown: true,
            isLoading: false
        )

        XCTAssertEqual(snapshot.displayedPercentage, 91)
        XCTAssertEqual(snapshot.claudeDisplayedPercentage, 20)
        XCTAssertEqual(snapshot.codexDisplayedPercentage, 91)
        XCTAssertEqual(snapshot.claudeStatus, .safe)
        XCTAssertEqual(snapshot.codexStatus, .critical)
        XCTAssertEqual(snapshot.status, .critical)
    }

    func test_withCodexEnabledButNoData_stillReservesTheCodexColumn() {
        let snapshot = MenuBarUsageSnapshot.make(
            claude: makeClaudeUsage(session: 40, weekly: 12),
            codex: nil,
            isCodexUsageShown: true,
            isLoading: false
        )

        XCTAssertTrue(snapshot.showsCodex)
        XCTAssertNil(snapshot.codexSession)
        XCTAssertNil(snapshot.codexWeekly)
        XCTAssertNil(snapshot.codexDisplayedPercentage)
        XCTAssertEqual(snapshot.displayedPercentage, 40)
        XCTAssertEqual(snapshot.status, .safe)
        XCTAssertFalse(snapshot.tooltip.contains("Codex 0%"))
        XCTAssertTrue(snapshot.tooltip.contains("Codex\nCan't load"))
    }

    func test_withoutClaudeData_doesNotTreatMissingClaudeAsZeroPercent() {
        let snapshot = MenuBarUsageSnapshot.make(
            claude: nil,
            codex: makeCodexUsage(session: 55, weekly: 18),
            isCodexUsageShown: true,
            isLoading: false
        )

        XCTAssertEqual(snapshot.displayedPercentage, 55)
        XCTAssertEqual(snapshot.status, .warning)
        XCTAssertNil(snapshot.claudeSession)
        XCTAssertNil(snapshot.claudeWeekly)
        XCTAssertEqual(snapshot.codexSession, 55)
        XCTAssertFalse(snapshot.tooltip.contains("Claude 0%"))
        XCTAssertTrue(snapshot.tooltip.contains("Claude\nCan't load"))
    }

    func test_isStale_whenOnlyCodexDataIsOlderThanThreshold() {
        let staleCodex = CodexUsageData(
            sessionUsage: UsageLimit(utilization: 20, resetAt: Date().addingTimeInterval(3600)),
            sessionWindowMinutes: 300,
            weeklyUsage: UsageLimit(utilization: 10, resetAt: Date().addingTimeInterval(86_400)),
            weeklyWindowMinutes: 10_080,
            planType: "plus",
            lastUpdated: Date().addingTimeInterval(-(Constants.Refresh.stalenessThreshold + 60))
        )
        let snapshot = MenuBarUsageSnapshot.make(
            claude: nil,
            codex: staleCodex,
            isCodexUsageShown: true,
            isLoading: false
        )

        XCTAssertTrue(snapshot.isStale)
    }

    func test_isStale_whenClaudeIsFreshAndCodexIsStale() {
        let staleCodex = CodexUsageData(
            sessionUsage: UsageLimit(utilization: 20, resetAt: Date().addingTimeInterval(3600)),
            sessionWindowMinutes: 300,
            weeklyUsage: nil,
            weeklyWindowMinutes: nil,
            planType: "plus",
            lastUpdated: Date().addingTimeInterval(-(Constants.Refresh.stalenessThreshold + 60))
        )
        let snapshot = MenuBarUsageSnapshot.make(
            claude: makeClaudeUsage(session: 10, weekly: 10),
            codex: staleCodex,
            isCodexUsageShown: true,
            isLoading: false
        )

        XCTAssertTrue(snapshot.isStale)
    }

    private func makeClaudeUsage(session: Double, weekly: Double) -> UsageData {
        UsageData(
            sessionUsage: UsageLimit(utilization: session, resetAt: Date().addingTimeInterval(3600)),
            weeklyUsage: UsageLimit(utilization: weekly, resetAt: Date().addingTimeInterval(86_400)),
            sonnetUsage: nil,
            lastUpdated: Date()
        )
    }

    private func makeCodexUsage(session: Double, weekly: Double) -> CodexUsageData {
        CodexUsageData(
            sessionUsage: UsageLimit(utilization: session, resetAt: Date().addingTimeInterval(3600)),
            sessionWindowMinutes: 300,
            weeklyUsage: UsageLimit(utilization: weekly, resetAt: Date().addingTimeInterval(86_400)),
            weeklyWindowMinutes: 10_080,
            planType: "plus",
            lastUpdated: Date()
        )
    }
}
