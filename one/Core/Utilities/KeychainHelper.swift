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

    /// "Şu adım tamamlandı" bayrakları için okuma.
    ///
    /// Farkı `bool(forKey:)`'den: Keychain okunamadığında (cihaz kilitli)
    /// `false` değil **`true`** varsayar. Bu bayraklar onboarding ve profil
    /// oluşturma akışlarını kapatıyor; okunamadı diye `false` dönmek, kurulumu
    /// çoktan bitirmiş kullanıcıyı onboarding'e geri atıyor. Bir kez fazla
    /// atlamak, tamamlanmış kurulumu sıfırlamaktan çok daha ucuz.
    static func completionFlag(forKey key: String) -> Bool {
        switch read(forKey: key) {
        case .found(let data):  return data.first == 1
        case .notFound:         return false
        case .unavailable:      return true
        }
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

    /// Erişilebilirlik sınıfı.
    ///
    /// Eskiden `WhenUnlockedThisDeviceOnly`'ydi ve bu sessiz bir hata
    /// kaynağıydı: cihaz kilitliyken okuma `errSecInteractionNotAllowed`
    /// döndürüyor. Widget zamanlaması ya da bildirim uygulamayı kilitliyken
    /// uyandırdığında `hasCompletedOnboarding` gibi bayraklar okunamıyor,
    /// `false` görünüyor ve kullanıcı onboarding'e düşebiliyordu.
    ///
    /// `AfterFirstUnlockThisDeviceOnly` arka plan erişimini açıyor; cihaz
    /// açılıştan sonra bir kez kilidi açıldıysa okunabilir. `ThisDeviceOnly`
    /// korunuyor — bu bayraklar yedeğe ya da başka cihaza gitmemeli.
    private static let accessibility = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly

    private static func baseQuery(forKey key: String) -> [CFString: Any] {
        [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: key
        ]
    }

    /// Add-or-update. Eskiden sil-sonra-ekle yapılıyordu; iki çağrı arasında
    /// süreç ölürse bayrak tamamen kayboluyordu — "uygulama silinse de kalsın"
    /// amacının tam tersi. `errSecDuplicateItem`'da güncellemek atomik.
    private static func set(_ data: Data, forKey key: String) {
        var addQuery = baseQuery(forKey: key)
        addQuery[kSecValueData] = data
        addQuery[kSecAttrAccessible] = accessibility

        let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
        switch addStatus {
        case errSecSuccess:
            return
        case errSecDuplicateItem:
            let attributes: [CFString: Any] = [
                kSecValueData: data,
                kSecAttrAccessible: accessibility
            ]
            let updateStatus = SecItemUpdate(
                baseQuery(forKey: key) as CFDictionary,
                attributes as CFDictionary
            )
            if updateStatus != errSecSuccess {
                ONELogger.error("Keychain update failed for key '\(key)': OSStatus \(updateStatus)", category: .general)
            }
        default:
            ONELogger.error("Keychain write failed for key '\(key)': OSStatus \(addStatus)", category: .general)
        }
    }

    /// Okuma sonucu.
    ///
    /// `Data?` yetmiyordu: "kayıt yok" ile "şu an okuyamadım" aynı `nil`e
    /// düşüyor ve çağıran ikisini ayırt edemiyordu. Kilitli cihazda okunamayan
    /// bir bayrağı "hiç yazılmamış" saymak yanlış kararlar ürettiriyor.
    enum ReadResult {
        case found(Data)
        case notFound
        /// Cihaz kilitli ya da başka bir geçici engel — kayıt **var olabilir**.
        case unavailable(OSStatus)
    }

    static func read(forKey key: String) -> ReadResult {
        var query = baseQuery(forKey: key)
        query[kSecReturnData] = true
        query[kSecMatchLimit] = kSecMatchLimitOne

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        switch status {
        case errSecSuccess:
            guard let data = result as? Data else { return .notFound }
            return .found(data)
        case errSecItemNotFound:
            return .notFound
        case errSecInteractionNotAllowed:
            // Yıkıcı davranma: kayıt duruyor, yalnız şu an erişilemiyor.
            ONELogger.warning("Keychain okunamadı (cihaz kilitli): '\(key)'", category: .general)
            return .unavailable(status)
        default:
            ONELogger.error("Keychain read failed for key '\(key)': OSStatus \(status)", category: .general)
            return .unavailable(status)
        }
    }

    private static func get(forKey key: String) -> Data? {
        if case .found(let data) = read(forKey: key) { return data }
        return nil
    }
}
