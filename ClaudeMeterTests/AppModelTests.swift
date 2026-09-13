import XCTest
@testable import ClaudeMeter

@MainActor
final class AppModelTests: XCTestCase {
    func test_bootstrap_withoutSessionKey_showsSetupState() async {
        let usageService = UsageServiceStub(fetchUsageResult: .failure(TestError(message: TestConstants.unexpectedErrorMessage)))
        let notificationService = NotificationServiceSpy()
        let settingsRepository = SettingsRepositoryFake()
        let keychainRepository = KeychainRepositoryFake()

        let appModel = AppModel(
            settingsRepository: settingsRepository,
            keychainRepository: keychainRepository,
            usageService: usageService,
            notificationService: notificationService
        )

        try? await keychainRepository.delete(account: "default")

        await appModel.bootstrap()

        XCTAssertTrue(appModel.isReady)
        XCTAssertFalse(appModel.isSetupComplete)
        XCTAssertNil(appModel.usageData)
        XCTAssertNil(appModel.errorMessage)
    }

    func test_userWithSessionKey_seesUsageAfterLaunch() async {
        let expectedUsage = makeUsageData(percentage: TestConstants.sessionPercentage)
        let usageService = UsageServiceStub(fetchUsageResult: .success(expectedUsage))
        let notificationService = NotificationServiceSpy()
        let settingsRepository = SettingsRepositoryFake()
        let keychainRepository = KeychainRepositoryFake()

        let appModel = AppModel(
            settingsRepository: settingsRepository,
            keychainRepository: keychainRepository,
            usageService: usageService,
            notificationService: notificationService
        )

        try? await keychainRepository.save(
            sessionKey: TestConstants.sessionKeyValue,
            account: "default"
        )

        await appModel.bootstrap()

        XCTAssertTrue(appModel.isReady)
        XCTAssertTrue(appModel.isSetupComplete)
        XCTAssertEqual(appModel.usageData, expectedUsage)
        XCTAssertNil(appModel.errorMessage)
        XCTAssertEqual(notificationService.lastEvaluatedUsageData, expectedUsage)
    }

    func test_userWithSessionKey_seesErrorWhenUsageFailsAfterLaunch() async {
        let failure = TestError(message: TestConstants.fetchFailureMessage)
        let usageService = UsageServiceStub(fetchUsageResult: .failure(failure))
        let notificationService = NotificationServiceSpy()
        let settingsRepository = SettingsRepositoryFake()
        let keychainRepository = KeychainRepositoryFake()

        let appModel = AppModel(
            settingsRepository: settingsRepository,
            keychainRepository: keychainRepository,
            usageService: usageService,
            notificationService: notificationService
        )

        try? await keychainRepository.save(
            sessionKey: TestConstants.sessionKeyValue,
            account: "default"
        )

        await appModel.bootstrap()

        XCTAssertTrue(appModel.isReady)
        XCTAssertTrue(appModel.isSetupComplete)
        XCTAssertNil(appModel.usageData)
        XCTAssertEqual(appModel.errorMessage, failure.localizedDescription)
        XCTAssertNil(notificationService.lastEvaluatedUsageData)
    }

    func test_refreshingUsage_showsLatestUsageAndClearsError() async {
        let expectedUsage = makeUsageData(percentage: TestConstants.sessionPercentage)
        let usageService = UsageServiceStub(fetchUsageResult: .success(expectedUsage))
        let notificationService = NotificationServiceSpy()
        let settingsRepository = SettingsRepositoryFake()
        let keychainRepository = KeychainRepositoryFake()

        let appModel = AppModel(
            settingsRepository: settingsRepository,
            keychainRepository: keychainRepository,
            usageService: usageService,
            notificationService: notificationService
        )

        appModel.isSetupComplete = true
        appModel.errorMessage = TestConstants.previousErrorMessage

        await appModel.refreshUsage(forceRefresh: true)

        XCTAssertEqual(appModel.usageData, expectedUsage)
        XCTAssertNil(appModel.errorMessage)
        XCTAssertFalse(appModel.isRefreshing)
        XCTAssertFalse(appModel.isLoading)
        XCTAssertEqual(notificationService.lastEvaluatedUsageData, expectedUsage)
    }

