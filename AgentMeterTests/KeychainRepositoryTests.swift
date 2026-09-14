import XCTest
@testable import AgentMeter

final class KeychainRepositoryTests: XCTestCase {
    private let account = "default"
    private let modernService = "com.erik5000.AgentMeter.sessionkey"
    private let legacyService = "com.claudemeter.sessionkey"

    func test_save_storesInDataProtectionKeychain() async throws {
        let secItem = InMemorySecItemClient()
        let repository = repository(secItem: secItem)

        try await repository.save(sessionKey: TestConstants.sessionKeyValue, account: account)

        XCTAssertEqual(
            secItem.storedValue(account: account, service: modernService, dataProtection: true),
            TestConstants.sessionKeyValue
        )
        XCTAssertNil(secItem.storedValue(account: account, service: modernService, dataProtection: false))
        XCTAssertFalse(secItem.queriedServices.contains(legacyService))
    }

    func test_retrieve_doesNotHitKeychainAgainAfterFirstRead() async throws {
        let secItem = InMemorySecItemClient()
        secItem.seed(
            account: account,
            service: modernService,
            dataProtection: true,
            value: TestConstants.sessionKeyValue
        )
        let repository = repository(secItem: secItem)

        _ = try await repository.retrieve(account: account)
        let firstCount = secItem.copyMatchingCount
        _ = try await repository.retrieve(account: account)
        _ = await repository.exists(account: account)

        XCTAssertEqual(secItem.copyMatchingCount, firstCount)
    }

    func test_retrieve_doesNotReadFileBasedOrLegacyItems() async {
        let secItem = InMemorySecItemClient()
        secItem.seed(
            account: account,
            service: modernService,
            dataProtection: false,
            value: TestConstants.sessionKeyValue
        )
        secItem.seed(
            account: account,
            service: legacyService,
            dataProtection: false,
            value: TestConstants.sessionKeyValue
        )
        let repository = repository(secItem: secItem)

        do {
            _ = try await repository.retrieve(account: account)
            XCTFail("Expected the file-based ClaudeMeter item to be ignored")
        } catch KeychainError.notFound {
            XCTAssertFalse(secItem.queriedServices.contains(legacyService))
            XCTAssertEqual(secItem.queriedServices, [modernService])
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func test_exists_isFalseForLegacyClaudeMeterItem() async {
        let secItem = InMemorySecItemClient()
        secItem.seed(
            account: account,
            service: legacyService,
            dataProtection: false,
            value: TestConstants.sessionKeyValue
        )
        let repository = repository(secItem: secItem)

        let exists = await repository.exists(account: account)

        XCTAssertFalse(exists)
        XCTAssertFalse(secItem.queriedServices.contains(legacyService))
    }

    func test_delete_doesNotRemoveLegacyClaudeMeterItem() async throws {
        let secItem = InMemorySecItemClient()
        let repository = repository(secItem: secItem)
        try await repository.save(sessionKey: TestConstants.sessionKeyValue, account: account)
        secItem.seed(
            account: account,
            service: legacyService,
            dataProtection: false,
            value: TestConstants.sessionKeyValue
        )

        try await repository.delete(account: account)

        XCTAssertNil(secItem.storedValue(account: account, service: modernService, dataProtection: true))
        XCTAssertEqual(
            secItem.storedValue(account: account, service: legacyService, dataProtection: false),
            TestConstants.sessionKeyValue
        )
    }

    private func repository(secItem: InMemorySecItemClient) -> KeychainRepository {
        KeychainRepository(secItem: secItem, serviceName: modernService)
    }
}
