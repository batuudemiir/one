//
//  ONE2StoreTests.swift
//  oneTests
//
//  ONE 2.0 depoları: gün anahtarı, geriye dönük giriş, ilişkiler ve
//  senkron çiftlerinin deterministik birleştirilmesi.
//

import Testing
import Foundation
import CoreData
@testable import OneDailyBatuhan

// Saat: 23 Eylül 2026, İstanbul 13:00.
private let noon = "2026-09-23T10:00:00Z"

@MainActor
struct JournalStoreTests {
    let container = ONE2TestStack.makeContainer()
    let clock = TestClock(noon)
    var store: JournalStore { JournalStore(context: container.viewContext, clock: clock) }

    @Test("Bugünün girdisi: gün, saat dilimi, kelime sayısı")
    func createToday() throws {
        let entry = try store.create(EntryDraft(kind: .freeform, title: "Sabah", body: "# Bugün\n- iyi bir gün, 3 iş"))
        #expect(entry.day.string == "2026-09-23")
        #expect(entry.timeZoneID == "Europe/Istanbul")
        #expect(entry.wordCount == 6) // "#" ve "-" kelime değil
        #expect(!entry.isBackfilled)
        #expect(entry.createdAt == clock.now)
    }

    @Test("Gece yarısından sonra yazılan girdi yeni güne düşer")
    func dayFollowsLocalMidnight() throws {
        clock.now = ISO8601DateFormatter().date(from: "2026-09-23T21:30:00Z")! // İstanbul 00:30, 24 Eylül
        #expect(try store.create(EntryDraft(kind: .freeform)).day.string == "2026-09-24")
    }

    @Test("Geriye dönük girdi: gün geçmişte, createdAt şimdi")
    func backfill() throws {
        let past = DayKey("2026-09-20")!
        let entry = try store.create(EntryDraft(kind: .evening, body: "unuttum"), on: past)
        #expect(entry.day == past)
        #expect(entry.isBackfilled)
        #expect(entry.createdAt == clock.now)
    }

    @Test("Gelecek güne girdi yazılamaz")
    func futureRejected() {
        #expect(throws: StoreError.self) {
            try store.create(EntryDraft(kind: .freeform), on: DayKey("2026-09-24")!)
        }
    }

    @Test("Cevaplar sırası ve tipleriyle geri gelir")
    func answersRoundTrip() throws {
        let answers = [
            EntryAnswer(kind: .text, stepRef: "s1", questionSnapshot: "Ne öğrendin?", text: "sabır"),
            EntryAnswer(kind: .scale5, number: 4),
            EntryAnswer(kind: .yesNo, bool: false),
            EntryAnswer(kind: .multiChoice, choices: ["iş", "uyku"])
        ]
        let entry = try store.create(EntryDraft(kind: .guided, contentRef: "guided:gratitude-01", answers: answers))
        #expect(entry.answers.map(\.kind) == [.text, .scale5, .yesNo, .multiChoice])
        #expect(entry.answers[0].text == "sabır")
        #expect(entry.answers[0].number == nil)
        #expect(entry.answers[1].number == 4)
        #expect(entry.answers[2].bool == false)
        #expect(entry.answers[3].choices == ["iş", "uyku"])
        #expect(entry.contentRef == "guided:gratitude-01")
    }

    @Test("Güncelleme metni, etiketleri ve cevapları değiştirir")
    func update() throws {
        let library = LibraryStore(context: container.viewContext, clock: clock)
        let tag = try library.createTag(name: "iş")
        let entry = try store.create(EntryDraft(kind: .freeform, body: "bir", answers: [EntryAnswer(kind: .text, text: "a")]))
        clock.advance(hours: 1)
        let updated = try store.update(entry.id, title: "Başlık", body: "bir iki üç",
                                       tagIDs: [tag.id], answers: [EntryAnswer(kind: .yesNo, bool: true)])
        #expect(updated.wordCount == 3)
        #expect(updated.tagIDs == [tag.id])
        #expect(updated.answers.map(\.kind) == [.yesNo])
        #expect(updated.updatedAt > updated.createdAt)
        let orphanAnswers = try container.viewContext.count(for: NSFetchRequest<NSManagedObject>(entityName: "EntryAnswer"))
        #expect(orphanAnswers == 1)
    }

    @Test("Silme cevapları da siler, mood kaydı kalır")
    func deleteCascades() throws {
        let entry = try store.create(EntryDraft(kind: .dailyCheckIn, answers: [EntryAnswer(kind: .text, text: "x")]))
        let mood = try MoodStore(context: container.viewContext, clock: clock)
            .log(score: 3, source: .checkIn, linkedTo: entry.id)
        try store.delete(entry.id)
        let context = container.viewContext
        #expect(try context.count(for: NSFetchRequest<NSManagedObject>(entityName: "EntryAnswer")) == 0)
        let logs = try MoodStore(context: context, clock: clock).logs(on: mood.day)
        #expect(logs.map(\.id) == [mood.id])
        #expect(logs[0].entryID == nil)
    }

    @Test("Aralık sorgusu: yeni gün önce, gün içinde yazılış sırası")
    func rangeOrdering() throws {
        let a = try store.create(EntryDraft(kind: .freeform, title: "a"), on: DayKey("2026-09-21")!)
        let b = try store.create(EntryDraft(kind: .freeform, title: "b"))
        clock.advance(hours: 1)
        let c = try store.create(EntryDraft(kind: .freeform, title: "c"))
        _ = try store.create(EntryDraft(kind: .freeform, title: "dışarıda"), on: DayKey("2026-09-10")!)
        let ids = try store.entries(from: DayKey("2026-09-20")!, through: DayKey("2026-09-23")!).map(\.id)
        #expect(ids == [b.id, c.id, a.id])
    }
}