    func test_refreshingUsage_alsoShowsCodexUsage() async {
        let expectedUsage = makeUsageData(percentage: TestConstants.sessionPercentage)
        let expectedCodexUsage = makeCodexUsageData()
        let usageService = UsageServiceStub(fetchUsageResult: .success(expectedUsage))
        let codexUsageService = CodexUsageServiceStub(result: .success(expectedCodexUsage))
        let appModel = AppModel(
            settingsRepository: SettingsRepositoryFake(),
            keychainRepository: KeychainRepositoryFake(),
            usageService: usageService,
            codexUsageService: codexUsageService,
            notificationService: NotificationServiceSpy()
        )
        appModel.isSetupComplete = true

        await appModel.refreshUsage(forceRefresh: true)

        XCTAssertEqual(appModel.usageData, expectedUsage)
        XCTAssertEqual(appModel.codexUsageData, expectedCodexUsage)
        XCTAssertNil(appModel.codexErrorMessage)
    }

    func test_refreshingUsage_whenClaudeFailsAndCodexSucceeds_isDisplayable() async {
        let claudeFailure = TestError(message: TestConstants.fetchFailureMessage)
        let expectedCodexUsage = makeCodexUsageData()
        let usageService = UsageServiceStub(fetchUsageResult: .failure(claudeFailure))
        let codexUsageService = CodexUsageServiceStub(result: .success(expectedCodexUsage))
        let appModel = AppModel(
            settingsRepository: SettingsRepositoryFake(),
            keychainRepository: KeychainRepositoryFake(),
            usageService: usageService,
            codexUsageService: codexUsageService,
            notificationService: NotificationServiceSpy()
        )
        appModel.isSetupComplete = true

        await appModel.refreshUsage(forceRefresh: true)

        XCTAssertNil(appModel.usageData)
        XCTAssertEqual(appModel.errorMessage, claudeFailure.localizedDescription)
        XCTAssertEqual(appModel.codexUsageData, expectedCodexUsage)
        XCTAssertNil(appModel.codexErrorMessage)
        XCTAssertTrue(
            UsagePopoverContent.hasUsageContent(
                claude: appModel.usageData,
                codex: appModel.codexUsageData,
                isCodexUsageShown: appModel.settings.isCodexUsageShown
            )
        )
    }

    func test_refreshingUsage_cancelsInFlightProviderFetchesWhenCallerCancels() async {
        let usageService = UsageServiceStub(
            fetchUsageResult: .success(makeUsageData(percentage: TestConstants.sessionPercentage)),
            fetchDelay: .seconds(5)
        )
        let codexUsageService = CodexUsageServiceStub(
            result: .success(makeCodexUsageData()),
            fetchDelay: .seconds(5)
        )
        let appModel = AppModel(
            settingsRepository: SettingsRepositoryFake(),
            keychainRepository: KeychainRepositoryFake(),
            usageService: usageService,
            codexUsageService: codexUsageService,
            notificationService: NotificationServiceSpy()
        )
        appModel.isSetupComplete = true

        let refresh = Task {
            await appModel.refreshUsage(forceRefresh: true)
        }
        await usageService.waitUntilFetchStarted()
        await codexUsageService.waitUntilFetchStarted()
        refresh.cancel()
        await refresh.value

        let claudeCancelled = await usageService.didCancelFetch()
        let codexCancelled = await codexUsageService.didCancelFetch()
        XCTAssertTrue(claudeCancelled)
        XCTAssertTrue(codexCancelled)
        XCTAssertFalse(appModel.isRefreshing)
        XCTAssertNil(appModel.errorMessage)
        XCTAssertNil(appModel.codexErrorMessage)
        XCTAssertNil(appModel.usageData)
        XCTAssertNil(appModel.codexUsageData)
    }

