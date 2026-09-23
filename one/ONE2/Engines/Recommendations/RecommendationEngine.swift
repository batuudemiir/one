//
//  RecommendationEngine.swift
//  ONE 2.0
//
//  Öneri motoru (04_arka_plan_motorlari.md › E7): + menüsündeki "Günlük
//  önerisi" ve Keşfet'teki "Sana özel" sıralaması.
//
//  Günlük önerisi karar tablosu (ilk eşleşen):
//  1. Bugünün tema sorusu yazılmadıysa → tema sorusu.
//  2. 18:00 sonrası ve akşam ritüeli yapılmadıysa → akşam refleksiyonu.
//  3. Son check-in skoru ≤ 2 → kısa rehberli günlük ("Kafandakini boşalt").
//  4. Karşılaştırma adayı varsa (E4) → o soru.
//  5. Değilse → serbest soru (E4).
//

import Foundation

nonisolated enum DailySuggestion: Hashable, Sendable {
    case themePrompt(PromptSuggestion)
    case eveningReflection
    case guided(GuidedJournal)
    case comparison(ComparisonCandidate)
    case freePrompt(PromptSuggestion)
    /// Hiçbir kaynak yoksa boş sayfa.
    case blankPage
}

nonisolated struct DailySuggestionInput: Sendable {
    var themePrompt: PromptSuggestion?
    var themeWrittenToday = false
    var hour: Int
    var eveningDone = false
    var lastScore: Int?
    var calmGuided: GuidedJournal?
    var comparison: ComparisonCandidate?
    var freePrompt: PromptSuggestion?
}

/// Keşfet kartı.
nonisolated struct ExploreItem: Hashable, Sendable {
    enum Kind: String, Hashable, Sendable { case guided, theme, path }

    let id: String
    let kind: Kind
    let tags: [String]
    let timeOfDay: DayPart
    let premium: Bool
}

nonisolated struct RankedExploreItem: Hashable, Sendable {
    let item: ExploreItem
    let isLocked: Bool
    let isCompleted: Bool
}

nonisolated enum Recommendation {
    static let eveningHour = 18
    /// Keşfet'te her 3 ardışık kartta en fazla 1 kilitli.
    static let lockedWindow = 3

    static func daily(_ input: DailySuggestionInput) -> DailySuggestion {
        if let theme = input.themePrompt, !input.themeWrittenToday { return .themePrompt(theme) }
        if input.hour >= eveningHour, !input.eveningDone { return .eveningReflection }
        if let score = input.lastScore, score <= 2, let guided = input.calmGuided { return .guided(guided) }
        if let comparison = input.comparison { return .comparison(comparison) }
        if let free = input.freePrompt { return .freePrompt(free) }
        return .blankPage
    }

    /// Düşük skorda önerilecek rehberli günlük: erişilebilir, sakinleştirici
    /// etiketli, en kısa olan.
    static func calmGuided(_ guided: [GuidedJournal], hasPremium: Bool) -> GuidedJournal? {
        let calming: Set<String> = ["kaygi", "dinlenme", "kabul", "ozsefkat"]
        return guided
            .filter { $0.active && (hasPremium || !$0.premium) && !calming.isDisjoint(with: $0.tags) }
            .min { ($0.durationMinutes ?? 99, $0.id) < ($1.durationMinutes ?? 99, $1.id) }
    }

    /// Keşfet sıralaması: odak alanları + son 30 günde tamamlanan türler +
    /// günün saati; tamamlananlar aşağı; kilitli kartlar serpiştirilir.
    static func explore(_ items: [ExploreItem], focusAreas: [String], recentKinds: [ExploreItem.Kind: Int],
                        completed: Set<String>, dayPart: DayPart, hasPremium: Bool) -> [RankedExploreItem] {
        let focus = Set(focusAreas)
        let kindTotal = max(1, recentKinds.values.reduce(0, +))
        func score(_ item: ExploreItem) -> Double {
            let focusFit = focus.isEmpty ? 0.5 : Double(focus.intersection(item.tags).count) / Double(max(1, min(focus.count, 2)))
            let kindFit = Double(recentKinds[item.kind] ?? 0) / Double(kindTotal)
            let time: Double = item.timeOfDay == .any || dayPart == .any ? 0.5 : (item.timeOfDay == dayPart ? 1 : 0)
            return 0.5 * min(1, focusFit) + 0.2 * kindFit + 0.3 * time - (completed.contains(item.id) ? 1 : 0)
        }
        let sorted = items.map { ($0, score($0)) }.sorted { ($0.1, $1.0.id) > ($1.1, $0.0.id) }.map(\.0)
        var locked = sorted.filter { $0.premium && !hasPremium }
        var open = sorted.filter { !($0.premium && !hasPremium) }
        var result: [RankedExploreItem] = []
        while !locked.isEmpty || !open.isEmpty {
            let recentLocked = result.suffix(lockedWindow - 1).contains(where: \.isLocked)
            let takeLocked: Bool
            if locked.isEmpty { takeLocked = false }
            else if open.isEmpty { takeLocked = true }
            else if recentLocked { takeLocked = false }
            else { takeLocked = score(locked[0]) > score(open[0]) }
            let item = takeLocked ? locked.removeFirst() : open.removeFirst()
            result.append(RankedExploreItem(item: item, isLocked: takeLocked, isCompleted: completed.contains(item.id)))
        }
        return result
    }
}

