import Foundation

enum RelativeTimestamp {
    static func age(since date: Date, now: Date = Date()) -> String {
        let elapsed = now.timeIntervalSince(date)
        if elapsed < 60 {
            return "just now"
        }

        if elapsed < 3600 {
            let minutes = max(1, Int(elapsed / 60))
            return minutes == 1 ? "1 min ago" : "\(minutes) min ago"
        }

        let hours = max(1, Int(elapsed / 3600))
        return hours == 1 ? "1 hour ago" : "\(hours) hours ago"
    }
}
