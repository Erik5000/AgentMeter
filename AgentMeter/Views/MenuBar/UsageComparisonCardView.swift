import SwiftUI

struct UsageProviderMetric: Identifiable {
    let id: String
    let name: String
    let detail: String?
    let icon: String
    let usageLimit: UsageLimit?
    let windowDuration: TimeInterval?
    let usesTimeOnlyResetTimestamp: Bool
    let placeholder: String
}

/// Side-by-side comparison of the same usage window across providers.
struct UsageComparisonCardView: View {
    let title: String
    let metrics: [UsageProviderMetric]
    var showsExactResetTime: Bool = true

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.subheadline.weight(.semibold))

            HStack(alignment: .top, spacing: 0) {
                ForEach(Array(metrics.enumerated()), id: \.element.id) { index, metric in
                    if index > 0 {
                        Divider()
                            .padding(.horizontal, 10)
                    }
                    providerColumn(metric)
                }
            }
        }
        .padding(14)
        .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
    }

    @ViewBuilder
    private func providerColumn(_ metric: UsageProviderMetric) -> some View {
        if let usageLimit = metric.usageLimit {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 5) {
                    Image(systemName: metric.icon)
                        .font(.caption)
                        .foregroundStyle(usageLimit.status.color)
                    Text(metric.name)
                        .font(.caption.weight(.semibold))
                    Spacer(minLength: 0)
                    if let detail = metric.detail {
                        Text(detail)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }

                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("\(Int(usageLimit.percentage))%")
                        .font(.system(size: 22, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(usageLimit.status.color)

                    Spacer(minLength: 0)

                    if let windowDuration = metric.windowDuration,
                       usageLimit.isAtRisk(windowDuration: windowDuration) {
                        UsagePacingIndicator(compact: true)
                    }
                }

                UsageMeterProgressBar(
                    percentage: usageLimit.percentage,
                    color: usageLimit.status.color,
                    height: 4
                )

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
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 5) {
                    Image(systemName: metric.icon)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                    Text(metric.name)
                        .font(.caption.weight(.semibold))
                    Spacer(minLength: 0)
                }

                if metric.placeholder == "Updating" {
                    ProgressView()
                        .controlSize(.mini)
                        .padding(.top, 6)
                } else {
                    Text("—")
                        .font(.system(size: 22, weight: .semibold, design: .rounded))
                        .foregroundStyle(.tertiary)
                }

                Text(metric.placeholder)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var accessibilityLabel: String {
        let parts = metrics.map { metric in
            if let usageLimit = metric.usageLimit {
                return "\(metric.name) \(Int(usageLimit.percentage)) percent"
            }
            return "\(metric.name) \(metric.placeholder)"
        }
        return "\(title): \(parts.joined(separator: ", "))"
    }
}
