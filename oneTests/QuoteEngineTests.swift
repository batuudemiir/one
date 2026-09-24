//
//  QuoteEngineTests.swift
//  oneTests
//
//  E2: söz motoru — tekrarsızlık, kuyruk, puan, günün sözü (04_arka_plan_motorlari.md).
//

import Testing
import Foundation
import CoreData
@testable import OneDailyBatuhan

/// Sentetik söz kataloğu ve motor kurulumu.
@MainActor
enum QuoteFixture {
    static let themes = ["cesaret", "minnet", "kabul", "odak", "dinlenme", "umut", "sinirlar", "degisim", "ozsefkat", "merak"]
    static let paths = ["stoacilar", "antik_yunan", "varoluscular", "dogu_bilgeligi", "islam_anadolu"]
    static let authorCount = 40

    /// Her 10. öğe olumlama (akışa girmemeli, 08 §1); gerisi `quote`.
    /// Yazar k'nin sözleri i ≡ k (mod 40), yolu `paths[k % 5]`.
    static func quotes(_ n: Int, premiumEvery: Int = 0) -> [Quote] {
        (0..<n).map { i in
            let kind: QuoteKind = i % 10 == 9 ? .affirmation : .quote
            let text = i % 3 == 0 ? "Kısa söz \(i)." : "Bu biraz daha uzun bir cümle, sayısı \(i), ve sakin bir düşünce taşıyor."
            return Quote(id: String(format: "q_%06d", i + 1), text: text, kind: kind,
                         author: kind == .quote ? "Yazar \(i % authorCount)" : nil, source: kind == .quote ? "Eser" : nil,
                         license: kind == .quote ? .publicDomain : .original,
                         themes: [themes[i % themes.count], themes[(i / 3) % themes.count]],
                         paths: [paths[i % paths.count]], moodFit: [1 + i % 5],
                         timeOfDay: [.any, .morning, .evening, .day][i % 4],
                         premium: premiumEvery > 0 && i % premiumEvery == premiumEvery - 1)
        }
    }

    static func authorID(_ k: Int) -> ThinkerID { ThinkerNames.syntheticID(for: "Yazar \(k)") }

    static let thinkers: [Thinker] = (0..<authorCount).map { k in
        Thinker(id: authorID(k), displayName: "Yazar \(k)", pathIDs: [paths[k % paths.count]])
    }

    static func repository(_ quotes: [Quote]) -> ContentRepository {
        let data = try! JSONEncoder().encode(ContentFile(items: quotes))
        let thinkerData = try! JSONEncoder().encode(ContentFile(items: thinkers))
        let manifest = try! JSONSerialization.data(withJSONObject: [
            "schemaVersion": "2.0", "contentVersion": 1, "generatedAt": "",
            "files": [["path": ContentFiles.quotes, "sha256": ContentFiles.sha256(data)],
                      ["path": ContentFiles.thinkers, "sha256": ContentFiles.sha256(thinkerData)]],
        ])
        let source = MemoryContentSource(files: [ContentFiles.manifest: manifest, ContentFiles.quotes: data,
                                                 ContentFiles.thinkers: thinkerData])
        return ContentRepository(bundle: source,
                                 cacheDirectory: FileManager.default.temporaryDirectory.appendingPathComponent("q-\(UUID())"),
                                 fetcher: FakeContentFetcher(files: nil), clock: FixedClock(Date()),
                                 defaults: UserDefaults(suiteName: "q-\(UUID())")!)
    }

    struct Rig {
        let engine: LiveQuoteEngine
        let exposure: ExposureStore
        let profile: ProfileStore
        let clock: TestClock
        let container: NSPersistentContainer
    }

    static func rig(_ quotes: [Quote], clock: TestClock = TestClock("2026-09-23T07:00:00Z"),
                    cloud: MemoryKeyValueStore = MemoryKeyValueStore(), paths: [String] = [],
                    premium: Bool = false, mood: Int? = nil) -> Rig {
        let container = ONE2TestStack.makeContainer()
        let exposure = ExposureStore(context: container.viewContext, clock: clock)
        let profile = ProfileStore(cloud: cloud, local: MemoryKeyValueStore())
        if !paths.isEmpty { profile.update { $0.quotePaths = paths } }
        let engine = LiveQuoteEngine(content: repository(quotes), exposure: exposure, profile: profile, clock: clock,
                                     cloud: cloud, local: MemoryKeyValueStore(),
                                     hasPremium: { premium }, moodScore: { mood })
        return Rig(engine: engine, exposure: exposure, profile: profile, clock: clock, container: container)
    }
}

