//
//  KeychainHelper.swift
//  one
//
//  Minimal Keychain wrapper for persisting flags that survive app deletion.
//

import Foundation
import Security

enum KeychainHelper {

    private static let service = "com.batu.ones"

    static func set(_ value: Bool, forKey key: String) {
        let data = Data([value ? 1 : 0])
        set(data, forKey: key)
    }

    static func bool(forKey key: String) -> Bool {
        guard let data = get(forKey: key) else { return false }
        return data.first == 1
    }

    static func remove(forKey key: String) {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: key
        ]
        SecItemDelete(query as CFDictionary)
    }

    // MARK: - Private

    private static func set(_ data: Data, forKey key: String) {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: key,
            kSecValueData: data,
            kSecAttrAccessible: kSecAttrAccessibleAfterFirstUnlock
        ]
        SecItemDelete(query as CFDictionary)
        SecItemAdd(query as CFDictionary, nil)
    }

    private static func get(forKey key: String) -> Data? {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: key,
            kSecReturnData: true,
            kSecMatchLimit: kSecMatchLimitOne
        ]
        var result: AnyObject?
        SecItemCopyMatching(query as CFDictionary, &result)
        return result as? Data
    }
}