final class RecommendationEngine {
    private let content: ContentRepository
    private let prompts: LivePromptEngine
    private let journal: JournalStore
    private let day: DayStore
    private let mood: MoodStore
    private let profile: ProfileStore
    private let clock: AppClock
    private let hasPremium: () -> Bool

    init(content: ContentRepository, prompts: LivePromptEngine, journal: JournalStore, day: DayStore,
         mood: MoodStore, profile: ProfileStore, clock: AppClock, hasPremium: @escaping () -> Bool = { false }) {
        self.content = content; self.prompts = prompts; self.journal = journal; self.day = day
        self.mood = mood; self.profile = profile; self.clock = clock; self.hasPremium = hasPremium
    }

    func dailySuggestion() async -> DailySuggestion {
        let today = clock.today
        let theme = await prompts.dailyPrompt(for: today)
        let todays = (try? journal.entries(on: today)) ?? []
        let lastScore = (try? mood.logs(on: today))?.last?.score
            ?? (try? mood.logs(from: today.adding(days: -1), through: today.adding(days: -1)))?.last?.score
        let input = DailySuggestionInput(
            themePrompt: theme,
            themeWrittenToday: theme.map { t in todays.contains { $0.contentRef == t.ref } } ?? true,
            hour: clock.calendar.component(.hour, from: clock.now),
            eveningDone: (try? day.completion(on: today))?.eveningCompletedAt != nil,
            lastScore: lastScore,
            calmGuided: Recommendation.calmGuided(content.catalog.guided, hasPremium: hasPremium()),
            comparison: await prompts.comparisonCandidate(on: today),
            freePrompt: await prompts.freePrompt(context: PromptContext(moodScore: lastScore))
        )
        return Recommendation.daily(input)
    }

    /// Keşfet › Sana özel.
    func exploreRanking() -> [RankedExploreItem] {
        let catalog = content.catalog
        let today = clock.today
        var items = catalog.guided.filter(\.active).map {
            ExploreItem(id: "guided:\($0.id)", kind: .guided, tags: $0.tags, timeOfDay: $0.timeOfDay, premium: $0.premium)
        }
        // Geçmiş temalar: son 4 hafta ücretsiz, öncesi premium (E5).
        let freeThemes = Set(ThemeCalendar.pastThemes(catalog: catalog, today: today, hasPremium: false).map(\.id))
        items += ThemeCalendar.pastThemes(catalog: catalog, today: today, hasPremium: true).map {
            ExploreItem(id: "theme:\($0.id)", kind: .theme, tags: $0.tags, timeOfDay: .any,
                        premium: !freeThemes.contains($0.id))
        }
        let recent = (try? journal.entries(from: today.adding(days: -30), through: today)) ?? []
        var kinds: [ExploreItem.Kind: Int] = [:]
        var completed: Set<String> = []
        for e in recent {
            if e.kind == .guided { kinds[.guided, default: 0] += 1 }
            if e.contentRef?.hasPrefix("theme:") == true { kinds[.theme, default: 0] += 1 }
            if let ref = e.contentRef, ref.hasPrefix("guided:") { completed.insert(ref) }
        }
        return Recommendation.explore(items, focusAreas: profile.profile.focusAreas, recentKinds: kinds,
                                      completed: completed,
                                      dayPart: .of(hour: clock.calendar.component(.hour, from: clock.now)),
                                      hasPremium: hasPremium())
    }
}