@MainActor
struct QuoteEngineTests {

    // MARK: - E2.2 tekrarsızlık

    @Test("1.000 kartlık simülasyonda sıfır tekrar; oturum içinde tekrar yok; çeşitlilik kısıtları tutuyor")
    func thousandCardsNoRepeat() async throws {
        let rig = QuoteFixture.rig(QuoteFixture.quotes(1_500), paths: ["antik_yunan", "varoluscular"], premium: true)
        var rng = SeededRandom(seed: 7)
        var seenOrder: [Quote] = []
        var shownTotal = 0
        while seenOrder.count < 1_000 {
            rig.engine.startSession()
            var sessionIDs: Set<QuoteID> = []
            let size = 5 + Int(rng.next() % 11) // 5–15 kart
            let batch = await rig.engine.nextBatch(mode: .forYou, count: size)
            #expect(!batch.isEmpty)
            for q in batch {
                #expect(q.kind == .quote, "akışta söz dışı tür: \(q.id)")
                #expect(!sessionIDs.contains(q.id), "oturumda tekrar: \(q.id)")
                sessionIDs.insert(q.id)
                shownTotal += 1
                await rig.engine.markSeen(q.id, dwell: .seconds(2))
                seenOrder.append(q)
            }
            rig.clock.advance(hours: 9)
        }
        try rig.exposure.flush()
        let snapshot = try rig.exposure.snapshot(.quote)
        #expect(Set(seenOrder.map(\.id)).count == seenOrder.count, "tekrar görülen söz var")
        #expect(snapshot.records.values.allSatisfy { $0.seenCount == 1 })

        var violations = 0
        for i in seenOrder.indices where QuoteSelection.violations(seenOrder[i], after: Array(seenOrder[..<i])) > 0 {
            violations += 1
        }
        #expect(violations == 0, "çeşitlilik ihlali: \(violations)")
    }

    @Test("Hızlı geçilen kart görülmüş sayılmaz ve sonraki oturumda kuyruktan geri gelir")
    func fastSwipeReturns() async throws {
        let rig = QuoteFixture.rig(QuoteFixture.quotes(100), premium: true)
        rig.engine.startSession()
        let first = await rig.engine.nextBatch(mode: .forYou, count: 5)
        await rig.engine.markSeen(first[0].id, dwell: .milliseconds(300))
        for q in first.dropFirst() { await rig.engine.markSeen(q.id, dwell: .seconds(3)) }
        #expect(try rig.exposure.seenIDs(.quote) == Set(first.dropFirst().map(\.id)))

        // Aynı oturumda tekrar gösterilmez.
        let more = await rig.engine.nextBatch(mode: .forYou, count: 40)
        #expect(!more.contains { $0.id == first[0].id })

        // Yeni oturumda kuyrukta geri döner.
        rig.engine.startSession()
        var returned = false
        for _ in 0..<5 where !returned {
            let batch = await rig.engine.nextBatch(mode: .forYou, count: 20)
            returned = batch.contains { $0.id == first[0].id }
            for q in batch { await rig.engine.markSeen(q.id, dwell: .seconds(2)) }
        }
        #expect(returned)
    }

    @Test("Döngü 2: yalnız 60 günden önce görülenler, en eskisi önce; hepsi yeniyse boş durum")
    func cycleTwo() async throws {
        let quotes = QuoteFixture.quotes(10)
        let rig = QuoteFixture.rig(quotes, premium: true)
        let now = rig.clock.now
        for (i, q) in quotes.enumerated() {
            let daysAgo = i < 5 ? 70.0 + Double(i) : 10.0
            rig.exposure.recordSeen(q.id, kind: .quote, at: now.addingTimeInterval(-daysAgo * 86_400))
        }
        try rig.exposure.flush()
        #expect(await rig.engine.remainingUnseen(mode: .forYou) == 0)

        rig.engine.startSession()
        let batch = await rig.engine.nextBatch(mode: .forYou, count: 10)
        #expect(Set(batch.map(\.id)) == Set(quotes.prefix(5).map(\.id))) // 10. öğe olumlama: akışta yok
        #expect(batch.first?.id == quotes[4].id) // 74 gün önce: en eski

        for q in batch { await rig.engine.markSeen(q.id, dwell: .seconds(2)) }
        rig.engine.startSession()
        #expect(await rig.engine.nextBatch(mode: .forYou, count: 10).isEmpty)
    }

