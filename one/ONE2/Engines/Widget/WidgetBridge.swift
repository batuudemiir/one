//
//  WidgetBridge.swift
//  ONE 2.0
//
//  Widget veri yazıcı (04_arka_plan_motorlari.md › E14, ADR-001 §9). App
//  Group UserDefaults'a sürümlü `w2_*` anahtarları yazar; widget yalnız
//  okur (widget'tan veri yazma yok). v3 `WidgetDataWriter` deseni: tek yazan
//  yer, yazdıktan sonra `MoodWidget` zaman çizelgesi tazelenir.
//
//  | Anahtar            | İçerik                                             |
//  |--------------------|----------------------------------------------------|
//  | `w2_dailyQuote`    | Günün sözü: id, metin, kaynak                      |
//  | `w2_dailyQuoteNext`| Ertesi günün sözü (gece yarısı widget kendisi geçer)|
//  | `w2_week`          | Bu ISO haftanın 7 günü: durum, bugün mü, gelecek mi |
//  | `w2_streak`        | Seri sayısı ve görünürlük                          |
//  | `w2_todayCheckin`  | Bugünkü son check-in: skor, etiket, yankı cümlesi   |
//  | `w2_theme`         | Tema adı ve günün sorusu                           |
//  | `w2_version`       | Şema sürümü                                        |
//
//  Tetik: her kayıt, gün değişimi, içerik güncellemesi.
//

import Foundation
import WidgetKit

nonisolated struct WidgetQuote: Codable, Equatable, Sendable {
    let id: String
    let text: String
    /// "Yazar, Eser" ya da boş.
    let source: String?
    /// Günü (`yyyy-MM-dd`): widget ertesi günün sözüne gece yarısı geçer.
    let day: String
}

nonisolated struct WidgetWeekDay: Codable, Equatable, Sendable {
    enum Status: String, Codable, Sendable { case none, half, full }
    let day: String
    let status: Status
    let isToday: Bool
    let isFuture: Bool
}

nonisolated struct WidgetStreak: Codable, Equatable, Sendable {
    let count: Int
    let visible: Bool
    let atRisk: Bool
}

nonisolated struct WidgetCheckIn: Codable, Equatable, Sendable {
    let score: Int
    let label: String?
    let echo: String?
}

nonisolated struct WidgetTheme: Codable, Equatable, Sendable {
    let title: String
    let prompt: String?
}

nonisolated struct WidgetSnapshotV2: Equatable, Sendable {
    static let version = 1

    var dailyQuote: WidgetQuote?
    var dailyQuoteNext: WidgetQuote?
    var week: [WidgetWeekDay] = []
    var streak: WidgetStreak?
    var todayCheckIn: WidgetCheckIn?
    var theme: WidgetTheme?

    enum Key {
        static let dailyQuote = "w2_dailyQuote"
        static let dailyQuoteNext = "w2_dailyQuoteNext"
        static let week = "w2_week"
        static let streak = "w2_streak"
        static let todayCheckIn = "w2_todayCheckin"
        static let theme = "w2_theme"
        static let version = "w2_version"
        static let all = [dailyQuote, dailyQuoteNext, week, streak, todayCheckIn, theme, version]
    }

    /// Bu ISO haftanın 7 günü.
    static func week(_ completions: [DayCompletion], mode: RitualMode, today: DayKey) -> [WidgetWeekDay] {
        let byDay = Dictionary(completions.map { ($0.day, $0) }, uniquingKeysWith: { a, _ in a })
        return ISOWeek(containing: today).days.map { d in
            let status: WidgetWeekDay.Status = switch byDay[d]?.status(in: mode) ?? DayStatus.none {
            case .none: .none
            case .half: .half
            case .full: .full
            }
            return WidgetWeekDay(day: d.string, status: status, isToday: d == today, isFuture: d > today)
        }
    }

    static func quote(_ q: Quote?, day: DayKey) -> WidgetQuote? {
        guard let q else { return nil }
        let source = [q.author, q.source].compactMap { $0 }.joined(separator: ", ")
        return WidgetQuote(id: q.id, text: q.text, source: source.isEmpty ? nil : source, day: day.string)
    }
}

final class WidgetBridge {
    private let backing: KeyValueBacking
    private let reload: () -> Void

    init(backing: KeyValueBacking = UserDefaults(suiteName: WidgetDataWriter.appGroupID) ?? .standard,
         reload: @escaping () -> Void = { WidgetCenter.shared.reloadTimelines(ofKind: "MoodWidget") }) {
        self.backing = backing
        self.reload = reload
    }

