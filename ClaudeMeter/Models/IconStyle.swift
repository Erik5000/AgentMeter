//
//  IconStyle.swift
//  ClaudeMeter
//
//  Created by Edd on 2025-12-28.
//

import Foundation

/// Menu bar icon display style
enum IconStyle: String, Codable, CaseIterable, Identifiable, Sendable {
    case battery        // Gradient bar + percentage (DEFAULT)
    case circular       // Donut gauge with percentage in center
    case minimal        // Just color-coded percentage text
    case segments       // 5 segments like signal bars
    case dualBar        // Two stacked bars: session + weekly
    case gauge          // SF Symbol gauge icon

    var id: String { rawValue }

    /// Display name for settings UI
    var displayName: String {
        switch self {
        case .battery: return "Battery"
        case .circular: return "Circular"
        case .minimal: return "Minimal"
        case .segments: return "Segments"
        case .dualBar: return "Dual Bar"
        case .gauge: return "Gauge"
        }
    }

    /// Description for accessibility
    var accessibilityDescription: String {
        switch self {
        case .battery: return "Battery-style bar with percentage"
        case .circular: return "Circular gauge with percentage in center"
        case .minimal: return "Minimal percentage only"
        case .segments: return "Segmented bar indicator"
        case .dualBar: return "Session and weekly bars; Codex adds a second column"
        case .gauge: return "Gauge indicator"
        }
    }

    /// Icon style is forced to Dual Bar while Codex usage is shown, so the picker is inert.
    static func isPickerEnabled(isCodexUsageShown: Bool) -> Bool {
        !isCodexUsageShown
    }

    static let dualBarRequiredForCodexCaption =
        "Dual Bar is used while Codex usage is on so Claude and Codex can be shown together."
}