    // MARK: - E2.3 puan ve erişim

    @Test("Skor ≤ 2 iken yumuşak temalı söz öne çıkar (ton kuralı S4'te)")
    func lowMoodSoftThemes() {
        let soft = Quote(id: "s", text: "Kısa.", kind: .quote, themes: ["ozsefkat"])
        let plain = Quote(id: "p", text: "Kısa.", kind: .quote, themes: ["odak"])
        #expect(QuoteSelection.moodScore(soft, 1) > QuoteSelection.moodScore(plain, 1))
        #expect(QuoteSelection.moodScore(soft, 1) > QuoteSelection.moodScore(soft, 5))
    }

    @Test("Ücretsiz: Sana özel + ilk seçilen yol açık; diğer yollar ve temalar kilitli; premium söz yok")
    func freeAccess() async {
        let quotes = QuoteFixture.quotes(200, premiumEvery: 4)
        let rig = QuoteFixture.rig(quotes, paths: ["varoluscular", "antik_yunan"])
        #expect(rig.engine.isAccessible(.forYou))
        #expect(rig.engine.isAccessible(.path("varoluscular")))
        #expect(!rig.engine.isAccessible(.path("antik_yunan")))
        #expect(!rig.engine.isAccessible(.path("stoacilar")))
        #expect(!rig.engine.isAccessible(.theme("minnet")))
        rig.engine.startSession()
        #expect(await rig.engine.nextBatch(mode: .path("antik_yunan"), count: 5).isEmpty)
        #expect(await rig.engine.nextBatch(mode: .theme("minnet"), count: 5).isEmpty)
        let batch = await rig.engine.nextBatch(mode: .path("varoluscular"), count: 20)
        #expect(!batch.isEmpty && batch.allSatisfy { !$0.premium && $0.paths.contains("varoluscular") })

        let premium = QuoteFixture.rig(quotes, paths: ["varoluscular"], premium: true)
        premium.engine.startSession()
        #expect(premium.engine.isAccessible(.path("antik_yunan")))
        #expect(!(await premium.engine.nextBatch(mode: .theme("minnet"), count: 5)).isEmpty)
    }

    @Test("Ücretsiz yol seçilmediyse stoacilar açık")
    func defaultFreePath() {
        let rig = QuoteFixture.rig(QuoteFixture.quotes(20))
        #expect(rig.engine.isAccessible(.path("stoacilar")))
        #expect(!rig.engine.isAccessible(.path("varoluscular")))
    }

    @Test("Kuyruk içerikleri: ücretsizde yalnız açık yol, premium işaretsiz, doğrulanmış quote; premium'da tüm yollar")
    func queueContents() async {
        var quotes = QuoteFixture.quotes(600, premiumEvery: 5)
        // Doğrulanmamış söz yayına girmez (08 §1).
        quotes.append(Quote(id: "q_unverified", text: "Kaynağı belirsiz.", kind: .quote,
                            authorID: QuoteFixture.authorID(0), verified: false, paths: ["stoacilar"]))
        func drain(_ rig: QuoteFixture.Rig, _ mode: QuoteFeedMode) async -> [Quote] {
            var all: [Quote] = []
            for _ in 0..<40 {
                rig.engine.startSession()
                let batch = await rig.engine.nextBatch(mode: mode, count: 15)
                if batch.isEmpty { break }
                for q in batch { await rig.engine.markSeen(q.id, dwell: .seconds(2)) }
                all += batch
            }
            return all
        }
        let free = await drain(QuoteFixture.rig(quotes), .forYou)
        let expectedFree = quotes.filter { $0.kind == .quote && $0.verified && !$0.premium && $0.paths == ["stoacilar"] }
        #expect(Set(free.map(\.id)) == Set(expectedFree.map(\.id)))
        #expect(free.count == expectedFree.count)

        let premium = await drain(QuoteFixture.rig(quotes, paths: ["stoacilar"], premium: true), .forYou)
        let expectedPremium = quotes.filter { $0.kind == .quote && $0.verified }
        #expect(Set(premium.map(\.id)) == Set(expectedPremium.map(\.id)))
        #expect(premium.contains { $0.premium })
        #expect(Set(premium.flatMap(\.paths)) == Set(QuoteFixture.paths))
    }

