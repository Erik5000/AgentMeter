//
//  UsageAPIResponse.swift
//  AgentMeter
//
//  Created by Edd on 2025-11-14.
//

import Foundation

/// API response for usage data
struct UsageAPIResponse: Codable {
    let fiveHour: UsageLimitResponse
    let sevenDay: UsageLimitResponse
    let sevenDaySonnet: UsageLimitResponse?
    let sevenDayFable: UsageLimitResponse?
    let limits: [ScopedUsageLimitResponse]?

    init(
        fiveHour: UsageLimitResponse,
        sevenDay: UsageLimitResponse,
        sevenDaySonnet: UsageLimitResponse? = nil,
        sevenDayFable: UsageLimitResponse? = nil,
        limits: [ScopedUsageLimitResponse]? = nil
    ) {
        self.fiveHour = fiveHour
        self.sevenDay = sevenDay
        self.sevenDaySonnet = sevenDaySonnet
        self.sevenDayFable = sevenDayFable
        self.limits = limits
    }

    enum CodingKeys: String, CodingKey {
        case fiveHour = "five_hour"
        case sevenDay = "seven_day"
        case sevenDaySonnet = "seven_day_sonnet"
        case sevenDayFable = "seven_day_fable"
        case limits
    }
}

/// A model-scoped usage window from the current Claude usage response.
struct ScopedUsageLimitResponse: Codable {
    let kind: String?
    let percent: Double?
    let resetsAt: String?
    let scope: Scope?

    struct Scope: Codable {
        let model: Model?
    }

    struct Model: Codable {
        let displayName: String?

        enum CodingKeys: String, CodingKey {
            case displayName = "display_name"
        }
    }

    enum CodingKeys: String, CodingKey {
        case kind
        case percent
        case resetsAt = "resets_at"
        case scope
    }
}

/// Individual usage limit response from API
struct UsageLimitResponse: Codable {
    let utilization: Double // Percentage 0-100
    let resetsAt: String? // ISO8601 string, can be null

    enum CodingKeys: String, CodingKey {
        case utilization
        case resetsAt = "resets_at"
    }
}

/// Mapping error for API response conversion
enum MappingError: LocalizedError {
    case invalidDateFormat
    case missingCriticalField(field: String)

    var errorDescription: String? {
        switch self {
        case .invalidDateFormat:
            return "Server returned invalid date format"
        case .missingCriticalField(let field):
            return "Server response missing critical field: \(field)"
        }
    }
}

/// Extension to map API response to domain model
extension UsageAPIResponse {
    func toDomain() throws -> UsageData {
        let iso8601Formatter = ISO8601DateFormatter()
        iso8601Formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        let sessionResetDate = try parseResetDate(
            from: fiveHour.resetsAt,
            field: "fiveHour.resetsAt",
            formatter: iso8601Formatter,
            fallback: Constants.Pacing.sessionWindow
        )
        let weeklyResetDate = try parseResetDate(
            from: sevenDay.resetsAt,
            field: "sevenDay.resetsAt",
            formatter: iso8601Formatter,
            fallback: Constants.Pacing.weeklyWindow
        )

        let sonnetLimit = try mapScopedWeeklyLimit(
            sevenDaySonnet ?? scopedWeeklyLimit(named: "Sonnet"),
            field: "sevenDaySonnet",
            formatter: iso8601Formatter
        )
        let fableLimit = try mapScopedWeeklyLimit(
            sevenDayFable ?? scopedWeeklyLimit(named: "Fable"),
            field: "sevenDayFable",
            formatter: iso8601Formatter
        )

        return UsageData(
            sessionUsage: UsageLimit(
                utilization: fiveHour.utilization,
                resetAt: sessionResetDate
            ),
            weeklyUsage: UsageLimit(
                utilization: sevenDay.utilization,
                resetAt: weeklyResetDate
            ),
            sonnetUsage: sonnetLimit,
            fableUsage: fableLimit,
            lastUpdated: Date()
        )
    }

    private func scopedWeeklyLimit(named modelName: String) -> UsageLimitResponse? {
        limits?.first { limit in
            limit.kind == "weekly_scoped"
                && limit.scope?.model?.displayName?.localizedCaseInsensitiveContains(modelName) == true
                && limit.percent != nil
        }.flatMap { limit in
            guard let percent = limit.percent else {
                return nil
            }
            return UsageLimitResponse(utilization: percent, resetsAt: limit.resetsAt)
        }
    }

    private func mapScopedWeeklyLimit(
        _ response: UsageLimitResponse?,
        field: String,
        formatter: ISO8601DateFormatter
    ) throws -> UsageLimit? {
        try response.map { response in
            let resetDate = try parseResetDate(
                from: response.resetsAt,
                field: "\(field).resetsAt",
                formatter: formatter,
                fallback: Constants.Pacing.weeklyWindow
            )
            return UsageLimit(
                utilization: response.utilization,
                resetAt: resetDate
            )
        }
    }

    private func parseResetDate(
        from rawValue: String?,
        field: String,
        formatter: ISO8601DateFormatter,
        fallback: TimeInterval
    ) throws -> Date {
        guard let rawValue else {
            return Date().addingTimeInterval(fallback)
        }
        if let date = formatter.date(from: rawValue) {
            return date
        }

        let formatterWithoutFractionalSeconds = ISO8601DateFormatter()
        formatterWithoutFractionalSeconds.formatOptions = [.withInternetDateTime]
        guard let date = formatterWithoutFractionalSeconds.date(from: rawValue) else {
            throw MappingError.missingCriticalField(field: field)
        }
        return date
    }
}
