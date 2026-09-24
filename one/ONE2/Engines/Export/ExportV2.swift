//
//  ExportV2.swift
//  ONE 2.0
//
//  Dışa aktarma v2 (04_arka_plan_motorlari.md › E16). Arşivin sahibi
//  kullanıcıdır; `ArchiveExporter` deseni korunur: sabit İngilizce anahtarlar,
//  `en_US_POSIX` tarihler, geçici dizine yazım, paylaşım sayfası kopyalar.
//
//  - JSON (ücretsiz): tüm ONE 2.0 kayıtları + içerik metinleri (söz, soru,
//    duygu/neden adları), ki dosya içerik kataloğu olmadan da okunsun. v3
//    kayıtları `legacyMoments` dizisinde, `ArchiveExporter` alan adlarıyla
//    (MIGRATION.md §1.1, T11).
//  - Markdown arşivi (premium, E15): her gün bir `.md`, fotoğraflar `media/`
//    klasöründe, tek zip. Başka bir günlük uygulamasına taşınabilir. v3
//    kayıtları "ONE 1" bölümünde.
//
//  Kurucular saf (`ExportV2Builder`, `MarkdownArchive`); `DataExporter`
//  depolardan okur ve diske yazar.
//

import Foundation
import CoreData

// MARK: - JSON şeması (v2)

struct ExportV2: Encodable {
    let app = "ONE"
    let schema = 2
    let exportedAt: String
    let contentVersion: Int
    let entries: [Entry]
    let moods: [Mood]
    let days: [Day]
    let tags: [Tag]
    let badges: [Badge]
    let practices: [Practice]
    let favorites: [Favorite]
    let legacyMoments: [ArchiveExporter.ExportedMoment]

    struct Answer: Encodable {
        let order: Int
        let kind: String
        let question: String?
        let text: String?
        let number: Double?
        let bool: Bool?
        let choices: [String]?
    }

    struct Media: Encodable {
        let id: String
        let type: String
        /// Markdown arşivinde `media/` altındaki dosya adı; JSON'da ikili veri yok.
        let file: String?
        let songTitle: String?
        let songArtist: String?
    }

    struct Entry: Encodable {
        let id: String
        let date: String
        let createdAt: String
        let updatedAt: String
        let kind: String
        let title: String?
        let body: String?
        let wordCount: Int
        let contentRef: String?
        /// Soru/söz metni: kayıttaki snapshot ya da katalogdaki metin.
        let contentText: String?
        let source: String?
        let comparedEntryID: String?
        let isBackfilled: Bool
        let tags: [String]
        let moodID: String?
        let answers: [Answer]
        let media: [Media]
    }

    struct Label: Encodable {
        let id: String
        let label: String?
    }

    struct Mood: Encodable {
        let id: String
        let date: String
        let timestamp: String
        let score: Int
        let emotions: [Label]
        let causes: [Label]
        let note: String?
        let source: String
        let entryID: String?
    }

    struct Day: Encodable {
        let date: String
        let dailyCompletedAt: String?
        let morningCompletedAt: String?
        let eveningCompletedAt: String?
        let completedBy: String?
        let focus: String?
    }

    struct Tag: Encodable {
        let id: String
        let name: String
    }

    struct Badge: Encodable {
        let id: String
        let title: String?
        let earnedAt: String
    }

    struct Practice: Encodable {
        let contentRef: String
        let addedAt: String
    }

    struct Favorite: Encodable {
        let quoteID: String
        let text: String?
        let author: String?
        let likedAt: String?
    }
}

/// Bir girdinin medyası (dışa aktarma için ikili veriyle).
nonisolated struct ExportMedia: Sendable {
    let id: UUID
    let entryID: UUID
    let type: String
    let order: Int
    let data: Data?
    let songTitle: String?
    let songArtist: String?

    /// `media/2026-09-23-<id8>.jpg`; ikili veri yoksa `nil`.
    var fileName: String? {
        guard data != nil else { return nil }
        let ext = ["photo": "jpg", "video": "mov", "audio": "m4a", "drawing": "png"][type] ?? "bin"
        return "\(id.uuidString.prefix(8).lowercased()).\(ext)"
    }
}

/// Kurucuya giden ham veri.
struct ExportInput {
    var entries: [JournalEntry] = []
    var moods: [MoodCheckIn] = []
    var days: [DayCompletion] = []
    var focusByDay: [DayKey: String] = [:]
    var tags: [JournalTag] = []
    var badges: [EarnedBadge] = []
    var practices: [PracticeItem] = []
    var favorites: [ExposureRecord] = []
    var media: [ExportMedia] = []
    var legacy: [LegacyMoment] = []
}

enum ExportV2Builder {