    func test_refreshingUsage_whenCancelled_keepsExistingDataAndDoesNotShowCancelledError() async {
        let existingUsage = makeUsageData(percentage: TestConstants.cachedPercentage)
        let existingCodex = makeCodexUsageData()
        let usageService = UsageServiceStub(
            fetchUsageResult: .success(makeUsageData(percentage: TestConstants.sessionPercentage)),
            fetchDelay: .seconds(5)
        )
        let codexUsageService = CodexUsageServiceStub(
            result: .success(makeCodexUsageData()),
            fetchDelay: .seconds(5)
        )
        let appModel = AppModel(
            settingsRepository: SettingsRepositoryFake(),
            keychainRepository: KeychainRepositoryFake(),
            usageService: usageService,
            codexUsageService: codexUsageService,
            notificationService: NotificationServiceSpy()
        )
        appModel.isSetupComplete = true
        appModel.usageData = existingUsage
        appModel.codexUsageData = existingCodex

        let refresh = Task {
            await appModel.refreshUsage(forceRefresh: true)
        }
        await usageService.waitUntilFetchStarted()
        await codexUsageService.waitUntilFetchStarted()
        refresh.cancel()
        await refresh.value

        XCTAssertNil(appModel.errorMessage)
        XCTAssertNil(appModel.codexErrorMessage)
        XCTAssertEqual(appModel.usageData, existingUsage)
        XCTAssertEqual(appModel.codexUsageData, existingCodex)
        XCTAssertFalse(appModel.isRefreshing)
        XCTAssertFalse(appModel.isLoading)
    }

    func test_overlappingRefresh_isNotDropped() async {
        let usageService = UsageServiceStub(
            fetchUsageResult: .success(makeUsageData(percentage: TestConstants.sessionPercentage)),
            fetchDelay: .seconds(5)
        )
        let appModel = AppModel(
            settingsRepository: SettingsRepositoryFake(),
            keychainRepository: KeychainRepositoryFake(),
            usageService: usageService,
            notificationService: NotificationServiceSpy()
        )
        appModel.isSetupComplete = true

        let first = Task { await appModel.refreshUsage(forceRefresh: true) }
        await usageService.waitUntilFetchStarted()
        let second = Task { await appModel.refreshUsage(forceRefresh: true) }
        await Task.yield()
        try? await Task.sleep(for: .milliseconds(50))

        let fetchCount = await usageService.fetchCallCount
        XCTAssertEqual(fetchCount, 2)

        first.cancel()
        second.cancel()
        await first.value
        await second.value
        XCTAssertFalse(appModel.isRefreshing)
    }

    func test_clearingSessionDuringRefresh_doesNotReviveUsageData() async throws {
        let usageService = UsageServiceStub(
            fetchUsageResult: .success(makeUsageData(percentage: TestConstants.sessionPercentage)),
            fetchDelay: .seconds(5)
        )
        let codexUsageService = CodexUsageServiceStub(
            result: .success(makeCodexUsageData()),
            fetchDelay: .seconds(5)
        )
        let keychainRepository = KeychainRepositoryFake()
        let appModel = AppModel(
            settingsRepository: SettingsRepositoryFake(),
            keychainRepository: keychainRepository,
            usageService: usageService,
            codexUsageService: codexUsageService,
            notificationService: NotificationServiceSpy()
        )
        appModel.isSetupComplete = true
        try await keychainRepository.save(
            sessionKey: TestConstants.sessionKeyValue,
            account: "default"
        )

        let refresh = Task { await appModel.refreshUsage(forceRefresh: true) }
        await usageService.waitUntilFetchStarted()
        try await appModel.clearSessionKey()
        await refresh.value

        XCTAssertFalse(appModel.isSetupComplete)
        XCTAssertNil(appModel.usageData)
        XCTAssertNil(appModel.codexUsageData)
        XCTAssertNil(appModel.errorMessage)
        XCTAssertNil(appModel.codexErrorMessage)
    }

