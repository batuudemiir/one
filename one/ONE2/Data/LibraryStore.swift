//
//  LibraryStore.swift
//  ONE 2.0
//
//  Kullanıcının kitaplığı: etiketler, kazanılan rozetler, favori pratikler.
//  Şablonlar ve alışkanlık metrikleri (premium) ekran spesifikasyonuyla
//  birlikte eklenecek.
//

import CoreData

final class LibraryStore {
    private let context: NSManagedObjectContext
    private let clock: AppClock
    /// Etiket adı karşılaştırması için: Türkçede "İ" ↔ "i", İngilizcede "I" ↔ "i".
    private let locale: Locale

    init(context: NSManagedObjectContext, clock: AppClock = SystemClock(), locale: Locale = .autoupdatingCurrent) {
        self.context = context
        self.clock = clock
        self.locale = locale
    }

    // MARK: - Etiketler

    /// Aynı adlı (kullanıcının yerel ayarına göre büyük/küçük harf ve
    /// baştaki/sondaki boşluk farksız) etiket varsa onu döner.
    @discardableResult
    func createTag(name: String, iconName: String? = nil) throws -> JournalTag {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw StoreError.invalidValue("empty tag") }
        if let existing = try tags().first(where: { $0.name.compare(trimmed, options: .caseInsensitive, range: nil, locale: locale) == .orderedSame }) {
            return existing
        }
        let row: TagMO = context.insert(ONE2Entity.tag)
        row.id = UUID()
        row.name = trimmed
        row.iconName = iconName
        row.createdAt = clock.now
        try context.saveIfNeeded()
        guard let value = row.value else { throw StoreError.invalidValue("mapping") }
        return value
    }

    func tags() throws -> [JournalTag] {
        let rows: [TagMO] = try context.fetchAll(ONE2Entity.tag,
                                                 sortedBy: [NSSortDescriptor(key: "name", ascending: true)])
        return rows.compactMap(\.value)
    }

    func renameTag(_ id: UUID, to name: String) throws {
        guard let row: TagMO = try context.fetchOne(ONE2Entity.tag, id: id) else { throw StoreError.notFound }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw StoreError.invalidValue("empty tag") }
        row.name = trimmed
        // Etiket adı girdilerin arama metninde (E11).
        for entry in (row.entries as? Set<EntryMO>) ?? [] { entry.refreshSearchText() }
        try context.saveIfNeeded()
    }

    /// Etiket silinir, girdiler kalır (nullify).
    func deleteTag(_ id: UUID) throws {
        guard let row: TagMO = try context.fetchOne(ONE2Entity.tag, id: id) else { return }
        context.delete(row)
        try context.saveIfNeeded()
    }

    // MARK: - Rozetler

    /// Rozeti bir kez verir; zaten kazanılmışsa ilk kaydı döner.
    @discardableResult
    func award(_ badgeID: String) throws -> EarnedBadge {
        if let existing = try badges().first(where: { $0.badgeID == badgeID }) { return existing }
        let row: BadgeAwardMO = context.insert(ONE2Entity.badge)
        row.id = UUID()
        row.badgeID = badgeID
        row.earnedAt = clock.now
        try context.saveIfNeeded()
        guard let value = row.value else { throw StoreError.invalidValue("mapping") }
        return value
    }

    /// Kazanılan rozetler; aynı rozetin senkron çiftleri tek (en erken) görünür.
    func badges() throws -> [EarnedBadge] {
        let rows: [BadgeAwardMO] = try context.fetchAll(ONE2Entity.badge,
                                                        sortedBy: [NSSortDescriptor(key: "earnedAt", ascending: true)])
        var seen = Set<String>()
        return rows.compactMap(\.value).filter { seen.insert($0.badgeID).inserted }
    }

    /// Aynı `badgeID`'li senkron çiftlerinden en erkeni kalır.
    @discardableResult
    func reconcileDuplicateBadges() throws -> Int {
        let rows: [BadgeAwardMO] = try context.fetchAll(ONE2Entity.badge)
        var removed = 0
        for group in Dictionary(grouping: rows, by: { $0.badgeID ?? "" }).values where group.count > 1 {
            let sorted = group.sorted {
                (($0.earnedAt ?? .distantFuture), $0.id?.uuidString ?? "") < (($1.earnedAt ?? .distantFuture), $1.id?.uuidString ?? "")
            }
            for extra in sorted.dropFirst() { context.delete(extra); removed += 1 }
        }
        try context.saveIfNeeded()
        return removed
    }

    // MARK: - Pratikler

    @discardableResult
    func addPractice(_ contentRef: String) throws -> PracticeItem {
        let current = try practices()
        if let existing = current.first(where: { $0.contentRef == contentRef }) { return existing }
        let row: PracticeMO = context.insert(ONE2Entity.practice)
        row.id = UUID()
        row.contentRef = contentRef
        row.order = Int16(clamping: (current.map(\.order).max() ?? -1) + 1)
        row.addedAt = clock.now
        try context.saveIfNeeded()
        guard let value = row.value else { throw StoreError.invalidValue("mapping") }
        return value
    }

    func removePractice(_ contentRef: String) throws {
        let rows: [PracticeMO] = try context.fetchAll(ONE2Entity.practice,
                                                      where: NSPredicate(format: "contentRef == %@", contentRef))
        rows.forEach(context.delete)
        try context.saveIfNeeded()
    }

    func practices() throws -> [PracticeItem] {
        let rows: [PracticeMO] = try context.fetchAll(ONE2Entity.practice,
                                                      sortedBy: [NSSortDescriptor(key: "order", ascending: true),
                                                                 NSSortDescriptor(key: "addedAt", ascending: true)])
        return rows.compactMap(\.value)
    }
}
