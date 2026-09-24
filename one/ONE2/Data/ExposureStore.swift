//
//  ExposureStore.swift
//  ONE 2.0
//
//  Maruz kalma kaydı (04_arka_plan_motorlari.md › E3): kullanıcının gördüğü,
//  beğendiği ve yazdığı her içerik tek entity'de (`ContentExposure`). E2, E4,
//  E6 ve E7 buradan okur; favoriler `liked` ile tutulur.
//
//  - Mantıksal anahtar `contentKind` + `contentID`. CloudKit unique
//    desteklemediği için iki cihaz aynı içeriği görürse iki satır oluşur;
//    `reconcileDuplicates()` bunları `ExposureRecord.merged` kuralıyla
//    birleştirir (en erken ilk görülme, en geç son görülme, sayılar toplanır,
//    `liked` VEYA'lanır). Sağ kalan satır en küçük `id`'li olandır: her cihaz
//    aynı sonuca varır.
//  - Görülme olayları bellekte biriktirilir, 10 olayda bir ya da `flush()`
//    çağrısında (arka plana geçiş) tek kayıtla yazılır. Beğeni ve yazma
//    kullanıcı niyetidir; beklemeden yazılır. Okumalar birikmiş olayları da
//    içerir, yani motorlar yazılmamış görülmeleri de görür.
//

import CoreData

nonisolated enum ContentKind: String, Codable, Sendable, CaseIterable {
    case quote, prompt, echo, guided, theme
}

/// Bir içeriğin kullanıcı geçmişi; motorların gördüğü değer.
nonisolated struct ExposureRecord: Hashable, Sendable {
    let contentID: String
    let kind: ContentKind
    var firstSeenAt: Date?
    var lastSeenAt: Date?
    var seenCount: Int = 0
    var liked: Bool = false
    var likedAt: Date?
    var lastEntryID: UUID?
    var lastWrittenAt: Date?
    var writtenCount: Int = 0
    /// Düşünür yakınlığı olayları (08 §4.5): sayı + son olay zamanı.
    var shareCount: Int = 0
    var lastSharedAt: Date?
    /// ≥ 4 sn bakış.
    var longLookCount: Int = 0
    var lastLongLookAt: Date?
    /// Hızlı geçiş (görülme eşiğinin altında).
    var skipCount: Int = 0
    var lastSkippedAt: Date?

    init(contentID: String, kind: ContentKind, firstSeenAt: Date? = nil, lastSeenAt: Date? = nil,
         seenCount: Int = 0, liked: Bool = false, likedAt: Date? = nil, lastEntryID: UUID? = nil,
         lastWrittenAt: Date? = nil, writtenCount: Int = 0,
         shareCount: Int = 0, lastSharedAt: Date? = nil, longLookCount: Int = 0, lastLongLookAt: Date? = nil,
         skipCount: Int = 0, lastSkippedAt: Date? = nil) {
        self.contentID = contentID; self.kind = kind
        self.firstSeenAt = firstSeenAt; self.lastSeenAt = lastSeenAt; self.seenCount = seenCount
        self.liked = liked; self.likedAt = likedAt
        self.lastEntryID = lastEntryID; self.lastWrittenAt = lastWrittenAt; self.writtenCount = writtenCount
        self.shareCount = shareCount; self.lastSharedAt = lastSharedAt
        self.longLookCount = longLookCount; self.lastLongLookAt = lastLongLookAt
        self.skipCount = skipCount; self.lastSkippedAt = lastSkippedAt
    }

    var wasSeen: Bool { seenCount > 0 || firstSeenAt != nil }
    var wasWritten: Bool { writtenCount > 0 }

    /// Aynı içeriğin iki kaydını birleştirir (CloudKit tekrarı). Değişmeli ve
    /// birleşmeli: sıra sonucu etkilemez.
    static func merged(_ a: ExposureRecord, _ b: ExposureRecord) -> ExposureRecord {
        let written: (Date?, UUID?) = {
            switch (a.lastWrittenAt, b.lastWrittenAt) {
            case let (x?, y?) where x == y:
                return (x, [a.lastEntryID, b.lastEntryID].compactMap { $0 }.min { $0.uuidString < $1.uuidString })
            case let (x?, y?): return x > y ? (x, a.lastEntryID) : (y, b.lastEntryID)
            case (_?, nil): return (a.lastWrittenAt, a.lastEntryID)
            case (nil, _?): return (b.lastWrittenAt, b.lastEntryID)
            case (nil, nil): return (nil, a.lastEntryID ?? b.lastEntryID)
            }
        }()
        return ExposureRecord(
            contentID: a.contentID, kind: a.kind,
            firstSeenAt: earliest(a.firstSeenAt, b.firstSeenAt),
            lastSeenAt: latest(a.lastSeenAt, b.lastSeenAt),
            seenCount: a.seenCount + b.seenCount,
            liked: a.liked || b.liked,
            likedAt: a.liked || b.liked ? earliest(a.liked ? a.likedAt : nil, b.liked ? b.likedAt : nil) : nil,
            lastEntryID: written.1,
            lastWrittenAt: written.0,
            writtenCount: a.writtenCount + b.writtenCount,
            shareCount: a.shareCount + b.shareCount, lastSharedAt: latest(a.lastSharedAt, b.lastSharedAt),
            longLookCount: a.longLookCount + b.longLookCount, lastLongLookAt: latest(a.lastLongLookAt, b.lastLongLookAt),
            skipCount: a.skipCount + b.skipCount, lastSkippedAt: latest(a.lastSkippedAt, b.lastSkippedAt)
        )
    }

    private static func earliest(_ a: Date?, _ b: Date?) -> Date? {
        switch (a, b) { case let (a?, b?): return min(a, b); default: return a ?? b }
    }

    private static func latest(_ a: Date?, _ b: Date?) -> Date? {
        switch (a, b) { case let (a?, b?): return max(a, b); default: return a ?? b }
    }
}

