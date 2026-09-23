//
//  MoodStore.swift
//  ONE 2.0
//
//  Mood check-in'leri (MoodLog). Günde birden çok olabilir.
//

import CoreData

final class MoodStore {
    private let context: NSManagedObjectContext
    private let clock: AppClock

    init(context: NSManagedObjectContext, clock: AppClock = SystemClock()) {
        self.context = context
        self.clock = clock
    }

    /// Yeni check-in. `entryID` verilirse girdiye bağlanır (check-in türü girdiler).
    @discardableResult
    func log(score: Int,
             emotionIDs: [String] = [],
             causeIDs: [String] = [],
             note: String? = nil,
             source: MoodSource,
             on day: DayKey? = nil,
             linkedTo entryID: UUID? = nil) throws -> MoodCheckIn {
        guard (1...5).contains(score) else { throw StoreError.invalidValue("score \(score)") }
        let today = clock.today
        let target = day ?? today
        guard target <= today else { throw StoreError.invalidValue("future day") }

        let row: MoodLogMO = context.insert(ONE2Entity.mood)
        row.id = UUID()
        row.dayKey = target.string
        row.timeZoneID = clock.timeZoneID
        row.timestamp = clock.now
        row.score = Int16(score)
        row.emotionIDsJSON = JSONList.encode(emotionIDs)
        row.causeIDsJSON = JSONList.encode(causeIDs)
        row.note = note
        row.source = source.rawValue
        if let entryID {
            guard let entry: EntryMO = try context.fetchOne(ONE2Entity.entry, id: entryID) else {
                context.delete(row)
                throw StoreError.notFound
            }
            row.entry = entry
        }
        try context.saveIfNeeded()
        guard let value = row.value else { throw StoreError.invalidValue("mapping") }
        return value
    }

    /// HealthKit'e yazıldıktan sonra örnek kimliği saklanır.
    func setHealthKitSampleID(_ sampleID: String, for id: UUID) throws {
        guard let row: MoodLogMO = try context.fetchOne(ONE2Entity.mood, id: id) else { throw StoreError.notFound }
        row.healthKitSampleID = sampleID
        try context.saveIfNeeded()
    }

    func delete(_ id: UUID) throws {
        guard let row: MoodLogMO = try context.fetchOne(ONE2Entity.mood, id: id) else { return }
        context.delete(row)
        try context.saveIfNeeded()
    }

    func logs(on day: DayKey) throws -> [MoodCheckIn] {
        try logs(from: day, through: day)
    }

    /// Aralıktaki check-in'ler, zaman sırasıyla.
    func logs(from start: DayKey, through end: DayKey) throws -> [MoodCheckIn] {
        let rows: [MoodLogMO] = try context.fetchAll(
            ONE2Entity.mood,
            where: NSPredicate(format: "dayKey >= %@ AND dayKey <= %@", start.string, end.string),
            sortedBy: [NSSortDescriptor(key: "timestamp", ascending: true)]
        )
        return rows.compactMap(\.value)
    }
}