    func test_enablingCodex_forcesDualBarIconStyle() async throws {
        var stored = AppSettings.default
        stored.isCodexUsageShown = false
        stored.iconStyle = .battery
        let settingsRepository = SettingsRepositoryFake()
        try await settingsRepository.save(stored)
        let keychainRepository = KeychainRepositoryFake()
        try await keychainRepository.save(
            sessionKey: TestConstants.sessionKeyValue,
            account: "default"
        )
        let appModel = AppModel(
            settingsRepository: settingsRepository,
            keychainRepository: keychainRepository,
            usageService: UsageServiceStub(
                fetchUsageResult: .success(makeUsageData(percentage: TestConstants.sessionPercentage))
            ),
            codexUsageService: CodexUsageServiceStub(result: .success(makeCodexUsageData())),
            notificationService: NotificationServiceSpy()
        )

        await appModel.bootstrap()
        XCTAssertEqual(appModel.settings.iconStyle, .battery)

        appModel.settings.isCodexUsageShown = true

        XCTAssertEqual(appModel.settings.iconStyle, .dualBar)
    }

    func test_refreshingUsage_keepsClaudeUsageWhenCodexFails() async {
        let expectedUsage = makeUsageData(percentage: TestConstants.sessionPercentage)
        let codexFailure = TestError(message: "Codex unavailable")
        let usageService = UsageServiceStub(fetchUsageResult: .success(expectedUsage))
        let codexUsageService = CodexUsageServiceStub(result: .failure(codexFailure))
        let appModel = AppModel(
            settingsRepository: SettingsRepositoryFake(),
            keychainRepository: KeychainRepositoryFake(),
            usageService: usageService,
            codexUsageService: codexUsageService,
            notificationService: NotificationServiceSpy()
        )
        appModel.isSetupComplete = true

        await appModel.refreshUsage(forceRefresh: true)

        XCTAssertEqual(appModel.usageData, expectedUsage)
        XCTAssertNil(appModel.errorMessage)
        XCTAssertEqual(appModel.codexErrorMessage, codexFailure.localizedDescription)
    }

    func test_refreshingUsage_skipsCodexWhenSettingIsDisabled() async {
        let expectedUsage = makeUsageData(percentage: TestConstants.sessionPercentage)
        let usageService = UsageServiceStub(fetchUsageResult: .success(expectedUsage))
        let codexUsageService = CodexUsageServiceStub(result: .success(makeCodexUsageData()))
        let appModel = AppModel(
            settingsRepository: SettingsRepositoryFake(),
            keychainRepository: KeychainRepositoryFake(),
            usageService: usageService,
            codexUsageService: codexUsageService,
            notificationService: NotificationServiceSpy()
        )
        appModel.isSetupComplete = true
        appModel.settings.isCodexUsageShown = false

        await appModel.refreshUsage(forceRefresh: true)

        XCTAssertEqual(appModel.usageData, expectedUsage)
        XCTAssertNil(appModel.codexUsageData)
        XCTAssertNil(appModel.codexErrorMessage)
    }

    func test_refreshingUsage_showsErrorWhenFetchFails() async {
        let failure = TestError(message: TestConstants.fetchFailureMessage)
        let usageService = UsageServiceStub(fetchUsageResult: .failure(failure))
        let notificationService = NotificationServiceSpy()
        let settingsRepository = SettingsRepositoryFake()
        let keychainRepository = KeychainRepositoryFake()

        let appModel = AppModel(
            settingsRepository: settingsRepository,
            keychainRepository: keychainRepository,
            usageService: usageService,
            notificationService: notificationService
        )

        appModel.isSetupComplete = true

        await appModel.refreshUsage(forceRefresh: false)

        XCTAssertNil(appModel.usageData)
        XCTAssertEqual(appModel.errorMessage, failure.localizedDescription)
        XCTAssertFalse(appModel.isRefreshing)
        XCTAssertFalse(appModel.isLoading)
        XCTAssertNil(notificationService.lastEvaluatedUsageData)
    }

