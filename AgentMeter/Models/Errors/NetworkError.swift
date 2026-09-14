//
//  NetworkError.swift
//  AgentMeter
//
//  Created by Edd on 2025-11-14.
//

import Foundation

/// Errors that can occur during network operations
enum NetworkError: LocalizedError {
    case invalidURL
    case invalidResponse
    case authenticationFailed
    case rateLimitExceeded
    case httpError(statusCode: Int)
    case decodingFailed(underlyingError: Error)
    case networkUnavailable

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Couldn't reach Claude."
        case .invalidResponse:
            return "Claude sent an unexpected response."
        case .authenticationFailed:
            return "Claude session expired. Update it in Settings."
        case .rateLimitExceeded:
            return "Too many requests. Try again in a moment."
        case .httpError(let code):
            return "Claude is unavailable (error \(code))."
        case .decodingFailed:
            return "Couldn't read usage data."
        case .networkUnavailable:
            return "No internet connection."
        }
    }
}
