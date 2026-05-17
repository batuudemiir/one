//
//  AppReviewManager.swift
//  one
//
//  App Store review prompt — triggers after meaningful engagement
//

import StoreKit
import UIKit
import Combine

final class AppReviewManager {
    static let shared = AppReviewManager()
    private init() {}

    private let lastPromptKey = "appReviewLastPromptDate"
    private let songCountKey = "appReviewSongCount"
    private let minDaysBetweenPrompts: TimeInterval = 60 * 86400 // 60 days
    private let minSongsBeforePrompt = 5

    /// Call after a meaningful event (song saved, streak milestone, etc.)
    func logSongSaved() {
        let count = UserDefaults.standard.integer(forKey: songCountKey) + 1
        UserDefaults.standard.set(count, forKey: songCountKey)

        if count >= minSongsBeforePrompt {
            requestReviewIfEligible()
        }
    }

    /// Call when the user successfully adds their first friend
    func logFirstFriendAdded() {
        requestReviewIfEligible()
    }

    /// Call when the user hits a streak milestone (7, 14, 30 days)
    func logStreakMilestone(_ days: Int) {
        guard days == 7 || days == 14 || days == 30 else { return }
        requestReviewIfEligible()
    }

    /// Directly opens App Store review page as fallback (used by "Uygulamayı Değerlendir" button)
    func openAppStorePage() {
        guard let url = URL(string: "itms-apps://itunes.apple.com/app/id\(ONETokens.appStoreID)?action=write-review") else { return }
        if UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
        } else if let fallback = URL(string: ONETokens.appStoreURL) {
            UIApplication.shared.open(fallback)
        }
    }

    private func requestReviewIfEligible() {
        let lastPrompt = UserDefaults.standard.object(forKey: lastPromptKey) as? Date ?? .distantPast
        guard Date().timeIntervalSince(lastPrompt) >= minDaysBetweenPrompts else { return }

        UserDefaults.standard.set(Date(), forKey: lastPromptKey)

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            guard let scene = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .first else { return }
            AppStore.requestReview(in: scene)
        }
    }
}
