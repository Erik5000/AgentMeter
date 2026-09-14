//
//  BatteryIcon.swift
//  AgentMeter
//
//  Created by Edd on 2025-12-28.
//

import SwiftUI

/// Battery-style menu bar icon with a status-colored fill
struct BatteryIcon: View {
    let percentage: Double
    let status: UsageStatus
    let isLoading: Bool
    let isStale: Bool

    private let capsuleWidth: CGFloat = 28
    private let capsuleHeight: CGFloat = 10

    var body: some View {
        HStack(spacing: 4) {
            if isLoading {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(statusColor)
            } else {
                Capsule()
                    .fill(Color.gray.opacity(0.3))
                    .overlay(alignment: .leading) {
                        GeometryReader { geo in
                            Capsule()
                                .fill(statusColor)
                                .frame(width: geo.size.width * min(max(percentage, 0) / 100, 1.0))
                        }
                        .clipShape(Capsule())
                    }
                    .frame(width: capsuleWidth, height: capsuleHeight)

                Text("\(Int(percentage))%")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .monospacedDigit()
                    .foregroundStyle(statusColor)
            }

            if isStale && !isLoading {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 8))
                    .foregroundStyle(.gray)
            }
        }
        .frame(height: 22)
        .padding(.horizontal, 4)
        .accessibilityLabel("Usage: \(Int(percentage)) percent")
        .accessibilityValue(status.accessibilityDescription)
    }

    private var statusColor: Color {
        isStale ? .gray : status.color
    }
}

#Preview {
    HStack(spacing: 20) {
        BatteryIcon(percentage: 25, status: .safe, isLoading: false, isStale: false)
        BatteryIcon(percentage: 50, status: .warning, isLoading: false, isStale: false)
        BatteryIcon(percentage: 75, status: .warning, isLoading: false, isStale: false)
        BatteryIcon(percentage: 95, status: .critical, isLoading: false, isStale: false)
        BatteryIcon(percentage: 45, status: .safe, isLoading: true, isStale: false)
        BatteryIcon(percentage: 45, status: .safe, isLoading: false, isStale: true)
    }
    .padding()
}