    static func build(_ input: ExportInput, catalog: ContentCatalog, now: Date, timeZone: TimeZone = .current) -> ExportV2 {
        let f = Formatters(timeZone: timeZone)
        let tagNames = Dictionary(input.tags.map { ($0.id, $0.name) }, uniquingKeysWith: { a, _ in a })
        let mediaByEntry = Dictionary(grouping: input.media, by: \.entryID)
        let emotionLabels = Dictionary(catalog.emotions.map { ($0.id, $0.label) }, uniquingKeysWith: { a, _ in a })
        let causeLabels = Dictionary(catalog.causes.map { ($0.id, $0.label) }, uniquingKeysWith: { a, _ in a })
        let badgeTitles = Dictionary(catalog.badges.map { ($0.id, $0.title) }, uniquingKeysWith: { a, _ in a })

        let entries = input.entries.sorted { ($0.day, $0.createdAt) < ($1.day, $1.createdAt) }.map { e in
            ExportV2.Entry(
                id: e.id.uuidString, date: e.day.string,
                createdAt: f.full.string(from: e.createdAt), updatedAt: f.full.string(from: e.updatedAt),
                kind: e.kind.rawValue, title: e.title, body: e.body, wordCount: e.wordCount,
                contentRef: e.contentRef, contentText: contentText(e, catalog: catalog),
                source: e.sourceContext?.rawValue, comparedEntryID: e.comparedEntryID?.uuidString,
                isBackfilled: e.isBackfilled,
                tags: e.tagIDs.compactMap { tagNames[$0] }.sorted(),
                moodID: e.moodID?.uuidString,
                answers: e.answers.map {
                    ExportV2.Answer(order: $0.order, kind: $0.kind.rawValue, question: $0.questionSnapshot, text: $0.text,
                                    number: $0.number, bool: $0.bool, choices: $0.choices.isEmpty ? nil : $0.choices)
                },
                media: (mediaByEntry[e.id] ?? []).sorted { $0.order < $1.order }.map {
                    ExportV2.Media(id: $0.id.uuidString, type: $0.type, file: $0.fileName.map { "media/\($0)" },
                                   songTitle: $0.songTitle, songArtist: $0.songArtist)
                }
            )
        }
        let moods = input.moods.sorted { $0.timestamp < $1.timestamp }.map { m in
            ExportV2.Mood(id: m.id.uuidString, date: m.day.string, timestamp: f.full.string(from: m.timestamp),
                          score: m.score,
                          emotions: m.emotionIDs.map { ExportV2.Label(id: $0, label: emotionLabels[$0]) },
                          causes: m.causeIDs.map { ExportV2.Label(id: $0, label: causeLabels[$0]) },
                          note: m.note, source: m.source.rawValue, entryID: m.entryID?.uuidString)
        }
        let days = input.days.sorted { $0.day < $1.day }.map { d in
            ExportV2.Day(date: d.day.string,
                         dailyCompletedAt: d.dailyCompletedAt.map(f.full.string),
                         morningCompletedAt: d.morningCompletedAt.map(f.full.string),
                         eveningCompletedAt: d.eveningCompletedAt.map(f.full.string),
                         completedBy: d.completedBy?.rawValue, focus: input.focusByDay[d.day])
        }
        let favorites = input.favorites.filter(\.liked)
            .sorted { ($0.likedAt ?? .distantPast, $0.contentID) < ($1.likedAt ?? .distantPast, $1.contentID) }
            .map { r in
                ExportV2.Favorite(quoteID: r.contentID, text: catalog.quote(r.contentID)?.text,
                                  author: catalog.quote(r.contentID)?.author, likedAt: r.likedAt.map(f.full.string))
            }
        return ExportV2(
            exportedAt: f.full.string(from: now),
            contentVersion: catalog.contentVersion,
            entries: entries, moods: moods, days: days,
            tags: input.tags.sorted { $0.name < $1.name }.map { ExportV2.Tag(id: $0.id.uuidString, name: $0.name) },
            badges: input.badges.sorted { $0.earnedAt < $1.earnedAt }
                .map { ExportV2.Badge(id: $0.badgeID, title: badgeTitles[$0.badgeID], earnedAt: f.full.string(from: $0.earnedAt)) },
            practices: input.practices.sorted { $0.order < $1.order }
                .map { ExportV2.Practice(contentRef: $0.contentRef, addedAt: f.full.string(from: $0.addedAt)) },
            favorites: favorites,
            legacyMoments: input.legacy.sorted { $0.moment.time < $1.moment.time }.map { legacyMoment($0, f: f) }
        )
    }