    func test_refreshingUsage_hidesUsageWhenSetupIncomplete() async {
        let usageService = UsageServiceStub(fetchUsageResult: .failure(TestError(message: TestConstants.unexpectedErrorMessage)))
        let notificationService = NotificationServiceSpy()
        let settingsRepository = SettingsRepositoryFake()
        let keychainRepository = KeychainRepositoryFake()

        let appModel = AppModel(
            settingsRepository: settingsRepository,
            keychainRepository: keychainRepository,
            usageService: usageService,
            notificationService: notificationService
        )

        appModel.isSetupComplete = false
        appModel.usageData = makeUsageData(percentage: TestConstants.cachedPercentage)
        appModel.codexUsageData = makeCodexUsageData()
        appModel.codexErrorMessage = "Codex unavailable"
        appModel.errorMessage = TestConstants.previousErrorMessage

        await appModel.refreshUsage(forceRefresh: false)

        XCTAssertNil(appModel.usageData)
        XCTAssertNil(appModel.codexUsageData)
        XCTAssertNil(appModel.errorMessage)
        XCTAssertNil(appModel.codexErrorMessage)
        XCTAssertNil(notificationService.lastEvaluatedUsageData)
    }

    func test_userWithInvalidSessionKey_staysInSetup() async throws {
        let usageService = UsageServiceStub(
            fetchUsageResult: .failure(TestError(message: TestConstants.unexpectedErrorMessage)),
            isSessionKeyValid: false
        )
        let notificationService = NotificationServiceSpy()
        let settingsRepository = SettingsRepositoryFake()
        let keychainRepository = KeychainRepositoryFake()

        let appModel = AppModel(
            settingsRepository: settingsRepository,
            keychainRepository: keychainRepository,
            usageService: usageService,
            notificationService: notificationService
        )

        let result = try await appModel.validateAndSaveSessionKey(TestConstants.sessionKeyValue)

        XCTAssertFalse(result)
        XCTAssertFalse(appModel.isSetupComplete)
        XCTAssertTrue(appModel.settings.isFirstLaunch)
        XCTAssertNil(appModel.settings.cachedOrganizationId)
        XCTAssertNil(appModel.usageData)
    }

    func test_userWithValidSessionKey_entersUsageAndLoadsData() async throws {
        let expectedUsage = makeUsageData(percentage: TestConstants.sessionPercentage)
        let organization = Organization(
            id: 1,
            uuid: TestConstants.organizationUUIDString,
            name: "Test Org"
        )
        let usageService = UsageServiceStub(
            fetchUsageResult: .success(expectedUsage),
            organizations: [organization],
            isSessionKeyValid: true
        )
        let notificationService = NotificationServiceSpy()
        let settingsRepository = SettingsRepositoryFake()
        let keychainRepository = KeychainRepositoryFake()

        let appModel = AppModel(
            settingsRepository: settingsRepository,
            keychainRepository: keychainRepository,
            usageService: usageService,
            notificationService: notificationService
        )

        let result = try await appModel.validateAndSaveSessionKey(TestConstants.sessionKeyValue)

        XCTAssertTrue(result)
        XCTAssertTrue(appModel.isSetupComplete)
        XCTAssertFalse(appModel.settings.isFirstLaunch)
        XCTAssertEqual(
            appModel.settings.cachedOrganizationId,
            UUID(uuidString: TestConstants.organizationUUIDString)
        )
        XCTAssertEqual(appModel.usageData, expectedUsage)
    }

