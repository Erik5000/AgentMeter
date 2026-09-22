import Foundation
import LocalAuthentication
import Security

enum KeychainItemQuery {
    static func password(
        account: String,
        service: String,
        usesDataProtectionKeychain: Bool = true
    ) -> [String: Any] {
        let authenticationContext = LAContext()
        authenticationContext.interactionNotAllowed = true

        return [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: account,
            kSecAttrService as String: service,
            kSecAttrSynchronizable as String: false,
            kSecUseDataProtectionKeychain as String: usesDataProtectionKeychain,
            kSecUseAuthenticationContext as String: authenticationContext,
        ]
    }

    static func lookup(
        account: String,
        service: String,
        returnData: Bool,
        usesDataProtectionKeychain: Bool = true
    ) -> [String: Any] {
        var query = password(
            account: account,
            service: service,
            usesDataProtectionKeychain: usesDataProtectionKeychain
        )
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        if returnData {
            query[kSecReturnData as String] = true
        }
        return query
    }

    static func add(
        account: String,
        service: String,
        data: Data,
        usesDataProtectionKeychain: Bool = true
    ) -> [String: Any] {
        var query = password(
            account: account,
            service: service,
            usesDataProtectionKeychain: usesDataProtectionKeychain
        )
        query[kSecValueData as String] = data
        query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        return query
    }
}
