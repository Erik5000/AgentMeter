//
//  DualBarIcon.swift
//  ClaudeMeter
//
//  Created by Edd on 2025-12-28.
//

import SwiftUI

/// Dual bar menu bar icon showing session (top) and weekly (bottom) usage.
/// When Codex is enabled, Claude is the left column and Codex is the right column.
struct DualBarIcon: View {
    let percentage: Double
    let weeklyPercentage: Double
    let status: UsageStatus
    let isLoading: Bool
    let isStale: Bool
    var showsCodex: Bool = false
    var claudeSession: Double? = nil
    var claudeWeekly: Double? = nil
    var codexSession: Double? = nil
    var codexWeekly: Double? = nil

    private let singleBarWidth: CGFloat = 32
    private let pairedBarWidth: CGFloat = 16
    private let barHeight: CGFloat = 5
    private let barSpacing: CGFloat = 2

    var body: some View {
        HStack(spacing: 4) {
            if isLoading {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(statusColor)
            } else if showsCodex {
                VStack(alignment: .leading, spacing: barSpacing) {
                    metricRow(claude: claudeSession, codex: codexSession)
                    metricRow(claude: claudeWeekly, codex: codexWeekly)
                }
            } else {
                VStack(spacing: barSpacing) {
                    ProgressBar(
                        percentage: sessionBarValue,
                        color: barColor(for: sessionBarValue),
                        isStale: isStale
                    )
                    .frame(width: singleBarWidth, height: barHeight)

                    ProgressBar(
                        percentage: weeklyBarValue,
                        color: isStale ? .gray : .purple,
                        isStale: isStale
                    )
                    .frame(width: singleBarWidth, height: barHeight)
                }

                Text("\(Int(percentage))%")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundColor(statusColor)
            }

            if isStale && !isLoading {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 8))
                    .foregroundColor(.gray)
            }
        }
        .frame(height: 22)
        .padding(.horizontal, 4)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityValue(status.accessibilityDescription)
    }

    private func metricRow(claude: Double?, codex: Double?) -> some View {
        HStack(spacing: 3) {
            ProgressBar(
                percentage: claude ?? 0,
                color: barColor(for: claude),
                isStale: isStale
            )
            .frame(width: pairedBarWidth, height: barHeight)

            compactPercent(claude)

            ProgressBar(
                percentage: codex ?? 0,
                color: barColor(for: codex),
                isStale: isStale
            )
            .frame(width: pairedBarWidth, height: barHeight)

            compactPercent(codex)
        }
    }

    private func compactPercent(_ value: Double?) -> some View {
        Group {
            if let value {
                Text("\(Int(value))%")
                    .foregroundColor(isStale ? .gray : UsageStatus.forPercentage(value).color)
            } else {
                Text("—")
                    .foregroundColor(.gray)
            }
        }
        .font(.system(size: 8, weight: .medium, design: .monospaced))
        .frame(minWidth: 22, alignment: .leading)
    }

    private var statusColor: Color {
        isStale ? .gray : status.color
    }

    private var sessionBarValue: Double {
        claudeSession ?? percentage
    }

    private var weeklyBarValue: Double {
        claudeWeekly ?? weeklyPercentage
    }

    private func barColor(for value: Double?) -> Color {
        guard let value else {
            return Color.gray.opacity(0.35)
        }
        return isStale ? .gray : UsageStatus.forPercentage(value).color
    }

    private var accessibilityLabel: String {
        if showsCodex {
            return "Claude session \(percentLabel(claudeSession)), Codex session \(percentLabel(codexSession)), Claude weekly \(percentLabel(claudeWeekly)), Codex weekly \(percentLabel(codexWeekly))"
        }
        return "Session \(Int(sessionBarValue)) percent, weekly \(Int(weeklyBarValue)) percent, showing \(Int(percentage)) percent"
    }

    private func percentLabel(_ value: Double?) -> String {
        guard let value else { return "unavailable" }
        return "\(Int(value)) percent"
    }
}

/// Individual progress bar component
private struct ProgressBar: View {
    let percentage: Double
    let color: Color
    let isStale: Bool

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(Color.gray.opacity(0.3))

                RoundedRectangle(cornerRadius: 1.5)
                    .fill(color)
                    .frame(width: geo.size.width * min(max(percentage, 0) / 100, 1.0))
            }
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        HStack(spacing: 20) {
            DualBarIcon(percentage: 35, weeklyPercentage: 20, status: .safe, isLoading: false, isStale: false)
            DualBarIcon(percentage: 65, weeklyPercentage: 45, status: .warning, isLoading: false, isStale: false)
            DualBarIcon(percentage: 92, weeklyPercentage: 78, status: .critical, isLoading: false, isStale: false)
        }
        DualBarIcon(
            percentage: 62,
            weeklyPercentage: 62,
            status: .warning,
            isLoading: false,
            isStale: false,
            showsCodex: true,
            claudeSession: 1,
            claudeWeekly: 62,
            codexSession: 13,
            codexWeekly: 24
        )
    }
    .padding()
}
