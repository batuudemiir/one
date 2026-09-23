//
//  PromptEngine.swift
//  ONE 2.0
//
//  Soru motoru (04_arka_plan_motorlari.md › E4).
//
//  | Havuz            | Tekrar kuralı                                             |
//  |------------------|-----------------------------------------------------------|
//  | Günlük soru      | Haftalık temanın günü (E5), takvimle belirlenir            |
//  | Serbest soru     | Görülmemiş önce; 90 gün içinde tekrar yok                  |
//  | Söze yazı        | Söze özel önce, yoksa genel; aynı söze ikinci yazışta      |
//  |                  | farklı soru; karşılaştırma modunda bilerek aynı soru       |
//  | Check-in takip   | 14 gün içinde tekrar yok                                   |
//  | Sabah/akşam      | Sabit çekirdek + dönen 1 soru                              |
//
//  Karşılaştırma: bir soruya ilk cevaptan ≥30 gün sonra aynı soru "30 gün
//  önce buna şöyle cevap vermiştin" notuyla sorulabilir; haftada en fazla 1.
//
//  Seçim kararları `PromptSelection`'da saf; `LivePromptEngine` onu içerik,
//  maruz kalma kaydı ve girdi geçmişiyle besler.
//

import Foundation

nonisolated enum PromptSource: String, Sendable {
    case theme, free, reflection, followUp, morning, evening, comparison
}

/// Arayüze verilen soru. Tema günü sorusu katalogda `Prompt` değil, tema
/// içinde metin olduğu için ortak bir değer tipi.
nonisolated struct PromptSuggestion: Hashable, Sendable {
    /// `Entry.contentRef`'e yazılacak kalıcı referans: `p_000045` ya da
    /// `theme:2026-w40:d3`.
    let ref: String
    let text: String
    let source: PromptSource
    /// Katalog sorusuysa ID'si.
    let promptID: PromptID?

    init(prompt: Prompt, source: PromptSource) {
        ref = prompt.id; text = prompt.text; self.source = source; promptID = prompt.id
    }

    init(ref: String, text: String, source: PromptSource, promptID: PromptID? = nil) {
        self.ref = ref; self.text = text; self.source = source; self.promptID = promptID
    }

    /// `theme:2026-w40:d3`.
    static func themeRef(week: ISOWeek, weekday: Int) -> String {
        "theme:\(week.description.lowercased()):d\(weekday)"
    }
}

/// Serbest soru seçiminin bağlamı.
nonisolated struct PromptContext: Sendable {
    var dayPart: DayPart = .any
    var moodScore: Int?
    var emotionFamilies: Set<String> = []
    var weekThemeTags: Set<String> = []
    var hasPremium = false
    var lang = "tr"
}

/// Bir soruya verilmiş cevap (karşılaştırma için).
nonisolated struct AnsweredPrompt: Hashable, Sendable {
    let ref: String
    let text: String
    let entryID: UUID
    let answeredAt: Date
    /// Bu cevap bir karşılaştırmaysa önceki girdi.
    let comparedEntryID: UUID?
}

nonisolated struct ComparisonCandidate: Hashable, Sendable {
    let prompt: PromptSuggestion
    /// "30 gün önce buna şöyle cevap vermiştin": gösterilecek önceki girdi.
    let previous: UUID
    let previousAt: Date
}

