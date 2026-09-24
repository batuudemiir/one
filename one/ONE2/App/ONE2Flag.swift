//
//  ONE2Flag.swift
//  ONE 2.0
//
//  Tek build, iki uygulama (ADR-001 §3). Bayrak açılışta bir kez okunur ve
//  süreç boyunca değişmez: iki kabuğun aynı oturumda yer değiştirmesi
//  desteklenmiyor. Değişiklik bir sonraki açılışta geçerli olur.
//
//  Varsayılan: DEBUG ve TestFlight'ta açık, App Store'da kapalı (relaunch'a
//  kadar). Elle geçersiz kılma `ONE2Enabled` anahtarıyla — Xcode'da launch
//  argument olarak da verilebilir: `-ONE2Enabled NO`.
//

import Foundation

nonisolated enum ONE2Flag {
    static let overrideKey = "ONE2Enabled"

    /// Süreç boyunca sabit.
    static let isEnabled: Bool = resolve(
        isDebug: isDebugBuild,
        isTestFlight: isTestFlightBuild,
        override: UserDefaults.standard.object(forKey: overrideKey) as? Bool
    )

    /// Geçersiz kılma varsa o, yoksa derleme ortamı.
    static func resolve(isDebug: Bool, isTestFlight: Bool, override: Bool?) -> Bool {
        if let override { return override }
        return isDebug || isTestFlight
    }

    /// Bir sonraki açılış için. `nil` varsayılana döner.
    static func setOverride(_ value: Bool?) {
        if let value {
            UserDefaults.standard.set(value, forKey: overrideKey)
        } else {
            UserDefaults.standard.removeObject(forKey: overrideKey)
        }
    }

    /// Geçersiz kılma ayarı yalnız geliştirme ve TestFlight'ta görünür.
    static var canOverride: Bool { isDebugBuild || isTestFlightBuild }

    static var isDebugBuild: Bool {
        #if DEBUG
        return true
        #else
        return false
        #endif
    }

    /// TestFlight build'lerinin makbuzu `sandboxReceipt` adını taşır.
    static var isTestFlightBuild: Bool {
        Bundle.main.appStoreReceiptURL?.lastPathComponent == "sandboxReceipt"
    }
}
