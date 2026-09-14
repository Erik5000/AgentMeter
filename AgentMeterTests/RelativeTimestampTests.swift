import XCTest
@testable import ClaudeMeter

final class RelativeTimestampTests: XCTestCase {
    func test_age_usesSingularMinute() {
        let now = Date()
        XCTAssertEqual(
            RelativeTimestamp.age(since: now.addingTimeInterval(-60), now: now),
            "1 min ago"
        )
    }

    func test_age_usesCompactMinutesAndHours() {
        let now = Date()
        XCTAssertEqual(
            RelativeTimestamp.age(since: now.addingTimeInterval(-5), now: now),
            "just now"
        )
        XCTAssertEqual(
            RelativeTimestamp.age(since: now.addingTimeInterval(-3 * 60), now: now),
            "3 min ago"
        )
        XCTAssertEqual(
            RelativeTimestamp.age(since: now.addingTimeInterval(-2 * 3600), now: now),
            "2 hours ago"
        )
        XCTAssertEqual(
            RelativeTimestamp.age(since: now.addingTimeInterval(-3600), now: now),
            "1 hour ago"
        )
    }

    func test_usageData_freshnessDescription_matchesRelativeTimestamp() {
        let now = Date()
        let data = UsageData(
            sessionUsage: UsageLimit(utilization: 10, resetAt: now.addingTimeInterval(3600)),
            weeklyUsage: UsageLimit(utilization: 10, resetAt: now.addingTimeInterval(86_400)),
            sonnetUsage: nil,
            lastUpdated: now.addingTimeInterval(-60)
        )

        XCTAssertEqual(data.freshnessDescription(now: now), "1 min ago")
    }
}
