//
//  JournalStore.swift
//  ONE 2.0
//
//  Günlük girdileri (Entry + EntryAnswer). Gün anahtarı ve zaman damgaları
//  burada verilir; çağıran yalnız içeriği söyler.
//

import CoreData

final class JournalStore {
    private let context: NSManagedObjectContext
    private let clock: AppClock
    /// Her kayıttan sonra (E8 yazıyla tamamlama, E9 rozet değerlendirmesi).
    var didSave: ((JournalEntry) -> Void)?

    init(context: NSManagedObjectContext, clock: AppClock = SystemClock()) {
        self.context = context
        self.clock = clock
    }

    /// Yeni girdi. `day` verilirse ve bugün değilse geriye dönük girdi olur:
    /// `dayKey` o güne, `createdAt` şimdiye (02_veri_modeli.md, ilke 1).
    @discardableResult
    func create(_ draft: EntryDraft, on day: DayKey? = nil) throws -> JournalEntry {
        let today = clock.today
        let target = day ?? today
        guard target <= today else { throw StoreError.invalidValue("future day") }
        guard target == today || DayCompletionRules.canBackfill(target, today: today) else {
            throw StoreError.invalidValue("backfill window")
        }

        let now = clock.now
        let entry: EntryMO = context.insert(ONE2Entity.entry)
        entry.id = UUID()
        entry.dayKey = target.string
        entry.timeZoneID = clock.timeZoneID
        entry.createdAt = now
        entry.updatedAt = now
        entry.kind = draft.kind.rawValue
        entry.isBackfilled = target < today
        apply(draft, to: entry)
        entry.refreshSearchText()
        try context.saveIfNeeded()
        let value = try require(entry.value)
        didSave?(value)
        return value
    }

    /// Metin ve etiketleri günceller; cevaplar verilirse tümüyle değiştirir.
    @discardableResult
    func update(_ id: UUID, title: String?, body: String?,
                tagIDs: Set<UUID>? = nil, answers: [EntryAnswer]? = nil) throws -> JournalEntry {
        guard let entry: EntryMO = try context.fetchOne(ONE2Entity.entry, id: id) else { throw StoreError.notFound }
        entry.title = title
        entry.body = body
        entry.wordCount = Int32(clamping: WordCounter.count(body))
        if let tagIDs { try setTags(tagIDs, on: entry) }
        if let answers { replaceAnswers(answers, on: entry) }
        entry.updatedAt = clock.now
        entry.refreshSearchText()
        try context.saveIfNeeded()
        let value = try require(entry.value)
        didSave?(value)
        return value
    }

    func delete(_ id: UUID) throws {
        guard let entry: EntryMO = try context.fetchOne(ONE2Entity.entry, id: id) else { return }
        context.delete(entry)
        try context.saveIfNeeded()
    }

    func entry(_ id: UUID) throws -> JournalEntry? {
        try (context.fetchOne(ONE2Entity.entry, id: id) as EntryMO?)?.value
    }

    func entries(on day: DayKey) throws -> [JournalEntry] {
        try entries(from: day, through: day)
    }

    /// Aralıktaki girdiler, en yeni gün önce; gün içinde oluşturulma sırasıyla.
    func entries(from start: DayKey, through end: DayKey) throws -> [JournalEntry] {
        let rows: [EntryMO] = try context.fetchAll(
            ONE2Entity.entry,
            where: NSPredicate(format: "dayKey >= %@ AND dayKey <= %@", start.string, end.string),
            sortedBy: [NSSortDescriptor(key: "dayKey", ascending: false),
                       NSSortDescriptor(key: "createdAt", ascending: true)]
        )
        return rows.compactMap(\.value)
    }

    /// Türe ve içerik referansına göre girdiler, eskiden yeniye (E4 soru
    /// geçmişi, karşılaştırma, rozetler).
    func entries(kind: EntryKind? = nil, contentRef: String? = nil) throws -> [JournalEntry] {
        var predicates: [NSPredicate] = []
        if let kind { predicates.append(NSPredicate(format: "kind == %@", kind.rawValue)) }
        if let contentRef { predicates.append(NSPredicate(format: "contentRef == %@", contentRef)) }
        let rows: [EntryMO] = try context.fetchAll(
            ONE2Entity.entry,
            where: predicates.isEmpty ? nil : NSCompoundPredicate(andPredicateWithSubpredicates: predicates),
            sortedBy: [NSSortDescriptor(key: "createdAt", ascending: true)]
        )
        return rows.compactMap(\.value)
    }

    // MARK: - Private

    private func apply(_ draft: EntryDraft, to entry: EntryMO) {
        entry.title = draft.title
        entry.body = draft.body
        entry.wordCount = Int32(clamping: WordCounter.count(draft.body))
        entry.contentRef = draft.contentRef
        entry.contentSnapshot = draft.contentSnapshot
        entry.sourceContext = draft.sourceContext?.rawValue
        entry.comparedEntryID = draft.comparedEntryID
        replaceAnswers(draft.answers, on: entry)
        try? setTags(draft.tagIDs, on: entry)
    }

    private func replaceAnswers(_ answers: [EntryAnswer], on entry: EntryMO) {
        for old in (entry.answers as? Set<EntryAnswerMO>) ?? [] { context.delete(old) }
        for (index, answer) in answers.enumerated() {
            let row: EntryAnswerMO = context.insert(ONE2Entity.answer)
            var ordered = answer
            if ordered.order == 0 { ordered.order = index }
            row.apply(ordered)
            row.entry = entry
        }
    }

    private func setTags(_ ids: Set<UUID>, on entry: EntryMO) throws {
        let tags: [TagMO] = ids.isEmpty ? [] : try context.fetchAll(
            ONE2Entity.tag, where: NSPredicate(format: "id IN %@", Array(ids))
        )
        entry.tags = NSSet(array: tags)
    }

    private func require<T>(_ value: T?) throws -> T {
        guard let value else { throw StoreError.invalidValue("mapping") }
        return value
    }
}