nonisolated enum PromptSelection {
    static let freeRepeatWindow: TimeInterval = 90 * 86_400
    static let followUpRepeatWindow: TimeInterval = 14 * 86_400
    static let comparisonMinimumAge: TimeInterval = 30 * 86_400

    static func available(_ prompts: [Prompt], pool: PromptPool, context: PromptContext) -> [Prompt] {
        prompts.filter { $0.pool == pool && $0.active && $0.lang == context.lang && (context.hasPremium || !$0.premium) }
    }

    /// Serbest soru: 90 gün içinde gösterilenler çıkarılır, görülmemişler önce,
    /// sonra puan (tema, günün saati, ruh hali) + tohumlu rastgelelik.
    static func free(_ prompts: [Prompt], context: PromptContext, exposure: ExposureSnapshot,
                     now: Date, rng: inout SeededRandom) -> Prompt? {
        let cutoff = now.addingTimeInterval(-freeRepeatWindow)
        let pool = available(prompts, pool: .free, context: context)
            .filter { (exposure[$0.id]?.lastSeenAt ?? .distantPast) < cutoff }
        let unseen = pool.filter { exposure[$0.id]?.wasSeen != true }
        return best(unseen.isEmpty ? pool : unseen, context: context, rng: &rng)
    }

    /// Check-in takip sorusu: ruh hali/duygu uyumu, 14 gün içinde tekrar yok.
    static func followUp(_ prompts: [Prompt], context: PromptContext, exposure: ExposureSnapshot,
                         now: Date, rng: inout SeededRandom) -> Prompt? {
        let cutoff = now.addingTimeInterval(-followUpRepeatWindow)
        let pool = available(prompts, pool: .checkinFollowUp, context: context)
            .filter { (exposure[$0.id]?.lastSeenAt ?? .distantPast) < cutoff }
            .filter { p in
                let moodOK = p.moodFit.isEmpty || context.moodScore.map(p.moodFit.contains) ?? true
                let emotionOK = p.emotionFit.isEmpty || context.emotionFamilies.isEmpty
                    || !context.emotionFamilies.isDisjoint(with: p.emotionFit)
                return moodOK && emotionOK
            }
        return best(pool, context: context, rng: &rng)
    }

    /// Söze yazı: söze özel sorular önce, yoksa genel havuz. Bu söze daha önce
    /// sorulanlar tekrar sorulmaz (hepsi sorulduysa en az kullanılan döner).
    static func reflection(for quote: Quote, prompts: [Prompt], context: PromptContext,
                           used: [PromptID], rng: inout SeededRandom) -> Prompt? {
        let pool = available(prompts, pool: .reflection, context: context)
        let specificIDs = Set(quote.reflectionPromptIDs ?? [])
        let specific = pool.filter { specificIDs.contains($0.id) || $0.quoteIDs.contains(quote.id) }
        let general = pool.filter { $0.quoteIDs.isEmpty }
        let usedSet = Set(used)
        for tier in [specific, general] {
            let fresh = tier.filter { !usedSet.contains($0.id) }
            if let pick = best(fresh, context: context, rng: &rng) { return pick }
        }
        // Hepsi kullanıldıysa: en az kullanılan, eşitlikte en eski kullanılan.
        let all = specific + general
        return all.min { a, b in
            let ca = used.filter { $0 == a.id }.count, cb = used.filter { $0 == b.id }.count
            if ca != cb { return ca < cb }
            return (used.firstIndex(of: a.id) ?? 0) < (used.firstIndex(of: b.id) ?? 0)
        }
    }

    /// Sabah/akşam ritüeli: çekirdek sorular (katalog sırasıyla) + gün ile
    /// tohumlanmış 1 dönen soru.
    static func ritual(_ pool: PromptPool, prompts: [Prompt], context: PromptContext,
                       rng: inout SeededRandom) -> [Prompt] {
        let all = available(prompts, pool: pool, context: context)
        let core = all.filter(\.isCore)
        let rotating = all.filter { !$0.isCore }
        guard !rotating.isEmpty else { return core }
        return core + [rotating[Int(rng.next() % UInt64(rotating.count))]]
    }

    /// Son cevabı ≥30 gün önce verilmiş soru; ilk cevabı en eski olan önce.
    /// Dönen çift: (ilk cevap, son cevap).
    static func comparison(_ answers: [AnsweredPrompt], now: Date) -> (AnsweredPrompt, AnsweredPrompt)? {
        let cutoff = now.addingTimeInterval(-comparisonMinimumAge)
        let byRef = Dictionary(grouping: answers, by: \.ref)
        var best: (AnsweredPrompt, AnsweredPrompt)?
        for (_, group) in byRef {
            let sorted = group.sorted { $0.answeredAt < $1.answeredAt }
            // ≥30 gün ölçüsü son cevaba göre: zincir en fazla ayda bir uzar.
            guard let first = sorted.first, let latest = sorted.last, latest.answeredAt <= cutoff else { continue }
            if let current = best, current.0.answeredAt <= first.answeredAt { continue }
            best = (first, latest)
        }
        return best
    }

    static func score(_ p: Prompt, context: PromptContext) -> Double {
        let theme: Double = context.weekThemeTags.isDisjoint(with: p.themes) ? 0 : 1
        let time: Double = p.timeOfDay == .any || context.dayPart == .any ? 0.5 : (p.timeOfDay == context.dayPart ? 1 : 0)
        let mood: Double = {
            guard let s = context.moodScore, !p.moodFit.isEmpty else { return 0.5 }
            return p.moodFit.contains(s) ? 1 : 0
        }()
        return 0.35 * theme + 0.25 * time + 0.25 * mood
    }

    static func best(_ prompts: [Prompt], context: PromptContext, rng: inout SeededRandom) -> Prompt? {
        prompts.map { ($0, score($0, context: context) + 0.15 * rng.unit()) }
            .max { ($0.1, $1.0.id) < ($1.1, $0.0.id) }?.0
    }
}

