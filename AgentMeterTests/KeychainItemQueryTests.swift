import XCTest
import Security
@testable import ClaudeMeter

final class KeychainItemQueryTests: XCTestCase {
    func test_passwordQuery_usesDataProtectionKeychainAndRefusesAuthUI() {
        let query = KeychainItemQuery.password(
            account: "default",
            service: AppIdentity.keychainService
        )

        XCTAssertEqual(query[kSecClass as String] as? NSString, kSecClassGenericPassword as NSString)
        XCTAssertEqual(query[kSecAttrAccount as String] as? String, "default")
        XCTAssertEqual(query[kSecAttrService as String] as? String, AppIdentity.keychainService)
        XCTAssertEqual(query[kSecUseDataProtectionKeychain as String] as? Bool, true)
        XCTAssertEqual(
            query[kSecUseAuthenticationUI as String] as? NSString,
            kSecUseAuthenticationUIFail as NSString
        )
        XCTAssertNil(query[kSecAttrAccessGroup as String])
        XCTAssertFalse(
            query.values.contains { "\($0)".contains("$(AppIdentifierPrefix)") }
        )
    }

    func test_lookupQuery_requestsASingleSecretWithoutPromptingUI() {
        let query = KeychainItemQuery.lookup(
            account: "default",
            service: AppIdentity.keychainService,
            returnData: true
        )

        XCTAssertEqual(query[kSecReturnData as String] as? Bool, true)
        XCTAssertEqual(query[kSecMatchLimit as String] as? NSString, kSecMatchLimitOne as NSString)
        XCTAssertEqual(query[kSecUseDataProtectionKeychain as String] as? Bool, true)
        XCTAssertEqual(
            query[kSecUseAuthenticationUI as String] as? NSString,
            kSecUseAuthenticationUIFail as NSString
        )
    }
}
