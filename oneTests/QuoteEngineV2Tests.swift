//
//  QuoteEngineV2Tests.swift
//  oneTests
//
//  S4: puanlama v2, düşünür yakınlığı, çeşitlilik ve keşif payı
//  (08_sozler_ve_dusunurler.md › §4.3–§4.5, §7).
//

import Testing
import Foundation
import CoreData
@testable import OneDailyBatuhan

@MainActor
struct QuoteEngineV2Tests {

    // MARK: - Yakınlık (08 §4.5)

    @Test("Yakınlık: olay puanları, 30 gün yarı ömür, [−3, +10] sınırı, susturma ve yenilik")
    func affinitySignals() {
        let quotes = QuoteFixture.quotes(200)
        let catalog = QuoteFixture.repository(quotes).catalog
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let day = 86_400.0
        let a = QuoteFixture.authorID(0), b = QuoteFixture.authorID(1), c = QuoteFixture.authorID(2)
        let d = QuoteFixture.authorID(3), e = QuoteFixture.authorID(4)
        func id(_ author: Int, _ n: Int) -> QuoteID { String(format: "q_%06d", author + 1 + 40 * n) }
        let records: [ExposureRecord] = [
            // a: beğeni (bugün) + yazma (30 gün önce) → 1 + 3 × 0,5
            ExposureRecord(contentID: id(0, 0), kind: .quote, firstSeenAt: now, lastSeenAt: now, seenCount: 1,
                           liked: true, likedAt: now),
            ExposureRecord(contentID: id(0, 1), kind: .quote, firstSeenAt: now - 30 * day, lastSeenAt: now - 30 * day,
                           seenCount: 1, lastWrittenAt: now - 30 * day, writtenCount: 1),
            // b: 5 yazma + 3 paylaşım bugün → 21, üst sınır 10
            ExposureRecord(contentID: id(1, 0), kind: .quote, lastSeenAt: now - 10 * day, seenCount: 1,
                           lastWrittenAt: now, writtenCount: 5, shareCount: 3, lastSharedAt: now),
            // c: 10 hızlı geçiş bugün → −3 (susturulur), görülmedi
            ExposureRecord(contentID: id(2, 0), kind: .quote, skipCount: 10, lastSkippedAt: now),
            // d: 2 uzun bakış 60 gün önce → 2 × 0,5 × 0,25
            ExposureRecord(contentID: id(3, 0), kind: .quote, firstSeenAt: now - 60 * day, lastSeenAt: now - 60 * day,
                           seenCount: 1, longLookCount: 2, lastLongLookAt: now - 60 * day),
        ]
        let snapshot = ExposureSnapshot(kind: .quote, records: Dictionary(uniqueKeysWithValues: records.map { ($0.contentID, $0) }))
        let s = ThinkerSignals.from(snapshot, catalog: catalog, now: now)
        #expect(abs(s.score(a) - 2.5) < 1e-9)
        #expect(s.score(b) == 10)
        #expect(s.score(c) == -3 && s.isMuted(c))
        #expect(abs(s.score(d) - 0.25) < 1e-9)
        #expect(s.score(e) == 0 && !s.isMuted(e))
        #expect(s.scaled(b) == 1 && s.scaled(c) == 0)
        // Yenilik: hiç görülmedi 1, son 7 günde 0, daha eski 0,5.
        #expect(s.novelty(e, now: now) == 1 && s.novelty(c, now: now) == 1)
        #expect(s.novelty(a, now: now) == 0)
        #expect(s.novelty(b, now: now) == 0.5)
    }

    @Test("Motor olayları: hızlı geçiş, uzun bakış ve paylaşım yakınlığa yazılır; hızlı geçiş görülme sayılmaz")
    func engineRecordsAffinityEvents() async throws {
        let quotes = QuoteFixture.quotes(100)
        let rig = QuoteFixture.rig(quotes, premium: true)
        let q = quotes[0], author = try #require(q.authorID)
        await rig.engine.markSeen(q.id, dwell: .milliseconds(400))
        #expect(try !rig.exposure.seenIDs(.quote).contains(q.id))
        #expect(abs(await rig.engine.affinity(for: author) - (-0.3)) < 1e-9)
        await rig.engine.markSeen(q.id, dwell: .seconds(5))
        await rig.engine.record(.shared, for: q.id)
        #expect(abs(await rig.engine.affinity(for: author) - (-0.3 + 0.5 + 2)) < 1e-9)
        try rig.exposure.flush()
        let r = try #require(try rig.exposure.record(q.id, kind: .quote))
        #expect(r.skipCount == 1 && r.longLookCount == 1 && r.shareCount == 1 && r.seenCount == 2)
    }

