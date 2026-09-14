import SwiftUI
import ServiceManagement
import AppKit

struct SettingsView: View {
    @Bindable var appModel: AppModel

    @State private var sessionKey: String = ""
    @State private var isSessionKeyShown: Bool = false
    @State private var isValidatingSessionKey: Bool = false
    @State private var isImportingSessionKey: Bool = false
    @State private var sessionKeyValidationMessage: String?
    @State private var offersFullDiskAccessSettings: Bool = false
    @State private var hasSessionKeyValidationSucceeded: Bool = false

    @State private var isSendingTestNotification: Bool = false
    @State private var testNotificationMessage: String?
    @State private var hasTestNotificationSucceeded: Bool = false
    @State private var notificationError: String?

    @State private var launchAtLogin: Bool = SMAppService.mainApp.status == .enabled

    var body: some View {
        TabView {
            generalTab
                .tabItem { Label("General", systemImage: "gearshape") }
            notificationsTab
                .tabItem { Label("Notifications", systemImage: "bell") }
            aboutTab
                .tabItem { Label("About", systemImage: "info.circle") }
        }
        .frame(width: 520)
        .onAppear {
            loadSettings()
        }
        .onChange(of: appModel.settings.hasNotificationsEnabled) { _, newValue in
            Task {
                if newValue {
                    await appModel.requestNotificationPermissionIfNeeded()
                }
                await updateNotificationStatus()
            }
        }
        .onChange(of: launchAtLogin) { _, newValue in
            updateLaunchAtLogin(newValue)
        }
    }

    // MARK: - General Tab

    private var generalTab: some View {
        Form {
            if !appModel.isReady {
                ProgressView("Loading…")
                    .frame(maxWidth: .infinity, minHeight: 360)
            } else {
                claudeSection
                popoverSection
                refreshSection
                menuBarSection
                loginSection
            }
        }
        .formStyle(.grouped)
        .frame(minHeight: 520, alignment: .top)
    }

