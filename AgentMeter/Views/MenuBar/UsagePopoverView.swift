//
//  UsagePopoverView.swift
//  AgentMeter
//
//  Created by Edd on 2025-11-14.
//

import SwiftUI
import AppKit

private struct UsageModelGroup: Identifiable {
    let id: String
    let title: String
    let detail: String?
    let icon: String
    let metrics: [UsageWindowMetric]
}

enum UsagePopoverLayout {
    static let width: CGFloat = 430

    static func preferredHeight(groupMetricCounts: [Int], errorBannerCount: Int = 0) -> CGFloat {
        let chromeHeight: CGFloat = 94
        let contentInsets: CGFloat = 24
        let surfaceInsets: CGFloat = 28
        let groupDividerHeight = CGFloat(max(0, groupMetricCounts.count - 1)) * 21
        let groupsHeight = groupMetricCounts.reduce(CGFloat.zero) { result, metricCount in
            let metricDividerHeight = CGFloat(max(0, metricCount - 1)) * 21
            return result + 26 + CGFloat(metricCount) * 51 + metricDividerHeight
        }
        let errorHeight = CGFloat(errorBannerCount) * 82
        return max(
            320,
            chromeHeight + contentInsets + surfaceInsets + groupDividerHeight + groupsHeight + errorHeight
        )
    }
}

