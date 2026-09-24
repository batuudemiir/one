//
//  LegacyWriteGuard.swift
//  ONE 2.0
//
//  B' kuralının emniyet ağı (MIGRATION.md §1.3): ONE 2.0 açıkken `DailySong`'a
//  ekleme ya da güncelleme yapılmaz; tek izinli yazma kullanıcının açık
//  silme isteği.
//
//  Koordinatöre bağlı çalışır: yalnız izlenen store'a yapılan kayıtlara bakar.
//  CloudKit aynasının kayıtları (başka cihazdaki v3'ün yazdıkları içeri
//  alınırken) kural dışı değil; onlar sayılmaz.
//  Varsayılan tepki DEBUG'da `assertionFailure`; release'de yalnız log.
//  `ONE2Flag` açıkken kurulur (ADR-001 Faz 1 madde 8).
//

import CoreData
import os

nonisolated final class LegacyWriteGuard: @unchecked Sendable {
    typealias Handler = @Sendable (String) -> Void

    private let observer: NSObjectProtocol

    init(coordinator: NSPersistentStoreCoordinator, onViolation: @escaping Handler = LegacyWriteGuard.defaultHandler) {
        observer = NotificationCenter.default.addObserver(
            forName: .NSManagedObjectContextWillSave, object: nil, queue: nil
        ) { [weak coordinator] note in
            guard let context = note.object as? NSManagedObjectContext,
                  let coordinator, context.persistentStoreCoordinator === coordinator,
                  !Self.isCloudKitMirroring(context) else { return }
            // willSave, context'in kendi kuyruğunda eşzamanlı gönderiliyor.
            for message in Self.violations(in: context) { onViolation(message) }
        }
    }

    deinit {
        NotificationCenter.default.removeObserver(observer)
    }

    /// `NSPersistentCloudKitContainer`'ın içe/dışa aktarma context'leri.
    static func isCloudKitMirroring(_ context: NSManagedObjectContext) -> Bool {
        let prefix = "NSCloudKitMirroringDelegate"
        return context.transactionAuthor?.hasPrefix(prefix) == true || context.name?.hasPrefix(prefix) == true
    }

    static func violations(in context: NSManagedObjectContext) -> [String] {
        let entity = "DailySong"
        let inserted = context.insertedObjects.filter { $0.entity.name == entity }.count
        let updated = context.updatedObjects.filter { $0.entity.name == entity && !$0.changedValues().isEmpty }.count
        var messages: [String] = []
        if inserted > 0 { messages.append("\(entity): \(inserted) insert (B' read-only)") }
        if updated > 0 { messages.append("\(entity): \(updated) update (B' read-only)") }
        return messages
    }

    static let defaultHandler: Handler = { message in
        #if DEBUG
        assertionFailure("LegacyWriteGuard — \(message)")
        #else
        // `ONELogger` ana aktörde; bu kapanış context'in kuyruğunda çalışıyor.
        Logger(subsystem: "com.batu.ones", category: "persistence").error("LegacyWriteGuard — \(message, privacy: .public)")
        #endif
    }
}
