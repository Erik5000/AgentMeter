//
//  MenuBarIconRenderer.swift
//  ClaudeMeter
//
//  Created by Edd on 2026-01-09.
//

import AppKit
import SwiftUI

/// Renders SwiftUI MenuBarIconView to NSImage using ImageRenderer.
@MainActor
struct MenuBarIconRenderer {
    func render(
        percentage: Double,
        status: UsageStatus,
        isLoading: Bool,
        isStale: Bool,
        iconStyle: IconStyle,
        weeklyPercentage: Double = 0,
        isColored: Bool = true,
        showsCodex: Bool = false,
        claudeSession: Double = 0,
        claudeWeekly: Double = 0,
        codexSession: Double = 0,
        codexWeekly: Double = 0
    ) -> NSImage {
        let iconView = MenuBarIconView(
            percentage: percentage,
            status: status,
            isLoading: isLoading,
            isStale: isStale,
            iconStyle: iconStyle,
            weeklyPercentage: weeklyPercentage,
            showsCodex: showsCodex,
            claudeSession: claudeSession,
            claudeWeekly: claudeWeekly,
            codexSession: codexSession,
            codexWeekly: codexWeekly
        )

        let renderer = ImageRenderer(content: iconView)
        renderer.scale = NSScreen.main?.backingScaleFactor ?? 2.0

        guard let nsImage = renderer.nsImage else {
            return NSImage(
                systemSymbolName: "exclamationmark.triangle",
                accessibilityDescription: "Error"
            ) ?? NSImage()
        }

        nsImage.isTemplate = !isColored
        return nsImage
    }
}
