import AppKit
import Foundation
import Observation

/// Main application model for SwiftUI-first architecture.
@MainActor
@Observable
final class AppModel {
    // MARK: - Published State

    var settings: AppSettings = .default {
        didSet {
            guard hasLoadedSettings, !isNormalizingSettings else { return }
            let previous = oldValue
            if settings.isCodexUsageShown, settings.iconStyle != .dualBar {
                isNormalizingSettings = true
                var normalized = settings
                normalized.iconStyle = .dualBar
                settings = normalized
                isNormalizingSettings = false
            }
            scheduleSettingsSave(previous: previous)
        }
    }

    var usageData: UsageData?
    var codexUsageData: CodexUsageData?
    var isLoading: Bool = false
    var isRefreshing: Bool = false
    var errorMessage: String?
    var codexErrorMessage: String?
    var isSetupComplete: Bool = false
    var isReady: Bool = false

    // MARK: - Dependencies

    @ObservationIgnored private let settingsRepository: SettingsRepositoryProtocol
    @ObservationIgnored private let keychainRepository: KeychainRepositoryProtocol
    @ObservationIgnored private let usageService: UsageServiceProtocol
    @ObservationIgnored private let codexUsageService: CodexUsageServiceProtocol?
    @ObservationIgnored private let notificationService: NotificationServiceProtocol
    @ObservationIgnored private let sessionKeyImportService: SessionKeyImportServiceProtocol

    // MARK: - Private

    @ObservationIgnored private var refreshTask: Task<Void, Never>?
    @ObservationIgnored private var inFlightRefresh: Task<Void, Never>?
    @ObservationIgnored private var settingsSaveTask: Task<Void, Never>?
    @ObservationIgnored private var wakeTask: Task<Void, Never>?
    @ObservationIgnored private var hasLoadedSettings: Bool = false
    @ObservationIgnored private var isNormalizingSettings: Bool = false
    @ObservationIgnored private var refreshGeneration: UInt64 = 0
    @ObservationIgnored private let refreshClock = ContinuousClock()

    // MARK: - Initialization

    init(
        settingsRepository: SettingsRepositoryProtocol = SettingsRepository(),
        keychainRepository: KeychainRepositoryProtocol = KeychainRepository(),
        usageService: UsageServiceProtocol? = nil,
        codexUsageService: CodexUsageServiceProtocol? = nil,
        notificationService: NotificationServiceProtocol? = nil,
        sessionKeyImportService: SessionKeyImportServiceProtocol = SessionKeyImportService()
    ) {
        self.settingsRepository = settingsRepository
        self.keychainRepository = keychainRepository
        self.sessionKeyImportService = sessionKeyImportService
        self.codexUsageService = codexUsageService

        let networkService = NetworkService()
        let cacheRepository = CacheRepository()
        let usageService = usageService ?? UsageService(
            networkService: networkService,
            cacheRepository: cacheRepository,
            keychainRepository: keychainRepository,
            settingsRepository: settingsRepository
        )
        self.usageService = usageService
        self.notificationService = notificationService ?? NotificationService(
            settingsRepository: settingsRepository
        )

        self.notificationService.setupDelegate()
    }

    // MARK: - Lifecycle

    func bootstrap() async {
        guard !isReady else { return }
        settings = await settingsRepository.load()
        hasLoadedSettings = true
        if settings.isCodexUsageShown, settings.iconStyle != .dualBar {
            settings.iconStyle = .dualBar
        }

        isSetupComplete = await keychainRepository.exists(account: "default")
        isReady = true

        if isSetupComplete {
            await refreshUsage(forceRefresh: true)
            startRefreshLoop()
        }

        startWakeObserver()
    }

    // MARK: - Usage

    func refreshUsage(forceRefresh: Bool = false) async {
        inFlightRefresh?.cancel()
        let task = Task { await self.performRefresh(forceRefresh: forceRefresh) }
        inFlightRefresh = task
        await withTaskCancellationHandler {
            await task.value
        } onCancel: {
            task.cancel()
        }
    }

    private func performRefresh(forceRefresh: Bool) async {
        guard isSetupComplete else {
            clearUsageState()
            return
        }

        refreshGeneration += 1
        let generation = refreshGeneration

        if !UsagePopoverContent.hasUsageContent(
            claude: usageData,
            codex: codexUsageData,
            isCodexUsageShown: settings.isCodexUsageShown
        ) {
            isLoading = true
        }
        isRefreshing = true
        errorMessage = nil
        codexErrorMessage = nil

        defer {
            if generation == refreshGeneration {
                isLoading = false
                isRefreshing = false
            }
        }

        let shouldFetchCodex = settings.isCodexUsageShown
        let codexService = shouldFetchCodex ? codexUsageService : nil

        async let claudeOutcome = fetchClaudeUsage(forceRefresh: forceRefresh)
        async let codexOutcome = fetchCodexUsage(using: codexService)

        let claude = await claudeOutcome
        let codex = await codexOutcome

        guard generation == refreshGeneration, !Task.isCancelled, isSetupComplete else {
            return
        }
        if claude.isCancelled || (shouldFetchCodex && (codex?.isCancelled ?? false)) {
            return
        }

        switch claude {
        case .success(let data):
            usageData = data
            errorMessage = nil
            await notificationService.evaluateThresholds(
                usageData: data,
                settings: settings
            )
        case .failure(let error):
            errorMessage = error.localizedDescription
        case .cancelled:
            return
        }

        guard generation == refreshGeneration, !Task.isCancelled, isSetupComplete else {
            return
        }

        if shouldFetchCodex {
            if let outcome = codex {
                switch outcome {
                case .success(let data):
                    codexUsageData = data
                    codexErrorMessage = nil
                case .failure(let error):
                    codexErrorMessage = error.localizedDescription
                case .cancelled:
                    return
                }
            } else {
                codexUsageData = nil
                codexErrorMessage = nil
            }
        } else {
            codexUsageData = nil
            codexErrorMessage = nil
        }
    }