    func test_importingSessionKey_savesImportedKeyAndLoadsData() async throws {
        let expectedUsage = makeUsageData(percentage: TestConstants.sessionPercentage)
        let organization = Organization(
            id: 1,
            uuid: TestConstants.organizationUUIDString,
            name: "Test Org"
        )
        let usageService = UsageServiceStub(
            fetchUsageResult: .success(expectedUsage),
            organizations: [organization],
            isSessionKeyValid: true
        )
        let notificationService = NotificationServiceSpy()
        let settingsRepository = SettingsRepositoryFake()
        let keychainRepository = KeychainRepositoryFake()
        let importService = SessionKeyImportServiceStub(result: .success(ImportedSessionKey(
            value: TestConstants.sessionKeyValue,
            sourceDescription: "Chrome Default"
        )))

        let appModel = AppModel(
            settingsRepository: settingsRepository,
            keychainRepository: keychainRepository,
            usageService: usageService,
            notificationService: notificationService,
            sessionKeyImportService: importService
        )

        let imported = try await appModel.importAndSaveSessionKey()
        let savedKey = try await keychainRepository.retrieve(account: "default")

        XCTAssertEqual(imported.sourceDescription, "Chrome Default")
        XCTAssertEqual(savedKey, TestConstants.sessionKeyValue)
        XCTAssertTrue(appModel.isSetupComplete)
        XCTAssertEqual(appModel.usageData, expectedUsage)
    }

