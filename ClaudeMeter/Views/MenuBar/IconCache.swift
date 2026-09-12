//
//  IconCache.swift
//  ClaudeMeter
//
//  Created by Edd on 2026-01-09.
//

import AppKit

/// Simple in-memory cache for rendered menu bar icons.
final class IconCache {
    private let cache = NSCache<NSString, NSImage>()

    init() {
        cache.countLimit = Constants.Cache.maxIconCacheSize
    }

    func get(
        percentage: Double,
        status: UsageStatus,
        isLoading: Bool,
        isStale: Bool,
        iconStyle: IconStyle,
        weeklyPercentage: Double,
        isColored: Bool,
        showsCodex: Bool = false,
        claudeSession: Double = 0,
        claudeWeekly: Double = 0,
        codexSession: Double = 0,
        codexWeekly: Double = 0
    ) -> NSImage? {
        cache.object(forKey: cacheKey(
            percentage: percentage,
            status: status,
            isLoading: isLoading,
            isStale: isStale,
            iconStyle: iconStyle,
            weeklyPercentage: weeklyPercentage,
            isColored: isColored,
            showsCodex: showsCodex,
            claudeSession: claudeSession,
            claudeWeekly: claudeWeekly,
            codexSession: codexSession,
            codexWeekly: codexWeekly
        ))
    }

    func set(
        _ image: NSImage,
        percentage: Double,
        status: UsageStatus,
        isLoading: Bool,
        isStale: Bool,
        iconStyle: IconStyle,
        weeklyPercentage: Double,
        isColored: Bool,
        showsCodex: Bool = false,
        claudeSession: Double = 0,
        claudeWeekly: Double = 0,
        codexSession: Double = 0,
        codexWeekly: Double = 0
    ) {
        cache.setObject(
            image,
            forKey: cacheKey(
                percentage: percentage,
                status: status,
                isLoading: isLoading,
                isStale: isStale,
                iconStyle: iconStyle,
                weeklyPercentage: weeklyPercentage,
                isColored: isColored,
                showsCodex: showsCodex,
                claudeSession: claudeSession,
                claudeWeekly: claudeWeekly,
                codexSession: codexSession,
                codexWeekly: codexWeekly
            )
        )
    }

    private func cacheKey(
        percentage: Double,
        status: UsageStatus,
        isLoading: Bool,
        isStale: Bool,
        iconStyle: IconStyle,
        weeklyPercentage: Double,
        isColored: Bool,
        showsCodex: Bool,
        claudeSession: Double,
        claudeWeekly: Double,
        codexSession: Double,
        codexWeekly: Double
    ) -> NSString {
        let percent = String(format: "%.2f", percentage)
        let weekly = String(format: "%.2f", weeklyPercentage)
        let claudeSessionValue = String(format: "%.2f", claudeSession)
        let claudeWeeklyValue = String(format: "%.2f", claudeWeekly)
        let codexSessionValue = String(format: "%.2f", codexSession)
        let codexWeeklyValue = String(format: "%.2f", codexWeekly)
        return "\(percent)|\(weekly)|\(status.rawValue)|\(isLoading)|\(isStale)|\(iconStyle.rawValue)|\(isColored)|\(showsCodex)|\(claudeSessionValue)|\(claudeWeeklyValue)|\(codexSessionValue)|\(codexWeeklyValue)" as NSString
    }
}