    private var claudeSection: some View {
        Section {
            LabeledContent("Status") {
                Text(sessionKey.isEmpty ? "Not added" : "Connected")
                    .foregroundStyle(sessionKey.isEmpty ? Color.secondary : Color(nsColor: .systemGreen))
            }

            HStack(spacing: 8) {
                Group {
                    if isSessionKeyShown {
                        TextField("sk-ant-…", text: $sessionKey)
                    } else {
                        SecureField("sk-ant-…", text: $sessionKey)
                    }
                }
                .font(.body.monospaced())
                .textFieldStyle(.roundedBorder)

                Button {
                    isSessionKeyShown.toggle()
                } label: {
                    Image(systemName: isSessionKeyShown ? "eye.slash" : "eye")
                }
                .buttonStyle(.borderless)
                .help(isSessionKeyShown ? "Hide session" : "Show session")
                .accessibilityLabel(isSessionKeyShown ? "Hide session" : "Show session")

                if !sessionKey.isEmpty {
                    Button(action: clearSessionKey) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.borderless)
                    .help("Remove session")
                    .accessibilityLabel("Remove session")
                }
            }

            HStack(spacing: 8) {
                Button("Save Session") {
                    Task {
                        await validateAndSaveSessionKey()
                    }
                }
                .disabled(sessionKey.isEmpty || isSessionKeyBusy)

                Button("Import from Browser") {
                    Task {
                        await importAndSaveSessionKey()
                    }
                }
                .disabled(isSessionKeyBusy)

                if isSessionKeyBusy {
                    ProgressView()
                        .controlSize(.small)
                }

                if let message = sessionKeyValidationMessage, hasSessionKeyValidationSucceeded {
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(Color(nsColor: .systemGreen))
                        .lineLimit(1)
                }

                Spacer(minLength: 0)
            }

            if let message = sessionKeyValidationMessage, !hasSessionKeyValidationSucceeded {
                VStack(alignment: .leading, spacing: 6) {
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(Color(nsColor: .systemRed))
                        .fixedSize(horizontal: false, vertical: true)

                    if offersFullDiskAccessSettings {
                        Button("Open Full Disk Access") {
                            SystemSettingsOpener.openFullDiskAccess()
                        }
                        .controlSize(.small)
                    }
                }
            }
        } header: {
            Text("Claude")
        } footer: {
            Text("Import from a browser signed in to claude.ai, or paste a session.")
        }
    }

    private var popoverSection: some View {
        Section {
            Toggle("Show Codex usage", isOn: $appModel.settings.isCodexUsageShown)
            Toggle("Show weekly Sonnet", isOn: $appModel.settings.isSonnetUsageShown)
            Toggle("Show exact reset times", isOn: $appModel.settings.isResetTimeShown)
        } header: {
            Text("Popover")
        } footer: {
            Text("Codex reads usage from the signed-in Codex app. Sonnet is Claude-only.")
        }
    }

    private var refreshSection: some View {
        Section {
            Picker("Refresh interval", selection: $appModel.settings.refreshInterval) {
                Text("1 minute").tag(60.0)
                Text("5 minutes").tag(300.0)
                Text("10 minutes").tag(600.0)
            }
        } footer: {
            Text("How often \(AppIdentity.displayName) checks Claude and Codex.")
        }
    }

    private var menuBarSection: some View {
        Section {
            Picker("Color", selection: $appModel.settings.isColoredIcon) {
                Text("System").tag(false)
                Text("Color").tag(true)
            }
            .pickerStyle(.segmented)
            .help("System matches the menu bar tint. Color uses green, orange, and red.")
            .accessibilityLabel("Menu bar color")

            IconStylePicker(
                selection: $appModel.settings.iconStyle,
                isColored: appModel.settings.isColoredIcon,
                showsCodex: appModel.settings.isCodexUsageShown
            )
            .listRowInsets(EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12))
        } header: {
            Text("Menu Bar")
        } footer: {
            Text(
                appModel.settings.isCodexUsageShown
                    ? IconStyle.dualBarRequiredForCodexCaption
                    : "Choose how \(AppIdentity.displayName) appears in the menu bar."
            )
        }
    }

    private var loginSection: some View {
        Section {
            Toggle("Start at login", isOn: $launchAtLogin)
        }
    }

    // MARK: - Notifications Tab

    private var notificationsTab: some View {
        Form {
            Section {
                Toggle("Enable notifications", isOn: $appModel.settings.hasNotificationsEnabled)

                if let error = notificationError {
                    HStack(alignment: .top, spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(Color(nsColor: .systemOrange))
                        VStack(alignment: .leading, spacing: 4) {
                            Text(error)
                            Button("Open System Settings") {
                                openSystemNotificationSettings()
                            }
                            .buttonStyle(.link)
                        }
                        .font(.caption)
                    }
                }
            } footer: {
                Text("Alerts cover Claude session usage. Codex is not included.")
            }

            Section {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Warning")
                        Spacer()
                        Text("\(Int(warningThresholdValue))%")
                            .foregroundStyle(Color(nsColor: .systemOrange))
                            .font(.body.monospacedDigit())
                    }

                    Slider(
                        value: warningThresholdBinding,
                        in: Constants.Thresholds.Notification.warningMin...Constants.Thresholds.Notification.warningMax,
                        step: Constants.Thresholds.Notification.step
                    )
                    .tint(Color(nsColor: .systemOrange))
                    .disabled(!appModel.settings.hasNotificationsEnabled)
                }

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Critical")
                        Spacer()
                        Text("\(Int(criticalThresholdValue))%")
                            .foregroundStyle(Color(nsColor: .systemRed))
                            .font(.body.monospacedDigit())
                    }

                    Slider(
                        value: criticalThresholdBinding,
                        in: Constants.Thresholds.Notification.criticalMin...Constants.Thresholds.Notification.criticalMax,
                        step: Constants.Thresholds.Notification.step
                    )
                    .tint(Color(nsColor: .systemRed))
                    .disabled(!appModel.settings.hasNotificationsEnabled)

                    if criticalThresholdValue <= warningThresholdValue {
                        Text("Critical must be higher than warning.")
                            .font(.caption)
                            .foregroundStyle(Color(nsColor: .systemRed))
                    }
                }
            } header: {
                Text("Claude Session Thresholds")
            } footer: {
                Text("The menu bar turns orange at 50% and red at 80%, independent of these alerts.")
            }
            .opacity(appModel.settings.hasNotificationsEnabled ? 1 : 0.5)

            Section {
                Toggle("Notify when a session resets", isOn: isNotifiedOnResetBinding)
                    .disabled(!appModel.settings.hasNotificationsEnabled)
            }
            .opacity(appModel.settings.hasNotificationsEnabled ? 1 : 0.5)

            Section {
                HStack {
                    Button("Send Test Notification") {
                        Task {
                            await sendTestNotification()
                        }
                    }
                    .disabled(isSendingTestNotification || !appModel.settings.hasNotificationsEnabled)

                    if isSendingTestNotification {
                        ProgressView()
                            .controlSize(.small)
                    }

                    if let message = testNotificationMessage {
                        Text(message)
                            .font(.caption)
                            .foregroundStyle(hasTestNotificationSucceeded ? Color(nsColor: .systemGreen) : Color(nsColor: .systemRed))
                    }

                    Spacer(minLength: 0)
                }
            }
            .opacity(appModel.settings.hasNotificationsEnabled ? 1 : 0.5)
        }
        .formStyle(.grouped)
        .frame(minHeight: 520, alignment: .top)
    }

    // MARK: - Bindings

    private var warningThresholdBinding: Binding<Double> {
        Binding(
            get: { appModel.settings.notificationThresholds.warningThreshold },
            set: { appModel.settings.notificationThresholds.warningThreshold = $0 }
        )
    }

    private var criticalThresholdBinding: Binding<Double> {
        Binding(
            get: { appModel.settings.notificationThresholds.criticalThreshold },
            set: { appModel.settings.notificationThresholds.criticalThreshold = $0 }
        )
    }

    private var isNotifiedOnResetBinding: Binding<Bool> {
        Binding(
            get: { appModel.settings.notificationThresholds.isNotifiedOnReset },
            set: { appModel.settings.notificationThresholds.isNotifiedOnReset = $0 }
        )
    }

    private var warningThresholdValue: Double {
        appModel.settings.notificationThresholds.warningThreshold
    }

    private var criticalThresholdValue: Double {
        appModel.settings.notificationThresholds.criticalThreshold
    }

    // MARK: - About Tab

    private var aboutTab: some View {
        VStack(spacing: 16) {
            Group {
                if let appIconImage = NSImage(named: "AppIcon") {
                    Image(nsImage: appIconImage)
                        .resizable()
                        .frame(width: 80, height: 80)
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                } else {
                    Image(systemName: "chart.bar.xaxis")
                        .font(.system(size: 36))
                        .foregroundStyle(.secondary)
                        .frame(width: 80, height: 80)
                }
            }

            VStack(spacing: 4) {
                Text(AppIdentity.displayName)
                    .font(.title2.weight(.semibold))

                if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String,
                   let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String {
                    Text("Version \(version) (\(build))")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            Text(AppIdentity.tagline)
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Link("GitHub", destination: AppIdentity.githubURL)
                .font(.callout)

            VStack(spacing: 2) {
                Text(AppIdentity.copyrightLine)
                Text(AppIdentity.forkAttribution)
            }
            .font(.caption)
            .foregroundStyle(.tertiary)
            .multilineTextAlignment(.center)
        }
        .padding(32)
        .frame(maxWidth: .infinity, minHeight: 520)
    }

    // MARK: - Actions

    private var isSessionKeyBusy: Bool {
        isValidatingSessionKey || isImportingSessionKey
    }

    private func loadSettings() {
        Task { @MainActor in
            sessionKey = await appModel.loadSessionKey() ?? ""
            await updateNotificationStatus()
        }
    }

    @MainActor
    private func updateNotificationStatus() async {
        let hasPermission = await appModel.checkNotificationPermissions()
        if !hasPermission {
            notificationError = "Notifications are turned off in System Settings."
            if appModel.settings.hasNotificationsEnabled {
                appModel.settings.hasNotificationsEnabled = false
            }
        } else {
            notificationError = nil
        }
    }

    @MainActor
    private func validateAndSaveSessionKey() async {
        guard !sessionKey.isEmpty else {
            sessionKeyValidationMessage = "Enter a Claude session."
            hasSessionKeyValidationSucceeded = false
            return
        }

        isValidatingSessionKey = true
        sessionKeyValidationMessage = nil
        offersFullDiskAccessSettings = false
        hasSessionKeyValidationSucceeded = false

        do {
            let isValid = try await appModel.validateAndSaveSessionKey(sessionKey)

            if isValid {
                sessionKeyValidationMessage = "Saved"
                hasSessionKeyValidationSucceeded = true

                Task { @MainActor in
                    try? await Task.sleep(for: .seconds(2))
                    sessionKeyValidationMessage = nil
                    hasSessionKeyValidationSucceeded = false
                }
            } else {
                sessionKeyValidationMessage = "Claude rejected this session."
                hasSessionKeyValidationSucceeded = false
            }
        } catch let error as SessionKeyError {
            sessionKeyValidationMessage = error.localizedDescription
            offersFullDiskAccessSettings = false
            hasSessionKeyValidationSucceeded = false
        } catch {
            sessionKeyValidationMessage = error.localizedDescription
            offersFullDiskAccessSettings = false
            hasSessionKeyValidationSucceeded = false
        }

        isValidatingSessionKey = false
    }

    @MainActor
    private func importAndSaveSessionKey() async {
        isImportingSessionKey = true
        sessionKeyValidationMessage = nil
        offersFullDiskAccessSettings = false
        hasSessionKeyValidationSucceeded = false

        do {
            let imported = try await appModel.importAndSaveSessionKey()
            sessionKey = imported.value
            sessionKeyValidationMessage = "Imported from \(imported.sourceDescription)"
            hasSessionKeyValidationSucceeded = true
            offersFullDiskAccessSettings = false

            Task { @MainActor in
                try? await Task.sleep(for: .seconds(2))
                sessionKeyValidationMessage = nil
                offersFullDiskAccessSettings = false
                hasSessionKeyValidationSucceeded = false
            }
        } catch let error as SessionKeyImportError {
            sessionKeyValidationMessage = error.localizedDescription
            offersFullDiskAccessSettings = error.offersFullDiskAccessSettings
            hasSessionKeyValidationSucceeded = false
        } catch {
            sessionKeyValidationMessage = error.localizedDescription
            offersFullDiskAccessSettings = false
            hasSessionKeyValidationSucceeded = false
        }

        isImportingSessionKey = false
    }

    private func clearSessionKey() {
        Task { @MainActor in
            do {
                try await appModel.clearSessionKey()
                sessionKey = ""
                sessionKeyValidationMessage = nil
                offersFullDiskAccessSettings = false
                hasSessionKeyValidationSucceeded = false
            } catch {
                sessionKeyValidationMessage = error.localizedDescription
                offersFullDiskAccessSettings = false
                hasSessionKeyValidationSucceeded = false
            }
        }
    }

    private func updateLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            launchAtLogin = SMAppService.mainApp.status == .enabled
        }
    }

    @MainActor
    private func sendTestNotification() async {
        isSendingTestNotification = true
        testNotificationMessage = nil
        hasTestNotificationSucceeded = false

        do {
            let hasPermission = await appModel.checkNotificationPermissions()
            if !hasPermission {
                await appModel.requestNotificationPermissionIfNeeded()
                let granted = await appModel.checkNotificationPermissions()
                if !granted {
                    testNotificationMessage = "Permission denied"
                    hasTestNotificationSucceeded = false
                    isSendingTestNotification = false
                    return
                }
            }

            try await appModel.sendTestNotification()

            testNotificationMessage = "Sent"
            hasTestNotificationSucceeded = true

            Task { @MainActor in
                try? await Task.sleep(for: .seconds(2))
                testNotificationMessage = nil
                hasTestNotificationSucceeded = false
            }
        } catch {
            testNotificationMessage = error.localizedDescription
            hasTestNotificationSucceeded = false
        }

        isSendingTestNotification = false
    }

    private func openSystemNotificationSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.notifications") {
            NSWorkspace.shared.open(url)
        }
    }
}
