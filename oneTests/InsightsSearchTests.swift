//
//  InsightsSearchTests.swift
//  oneTests
//
//  E10 içgörü motoru (temel set) ve E11 arama (04_arka_plan_motorlari.md).
//

import Testing
import Foundation
import CoreData
@testable import OneDailyBatuhan

private let today = DayKey("2026-09-23")!

private func log(_ day: DayKey, _ score: Int, emotions: [String] = [], causes: [String] = [], hour: Int = 9) -> MoodCheckIn {
    var cal = Calendar(identifier: .gregorian); cal.timeZone = TimeZone(identifier: "Europe/Istanbul")!
    let ts = cal.date(byAdding: .hour, value: hour, to: day.startDate(in: cal)!)!
    return MoodCheckIn(id: UUID(), day: day, timeZoneID: nil, timestamp: ts, score: score, emotionIDs: emotions,
                       causeIDs: causes, note: nil, source: .checkIn, healthKitSampleID: nil, entryID: nil)
}

private func entry(_ day: DayKey, _ kind: EntryKind = .freeform, ref: String? = nil, words: Int = 5,
                   created: Date? = nil) -> JournalEntry {
    let at = created ?? day.startDate(in: Calendar(identifier: .gregorian))!.addingTimeInterval(12 * 3600)
    return JournalEntry(id: UUID(), day: day, timeZoneID: nil, createdAt: at, updatedAt: at, kind: kind,
                        title: nil, body: nil, wordCount: words, contentRef: ref, contentSnapshot: nil,
                        isBackfilled: false, sourceContext: nil, comparedEntryID: nil, moodID: nil, tagIDs: [], answers: [])
}

struct InsightsTests {

    @Test("Mood çizgisi: 3 check-in eşiği, gün başına ortalama, dönem dışı hariç")
    func moodLine() {
        let two = [log(today, 4), log(today.adding(days: -1), 2)]
        #expect(Insights.moodLine(two, period: .days14, today: today) == .insufficient(needed: 3, have: 2))
        let logs = two + [log(today, 2), log(today.adding(days: -20), 5)]
        let points = Insights.moodLine(logs, period: .days14, today: today).value!
        #expect(points.map(\.day) == [today.adding(days: -1), today])
        #expect(points.last?.average == 3 && points.last?.count == 2)
    }

    @Test("Ortalama ve değişim: 7 check-in eşiği, önceki dönemle fark")
    func averageChange() {
        let current = (0..<7).map { log(today.adding(days: -$0), 4) }
        let previous = (14..<21).map { log(today.adding(days: -$0), 2) }
        let r = Insights.averageChange(current + previous, period: .days14, today: today).value!
        #expect(r.average == 4 && r.previousAverage == 2 && r.delta == 2)
        #expect(Insights.averageChange(Array(current.prefix(6)), period: .days14, today: today) == .insufficient(needed: 7, have: 6))
        #expect(Insights.averageChange(current, period: .days14, today: today).value?.previousAverage == nil)
    }

    @Test("Duygu dağılımı: aile ve duygu oranları")
    func emotions() {
        let logs = [log(today, 3, emotions: ["emo_a", "emo_b"]), log(today, 3, emotions: ["emo_a"]),
                    log(today, 3, emotions: ["emo_c"]), log(today, 3), log(today, 3)]
        let families = ["emo_a": "huzur", "emo_b": "huzur", "emo_c": "kaygi"]
        let d = Insights.emotionDistribution(logs, period: .days14, today: today, familyOf: { families[$0] }).value!
        #expect(d.families.first == Share(id: "huzur", count: 3, ratio: 0.75))
        #expect(d.emotions.first?.id == "emo_a" && d.emotions.first?.count == 2)
    }

    @Test("Etiket ilişkisi: 21 check-in eşiği, etiket başına ≥5 örnek, gözlem ortalamaları")
    func causeRelations() {
        var logs = (0..<6).map { log(today.adding(days: -$0), 2, causes: ["c_uyku"]) }
        logs += (6..<21).map { log(today.adding(days: -$0), 4) }
        logs += (0..<4).map { log(today.adding(days: -$0), 1, causes: ["c_is"]) }
        #expect(Insights.causeRelations(Array(logs.prefix(20)), period: .days30, today: today) == .insufficient(needed: 21, have: 20))
        let r = Insights.causeRelations(logs, period: .days30, today: today).value!
        #expect(r.map(\.causeID) == ["c_uyku"])
        #expect(r[0].withAverage == 2 && r[0].samples == 6)
        #expect(abs(r[0].withoutAverage - (15 * 4 + 4 * 1) / 19.0) < 0.0001)
    }