/// Bir türün tüm kayıtları; motorlara verilen anlık görüntü.
nonisolated struct ExposureSnapshot: Sendable {
    let kind: ContentKind
    let records: [String: ExposureRecord]

    init(kind: ContentKind, records: [String: ExposureRecord] = [:]) {
        self.kind = kind
        self.records = records
    }

    subscript(id: String) -> ExposureRecord? { records[id] }

    var seenIDs: Set<String> { Set(records.values.lazy.filter(\.wasSeen).map(\.contentID)) }
    var likedIDs: Set<String> { Set(records.values.lazy.filter(\.liked).map(\.contentID)) }
    var writtenIDs: Set<String> { Set(records.values.lazy.filter(\.wasWritten).map(\.contentID)) }
}

final class ExposureStore {
    /// Bu kadar görülme olayı birikince yazılır.
    static let batchSize = 10

    private let context: NSManagedObjectContext
    private let clock: AppClock
    private var pending: [Key: ExposureRecord] = [:]
    private var pendingEvents = 0

    private struct Key: Hashable { let kind: ContentKind; let id: String }

    init(context: NSManagedObjectContext, clock: AppClock = SystemClock()) {
        self.context = context
        self.clock = clock
    }

    /// Yazılmayı bekleyen olay sayısı (test ve tanı).
    var pendingCount: Int { pendingEvents }

    // MARK: - Yazma

    func recordSeen(_ id: String, kind: ContentKind, at date: Date? = nil) {
        let now = date ?? clock.now
        buffer(ExposureRecord(contentID: id, kind: kind, firstSeenAt: now, lastSeenAt: now, seenCount: 1))
    }

    /// ≥ 4 sn bakış (08 §4.5). Görülmeyi ayrıca kaydetmez.
    func recordLongLook(_ id: String, kind: ContentKind, at date: Date? = nil) {
        let now = date ?? clock.now
        buffer(ExposureRecord(contentID: id, kind: kind, longLookCount: 1, lastLongLookAt: now))
    }

