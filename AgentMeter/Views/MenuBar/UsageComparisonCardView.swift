import SwiftUI

struct UsageWindowMetric: Identifiable {
    let id: String
    let name: String
    let icon: String
    let usageLimit: UsageLimit?
    let windowDuration: TimeInterval?
    let usesTimeOnlyResetTimestamp: Bool
    let placeholder: String
}

/// A compact provider/model section containing each independently metered window.
struct UsageComparisonCardView: View {
    let title: String
    let detail: String?
    let icon: String
    let metrics: [UsageWindowMetric]
    var showsExactResetTime: Bool = true

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            modelHeader

            VStack(spacing: 0) {
                ForEach(Array(metrics.enumerated()), id: \.element.id) { index, metric in
                    if index > 0 {
                        Divider()
                            .padding(.vertical, 10)
                    }
                    metricRow(metric)
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
    }

    private var modelHeader: some View {
        HStack(spacing: 7) {
            Image(systemName: icon)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            Text(title.uppercased())
                .font(.caption.weight(.semibold))
                .tracking(0.4)
                .foregroundStyle(.secondary)

            if let detail {
                Text("·")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                Text(detail.uppercased())
                    .font(.caption.weight(.semibold))
                    .tracking(0.4)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)
        }
    }

    @ViewBuilder
    private func metricRow(_ metric: UsageWindowMetric) -> some View {
        if let usageLimit = metric.usageLimit {
            VStack(alignment: .leading, spacing: 5) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    metricLabel(metric)

                    Spacer(minLength: 8)

                    Text("\(Int(usageLimit.percentage))%")
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(usageLimit.status.color)
                }

                UsageMeterProgressBar(
                    percentage: usageLimit.percentage,
                    color: usageLimit.status.color,
                    height: 4
                )

                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(
                        usageLimit.resetCaption(
                            showsExactTime: showsExactResetTime,
                            usesTimeOnly: metric.usesTimeOnlyResetTimestamp,
                            compact: true
                        )
                    )
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                    Spacer(minLength: 0)

                    if let windowDuration = metric.windowDuration,
                       usageLimit.isAtRisk(windowDuration: windowDuration) {
                        UsagePacingIndicator(compact: true)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            VStack(alignment: .leading, spacing: 5) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    metricLabel(metric)

                    Spacer(minLength: 8)

                    if metric.placeholder == "Updating" {
                        ProgressView()
                            .controlSize(.mini)
                    } else {
                        Text("—")
                            .font(.system(size: 18, weight: .semibold, design: .rounded))
                            .foregroundStyle(.tertiary)
                    }
                }

                Text(metric.placeholder)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func metricLabel(_ metric: UsageWindowMetric) -> some View {
        HStack(spacing: 6) {
            Image(systemName: metric.icon)
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(metric.name)
                .font(.caption.weight(.semibold))
        }
    }

    private var accessibilityLabel: String {
        let modelName = [title, detail]
            .compactMap { $0 }
            .joined(separator: " ")
        let parts = metrics.map { metric in
            if let usageLimit = metric.usageLimit {
                return "\(metric.name) \(Int(usageLimit.percentage)) percent"
            }
            return "\(metric.name) \(metric.placeholder)"
        }
        return "\(modelName): \(parts.joined(separator: ", "))"
    }
}