    /// Kayıttaki snapshot; yoksa katalogdaki söz/soru metni.
    static func contentText(_ e: JournalEntry, catalog: ContentCatalog) -> String? {
        if let s = e.contentSnapshot, !s.isEmpty { return s }
        guard let ref = e.contentRef else { return nil }
        return catalog.quote(ref)?.text ?? catalog.prompt(ref)?.text
    }

    /// `ArchiveExporter.ExportedMoment` alan adlarıyla v3 anı. Mood etiketi
    /// yalnız hex tam eşleşirse (`V3Mood.closest` ile tahmin edilmez).
    static func legacyMoment(_ l: LegacyMoment, f: Formatters) -> ArchiveExporter.ExportedMoment {
        let m = l.moment
        return ArchiveExporter.ExportedMoment(
            date: l.day.string, createdAt: f.full.string(from: m.time),
            mood: V3Mood.fromHex(m.moodColorHex)?.rawValue,
            moodColor: m.moodColorHex, song: m.songName, artist: m.songArtist,
            note: m.note, hasPhoto: l.hasPhoto, sharedWithCircle: m.scope == .friends
        )
    }

    struct Formatters {
        let full: ISO8601DateFormatter

        init(timeZone: TimeZone) {
            let f = ISO8601DateFormatter()
            f.formatOptions = [.withInternetDateTime]
            f.timeZone = timeZone
            full = f
        }
    }
}

// MARK: - Markdown arşivi

enum MarkdownArchive {

    /// Dosya yolu → metin. Her gün `YYYY-MM-DD.md`; v3 günleri `ONE 1/`.
    static func render(_ export: ExportV2) -> [String: String] {
        var files: [String: String] = [:]
        let entriesByDay = Dictionary(grouping: export.entries, by: \.date)
        let moodsByDay = Dictionary(grouping: export.moods, by: \.date)
        let focusByDay = Dictionary(export.days.compactMap { d in d.focus.map { (d.date, $0) } }, uniquingKeysWith: { a, _ in a })
        for day in Set(entriesByDay.keys).union(moodsByDay.keys).sorted() {
            var md = "# \(day)\n"
            if let focus = focusByDay[day] { md += "\n**\(focusLabel):** \(focus)\n" }
            for m in moodsByDay[day] ?? [] {
                let time = String(m.timestamp.dropFirst(11).prefix(5))
                let emotions = m.emotions.map { $0.label ?? $0.id }.joined(separator: ", ")
                let causes = m.causes.map { $0.label ?? $0.id }.joined(separator: ", ")
                md += "\n- \(time) · \(m.score)/5"
                if !emotions.isEmpty { md += " · \(emotions)" }
                if !causes.isEmpty { md += " · \(causes)" }
                if let note = m.note, !note.isEmpty { md += "\n  \(note)" }
                md += "\n"
            }
            for e in entriesByDay[day] ?? [] {
                md += "\n## \(e.title ?? heading(for: e.kind))\n"
                if let text = e.contentText { md += "\n> \(text.replacingOccurrences(of: "\n", with: "\n> "))\n" }
                for a in e.answers {
                    if let q = a.question { md += "\n**\(q)**\n" }
                    let value = a.text ?? a.number.map { String(format: "%g", $0) } ?? a.bool.map { $0 ? "✓" : "—" }
                        ?? a.choices?.joined(separator: ", ")
                    if let value { md += "\n\(value)\n" }
                }
                if let body = e.body, !body.isEmpty { md += "\n\(body)\n" }
                for media in e.media {
                    if let file = media.file { md += "\n![](\(file))\n" }
                    if let song = media.songTitle { md += "\n♪ \(song)\(media.songArtist.map { " — \($0)" } ?? "")\n" }
                }
                if !e.tags.isEmpty { md += "\n" + e.tags.map { "#\($0.replacingOccurrences(of: " ", with: "_"))" }.joined(separator: " ") + "\n" }
            }
            files["\(day).md"] = md
        }
        for (day, moments) in Dictionary(grouping: export.legacyMoments, by: \.date) {
            var md = "# \(day) · ONE 1\n"
            for m in moments {
                md += "\n- \(m.createdAt.map { String($0.dropFirst(11).prefix(5)) } ?? "")"
                if let mood = m.mood { md += " · \(mood)" }
                if let song = m.song { md += " · ♪ \(song)\(m.artist.map { " — \($0)" } ?? "")" }
                if let note = m.note { md += "\n  \(note)" }
                md += "\n"
            }
            files["ONE 1/\(day).md"] = md
        }
        return files
    }

    /// Başlıksız girdinin başlığı: tür adı, kullanıcının dilinde.
    static func heading(for kind: String) -> String {
        let key = "export.md.kind.\(kind)"
        let value = NSLocalizedString(key, comment: "Markdown export heading for entry kind")
        return value == key ? kind : value
    }

    static var focusLabel: String { NSLocalizedString("export.md.focus", comment: "Markdown export focus label") }
}