    // MARK: - Session Key

    func loadSessionKey() async -> String? {
        do {
            return try await keychainRepository.retrieve(account: "default")
        } catch KeychainError.notFound {
            return nil
        } catch {
            return nil
        }
    }

    func validateAndSaveSessionKey(_ rawValue: String) async throws -> Bool {
        let sessionKey = try SessionKey(rawValue)
        let isValid = try await usageService.validateSessionKey(sessionKey)

        guard isValid else {
            return false
        }

        let organizations = try await usageService.fetchOrganizations(sessionKey: sessionKey)
        guard let firstOrg = organizations.first,
              let orgUUID = firstOrg.organizationUUID else {
            throw AppError.organizationNotFound
        }

        try await keychainRepository.save(sessionKey: sessionKey.value, account: "default")

        settings.cachedOrganizationId = orgUUID
        settings.isFirstLaunch = false
        isSetupComplete = true

        await refreshUsage(forceRefresh: true)
        startRefreshLoop()

        return true
    }

    func importAndSaveSessionKey() async throws -> ImportedSessionKey {
        let imported = try await sessionKeyImportService.importSessionKey()
        let isValid = try await validateAndSaveSessionKey(imported.value)

        guard isValid else {
            throw SessionKeyImportError.invalidImportedSessionKey
        }

        return imported
    }

    func clearSessionKey() async throws {
        refreshGeneration += 1
        inFlightRefresh?.cancel()
        refreshTask?.cancel()
        try await keychainRepository.delete(account: "default")
        settings.cachedOrganizationId = nil
        settings.isFirstLaunch = true
        isSetupComplete = false
        clearUsageState()
    }

    // MARK: - Notifications

    func requestNotificationPermissionIfNeeded() async {
        let hasPermission = await notificationService.checkNotificationPermissions()
        if !hasPermission {
            _ = try? await notificationService.requestAuthorization()
        }
    }

    func checkNotificationPermissions() async -> Bool {
        await notificationService.checkNotificationPermissions()
    }

    func sendTestNotification() async throws {
        try await notificationService.sendThresholdNotification(
            percentage: 85.0,
            threshold: .warning,
            resetTime: Date().addingTimeInterval(3600)
        )
    }

    // MARK: - Private

    private func scheduleSettingsSave(previous: AppSettings) {
        settingsSaveTask?.cancel()
        settingsSaveTask = Task {
            try? await settingsRepository.save(settings)
        }

        if previous.refreshInterval != settings.refreshInterval {
            startRefreshLoop()
        }

        if previous.isCodexUsageShown != settings.isCodexUsageShown, isSetupComplete {
            Task { await refreshUsage(forceRefresh: true) }
        }
    }

    private func clearUsageState() {
        usageData = nil
        errorMessage = nil
        codexUsageData = nil
        codexErrorMessage = nil
    }

    private func fetchClaudeUsage(forceRefresh: Bool) async -> ProviderFetch<UsageData> {
        do {
            return .success(try await usageService.fetchUsage(forceRefresh: forceRefresh))
        } catch {
            return Self.providerFetch(from: error)
        }
    }

    private func fetchCodexUsage(using service: CodexUsageServiceProtocol?) async -> ProviderFetch<CodexUsageData>? {
        guard let service else { return nil }
        do {
            return .success(try await service.fetchUsage())
        } catch {
            return Self.providerFetch(from: error)
        }
    }

    private static func providerFetch<Value>(from error: Error) -> ProviderFetch<Value> {
        if error is CancellationError {
            return .cancelled
        }
        let urlError = error as NSError
        if urlError.domain == NSURLErrorDomain, urlError.code == NSURLErrorCancelled {
            return .cancelled
        }
        return .failure(error)
    }

    private func startRefreshLoop() {
        refreshTask?.cancel()
        guard isSetupComplete else { return }

        let interval = Duration.seconds(Int(settings.refreshInterval))
        refreshTask = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                try? await self.refreshClock.sleep(for: interval)
                await self.refreshUsage()
            }
        }
    }

    private func startWakeObserver() {
        wakeTask?.cancel()
        wakeTask = Task { [weak self] in
            guard let self else { return }
            for await _ in NSWorkspace.shared.notificationCenter.notifications(named: NSWorkspace.didWakeNotification) {
                await self.refreshUsage(forceRefresh: true)
            }
        }
    }

    // MARK: - Demo Mode

    #if DEBUG
    /// Applies demo state for App Store screenshots.
    /// Skips normal bootstrap and sets state directly.
    func applyDemoState(
        usageData: UsageData?,
        isSetupComplete: Bool,
        errorMessage: String?,
        isLoading: Bool,
        codexUsageData: CodexUsageData? = nil
    ) {
        self.usageData = usageData
        self.codexUsageData = codexUsageData
        self.isSetupComplete = isSetupComplete
        self.errorMessage = errorMessage
        self.isLoading = isLoading
        self.isReady = true
        self.hasLoadedSettings = true
        // Don't start refresh loop or wake observer in demo mode
    }
    #endif

}

private enum ProviderFetch<Value> {
    case success(Value)
    case failure(Error)
    case cancelled

    var isCancelled: Bool {
        if case .cancelled = self { return true }
        return false
    }
}
