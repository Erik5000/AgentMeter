import XCTest
@testable import ClaudeMeter

final class UsagePopoverContentTests: XCTestCase {
    func test_hasUsageContent_whenClaudeIsMissingAndCodexIsPresent_isDisplayable() {
        XCTAssertTrue(
            UsagePopoverContent.hasUsageContent(
                claude: nil,
                codex: makeCodexUsageData(),
                isCodexUsageShown: true
            )
        )
    }

    func test_hasUsageContent_whenOnlyClaudeIsPresent() {
        XCTAssertTrue(
            UsagePopoverContent.hasUsageContent(
                claude: makeClaudeUsageData(),
                codex: nil,
                isCodexUsageShown: true
            )
        )
    }

    func test_hasUsageContent_whenCodexIsPresentButHidden_isNotDisplayable() {
        XCTAssertFalse(
            UsagePopoverContent.hasUsageContent(
                claude: nil,
                codex: makeCodexUsageData(),
                isCodexUsageShown: false
            )
        )
    }

    func test_hasUsageContent_whenBothProvidersAreMissing_isNotDisplayable() {
        XCTAssertFalse(
            UsagePopoverContent.hasUsageContent(
                claude: nil,
                codex: nil,
                isCodexUsageShown: true
            )
        )
    }

    func test_iconStylePicker_isDisabledWhileCodexUsageIsShown() {
        XCTAssertFalse(IconStyle.isPickerEnabled(isCodexUsageShown: true))
        XCTAssertTrue(IconStyle.isPickerEnabled(isCodexUsageShown: false))
        XCTAssertTrue(IconStyle.dualBarRequiredForCodexCaption.localizedCaseInsensitiveContains("Dual Bar"))
        XCTAssertTrue(IconStyle.dualBarRequiredForCodexCaption.localizedCaseInsensitiveContains("Claude"))
        XCTAssertTrue(IconStyle.dualBarRequiredForCodexCaption.localizedCaseInsensitiveContains("Codex"))
    }

    func test_resolvedIconStyle_usesDualBarWheneverCodexIsShown() {
        XCTAssertEqual(IconStyle.resolved(selected: .battery, showsCodex: true), .dualBar)
        XCTAssertEqual(IconStyle.resolved(selected: .gauge, showsCodex: true), .dualBar)
        XCTAssertEqual(IconStyle.resolved(selected: .battery, showsCodex: false), .battery)
    }

    func test_usageWindowTitle_usesActualCodexDuration() {
        XCTAssertEqual(UsageWindowTitle.session(codexMinutes: 300), "5-Hour Session")
        XCTAssertEqual(UsageWindowTitle.weekly(codexMinutes: 10_080), "Weekly Usage")
        XCTAssertEqual(UsageWindowTitle.weekly(codexMinutes: 43_200), "Monthly Usage")
        XCTAssertEqual(UsageWindowTitle.session(codexMinutes: 90), "90-Minute Window")
        XCTAssertEqual(UsageWindowTitle.session(codexMinutes: nil), "5-Hour Session")
    }

    func test_codexPlanDisplay_replacesUnderscores() {
        XCTAssertEqual(
            CodexPlanDisplay.formatted("self_serve_business_prolite"),
            "Self Serve Business Prolite"
        )
        XCTAssertEqual(CodexPlanDisplay.formatted("plus"), "Plus")
        XCTAssertNil(CodexPlanDisplay.formatted(nil))
    }
}

private func makeClaudeUsageData() -> UsageData {
    UsageData(
        sessionUsage: UsageLimit(utilization: 40, resetAt: Date().addingTimeInterval(3600)),
        weeklyUsage: UsageLimit(utilization: 20, resetAt: Date().addingTimeInterval(86_400)),
        sonnetUsage: nil,
        lastUpdated: Date()
    )
}

private func makeCodexUsageData() -> CodexUsageData {
    CodexUsageData(
        sessionUsage: UsageLimit(utilization: 55, resetAt: Date().addingTimeInterval(3600)),
        sessionWindowMinutes: 300,
        weeklyUsage: UsageLimit(utilization: 18, resetAt: Date().addingTimeInterval(86_400)),
        weeklyWindowMinutes: 10_080,
        planType: "plus",
        lastUpdated: Date()
    )
}
