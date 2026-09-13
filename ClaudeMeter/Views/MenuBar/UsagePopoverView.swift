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
            HStack {
                Text("Usage")
                    .font(.title2)
                    .fontWeight(.bold)

                Spacer()

                Button(action: {
                    Task {
                        await appModel.refreshUsage(forceRefresh: true)
                    }
                }) {
                    if appModel.isRefreshing {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Image(systemName: "arrow.clockwise")
                    }
                }
                .buttonStyle(.plain)
                .disabled(appModel.isRefreshing)
                .help("Refresh usage data")
                .keyboardShortcut("r", modifiers: .command)
            }
            .padding()

            Divider()

            if let errorMessage = appModel.errorMessage {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                        Text(errorMessage)
                            .font(.callout)
                            .foregroundColor(.primary)

                        Spacer()
                    }

                    HStack(spacing: 8) {
                        Button("Retry") {
                            Task {
                                await appModel.refreshUsage(forceRefresh: true)
                            }
                        }
                        .buttonStyle(.bordered)

                        if errorMessage.contains("invalid") || errorMessage.contains("expired") || errorMessage.contains("authentication") {
                            Button("Update Session Key") {
                                openSettingsFront()
                            }
                            .buttonStyle(.borderedProminent)
                        }
                    }
                }
                .padding()
                .background(Color.orange.opacity(0.1))

                Divider()
            }

            if UsagePopoverContent.hasUsageContent(
                claude: appModel.usageData,
                codex: appModel.codexUsageData,
                isCodexUsageShown: appModel.settings.isCodexUsageShown
            ) {
                ScrollView {
                    VStack(spacing: appModel.settings.isCodexUsageShown ? 12 : 16) {
                        if appModel.settings.isCodexUsageShown,
                           let codexErrorMessage = appModel.codexErrorMessage {
                            Label(codexErrorMessage, systemImage: "exclamationmark.triangle.fill")
                                .font(.caption)
                                .foregroundStyle(.orange)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }

                        if appModel.settings.isCodexUsageShown {
                            UsageComparisonCardView(
                                title: UsageWindowTitle.session(
                                    codexMinutes: appModel.codexUsageData?.sessionWindowMinutes
                                ),
                                icon: "clock.arrow.circlepath",
                                metrics: sessionMetrics(),
                                showsExactResetTime: appModel.settings.isResetTimeShown
                            )

                            UsageComparisonCardView(
                                title: UsageWindowTitle.weekly(
                                    codexMinutes: appModel.codexUsageData?.weeklyWindowMinutes
                                ),
                                icon: "calendar",
                                metrics: weeklyMetrics(),
                                showsExactResetTime: appModel.settings.isResetTimeShown
                            )
                        } else if let usageData = appModel.usageData {
                            UsageCardView(
                                title: UsageWindowTitle.session(),
                                usageLimit: usageData.sessionUsage,
                                icon: "gauge.with.dots.needle.67percent",
                                windowDuration: Constants.Pacing.sessionWindow,
                                showsExactResetTime: appModel.settings.isResetTimeShown,
                                usesTimeOnlyResetTimestamp: true
                            )

                            UsageCardView(
                                title: UsageWindowTitle.weekly(),
                                usageLimit: usageData.weeklyUsage,
                                icon: "calendar",
                                windowDuration: Constants.Pacing.weeklyWindow,
                                showsExactResetTime: appModel.settings.isResetTimeShown
                            )
                        }

                        if appModel.settings.isSonnetUsageShown, let sonnetUsage = appModel.usageData?.sonnetUsage {
                            UsageCardView(
                                title: "Weekly Sonnet",
                                usageLimit: sonnetUsage,
                                icon: "sparkles",
                                windowDuration: Constants.Pacing.weeklyWindow,
                                showsExactResetTime: appModel.settings.isResetTimeShown
                            )
                        }
                    }
                    .padding()
                }
            } else if appModel.isLoading || appModel.isRefreshing {
                VStack(spacing: 16) {
                    ProgressView()
                    Text("Loading usage data...")
                        .font(.callout)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
            } else {
                Spacer(minLength: 0)
            }

            Divider()

            HStack {
                Button("Settings") {
                    openSettingsFront()
                }
                .buttonStyle(.plain)
                .keyboardShortcut(",", modifiers: .command)
                .accessibilityLabel("Open settings window")

                Spacer()

                Button("Quit") {
                    NSApplication.shared.terminate(nil)
                }
                .buttonStyle(.plain)
                .keyboardShortcut("q", modifiers: .command)
                .accessibilityLabel("Quit application")
            }
            .padding()
        }
        .frame(width: appModel.settings.isCodexUsageShown ? 380 : 320, height: 460)
        .background(Color(nsColor: .windowBackgroundColor))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Usage Dashboard")
    }

    private var claudePlaceholder: String {
        if appModel.errorMessage != nil {
            return "Unavailable"
        }
        if appModel.usageData == nil {
            return "Loading…"
        }
        return "Unavailable"
    }

    private var codexPlaceholder: String {
        if appModel.codexErrorMessage != nil {
            return "Unavailable"
        }
        if appModel.codexUsageData == nil {
            return "Loading…"
        }
        return "Unavailable"
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
                    icon: "terminal",
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
                    detail: CodexPlanDisplay.formatted(appModel.codexUsageData?.planType),
                    icon: "terminal",
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
