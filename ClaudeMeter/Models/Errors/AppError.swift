//
//  AppError.swift
//  ClaudeMeter
//
//  Created by Edd on 2025-11-14.
//

import Foundation

/// Application-level errors with user-facing messages
enum AppError: LocalizedError {
    case noSessionKey
    case networkError(NetworkError)
    case keychainError(KeychainError)
    case sessionKeyInvalid
    case apiResponseInvalid
    case organizationNotFound
    case cacheCorrupted

    var errorDescription: String? {
        switch self {
        case .noSessionKey:
            return "Add a Claude session to start tracking."
        case .networkError(let error):
            return error.localizedDescription
        case .keychainError(let error):
            return error.localizedDescription
        case .sessionKeyInvalid:
            return "Claude session expired. Update it in Settings."
        case .apiResponseInvalid:
            return "Couldn't read usage data. Try refreshing."
        case .organizationNotFound:
            return "No Claude organizations found for this account."
        case .cacheCorrupted:
            return "Cached data was unreadable. Fetching a fresh copy…"
        }
    }

    /// Whether error is recoverable without user action
    var isRecoverable: Bool {
        switch self {
        case .networkError, .cacheCorrupted, .apiResponseInvalid:
            return true
        case .noSessionKey, .sessionKeyInvalid, .organizationNotFound, .keychainError:
            return false
        }
    }

    /// User action to resolve error
    var recoveryAction: String? {
        switch self {
        case .noSessionKey:
            return "Complete Setup"
        case .sessionKeyInvalid:
            return "Update Session Key"
        case .networkError:
            return "Retry"
        case .organizationNotFound:
            return "Check Account"
        default:
            return nil
        }
    }
}