    func test_importingSessionKey_whenImportedKeyInvalid_staysInSetup() async throws {
        let usageService = UsageServiceStub(
            fetchUsageResult: .failure(TestError(message: TestConstants.unexpectedErrorMessage)),
            organizations: [],
            isSessionKeyValid: false
        )
        let notificationService = NotificationServiceSpy()
        let settingsRepository = SettingsRepositoryFake()
        let keychainRepository = KeychainRepositoryFake()
        let importService = SessionKeyImportServiceStub(result: .success(ImportedSessionKey(
            value: TestConstants.sessionKeyValue,
            sourceDescription: "Chrome Default"
        )))

        let appModel = AppModel(
            settingsRepository: settingsRepository,
            keychainRepository: keychainRepository,
            usageService: usageService,
            notificationService: notificationService,
            sessionKeyImportService: importService
        )

        do {
            _ = try await appModel.importAndSaveSessionKey()
            XCTFail("Expected invalidImportedSessionKey to be thrown")
        } catch SessionKeyImportError.invalidImportedSessionKey {
            XCTAssertFalse(appModel.isSetupComplete)
            XCTAssertNil(appModel.usageData)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func test_userWithValidSessionKeyWithoutOrganization_staysInSetup() async {
        let usageService = UsageServiceStub(
            fetchUsageResult: .failure(TestError(message: TestConstants.unexpectedErrorMessage)),
            organizations: [],
            isSessionKeyValid: true
        )
        let notificationService = NotificationServiceSpy()
        let settingsRepository = SettingsRepositoryFake()
        let keychainRepository = KeychainRepositoryFake()

        let appModel = AppModel(
            settingsRepository: settingsRepository,
            keychainRepository: keychainRepository,
            usageService: usageService,
            notificationService: notificationService
        )

        do {
            _ = try await appModel.validateAndSaveSessionKey(TestConstants.sessionKeyValue)
            XCTFail("Expected organizationNotFound to be thrown")
        } catch AppError.organizationNotFound {
            XCTAssertFalse(appModel.isSetupComplete)
            XCTAssertNil(appModel.usageData)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func test_userClearsSession_returnsToSetupState() async throws {
        let usageService = UsageServiceStub(fetchUsageResult: .failure(TestError(message: TestConstants.unexpectedErrorMessage)))
        let notificationService = NotificationServiceSpy()
        let settingsRepository = SettingsRepositoryFake()
        let keychainRepository = KeychainRepositoryFake()

        let appModel = AppModel(
            settingsRepository: settingsRepository,
            keychainRepository: keychainRepository,
            usageService: usageService,
            notificationService: notificationService
        )

        appModel.isSetupComplete = true
        appModel.usageData = makeUsageData(percentage: TestConstants.cachedPercentage)
        appModel.errorMessage = TestConstants.fetchFailureMessage

        var updatedSettings = appModel.settings
        updatedSettings.cachedOrganizationId = UUID(uuidString: TestConstants.organizationUUIDString)
        updatedSettings.isFirstLaunch = false
        appModel.settings = updatedSettings

        try await appModel.clearSessionKey()

        XCTAssertFalse(appModel.isSetupComplete)
        XCTAssertNil(appModel.usageData)
        XCTAssertNil(appModel.errorMessage)
        XCTAssertNil(appModel.settings.cachedOrganizationId)
        XCTAssertTrue(appModel.settings.isFirstLaunch)
    }

    func test_userWithNotificationPermission_doesNotSeePermissionPrompt() async {
        let usageService = UsageServiceStub(fetchUsageResult: .failure(TestError(message: TestConstants.unexpectedErrorMessage)))
        let notificationService = NotificationServiceSpy()
        notificationService.hasPermission = true
        let settingsRepository = SettingsRepositoryFake()
        let keychainRepository = KeychainRepositoryFake()

        let appModel = AppModel(
            settingsRepository: settingsRepository,
            keychainRepository: keychainRepository,
            usageService: usageService,
            notificationService: notificationService
        )

        await appModel.requestNotificationPermissionIfNeeded()

        XCTAssertEqual(notificationService.requestAuthorizationCallCount, 0)
    }

    func test_userWithoutNotificationPermission_isPromptedForPermission() async {
        let usageService = UsageServiceStub(fetchUsageResult: .failure(TestError(message: TestConstants.unexpectedErrorMessage)))
        let notificationService = NotificationServiceSpy()
        notificationService.hasPermission = false
        let settingsRepository = SettingsRepositoryFake()
        let keychainRepository = KeychainRepositoryFake()

        let appModel = AppModel(
            settingsRepository: settingsRepository,
            keychainRepository: keychainRepository,
            usageService: usageService,
            notificationService: notificationService
        )

        await appModel.requestNotificationPermissionIfNeeded()

        XCTAssertEqual(notificationService.requestAuthorizationCallCount, 1)
    }

    func test_userSendsTestNotification_triggersNotificationService() async throws {
        let usageService = UsageServiceStub(fetchUsageResult: .failure(TestError(message: TestConstants.unexpectedErrorMessage)))
        let notificationService = NotificationServiceSpy()
        let settingsRepository = SettingsRepositoryFake()
        let keychainRepository = KeychainRepositoryFake()

        let appModel = AppModel(
            settingsRepository: settingsRepository,
            keychainRepository: keychainRepository,
            usageService: usageService,
            notificationService: notificationService
        )

        try await appModel.sendTestNotification()

        XCTAssertEqual(notificationService.sentThresholdType, .warning)
        XCTAssertEqual(notificationService.sentThresholdPercentage, 85.0)
    }
}

// MARK: - Helpers

private func makeUsageData(percentage: Double) -> UsageData {
    let resetDate = Date().addingTimeInterval(TestConstants.oneHourInterval)
    let sessionUsage = UsageLimit(utilization: percentage, resetAt: resetDate)
    let weeklyUsage = UsageLimit(utilization: TestConstants.weeklyPercentage, resetAt: resetDate)

    return UsageData(
        sessionUsage: sessionUsage,
        weeklyUsage: weeklyUsage,
        sonnetUsage: nil,
        lastUpdated: Date()
    )
}

private func makeCodexUsageData() -> CodexUsageData {
    CodexUsageData(
        sessionUsage: UsageLimit(
            utilization: 32,
            resetAt: Date().addingTimeInterval(Constants.Pacing.sessionWindow)
        ),
        sessionWindowMinutes: 300,
        weeklyUsage: UsageLimit(
            utilization: 25,
            resetAt: Date().addingTimeInterval(Constants.Pacing.weeklyWindow)
        ),
        weeklyWindowMinutes: 10_080,
        planType: "plus",
        lastUpdated: Date()
    )
}