@MainActor
struct MoodStoreTests {
    let container = ONE2TestStack.makeContainer()
    let clock = TestClock(noon)
    var store: MoodStore { MoodStore(context: container.viewContext, clock: clock) }

    @Test("Skor 1–5 dışında reddedilir")
    func scoreRange() {
        #expect(throws: StoreError.invalidValue("score 0")) { try store.log(score: 0, source: .launch) }
        #expect(throws: StoreError.invalidValue("score 6")) { try store.log(score: 6, source: .launch) }
    }

    @Test("Duygu ve nedenler geri gelir, girdiye bağlanır")
    func logRoundTrip() throws {
        let entry = try JournalStore(context: container.viewContext, clock: clock).create(EntryDraft(kind: .emotionCheckIn))
        let log = try store.log(score: 4, emotionIDs: ["calm", "grateful"], causeIDs: ["sleep"],
                                note: "iyi uyudum", source: .emotionCheckIn, linkedTo: entry.id)
        #expect(log.emotionIDs == ["calm", "grateful"])
        #expect(log.causeIDs == ["sleep"])
        #expect(log.entryID == entry.id)
        #expect(try JournalStore(context: container.viewContext, clock: clock).entry(entry.id)?.moodID == log.id)
    }

    @Test("Günde birden çok check-in zaman sırasıyla")
    func multiplePerDay() throws {
        let first = try store.log(score: 2, source: .launch)
        clock.advance(hours: 3)
        let second = try store.log(score: 5, source: .widget)
        #expect(try store.logs(on: DayKey("2026-09-23")!).map(\.id) == [first.id, second.id])
    }

    @Test("Var olmayan girdiye bağlama hata verir, yarım kayıt kalmaz")
    func missingEntry() throws {
        #expect(throws: StoreError.notFound) { try store.log(score: 3, source: .checkIn, linkedTo: UUID()) }
        #expect(try store.logs(on: DayKey("2026-09-23")!).isEmpty)
    }
}

@MainActor
struct DayStoreTests {
    let container = ONE2TestStack.makeContainer()
    let clock = TestClock(noon)
    var store: DayStore { DayStore(context: container.viewContext, clock: clock) }

    @Test("Kart tamamlama ilk zamanı korur")
    func keepsFirstCompletion() throws {
        let first = try store.markCompleted(.daily)
        clock.advance(hours: 2)
        let again = try store.markCompleted(.daily)
        #expect(again.dailyCompletedAt == first.dailyCompletedAt)
        #expect(try container.viewContext.count(for: NSFetchRequest<NSManagedObject>(entityName: "DayRecord")) == 1)
    }

    @Test("Geçmiş günü tamamlamak geriye dönük işaretler ve seriyi onarır")
    func backfillHealsStreak() throws {
        let today = DayKey("2026-09-23")!
        try store.markCompleted(.daily)
        try store.markCompleted(.daily, on: today.adding(days: -2))
        #expect(try store.currentStreak(mode: .daily) == 1)
        try store.markCompleted(.daily, on: today.adding(days: -1))
        #expect(try store.currentStreak(mode: .daily) == 3)
        let backfilled: [DayRecordMO] = try container.viewContext.fetchAll("DayRecord",
            where: NSPredicate(format: "backfilledAt != nil"))
        #expect(backfilled.count == 2)
    }