protocol PromptEngine: AnyObject {
    func dailyPrompt(for day: DayKey) async -> PromptSuggestion?
    func freePrompt(context: PromptContext) async -> PromptSuggestion?
    func reflectionPrompt(for quote: QuoteID, compare: Bool) async -> PromptSuggestion?
    func followUpPrompt(context: PromptContext) async -> PromptSuggestion?
    func ritualPrompts(_ kind: PromptPool, on day: DayKey) async -> [PromptSuggestion]
    func comparisonCandidate(on day: DayKey) async -> ComparisonCandidate?
    func markShown(_ id: PromptID) async
}

final class LivePromptEngine: PromptEngine {
    private let content: ContentRepository
    private let exposure: ExposureStore
    private let journal: JournalStore
    private let profile: ProfileStore
    private let clock: AppClock
    private let local: KeyValueBacking
    private let hasPremium: () -> Bool

    private static let comparisonKey = "prompt.comparison.last"

    init(content: ContentRepository, exposure: ExposureStore, journal: JournalStore, profile: ProfileStore,
         clock: AppClock, local: KeyValueBacking = UserDefaults(suiteName: "group.com.batudemir.ones") ?? .standard,
         hasPremium: @escaping () -> Bool = { false }) {
        self.content = content; self.exposure = exposure; self.journal = journal; self.profile = profile
        self.clock = clock; self.local = local; self.hasPremium = hasPremium
    }

    func dailyPrompt(for day: DayKey) async -> PromptSuggestion? {
        guard let week = ThemeCalendar.theme(for: day, catalog: content.catalog, firstSeen: evergreenFirstSeen(),
                                             salt: profile.profile.userSalt),
              let text = week.prompt(on: day) else { return nil }
        return PromptSuggestion(ref: PromptSuggestion.themeRef(week: week.week, weekday: day.isoWeekday),
                                text: text, source: .theme)
    }

    func freePrompt(context: PromptContext) async -> PromptSuggestion? {
        var rng = seed("free")
        return PromptSelection.free(content.catalog.prompts, context: filled(context), exposure: snapshot(),
                                    now: clock.now, rng: &rng).map { PromptSuggestion(prompt: $0, source: .free) }
    }

    func reflectionPrompt(for quoteID: QuoteID, compare: Bool = false) async -> PromptSuggestion? {
        guard let quote = content.catalog.quote(quoteID) else { return nil }
        let used = usedReflectionPrompts(quoteID)
        if compare, let last = used.last, let p = content.catalog.prompt(last) {
            return PromptSuggestion(prompt: p, source: .comparison)
        }
        var rng = seed("reflection", quoteID, String(used.count))
        return PromptSelection.reflection(for: quote, prompts: content.catalog.prompts, context: filled(PromptContext()),
                                          used: used, rng: &rng)
            .map { PromptSuggestion(prompt: $0, source: .reflection) }
    }

    func followUpPrompt(context: PromptContext) async -> PromptSuggestion? {
        var rng = seed("followUp")
        return PromptSelection.followUp(content.catalog.prompts, context: filled(context), exposure: snapshot(),
                                        now: clock.now, rng: &rng).map { PromptSuggestion(prompt: $0, source: .followUp) }
    }

