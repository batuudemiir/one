//
//  AppleSignInService.swift
//  one
//
//  Sign in with Apple — launch-level zorunlu kimlik kapısı.
//
//  Kullanıcı bir kez Apple ID ile giriş yapar; stable `userIdentifier`
//  Keychain'e yazılır (uygulama silinse de kalır). Uygulama her açılışta
//  `ASAuthorizationAppleIDProvider.getCredentialState(forUserID:)` ile
//  durum kontrol edilir — revoked/notFound olursa gate tekrar çıkar.
//
//  CloudKit AppUser kaydına `appleUserID` / `appleEmail` / `appleFullName`
//  olarak yazılır (currentUser hazır olduğunda). Böylece ileride başka bir
//  backend'e taşımak istersen kimlik köprün var.
//

import Foundation
import AuthenticationServices
import Combine
import CloudKit
import CryptoKit

@MainActor
final class AppleSignInService: NSObject, ObservableObject {

    // MARK: - Types

    enum Status: Equatable {
        case unknown      // bootstrap devam ediyor
        case signedIn     // geçerli Apple kimliği var
        case needsSignIn  // ilk kurulum veya revoked/notFound
    }

    enum SignInError: Error {
        case cancelled
        case missingIdentifier
        case failed(Error)
    }

    // MARK: - Singleton

    static let shared = AppleSignInService()

    private override init() {
        // Cold start'ta gate flash'ını önlemek için keychain'i init'te oku:
        // ContentView ilk render olduğunda status doğru — `.unknown` sadece
        // teorik bir başlangıç değeri, hiçbir kod path'inde görünmüyor.
        if let id = KeychainHelper.string(forKey: Keys.userID), !id.isEmpty {
            self._status = Published(initialValue: .signedIn)
        } else {
            self._status = Published(initialValue: .needsSignIn)
        }
        super.init()
    }

    // MARK: - Keychain keys

    private enum Keys {
        static let userID   = "appleSignInUserID"
        static let email    = "appleSignInEmail"
        static let fullName = "appleSignInFullName"
    }

    // MARK: - State

    @Published private(set) var status: Status = .unknown

    /// Sign-in başarılı olduğunda ama CloudKit currentUser henüz nil ise
    /// oluşan tek seferlik senkronizasyonu tekrar denemek için observer.
    private var cloudKitSubscription: AnyCancellable?

    /// Nonce'u SwiftUI SignInWithAppleButton'ın `onRequest` callback'iyle
    /// ASAuthorizationController delegate'i arasında taşımak için tutuyoruz.
    private var currentNonce: String?

    /// Sign-in tamamlandığında çağrılan continuation — SwiftUI'dan async çağrılıyor.
    private var pendingContinuation: CheckedContinuation<Void, Error>?

    // MARK: - Bootstrap

    /// Uygulama açılışında bir kez çağrılır. Keychain'de userID varsa
    /// optimistic olarak `.signedIn` set eder — cold start'ta gate'in bir
    /// an flash etmesini önler. Ardından async `getCredentialState` ile
    /// gerçek durumu doğrular; revoked/notFound ise `.needsSignIn` düşer.
    func bootstrap() {
        guard let storedID = KeychainHelper.string(forKey: Keys.userID),
              !storedID.isEmpty else {
            status = .needsSignIn
            return
        }

        status = .signedIn
        observeCloudKitAndSync()

        let provider = ASAuthorizationAppleIDProvider()
        provider.getCredentialState(forUserID: storedID) { [weak self] state, _ in
            Task { @MainActor in
                guard let self else { return }
                switch state {
                case .authorized:
                    break
                case .revoked, .notFound, .transferred:
                    self.clearLocal()
                    self.status = .needsSignIn
                @unknown default:
                    break
                }
            }
        }
    }

    // MARK: - Sign in (SwiftUI button flow)

    /// SwiftUI `SignInWithAppleButton.onRequest` içinde çağrılır.
    func prepare(request: ASAuthorizationAppleIDRequest) {
        let nonce = Self.randomNonceString()
        currentNonce = nonce
        request.requestedScopes = [.fullName, .email]
        request.nonce = Self.sha256(nonce)
    }

