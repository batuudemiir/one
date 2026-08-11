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

    /// Kurulum tarihi gibi, uygulama silinip yeniden kurulsa da korunması
    /// gereken tarihler için. `timeIntervalSinceReferenceDate` olarak yazılır.
    static func set(_ value: Date, forKey key: String) {
        var interval = value.timeIntervalSinceReferenceDate
        let data = withUnsafeBytes(of: &interval) { Data($0) }
        set(data, forKey: key)
    }

    static func date(forKey key: String) -> Date? {
        guard let data = get(forKey: key), data.count == MemoryLayout<Double>.size else { return nil }
        let interval = data.withUnsafeBytes { $0.loadUnaligned(as: Double.self) }
        return Date(timeIntervalSinceReferenceDate: interval)
    }

    static func set(_ value: String, forKey key: String) {
        set(Data(value.utf8), forKey: key)
    }

    static func string(forKey key: String) -> String? {
        guard let data = get(forKey: key) else { return nil }
        return String(data: data, encoding: .utf8)
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
            kSecAttrAccessible: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        SecItemDelete(query as CFDictionary)
        let status = SecItemAdd(query as CFDictionary, nil)
        if status != errSecSuccess {
            ONELogger.error("Keychain write failed for key '\(key)': OSStatus \(status)", category: .general)
        }
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
