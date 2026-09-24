//
//  PromptEchoEngineTests.swift
//  oneTests
//
//  E4 soru motoru ve E6 yankı motoru (04_arka_plan_motorlari.md).
//

import Testing
import Foundation
import CoreData
@testable import OneDailyBatuhan

@MainActor
struct PromptEngineTests {

    struct Rig {
        let engine: LivePromptEngine
        let journal: JournalStore
        let clock: TestClock
        let container: NSPersistentContainer
    }

    static func prompts() -> [Prompt] {
        (1...20).map { Prompt(id: String(format: "p_f%02d", $0), text: "Serbest \($0)?", pool: .free) }
        + (1...6).map { Prompt(id: String(format: "p_g%02d", $0), text: "Söz sorusu \($0)?", pool: .reflection) }
        + [Prompt(id: "p_s01", text: "Bu söze özel soru?", pool: .reflection, quoteIDs: ["q_000001"])]
        + (1...5).map { Prompt(id: String(format: "p_c%02d", $0), text: "Takip \($0)?", pool: .checkinFollowUp,
                               moodFit: $0 <= 3 ? [1, 2] : [4, 5]) }
        + [Prompt(id: "p_m1", text: "Odak?", pool: .morning, isCore: true),
           Prompt(id: "p_m2", text: "Niyet?", pool: .morning, isCore: true)]
        + (1...4).map { Prompt(id: "p_mr\($0)", text: "Dönen \($0)?", pool: .morning) }
    }

    static func repository(prompts: [Prompt], quotes: [Quote]) -> ContentRepository {
        let enc = JSONEncoder()
        var files: [String: Data] = [
            ContentFiles.prompts: try! enc.encode(ContentFile(items: prompts)),
            ContentFiles.quotes: try! enc.encode(ContentFile(items: quotes)),
        ]
        files[ContentFiles.manifest] = try! JSONSerialization.data(withJSONObject: [
            "schemaVersion": "1.0", "contentVersion": 1, "generatedAt": "",
            "files": files.map { ["path": $0.key, "sha256": ContentFiles.sha256($0.value)] },
        ])
        return ContentRepository(bundle: MemoryContentSource(files: files),
                                 cacheDirectory: FileManager.default.temporaryDirectory.appendingPathComponent("p-\(UUID())"),
                                 fetcher: FakeContentFetcher(files: nil), clock: FixedClock(Date()),
                                 defaults: UserDefaults(suiteName: "p-\(UUID())")!)
    }

    static func rig(content: ContentRepository? = nil) -> Rig {
        let clock = TestClock("2026-09-23T07:00:00Z")
        let container = ONE2TestStack.makeContainer()
        let journal = JournalStore(context: container.viewContext, clock: clock)
        let quote = Quote(id: "q_000001", text: "Bir söz.", kind: .reflection, reflectionPromptIDs: ["p_s01"])
        let engine = LivePromptEngine(
            content: content ?? repository(prompts: prompts(), quotes: [quote]),
            exposure: ExposureStore(context: container.viewContext, clock: clock), journal: journal,
            profile: ProfileStore(cloud: MemoryKeyValueStore(), local: MemoryKeyValueStore()),
            clock: clock, local: MemoryKeyValueStore())
        return Rig(engine: engine, journal: journal, clock: clock, container: container)
    }

    @Test("Günün sorusu haftalık temanın günü; ref theme:yyyy-wNN:dN")
    func dailyPrompt() async throws {
        let bundle = ContentRepository(bundle: BundleContentSource(bundle: Bundle(for: PersistenceController.self)),
                                       cacheDirectory: FileManager.default.temporaryDirectory.appendingPathComponent("b-\(UUID())"),
                                       fetcher: FakeContentFetcher(files: nil), clock: FixedClock(Date()),
                                       defaults: UserDefaults(suiteName: "b-\(UUID())")!)
        let rig = Self.rig(content: bundle)
        let p = try #require(await rig.engine.dailyPrompt(for: DayKey("2026-09-23")!))
        #expect(p.ref == "theme:2026-w39:d3")
        #expect(p.text == bundle.catalog.theme(week: "2026-W39")?.prompt(forWeekday: 3))
        #expect(p.source == .theme)
    }

    @Test("Serbest soru 90 gün içinde tekrar etmez")
    func freeNoRepeat90() async throws {
        let rig = Self.rig()
        var shown: [String] = []
        for _ in 0..<20 {
            let p = try #require(await rig.engine.freePrompt(context: PromptContext()))
            shown.append(p.ref)
            await rig.engine.markShown(p.ref)
            rig.clock.advance(hours: 24)
        }
        #expect(Set(shown).count == 20)
        // Havuz 90 gün boyunca tükenmiş: soru yok (boş sayfa sorusuz açılır).
        #expect(await rig.engine.freePrompt(context: PromptContext()) == nil)
        rig.clock.advance(hours: 24 * 70 + 1) // ilk gösterimden 90 gün sonrası
        let again = try #require(await rig.engine.freePrompt(context: PromptContext()))
        #expect(again.ref == shown[0])
    }

