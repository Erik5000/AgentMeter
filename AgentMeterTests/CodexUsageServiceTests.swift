import XCTest
@testable import AgentMeter

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

    func test_rateLimitResponse_withNullResetAndDuration_stillMapsUsage() throws {
        let response = """
        {
          "id": 1,
          "result": {
            "rateLimits": {
              "primary": {
                "usedPercent": 12,
                "windowDurationMins": null,
                "resetsAt": null
              },
              "planType": "plus"
            }
          }
        }
        """.data(using: .utf8)!
        let now = Date(timeIntervalSince1970: 1_700_000_000)

        let usage = try CodexUsageService.parseRateLimitsResponse(response, now: now)

        XCTAssertEqual(usage.sessionUsage.percentage, 12)
        XCTAssertNil(usage.sessionWindowMinutes)
        XCTAssertGreaterThan(usage.sessionUsage.resetAt.timeIntervalSince(now), 0)
        XCTAssertEqual(usage.lastUpdated, now)
    }

    func test_rateLimitResponse_assignsShorterWindowAsSession() throws {
        let response = """
        {
          "id": 1,
          "result": {
            "rateLimits": {
              "primary": {
                "usedPercent": 40,
                "windowDurationMins": 10080,
                "resetsAt": 1788856695
              },
              "secondary": {
                "usedPercent": 7,
                "windowDurationMins": 300,
                "resetsAt": 1788378759
              },
              "planType": "team"
            }
          }
        }
        """.data(using: .utf8)!

        let usage = try CodexUsageService.parseRateLimitsResponse(response)

        XCTAssertEqual(usage.sessionUsage.percentage, 7)
        XCTAssertEqual(usage.sessionWindowMinutes, 300)
        XCTAssertEqual(usage.weeklyUsage?.percentage, 40)
        XCTAssertEqual(usage.weeklyWindowMinutes, 10080)
        XCTAssertEqual(usage.planType, "team")
    }

    func test_defaultExecutableCandidates_includePATHAndUserLocalBin() {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let candidates = CodexUsageService.defaultExecutableCandidates(
            fileManager: .default,
            path: "/tmp/codex-bin:/opt/homebrew/bin"
        )
        let paths = Set(candidates.map(\.path))

        XCTAssertTrue(paths.contains("/tmp/codex-bin/codex"))
        XCTAssertTrue(paths.contains(home.appendingPathComponent(".local/bin/codex").path))
        XCTAssertTrue(paths.contains("/Applications/ChatGPT.app/Contents/Resources/codex"))
        XCTAssertTrue(paths.contains("/opt/homebrew/bin/codex"))
    }
}
