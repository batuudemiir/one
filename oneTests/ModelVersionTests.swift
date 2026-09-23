//
//  ModelVersionTests.swift
//  oneTests
//
//  `one 2` → `one 3` geçişinin güvencesi (MIGRATION.md §3, §4, §7 T1/T3/T4).
//
//  Model değiştiğinde ilk kırılması gereken yer burası: `DailySong`'a
//  dokunulursa (T3), CloudKit kuralı çiğnenirse (T4) ya da v3 store'u yeni
//  modelle açılamazsa (T1) üretimde store açılmaz ve kurtarma yolu devreye
//  girer.
//

import Testing
import Foundation
import CoreData
@testable import OneDailyBatuhan

struct ModelVersionTests {

    private static var momdURL: URL {
        Bundle(for: PersistenceController.self).url(forResource: "one", withExtension: "momd")!
    }

    private static func model(version: String) throws -> NSManagedObjectModel {
        let url = momdURL.appendingPathComponent("\(version).mom")
        return try #require(NSManagedObjectModel(contentsOf: url))
    }

    /// Paketin güncel sürümü (`.xccurrentversion`).
    private static var currentModel: NSManagedObjectModel {
        NSManagedObjectModel(contentsOf: momdURL)!
    }

    private static let newEntities = [
        "Entry", "EntryAnswer", "MoodLog", "DayRecord", "Tag", "Media",
        "Template", "TemplateItem", "MetricDefinition", "BadgeAward", "Practice"
    ]

    // MARK: - T3

    @Test("Güncel sürüm one 3 ve tüm yeni entity'leri içeriyor")
    func currentVersionIsOne3() throws {
        let names = Set(Self.currentModel.entitiesByName.keys)
        #expect(names == Set(Self.newEntities + ["DailySong"]))
    }

    @Test("DailySong şeması one 2 ile birebir aynı (version hash)")
    func dailySongUnchanged() throws {
        let old = try #require(try Self.model(version: "one 2").entitiesByName["DailySong"])
        let new = try #require(Self.currentModel.entitiesByName["DailySong"])
        #expect(old.versionHash == new.versionHash)
        #expect(try Self.model(version: "one").entitiesByName["DailySong"]?.versionHash == old.versionHash)
    }

    // MARK: - T4

    @Test("Model NSPersistentCloudKitContainer kurallarına uyuyor")
    func cloudKitCompliance() {
        var problems: [String] = []
        for entity in Self.currentModel.entities {
            let name = entity.name ?? "?"
            if !entity.uniquenessConstraints.isEmpty {
                problems.append("\(name): unique constraint")
            }
            for (attrName, attr) in entity.attributesByName
            where !attr.isOptional && attr.defaultValue == nil {
                problems.append("\(name).\(attrName): zorunlu ve varsayılansız")
            }
            for (relName, rel) in entity.relationshipsByName {
                if !rel.isOptional { problems.append("\(name).\(relName): zorunlu ilişki") }
                if rel.inverseRelationship == nil { problems.append("\(name).\(relName): ters ilişki yok") }
                if rel.isOrdered { problems.append("\(name).\(relName): ordered") }
                if rel.deleteRule == .denyDeleteRule { problems.append("\(name).\(relName): deny") }
            }
        }
        #expect(problems.isEmpty, "\(problems)")
    }

    @Test("Büyük ikili veri harici depolamada")
    func binaryIsExternal() {
        let media = Self.currentModel.entitiesByName["Media"]!.attributesByName
        #expect(media["data"]?.allowsExternalBinaryDataStorage == true)
        #expect(media["thumbnail"]?.allowsExternalBinaryDataStorage == true)
    }

    // MARK: - T1

