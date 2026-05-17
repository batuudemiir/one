//
//  AppUpdateChecker.swift
//  one
//
//  iTunes Lookup API ile App Store'daki güncel sürümü kontrol eder.
//

import Foundation
import Combine
import UIKit

final class AppUpdateChecker: ObservableObject {
    static let shared = AppUpdateChecker()

    /// Bu sürümün altındaki kullanıcılar uygulamayı kullanamaz — zorla güncelleme.
    /// Yeni sürüm yayınlarken bu değeri yeni sürüm numarasıyla güncelle.
    static let minimumRequiredVersion = "2.2"

    // SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor makes all members implicitly @MainActor,
    // which breaks ObservableObject synthesis. Declare objectWillChange nonisolated so
    // SwiftUI can observe it from any actor context.
    nonisolated(unsafe) var objectWillChange = ObservableObjectPublisher()

    var updateAvailable = false {
        willSet { objectWillChange.send() }
    }
    /// Zorunlu güncelleme — kullanıcı devam edemez, App Store'a yönlendirilir.
    var forceUpdate = false {
        willSet { objectWillChange.send() }
    }
    var appStoreVersion: String = "" {
        willSet { objectWillChange.send() }
    }

    private let bundleID = "com.batudemir.ones"
    private let lookupURL = "https://itunes.apple.com/lookup?bundleId=com.batudemir.ones&country=tr"

    /// Mevcut yüklü sürüm (CFBundleShortVersionString)
    var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0"
    }

    private init() {}

    func check() {
        guard let url = URL(string: lookupURL) else { return }

        URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
            guard let self,
                  let data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let results = json["results"] as? [[String: Any]],
                  let first = results.first,
                  let storeVersion = first["version"] as? String else { return }

            Task { @MainActor in
                self.appStoreVersion = storeVersion
                self.updateAvailable = storeVersion.isNewerThan(self.currentVersion)
                if self.updateAvailable {
                    ONELogger.info("App Store'da yeni sürüm: \(storeVersion) (yüklü: \(self.currentVersion))", category: .general)
                    NotificationManager.shared.scheduleAppUpdateNotification(newVersion: storeVersion)
                }
            }
        }.resume()
    }

    func openAppStore() {
        // App Store ürün sayfası — App ID ile güncelle
        guard let url = URL(string: "https://apps.apple.com/app/id6743296937") else { return }
        Task { @MainActor in
            await UIApplication.shared.open(url)
        }
    }
}

// MARK: - Version Comparison

private extension String {
    /// "2.1.0".isNewerThan("1.9.3") → true
    func isNewerThan(_ other: String) -> Bool {
        let lhs = components(separatedBy: ".").compactMap { Int($0) }
        let rhs = other.components(separatedBy: ".").compactMap { Int($0) }
        let maxLen = max(lhs.count, rhs.count)
        for i in 0..<maxLen {
            let l = i < lhs.count ? lhs[i] : 0
            let r = i < rhs.count ? rhs[i] : 0
            if l != r { return l > r }
        }
        return false
    }
}