// MARK: - Yazıcı

final class DataExporter {
    enum Format { case json, markdown }

    enum ExportError: Error, Equatable {
        case premiumRequired
        case writeFailed
    }

    private let context: NSManagedObjectContext
    private let journal: JournalStore
    private let mood: MoodStore
    private let day: DayStore
    private let library: LibraryStore
    private let exposure: ExposureStore
    private let legacy: LegacyMomentStore
    private let content: ContentRepository
    private let clock: AppClock

    init(context: NSManagedObjectContext, journal: JournalStore, mood: MoodStore, day: DayStore, library: LibraryStore,
         exposure: ExposureStore, legacy: LegacyMomentStore, content: ContentRepository, clock: AppClock) {
        self.context = context; self.journal = journal; self.mood = mood; self.day = day; self.library = library
        self.exposure = exposure; self.legacy = legacy; self.content = content; self.clock = clock
    }

    func makeExport() throws -> (ExportV2, [ExportMedia]) {
        let today = clock.today
        let origin = DayKey(year: 2000, month: 1, day: 1)!
        let completions = try day.allCompletions()
        var focus: [DayKey: String] = [:]
        for c in completions { if let f = try day.focus(on: c.day) { focus[c.day] = f } }
        let media = try fetchMedia()
        let input = ExportInput(
            entries: try journal.entries(),
            moods: try mood.logs(from: origin, through: today),
            days: completions, focusByDay: focus,
            tags: try library.tags(), badges: try library.badges(), practices: try library.practices(),
            favorites: Array(try exposure.snapshot(.quote).records.values),
            media: media,
            legacy: try legacy.days(from: origin, through: today.adding(days: 1)).flatMap(\.moments)
        )
        return (ExportV2Builder.build(input, catalog: content.catalog, now: clock.now, timeZone: clock.calendar.timeZone), media)
    }

    /// Dosyayı geçici dizine yazar; paylaşım sayfasına verilecek URL'yi döner.
    func write(_ format: Format, hasPremium: Bool, to directory: URL = FileManager.default.temporaryDirectory) throws -> URL {
        if format == .markdown && !hasPremium { throw ExportError.premiumRequired }
        let (export, media) = try makeExport()
        let stamp = clock.today.string
        do {
            switch format {
            case .json:
                let encoder = JSONEncoder()
                encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
                let url = directory.appendingPathComponent("ONE-arsiv-v2-\(stamp).json")
                try encoder.encode(export).write(to: url, options: .atomic)
                return url
            case .markdown:
                let folder = directory.appendingPathComponent("ONE-arsiv-\(stamp)", isDirectory: true)
                let fm = FileManager.default
                try? fm.removeItem(at: folder)
                try fm.createDirectory(at: folder.appendingPathComponent("media"), withIntermediateDirectories: true)
                for (path, text) in MarkdownArchive.render(export) {
                    let url = folder.appendingPathComponent(path)
                    try fm.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
                    try Data(text.utf8).write(to: url, options: .atomic)
                }
                for m in media {
                    if let name = m.fileName, let data = m.data {
                        try data.write(to: folder.appendingPathComponent("media/\(name)"), options: .atomic)
                    }
                }
                let zip = try Self.zip(folder)
                try? fm.removeItem(at: folder)
                return zip
            }
        } catch let error as ExportError {
            throw error
        } catch {
            ONELogger.error("Export v2 write failed", error: error, category: .general)
            throw ExportError.writeFailed
        }
    }

    /// Klasörü zip'ler (`NSFileCoordinator.forUploading`; ek bağımlılık yok).
    static func zip(_ folder: URL) throws -> URL {
        var result: URL?
        var coordinationError: NSError?
        var copyError: Error?
        NSFileCoordinator().coordinate(readingItemAt: folder, options: .forUploading, error: &coordinationError) { zipped in
            let target = folder.deletingLastPathComponent().appendingPathComponent(folder.lastPathComponent + ".zip")
            do {
                try? FileManager.default.removeItem(at: target)
                try FileManager.default.copyItem(at: zipped, to: target)
                result = target
            } catch { copyError = error }
        }
        if let error = coordinationError ?? copyError.map({ $0 as NSError }) { throw error }
        guard let result else { throw ExportError.writeFailed }
        return result
    }

    private func fetchMedia() throws -> [ExportMedia] {
        let rows: [MediaMO] = try context.fetchAll("Media")
        return rows.compactMap { row in
            guard let id = row.id, let entryID = row.entry?.id else { return nil }
            return ExportMedia(id: id, entryID: entryID, type: row.type ?? "photo", order: Int(row.order),
                               data: row.data, songTitle: row.songTitle, songArtist: row.songArtist)
        }
    }
}