    @Test("Sabah-akşam modunda iki kart gerekir")
    func morningEvening() throws {
        try store.markCompleted(.morning)
        #expect(try store.currentStreak(mode: .morningEvening) == 0)
        try store.markCompleted(.evening)
        #expect(try store.currentStreak(mode: .morningEvening) == 1)
    }

    @Test("Senkron çiftleri deterministik birleşir: en erken zaman, en küçük id")
    func reconcile() throws {
        let context = container.viewContext
        let early = ISO8601DateFormatter().date(from: "2026-09-23T05:00:00Z")!
        let late = ISO8601DateFormatter().date(from: "2026-09-23T08:00:00Z")!
        let idA = UUID(uuidString: "00000000-0000-0000-0000-00000000000A")!
        let idB = UUID(uuidString: "00000000-0000-0000-0000-00000000000B")!
        let a: DayRecordMO = context.insert("DayRecord")
        a.id = idB; a.dayKey = "2026-09-23"; a.morningCompletedAt = late; a.focusText = "odak"
        let b: DayRecordMO = context.insert("DayRecord")
        b.id = idA; b.dayKey = "2026-09-23"; b.morningCompletedAt = early; b.eveningCompletedAt = late
        try context.save()

        // Birleşmeden önce bile okuma birleşik görünür.
        let before = try #require(try store.completions(from: DayKey("2026-09-23")!, through: DayKey("2026-09-23")!).first)
        #expect(before.morningCompletedAt == early)

        #expect(try store.reconcileDuplicates() == 1)
        let rows: [DayRecordMO] = try context.fetchAll("DayRecord")
        #expect(rows.count == 1)
        #expect(rows[0].id == idA)
        #expect(rows[0].morningCompletedAt == early)
        #expect(rows[0].eveningCompletedAt == late)
        #expect(rows[0].focusText == "odak")
    }

    @Test("Odak metni güne yazılır")
    func focus() throws {
        try store.setFocus("sakin kal")
        #expect(try store.focus(on: DayKey("2026-09-23")!) == "sakin kal")
    }
}

@MainActor
struct LibraryStoreTests {
    let container = ONE2TestStack.makeContainer()
    let clock = TestClock(noon)
    var store: LibraryStore { LibraryStore(context: container.viewContext, clock: clock) }

    @Test("Aynı adlı etiket ikinci kez oluşmaz")
    func tagDedupe() throws {
        let a = try store.createTag(name: "Aile")
        let b = try store.createTag(name: "  aile ")
        #expect(a.id == b.id)
        #expect(try store.tags().count == 1)
        #expect(throws: StoreError.self) { try store.createTag(name: "   ") }
    }

    @Test("Türkçe yerel ayarda İ/i eşleşir")
    func turkishCaseFolding() throws {
        let tr = LibraryStore(context: container.viewContext, clock: clock, locale: Locale(identifier: "tr_TR"))
        let a = try tr.createTag(name: "İş")
        #expect(try tr.createTag(name: "iş").id == a.id)
    }

    @Test("Etiket silinince girdi kalır")
    func deleteTagKeepsEntry() throws {
        let tag = try store.createTag(name: "aile")
        let journal = JournalStore(context: container.viewContext, clock: clock)
        let entry = try journal.create(EntryDraft(kind: .freeform, tagIDs: [tag.id]))
        try store.deleteTag(tag.id)
        #expect(try journal.entry(entry.id)?.tagIDs.isEmpty == true)
    }

    @Test("Rozet bir kez verilir, senkron çifti birleşir")
    func badges() throws {
        let first = try store.award("streak-7")
        clock.advance(hours: 1)
        #expect(try store.award("streak-7").id == first.id)

        let dup: BadgeAwardMO = container.viewContext.insert("BadgeAward")
        dup.id = UUID(); dup.badgeID = "streak-7"; dup.earnedAt = clock.now
        try container.viewContext.save()
        #expect(try store.badges().map(\.id) == [first.id])
        #expect(try store.reconcileDuplicateBadges() == 1)
    }

    @Test("Pratikler sıralı ve tekil")
    func practices() throws {
        try store.addPractice("guided:breath-01")
        try store.addPractice("quote:seneca-3")
        try store.addPractice("guided:breath-01")
        #expect(try store.practices().map(\.contentRef) == ["guided:breath-01", "quote:seneca-3"])
        try store.removePractice("guided:breath-01")
        #expect(try store.practices().map(\.contentRef) == ["quote:seneca-3"])
    }
}