    func ritualPrompts(_ kind: PromptPool, on day: DayKey) async -> [PromptSuggestion] {
        guard kind == .morning || kind == .evening else { return [] }
        var rng = SeededRandom("prompt.ritual", kind.rawValue, profile.profile.userSalt.uuidString, day.string)
        return PromptSelection.ritual(kind, prompts: content.catalog.prompts, context: filled(PromptContext()), rng: &rng)
            .map { PromptSuggestion(prompt: $0, source: kind == .morning ? .morning : .evening) }
    }

    /// Haftada en fazla bir; aynı gün tekrar sorulursa aynı aday.
    func comparisonCandidate(on day: DayKey) async -> ComparisonCandidate? {
        if let last = (local.object(forKey: Self.comparisonKey) as? String)?.split(separator: "|"), last.count == 3,
           let lastDay = DayKey(String(last[0])) {
            if lastDay == day, let entryID = UUID(uuidString: String(last[2])),
               let entry = try? journal.entry(entryID), let suggestion = suggestion(for: String(last[1])) {
                return ComparisonCandidate(prompt: suggestion, previous: entryID, previousAt: entry.createdAt)
            }
            if lastDay.days(to: day) < 7 { return nil }
        }
        let answers = answeredPrompts()
        guard let (_, latest) = PromptSelection.comparison(answers, now: clock.now),
              let suggestion = suggestion(for: latest.ref) else { return nil }
        local.set("\(day.string)|\(latest.ref)|\(latest.entryID.uuidString)", forKey: Self.comparisonKey)
        return ComparisonCandidate(prompt: suggestion, previous: latest.entryID, previousAt: latest.answeredAt)
    }

    func markShown(_ id: PromptID) async {
        exposure.recordSeen(id, kind: .prompt)
    }

    // MARK: - Private

    private func seed(_ parts: String...) -> SeededRandom {
        SeededRandom((["prompt", profile.profile.userSalt.uuidString, clock.today.string] + parts).joined(separator: "|"))
    }

    private func snapshot() -> ExposureSnapshot {
        (try? exposure.snapshot(.prompt)) ?? ExposureSnapshot(kind: .prompt)
    }

    private func filled(_ context: PromptContext) -> PromptContext {
        var c = context
        c.hasPremium = hasPremium()
        c.lang = profile.profile.contentLang
        if c.dayPart == .any { c.dayPart = .of(hour: clock.calendar.component(.hour, from: clock.now)) }
        if c.weekThemeTags.isEmpty,
           let week = ThemeCalendar.theme(for: clock.today, catalog: content.catalog, salt: profile.profile.userSalt) {
            c.weekThemeTags = Set(week.theme.tags)
        }
        return c
    }

    private func evergreenFirstSeen() -> [String: DayKey] {
        let records = (try? exposure.snapshot(.theme))?.records ?? [:]
        return records.compactMapValues { $0.firstSeenAt.map { DayKey(date: $0, calendar: clock.calendar) } }
    }

    /// Bu söze yazılmış girdilerde kullanılan soru ID'leri, eskiden yeniye.
    private func usedReflectionPrompts(_ quoteID: QuoteID) -> [PromptID] {
        let entries = (try? journal.entries(kind: .quoteReflection, contentRef: quoteID)) ?? []
        return entries.flatMap { $0.answers.compactMap(\.stepRef) }.filter { $0.hasPrefix("p_") }
    }

    /// Soru ve tema sorusu cevapları (karşılaştırma kaynağı).
    private func answeredPrompts() -> [AnsweredPrompt] {
        let entries = (try? journal.entries(kind: .prompt)) ?? []
        return entries.compactMap { e in
            guard let ref = e.contentRef else { return nil }
            return AnsweredPrompt(ref: ref, text: e.contentSnapshot ?? "", entryID: e.id,
                                  answeredAt: e.createdAt, comparedEntryID: e.comparedEntryID)
        }
    }

    private func suggestion(for ref: String) -> PromptSuggestion? {
        if let p = content.catalog.prompt(ref) { return PromptSuggestion(prompt: p, source: .comparison) }
        let entries = (try? journal.entries(kind: .prompt, contentRef: ref)) ?? []
        guard let text = entries.last?.contentSnapshot else { return nil }
        return PromptSuggestion(ref: ref, text: text, source: .comparison)
    }
}
