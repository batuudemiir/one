//
//  DayStore.swift
//  ONE 2.0
//
//  Günün tamamlanma durumu (DayRecord) ve seri.
//
//  CloudKit unique constraint desteklemediği için "gün başına bir kayıt"
//  kodla sağlanır: iki cihaz aynı günü çevrimdışı tamamlarsa senkron sonrası
//  iki satır olur. `reconcileDuplicates()` bunları deterministik birleştirir
//  (02_veri_modeli.md, ilke 4): her tamamlanma alanında en erken zaman
//  kazanır, sağ kalan satır en küçük `id`'li olandır. Her cihaz aynı veriden
//  aynı sonucu üretir; düzeltmeler birbirini kovalamaz.
//

import CoreData

/// Tamamlanabilen günlük kart.
nonisolated enum RitualCard: String, Sendable, CaseIterable {
    case daily, morning, evening
}

final class DayStore {
    private let context: NSManagedObjectContext
    private let clock: AppClock

    init(context: NSManagedObjectContext, clock: AppClock = SystemClock()) {
        self.context = context
        self.clock = clock
    }

    /// Kartı tamamlandı işaretler. Zaten işaretliyse ilk zaman korunur.
    /// Geçmiş bir gün için çağrılırsa gün geriye dönük tamamlanmış sayılır.
    @discardableResult
    func markCompleted(_ card: RitualCard, on day: DayKey? = nil) throws -> DayCompletion {
        let today = clock.today
        let target = day ?? today
        guard target <= today else { throw StoreError.invalidValue("future day") }
        guard target == today || DayCompletionRules.canBackfill(target, today: today) else {
            throw StoreError.invalidValue("backfill window")
        }

        let record = try recordForWriting(target)
        let now = clock.now
        switch card {
        case .daily:   if record.dailyCompletedAt == nil { record.dailyCompletedAt = now }
        case .morning: if record.morningCompletedAt == nil { record.morningCompletedAt = now }
        case .evening: if record.eveningCompletedAt == nil { record.eveningCompletedAt = now }
        }
        if target < today, record.backfilledAt == nil { record.backfilledAt = now }
        if record.completedBy == nil { record.completedBy = DayCompletionSource.ritual.rawValue }
        try context.saveIfNeeded()
        guard let completion = record.completion else { throw StoreError.invalidValue("mapping") }
        return completion
    }

    /// E8 alternatif tamamlama: o günün ≥ 20 kelimelik yazılı girdisi günü
    /// tamamlar. Girdi kaydedildikten sonra çağrılır; eşik altındaysa bir şey
    /// yapmaz. Geriye dönük girdi 7 günlük pencere içindeyse günü onarır.
    @discardableResult
    func recordWriting(_ entry: JournalEntry) throws -> Bool {
        guard DayCompletionRules.countsAsWriting(entry.kind, words: entry.wordCount) else { return false }
        let today = clock.today
        guard entry.day == today || DayCompletionRules.canBackfill(entry.day, today: today) else { return false }
        let record = try recordForWriting(entry.day)
        guard record.completedBy == nil else { return false }
        record.completedBy = DayCompletionSource.writing.rawValue
        if entry.day < today, record.backfilledAt == nil { record.backfilledAt = clock.now }
        try context.saveIfNeeded()
        return true
    }

    /// Seri durumu (sayı, risk, görünürlük, en uzun).
    func streakState(mode: RitualMode, visible: Bool = true) throws -> StreakState {
        let rows: [DayRecordMO] = try context.fetchAll(ONE2Entity.day)
        return Streak.state(Self.merged(rows.compactMap(\.completion)), mode: mode, today: clock.today, visible: visible)
    }

    func allCompletions() throws -> [DayCompletion] {
        let rows: [DayRecordMO] = try context.fetchAll(ONE2Entity.day)
        return Self.merged(rows.compactMap(\.completion))
    }

    /// Sabah seçilen odak.
    func setFocus(_ text: String?, on day: DayKey? = nil) throws {
        let record = try recordForWriting(day ?? clock.today)
        record.focusText = text
        try context.saveIfNeeded()
    }

    func focus(on day: DayKey) throws -> String? {
        try records(for: day).first?.focusText
    }

    func completion(on day: DayKey) throws -> DayCompletion? {
        try records(for: day).first?.completion
    }

    func completions(from start: DayKey, through end: DayKey) throws -> [DayCompletion] {
        let rows: [DayRecordMO] = try context.fetchAll(
            ONE2Entity.day,
            where: NSPredicate(format: "dayKey >= %@ AND dayKey <= %@", start.string, end.string),
            sortedBy: [NSSortDescriptor(key: "dayKey", ascending: true)]
        )
        return Self.merged(rows.compactMap(\.completion))
    }

