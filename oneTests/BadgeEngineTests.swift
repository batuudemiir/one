//
//  BadgeEngineTests.swift
//  oneTests
//
//  E9: rozet motoru (04_arka_plan_motorlari.md).
//

import Testing
import Foundation
import CoreData
@testable import OneDailyBatuhan

@MainActor
struct BadgeEngineTests {

    private static func badge(_ id: String, _ rule: BadgeRule) -> BadgeDefinition {
        BadgeDefinition(id: id, title: id, summary: "", rule: rule, premium: false, active: true, addedIn: 1, lang: "tr")
    }

    private static let defs: [BadgeDefinition] = [
        badge("b_streak_3", .streak(3)),
        badge("b_entries_2", .entries(kind: nil, count: 2)),
        badge("b_quote_1", .entries(kind: .quoteReflection, count: 1)),
        badge("b_words_50", .words(50)),
        badge("b_theme_1", .themeComplete(1)),
        badge("b_both_1", .bothRituals(1)),
        badge("b_cmp_1", .comparison(1)),
        badge("b_first_guided", .firstOf(.guided)),
    ]

    @Test("Her kural tipi eşiğinde sağlanıyor")
    func ruleTypes() {
        var s = BadgeStats()
        for d in Self.defs { #expect(!BadgeRules.isSatisfied(d.rule, by: s), "\(d.id)") }
        s.longestStreak = 3
        s.entriesByKind = [.quoteReflection: 1, .guided: 1]
        s.totalWords = 50
        s.themesCompleted = 1
        s.bothRitualDays = 1
        s.comparisons = 1
        for d in Self.defs { #expect(BadgeRules.isSatisfied(d.rule, by: s), "\(d.id)") }
    }

    @Test("İstatistik: tema haftası 7 farklı günle tamamlanır, karşılaştırma ve kelime sayılır")
    func stats() {
        let day = DayKey("2026-09-23")!
        func entry(_ kind: EntryKind, ref: String? = nil, words: Int = 0, compared: UUID? = nil) -> JournalEntry {
            JournalEntry(id: UUID(), day: day, timeZoneID: nil, createdAt: Date(), updatedAt: Date(), kind: kind,
                         title: nil, body: nil, wordCount: words, contentRef: ref, contentSnapshot: nil,
                         isBackfilled: false, sourceContext: nil, comparedEntryID: compared, moodID: nil,
                         tagIDs: [], answers: [])
        }
        var entries = (1...7).map { entry(.prompt, ref: "theme:2026-w40:d\($0)", words: 10) }
        entries += (1...6).map { entry(.prompt, ref: "theme:2026-w41:d\($0)") }
        entries.append(entry(.prompt, ref: "theme:2026-w40:d3")) // aynı gün ikinci kez sayılmaz
        entries.append(entry(.prompt, ref: "p_1", compared: UUID()))
        let t = Date()
        let days = [DayCompletion(day: day, morningCompletedAt: t, eveningCompletedAt: t),
                    DayCompletion(day: day.adding(days: -1), morningCompletedAt: t)]
        let s = BadgeStats.from(entries: entries, days: days, mode: .morningEvening)
        #expect(s.themesCompleted == 1)
        #expect(s.totalWords == 70)
        #expect(s.comparisons == 1)
        #expect(s.bothRitualDays == 1)
        #expect(s.longestStreak == 2)
        #expect(s.totalEntries == 15)
    }

    @Test("Açılışta geriye dönük rozetler sessiz; kayıt sonrası yalnız yeni hak edilen duyurulur")
    func announceRules() {
        var before = BadgeStats(); before.entriesByKind = [.freeform: 2]
        var after = before; after.entriesByKind[.quoteReflection] = 1
        let launch = BadgeRules.newlyEarned(Self.defs, stats: after, earned: [], previous: nil)
        #expect(Set(launch.map(\.badge.id)) == ["b_entries_2", "b_quote_1"])
        #expect(launch.allSatisfy { !$0.announce })

        let save = BadgeRules.newlyEarned(Self.defs, stats: after, earned: [], previous: before)
        #expect(save.first { $0.badge.id == "b_quote_1" }?.announce == true)
        #expect(save.first { $0.badge.id == "b_entries_2" }?.announce == false)
        #expect(BadgeRules.newlyEarned(Self.defs, stats: after, earned: ["b_entries_2", "b_quote_1"], previous: before).isEmpty)
    }

    @Test("Canlı motor: rozet bir kez verilir; seri gizliyken de seri rozeti kazanılır")
    func liveEngine() throws {
        let clock = TestClock("2026-09-23T09:00:00Z")
        let container = ONE2TestStack.makeContainer()
        let ctx = container.viewContext
        let content = ContentRepository(bundle: BundleContentSource(bundle: Bundle(for: PersistenceController.self)),
                                        cacheDirectory: FileManager.default.temporaryDirectory.appendingPathComponent("bd-\(UUID())"),
                                        fetcher: FakeContentFetcher(files: nil), clock: clock,
                                        defaults: UserDefaults(suiteName: "bd-\(UUID())")!)
        let profile = ProfileStore(cloud: MemoryKeyValueStore(), local: MemoryKeyValueStore())
        profile.update { $0.streakVisible = false }
        let journal = JournalStore(context: ctx, clock: clock)
        let day = DayStore(context: ctx, clock: clock)
        let library = LibraryStore(context: ctx, clock: clock)
        let engine = BadgeEngine(content: content, journal: journal, day: day, library: library, profile: profile)

        #expect(try engine.evaluateOnLaunch().isEmpty)
        for offset in (0...2).reversed() { try day.markCompleted(.daily, on: clock.today.adding(days: -offset)) }
        _ = try journal.create(EntryDraft(kind: .freeform, body: "ilk"))
        let awarded = try engine.evaluateAfterSave()
        #expect(Set(awarded.map(\.badge.id)).isSuperset(of: ["b_first_entry", "b_streak_3"]))
        #expect(awarded.allSatisfy { $0.announce })

        #expect(try engine.evaluateAfterSave().isEmpty)
        #expect(try engine.evaluateOnLaunch().isEmpty)
        let rows = try ctx.count(for: NSFetchRequest<NSManagedObject>(entityName: ONE2Entity.badge))
        #expect(rows == awarded.count)
    }
}