    /// Hızlı geçiş: görülmüş sayılmaz, yakınlığı düşürür.
    func recordSkipped(_ id: String, kind: ContentKind, at date: Date? = nil) {
        let now = date ?? clock.now
        buffer(ExposureRecord(contentID: id, kind: kind, skipCount: 1, lastSkippedAt: now))
    }

    func recordShared(_ id: String, kind: ContentKind, at date: Date? = nil) {
        let now = date ?? clock.now
        buffer(ExposureRecord(contentID: id, kind: kind, shareCount: 1, lastSharedAt: now))
    }

    private func buffer(_ delta: ExposureRecord) {
        let key = Key(kind: delta.kind, id: delta.contentID)
        pending[key] = pending[key].map { ExposureRecord.merged($0, delta) } ?? delta
        pendingEvents += 1
        if pendingEvents >= Self.batchSize { try? flush() }
    }

    /// Beğeni kullanıcı niyeti: bekleyen olaylarla birlikte hemen yazılır.
    func setLiked(_ liked: Bool, id: String, kind: ContentKind) throws {
        try flush()
        let row = try rowForWriting(id: id, kind: kind)
        row.liked = liked
        row.likedAt = liked ? (row.likedAt ?? clock.now) : nil
        try context.saveIfNeeded()
    }

    /// Bu içeriğe yazılan girdi (söze yazı, soru cevabı). Hemen yazılır.
    func recordWritten(_ id: String, kind: ContentKind, entryID: UUID) throws {
        try flush()
        let row = try rowForWriting(id: id, kind: kind)
        row.writtenCount += 1
        row.lastEntryID = entryID
        row.lastWrittenAt = clock.now
        if row.firstSeenAt == nil { row.firstSeenAt = clock.now; row.lastSeenAt = clock.now; row.seenCount += 1 }
        try context.saveIfNeeded()
    }

    /// Birikmiş görülmeleri tek kayıtla yazar. Arka plana geçişte çağrılır;
    /// boşken bir şey yapmaz.
    func flush() throws {
        guard !pending.isEmpty else { return }
        let batch = pending
        pending = [:]
        pendingEvents = 0
        for (key, delta) in batch {
            let row = try rowForWriting(id: key.id, kind: key.kind)
            row.apply(ExposureRecord.merged(row.record ?? ExposureRecord(contentID: key.id, kind: key.kind), delta))
        }
        try context.saveIfNeeded()
    }

    // MARK: - Okuma

    /// Türün tüm kayıtları (kaydedilmiş + bekleyen). Tekrar satırları okumada
    /// birleştirilir; uzlaştırma beklemez.
    func snapshot(_ kind: ContentKind) throws -> ExposureSnapshot {
        var records = try persistedRecords(kind)
        for (key, delta) in pending where key.kind == kind {
            records[key.id] = records[key.id].map { ExposureRecord.merged($0, delta) } ?? delta
        }
        return ExposureSnapshot(kind: kind, records: records)
    }

    func record(_ id: String, kind: ContentKind) throws -> ExposureRecord? {
        try snapshot(kind)[id]
    }

    /// Görülmüş ID'ler: aday sorgusunun sıcak yolu, yalnız iki sütun okur.
    func seenIDs(_ kind: ContentKind) throws -> Set<String> {
        let request = NSFetchRequest<NSDictionary>(entityName: ONE2Entity.exposure)
        request.resultType = .dictionaryResultType
        request.propertiesToFetch = ["contentID"]
        request.predicate = NSPredicate(format: "contentKind == %@ AND seenCount > 0", kind.rawValue)
        var ids = Set(try context.fetch(request).compactMap { $0["contentID"] as? String })
        for (key, delta) in pending where key.kind == kind && delta.wasSeen { ids.insert(key.id) }
        return ids
    }

