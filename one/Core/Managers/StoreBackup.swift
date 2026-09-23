//
//  StoreBackup.swift
//  one
//
//  Açılamayan store'u silmeden önce kenara taşır.
//
//  `PersistenceController.recoverFromUnopenableStore` eskiden store'u doğrudan
//  siliyordu: veri CloudKit'ten geri iner varsayımıyla. iCloud'u kapalı
//  kullanıcıda bu kalıcı kayıp demek (MIGRATION.md §4, AUDIT R3). Model
//  sürümü `one 3`'e geçerken store'un açılamama ihtimali ilk kez gerçek bir
//  risk oluyor; silinen yerine taşınan dosya en azından elle kurtarılabilir.
//
//  Taşınanlar: `<ad>.sqlite`, `-wal`, `-shm` ve harici ikili veri klasörü
//  `.<ad>_SUPPORT` (fotoğraflar `allowsExternalBinaryDataStorage` ile orada).
//

import Foundation

nonisolated enum StoreBackup {

    /// Son kaç yedek tutulur. Yedekler fotoğrafları da taşıdığı için büyük;
    /// sınırsız birikmesin.
    static let keepCount = 2

    static func defaultRoot(fileManager: FileManager = .default) -> URL? {
        fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
            .appendingPathComponent("StoreBackups", isDirectory: true)
    }

    /// Store dosyalarını `root/<zaman damgası>/` altına taşır ve klasörün
    /// URL'sini döner. Taşınacak hiçbir dosya yoksa `nil`.
    ///
    /// Bir dosya taşınamazsa hata fırlatır; o durumda çağıran taraf eski
    /// silme yoluna düşmeli, çünkü yarım kalan store yeniden açılmaz.
    @discardableResult
    static func moveAside(
        storeURL: URL,
        root: URL,
        now: Date = Date(),
        fileManager: FileManager = .default
    ) throws -> URL? {
        let candidates = files(for: storeURL).filter { fileManager.fileExists(atPath: $0.path) }
        guard !candidates.isEmpty else { return nil }

        let folder = root.appendingPathComponent(stamp(now), isDirectory: true)
        try fileManager.createDirectory(at: folder, withIntermediateDirectories: true)
        for source in candidates {
            try fileManager.moveItem(
                at: source,
                to: folder.appendingPathComponent(source.lastPathComponent)
            )
        }
        prune(root: root, keeping: keepCount, fileManager: fileManager)
        return folder
    }

    /// Store'a ait tüm dosyalar: ana dosya, SQLite yan dosyaları ve harici
    /// veri klasörü.
    static func files(for storeURL: URL) -> [URL] {
        let dir = storeURL.deletingLastPathComponent()
        let name = storeURL.deletingPathExtension().lastPathComponent
        return [
            storeURL,
            URL(fileURLWithPath: storeURL.path + "-wal"),
            URL(fileURLWithPath: storeURL.path + "-shm"),
            dir.appendingPathComponent(".\(name)_SUPPORT", isDirectory: true)
        ]
    }

    /// En yeni `count` yedeği bırakır. Klasör adları zaman damgası olduğu
    /// için ad sırası tarih sırasıdır.
    static func prune(root: URL, keeping count: Int, fileManager: FileManager = .default) {
        guard let entries = try? fileManager.contentsOfDirectory(
            at: root, includingPropertiesForKeys: nil
        ) else { return }
        let sorted = entries.sorted { $0.lastPathComponent > $1.lastPathComponent }
        for stale in sorted.dropFirst(count) {
            try? fileManager.removeItem(at: stale)
        }
    }

    /// `2026-09-23T11-40-05Z`: dosya adında `:` yok, sözlük sırası = zaman sırası.
    static func stamp(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "UTC")
        f.dateFormat = "yyyy-MM-dd'T'HH-mm-ss'Z'"
        return f.string(from: date)
    }
}