    @Test("Yazma istatistiği, günün saati, geçen yıl/ay bugün, değişim çiftleri")
    func otherInsights() {
        #expect(Insights.writing([], days: [], mode: .daily) == .insufficient(needed: 1, have: 0))
        let entries = [entry(today, .prompt, ref: "p_1", words: 30), entry(today.adding(days: -40), .prompt, ref: "p_1", words: 10),
                       entry(today, .freeform, words: 5), entry(DayKey("2025-09-23")!), entry(DayKey("2026-08-23")!)]
        let w = Insights.writing(entries, days: [DayCompletion(day: today, dailyCompletedAt: Date())], mode: .daily).value!
        #expect(w.entries == 5 && w.words == 55 && w.topKind == .freeform && w.longestStreak == 1)

        #expect(Insights.onThisDay(entries, today: today).value?.count == 2)
        #expect(Insights.onThisDay(entries, today: today.adding(days: 1)) == .insufficient(needed: 1, have: 0))

        let pairs = Insights.changePairs(entries).value!
        #expect(pairs.count == 1 && pairs[0].ref == "p_1" && pairs[0].daysApart == 40)

        var cal = Calendar(identifier: .gregorian); cal.timeZone = TimeZone(identifier: "Europe/Istanbul")!
        let hours = Insights.hours((0..<10).map { log(today, 3, hour: 7 + $0 % 2) }, [], calendar: cal).value!
        #expect(hours.checkIns[7] == 5 && hours.checkIns[8] == 5)
        #expect(Insights.hours([log(today, 3)], [], calendar: cal) == .insufficient(needed: 10, have: 1))
    }

    @Test("5 yıllık sentetik veride 365 günlük hesap 200 ms altında")
    func performance() {
        var rng = SeededRandom(seed: 3)
        var logs: [MoodCheckIn] = []
        for d in 0..<(5 * 365) {
            for _ in 0..<2 {
                logs.append(log(today.adding(days: -d), 1 + Int(rng.next() % 5),
                                emotions: ["emo_\(rng.next() % 40)"], causes: ["c_\(rng.next() % 20)"]))
            }
        }
        let start = Date()
        _ = Insights.moodLine(logs, period: .days365, today: today)
        _ = Insights.averageChange(logs, period: .days365, today: today)
        _ = Insights.emotionDistribution(logs, period: .days365, today: today, familyOf: { _ in "f" })
        _ = Insights.causeRelations(logs, period: .days365, today: today)
        let ms = Date().timeIntervalSince(start) * 1000
        #expect(ms < 200, "\(ms) ms")
    }

    @Test("Ücretsiz: yalnız 14 gün mood")
    func access() {
        #expect(InsightAccess.moodPeriodAvailable(.days14, hasPremium: false))
        #expect(!InsightAccess.moodPeriodAvailable(.days90, hasPremium: false))
        #expect(InsightAccess.moodPeriodAvailable(.days365, hasPremium: true))
    }

    @Test("Canlı motor: yeni check-in önbelleği tazeler")
    @MainActor func liveEngineInvalidates() throws {
        let clock = TestClock("2026-09-23T09:00:00Z")
        let container = ONE2TestStack.makeContainer()
        let ctx = container.viewContext
        let mood = MoodStore(context: ctx, clock: clock)
        let engine = InsightsEngine(context: ctx, mood: mood, journal: JournalStore(context: ctx, clock: clock),
                                    day: DayStore(context: ctx, clock: clock), exposure: ExposureStore(context: ctx, clock: clock),
                                    content: QuoteFixture.repository([]),
                                    profile: ProfileStore(cloud: MemoryKeyValueStore(), local: MemoryKeyValueStore()),
                                    clock: clock)
        for s in [3, 4] { try mood.log(score: s, source: .checkIn) }
        #expect(engine.moodLine(.days14) == .insufficient(needed: 3, have: 2))
        try mood.log(score: 5, source: .checkIn)
        #expect(engine.moodLine(.days14).value?.first?.average == 4)
    }
}

@MainActor
struct SearchIndexTests {