    // MARK: - Uzlaştırma

    /// Aynı içerik için birden çok satırı birleştirir; silinen satır sayısını
    /// döner. Remote change sonrası çağrılır (ADR-001 §1).
    @discardableResult
    func reconcileDuplicates() throws -> Int {
        let rows: [ContentExposureMO] = try context.fetchAll(ONE2Entity.exposure)
        var removed = 0
        let groups = Dictionary(grouping: rows) { "\($0.contentKind ?? "")|\($0.contentID ?? "")" }
        for group in groups.values where group.count > 1 {
            let sorted = group.sorted { ($0.id?.uuidString ?? "") < ($1.id?.uuidString ?? "") }
            let survivor = sorted[0]
            guard var merged = survivor.record else { continue }
            for other in sorted.dropFirst() {
                if let record = other.record { merged = ExposureRecord.merged(merged, record) }
                context.delete(other)
                removed += 1
            }
            survivor.apply(merged)
        }
        try context.saveIfNeeded()
        return removed
    }

    // MARK: - Private

    private func persistedRecords(_ kind: ContentKind) throws -> [String: ExposureRecord] {
        let rows: [ContentExposureMO] = try context.fetchAll(
            ONE2Entity.exposure, where: NSPredicate(format: "contentKind == %@", kind.rawValue)
        )
        var records: [String: ExposureRecord] = [:]
        for record in rows.compactMap(\.record) {
            records[record.contentID] = records[record.contentID].map { ExposureRecord.merged($0, record) } ?? record
        }
        return records
    }

    private func rowForWriting(id: String, kind: ContentKind) throws -> ContentExposureMO {
        let predicate = NSPredicate(format: "contentKind == %@ AND contentID == %@", kind.rawValue, id)
        let rows: [ContentExposureMO] = try context.fetchAll(
            ONE2Entity.exposure, where: predicate, sortedBy: [NSSortDescriptor(key: "id", ascending: true)]
        )
        if rows.count > 1 { try reconcileDuplicates() }
        if let row = try context.fetchAll(ONE2Entity.exposure, as: ContentExposureMO.self, where: predicate).first {
            return row
        }
        let row: ContentExposureMO = context.insert(ONE2Entity.exposure)
        row.id = UUID()
        row.contentID = id
        row.contentKind = kind.rawValue
        return row
    }
}

extension ContentExposureMO {
    var record: ExposureRecord? {
        guard let contentID, let kind = contentKind.flatMap(ContentKind.init(rawValue:)) else { return nil }
        return ExposureRecord(
            contentID: contentID, kind: kind,
            firstSeenAt: firstSeenAt, lastSeenAt: lastSeenAt, seenCount: Int(seenCount),
            liked: liked, likedAt: likedAt,
            lastEntryID: lastEntryID, lastWrittenAt: lastWrittenAt, writtenCount: Int(writtenCount),
            shareCount: Int(shareCount), lastSharedAt: lastSharedAt,
            longLookCount: Int(longLookCount), lastLongLookAt: lastLongLookAt,
            skipCount: Int(skipCount), lastSkippedAt: lastSkippedAt
        )
    }

    func apply(_ record: ExposureRecord) {
        firstSeenAt = record.firstSeenAt
        lastSeenAt = record.lastSeenAt
        seenCount = Int32(clamping: record.seenCount)
        liked = record.liked
        likedAt = record.likedAt
        lastEntryID = record.lastEntryID
        lastWrittenAt = record.lastWrittenAt
        writtenCount = Int16(clamping: record.writtenCount)
        shareCount = Int16(clamping: record.shareCount)
        lastSharedAt = record.lastSharedAt
        longLookCount = Int16(clamping: record.longLookCount)
        lastLongLookAt = record.lastLongLookAt
        skipCount = Int16(clamping: record.skipCount)
        lastSkippedAt = record.lastSkippedAt
    }
}
