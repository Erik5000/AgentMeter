import Foundation

enum UsageErrorPresentation {
    static func offersSessionRecovery(_ message: String) -> Bool {
        let tokens = ["session key", "session expired", "invalid or expired", "authentication"]
        return tokens.contains { message.localizedCaseInsensitiveContains($0) }
    }
}
