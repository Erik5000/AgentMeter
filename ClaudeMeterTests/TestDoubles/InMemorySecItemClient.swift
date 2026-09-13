import Foundation
import Security
@testable import ClaudeMeter

final class InMemorySecItemClient: SecItemClient, @unchecked Sendable {
    struct ItemKey: Hashable {
        var account: String
        var service: String
        var dataProtection: Bool
    }

    private let lock = NSLock()
    private var items: [ItemKey: Data] = [:]
    private(set) var copyMatchingCount = 0
    private(set) var addCount = 0
    private(set) var updateCount = 0
    private(set) var deleteCount = 0

    func seed(account: String, service: String, dataProtection: Bool, value: String) {
        lock.lock()
        defer { lock.unlock() }
        items[ItemKey(account: account, service: service, dataProtection: dataProtection)] =
            Data(value.utf8)
    }

    func storedValue(account: String, service: String, dataProtection: Bool) -> String? {
        lock.lock()
        defer { lock.unlock() }
        guard let data = items[ItemKey(account: account, service: service, dataProtection: dataProtection)] else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }

    func add(_ attributes: [String: Any]) -> OSStatus {
        lock.lock()
        defer { lock.unlock() }
        addCount += 1
        let key = itemKey(from: attributes)
        guard items[key] == nil else { return errSecDuplicateItem }
        guard let data = attributes[kSecValueData as String] as? Data else {
            return errSecParam
        }
        items[key] = data
        return errSecSuccess
    }

    func copyMatching(_ query: [String: Any]) -> (OSStatus, Data?) {
        lock.lock()
        defer { lock.unlock() }
        copyMatchingCount += 1
        let key = itemKey(from: query)
        guard let data = items[key] else { return (errSecItemNotFound, nil) }
        if boolValue(query[kSecReturnData as String]) {
            return (errSecSuccess, data)
        }
        return (errSecSuccess, nil)
    }

    func update(query: [String: Any], attributes: [String: Any]) -> OSStatus {
        lock.lock()
        defer { lock.unlock() }
        updateCount += 1
        let key = itemKey(from: query)
        guard items[key] != nil else { return errSecItemNotFound }
        guard let data = attributes[kSecValueData as String] as? Data else {
            return errSecParam
        }
        items[key] = data
        return errSecSuccess
    }

    func delete(_ query: [String: Any]) -> OSStatus {
        lock.lock()
        defer { lock.unlock() }
        deleteCount += 1
        let key = itemKey(from: query)
        guard items.removeValue(forKey: key) != nil else { return errSecItemNotFound }
        return errSecSuccess
    }

    private func itemKey(from query: [String: Any]) -> ItemKey {
        ItemKey(
            account: query[kSecAttrAccount as String] as? String ?? "",
            service: query[kSecAttrService as String] as? String ?? "",
            dataProtection: boolValue(query[kSecUseDataProtectionKeychain as String])
        )
    }

    private func boolValue(_ value: Any?) -> Bool {
        switch value {
        case let value as Bool:
            return value
        case let value as NSNumber:
            return value.boolValue
        default:
            return false
        }
    }
}