    @Test("Susturulan düşünür (skor ≤ −2) Sana özel'e girmez")
    func mutedThinkerLeavesForYou() async {
        let quotes = QuoteFixture.quotes(400)
        let rig = QuoteFixture.rig(quotes, premium: true)
        let muted = QuoteFixture.authorID(0)
        let target = quotes.first { $0.authorID == muted }!
        for _ in 0..<8 { await rig.engine.markSeen(target.id, dwell: .milliseconds(100)) }
        #expect(await rig.engine.affinity(for: muted) <= ThinkerSignals.mutedAt)
        rig.engine.startSession()
        let batch = await rig.engine.nextBatch(mode: .forYou, count: 30)
        #expect(!batch.isEmpty && !batch.contains { $0.authorID == muted })
        // Düşünür sayfasında açık kalır.
        #expect(!(await rig.engine.nextBatch(mode: .thinker(muted), count: 3)).isEmpty)
    }

    // MARK: - Çeşitlilik ve keşif (08 §4.4)

    @Test("Kısıtlar: aynı yol 3'ten fazla arka arkaya yok; düşünür günde 2; düşünür ve yol modunda gevşer")
    func pathAndDailyRules() {
        func q(_ id: String, author: String, path: String, short: Bool = true, theme: String) -> Quote {
            Quote(id: id, text: short ? "Kısa." : String(repeating: "uzun ", count: 15), kind: .quote,
                  authorID: author, themes: [theme], paths: [path])
        }
        let three = (0..<3).map { q("s\($0)", author: "a\($0)", path: "stoacilar", theme: "t\($0)") }
        let next = q("x", author: "z", path: "stoacilar", theme: "z")
        #expect(QuoteSelection.violations(next, after: three) == 1)
        #expect(QuoteSelection.violations(next, after: three, rules: .for(.path("stoacilar"))) == 0)
        #expect(QuoteSelection.violations(q("y", author: "z", path: "antik_yunan", theme: "z"), after: three) == 0)
        #expect(QuoteSelection.violations(next, after: [], dayCounts: ["z": 2]) == 1)
        #expect(QuoteSelection.violations(next, after: [], dayCounts: ["z": 1]) == 0)
        #expect(QuoteSelection.violations(next, after: [q("p", author: "z", path: "x", theme: "p")],
                                          rules: .for(.thinker("z")), dayCounts: ["z": 5]) == 0)
    }

    @Test("Keşif payı: her 10. kart keşif adayından; tanıtım hakkı bitince yerine normal kart")
    func assembleDiscovery() {
        let ranked = (0..<30).map { Quote(id: "r\($0)", text: "Kısa \($0).", kind: .quote, authorID: "a\($0)", paths: ["stoacilar"]) }
        let discovery = (0..<5).map { Quote(id: "d\($0)", text: "Kısa d\($0).", kind: .quote, authorID: "n\($0)", paths: ["varoluscular"]) }
        let all = QuoteSelection.assemble(ranked, discovery: discovery, count: 30, startIndex: 0)
        #expect(all.discoveryIDs == ["d0", "d1", "d2"])
        #expect(all.quotes[9].id == "d0" && all.quotes[19].id == "d1" && all.quotes[29].id == "d2")

        let capped = QuoteSelection.assemble(ranked, discovery: discovery, count: 30, startIndex: 5,
                                             introLimit: 1, isIntro: { _ in true })
        #expect(capped.discoveryIDs == ["d0"] && capped.quotes[4].id == "d0")
        #expect(capped.quotes.count == 30)
    }

    // MARK: - Simülasyon (08 §7 › S4)

    struct SimResult {
        var cards = 0, repeats = 0, minThinkerGap = Int.max, maxPerDay = 0, discovery = 0, intros = 0
        var maxIntroPerDay = 0, windowViolations = 0, tones: [String: Int] = [:]
    }

    /// `cards` kart gösterilene kadar 5–15 kartlık oturumlar; her kartta 2 sn; oturum arası 9 saat.
    static func simulate(_ rig: QuoteFixture.Rig, cards: Int, premium: Bool = true,
                         seed: UInt64 = 7) async throws -> SimResult {
        var rng = SeededRandom(seed: seed)
        var order: [(Quote, DayKey)] = []
        var r = SimResult()
        var lastIndex: [ThinkerID: Int] = [:]
        var perDay: [String: Int] = [:], introsPerDay: [DayKey: Int] = [:]
        var seen: Set<QuoteID> = []
        while order.count < cards {
            rig.engine.startSession()
            let batch = await rig.engine.nextBatch(mode: .forYou, count: 5 + Int(rng.next() % 11))
            if batch.isEmpty { break }
            for q in batch where order.count < cards {
                await rig.engine.markSeen(q.id, dwell: .seconds(2))
                let day = rig.clock.today
                if !seen.insert(q.id).inserted { r.repeats += 1 }
                if let t = q.authorID {
                    if let last = lastIndex[t] { r.minThinkerGap = min(r.minThinkerGap, order.count - last) }
                    lastIndex[t] = order.count
                    perDay["\(day.string)|\(t)", default: 0] += 1
                }
                if rig.engine.isDiscovery(q.id) {
                    r.discovery += 1
                    if !premium, !q.paths.contains(rig.profile.profile.freeQuotePath) || q.premium {
                        introsPerDay[day, default: 0] += 1
                    }
                }
                for t in q.tones { r.tones[t, default: 0] += 1 }
                order.append((q, day))
            }
            rig.clock.advance(hours: 9)
        }
        r.cards = order.count
        r.maxPerDay = perDay.values.max() ?? 0
        r.intros = introsPerDay.values.reduce(0, +)
        r.maxIntroPerDay = introsPerDay.values.max() ?? 0
        let quotes = order.map(\.0)
        // Motorun o moddaki kuralları (ücretsizde yol kuralı yok); günlük sınır ayrıca `maxPerDay`.
        let rules = premium ? DiversityRules.all : DiversityRules(sameThinker: true, samePath: false)
        for i in quotes.indices where QuoteSelection.violations(quotes[i], after: Array(quotes[..<i]), rules: rules) > 0 {
            r.windowViolations += 1
        }
        return r
    }

    static func report(_ label: String, _ r: SimResult) {
        let share = Double(r.discovery) / Double(max(1, r.cards)) * 100
        let toneTotal = max(1, r.tones.values.reduce(0, +))
        let tones = QuoteTone.allCases.map { t in
            String(format: "%@ %%%.0f", t.rawValue, Double(r.tones[t.rawValue] ?? 0) / Double(toneTotal) * 100)
        }.joined(separator: " · ")
        print(String(format: "SIM| %@ | kart %d | tekrar %d | min düşünür aralığı %d | günde en çok %d | keşif %d (%%%.1f) | tanıtım %d (günde en çok %d) | çeşitlilik ihlali %d | ton: %@",
                     label, r.cards, r.repeats, r.minThinkerGap, r.maxPerDay, r.discovery, share,
                     r.intros, r.maxIntroPerDay, r.windowViolations, tones))
    }

    @Test("Simülasyon: 1.000 kart — tekrar 0, 8'lik pencerede aynı düşünür ≤ 1, keşif payı %10 ± 2, skor ≤ 2'de yumuşak ton ağırlıklı")
    func thousandCardSimulation() async throws {
        let quotes = QuoteFixture.quotes(1_500)

        // A: premium, iki yol, nötr ruh hali.
        let a = try await Self.simulate(QuoteFixture.rig(quotes, paths: ["stoacilar", "antik_yunan"], premium: true), cards: 1_000)
        Self.report("premium 2 yol", a)
        #expect(a.cards == 1_000 && a.repeats == 0)
        #expect(a.minThinkerGap >= 8, "8'lik pencerede aynı düşünür")
        #expect(a.maxPerDay <= QuoteSelection.thinkerDailyLimit)
        #expect(a.windowViolations == 0)
        let share = Double(a.discovery) / Double(a.cards)
        #expect(abs(share - 0.10) <= 0.02, "keşif payı \(share)")

        // B: ücretsiz, tek yol: tanıtım kartı günde en fazla 2.
        let b = try await Self.simulate(QuoteFixture.rig(quotes, paths: ["stoacilar"]), cards: 200, premium: false)
        Self.report("ücretsiz 1 yol", b)
        #expect(b.repeats == 0)
        #expect(b.maxIntroPerDay <= QuoteSelection.introDailyLimit)
        #expect(b.intros > 0)

        // C/D: skor 2 ve 5 — ton dağılımı (fixture'da her ton %20).
        let low = try await Self.simulate(QuoteFixture.rig(quotes, paths: ["stoacilar", "antik_yunan"], premium: true, mood: 2), cards: 200)
        let high = try await Self.simulate(QuoteFixture.rig(quotes, paths: ["stoacilar", "antik_yunan"], premium: true, mood: 5), cards: 200)
        Self.report("skor 2", low)
        Self.report("skor 5", high)
        func ratio(_ r: SimResult, _ set: Set<String>) -> Double {
            Double(set.map { r.tones[$0] ?? 0 }.reduce(0, +)) / Double(max(1, r.tones.values.reduce(0, +)))
        }
        #expect(low.repeats == 0)
        #expect(ratio(low, QuoteSelection.lowMoodTones) >= 0.6)
        #expect(ratio(low, QuoteSelection.highEnergyTones) <= 0.15)
        #expect(ratio(low, QuoteSelection.lowMoodTones) > ratio(high, QuoteSelection.lowMoodTones))
    }
}