/// Usage popover view with detailed metrics
struct UsagePopoverView: View {
    @Bindable var appModel: AppModel
    let onRequestClose: (() -> Void)?
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        VStack(spacing: 0) {
            header
                .padding(.horizontal, 14)
                .padding(.top, 12)
                .padding(.bottom, 10)

            Divider()

            if let errorMessage = appModel.errorMessage {
                errorBanner(
                    message: errorMessage,
                    offersSessionRecovery: UsageErrorPresentation.offersSessionRecovery(errorMessage)
                )
                Divider()
            }

            if appModel.settings.isCodexUsageShown,
               let codexErrorMessage = appModel.codexErrorMessage {
                errorBanner(message: codexErrorMessage, offersSessionRecovery: false)
                Divider()
            }

            content
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

            Divider()

            footer
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
        }
        .frame(width: UsagePopoverLayout.width, height: popoverHeight)
        .background(Color(nsColor: .windowBackgroundColor))
        .accessibilityElement(children: .contain)
        .accessibilityLabel(AppIdentity.displayName)
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .center, spacing: 8) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Usage")
                    .font(.headline)

                if let lastUpdatedDate {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(isStale ? Color(nsColor: .systemOrange) : Color(nsColor: .systemGreen))
                            .frame(width: 6, height: 6)
                        Text("Updated")
                        Text(lastUpdatedDate, style: .relative)
                    }
                    .font(.caption)
                    .foregroundStyle(isStale ? Color(nsColor: .systemOrange) : Color.secondary)
                    .accessibilityLabel("Updated \(RelativeTimestamp.age(since: lastUpdatedDate))")
                } else if appModel.isLoading || appModel.isRefreshing {
                    HStack(spacing: 4) {
                        ProgressView()
                            .controlSize(.mini)
                        Text("Updating")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                } else {
                    Text(AppIdentity.displayName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Button {
                Task {
                    await appModel.refreshUsage(forceRefresh: true)
                }
            } label: {
                if appModel.isRefreshing {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Image(systemName: "arrow.clockwise")
                        .font(.body.weight(.medium))
                }
            }
            .buttonStyle(.plain)
            .padding(6)
            .background(.quaternary.opacity(0.4), in: Circle())
            .disabled(appModel.isRefreshing)
            .help("Refresh usage")
            .accessibilityLabel("Refresh usage")
            .keyboardShortcut("r", modifiers: .command)
        }
    }

    @ViewBuilder
    private var content: some View {
        if UsagePopoverContent.hasUsageContent(
            claude: appModel.usageData,
            codex: appModel.codexUsageData,
            isCodexUsageShown: appModel.settings.isCodexUsageShown
        ) {
            VStack(spacing: 0) {
                ForEach(Array(modelGroups.enumerated()), id: \.element.id) { index, group in
                    if index > 0 {
                        Divider()
                            .padding(.vertical, 10)
                    }

                    UsageComparisonCardView(
                        title: group.title,
                        detail: group.detail,
                        icon: group.icon,
                        metrics: group.metrics,
                        showsExactResetTime: appModel.settings.isResetTimeShown
                    )
                }
            }
            .padding(14)
            .background(.quaternary.opacity(0.22), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(.quaternary.opacity(0.55), lineWidth: 0.5)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
        } else if appModel.isLoading || appModel.isRefreshing {
            VStack(spacing: 10) {
                ProgressView()
                    .controlSize(.small)
                Text("Updating")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            emptyState
        }
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "chart.bar.xaxis")
                .font(.title2)
                .foregroundStyle(.tertiary)
            Text("No usage data yet")
                .font(.headline)
            Text("Refresh, or check your Claude session in Settings.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            HStack(spacing: 8) {
                Button("Refresh") {
                    Task {
                        await appModel.refreshUsage(forceRefresh: true)
                    }
                }
                .controlSize(.small)
                Button("Settings…") {
                    openSettingsFront()
                }
                .controlSize(.small)
            }
            .padding(.top, 4)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var footer: some View {
        HStack(spacing: 12) {
            Button("Settings…") {
                openSettingsFront()
            }
            .buttonStyle(.plain)
            .foregroundStyle(.primary)
            .keyboardShortcut(",", modifiers: .command)
            .accessibilityLabel("Open settings window")

            Spacer()

            MenuBarQuitButton()
        }
        .font(.callout)
    }

    private func errorBanner(message: String, offersSessionRecovery: Bool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(Color(nsColor: .systemOrange))
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }

            HStack(spacing: 8) {
                Button("Retry") {
                    Task {
                        await appModel.refreshUsage(forceRefresh: true)
                    }
                }
                .controlSize(.small)
                .buttonStyle(.bordered)

                if offersSessionRecovery {
                    Button("Update Session") {
                        openSettingsFront()
                    }
                    .controlSize(.small)
                    .buttonStyle(.borderedProminent)
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(nsColor: .systemOrange).opacity(0.12))
    }

    private var popoverHeight: CGFloat {
        let visibleErrorCount = (appModel.errorMessage == nil ? 0 : 1)
            + (appModel.settings.isCodexUsageShown && appModel.codexErrorMessage != nil ? 1 : 0)
        return UsagePopoverLayout.preferredHeight(
            groupMetricCounts: modelGroups.map(\.metrics.count),
            errorBannerCount: visibleErrorCount
        )
    }

    private var lastUpdatedDate: Date? {
        let dates = [
            appModel.usageData?.lastUpdated,
            appModel.settings.isCodexUsageShown ? appModel.codexUsageData?.lastUpdated : nil
        ].compactMap { $0 }
        return dates.min()
    }

    private var isStale: Bool {
        (appModel.usageData?.isStale ?? false)
            || (appModel.settings.isCodexUsageShown && (appModel.codexUsageData?.isStale ?? false))
    }

    private var claudePlaceholder: String {
        if appModel.errorMessage != nil {
            return "Can't load"
        }
        if appModel.usageData == nil {
            return "Updating"
        }
        return "Can't load"
    }

    private var codexPlaceholder: String {
        if appModel.codexErrorMessage != nil {
            return "Can't load"
        }
        if appModel.codexUsageData == nil {
            return "Updating"
        }
        return "Can't load"
    }

    private var modelGroups: [UsageModelGroup] {
        var groups: [UsageModelGroup] = []

        if appModel.usageData != nil || appModel.errorMessage == nil {
            groups.append(
                UsageModelGroup(
                    id: "claude",
                    title: "Claude",
                    detail: "All Models",
                    icon: "sparkles",
                    metrics: claudeMetrics
                )
            )
        }

        if appModel.settings.isFableUsageShown,
           let fableUsage = appModel.usageData?.fableUsage {
            groups.append(
                UsageModelGroup(
                    id: "claude-fable",
                    title: "Claude",
                    detail: "Fable",
                    icon: "sparkles",
                    metrics: [
                        UsageWindowMetric(
                            id: "claude-fable-weekly",
                            name: "Week",
                            icon: "calendar",
                            usageLimit: fableUsage,
                            windowDuration: Constants.Pacing.weeklyWindow,
                            usesTimeOnlyResetTimestamp: false,
                            placeholder: claudePlaceholder
                        )
                    ]
                )
            )
        }

        if appModel.settings.isSonnetUsageShown,
           let sonnetUsage = appModel.usageData?.sonnetUsage {
            groups.append(
                UsageModelGroup(
                    id: "claude-sonnet",
                    title: "Claude",
                    detail: "Sonnet",
                    icon: "sparkles",
                    metrics: [
                        UsageWindowMetric(
                            id: "claude-sonnet-weekly",
                            name: "Week",
                            icon: "calendar",
                            usageLimit: sonnetUsage,
                            windowDuration: Constants.Pacing.weeklyWindow,
                            usesTimeOnlyResetTimestamp: false,
                            placeholder: claudePlaceholder
                        )
                    ]
                )
            )
        }

        guard appModel.settings.isCodexUsageShown else {
            return groups
        }

        if let codexUsageData = appModel.codexUsageData {
            if codexUsageData.buckets.isEmpty {
                groups.append(unavailableCodexGroup(usageData: codexUsageData))
            } else {
                groups.append(contentsOf: codexUsageData.buckets.map { bucket in
                    codexGroup(for: bucket, usageData: codexUsageData)
                })
            }
        } else {
            groups.append(unavailableCodexGroup(usageData: nil))
        }

        return groups
    }

    private var claudeMetrics: [UsageWindowMetric] {
        [
            UsageWindowMetric(
                id: "claude-session",
                name: "Session",
                icon: "clock",
                usageLimit: appModel.usageData?.sessionUsage,
                windowDuration: Constants.Pacing.sessionWindow,
                usesTimeOnlyResetTimestamp: true,
                placeholder: claudePlaceholder
            ),
            UsageWindowMetric(
                id: "claude-weekly",
                name: "Week",
                icon: "calendar",
                usageLimit: appModel.usageData?.weeklyUsage,
                windowDuration: Constants.Pacing.weeklyWindow,
                usesTimeOnlyResetTimestamp: false,
                placeholder: claudePlaceholder
            )
        ]
    }

    private func codexGroup(
        for bucket: CodexUsageBucket,
        usageData: CodexUsageData
    ) -> UsageModelGroup {
        var metrics: [UsageWindowMetric] = []

        if let sessionUsage = bucket.sessionUsage {
            metrics.append(
                UsageWindowMetric(
                    id: "codex-\(bucket.id)-session",
                    name: "Session",
                    icon: "clock",
                    usageLimit: sessionUsage,
                    windowDuration: bucket.sessionWindowDuration,
                    usesTimeOnlyResetTimestamp: true,
                    placeholder: ""
                )
            )
        }

        if let longTermUsage = bucket.longTermUsage {
            metrics.append(
                UsageWindowMetric(
                    id: "codex-\(bucket.id)-long-term",
                    name: UsageWindowTitle.comparisonWeekly(codexMinutes: bucket.longTermWindowMinutes),
                    icon: "calendar",
                    usageLimit: longTermUsage,
                    windowDuration: bucket.longTermWindowDuration,
                    usesTimeOnlyResetTimestamp: false,
                    placeholder: ""
                )
            )
        }

        if metrics.isEmpty {
            metrics.append(
                UsageWindowMetric(
                    id: "codex-\(bucket.id)-unavailable",
                    name: "Usage",
                    icon: "chart.bar.xaxis",
                    usageLimit: nil,
                    windowDuration: nil,
                    usesTimeOnlyResetTimestamp: false,
                    placeholder: "No limits reported"
                )
            )
        }

        return UsageModelGroup(
            id: "codex-\(bucket.id)",
            title: "Codex",
            detail: codexDetail(for: bucket, usageData: usageData),
            icon: "chevron.left.forwardslash.chevron.right",
            metrics: metrics
        )
    }

    private func unavailableCodexGroup(usageData: CodexUsageData?) -> UsageModelGroup {
        let hasLoaded = usageData != nil
        return UsageModelGroup(
            id: "codex-unavailable",
            title: "Codex",
            detail: CodexPlanDisplay.formatted(usageData?.planType),
            icon: "chevron.left.forwardslash.chevron.right",
            metrics: [
                UsageWindowMetric(
                    id: "codex-unavailable",
                    name: "Usage",
                    icon: "chart.bar.xaxis",
                    usageLimit: nil,
                    windowDuration: nil,
                    usesTimeOnlyResetTimestamp: false,
                    placeholder: hasLoaded ? "No limits reported" : codexPlaceholder
                )
            ]
        )
    }

    private func codexDetail(
        for bucket: CodexUsageBucket,
        usageData: CodexUsageData
    ) -> String? {
        if let modeName = bucket.modeName {
            return modeName
        }
        if usageData.buckets.count > 1 {
            return "Shared"
        }
        return CodexPlanDisplay.formatted(usageData.planType)
    }

    private func openSettingsFront() {
        onRequestClose?()
        if let keyWindow = NSApp.keyWindow, keyWindow.level != .normal {
            keyWindow.orderOut(nil)
        }
        NSApp.activate(ignoringOtherApps: true)
        openSettings()
    }
}