    /// SwiftUI `SignInWithAppleButton.onCompletion` içinde çağrılır.
    func handle(result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let auth):
            guard let credential = auth.credential as? ASAuthorizationAppleIDCredential else {
                ONELogger.error("Apple credential wrong type", category: .general)
                return
            }
            persist(credential: credential)
            status = .signedIn
            observeCloudKitAndSync()
            AppAnalytics.shared.identify(
                userID: credential.user,
                properties: Experiment.analyticsProperties
            )
        case .failure(let error):
            // Kullanıcı iptal ederse sessiz geç — gate yerinde kalır.
            let nsError = error as NSError
            if nsError.code == ASAuthorizationError.canceled.rawValue { return }
            ONELogger.error("Apple sign-in failed", error: error, category: .general)
        }
    }

    // MARK: - Sign out (opsiyonel — debug / hesap silme)

    func signOut() {
        clearLocal()
        status = .needsSignIn
    }

    // MARK: - Persistence

    private func persist(credential: ASAuthorizationAppleIDCredential) {
        KeychainHelper.set(credential.user, forKey: Keys.userID)

        // Email + fullName YALNIZ ilk sign-in'de dolu gelir. Sonraki
        // girişlerde nil — Apple'ın gizlilik kontratı. Bu yüzden yazmadan
        // önce non-nil kontrolü + var olanı override etme.
        if let email = credential.email, !email.isEmpty {
            KeychainHelper.set(email, forKey: Keys.email)
        }
        if let name = credential.fullName {
            let formatter = PersonNameComponentsFormatter()
            formatter.style = .default
            let joined = formatter.string(from: name)
            if !joined.isEmpty {
                KeychainHelper.set(joined, forKey: Keys.fullName)
            }
        }
    }

    private func clearLocal() {
        KeychainHelper.remove(forKey: Keys.userID)
        KeychainHelper.remove(forKey: Keys.email)
        KeychainHelper.remove(forKey: Keys.fullName)
        cloudKitSubscription?.cancel()
        cloudKitSubscription = nil
    }

    // MARK: - CloudKit sync

    /// CloudKit currentUser hazır olduğu anda AppUser kaydına Apple
    /// kimlik alanlarını yaz. Hazırsa hemen; değilse Combine ile bekle.
    private func observeCloudKitAndSync() {
        cloudKitSubscription?.cancel()

        if CloudKitManager.shared.currentUser != nil {
            syncNow()
            return
        }

        cloudKitSubscription = CloudKitManager.shared.$currentUser
            .compactMap { $0 }
            .first()
            .sink { [weak self] _ in
                Task { @MainActor in self?.syncNow() }
            }
    }

    private func syncNow() {
        guard let record = CloudKitManager.shared.currentUser else { return }
        guard let appleID = KeychainHelper.string(forKey: Keys.userID) else { return }

        let existing = record["appleUserID"] as? String
        let newEmail = KeychainHelper.string(forKey: Keys.email)
        let newName  = KeychainHelper.string(forKey: Keys.fullName)

        var dirty = false
        if existing != appleID {
            record["appleUserID"] = appleID as CKRecordValue
            dirty = true
        }
        if let email = newEmail, (record["appleEmail"] as? String) != email {
            record["appleEmail"] = email as CKRecordValue
            dirty = true
        }
        if let name = newName, (record["appleFullName"] as? String) != name {
            record["appleFullName"] = name as CKRecordValue
            dirty = true
        }
        guard dirty else {
            cloudKitSubscription?.cancel()
            cloudKitSubscription = nil
            return
        }

        let op = CKModifyRecordsOperation(recordsToSave: [record], recordIDsToDelete: nil)
        op.savePolicy = .changedKeys
        op.qualityOfService = .userInitiated
        op.modifyRecordsResultBlock = { [weak self] result in
            Task { @MainActor in
                switch result {
                case .success:
                    ONELogger.success("Apple identity attached to AppUser", category: .cloudkit)
                    self?.cloudKitSubscription?.cancel()
                    self?.cloudKitSubscription = nil
                case .failure(let error):
                    // Şema henüz deploy edilmemiş olabilir (CKError 26).
                    // Sessizce logla — gate yine geçerli, sync sonra retry olur.
                    ONELogger.warning("Apple identity sync failed: \(error.localizedDescription)", category: .cloudkit)
                }
            }
        }
        CloudKitManager.shared.publicDatabase.add(op)
    }

    // MARK: - Nonce utilities

    private static func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remaining = length
        while remaining > 0 {
            var random: UInt8 = 0
            let status = SecRandomCopyBytes(kSecRandomDefault, 1, &random)
            guard status == errSecSuccess else { continue }
            if random < charset.count {
                result.append(charset[Int(random)])
                remaining -= 1
            }
        }
        return result
    }

    private static func sha256(_ input: String) -> String {
        let hashed = SHA256.hash(data: Data(input.utf8))
        return hashed.compactMap { String(format: "%02x", $0) }.joined()
    }
}
