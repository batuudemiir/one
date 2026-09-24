//
//  EngagementTracker.swift
//  one
//
//  Uygulama açılış / mood kayıt / oturum telemetrisini App Group shared
//  UserDefaults'a yazar. NotificationMessageBuilder ve planlayıcılar
//  bu veriden beslenir.
//

import Foundation

enum EngagementTracker {
    private static let suiteName = "group.com.batudemir.ones"
    private static var defaults: UserDefaults {
        UserDefaults(suiteName: suiteName) ?? .standard
    }

    private enum Key {
        static let lastOpenedDate       = "engagement.lastOpenedDate"
        static let sessionCount         = "engagement.sessionCount"
        static let lastMoodDate         = "engagement.lastMoodDate"
        static let lastMoodLabel        = "engagement.lastMoodLabel"
        static let lastMoodColorHex     = "engagement.lastMoodColorHex"
        static let recentMoodLabels     = "engagement.recentMoodLabels"
        static let lastKnownFriendCount = "engagement.lastKnownFriendCount"
        static let abBucket             = "engagement.abBucket"
        // Akıllı bildirim saati — açılış geçmişi
        static let openTimestampLog     = "engagement.openTimestampLog"   // [Double] — son 40 açılış
        static let firstLaunchDate      = "engagement.firstLaunchDate"    // Date — ilk kurulum
    }

    // MARK: - Sessions

    static func markOpened(_ date: Date = Date()) {
        // Geri dönüş kararı burada, lastOpenedDate güncellenmeden ÖNCE
        // verilmeli — sonra aradaki boşluk kaybolur ve ekran hiç açılmaz.
        evaluateComeback(now: date)
        defaults.set(date, forKey: Key.lastOpenedDate)
        defaults.set(sessionCount + 1, forKey: Key.sessionCount)
        recordOpenTimestamp(date)
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

    /// Geri dönüş ekranının eşiği. 7 gün: bir haftadan kısa aralar "dönüş"
    /// sayılmaz, kullanıcı zaten akıştadır ve ekstra bir ekran araya girmek
    /// gereksiz sürtünme olur.
    static let comebackThresholdDays = 7

    private static let comebackPendingKey = "engagement.comebackPending"
    private static let comebackDaysKey    = "engagement.comebackDays"

    /// `markOpened` içinden, `lastOpenedDate` güncellenmeden çağrılır.
    /// Kararı bir bayrağa yazar; UI o bayrağı okur. Böylece ekranın
    /// açılması view'ın ne zaman kurulduğuna bağlı olmaz.
    private static func evaluateComeback(now: Date) {
        guard let days = daysSinceLastOpen(now: now), days >= comebackThresholdDays else { return }
        defaults.set(true, forKey: comebackPendingKey)
        defaults.set(days, forKey: comebackDaysKey)
    }

    /// Bekleyen bir geri dönüş var mı? Kaç gün uzak kalındığını da döner.
    static var pendingComebackDays: Int? {
        guard defaults.bool(forKey: comebackPendingKey) else { return nil }
        return defaults.integer(forKey: comebackDaysKey)
    }

    /// Ekran gösterildikten sonra bayrağı düşür — aynı dönüşte tekrar çıkmasın.
    static func consumeComeback() {
        defaults.set(false, forKey: comebackPendingKey)
    }

    // MARK: - Akıllı Bildirim Saati

    /// İlk kurulum tarihi. **Keychain'de** tutulur: uygulama silinip yeniden
    /// kurulunca sıfırlanırsa "ilk 3 gün" aktivasyon penceresi ve ileride
    /// D14 paywall kapısı yanlış hesaplanır. UserDefaults'taki eski değer
    /// ilk okumada Keychain'e taşınır.
    static var firstLaunchDate: Date? {
        if let fromKeychain = KeychainHelper.date(forKey: Key.firstLaunchDate) {
            return fromKeychain
        }
        // One-time migration: UserDefaults → Keychain
        guard let legacy = defaults.object(forKey: Key.firstLaunchDate) as? Date else { return nil }
        KeychainHelper.set(legacy, forKey: Key.firstLaunchDate)
        defaults.removeObject(forKey: Key.firstLaunchDate)
        ONELogger.info("Migrated firstLaunchDate to Keychain", category: .general)
        return legacy
    }

    /// Kurulumdan bu yana geçen tam gün sayısı. Analytics'te global
    /// `days_since_install` property'si olarak her event'e ekleniyor.
    static var daysSinceInstall: Int? {
        guard let first = firstLaunchDate else { return nil }
        return Calendar.current.dateComponents(
            [.day], from: Calendar.current.startOfDay(for: first),
            to: Calendar.current.startOfDay(for: Date())
        ).day
    }

    /// Yeni açılışı timestamp log'a ekler; ilk açılışta firstLaunchDate'i set eder.
    private static func recordOpenTimestamp(_ date: Date) {
        if firstLaunchDate == nil {
            KeychainHelper.set(date, forKey: Key.firstLaunchDate)
        }
        var log = defaults.array(forKey: Key.openTimestampLog) as? [Double] ?? []
        log.append(date.timeIntervalSinceReferenceDate)
        if log.count > 40 { log = Array(log.suffix(40)) }
        defaults.set(log, forKey: Key.openTimestampLog)
    }

    // v4: `computeSmartReminderHour` + `stableJitterMinute` kaldırıldı.
    // Hatırlatma saatini kullanıcı seçer; uygulama açılış medyanına bakıp
    // randevuyu kendi başına kaydırmaz. Açılış log'u (`openTimestampLog`)
    // duruyor — gün/streak hesapları onu okuyor.

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

    // v4: nurture (D1/D2/D3) serisi kaldırıldı — `startNurtureIfNeeded` ve
    // `nurtureStartedAt` ile birlikte. Bkz. CLAUDE.md › Bildirim mimarisi.

    // MARK: - A/B Bucket

    static func abBucket(userID: String?, buckets: Int = 4) -> Int {
        if let existing = defaults.object(forKey: Key.abBucket) as? Int { return existing }
        let seed = userID ?? UUID().uuidString
        let bucket = abs(seed.hashValue) % buckets
        defaults.set(bucket, forKey: Key.abBucket)
        return bucket
    }
}