    @Test("Aynı söze ikinci yazışta farklı soru; karşılaştırma modunda bilerek aynı soru")
    func reflectionPrompts() async throws {
        let rig = Self.rig()
        let first = try #require(await rig.engine.reflectionPrompt(for: "q_000001", compare: false))
        #expect(first.ref == "p_s01") // söze özel önce
        _ = try rig.journal.create(EntryDraft(kind: .quoteReflection, contentRef: "q_000001",
                                              answers: [EntryAnswer(kind: .text, stepRef: first.ref, text: "cevap")],
                                              sourceContext: .quote))
        let second = try #require(await rig.engine.reflectionPrompt(for: "q_000001", compare: false))
        #expect(second.ref != first.ref)
        #expect(second.ref.hasPrefix("p_g"))
        let compare = try #require(await rig.engine.reflectionPrompt(for: "q_000001", compare: true))
        #expect(compare.ref == first.ref && compare.source == .comparison)
    }

    @Test("Karşılaştırma: ≥30 gün önce cevaplanan soru, haftada en fazla bir")
    func comparisonWeeklyLimit() async throws {
        let rig = Self.rig()
        let old = try rig.journal.create(EntryDraft(kind: .prompt, contentRef: "p_f03", contentSnapshot: "Serbest 3?",
                                                    sourceContext: .free))
        _ = try rig.journal.create(EntryDraft(kind: .prompt, contentRef: "p_f04", contentSnapshot: "Serbest 4?"))
        rig.clock.advance(hours: 24 * 10)
        #expect(await rig.engine.comparisonCandidate(on: rig.clock.today) == nil) // 30 gün dolmadı

        rig.clock.advance(hours: 24 * 25)
        let day = rig.clock.today
        let c = try #require(await rig.engine.comparisonCandidate(on: day))
        #expect(["p_f03", "p_f04"].contains(c.prompt.ref))
        #expect(await rig.engine.comparisonCandidate(on: day) == c)
        #expect(await rig.engine.comparisonCandidate(on: day.adding(days: 3)) == nil)
        #expect(await rig.engine.comparisonCandidate(on: day.adding(days: 7)) != nil)
        _ = old
    }

    @Test("Karşılaştırma zinciri: cevap comparedEntryID ile kaydedilir, 30 gün dolmadan tekrar sorulmaz")
    func comparisonChain() async throws {
        let rig = Self.rig()
        let old = try rig.journal.create(EntryDraft(kind: .prompt, contentRef: "p_f03", contentSnapshot: "Serbest 3?"))
        rig.clock.advance(hours: 24 * 31)
        let c = try #require(await rig.engine.comparisonCandidate(on: rig.clock.today))
        #expect(c.previous == old.id)
        let answer = try rig.journal.create(EntryDraft(kind: .prompt, contentRef: c.prompt.ref, contentSnapshot: c.prompt.text,
                                                       sourceContext: .comparison, comparedEntryID: c.previous))
        #expect(answer.comparedEntryID == old.id && answer.sourceContext == .comparison)
        rig.clock.advance(hours: 24 * 8)
        #expect(await rig.engine.comparisonCandidate(on: rig.clock.today) == nil)
    }

    @Test("Check-in takip sorusu ruh haline uyar, 14 gün içinde tekrar etmez")
    func followUp() async throws {
        let rig = Self.rig()
        var seen: Set<String> = []
        for _ in 0..<3 {
            let p = try #require(await rig.engine.followUpPrompt(context: PromptContext(moodScore: 1)))
            #expect(["p_c01", "p_c02", "p_c03"].contains(p.ref))
            #expect(!seen.contains(p.ref))
            seen.insert(p.ref)
            await rig.engine.markShown(p.ref)
            rig.clock.advance(hours: 24)
        }
        #expect(await rig.engine.followUpPrompt(context: PromptContext(moodScore: 1)) == nil)
        rig.clock.advance(hours: 24 * 12)
        #expect(await rig.engine.followUpPrompt(context: PromptContext(moodScore: 1)) != nil)
    }

    @Test("Ritüel: sabit çekirdek + gün başına sabit dönen 1 soru")
    func ritual() async {
        let rig = Self.rig()
        let day = DayKey("2026-09-23")!
        let a = await rig.engine.ritualPrompts(.morning, on: day)
        #expect(a.count == 3)
        #expect(Array(a.prefix(2).map(\.ref)) == ["p_m1", "p_m2"])
        #expect(await rig.engine.ritualPrompts(.morning, on: day) == a)
        var rotating: Set<String> = []
        for i in 0..<20 { rotating.insert(await rig.engine.ritualPrompts(.morning, on: day.adding(days: i)).last!.ref) }
        #expect(rotating.count > 1)
        #expect(await rig.engine.ritualPrompts(.free, on: day).isEmpty)
    }
}