    @Test("Düşünür modu: yalnız o düşünür, açık yoldaysa ücretsiz; tükenince boş ve benzer düşünürler")
    func thinkerMode() async throws {
        let quotes = QuoteFixture.quotes(800)
        let stoic = QuoteFixture.authorID(0), greek = QuoteFixture.authorID(1)
        let rig = QuoteFixture.rig(quotes, paths: ["stoacilar"])
        #expect(rig.engine.isAccessible(.thinker(stoic)))
        #expect(!rig.engine.isAccessible(.thinker(greek)))
        rig.engine.startSession()
        #expect(await rig.engine.nextBatch(mode: .thinker(greek), count: 5).isEmpty)

        let own = quotes.filter { $0.authorID == stoic && $0.kind == .quote }
        var shown: [Quote] = []
        for _ in 0..<10 {
            rig.engine.startSession()
            let batch = await rig.engine.nextBatch(mode: .thinker(stoic), count: 8)
            if batch.isEmpty { break }
            #expect(batch.allSatisfy { $0.authorID == stoic })
            for q in batch { await rig.engine.markSeen(q.id, dwell: .seconds(2)) }
            shown += batch
        }
        #expect(Set(shown.map(\.id)) == Set(own.map(\.id)) && shown.count == own.count)
        #expect(await rig.engine.remainingUnseen(mode: .thinker(stoic)) == 0)
        #expect(!QuoteFixture.repository(quotes).catalog.similar(to: stoic, limit: 3).isEmpty)

        let premium = QuoteFixture.rig(quotes, paths: ["stoacilar"], premium: true)
        premium.engine.startSession()
        let greekBatch = await premium.engine.nextBatch(mode: .thinker(greek), count: 5)
        #expect(greekBatch.count == 5 && greekBatch.allSatisfy { $0.authorID == greek })
    }

    @Test("Kuyruk kalıcı: aynı depo yeniden açılınca aynı sıradan devam eder")
    func queuePersists() async {
        let quotes = QuoteFixture.quotes(200)
        let local = MemoryKeyValueStore(), cloud = MemoryKeyValueStore(), clock = TestClock("2026-09-23T07:00:00Z")
        let container = ONE2TestStack.makeContainer()
        let content = QuoteFixture.repository(quotes)
        func engine() -> LiveQuoteEngine {
            LiveQuoteEngine(content: content, exposure: ExposureStore(context: container.viewContext, clock: clock),
                            profile: ProfileStore(cloud: cloud, local: MemoryKeyValueStore()), clock: clock,
                            cloud: cloud, local: local)
        }
        let a = engine()
        a.startSession()
        let first = await a.nextBatch(mode: .forYou, count: 3)
        let b = engine()
        b.startSession()
        #expect(await b.nextBatch(mode: .forYou, count: 3) == first)
    }

    // MARK: - E2.4 günün sözü

    @Test("İki cihaz aynı gün aynı günün sözünü görür; söz akışta tekrar çıkmaz")
    func dailyQuoteAcrossDevices() async throws {
        let quotes = QuoteFixture.quotes(300)
        let cloud = MemoryKeyValueStore()
        let deviceA = QuoteFixture.rig(quotes, cloud: cloud, paths: ["stoacilar"])
        let deviceB = QuoteFixture.rig(quotes, cloud: cloud)
        let day = DayKey("2026-09-23")!
        let a = try #require(await deviceA.engine.dailyQuote(for: day))
        #expect(await deviceB.engine.dailyQuote(for: day) == a)
        #expect(await deviceA.engine.dailyQuote(for: day) == a)

        // KVS henüz senkron olmasa da aynı veriden aynı seçim çıkar.
        let isolated = MemoryKeyValueStore()
        isolated.set(deviceA.profile.profile.userSalt.uuidString, forKey: ProfileStore.Key.userSalt)
        isolated.set(["stoacilar"], forKey: ProfileStore.Key.quotePaths)
        let deviceC = QuoteFixture.rig(quotes, cloud: isolated)
        #expect(await deviceC.engine.dailyQuote(for: day) == a)

        // Ertesi gün farklı söz.
        #expect(await deviceA.engine.dailyQuote(for: day.adding(days: 1)) != a)

        deviceA.engine.startSession()
        let feed = await deviceA.engine.nextBatch(mode: .forYou, count: 60)
        #expect(!feed.contains(a))
    }

    // MARK: - E2.2 kural 4, E2.6, listeler

