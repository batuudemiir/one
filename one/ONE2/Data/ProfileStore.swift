//
//  ProfileStore.swift
//  ONE 2.0
//
//  Kişiselleştirme profili (04_arka_plan_motorlari.md › E12). Adı dokümanda
//  `UserProfileStore`; v3'te aynı adlı bir sınıf olduğu için burada
//  `ProfileStore`.
//
//  Kaynak `NSUbiquitousKeyValueStore` (cihazlar arası), ayna App Group
//  UserDefaults (widget ve eklentiler okur). Her alan ayrı anahtarda: KVS
//  anahtar başına birleştirir, iki cihaz farklı alanları değiştirirse ikisi de
//  kalır. Profil değişince `didChange` yayınlanır ve `revision` artar;
//  E2/E4/E7 kuyrukları bunu geçersizlik sinyali sayar.
//

import Foundation
import Observation

/// Anahtar-değer deposu soyutlaması (KVS, UserDefaults, test belleği).
protocol KeyValueBacking: AnyObject {
    func object(forKey key: String) -> Any?
    func set(_ value: Any?, forKey key: String)
}

extension UserDefaults: KeyValueBacking {}

extension NSUbiquitousKeyValueStore: KeyValueBacking {}

/// Testler için bellekte depo.
final class MemoryKeyValueStore: KeyValueBacking {
    private(set) var values: [String: Any] = [:]
    func object(forKey key: String) -> Any? { values[key] }
    func set(_ value: Any?, forKey key: String) { values[key] = value }
}

/// Saat:dakika (hatırlatma saatleri). Metin biçimi `HH:mm`.
nonisolated struct ReminderTime: Hashable, Sendable, Comparable, CustomStringConvertible {
    let hour: Int
    let minute: Int

    init?(hour: Int, minute: Int) {
        guard (0..<24).contains(hour), (0..<60).contains(minute) else { return nil }
        self.hour = hour; self.minute = minute
    }

    init?(_ string: String) {
        let parts = string.split(separator: ":")
        guard parts.count == 2, let h = Int(parts[0]), let m = Int(parts[1]) else { return nil }
        self.init(hour: h, minute: m)
    }

    var description: String { String(format: "%02d:%02d", hour, minute) }
    var minutesSinceMidnight: Int { hour * 60 + minute }

    static func < (a: ReminderTime, b: ReminderTime) -> Bool { a.minutesSinceMidnight < b.minutesSinceMidnight }
}

nonisolated struct UserProfile: Hashable, Sendable {
    var name: String?
    /// Onboarding odakları (`kaygi`, `odak`, `minnet`, `uyku`, `iliskiler`).
    var focusAreas: [String] = []
    /// Seçilen söz yolları. İlki ücretsiz kullanıcının "+1 yol"u (04 › karar 4).
    var quotePaths: [String] = []
    var ritualMode: RitualMode = .daily
    var morningTime: ReminderTime = ReminderTime(hour: 8, minute: 30)!
    var eveningTime: ReminderTime = ReminderTime(hour: 21, minute: 30)!
    var streakVisible = true
    /// E2.2 kural 4: yazılan söz 90 gün sonra akışa dönebilir. Varsayılan açık (04 › karar 3).
    var resurfaceWritten = true
    /// Günün sözü ve akış tohumu; ilk açılışta üretilir, cihazlar arası aynı.
    var userSalt: UUID
    var contentLang = "tr"

    /// Ücretsiz kullanıcının açık yolu.
    var freeQuotePath: String? { quotePaths.first }
}

@Observable
final class ProfileStore {
    static let didChange = Notification.Name("one2.profile.didChange")

    enum Key {
        static let name = "profile.name"
        static let focusAreas = "profile.focusAreas"
        static let quotePaths = "profile.quotePaths"
        static let ritualMode = "profile.ritualMode"
        static let morningTime = "profile.morningTime"
        static let eveningTime = "profile.eveningTime"
        static let streakVisible = "profile.streakVisible"
        static let resurfaceWritten = "profile.resurfaceWritten"
        static let userSalt = "profile.userSalt"
        static let contentLang = "profile.contentLang"

        static let all = [name, focusAreas, quotePaths, ritualMode, morningTime, eveningTime,
                          streakVisible, resurfaceWritten, userSalt, contentLang]
    }

    private(set) var profile: UserProfile
    /// Her değişiklikte artar; motorlar önbellek anahtarına katar.
    private(set) var revision = 0

    @ObservationIgnored private let cloud: KeyValueBacking
    @ObservationIgnored private let local: KeyValueBacking
    @ObservationIgnored private var observer: NSObjectProtocol?

    init(cloud: KeyValueBacking = NSUbiquitousKeyValueStore.default,
         local: KeyValueBacking = UserDefaults(suiteName: "group.com.batudemir.ones") ?? .standard) {
        self.cloud = cloud
        self.local = local
        profile = Self.read(cloud: cloud, local: local)
        persistSaltIfNeeded()
        if let kvs = cloud as? NSUbiquitousKeyValueStore {
            observer = NotificationCenter.default.addObserver(
                forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification, object: kvs, queue: .main
            ) { [weak self] _ in
                MainActor.assumeIsolated { self?.reloadFromCloud() }
            }
            kvs.synchronize()
        }
    }

