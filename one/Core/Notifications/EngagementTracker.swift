//
//  EngagementTracker.swift
//  one
//
//  Uygulama açılış / mood kayıt / oturum telemetrisini App Group shared
//  UserDefaults'a yazar. WinBackScheduler ve NotificationMessageBuilder
//  bu veriden beslenir.
//

import Foundation

enum EngagementTracker {
    private static let suiteName = "group.com.batudemir.ones"
    private static var defaults: UserDefaults {
        UserDefaults(suiteName: suiteName) ?? .standard
    }

    private enum Key {
        static let lastOpenedDate   = "engagement.lastOpenedDate"
        static let sessionCount     = "engagement.sessionCount"
        static let lastMoodDate     = "engagement.lastMoodDate"
        static let lastMoodLabel    = "engagement.lastMoodLabel"
        static let lastMoodColorHex = "engagement.lastMoodColorHex"
        static let recentMoodLabels = "engagement.recentMoodLabels"   // B6 — son 7 mood label rolling
        static let lastKnownStreak  = "engagement.lastKnownStreak"    // B3 — push kişiselleştirme için
        static let lastKnownFriendCount = "engagement.lastKnownFriendCount"  // B4 — Day-4 circle gating
        static let nurtureStartedAt = "engagement.nurtureStartedAt"
        static let abBucket         = "engagement.abBucket"
    }

    // MARK: - Sessions

    static func markOpened(_ date: Date = Date()) {
        defaults.set(date, forKey: Key.lastOpenedDate)
        defaults.set(sessionCount + 1, forKey: Key.sessionCount)
    }

    static var lastOpenedDate: Date? {
        defaults.object(forKey: Key.lastOpenedDate) as? Date
    }

    static var sessionCount: Int {
        defaults.integer(forKey: Key.sessionCount)
    }

    static func daysSinceLastOpen(now: Date = Date()) -> Int? {
        guard let last = lastOpenedDate else { return nil }
        return Calendar.current.dateComponents([.day], from: last, to: now).day
    }

    // MARK: - Mood

    static func markMoodSaved(label: String?, colorHex: String?, date: Date = Date()) {
        defaults.set(date, forKey: Key.lastMoodDate)
        if let label { defaults.set(label, forKey: Key.lastMoodLabel) }
        if let colorHex { defaults.set(colorHex, forKey: Key.lastMoodColorHex) }

        // B6 — son 7 mood label'ı rolling olarak tut (en yenisi başta).
        if let label {
            var rolling = defaults.array(forKey: Key.recentMoodLabels) as? [String] ?? []
            rolling.insert(label, at: 0)
            if rolling.count > 7 { rolling = Array(rolling.prefix(7)) }
            defaults.set(rolling, forKey: Key.recentMoodLabels)
        }
    }

    /// B6 — Son N mood label'ı (en yenisi başta). Push kişiselleştirme için.
    static func recentMoodLabels(limit: Int = 3) -> [String] {
        let arr = defaults.array(forKey: Key.recentMoodLabels) as? [String] ?? []
        return Array(arr.prefix(limit))
    }

    /// B3 — Son hesaplanmış streak (push planlama anında okunur).
    static var lastKnownStreak: Int {
        get { defaults.integer(forKey: Key.lastKnownStreak) }
        set { defaults.set(newValue, forKey: Key.lastKnownStreak) }
    }

    /// B4 — Son bilinen arkadaş sayısı (Day-4 circle invite push'unu gate'ler).
    static var lastKnownFriendCount: Int {
        get { defaults.integer(forKey: Key.lastKnownFriendCount) }
        set { defaults.set(newValue, forKey: Key.lastKnownFriendCount) }
    }

    static var lastMoodDate: Date? {
        defaults.object(forKey: Key.lastMoodDate) as? Date
    }

    static var lastMoodLabel: String? {
        defaults.string(forKey: Key.lastMoodLabel)
    }

    static var lastMoodColorHex: String? {
        defaults.string(forKey: Key.lastMoodColorHex)
    }

    static var savedMoodToday: Bool {
        guard let last = lastMoodDate else { return false }
        return Calendar.current.isDateInToday(last)
    }

    // MARK: - Nurture

    static func startNurtureIfNeeded(_ date: Date = Date()) {
        guard defaults.object(forKey: Key.nurtureStartedAt) == nil else { return }
        defaults.set(date, forKey: Key.nurtureStartedAt)
    }

    static var nurtureStartedAt: Date? {
        defaults.object(forKey: Key.nurtureStartedAt) as? Date
    }

    // MARK: - A/B Bucket

    static func abBucket(userID: String?, buckets: Int = 4) -> Int {
        if let existing = defaults.object(forKey: Key.abBucket) as? Int { return existing }
        let seed = userID ?? UUID().uuidString
        let bucket = abs(seed.hashValue) % buckets
        defaults.set(bucket, forKey: Key.abBucket)
        return bucket
    }
}
