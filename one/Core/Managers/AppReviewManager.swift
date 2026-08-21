//
//  AppReviewManager.swift
//  one
//
//  Puan isteme: 3. gün, 2. giriş, müzik anı sonrasında (tek seferlik).
//  Diğer triggerlar (streak, arkadaş) için de 60 gün cooldown uygulanır.
//

import StoreKit
import UIKit

final class AppReviewManager {
    static let shared = AppReviewManager()
    private init() {}

    private let lastPromptKey        = "appReviewLastPromptDate"
    private let primaryPromptDoneKey = "appReviewPrimaryDone"
    private let minDaysBetweenPrompts: TimeInterval = 60 * 86400

    // MARK: - Primary trigger
    // Koşul: 3+ farklı gün girişi olan kullanıcı, 2. girişini kaydetti → müzik anı bitince sor.

    func evaluateAfterSave(totalEntryCount: Int, uniqueDayCount: Int) {
        // İlk tetikleme: 3. gün, 2+ giriş, henüz gösterilmedi.
        guard !UserDefaults.standard.bool(forKey: primaryPromptDoneKey) else { return }
        guard uniqueDayCount >= 3, totalEntryCount >= 2 else { return }

        UserDefaults.standard.set(true, forKey: primaryPromptDoneKey)
        UserDefaults.standard.set(Date(), forKey: lastPromptKey)
        requestReview(delay: 1.5)
    }

    // MARK: - Secondary triggers (streak milestone, first friend)

    func logStreakMilestone(_ days: Int) {
        guard days == 7 || days == 14 || days == 30 else { return }
        requestReviewIfCooldownPassed()
    }

    func logFirstFriendAdded() {
        requestReviewIfCooldownPassed()
    }

    // MARK: - App Store page (manual)

    func openAppStorePage() {
        guard let url = URL(string: "itms-apps://itunes.apple.com/app/id\(ONEConfig.appStoreID)?action=write-review") else { return }
        if UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
        } else if let fallback = URL(string: ONEConfig.appStoreURL) {
            UIApplication.shared.open(fallback)
        }
    }

    // MARK: - Private

    private func requestReviewIfCooldownPassed() {
        let last = UserDefaults.standard.object(forKey: lastPromptKey) as? Date ?? .distantPast
        guard Date().timeIntervalSince(last) >= minDaysBetweenPrompts else { return }
        UserDefaults.standard.set(Date(), forKey: lastPromptKey)
        requestReview(delay: 1.5)
    }

    private func requestReview(delay: Double) {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            guard let scene = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .first else { return }
            AppStore.requestReview(in: scene)
        }
    }
}
