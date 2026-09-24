//
//  InsightsEngine.swift
//  ONE 2.0
//
//  İçgörü motoru, temel set (04_arka_plan_motorlari.md › E10). Hesaplar saf
//  (`Insights`); `InsightsEngine` depolardan dönem verisini okur, sonucu
//  dönem başına bellekte tutar ve veri değişince önbelleği boşaltır.
//
//  | İçgörü                     | Minimum veri   |
//  |----------------------------|----------------|
//  | Mood çizgisi               | 3 check-in     |
//  | Ortalama ve değişim        | 7 check-in     |
//  | Duygu dağılımı             | 5 check-in     |
//  | Etiket (neden) ilişkisi    | 21 check-in; etiket başına ≥ 5 örnek |
//  | Yazma istatistiği          | 1 girdi        |
//  | Günün saati                | 10 kayıt       |
//  | Söz temaları               | 5 etkileşim    |
//  | Geçen yıl/ay bugün         | 1 eşleşme      |
//  | Değişim çiftleri           | 2 cevap        |
//
//  Minimum veri yoksa `.insufficient(needed:)`: kart "Henüz erken" durumuna
//  düşer. Yılın özeti (Aralık) temel sete dahil değil.
//

import Foundation
import CoreData

nonisolated enum InsightState<Value: Sendable & Equatable>: Sendable, Equatable {
    case ready(Value)
    /// `needed`: bu içgörü için gereken toplam; `have`: şu anki sayı.
    case insufficient(needed: Int, have: Int)

    var value: Value? { if case .ready(let v) = self { return v } else { return nil } }
}

nonisolated enum InsightPeriod: Int, CaseIterable, Sendable {
    case days14 = 14, days30 = 30, days90 = 90, days365 = 365

    func range(endingAt today: DayKey) -> ClosedRange<DayKey> {
        today.adding(days: -(rawValue - 1))...today
    }

    func previousRange(endingAt today: DayKey) -> ClosedRange<DayKey> {
        today.adding(days: -(2 * rawValue - 1))...today.adding(days: -rawValue)
    }
}

nonisolated struct MoodPoint: Equatable, Sendable {
    let day: DayKey
    let average: Double
    let count: Int
}

nonisolated struct AverageChange: Equatable, Sendable {
    let average: Double
    /// Önceki dönem yetersizse `nil`.
    let previousAverage: Double?
    var delta: Double? { previousAverage.map { average - $0 } }
}

nonisolated struct Share: Equatable, Sendable {
    let id: String
    let count: Int
    /// 0–1.
    let ratio: Double
}

nonisolated struct EmotionDistribution: Equatable, Sendable {
    let families: [Share]
    let emotions: [Share]
}

/// "Uyku etiketli günlerde ortalama 2,8, diğerlerinde 3,6" — gözlem dili.
nonisolated struct CauseRelation: Equatable, Sendable {
    let causeID: String
    let withAverage: Double
    let withoutAverage: Double
    let samples: Int
}

nonisolated struct WritingStats: Equatable, Sendable {
    let entries: Int
    let words: Int
    let longestStreak: Int
    let topKind: EntryKind?
}

nonisolated struct HourDistribution: Equatable, Sendable {
    /// 24 kova, saat → sayı.
    let checkIns: [Int]
    let entries: [Int]
}

nonisolated struct ChangePair: Equatable, Sendable {
    let ref: String
    let earlier: UUID
    let later: UUID
    let daysApart: Int
}

