//
//  ExposureStoreTests.swift
//  oneTests
//
//  E3: maruz kalma kaydı — toplu yazma, dedupe, okuma (04_arka_plan_motorlari.md).
//

import Testing
import Foundation
import CoreData
@testable import OneDailyBatuhan

@MainActor
struct ExposureStoreTests {
    let container = ONE2TestStack.makeContainer()
    let clock = TestClock("2026-09-23T09:00:00Z")

    var store: ExposureStore { ExposureStore(context: container.viewContext, clock: clock) }

    private func rowCount() throws -> Int {
        try container.viewContext.count(for: NSFetchRequest<NSManagedObject>(entityName: ONE2Entity.exposure))
    }

    @Test("Görülmeler 10 olayda bir tek kayıtla yazılıyor; okuma bekleyenleri de görüyor")
    func batchedWrites() throws {
        let store = self.store
        for i in 1...9 { store.recordSeen("q_\(i)", kind: .quote) }
        #expect(try rowCount() == 0)
        #expect(store.pendingCount == 9)
        #expect(try store.seenIDs(.quote).count == 9)
        #expect(try store.snapshot(.quote).seenIDs.count == 9)

        store.recordSeen("q_10", kind: .quote)
        #expect(store.pendingCount == 0)
        #expect(try rowCount() == 10)
    }

    @Test("Aynı içerik tekrar görülünce satır çoğalmıyor, sayı artıyor")
    func repeatSeen() throws {
        let store = self.store
        store.recordSeen("q_1", kind: .quote)
        clock.advance(hours: 2)
        store.recordSeen("q_1", kind: .quote)
        try store.flush()
        clock.advance(hours: 2)
        store.recordSeen("q_1", kind: .quote)
        try store.flush()

        #expect(try rowCount() == 1)
        let record = try #require(try store.record("q_1", kind: .quote))
        #expect(record.seenCount == 3)
        #expect(record.firstSeenAt == ISO8601DateFormatter().date(from: "2026-09-23T09:00:00Z"))
        #expect(record.lastSeenAt == ISO8601DateFormatter().date(from: "2026-09-23T13:00:00Z"))
    }

    @Test("Tür ayrımı: aynı ID farklı türde ayrı kayıt")
    func kindsAreSeparate() throws {
        let store = self.store
        store.recordSeen("x_1", kind: .quote)
        store.recordSeen("x_1", kind: .prompt)
        try store.flush()
        #expect(try rowCount() == 2)
        #expect(try store.seenIDs(.echo).isEmpty)
    }

    @Test("Toplu yazma yarıda kalırsa yalnız son flush'tan sonrası kaybolur")
    func crashDuringBatch() throws {
        let store = self.store
        for i in 1...10 { store.recordSeen("q_\(i)", kind: .quote) } // yazıldı
        for i in 11...14 { store.recordSeen("q_\(i)", kind: .quote) } // bellekte
        // Uygulama kapandı: yeni depo aynı store'u açıyor, bellek yok.
        let reopened = ExposureStore(context: container.viewContext, clock: clock)
        let seen = try reopened.seenIDs(.quote)
        #expect(seen == Set((1...10).map { "q_\($0)" }))
        #expect(try reopened.snapshot(.quote).records.values.allSatisfy { $0.seenCount == 1 })
    }

    @Test("Beğeni ve yazma beklemeden yazılıyor ve bekleyen görülmeleri de götürüyor")
    func likeAndWriteAreImmediate() throws {
        let store = self.store
        store.recordSeen("q_1", kind: .quote)
        try store.setLiked(true, id: "q_2", kind: .quote)
        #expect(store.pendingCount == 0)
        #expect(try rowCount() == 2)

        let entry = UUID()
        try store.recordWritten("q_3", kind: .quote, entryID: entry)
        let snap = try store.snapshot(.quote)
        #expect(snap.likedIDs == ["q_2"])
        #expect(snap.writtenIDs == ["q_3"])
        #expect(snap["q_3"]?.lastEntryID == entry)
        #expect(snap["q_3"]?.wasSeen == true)

        try store.setLiked(false, id: "q_2", kind: .quote)
        #expect(try store.snapshot(.quote).likedIDs.isEmpty)
        #expect(try store.record("q_2", kind: .quote)?.likedAt == nil)
    }

