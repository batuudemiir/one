//
//  BadgeEngine.swift
//  ONE 2.0
//
//  Rozet motoru (04_arka_plan_motorlari.md › E9). Kurallar `badges.tr.json`'da;
//  kod yalnız kural tiplerini bilir.
//
//  - Her kayıttan sonra ve açılışta değerlendirilir. `BadgeAward` idempotent:
//    `LibraryStore.award` aynı rozeti ikinci kez vermez, CloudKit çiftleri
//    remote change sonrası birleşir.
//  - Geriye dönük: güncelleme sonrası eklenen rozet geçmiş veriden hak
//    edilmişse sessizce verilir (duyurulmaz, Profil'de görünür). Açılış
//    değerlendirmesi her zaman sessizdir; kayıt sonrası yalnız o kayıtla
//    hak edilen rozet duyurulur.
//  - Seri rozeti en uzun seriye bakar: seri sonradan kırılsa da ya da seri
//    görünürlüğü kapalıyken de kazanılır.
//

import Foundation

/// Rozet kurallarının girdisi; depolardan bir kez hesaplanır.
nonisolated struct BadgeStats: Equatable, Sendable {
    var longestStreak = 0
    var entriesByKind: [EntryKind: Int] = [:]
    var totalWords = 0
    /// 7 gününün hepsi yazılmış haftalık tema sayısı.
    var themesCompleted = 0
    /// Sabah ve akşamın aynı gün yapıldığı gün sayısı.
    var bothRitualDays = 0
    /// Karşılaştırma zincirindeki cevap sayısı (`comparedEntryID` dolu).
    var comparisons = 0

    var totalEntries: Int { entriesByKind.values.reduce(0, +) }

    static func from(entries: [JournalEntry], days: [DayCompletion], mode: RitualMode) -> BadgeStats {
        var s = BadgeStats()
        for e in entries {
            s.entriesByKind[e.kind, default: 0] += 1
            s.totalWords += e.wordCount
            if e.comparedEntryID != nil { s.comparisons += 1 }
        }
        // theme:2026-w40:d3 → hafta başına yazılan gün kümesi.
        var themeDays: [String: Set<String>] = [:]
        for e in entries {
            guard let ref = e.contentRef, ref.hasPrefix("theme:") else { continue }
            let parts = ref.split(separator: ":")
            guard parts.count == 3 else { continue }
            themeDays[String(parts[1]), default: []].insert(String(parts[2]))
        }
        s.themesCompleted = themeDays.values.filter { $0.count >= 7 }.count
        s.bothRitualDays = days.filter(\.hasBothRituals).count
        s.longestStreak = Streak.longest(completed: Streak.completedDays(days, mode: mode))
        return s
    }
}

nonisolated struct BadgeAwardDecision: Equatable, Sendable {
    let badge: BadgeDefinition
    /// Kapanış ekranında duyurulsun mu.
    let announce: Bool
}

nonisolated enum BadgeRules {

    static func isSatisfied(_ rule: BadgeRule, by s: BadgeStats) -> Bool {
        switch rule {
        case .streak(let n): return s.longestStreak >= n
        case .entries(let kind, let n): return (kind.map { s.entriesByKind[$0] ?? 0 } ?? s.totalEntries) >= n
        case .words(let n): return s.totalWords >= n
        case .themeComplete(let n): return s.themesCompleted >= n
        case .bothRituals(let n): return s.bothRitualDays >= n
        case .comparison(let n): return s.comparisons >= n
        case .firstOf(let kind): return (s.entriesByKind[kind] ?? 0) >= 1
        }
    }

    /// Yeni kazanılan rozetler. `previous` verilirse (kayıt sonrası) yalnız
    /// önceki durumda sağlanmayanlar duyurulur; verilmezse (açılış) hepsi sessiz.
    static func newlyEarned(_ definitions: [BadgeDefinition], stats: BadgeStats, earned: Set<String>,
                            previous: BadgeStats?) -> [BadgeAwardDecision] {
        definitions
            .filter { $0.active && !earned.contains($0.id) && isSatisfied($0.rule, by: stats) }
            .sorted { $0.id < $1.id }
            .map { def in
                BadgeAwardDecision(badge: def, announce: previous.map { !isSatisfied(def.rule, by: $0) } ?? false)
            }
    }
}

final class BadgeEngine {
    private let content: ContentRepository
    private let journal: JournalStore
    private let day: DayStore
    private let library: LibraryStore
    private let profile: ProfileStore
    /// Son değerlendirmedeki durum: kayıt sonrası "bu kayıtla mı kazanıldı" ayrımı için.
    private var lastStats: BadgeStats?

    init(content: ContentRepository, journal: JournalStore, day: DayStore, library: LibraryStore, profile: ProfileStore) {
        self.content = content; self.journal = journal; self.day = day; self.library = library; self.profile = profile
    }

    /// Açılışta: geriye dönük, sessiz.
    @discardableResult
    func evaluateOnLaunch() throws -> [BadgeAwardDecision] {
        try evaluate(previous: nil)
    }

    /// Her kayıttan sonra: bu kayıtla kazanılanlar duyurulur.
    @discardableResult
    func evaluateAfterSave() throws -> [BadgeAwardDecision] {
        if lastStats == nil { lastStats = try currentStats() } // ilk kayıttan önceki durum bilinmiyorsa açılış gibi
        return try evaluate(previous: lastStats)
    }

    func currentStats() throws -> BadgeStats {
        BadgeStats.from(entries: try journal.entries(), days: try day.allCompletions(), mode: profile.profile.ritualMode)
    }

    private func evaluate(previous: BadgeStats?) throws -> [BadgeAwardDecision] {
        let stats = try currentStats()
        let earned = Set(try library.badges().map(\.badgeID))
        let decisions = BadgeRules.newlyEarned(content.catalog.badges, stats: stats, earned: earned, previous: previous)
        for d in decisions { try library.award(d.badge.id) }
        lastStats = stats
        return decisions
    }
}
