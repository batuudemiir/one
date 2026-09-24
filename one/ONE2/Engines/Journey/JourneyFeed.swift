//
//  JourneyFeed.swift
//  ONE 2.0
//
//  Yolculuk akışı (MIGRATION.md §1.1 "Yolculuk birleştirme", T7): ONE 2.0
//  girdileri, check-in'ler, fotoğraflar ve v3 anıları (`DailySong`, B')
//  `dayKey` üzerinden tek zaman çizelgesinde. Günler yeniden eskiye, gün
//  içinde yeniden eskiye.
//
//  - Yalnız check-in taşıyan ritüel girdisi (metinsiz günlük/duygu kaydı) ayrı
//    kart olmaz; check-in kartı onu temsil eder. Metin ya da cevap taşıyan
//    girdi (sabah/akşam ritüeli dahil) kendi kartıyla görünür.
//  - v3 anıları yalnız gösterilir; seri, istatistik ve rozete girmez.
//  - Sayfalama ay ay: her sayfa iki kaynak sorgusu (ONE 2.0 + DailySong).
//

import Foundation
import CoreData

nonisolated struct JourneyPhoto: Hashable, Sendable {
    let mediaID: UUID
    let entryID: UUID
    let createdAt: Date
}

enum JourneyItem: Identifiable, Hashable {
    case entry(JournalEntry)
    case checkIn(MoodCheckIn)
    case photo(JourneyPhoto)
    /// v3 anı kartı ("ONE 1").
    case legacy(LegacyMoment)

    var id: String {
        switch self {
        case .entry(let e): return "entry:\(e.id)"
        case .checkIn(let m): return "mood:\(m.id)"
        case .photo(let p): return "photo:\(p.mediaID)"
        case .legacy(let l): return "legacy:\(l.id)"
        }
    }

    var time: Date {
        switch self {
        case .entry(let e): return e.createdAt
        case .checkIn(let m): return m.timestamp
        case .photo(let p): return p.createdAt
        case .legacy(let l): return l.moment.time
        }
    }

    var isLegacy: Bool { if case .legacy = self { return true } else { return false } }
}

struct JourneyDay: Identifiable, Hashable {
    let day: DayKey
    /// Yeniden eskiye.
    let items: [JourneyItem]

    var id: DayKey { day }
}

enum JourneyMerge {

    /// Metinsiz ritüel kaydı: check-in kartı onu zaten gösteriyor.
    static func isCheckInOnly(_ e: JournalEntry) -> Bool {
        let ritual: Set<EntryKind> = [.dailyCheckIn, .emotionCheckIn]
        let hasText = !(e.body ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || e.answers.contains { !($0.text ?? "").isEmpty || $0.number != nil || $0.bool != nil || !$0.choices.isEmpty }
        return ritual.contains(e.kind) && e.moodID != nil && !hasText
    }

    static func days(entries: [JournalEntry], moods: [MoodCheckIn], photos: [JourneyPhoto],
                     legacy: [LegacyMoment]) -> [JourneyDay] {
        let entryDays = Dictionary(entries.map { ($0.id, $0.day) }, uniquingKeysWith: { a, _ in a })
        var byDay: [DayKey: [JourneyItem]] = [:]
        for e in entries where !isCheckInOnly(e) { byDay[e.day, default: []].append(.entry(e)) }
        for m in moods where m.score > 0 { byDay[m.day, default: []].append(.checkIn(m)) }
        for p in photos { if let d = entryDays[p.entryID] { byDay[d, default: []].append(.photo(p)) } }
        for l in legacy { byDay[l.day, default: []].append(.legacy(l)) }
        return byDay.map { day, items in
            JourneyDay(day: day, items: items.sorted { ($0.time, $0.id) > ($1.time, $1.id) })
        }.sorted { $0.day > $1.day }
    }
}

final class JourneyFeed {
    private let context: NSManagedObjectContext
    private let journal: JournalStore
    private let mood: MoodStore
    private let legacy: LegacyMomentStore

    init(context: NSManagedObjectContext, journal: JournalStore, mood: MoodStore, legacy: LegacyMomentStore) {
        self.context = context; self.journal = journal; self.mood = mood; self.legacy = legacy
    }

    func days(from start: DayKey, through end: DayKey, includeLegacy: Bool = true) throws -> [JourneyDay] {
        let entries = try journal.entries(from: start, through: end)
        return JourneyMerge.days(
            entries: entries,
            moods: try mood.logs(from: start, through: end),
            photos: try photos(for: Set(entries.map(\.id))),
            legacy: includeLegacy ? try legacy.days(from: start, through: end).flatMap(\.moments) : []
        )
    }

    /// Ay sayfası: `month` ayının tüm günleri.
    func month(containing day: DayKey, includeLegacy: Bool = true) throws -> [JourneyDay] {
        guard let first = DayKey(year: day.year, month: day.month, day: 1) else { return [] }
        let next = day.month == 12 ? DayKey(year: day.year + 1, month: 1, day: 1) : DayKey(year: day.year, month: day.month + 1, day: 1)
        return try days(from: first, through: (next ?? first).adding(days: -1), includeLegacy: includeLegacy)
    }

    private func photos(for entryIDs: Set<UUID>) throws -> [JourneyPhoto] {
        guard !entryIDs.isEmpty else { return [] }
        let rows: [MediaMO] = try context.fetchAll(
            "Media", where: NSPredicate(format: "type == %@ AND entry.id IN %@", "photo", Array(entryIDs)),
            sortedBy: [NSSortDescriptor(key: "order", ascending: true)]
        )
        return rows.compactMap { row in
            guard let id = row.id, let entry = row.entry, let entryID = entry.id else { return nil }
            return JourneyPhoto(mediaID: id, entryID: entryID, createdAt: entry.createdAt ?? .distantPast)
        }
    }
}