@MainActor
struct EchoEngineTests {

    private static var bundleCatalog: ContentCatalog {
        try! ContentLoader.load(from: BundleContentSource(bundle: Bundle(for: PersistenceController.self)))
    }

    @Test("Skor 1'de pozitif baskı cümlesi seçilmez (etiketli set)")
    func lowScoreTone() {
        let catalog = Self.bundleCatalog
        let banned = ["harika", "neşelen", "gülümse", "süper", "!", "hafiflik", "güzel bir an", "iyi bir gün"]
        var picked: Set<String> = []
        for i in 0..<300 {
            var rng = SeededRandom("t", String(i))
            let families = ["huzun", "kaygi", "ofke", "yorgun", "nese"]
            let emotion = catalog.emotions.first { $0.family == families[i % families.count] }!.id
            let input = EchoInput(score: 1, emotionIDs: [emotion], causeIDs: i % 2 == 0 ? ["c_uyku"] : [],
                                  dayPart: [.morning, .day, .evening][i % 3], isFirstCheckin: i % 7 == 0,
                                  recentDailyScores: i % 4 == 0 ? [4, 4, 2, 1] : [])
            let echo = EchoSelection.choose(catalog.echoes, input: input, catalog: catalog,
                                            exposure: ExposureSnapshot(kind: .echo), now: Date(), lang: "tr", rng: &rng)
            guard let echo else { Issue.record("yankı yok"); continue }
            picked.insert(echo.id)
            #expect(echo.conditions.scoreIn.map { $0.contains(1) } ?? true, "\(echo.id)")
            #expect(echo.conditions.trend != .up, "\(echo.id)")
            for word in banned { #expect(!echo.text.lowercased().contains(word), "\(echo.id): \(word)") }
        }
        #expect(picked.count > 5)
    }

    @Test("14 gün içinde aynı yankı tekrar etmez (akşam, skor 3: 5 koşullu + 7 genel)")
    func noRepeat14() throws {
        let clock = TestClock("2026-09-23T18:00:00Z")
        let container = ONE2TestStack.makeContainer()
        let content = ContentRepository(bundle: BundleContentSource(bundle: Bundle(for: PersistenceController.self)),
                                        cacheDirectory: FileManager.default.temporaryDirectory.appendingPathComponent("e-\(UUID())"),
                                        fetcher: FakeContentFetcher(files: nil), clock: clock,
                                        defaults: UserDefaults(suiteName: "e-\(UUID())")!)
        let engine = EchoEngine(content: content, exposure: ExposureStore(context: container.viewContext, clock: clock),
                                profile: ProfileStore(cloud: MemoryKeyValueStore(), local: MemoryKeyValueStore()), clock: clock)
        var shown: [String] = []
        for i in 0..<12 {
            let echo = try #require(engine.echo(for: EchoInput(score: 3, checkInID: "c\(i)")))
            shown.append(echo.id)
            clock.advance(hours: 24)
        }
        #expect(Set(shown).count == 12)
    }

    @Test("Koşul eşleşmesi: her belirtilen koşul sağlanmalı; koşullu yoksa genel havuz")
    func conditions() {
        let c = Echo.Conditions(scoreIn: [1, 2], emotionFamilyAny: ["kaygi"], timeOfDay: .evening)
        let base = EchoInput(score: 2, dayPart: .evening)
        #expect(EchoSelection.matches(c, input: base, families: ["kaygi"], trend: nil))
        #expect(!EchoSelection.matches(c, input: base, families: ["nese"], trend: nil))
        #expect(!EchoSelection.matches(c, input: EchoInput(score: 4, dayPart: .evening), families: ["kaygi"], trend: nil))
        #expect(!EchoSelection.matches(c, input: EchoInput(score: 2, dayPart: .morning), families: ["kaygi"], trend: nil))

        let general = Echo(id: "g", text: "Genel.", conditions: .init(), weight: 1, premium: false, active: true, addedIn: 1, lang: "tr")
        let high = Echo(id: "h", text: "Yüksek.", conditions: .init(scoreIn: [5]), weight: 1, premium: false, active: true, addedIn: 1, lang: "tr")
        var rng = SeededRandom(seed: 1)
        let pick = EchoSelection.choose([general, high], input: EchoInput(score: 1), catalog: .empty,
                                        exposure: ExposureSnapshot(kind: .echo), now: Date(), lang: "tr", rng: &rng)
        #expect(pick?.id == "g")
    }

    @Test("Eğilim: en az 3 gün; ±0,75 eşik")
    func trend() {
        #expect(EchoSelection.trend([3, 3]) == nil)
        #expect(EchoSelection.trend([2, 2, 3, 4]) == .up)
        #expect(EchoSelection.trend([4, 4, 3, 2]) == .down)
        #expect(EchoSelection.trend([3, 3, 3.5, 3]) == .flat)
    }
}