    deinit {
        if let observer { NotificationCenter.default.removeObserver(observer) }
    }

    /// Profili değiştirir; yalnız değişen anahtarlar yazılır.
    func update(_ mutate: (inout UserProfile) -> Void) {
        var next = profile
        mutate(&next)
        next.userSalt = profile.userSalt // tuz kullanıcıdan değişmez
        guard next != profile else { return }
        let changed = Self.encode(next).filter { key, value in
            !Self.equal(Self.encode(profile)[key], value)
        }
        for (key, value) in changed {
            cloud.set(value, forKey: key)
            local.set(value, forKey: key)
        }
        profile = next
        announce(Set(changed.keys))
    }

    /// Başka cihazdan gelen değişiklik (KVS dış değişim bildirimi).
    func reloadFromCloud() {
        let incoming = Self.read(cloud: cloud, local: local, fallbackSalt: profile.userSalt)
        // Tuz çakışması: iki cihaz ilk açılışta ayrı tuz ürettiyse küçük olan
        // kazanır; herkes aynı sonuca varır.
        var resolved = incoming
        let (a, b) = (incoming.userSalt, profile.userSalt)
        resolved.userSalt = a.uuidString < b.uuidString ? a : b
        if resolved.userSalt != incoming.userSalt { cloud.set(resolved.userSalt.uuidString, forKey: Key.userSalt) }
        local.set(resolved.userSalt.uuidString, forKey: Key.userSalt)
        guard resolved != profile else { return }
        let before = Self.encode(profile)
        let changed = Self.encode(resolved).filter { !Self.equal(before[$0.key], $0.value) }.keys
        for key in Key.all where key != Key.userSalt { local.set(cloud.object(forKey: key), forKey: key) }
        profile = resolved
        announce(Set(changed))
    }

    // MARK: - Private

    private func announce(_ keys: Set<String>) {
        revision += 1
        NotificationCenter.default.post(name: Self.didChange, object: self, userInfo: ["keys": keys])
    }

    private func persistSaltIfNeeded() {
        let salt = profile.userSalt.uuidString
        if cloud.object(forKey: Key.userSalt) as? String != salt { cloud.set(salt, forKey: Key.userSalt) }
        if local.object(forKey: Key.userSalt) as? String != salt { local.set(salt, forKey: Key.userSalt) }
    }

    /// Önce bulut, yoksa yerel ayna; geçersiz değer varsayılana düşer.
    private static func read(cloud: KeyValueBacking, local: KeyValueBacking, fallbackSalt: UUID? = nil) -> UserProfile {
        func value(_ key: String) -> Any? { cloud.object(forKey: key) ?? local.object(forKey: key) }
        let salt = (value(Key.userSalt) as? String).flatMap(UUID.init(uuidString:)) ?? fallbackSalt ?? UUID()
        var p = UserProfile(userSalt: salt)
        if let name = value(Key.name) as? String, !name.isEmpty { p.name = name }
        if let areas = value(Key.focusAreas) as? [String] { p.focusAreas = areas }
        if let paths = value(Key.quotePaths) as? [String] { p.quotePaths = paths }
        if let mode = (value(Key.ritualMode) as? String).flatMap(RitualMode.init(rawValue:)) { p.ritualMode = mode }
        if let t = (value(Key.morningTime) as? String).flatMap(ReminderTime.init) { p.morningTime = t }
        if let t = (value(Key.eveningTime) as? String).flatMap(ReminderTime.init) { p.eveningTime = t }
        if let v = value(Key.streakVisible) as? Bool { p.streakVisible = v }
        if let v = value(Key.resurfaceWritten) as? Bool { p.resurfaceWritten = v }
        if let lang = value(Key.contentLang) as? String, !lang.isEmpty { p.contentLang = lang }
        return p
    }

    private static func encode(_ p: UserProfile) -> [String: Any?] {
        [
            Key.name: p.name,
            Key.focusAreas: p.focusAreas,
            Key.quotePaths: p.quotePaths,
            Key.ritualMode: p.ritualMode.rawValue,
            Key.morningTime: p.morningTime.description,
            Key.eveningTime: p.eveningTime.description,
            Key.streakVisible: p.streakVisible,
            Key.resurfaceWritten: p.resurfaceWritten,
            Key.userSalt: p.userSalt.uuidString,
            Key.contentLang: p.contentLang,
        ]
    }

    private static func equal(_ a: Any??, _ b: Any?) -> Bool {
        let lhs: Any? = a ?? nil
        switch (lhs, b) {
        case (nil, nil): return true
        case let (x as NSObject, y as NSObject): return x.isEqual(y)
        default: return false
        }
    }
}
