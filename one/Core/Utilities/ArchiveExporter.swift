//
//  ArchiveExporter.swift
//  one
//
//  Arşivin dışa aktarılması. Duruş ilke 4: **arşivin sahibi kullanıcıdır** —
//  dışa aktarma birinci sınıf bir özellik, gizli bir ayar değil.
//
//  Biçim JSON: makinenin de insanın da okuyabildiği tek dosya. CSV, notlardaki
//  satır sonlarını ve virgülleri kaybediyor; kaydın kendisi metin olduğu için
//  bu kabul edilebilir bir kayıp değil.
//
//  Fotoğraflar dosyaya girmiyor. Binary'i base64'e çevirmek dosyayı on kat
//  büyütüp okunmaz yapıyor; kayıtta fotoğrafın **varlığı** bilgi olarak
//  duruyor (`hasPhoto`).
//

import Foundation
import CoreData

enum ArchiveExporter {

    /// Tek bir an. Alan adları İngilizce ve sabit: dosya kullanıcının
    /// dilinden bağımsız okunabilir olmalı, uygulama dili değişince eski
    /// dışa aktarımlar anlamını kaybetmemeli.
    struct ExportedMoment: Encodable {
        let date: String            // ISO-8601, yalnız gün (2026-09-09)
        let createdAt: String?      // ISO-8601, tam zaman damgası
        let mood: String?
        let moodColor: String?
        let song: String?
        let artist: String?
        let note: String?
        let hasPhoto: Bool
        let sharedWithCircle: Bool
    }

    struct ExportedArchive: Encodable {
        let app = "ONE"
        let schema = 1
        let exportedAt: String
        let momentCount: Int
        let moments: [ExportedMoment]
    }

    enum ExportError: LocalizedError {
        case writeFailed(Error)

        var errorDescription: String? {
            NSLocalizedString("export.failed", comment: "")
        }
    }

    // MARK: - Public

    /// Tüm kayıtları tek dosyaya yazar ve dosyanın URL'sini döner.
    ///
    /// Geçici dizine yazılıyor: paylaşım sayfası dosyayı kullanıcının seçtiği
    /// yere kopyalıyor, uygulamanın kendi kutusunda ikinci bir kopya tutmasının
    /// bir anlamı yok.
    static func writeArchive(context: NSManagedObjectContext,
                             now: Date = Date()) throws -> URL {
        let moments = fetchMoments(context: context)
        let payload = ExportedArchive(
            exportedAt: isoFull.string(from: now),
            momentCount: moments.count,
            moments: moments
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]

        do {
            let data = try encoder.encode(payload)
            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent(fileName(now: now))
            try data.write(to: url, options: .atomic)
            ONELogger.success("Arşiv dışa aktarıldı: \(moments.count) an", category: .general)
            return url
        } catch {
            ONELogger.error("Arşiv dışa aktarılamadı", error: error, category: .general)
            throw ExportError.writeFailed(error)
        }
    }

    /// Dosya adı: `ONE-arsiv-2026-09-09.json`. Tarih ISO — dosya listesinde
    /// kendiliğinden sıralanıyor.
    static func fileName(now: Date = Date()) -> String {
        "ONE-arsiv-\(isoDay.string(from: now)).json"
    }

    // MARK: - Internal

    private static func fetchMoments(context: NSManagedObjectContext) -> [ExportedMoment] {
        let request: NSFetchRequest<DailySong> = DailySong.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "date", ascending: true),
                                   NSSortDescriptor(key: "createdAt", ascending: true)]
        guard let rows = try? context.fetch(request) else { return [] }

        return rows.compactMap { row in
            guard let date = row.date else { return nil }
            let note = row.dailyNote?.trimmingCharacters(in: .whitespacesAndNewlines)
            return ExportedMoment(
                date: isoDay.string(from: date),
                createdAt: row.createdAt.map { isoFull.string(from: $0) },
                mood: row.moodLabel ?? row.moodWord,
                moodColor: row.moodColorHex,
                song: row.songName,
                artist: row.artistName,
                note: (note?.isEmpty ?? true) ? nil : note,
                hasPhoto: row.photoData != nil || (row.photoURL?.isEmpty == false),
                sharedWithCircle: row.isSharedWithCircle
            )
        }
    }

    /// Sabit `en_US_POSIX`: dosya içeriği cihazın takvimine göre değişmemeli.
    private static let isoDay: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone.current
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    private static let isoFull: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone.current
        f.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
        return f
    }()
}
