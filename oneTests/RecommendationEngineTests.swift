//
//  RecommendationEngineTests.swift
//  oneTests
//
//  E7: günlük önerisi karar tablosu ve Keşfet sıralaması (04_arka_plan_motorlari.md).
//

import Testing
import Foundation
import CoreData
@testable import OneDailyBatuhan

@MainActor
struct RecommendationEngineTests {

    private static let theme = PromptSuggestion(ref: "theme:2026-w39:d3", text: "Tema?", source: .theme)
    private static let free = PromptSuggestion(ref: "p_1", text: "Serbest?", source: .free)
    private static let guided = GuidedJournal(id: "g_bosalt_01", title: "Boşalt", summary: "", durationMinutes: 3,
                                              tags: ["kaygi"], timeOfDay: .any, steps: [], premium: false,
                                              active: true, addedIn: 1, lang: "tr")
    private static let comparison = ComparisonCandidate(prompt: PromptSuggestion(ref: "p_2", text: "Eski?", source: .comparison),
                                                        previous: UUID(), previousAt: Date())

    private func input(_ mutate: (inout DailySuggestionInput) -> Void) -> DailySuggestion {
        var i = DailySuggestionInput(themePrompt: Self.theme, hour: 10, lastScore: 3, calmGuided: Self.guided,
                                     comparison: Self.comparison, freePrompt: Self.free)
        mutate(&i)
        return Recommendation.daily(i)
    }

    @Test("Karar tablosu: her dal, ilk eşleşen kazanır")
    func decisionTable() {
        #expect(input { _ in } == .themePrompt(Self.theme))
        #expect(input { $0.themeWrittenToday = true; $0.hour = 19 } == .eveningReflection)
        #expect(input { $0.themeWrittenToday = true; $0.hour = 19; $0.eveningDone = true; $0.lastScore = 2 } == .guided(Self.guided))
        #expect(input { $0.themeWrittenToday = true; $0.hour = 17; $0.lastScore = 1 } == .guided(Self.guided))
        #expect(input { $0.themeWrittenToday = true; $0.hour = 12 } == .comparison(Self.comparison))
        #expect(input { $0.themeWrittenToday = true; $0.comparison = nil } == .freePrompt(Self.free))
        #expect(input { $0.themePrompt = nil; $0.comparison = nil; $0.freePrompt = nil } == .blankPage)
        // Düşük skor ama uygun rehber yoksa bir sonraki dal.
        #expect(input { $0.themeWrittenToday = true; $0.lastScore = 1; $0.calmGuided = nil } == .comparison(Self.comparison))
    }

    @Test("Sakinleştirici rehber: erişilebilir ve en kısa")
    func calmGuided() {
        func g(_ id: String, _ minutes: Int, premium: Bool = false, tags: [String] = ["kaygi"]) -> GuidedJournal {
            GuidedJournal(id: id, title: id, summary: "", durationMinutes: minutes, tags: tags, timeOfDay: .any,
                          steps: [], premium: premium, active: true, addedIn: 1, lang: "tr")
        }
        let all = [g("a", 5), g("b", 2, premium: true), g("c", 3), g("d", 1, tags: ["odak"])]
        #expect(Recommendation.calmGuided(all, hasPremium: false)?.id == "c")
        #expect(Recommendation.calmGuided(all, hasPremium: true)?.id == "b")
    }

    @Test("Keşfet: ücretsizde her 3 kartta en fazla 1 kilitli, kilitliler yine görünür")
    func lockedRatio() {
        let items = (0..<30).map { i in
            ExploreItem(id: "i\(i)", kind: .guided, tags: ["kaygi"], timeOfDay: .any, premium: i % 2 == 0)
        }
        let ranked = Recommendation.explore(items, focusAreas: ["kaygi"], recentKinds: [:], completed: [],
                                            dayPart: .morning, hasPremium: false)
        #expect(ranked.count == 30)
        #expect(ranked.filter(\.isLocked).count == 15)
        // Açık kartlar bitene kadar pencere kuralı: 3 ardışıkta ≤ 1 kilitli.
        let lastOpen = ranked.lastIndex { !$0.isLocked }!
        for i in 0...max(0, lastOpen - 2) {
            #expect(ranked[i...(i + 2)].filter(\.isLocked).count <= 1, "pencere \(i)")
        }
        let premium = Recommendation.explore(items, focusAreas: [], recentKinds: [:], completed: [],
                                             dayPart: .morning, hasPremium: true)
        #expect(premium.allSatisfy { !$0.isLocked })
    }

    @Test("Keşfet: odak alanı uyanlar önce, tamamlananlar aşağı, günün saati sayılır")
    func exploreOrdering() {
        let items = [
            ExploreItem(id: "focus", kind: .guided, tags: ["uyku"], timeOfDay: .any, premium: false),
            ExploreItem(id: "other", kind: .guided, tags: ["odak"], timeOfDay: .any, premium: false),
            ExploreItem(id: "done", kind: .guided, tags: ["uyku"], timeOfDay: .evening, premium: false),
            ExploreItem(id: "evening", kind: .guided, tags: ["odak"], timeOfDay: .evening, premium: false),
        ]
        let ranked = Recommendation.explore(items, focusAreas: ["uyku"], recentKinds: [:], completed: ["done"],
                                            dayPart: .evening, hasPremium: false).map(\.item.id)
        #expect(ranked.first == "focus")
        #expect(ranked.last == "done")
        #expect(ranked.firstIndex(of: "evening")! < ranked.firstIndex(of: "other")!)
    }

    @Test("Canlı motor: bundle içeriğiyle tema sorusu, yazıldıktan sonra sıradaki dal")
    func liveDailySuggestion() async throws {
        let clock = TestClock("2026-09-23T07:00:00Z")
        let container = ONE2TestStack.makeContainer()
        let ctx = container.viewContext
        let content = ContentRepository(bundle: BundleContentSource(bundle: Bundle(for: PersistenceController.self)),
                                        cacheDirectory: FileManager.default.temporaryDirectory.appendingPathComponent("r-\(UUID())"),
                                        fetcher: FakeContentFetcher(files: nil), clock: clock,
                                        defaults: UserDefaults(suiteName: "r-\(UUID())")!)
        let profile = ProfileStore(cloud: MemoryKeyValueStore(), local: MemoryKeyValueStore())
        let journal = JournalStore(context: ctx, clock: clock)
        let exposure = ExposureStore(context: ctx, clock: clock)
        let prompts = LivePromptEngine(content: content, exposure: exposure, journal: journal, profile: profile,
                                       clock: clock, local: MemoryKeyValueStore())
        let mood = MoodStore(context: ctx, clock: clock)
        let engine = RecommendationEngine(content: content, prompts: prompts, journal: journal,
                                          day: DayStore(context: ctx, clock: clock), mood: mood,
                                          profile: profile, clock: clock)
        guard case .themePrompt(let t) = await engine.dailySuggestion() else { Issue.record("tema bekleniyordu"); return }
        _ = try journal.create(EntryDraft(kind: .prompt, body: "cevap", contentRef: t.ref, sourceContext: .theme))
        _ = try mood.log(score: 1, source: .checkIn)
        guard case .guided(let g) = await engine.dailySuggestion() else { Issue.record("rehber bekleniyordu"); return }
        #expect(g.id == "g_bosalt_01")
        #expect(!engine.exploreRanking().isEmpty)
    }
}
