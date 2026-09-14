//
//  UsagePopoverView.swift
//  ClaudeMeter
//
//  Created by Edd on 2025-11-14.
//

import SwiftUI
import AppKit

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
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            Divider()

            footer
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
        }
        .frame(width: appModel.settings.isCodexUsageShown ? 392 : 332, height: popoverHeight)
        .background(Color(nsColor: .windowBackgroundColor))
        .accessibilityElement(children: .contain)
        .accessibilityLabel(AppIdentity.displayName)
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .center, spacing: 8) {
            VStack(alignment: .leading, spacing: 1) {
                if let lastUpdatedDate {
                    HStack(spacing: 4) {
                        Text("Updated")
                        Text(lastUpdatedDate, style: .relative)
                    }
                    .font(.caption)
                    .foregroundStyle(isStale ? Color(nsColor: .systemOrange) : Color.secondary)
                    .accessibilityLabel("Updated \(RelativeTimestamp.age(since: lastUpdatedDate))")
                } else if appModel.isLoading || appModel.isRefreshing {
                    Text("Updating")
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
            ScrollView {
                VStack(spacing: 10) {
                    if appModel.settings.isCodexUsageShown {
                        UsageComparisonCardView(
                            title: UsageWindowTitle.comparisonSession(),
                            metrics: sessionMetrics(),
                            showsExactResetTime: appModel.settings.isResetTimeShown
                        )

                        UsageComparisonCardView(
                            title: UsageWindowTitle.comparisonWeekly(
                                codexMinutes: appModel.codexUsageData?.weeklyWindowMinutes
                            ),
                            metrics: weeklyMetrics(),
                            showsExactResetTime: appModel.settings.isResetTimeShown
                        )
                    } else if let usageData = appModel.usageData {
                        UsageCardView(
                            title: UsageWindowTitle.session(),
                            usageLimit: usageData.sessionUsage,
                            windowDuration: Constants.Pacing.sessionWindow,
                            showsExactResetTime: appModel.settings.isResetTimeShown,
                            usesTimeOnlyResetTimestamp: true
                        )

                        UsageCardView(
                            title: UsageWindowTitle.weekly(),
                            usageLimit: usageData.weeklyUsage,
                            windowDuration: Constants.Pacing.weeklyWindow,
                            showsExactResetTime: appModel.settings.isResetTimeShown
                        )
                    }

                    if appModel.settings.isSonnetUsageShown, let sonnetUsage = appModel.usageData?.sonnetUsage {
                        UsageCardView(
                            title: "Weekly Sonnet",
                            usageLimit: sonnetUsage,
                            windowDuration: Constants.Pacing.weeklyWindow,
                            showsExactResetTime: appModel.settings.isResetTimeShown
                        )
                    }
                }
                .padding(14)
            }
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

            Button("Quit \(AppIdentity.displayName)") {
                NSApplication.shared.terminate(nil)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .keyboardShortcut("q", modifiers: .command)
            .accessibilityLabel("Quit \(AppIdentity.displayName)")
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
        if appModel.settings.isSonnetUsageShown, appModel.usageData?.sonnetUsage != nil {
            return 500
        }
        return 440
    }

    private var lastUpdatedDate: Date? {
        let dates = [
            appModel.usageData?.lastUpdated,
            appModel.settings.isCodexUsageShown ? appModel.codexUsageData?.lastUpdated : nil
        ].compactMap { $0 }
        return dates.max()
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

    private func sessionMetrics() -> [UsageProviderMetric] {
        var metrics = [
            UsageProviderMetric(
                id: "claude-session",
                name: "Claude",
                detail: nil,
                icon: "sparkles",
                usageLimit: appModel.usageData?.sessionUsage,
                windowDuration: Constants.Pacing.sessionWindow,
                usesTimeOnlyResetTimestamp: true,
                placeholder: claudePlaceholder
            )
        ]

        if appModel.settings.isCodexUsageShown {
            metrics.append(
                UsageProviderMetric(
                    id: "codex-session",
                    name: "Codex",
                    detail: CodexPlanDisplay.formatted(appModel.codexUsageData?.planType),
                    icon: "chevron.left.forwardslash.chevron.right",
                    usageLimit: appModel.codexUsageData?.sessionUsage,
                    windowDuration: appModel.codexUsageData?.sessionWindowDuration,
                    usesTimeOnlyResetTimestamp: true,
                    placeholder: codexPlaceholder
                )
            )
        }

        return metrics
    }

    private func weeklyMetrics() -> [UsageProviderMetric] {
        var metrics = [
            UsageProviderMetric(
                id: "claude-weekly",
                name: "Claude",
                detail: nil,
                icon: "sparkles",
                usageLimit: appModel.usageData?.weeklyUsage,
                windowDuration: Constants.Pacing.weeklyWindow,
                usesTimeOnlyResetTimestamp: false,
                placeholder: claudePlaceholder
            )
        ]

        if appModel.settings.isCodexUsageShown {
            metrics.append(
                UsageProviderMetric(
                    id: "codex-weekly",
                    name: "Codex",
                    detail: nil,
                    icon: "chevron.left.forwardslash.chevron.right",
                    usageLimit: appModel.codexUsageData?.weeklyUsage,
                    windowDuration: appModel.codexUsageData?.weeklyWindowDuration,
                    usesTimeOnlyResetTimestamp: false,
                    placeholder: codexPlaceholder
                )
            )
        }

        return metrics
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