    @Test("Türkçe küçük harf ve aksansız kopya")
    func folding() {
        #expect(SearchText.folded("GÜNLÜK İstanbul Işık") == "gunluk istanbul isik")
        #expect(SearchText.lowered("İ I") == "i ı")
        let text = SearchText.make(title: "Günlük", body: "Şeker", snapshot: nil, tagNames: ["Uyku"])!
        #expect(text.contains("günlük") && text.contains("gunluk") && text.contains("seker") && text.contains("uyku"))
        #expect(SearchText.make(title: nil, body: "", snapshot: nil, tagNames: []) == nil)
    }

    @Test("Vurgu aralıkları özgün metin üzerinde")
    func highlights() {
        let text = "Bugün günlük yazdım, GÜNLÜK güzel."
        let ranges = SearchText.highlights(of: "gunluk", in: text)
        #expect(ranges.map { String(text[$0]) } == ["günlük", "GÜNLÜK"])
    }

    @Test("Girdi araması: aksansız sorgu, filtreler, yeniden eskiye")
    func entrySearch() throws {
        let clock = TestClock("2026-09-23T09:00:00Z")
        let container = ONE2TestStack.makeContainer()
        let ctx = container.viewContext
        let journal = JournalStore(context: ctx, clock: clock)
        let library = LibraryStore(context: ctx, clock: clock)
        let mood = MoodStore(context: ctx, clock: clock)
        let tag = try library.createTag(name: "Uyku")
        let old = try journal.create(EntryDraft(kind: .freeform, body: "Dün gece iyi uyudum, günlük tutmak iyi geldi."),
                                     on: DayKey("2026-09-20")!)
        let prompt = try journal.create(EntryDraft(kind: .prompt, body: "Bugün kısa bir not.",
                                                   contentSnapshot: "Günlük sorusu?", tagIDs: [tag.id]))
        try mood.log(score: 2, source: .checkIn, linkedTo: prompt.id)
        _ = try journal.create(EntryDraft(kind: .freeform, body: "alakasız"))

        let search = SearchIndex(context: ctx)
        #expect(try search.search("gunluk").map(\.entry.id) == [prompt.id, old.id])
        #expect(try search.search("GÜNLÜK iyi").map(\.entry.id) == [old.id])
        #expect(try search.search("gunluk", filter: EntrySearchFilter(kinds: [.prompt])).map(\.entry.id) == [prompt.id])
        #expect(try search.search("gunluk", filter: EntrySearchFilter(through: DayKey("2026-09-21")!)).map(\.entry.id) == [old.id])
        #expect(try search.search("", filter: EntrySearchFilter(tagID: tag.id)).map(\.entry.id) == [prompt.id])
        #expect(try search.search("gunluk", filter: EntrySearchFilter(scores: [2])).map(\.entry.id) == [prompt.id])
        #expect(try search.search("uyku").map(\.entry.id).contains(prompt.id)) // etiket adı

        let hit = try #require(try search.search("gunluk").last)
        #expect(hit.highlights.map { String(hit.snippet[$0]) } == ["günlük"])

        try library.renameTag(tag.id, to: "Dinlenme")
        #expect(try search.search("dinlenme").map(\.entry.id) == [prompt.id])
    }

    @Test("Eksik searchText yeniden kurulur")
    func rebuild() throws {
        let container = ONE2TestStack.makeContainer()
        let ctx = container.viewContext
        let row: EntryMO = ctx.insert(ONE2Entity.entry)
        row.id = UUID(); row.dayKey = "2026-09-23"; row.kind = "freeform"; row.body = "Şükran"
        try ctx.save()
        let search = SearchIndex(context: ctx)
        #expect(try search.search("sukran").isEmpty)
        #expect(try search.rebuildMissing() == 1)
        #expect(try search.search("sukran").count == 1)
    }

    @Test("Söz araması: metin, yazar, tema; premium süzgeci")
    func quoteSearch() {
        let quotes = [
            Quote(id: "q1", text: "Yavaş yürüyen tez varır.", kind: .proverb, themes: ["sabir"]),
            Quote(id: "q2", text: "Bazı şeyler senin elindedir.", kind: .quote, author: "Epiktetos", themes: ["kabul"]),
            Quote(id: "q3", text: "Şükret.", kind: .affirmation, themes: ["minnet"], premium: true),
        ]
        let index = QuoteSearchIndex(quotes)
        #expect(index.search("yavas").map(\.id) == ["q1"])
        #expect(index.search("epiktetos elindedir").map(\.id) == ["q2"])
        #expect(index.search("minnet").map(\.id) == ["q3"])
        #expect(index.search("minnet", hasPremium: false).isEmpty)
    }
}
