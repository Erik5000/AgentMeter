//
//  UsageStatus.swift
//  AgentMeter
//
//  Created by Edd on 2025-11-14.
//

import SwiftUI

/// Usage status level for visual indication
enum UsageStatus: String, Codable, Sendable {
    case safe      // 0-49%
    case warning   // 50-79%
    case critical  // 80-100%

    /// SwiftUI color for this status
    var color: Color {
        switch self {
        case .safe: return Color(nsColor: .systemGreen)
        case .warning: return Color(nsColor: .systemOrange)
        case .critical: return Color(nsColor: .systemRed)
        }
    }

    /// Track behind a usage bar.
    static var trackColor: Color {
        Color.primary.opacity(0.12)
    }

    /// SF Symbol for status indicator
    var iconName: String {
        switch self {
        case .safe: return "checkmark.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .critical: return "xmark.octagon.fill"
        }
    }

    /// VoiceOver description (Principle V - Accessibility)
    var accessibilityDescription: String {
        switch self {
        case .safe: return "Safe usage level"
        case .warning: return "Warning: approaching limit"
        case .critical: return "Critical: near or at limit"
        }
    }

    /// Rank used to break ties when two limits share a percentage.
    var rank: Int {
        switch self {
        case .safe: return 0
        case .warning: return 1
        case .critical: return 2
        }
    }

    static func forPercentage(_ percentage: Double) -> UsageStatus {
        switch percentage {
        case 0..<Constants.Thresholds.Status.warningStart:
            return .safe
        case Constants.Thresholds.Status.warningStart..<Constants.Thresholds.Status.criticalStart:
            return .warning
        default:
            return .critical
        }
    }
}
