import XCTest
import Security
@testable import ClaudeMeter

final class KeychainItemQueryTests: XCTestCase {
    func test_passwordQuery_usesDataProtectionKeychainAndOmitsAccessGroup() {
        let query = KeychainItemQuery.password(
            account: "default",
            service: AppIdentity.keychainService,
            dataProtection: true
        )

        XCTAssertEqual(query[kSecClass as String] as? NSString, kSecClassGenericPassword as NSString)
        XCTAssertEqual(query[kSecAttrAccount as String] as? String, "default")
        XCTAssertEqual(query[kSecAttrService as String] as? String, AppIdentity.keychainService)
        XCTAssertEqual(query[kSecUseDataProtectionKeychain as String] as? Bool, true)
        XCTAssertNil(query[kSecAttrAccessGroup as String])
        XCTAssertFalse(
            query.values.contains { "\($0)".contains("$(AppIdentifierPrefix)") }
        )
    }

    func test_fileBasedPasswordQuery_omitsDataProtectionKey() {
        let query = KeychainItemQuery.password(
            account: "default",
            service: "com.claudemeter.sessionkey",
            dataProtection: false
        )

        XCTAssertNil(query[kSecUseDataProtectionKeychain as String])
        XCTAssertNil(query[kSecAttrAccessGroup as String])
        XCTAssertEqual(query[kSecAttrService as String] as? String, "com.claudemeter.sessionkey")
    }

    func test_lookupQuery_requestsASingleSecretWithoutPromptingUI() {
        let query = KeychainItemQuery.lookup(
            account: "default",
            service: AppIdentity.keychainService,
            returnData: true,
            dataProtection: true
        )

        XCTAssertEqual(query[kSecReturnData as String] as? Bool, true)
        XCTAssertEqual(query[kSecMatchLimit as String] as? NSString, kSecMatchLimitOne as NSString)
        XCTAssertEqual(query[kSecUseDataProtectionKeychain as String] as? Bool, true)
        XCTAssertNil(query[kSecUseAuthenticationUI as String])
    }
}
