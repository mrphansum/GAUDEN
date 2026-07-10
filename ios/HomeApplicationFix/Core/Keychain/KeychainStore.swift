/**
 KeychainStore — lưu secret an toàn (token, không dùng UserDefaults).

 Giải thích:
 - kSecClassGenericPassword + service/account.
 - accessibleAfterFirstUnlockThisDeviceOnly: đủ cho app foreground + refresh nền nhẹ.
 - Không bật biometric (theo yêu cầu).
 */
import Foundation
import Security

enum KeychainStore {
    static let service = "com.mrphansum.homeapplicationfix.keychain"

    enum Key: String {
        case accessToken
        case refreshToken
        case refreshExpiresAt
    }

    @discardableResult
    static func set(_ value: String, for key: Key) -> Bool {
        guard let data = value.data(using: .utf8) else { return false }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key.rawValue
        ]
        SecItemDelete(query as CFDictionary)
        var add = query
        add[kSecValueData as String] = data
        add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        return SecItemAdd(add as CFDictionary, nil) == errSecSuccess
    }

    static func get(_ key: Key) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key.rawValue,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess,
              let data = item as? Data,
              let str = String(data: data, encoding: .utf8) else {
            return nil
        }
        return str
    }

    static func delete(_ key: Key) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key.rawValue
        ]
        SecItemDelete(query as CFDictionary)
    }

    static func clearAll() {
        Key.allCases.forEach { delete($0) }
    }
}

extension KeychainStore.Key: CaseIterable {}
