//
//  AppLockManager.swift
//  one
//
//  Uygulama kilidi — Face ID / Touch ID / cihaz parolası.
//
//  Profil'deki "Uygulama kilidi" anahtarı uzun süre yalnız bir `@AppStorage`
//  yazıyordu; hiçbir yer onu okumuyordu. Anahtarı açan kullanıcı korunduğunu
//  sanıyordu — bu güvenlik açığından öte bir güven sorunuydu.
//
//  Davranış:
//   - Kilit açıkken uygulama ön plana geldiğinde (cold start dahil) kilitlenir.
//   - Arka plana giderken içerik hemen gizlenir (App Switcher önizlemesinde
//     anlar görünmesin).
//   - Kısa geri dönüşler için `graceInterval` toleransı var: paylaşım
//     sheet'inden ya da fotoğraf seçiciden dönerken tekrar Face ID sormaz.
//   - Biyometri yoksa/başarısızsa cihaz parolasına düşer
//     (`deviceOwnerAuthentication`).
//   - Donanım hiçbir doğrulamayı desteklemiyorsa kilit kendini kapatır;
//     kullanıcıyı uygulamanın dışında bırakmaz.
//

import Foundation
import LocalAuthentication
import Combine
import UIKit

@MainActor
final class AppLockManager: ObservableObject {
    static let shared = AppLockManager()

    /// Profil anahtarıyla aynı UserDefaults anahtarı.
    static let enabledKey = "v3.settings.appLock"

    /// Kilit ekranı gösteriliyor mu.
    @Published private(set) var isLocked = false
    /// Doğrulama uçuşta — buton iki kez tetiklenmesin.
    @Published private(set) var isAuthenticating = false
    /// Son denemede kullanıcıya gösterilecek hata (nil = hata yok).
    @Published private(set) var lastError: String?

    /// Arka planda bu süreden kısa kalındıysa tekrar sorma.
    private let graceInterval: TimeInterval = 20
    private var backgroundedAt: Date?

    private init() {}

    var isEnabled: Bool {
        UserDefaults.standard.bool(forKey: Self.enabledKey)
    }

    /// Cihaz herhangi bir doğrulama yöntemi sunuyor mu (biyometri **veya**
    /// parola). Anahtar açılmadan önce sorulur.
    static func isAvailable() -> Bool {
        var error: NSError?
        return LAContext().canEvaluatePolicy(.deviceOwnerAuthentication, error: &error)
    }

    /// Kullanılabilir biyometri türünün adı — ayar satırındaki alt metin için.
    static func biometryLabel() -> String? {
        let context = LAContext()
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: nil) else { return nil }
        switch context.biometryType {
        case .faceID:  return "Face ID"
        case .touchID: return "Touch ID"
        case .opticID: return "Optic ID"
        default:       return nil
        }
    }

    // MARK: - Lifecycle

    /// Uygulama açılışında çağrılır.
    func handleLaunch() {
        guard isEnabled else { return }
        isLocked = true
    }

    func handleWillResignActive() {
        guard isEnabled else { return }
        backgroundedAt = Date()
        // İçeriği hemen kapat — App Switcher anlık görüntüsü boş kalsın.
        isLocked = true
    }

    func handleDidBecomeActive() {
        guard isEnabled else {
            isLocked = false
            return
        }
        // Kısa dönüşte (share sheet, foto seçici) tekrar sorma.
        if let since = backgroundedAt, Date().timeIntervalSince(since) < graceInterval {
            isLocked = false
            backgroundedAt = nil
            return
        }
        backgroundedAt = nil
        authenticate()
    }

    /// Anahtar açıldığında/kapandığında çağrılır.
    func settingChanged(to enabled: Bool) {
        if enabled {
            // Açar açmaz bir kez doğrula — kullanıcı yöntemin çalıştığını
            // görsün, kilidi ilk kez uygulamayı kapattığında keşfetmesin.
            authenticate()
        } else {
            isLocked = false
            lastError = nil
        }
    }

    // MARK: - Authentication

    func authenticate() {
        guard !isAuthenticating else { return }

        let context = LAContext()
        context.localizedFallbackTitle = ""   // Sistem "Parola gir" sunar.

        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            // Cihazda ne biyometri ne parola var — kullanıcıyı dışarıda
            // bırakmak yerine kilidi kapat ve ayarı geri al.
            UserDefaults.standard.set(false, forKey: Self.enabledKey)
            isLocked = false
            lastError = nil
            return
        }

        isAuthenticating = true
        lastError = nil

        context.evaluatePolicy(
            .deviceOwnerAuthentication,
            localizedReason: "Anlarını açmak için kimliğini doğrula."
        ) { [weak self] success, evalError in
            Task { @MainActor in
                guard let self else { return }
                self.isAuthenticating = false
                if success {
                    self.isLocked = false
                    self.lastError = nil
                } else {
                    self.isLocked = true
                    self.lastError = Self.message(for: evalError)
                }
            }
        }
    }

    private static func message(for error: Error?) -> String? {
        guard let code = (error as? LAError)?.code else { return nil }
        switch code {
        case .userCancel, .systemCancel, .appCancel:
            return nil                       // İptal hata değil — sessiz kal.
        case .userFallback:
            return nil
        case .biometryLockout:
            return "Çok fazla deneme oldu. Cihaz parolanla aç."
        case .biometryNotEnrolled, .biometryNotAvailable:
            return "Biyometri kullanılamıyor. Cihaz parolanla aç."
        default:
            return "Doğrulanamadı. Tekrar dene."
        }
    }
}
