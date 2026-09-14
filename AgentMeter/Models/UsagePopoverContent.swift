import Foundation

/// Conditions for showing usage cards in the menu-bar popover.
enum UsagePopoverContent {
    static func hasUsageContent(
        claude: UsageData?,
        codex: CodexUsageData?,
        isCodexUsageShown: Bool
    ) -> Bool {
        claude != nil || (isCodexUsageShown && codex != nil)
    }
}
