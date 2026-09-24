//
//  LegacyMomentStore.swift
//  ONE 2.0
//
//  v3 verisinin (DailySong) salt okunur okuyucusu — taşıma kararı B'
//  (MIGRATION.md §1.1). Yolculuk'taki "ONE 1" kartları buradan gelir.
//
//  - Hiçbir şey yazmaz. Yazma girişimini `LegacyWriteGuard` yakalar.
//  - Pas günleri (`passed = YES`) gösterilmez (R10).
//  - Fotoğraf listede yüklenmez: sorgu sözlük sonucu döner ve `photoData`
//    alınmaz; yalnız "fotoğraf var" bilgisi ayrı bir hafif sorguyla gelir.
//    Fotoğrafın kendisi `photo(for:)` ile tek tek okunur (R11).
//  - Gün, v3'ün gece yarısına normalize ettiği `date`'ten en yakın gece
//    yarısına yuvarlanarak türetilir (`DayKey(normalizedMidnight:)`, R4).
//  - Seri, istatistik ve rozet hesaplarına hiç verilmez.
//

import CoreData

/// Tek bir v3 anı. `moment.photoData` her zaman nil; fotoğraf `photo(for:)` ile.
struct LegacyMoment: Identifiable, Hashable {
    let moment: Moment
    let day: DayKey
    let hasPhoto: Bool
    let objectID: NSManagedObjectID

    var id: UUID { moment.id }
}

struct LegacyDay: Identifiable, Hashable {
    let day: DayKey
    /// Zaman sırasıyla.
    let moments: [LegacyMoment]

    var id: DayKey { day }
}

final class LegacyMomentStore {
    static let entityName = "DailySong"

    private let context: NSManagedObjectContext
    private let calendar: Calendar

    init(context: NSManagedObjectContext, calendar: Calendar = .autoupdatingCurrent) {
        self.context = context
        self.calendar = calendar
    }

    /// Aralıktaki v3 günleri, eski günden yeniye. Boş günler dönmez.
    func days(from start: DayKey, through end: DayKey) throws -> [LegacyDay] {
        // `date` yazan cihazın saat diliminde gece yarısı; sınırda kaymayı
        // kaçırmamak için sorgu bir gün geniş tutulur, gün sonra süzülür.
        guard let lower = start.adding(days: -1).startDate(in: calendar),
              let upper = end.adding(days: 2).startDate(in: calendar) else { return [] }
        let range = NSPredicate(format: "date >= %@ AND date < %@ AND (passed == nil OR passed == NO)",
                                lower as NSDate, upper as NSDate)

        let withPhoto = try objectIDs(matching: NSCompoundPredicate(andPredicateWithSubpredicates: [
            range, NSPredicate(format: "photoData != nil OR photoURL != nil")
        ]))

        let request = NSFetchRequest<NSDictionary>(entityName: Self.entityName)
        request.resultType = .dictionaryResultType
        request.predicate = range
        request.propertiesToFetch = try listProperties() + [Self.objectIDExpression]
        request.sortDescriptors = [NSSortDescriptor(key: "date", ascending: true),
                                   NSSortDescriptor(key: "createdAt", ascending: true),
                                   NSSortDescriptor(key: "entryIndex", ascending: true)]

        let moments: [LegacyMoment] = try context.fetch(request).compactMap { row in
            guard let objectID = row["objectID"] as? NSManagedObjectID,
                  let date = row["date"] as? Date,
                  let moment = Moment(from: row) else { return nil }
            let day = DayKey(normalizedMidnight: date, calendar: calendar)
            guard day >= start, day <= end else { return nil }
            return LegacyMoment(moment: moment, day: day,
                                hasPhoto: withPhoto.contains(objectID), objectID: objectID)
        }

        return Dictionary(grouping: moments, by: \.day)
            .map { LegacyDay(day: $0.key, moments: $0.value.sorted { $0.moment.time < $1.moment.time }) }
            .sorted { $0.day < $1.day }
    }

    /// Tek anın fotoğrafı (harici depolamadan okunur).
    func photo(for moment: LegacyMoment) -> Data? {
        guard let object = try? context.existingObject(with: moment.objectID) else { return nil }
        return object.value(forKey: "photoData") as? Data
    }

    /// Pas günleri hariç v3 anı sayısı ("ONE 1 arşivi" bilgisi için).
    func count() throws -> Int {
        let request = NSFetchRequest<NSManagedObject>(entityName: Self.entityName)
        request.predicate = NSPredicate(format: "passed == nil OR passed == NO")
        return try context.count(for: request)
    }

    // MARK: - Private

    private static var objectIDExpression: NSExpressionDescription {
        let description = NSExpressionDescription()
        description.name = "objectID"
        description.expression = NSExpression.expressionForEvaluatedObject()
        description.expressionResultType = .objectIDAttributeType
        return description
    }

    /// `photoData` dışındaki tüm alanlar.
    private func listProperties() throws -> [Any] {
        guard let entity = context.persistentStoreCoordinator?.managedObjectModel
                .entitiesByName[Self.entityName] else { throw StoreError.notFound }
        return entity.attributesByName.keys.filter { $0 != "photoData" }.sorted()
    }

    private func objectIDs(matching predicate: NSPredicate) throws -> Set<NSManagedObjectID> {
        let request = NSFetchRequest<NSManagedObjectID>(entityName: Self.entityName)
        request.resultType = .managedObjectIDResultType
        request.predicate = predicate
        return Set(try context.fetch(request))
    }
}