    @Test("Yazılan söz 90 gün sonra en fazla haftada bir döner; ayar kapalıysa dönmez")
    func resurfacing() async throws {
        let quotes = QuoteFixture.quotes(20)
        let rig = QuoteFixture.rig(quotes)
        let entry = UUID()
        try rig.exposure.recordWritten(quotes[3].id, kind: .quote, entryID: entry)
        let day = rig.clock.today
        #expect(await rig.engine.resurfacingCandidate(on: day) == nil)

        rig.clock.advance(hours: 24 * 91)
        let today = rig.clock.today
        let r = try #require(await rig.engine.resurfacingCandidate(on: today))
        #expect(r.quote.id == quotes[3].id && r.entryID == entry)
        #expect(await rig.engine.resurfacingCandidate(on: today) == r) // aynı gün aynı
        #expect(await rig.engine.resurfacingCandidate(on: today.adding(days: 3)) == nil) // haftada bir

        rig.profile.update { $0.resurfaceWritten = false }
        #expect(await rig.engine.resurfacingCandidate(on: today.adding(days: 8)) == nil)
    }

    @Test("Görülmemiş sayısı ve content_pool_low tek sefer")
    func poolLow() async {
        let quotes = QuoteFixture.quotes(120)
        let rig = QuoteFixture.rig(quotes, premium: true)
        let expected = quotes.filter { $0.kind == .quote }.count
        var reports: [(String, Int)] = []
        rig.engine.onPoolLow = { reports.append(($0.key, $1)) }
        #expect(await rig.engine.remainingUnseen(mode: .forYou) == expected)
        _ = await rig.engine.remainingUnseen(mode: .forYou)
        #expect(reports.count == 1 && reports[0].0 == "forYou" && reports[0].1 == expected)
    }

    @Test("Favoriler ve yazılanlar kendi listelerinde, akış kurallarından bağımsız")
    func lists() async throws {
        let quotes = QuoteFixture.quotes(10)
        let rig = QuoteFixture.rig(quotes)
        await rig.engine.record(.liked, for: quotes[1].id)
        rig.clock.advance(hours: 1)
        await rig.engine.record(.liked, for: quotes[2].id)
        await rig.engine.record(.wroteAbout(UUID()), for: quotes[5].id)
        #expect(await rig.engine.nextBatch(mode: .favorites, count: 10).map(\.id) == [quotes[2].id, quotes[1].id])
        #expect(await rig.engine.nextBatch(mode: .written, count: 10).map(\.id) == [quotes[5].id])
        // Beğeni ve yazma görülme sayılır.
        #expect(try rig.exposure.seenIDs(.quote) == [quotes[1].id, quotes[2].id, quotes[5].id])
        await rig.engine.record(.unliked, for: quotes[1].id)
        #expect(await rig.engine.nextBatch(mode: .favorites, count: 10).map(\.id) == [quotes[2].id])
    }

    // MARK: - Saf çekirdek

    @Test("Çeşitlilik: aynı yazar 8 kartta bir, aynı tür en çok 3, 5 kartta bir kısa, aynı tema en çok 2")
    func diversityRules() {
        func q(_ id: String, kind: QuoteKind = .reflection, author: String? = nil, short: Bool = false,
               themes: [String] = ["a"]) -> Quote {
            Quote(id: id, text: short ? "Kısa." : String(repeating: "uzun ", count: 15), kind: kind,
                  author: author, themes: themes)
        }
        #expect(QuoteSelection.violations(q("x", author: "A"), after: [q("1", author: "A")] + (0..<6).map { q("f\($0)", kind: .proverb, short: true, themes: ["t\($0)"]) }) == 1)
        #expect(QuoteSelection.violations(q("x", author: "A", short: true, themes: ["z"]),
                                          after: [q("1", author: "A")] + (0..<7).map { q("f\($0)", kind: .proverb, short: true, themes: ["t\($0)"]) }) == 0)
        #expect(QuoteSelection.violations(q("x", kind: .proverb, short: true, themes: ["z"]),
                                          after: (0..<3).map { q("p\($0)", kind: .proverb, short: true, themes: ["t\($0)"]) }) == 1)
        #expect(QuoteSelection.violations(q("x", themes: ["z"]), after: (0..<4).map { q("l\($0)", kind: .proverb, themes: ["t\($0)"]) }) == 1)
        #expect(QuoteSelection.violations(q("x", short: true, themes: ["a"]), after: [q("1", short: true), q("2", short: true)]) == 1)
    }
}