nonisolated enum Insights {
    static let minMoodLine = 3
    static let minAverage = 7
    static let minDistribution = 5
    static let minCauseRelation = 21
    static let minCauseSamples = 5
    static let minHours = 10
    static let minQuoteInteractions = 5

    static func moodLine(_ logs: [MoodCheckIn], period: InsightPeriod, today: DayKey) -> InsightState<[MoodPoint]> {
        let range = period.range(endingAt: today)
        let inRange = logs.filter { range.contains($0.day) && $0.score > 0 }
        guard inRange.count >= minMoodLine else { return .insufficient(needed: minMoodLine, have: inRange.count) }
        let points = Dictionary(grouping: inRange, by: \.day).map { day, group in
            MoodPoint(day: day, average: Double(group.map(\.score).reduce(0, +)) / Double(group.count), count: group.count)
        }.sorted { $0.day < $1.day }
        return .ready(points)
    }

    static func averageChange(_ logs: [MoodCheckIn], period: InsightPeriod, today: DayKey) -> InsightState<AverageChange> {
        let current = logs.filter { period.range(endingAt: today).contains($0.day) && $0.score > 0 }
        guard current.count >= minAverage else { return .insufficient(needed: minAverage, have: current.count) }
        let previous = logs.filter { period.previousRange(endingAt: today).contains($0.day) && $0.score > 0 }
        return .ready(AverageChange(average: mean(current.map(\.score)),
                                    previousAverage: previous.count >= minAverage ? mean(previous.map(\.score)) : nil))
    }

    static func emotionDistribution(_ logs: [MoodCheckIn], period: InsightPeriod, today: DayKey,
                                    familyOf: (String) -> String?) -> InsightState<EmotionDistribution> {
        let inRange = logs.filter { period.range(endingAt: today).contains($0.day) }
        guard inRange.count >= minDistribution else { return .insufficient(needed: minDistribution, have: inRange.count) }
        let emotions = inRange.flatMap(\.emotionIDs)
        return .ready(EmotionDistribution(families: shares(emotions.compactMap(familyOf)), emotions: shares(emotions)))
    }

    /// Neden etiketleriyle skor ilişkisi; yalnız ≥ 5 örnekli etiketler, fark büyükten küçüğe.
    static func causeRelations(_ logs: [MoodCheckIn], period: InsightPeriod, today: DayKey) -> InsightState<[CauseRelation]> {
        let inRange = logs.filter { period.range(endingAt: today).contains($0.day) && $0.score > 0 }
        guard inRange.count >= minCauseRelation else { return .insufficient(needed: minCauseRelation, have: inRange.count) }
        let causes = Set(inRange.flatMap(\.causeIDs))
        let relations: [CauseRelation] = causes.compactMap { cause in
            let with = inRange.filter { $0.causeIDs.contains(cause) }
            let without = inRange.filter { !$0.causeIDs.contains(cause) }
            guard with.count >= minCauseSamples, !without.isEmpty else { return nil }
            return CauseRelation(causeID: cause, withAverage: mean(with.map(\.score)),
                                 withoutAverage: mean(without.map(\.score)), samples: with.count)
        }
        return .ready(relations.sorted {
            (abs($0.withAverage - $0.withoutAverage), $1.causeID) > (abs($1.withAverage - $1.withoutAverage), $0.causeID)
        })
    }

    static func writing(_ entries: [JournalEntry], days: [DayCompletion], mode: RitualMode) -> InsightState<WritingStats> {
        guard !entries.isEmpty else { return .insufficient(needed: 1, have: 0) }
        let kinds = Dictionary(grouping: entries, by: \.kind).mapValues(\.count)
        let top = kinds.max { ($0.value, $1.key.rawValue) < ($1.value, $0.key.rawValue) }?.key
        return .ready(WritingStats(entries: entries.count, words: entries.map(\.wordCount).reduce(0, +),
                                   longestStreak: Streak.longest(completed: Streak.completedDays(days, mode: mode)),
                                   topKind: top))
    }

    static func hours(_ logs: [MoodCheckIn], _ entries: [JournalEntry], calendar: Calendar) -> InsightState<HourDistribution> {
        let total = logs.count + entries.count
        guard total >= minHours else { return .insufficient(needed: minHours, have: total) }
        var c = [Int](repeating: 0, count: 24), e = [Int](repeating: 0, count: 24)
        for l in logs { c[calendar.component(.hour, from: l.timestamp)] += 1 }
        for x in entries { e[calendar.component(.hour, from: x.createdAt)] += 1 }
        return .ready(HourDistribution(checkIns: c, entries: e))
    }

    /// En çok beğenilen ve yazılan söz temaları (yazma ×2).
    static func quoteThemes(_ exposure: ExposureSnapshot, catalog: ContentCatalog) -> InsightState<[Share]> {
        let interactions = exposure.records.values.filter { $0.liked || $0.wasWritten }
        guard interactions.count >= minQuoteInteractions else {
            return .insufficient(needed: minQuoteInteractions, have: interactions.count)
        }
        var weighted: [String] = []
        for r in interactions {
            guard let q = catalog.quote(r.contentID) else { continue }
            let w = (r.liked ? 1 : 0) + (r.wasWritten ? 2 : 0)
            for t in q.themes { weighted += Array(repeating: t, count: w) }
        }
        return .ready(shares(weighted))
    }

    /// Geçen yıl ve geçen ay bugün yazılan girdiler.
    static func onThisDay(_ entries: [JournalEntry], today: DayKey) -> InsightState<[JournalEntry]> {
        let lastYear = DayKey(year: today.year - 1, month: today.month, day: today.day)
        let monthDate = today.month == 1 ? (today.year - 1, 12) : (today.year, today.month - 1)
        let lastMonth = DayKey(year: monthDate.0, month: monthDate.1, day: today.day)
        let targets = Set([lastYear, lastMonth].compactMap { $0 })
        let matches = entries.filter { targets.contains($0.day) }.sorted { $0.day > $1.day }
        return matches.isEmpty ? .insufficient(needed: 1, have: 0) : .ready(matches)
    }

    /// Aynı soruya/söze farklı zamanlardaki cevaplar: ilk ve son cevap yan yana.
    static func changePairs(_ entries: [JournalEntry]) -> InsightState<[ChangePair]> {
        let answered = entries.filter { $0.contentRef != nil && [.prompt, .quoteReflection].contains($0.kind) }
        let pairs: [ChangePair] = Dictionary(grouping: answered, by: { $0.contentRef! }).compactMap { ref, group in
            let sorted = group.sorted { $0.createdAt < $1.createdAt }
            guard sorted.count >= 2, let first = sorted.first, let last = sorted.last, first.day != last.day else { return nil }
            return ChangePair(ref: ref, earlier: first.id, later: last.id, daysApart: first.day.days(to: last.day))
        }.sorted { ($0.daysApart, $1.ref) > ($1.daysApart, $0.ref) }
        return pairs.isEmpty ? .insufficient(needed: 2, have: answered.isEmpty ? 0 : 1) : .ready(pairs)
    }

    // MARK: - Yardımcılar

    static func mean(_ values: [Int]) -> Double {
        values.isEmpty ? 0 : Double(values.reduce(0, +)) / Double(values.count)
    }

    static func shares(_ ids: [String]) -> [Share] {
        let total = ids.count
        guard total > 0 else { return [] }
        return Dictionary(grouping: ids, by: { $0 }).map { Share(id: $0.key, count: $0.value.count, ratio: Double($0.value.count) / Double(total)) }
            .sorted { ($0.count, $1.id) > ($1.count, $0.id) }
    }
}

