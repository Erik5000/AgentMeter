//
//  UsageCardView.swift
//  ClaudeMeter
//
//  Created by Edd on 2025-11-14.
//

import SwiftUI

/// Reusable usage card component
struct UsageCardView: View {
    let title: String
    let usageLimit: UsageLimit
    let windowDuration: TimeInterval?

    /// Whether to append the exact reset time.
    var showsExactResetTime: Bool = true

    /// When true, the exact reset time shows the time of day only (no date).
    var usesTimeOnlyResetTimestamp: Bool = false

    private var resetLabel: String {
        usageLimit.resetCaption(
            showsExactTime: showsExactResetTime,
            usesTimeOnly: usesTimeOnlyResetTimestamp,
            compact: false
        )
    }

    private var isAtRisk: Bool {
        guard let windowDuration else { return false }
        return usageLimit.isAtRisk(windowDuration: windowDuration)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)

            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("\(Int(usageLimit.percentage))%")
                    .font(.system(size: 28, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(usageLimit.status.color)

                Spacer(minLength: 8)

                if isAtRisk {
                    UsagePacingIndicator()
                }
            }

            UsageMeterProgressBar(
                percentage: usageLimit.percentage,
                color: usageLimit.status.color
            )

            Text(resetLabel)
                .font(.caption)
                .foregroundStyle(.secondary)
                .help(usageLimit.resetTimeFormatted)
        }
        .padding(14)
        .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title): \(Int(usageLimit.percentage))% used, \(usageLimit.status.accessibilityDescription)")
        .accessibilityValue(resetLabel)
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 12) {
        UsageCardView(
            title: "5-Hour Session",
            usageLimit: UsageLimit(
                utilization: 35.0,
                resetAt: Date().addingTimeInterval(7200)
            ),
            windowDuration: Constants.Pacing.sessionWindow
        )

        UsageCardView(
            title: "Weekly Usage",
            usageLimit: UsageLimit(
                utilization: 75.0,
                resetAt: Date().addingTimeInterval(86400 * 3)
            ),
            windowDuration: Constants.Pacing.weeklyWindow
        )
    }
    .padding()
    .frame(width: 332)
}