    /// Güncel seri. v3 günleri (DailySong) bu hesaba girmez.
    func currentStreak(mode: RitualMode) throws -> Int {
        let rows: [DayRecordMO] = try context.fetchAll(ONE2Entity.day)
        return Streak.current(Self.merged(rows.compactMap(\.completion)), mode: mode, today: clock.today)
    }

    func longestStreak(mode: RitualMode) throws -> Int {
        let rows: [DayRecordMO] = try context.fetchAll(ONE2Entity.day)
        return Streak.longest(completed: Streak.completedDays(Self.merged(rows.compactMap(\.completion)), mode: mode))
    }

    /// Aynı `dayKey`'li satırları birleştirir; silinen satır sayısını döner.
    /// Remote change sonrası çağrılır (ADR-001 §1).
    @discardableResult
    func reconcileDuplicates() throws -> Int {
        let rows: [DayRecordMO] = try context.fetchAll(ONE2Entity.day)
        var removed = 0
        for group in Dictionary(grouping: rows, by: { $0.dayKey ?? "" }).values where group.count > 1 {
            let sorted = group.sorted { ($0.id?.uuidString ?? "") < ($1.id?.uuidString ?? "") }
            let survivor = sorted[0]
            for other in sorted.dropFirst() {
                survivor.dailyCompletedAt = Self.earliest(survivor.dailyCompletedAt, other.dailyCompletedAt)
                survivor.morningCompletedAt = Self.earliest(survivor.morningCompletedAt, other.morningCompletedAt)
                survivor.eveningCompletedAt = Self.earliest(survivor.eveningCompletedAt, other.eveningCompletedAt)
                survivor.backfilledAt = Self.earliest(survivor.backfilledAt, other.backfilledAt)
                if survivor.focusText == nil { survivor.focusText = other.focusText }
                if survivor.timeZoneID == nil { survivor.timeZoneID = other.timeZoneID }
                survivor.completedBy = Self.mergedSource(survivor.completedBy, other.completedBy)
                context.delete(other)
                removed += 1
            }
        }
        try context.saveIfNeeded()
        return removed
    }

    // MARK: - Private

    private func records(for day: DayKey) throws -> [DayRecordMO] {
        try context.fetchAll(
            ONE2Entity.day,
            where: NSPredicate(format: "dayKey == %@", day.string),
            sortedBy: [NSSortDescriptor(key: "id", ascending: true)]
        )
    }

    /// Günün kaydı; yoksa oluşturur. Çift varsa önce birleştirir.
    private func recordForWriting(_ day: DayKey) throws -> DayRecordMO {
        let existing = try records(for: day)
        if existing.count > 1 { try reconcileDuplicates() }
        if let record = try records(for: day).first { return record }
        let record: DayRecordMO = context.insert(ONE2Entity.day)
        record.id = UUID()
        record.dayKey = day.string
        record.timeZoneID = clock.timeZoneID
        return record
    }

    /// Henüz uzlaştırılmamış çift satırları okuma sırasında birleştirir.
    private static func merged(_ completions: [DayCompletion]) -> [DayCompletion] {
        Dictionary(grouping: completions, by: \.day).map { day, group in
            group.dropFirst().reduce(group[0]) { acc, next in
                DayCompletion(day: day,
                              dailyCompletedAt: earliest(acc.dailyCompletedAt, next.dailyCompletedAt),
                              morningCompletedAt: earliest(acc.morningCompletedAt, next.morningCompletedAt),
                              eveningCompletedAt: earliest(acc.eveningCompletedAt, next.eveningCompletedAt),
                              completedBy: mergedSource(acc.completedBy?.rawValue, next.completedBy?.rawValue)
                                  .flatMap(DayCompletionSource.init(rawValue:)))
            }
        }.sorted { $0.day < $1.day }
    }

    /// Ritüel yazıya üstün: iki cihazdan biri ritüelle tamamladıysa o kalır.
    private static func mergedSource(_ a: String?, _ b: String?) -> String? {
        if a == DayCompletionSource.ritual.rawValue || b == DayCompletionSource.ritual.rawValue {
            return DayCompletionSource.ritual.rawValue
        }
        return a ?? b
    }

    private static func earliest(_ a: Date?, _ b: Date?) -> Date? {
        switch (a, b) {
        case let (a?, b?): return min(a, b)
        default: return a ?? b
        }
    }
}