/// Premium sınırı (E15): ücretsizde 14 gün mood + temel yazma istatistiği.
nonisolated enum InsightAccess {
    static func moodPeriodAvailable(_ period: InsightPeriod, hasPremium: Bool) -> Bool {
        hasPremium || period == .days14
    }

    /// Duygu/etiket ilişkisi ve değişim çiftleri premium.
    static let premiumOnly: Set<String> = ["emotionDistribution", "causeRelations", "changePairs"]
}

/// Depolardan okuyup `Insights`'ı çağırır; dönem başına önbellek, veri
/// değişince (`NSManagedObjectContextObjectsDidChange`) boşalır.
final class InsightsEngine {
    private let mood: MoodStore
    private let journal: JournalStore
    private let day: DayStore
    private let exposure: ExposureStore
    private let content: ContentRepository
    private let profile: ProfileStore
    private let clock: AppClock
    private var moodCache: [InsightPeriod: [MoodCheckIn]] = [:]
    private var observer: NSObjectProtocol?

    init(context: NSManagedObjectContext, mood: MoodStore, journal: JournalStore, day: DayStore, exposure: ExposureStore,
         content: ContentRepository, profile: ProfileStore, clock: AppClock) {
        self.mood = mood; self.journal = journal; self.day = day; self.exposure = exposure
        self.content = content; self.profile = profile; self.clock = clock
        observer = NotificationCenter.default.addObserver(
            forName: .NSManagedObjectContextObjectsDidChange, object: context, queue: nil
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.invalidate() }
        }
    }

    deinit { if let observer { NotificationCenter.default.removeObserver(observer) } }

    func invalidate() { moodCache = [:] }

    /// Dönem ve bir önceki dönem (ortalama değişimi için) check-in'leri.
    private func logs(_ period: InsightPeriod) -> [MoodCheckIn] {
        if let cached = moodCache[period] { return cached }
        let today = clock.today
        let logs = (try? mood.logs(from: period.previousRange(endingAt: today).lowerBound, through: today)) ?? []
        moodCache[period] = logs
        return logs
    }

    func moodLine(_ period: InsightPeriod) -> InsightState<[MoodPoint]> {
        Insights.moodLine(logs(period), period: period, today: clock.today)
    }

    func averageChange(_ period: InsightPeriod) -> InsightState<AverageChange> {
        Insights.averageChange(logs(period), period: period, today: clock.today)
    }

    func emotionDistribution(_ period: InsightPeriod) -> InsightState<EmotionDistribution> {
        let catalog = content.catalog
        return Insights.emotionDistribution(logs(period), period: period, today: clock.today, familyOf: catalog.emotionFamily)
    }

    func causeRelations(_ period: InsightPeriod) -> InsightState<[CauseRelation]> {
        Insights.causeRelations(logs(period), period: period, today: clock.today)
    }

    func writing() -> InsightState<WritingStats> {
        Insights.writing((try? journal.entries()) ?? [], days: (try? day.allCompletions()) ?? [],
                         mode: profile.profile.ritualMode)
    }

    func hours(_ period: InsightPeriod) -> InsightState<HourDistribution> {
        let today = clock.today
        let range = period.range(endingAt: today)
        let entries = (try? journal.entries(from: range.lowerBound, through: today)) ?? []
        return Insights.hours(logs(period).filter { range.contains($0.day) }, entries, calendar: clock.calendar)
    }

    func quoteThemes() -> InsightState<[Share]> {
        Insights.quoteThemes((try? exposure.snapshot(.quote)) ?? ExposureSnapshot(kind: .quote), catalog: content.catalog)
    }

    func onThisDay() -> InsightState<[JournalEntry]> {
        let today = clock.today
        let start = DayKey(year: today.year - 1, month: today.month, day: 1) ?? today.adding(days: -400)
        return Insights.onThisDay((try? journal.entries(from: start, through: today)) ?? [], today: today)
    }

    func changePairs() -> InsightState<[ChangePair]> {
        Insights.changePairs((try? journal.entries()) ?? [])
    }
}
