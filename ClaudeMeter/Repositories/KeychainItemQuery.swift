import Foundation
import Security

enum KeychainItemQuery {
    static func password(account: String, service: String, dataProtection: Bool) -> [String: Any] {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: account,
            kSecAttrService as String: service,
            kSecAttrSynchronizable as String: false,
        ]
        if dataProtection {
            query[kSecUseDataProtectionKeychain as String] = true
        }
        return query
    }

    static func lookup(
        account: String,
        service: String,
        returnData: Bool,
        dataProtection: Bool
    ) -> [String: Any] {
        var query = password(account: account, service: service, dataProtection: dataProtection)
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        if returnData {
            query[kSecReturnData as String] = true
        }
        return query
    }

    static func add(account: String, service: String, data: Data) -> [String: Any] {
        var query = password(account: account, service: service, dataProtection: true)
        query[kSecValueData as String] = data
        query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        return query
    }
}
