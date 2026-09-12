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
    let icon: String
    let metrics: [UsageProviderMetric]
    var showsExactResetTime: Bool = true

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(.secondary)
                Text(title)
                    .font(.headline)
            }

            HStack(alignment: .top, spacing: 0) {
                ForEach(Array(metrics.enumerated()), id: \.element.id) { index, metric in
                    if index > 0 {
                        Divider()
                            .padding(.horizontal, 12)
                    }
                    providerColumn(metric)
                }
            }
        }
        .padding(16)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(12)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
    }

    @ViewBuilder
    private func providerColumn(_ metric: UsageProviderMetric) -> some View {
        if let usageLimit = metric.usageLimit {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: metric.icon)
                        .foregroundStyle(usageLimit.status.color)
                    Text(metric.name)
                        .font(.subheadline.weight(.semibold))
                    if let detail = metric.detail {
                        Text(detail)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 0)
                }

                Text("\(Int(usageLimit.percentage))%")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(usageLimit.status.color)

                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.gray.opacity(0.2))
                        RoundedRectangle(cornerRadius: 4)
                            .fill(usageLimit.status.color)
                            .frame(width: geometry.size.width * min(usageLimit.percentage / 100, 1.0))
                    }
                }
                .frame(height: 6)

                HStack(spacing: 4) {
                    Image(systemName: "clock")
                        .font(.caption2)
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Resets \(usageLimit.compactResetDescription)")
                        if showsExactResetTime {
                            Text(metric.usesTimeOnlyResetTimestamp
                                 ? usageLimit.resetTimeOnlyFormatted
                                 : usageLimit.resetTimeFormatted)
                        }
                    }
                    .font(.caption)
                    Spacer(minLength: 0)
                    if let windowDuration = metric.windowDuration,
                       usageLimit.isAtRisk(windowDuration: windowDuration) {
                        Image(systemName: "flame.fill")
                            .font(.caption)
                            .foregroundStyle(.orange)
                            .help("You may hit your limit before it resets")
                            .accessibilityLabel("At risk of hitting limit")
                    }
                }
                .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: metric.icon)
                        .foregroundStyle(.secondary)
                    Text(metric.name)
                        .font(.subheadline.weight(.semibold))
                    Spacer(minLength: 0)
                }

                if metric.placeholder == "Loading…" {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Image(systemName: "minus.circle")
                        .foregroundStyle(.secondary)
                }

                Text(metric.placeholder)
                    .font(.caption)
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
