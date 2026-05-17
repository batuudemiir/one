//
//  BadgeManager.swift
//  one
//
//  Persistent badge unlock + toast broadcast
//

import Foundation
import Combine

@MainActor
final class BadgeManager: ObservableObject {
    static let shared = BadgeManager()

    @Published private(set) var unlocked: Set<BadgeID> = []
    @Published var pendingToast: Badge? = nil

    private let storageKey = "one.badges.unlocked"
    private let dateKeyPrefix = "one.badges.unlockedAt."

    private init() {
        load()
    }

    // MARK: - Queries

    func isUnlocked(_ id: BadgeID) -> Bool { unlocked.contains(id) }

    func unlockedAt(_ id: BadgeID) -> Date? {
        UserDefaults.standard.object(forKey: dateKeyPrefix + id.rawValue) as? Date
    }

    // MARK: - Unlock

    /// Idempotent unlock — first time fires analytics + toast; subsequent calls are no-ops.
    func unlock(_ id: BadgeID) {
        guard !unlocked.contains(id) else { return }
        unlocked.insert(id)
        UserDefaults.standard.set(Date(), forKey: dateKeyPrefix + id.rawValue)
        persist()
        AppAnalytics.shared.track(.badgeUnlocked(id: id.rawValue))
        ONELogger.success("Badge unlocked: \(id.rawValue)", category: .general)
        pendingToast = BadgeCatalog.badge(for: id)
    }

    // MARK: - Event evaluators

    func evaluateStreak(_ streak: Int) {
        if streak >= 3   { unlock(.streak3) }
        if streak >= 7   { unlock(.streak7) }
        if streak >= 14  { unlock(.streak14) }
        if streak >= 30  { unlock(.streak30) }
        if streak >= 100 { unlock(.streak100) }
    }

    func evaluateFriendCount(_ count: Int) {
        if count >= 1 { unlock(.firstFriend) }
        if count >= 5 { unlock(.fiveFriends) }
    }

    func evaluateTimeBasedBadges(hour: Int) {
        // Gece kuşu: 00:00 - 04:00 arası giriş (0, 1, 2, 3)
        if hour >= 0 && hour < 4 {
            unlock(.nightOwl)
        }
        // Erken kuş: 05:00 - 08:00 arası giriş (5, 6, 7)
        if hour >= 5 && hour < 8 {
            unlock(.earlyBird)
        }
    }

    func evaluateEntryCount(_ total: Int) {
        if total >= 1  { unlock(.firstShare) }
        if total >= 7  { unlock(.totalEntry7) }
        if total >= 30 { unlock(.totalEntry30) }
    }

    // MARK: - Persistence

    private func load() {
        guard let raw = UserDefaults.standard.array(forKey: storageKey) as? [String] else { return }
        unlocked = Set(raw.compactMap(BadgeID.init(rawValue:)))
    }

    private func persist() {
        let raw = unlocked.map(\.rawValue)
        UserDefaults.standard.set(raw, forKey: storageKey)
    }
}
