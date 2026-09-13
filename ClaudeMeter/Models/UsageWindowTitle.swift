import Foundation

enum UsageWindowTitle {
    static func session(codexMinutes: Double? = nil) -> String {
        displayName(minutes: codexMinutes, fallback: "5-Hour Session")
    }

    static func weekly(codexMinutes: Double? = nil) -> String {
        displayName(minutes: codexMinutes, fallback: "Weekly Usage")
    }

    static func displayName(minutes: Double?, fallback: String) -> String {
        guard let minutes else { return fallback }
        switch classification(minutes) {
        case .fiveHour:
            return "5-Hour Session"
        case .weekly:
            return "Weekly Usage"
        case .monthly:
            return "Monthly Usage"
        case .custom:
            return formatted(minutes)
        }
    }

    static func formatted(_ minutes: Double) -> String {
        if minutes < 120 {
            let value = max(1, Int(minutes.rounded()))
            return "\(value)-Minute Window"
        }
        if minutes < 24 * 60 {
            let hours = max(1, Int((minutes / 60).rounded()))
            return "\(hours)-Hour Window"
        }
        let days = max(1, Int((minutes / (24 * 60)).rounded()))
        return "\(days)-Day Window"
    }

    enum Classification {
        case fiveHour
        case weekly
        case monthly
        case custom
    }

    static func classification(_ minutes: Double) -> Classification {
        if (180...480).contains(minutes) {
            return .fiveHour
        }
        if (6 * 24 * 60...9 * 24 * 60).contains(minutes) {
            return .weekly
        }
        if minutes >= 20 * 24 * 60 {
            return .monthly
        }
        return .custom
    }
}