    /// Anlık görüntüyü yazar; değişmeyen anahtara dokunmaz, bir şey değiştiyse
    /// widget'ı tazeler. Yazılan anahtarları döner.
    @discardableResult
    func write(_ s: WidgetSnapshotV2) -> [String] {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        func data<T: Encodable>(_ v: T?) -> Data? { v.flatMap { try? encoder.encode($0) } }
        let values: [String: Data?] = [
            WidgetSnapshotV2.Key.dailyQuote: data(s.dailyQuote),
            WidgetSnapshotV2.Key.dailyQuoteNext: data(s.dailyQuoteNext),
            WidgetSnapshotV2.Key.week: data(s.week),
            WidgetSnapshotV2.Key.streak: data(s.streak),
            WidgetSnapshotV2.Key.todayCheckIn: data(s.todayCheckIn),
            WidgetSnapshotV2.Key.theme: data(s.theme),
        ]
        var changed: [String] = []
        for (key, value) in values where (backing.object(forKey: key) as? Data) != value {
            backing.set(value, forKey: key)
            changed.append(key)
        }
        if backing.object(forKey: WidgetSnapshotV2.Key.version) as? Int != WidgetSnapshotV2.version {
            backing.set(WidgetSnapshotV2.version, forKey: WidgetSnapshotV2.Key.version)
            changed.append(WidgetSnapshotV2.Key.version)
        }
        if !changed.isEmpty { reload() }
        return changed.sorted()
    }

    func read<T: Decodable>(_ key: String, as: T.Type) -> T? {
        (backing.object(forKey: key) as? Data).flatMap { try? JSONDecoder().decode(T.self, from: $0) }
    }
}

/// Motorlardan widget anlık görüntüsünü kurar.
final class WidgetSnapshotSource {
    private let quotes: LiveQuoteEngine
    private let prompts: LivePromptEngine
    private let content: ContentRepository
    private let day: DayStore
    private let mood: MoodStore
    private let exposure: ExposureStore
    private let profile: ProfileStore
    private let clock: AppClock

    init(quotes: LiveQuoteEngine, prompts: LivePromptEngine, content: ContentRepository, day: DayStore,
         mood: MoodStore, exposure: ExposureStore, profile: ProfileStore, clock: AppClock) {
        self.quotes = quotes; self.prompts = prompts; self.content = content; self.day = day
        self.mood = mood; self.exposure = exposure; self.profile = profile; self.clock = clock
    }

    func snapshot() async -> WidgetSnapshotV2 {
        let today = clock.today
        let p = profile.profile
        let catalog = content.catalog
        var s = WidgetSnapshotV2()
        s.dailyQuote = WidgetSnapshotV2.quote(await quotes.dailyQuote(for: today), day: today)
        s.dailyQuoteNext = WidgetSnapshotV2.quote(quotes.previewDailyQuote(for: today.adding(days: 1)), day: today.adding(days: 1))
        let week = ISOWeek(containing: today)
        s.week = WidgetSnapshotV2.week((try? day.completions(from: week.days.first ?? today, through: week.days.last ?? today)) ?? [],
                                       mode: p.ritualMode, today: today)
        if let state = try? day.streakState(mode: p.ritualMode, visible: p.streakVisible) {
            s.streak = WidgetStreak(count: state.count, visible: state.isVisible, atRisk: state.atRisk)
        }
        if let last = (try? mood.logs(on: today))?.last {
            let label = last.emotionIDs.first.flatMap { id in catalog.emotions.first { $0.id == id }?.label }
            s.todayCheckIn = WidgetCheckIn(score: last.score, label: label, echo: todaysEcho(catalog))
        }
        if let theme = ThemeCalendar.theme(for: today, catalog: catalog, salt: p.userSalt) {
            s.theme = WidgetTheme(title: theme.theme.title, prompt: await prompts.dailyPrompt(for: today)?.text)
        }
        return s
    }

    /// Bugün gösterilen son yankı cümlesi (E6).
    private func todaysEcho(_ catalog: ContentCatalog) -> String? {
        let records = (try? exposure.snapshot(.echo)).map { Array($0.records.values) } ?? []
        let todays = records.filter { r in r.lastSeenAt.map { DayKey(date: $0, calendar: clock.calendar) == clock.today } ?? false }
        guard let latest = todays.max(by: { ($0.lastSeenAt ?? .distantPast) < ($1.lastSeenAt ?? .distantPast) }) else { return nil }
        return catalog.echoes.first { $0.id == latest.contentID }?.text
    }
}