    @Test("İki cihazdan gelen aynı contentID birleşiyor: en erken ilk görülme, toplam sayı, beğeni VEYA")
    func reconcileDuplicates() throws {
        let ctx = container.viewContext
        let t0 = Date(timeIntervalSince1970: 1_790_000_000)
        let entryA = UUID(), entryB = UUID()
        func row(first: Double, last: Double, seen: Int32, liked: Bool, written: Int16, writtenAt: Double?, entry: UUID?) {
            let r: ContentExposureMO = ctx.insert(ONE2Entity.exposure)
            r.id = UUID(); r.contentID = "q_1"; r.contentKind = "quote"
            r.firstSeenAt = t0 + first; r.lastSeenAt = t0 + last; r.seenCount = seen
            r.liked = liked; r.likedAt = liked ? t0 + last : nil
            r.writtenCount = written; r.lastWrittenAt = writtenAt.map { t0 + $0 }; r.lastEntryID = entry
        }
        row(first: 100, last: 500, seen: 2, liked: false, written: 1, writtenAt: 400, entry: entryA)
        row(first: 50, last: 300, seen: 3, liked: true, written: 1, writtenAt: 450, entry: entryB)
        try ctx.save()

        // Okuma, uzlaştırma beklemeden birleştiriyor.
        let before = try #require(try store.record("q_1", kind: .quote))
        #expect(before.seenCount == 5)

        #expect(try store.reconcileDuplicates() == 1)
        #expect(try rowCount() == 1)
        let merged = try #require(try store.record("q_1", kind: .quote))
        #expect(merged.firstSeenAt == t0 + 50)
        #expect(merged.lastSeenAt == t0 + 500)
        #expect(merged.seenCount == 5)
        #expect(merged.liked)
        #expect(merged.writtenCount == 2)
        #expect(merged.lastEntryID == entryB)
        #expect(merged.lastWrittenAt == t0 + 450)
        #expect(try store.reconcileDuplicates() == 0)
    }

    @Test("Birleştirme kuralı sıradan bağımsız")
    func mergeIsCommutative() {
        let t0 = Date(timeIntervalSince1970: 0)
        let a = ExposureRecord(contentID: "q", kind: .quote, firstSeenAt: t0 + 10, lastSeenAt: t0 + 20, seenCount: 1,
                               liked: true, likedAt: t0 + 15, lastEntryID: UUID(), lastWrittenAt: t0 + 12, writtenCount: 1)
        let b = ExposureRecord(contentID: "q", kind: .quote, firstSeenAt: t0 + 5, lastSeenAt: t0 + 30, seenCount: 2,
                               liked: false, lastEntryID: UUID(), lastWrittenAt: t0 + 12, writtenCount: 1)
        #expect(ExposureRecord.merged(a, b) == ExposureRecord.merged(b, a))
    }

    @Test("10 bin satırda görülmüş ID sorgusu 50 ms altında")
    func candidateQueryPerformance() throws {
        let ctx = container.viewContext
        let kinds: [ContentKind] = [.quote, .prompt, .echo]
        for i in 0..<10_000 {
            let r: ContentExposureMO = ctx.insert(ONE2Entity.exposure)
            r.id = UUID(); r.contentID = String(format: "q_%06d", i); r.contentKind = kinds[i % 3].rawValue
            r.firstSeenAt = clock.now; r.lastSeenAt = clock.now; r.seenCount = 1
        }
        try ctx.save()
        ctx.reset()

        let store = self.store
        _ = try store.seenIDs(.quote) // ısınma
        let start = Date()
        let ids = try store.seenIDs(.quote)
        let elapsed = Date().timeIntervalSince(start)
        #expect(ids.count == 3_334)
        #expect(elapsed < 0.05, "\(elapsed * 1000) ms")
    }
}
