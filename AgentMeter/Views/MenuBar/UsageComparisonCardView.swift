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

/// A provider or model card containing each of its independently metered windows.
struct UsageComparisonCardView: View {
    let title: String
    let detail: String?
    let icon: String
    let metrics: [UsageWindowMetric]
    var showsExactResetTime: Bool = true

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            modelHeader

            VStack(spacing: 12) {
                ForEach(Array(metrics.enumerated()), id: \.element.id) { index, metric in
                    if index > 0 {
                        Divider()
                    }
                    metricRow(metric)
                }
            }
        }
        .padding(16)
        .background(.quaternary.opacity(0.28), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(.quaternary.opacity(0.6), lineWidth: 0.5)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
    }

    private var modelHeader: some View {
        HStack(spacing: 7) {
            Image(systemName: icon)
                .font(.caption.weight(.semibold))
                .foregroundStyle(accentColor)

            Text(title.uppercased())
                .font(.caption.weight(.semibold))
                .tracking(0.4)
                .foregroundStyle(.secondary)

            if let detail {
                Text(detail)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(.quaternary.opacity(0.55), in: Capsule())
            }

            Spacer(minLength: 0)
        }
    }

    @ViewBuilder
    private func metricRow(_ metric: UsageWindowMetric) -> some View {
        if let usageLimit = metric.usageLimit {
            VStack(alignment: .leading, spacing: 7) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    metricLabel(metric, color: usageLimit.status.color)

                    Spacer(minLength: 8)

                    Text("\(Int(usageLimit.percentage))%")
                        .font(.system(size: 19, weight: .semibold, design: .rounded))
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
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    metricLabel(metric, color: .secondary)

                    Spacer(minLength: 8)

                    if metric.placeholder == "Updating" {
                        ProgressView()
                            .controlSize(.mini)
                    } else {
                        Text("—")
                            .font(.system(size: 19, weight: .semibold, design: .rounded))
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

    private func metricLabel(_ metric: UsageWindowMetric, color: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: metric.icon)
                .font(.caption)
                .foregroundStyle(color)

            Text(metric.name)
                .font(.caption.weight(.semibold))
        }
    }

    private var accentColor: Color {
        metrics
            .compactMap(\.usageLimit)
            .max { $0.percentage < $1.percentage }?
            .status.color ?? .secondary
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
