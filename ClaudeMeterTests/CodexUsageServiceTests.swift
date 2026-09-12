import XCTest
@testable import ClaudeMeter

final class CodexUsageServiceTests: XCTestCase {
    func test_rateLimitResponse_mapsSessionAndWeeklyUsage() throws {
        let response = """
        {
          "id": 1,
          "result": {
            "rateLimits": {
              "primary": {
                "usedPercent": 32,
                "windowDurationMins": 300,
                "resetsAt": 1788378759
              },
              "secondary": {
                "usedPercent": 25,
                "windowDurationMins": 10080,
                "resetsAt": 1788856695
              },
              "planType": "plus"
            }
          }
        }
        """.data(using: .utf8)!
        let now = Date(timeIntervalSince1970: 1_700_000_000)

        let usage = try CodexUsageService.parseRateLimitsResponse(response, now: now)

        XCTAssertEqual(usage.sessionUsage.percentage, 32)
        XCTAssertEqual(usage.sessionWindowMinutes, 300)
        XCTAssertEqual(usage.weeklyUsage?.percentage, 25)
        XCTAssertEqual(usage.weeklyWindowMinutes, 10080)
        XCTAssertEqual(usage.planType, "plus")
        XCTAssertEqual(usage.lastUpdated, now)
        XCTAssertEqual(usage.sessionUsage.resetAt, Date(timeIntervalSince1970: 1_788_378_759))
    }

    func test_rateLimitResponse_withoutPrimaryLimit_isRejected() {
        let response = """
        {
          "id": 1,
          "result": {
            "rateLimits": {
              "primary": null,
              "secondary": null,
              "planType": "plus"
            }
          }
        }
        """.data(using: .utf8)!

        XCTAssertThrowsError(try CodexUsageService.parseRateLimitsResponse(response)) { error in
            XCTAssertEqual(error as? CodexUsageError, .invalidResponse)
        }
    }

    func test_rateLimitResponse_surfacesServerError() {
        let response = """
        {
          "id": 1,
          "error": {
            "message": "Sign in to Codex to view usage."
          }
        }
        """.data(using: .utf8)!

        XCTAssertThrowsError(try CodexUsageService.parseRateLimitsResponse(response)) { error in
            XCTAssertEqual(
                error as? CodexUsageError,
                .serverError("Sign in to Codex to view usage.")
            )
        }
    }

    func test_rateLimitResponse_withoutWeeklyLimit_stillMapsSession() throws {
        let response = """
        {
          "id": 1,
          "result": {
            "rateLimits": {
              "primary": {
                "usedPercent": 8,
                "windowDurationMins": 300,
                "resetsAt": 1788378759
              },
              "planType": "plus"
            }
          }
        }
        """.data(using: .utf8)!

        let usage = try CodexUsageService.parseRateLimitsResponse(response)

        XCTAssertEqual(usage.sessionUsage.percentage, 8)
        XCTAssertNil(usage.weeklyUsage)
        XCTAssertNil(usage.weeklyWindowMinutes)
    }
}