    @Test("one 2 ile yazılmış store one 3 ile açılıyor, v3 verisi aynen duruyor")
    func lightweightMigrationKeepsV3Data() throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("ModelVersionTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let storeURL = dir.appendingPathComponent("one.sqlite")

        // 1) v3 store'u `one 2` modeliyle yaz.
        let photo = Data((0..<200_000).map { UInt8($0 % 251) }) // harici depolamaya gider
        let (ids, rowCount) = try writeV3Store(at: storeURL, photo: photo)

        // 2) Güncel modelle (one 3), uygulamayla aynı seçeneklerle aç.
        let container = NSPersistentContainer(name: "one", managedObjectModel: Self.currentModel)
        let description = NSPersistentStoreDescription(url: storeURL)
        description.shouldMigrateStoreAutomatically = true
        description.shouldInferMappingModelAutomatically = true
        description.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
        container.persistentStoreDescriptions = [description]
        var loadError: Error?
        container.loadPersistentStores { _, error in loadError = error }
        #expect(loadError == nil, "\(String(describing: loadError))")

        let context = container.viewContext
        let rows = try context.fetch(NSFetchRequest<NSManagedObject>(entityName: "DailySong"))
        #expect(rows.count == rowCount)
        #expect(Set(rows.compactMap { $0.value(forKey: "id") as? UUID }) == Set(ids))
        let withPhoto = rows.first { $0.value(forKey: "photoData") != nil }
        #expect((withPhoto?.value(forKey: "photoData") as? Data) == photo)
        #expect(rows.filter { ($0.value(forKey: "passed") as? Bool) == true }.count == 1)

        // 3) Yeni entity'ler boş ve yazılabilir.
        for name in Self.newEntities {
            #expect(try context.count(for: NSFetchRequest<NSManagedObject>(entityName: name)) == 0)
        }
        let entry = NSEntityDescription.insertNewObject(forEntityName: "Entry", into: context)
        entry.setValue(UUID(), forKey: "id")
        entry.setValue("2026-09-23", forKey: "dayKey")
        let mood = NSEntityDescription.insertNewObject(forEntityName: "MoodLog", into: context)
        mood.setValue(UUID(), forKey: "id")
        mood.setValue(Int16(4), forKey: "score")
        entry.setValue(mood, forKey: "mood")
        try context.save()
        #expect((mood.value(forKey: "entry") as? NSManagedObject) == entry)
    }

    /// v3'ün yazdığı satır çeşitleri: normal, aynı gün ikinci an, fotoğraflı,
    /// pas günü, `id`'siz eski satır.
    private func writeV3Store(at url: URL, photo: Data) throws -> (ids: [UUID], rowCount: Int) {
        let container = NSPersistentContainer(name: "one", managedObjectModel: try Self.model(version: "one 2"))
        container.persistentStoreDescriptions = [NSPersistentStoreDescription(url: url)]
        var loadError: Error?
        container.loadPersistentStores { _, error in loadError = error }
        if let loadError { throw loadError }

        let context = container.viewContext
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Europe/Istanbul")!
        let day = cal.startOfDay(for: Date(timeIntervalSince1970: 1_778_400_000))
        var ids: [UUID] = []

        func row(_ index: Int16, hex: String, note: String?, photo: Data? = nil, passed: Bool = false, withID: Bool = true) {
            let obj = NSEntityDescription.insertNewObject(forEntityName: "DailySong", into: context)
            if withID {
                let id = UUID(); ids.append(id)
                obj.setValue(id, forKey: "id")
            }
            obj.setValue(day.addingTimeInterval(Double(index) * 86_400), forKey: "date")
            obj.setValue(Date(), forKey: "createdAt")
            obj.setValue(index, forKey: "entryIndex")
            obj.setValue(hex, forKey: "moodColorHex")
            obj.setValue(note, forKey: "dailyNote")
            obj.setValue(photo, forKey: "photoData")
            obj.setValue(passed, forKey: "passed")
        }
        row(0, hex: "#FF3B1F", note: "ilk an")
        row(0, hex: "#00B58C", note: "ikinci an")
        row(1, hex: "#123456", note: nil, photo: photo)
        row(2, hex: "#9E9E9E", note: nil, passed: true)
        row(3, hex: "#FFC300", note: "id yok", withID: false)
        try context.save()

        let coordinator = container.persistentStoreCoordinator
        for store in coordinator.persistentStores { try coordinator.remove(store) }
        return (ids, 5)
    }
}
