//
//  LegacyMomentStoreTests.swift
//  oneTests
//
//  B' okuma katmanı ve yazma emniyet ağı (MIGRATION.md §7: T5, T8, T9).
//

import Testing
import Foundation
import CoreData
@testable import OneDailyBatuhan

@MainActor
struct LegacyMomentStoreTests {
    let container = ONE2TestStack.makeContainer()

    private func calendar(_ id: String) -> Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: id)!
        return cal
    }

    /// v3'ün yazdığı gibi: `date` yazan cihazın saat diliminde gece yarısı.
    @discardableResult
    private func insertV3(_ day: String, hour: Int = 9, tz: String = "Europe/Istanbul",
                          hex: String = "#FF3B1F", note: String? = nil, photo: Data? = nil,
                          passed: Bool = false, id: UUID? = UUID(), entryIndex: Int16 = 0) -> NSManagedObject {
        let cal = calendar(tz)
        let midnight = DayKey(day)!.startDate(in: cal)!
        let row = NSEntityDescription.insertNewObject(forEntityName: "DailySong", into: container.viewContext)
        row.setValue(id, forKey: "id")
        row.setValue(midnight, forKey: "date")
        row.setValue(midnight.addingTimeInterval(Double(hour) * 3600), forKey: "createdAt")
        row.setValue(hex, forKey: "moodColorHex")
        row.setValue(note, forKey: "dailyNote")
        row.setValue(photo, forKey: "photoData")
        row.setValue(passed, forKey: "passed")
        row.setValue(entryIndex, forKey: "entryIndex")
        return row
    }

    // MARK: - T5

    @Test("Aralık: pas günü yok, gün içinde zaman sırası, id'siz satır da gelir")
    func rangeQuery() throws {
        insertV3("2026-05-10", hour: 20, note: "akşam", entryIndex: 1)
        insertV3("2026-05-10", hour: 8, note: "sabah")
        insertV3("2026-05-11", hex: "#9E9E9E", passed: true)
        insertV3("2026-05-12", note: "id yok", id: nil)
        insertV3("2026-06-01", note: "aralık dışı")
        try container.viewContext.save()

        let store = LegacyMomentStore(context: container.viewContext, calendar: calendar("Europe/Istanbul"))
        let days = try store.days(from: DayKey("2026-05-01")!, through: DayKey("2026-05-31")!)
        #expect(days.map(\.day.string) == ["2026-05-10", "2026-05-12"])
        #expect(days[0].moments.map(\.moment.note) == ["sabah", "akşam"])
        #expect(days[1].moments.count == 1)
        #expect(try store.count() == 4)
    }

    @Test("Batıda okunan TR kaydı kendi gününde kalır")
    func legacyDayKeyAcrossTimeZones() throws {
        insertV3("2026-05-10", tz: "Europe/Istanbul")
        try container.viewContext.save()
        let london = LegacyMomentStore(context: container.viewContext, calendar: calendar("Europe/London"))
        let days = try london.days(from: DayKey("2026-05-10")!, through: DayKey("2026-05-10")!)
        #expect(days.map(\.day.string) == ["2026-05-10"])
    }

    // MARK: - T9

    @Test("Liste fotoğrafı yüklemez; fotoğraf tek tek okunur")
    func photosAreLazy() throws {
        let photo = Data(repeating: 7, count: 50_000)
        insertV3("2026-05-10", hour: 8, photo: photo)
        insertV3("2026-05-10", hour: 9)
        try container.viewContext.save()
        container.viewContext.reset()

        let store = LegacyMomentStore(context: container.viewContext, calendar: calendar("Europe/Istanbul"))
        let moments = try #require(try store.days(from: DayKey("2026-05-10")!, through: DayKey("2026-05-10")!).first).moments
        #expect(moments.map(\.hasPhoto) == [true, false])
        #expect(moments.allSatisfy { $0.moment.photoData == nil })
        #expect(container.viewContext.registeredObjects.isEmpty) // hiçbir satır nesneye dönmedi
        #expect(store.photo(for: moments[0]) == photo)
    }

    // MARK: - T8

    @Test("Emniyet ağı DailySong insert ve update'ini yakalar, silmeye izin verir")
    func writeGuard() throws {
        let row = insertV3("2026-05-10")
        try container.viewContext.save() // guard kurulmadan önce: v3 verisi hazırlanıyor

        let violations = ViolationLog()
        let guardian = LegacyWriteGuard(coordinator: container.persistentStoreCoordinator,
                                        onViolation: { violations.append($0) })

        insertV3("2026-05-11")
        try container.viewContext.save()
        #expect(violations.messages.count == 1)
        #expect(violations.messages.first?.contains("insert") == true)

        row.setValue("değişti", forKey: "dailyNote")
        try container.viewContext.save()
        #expect(violations.messages.last?.contains("update") == true)

        let before = violations.messages.count
        container.viewContext.delete(row)
        try container.viewContext.save()
        #expect(violations.messages.count == before)

        // ONE2 yazımları serbest.
        try JournalStore(context: container.viewContext, clock: TestClock("2026-09-23T10:00:00Z"))
            .create(EntryDraft(kind: .freeform))
        #expect(violations.messages.count == before)

        // Başka koordinatörün kayıtlarına karışmaz.
        let other = ONE2TestStack.makeContainer()
        NSEntityDescription.insertNewObject(forEntityName: "DailySong", into: other.viewContext)
            .setValue(Date(), forKey: "date")
        try other.viewContext.save()
        #expect(violations.messages.count == before)
        withExtendedLifetime(guardian) {}
    }
}

private nonisolated final class ViolationLog: @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [String] = []
    var messages: [String] { lock.withLock { storage } }
    func append(_ message: String) { lock.withLock { storage.append(message) } }
}
