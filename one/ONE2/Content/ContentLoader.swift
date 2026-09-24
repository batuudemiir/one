//
//  ContentLoader.swift
//  ONE 2.0
//
//  Manifest + dosyalar → doğrulanmış `ContentCatalog` (E1). Saf: dosyaları
//  bir `ContentSource`'tan okur, ağ ve disk yazımı yok.
//
//  Reddedilen durumlar (hepsi `ContentLoadError`): manifest yok ya da bozuk,
//  `schemaVersion` major'ı büyük, manifestteki dosya yok, hash uyuşmuyor,
//  JSON çözülemiyor, aynı türde ID çakışıyor. Reddedilen kaynak yerine bir
//  öncekine (önbellek → bundle) düşülür; hiçbir durumda boş ekran yok.
//

import Foundation
import CryptoKit

/// İçerik dosyalarının okunduğu yer. `path` manifest köküne göredir.
nonisolated protocol ContentSource: Sendable {
    func data(at path: String) -> Data?
}

nonisolated enum ContentLoadError: Error, Equatable {
    case missingManifest
    case unsupportedSchema(String)
    case missingFile(String)
    case hashMismatch(String)
    case corrupt(String)
    case duplicateIDs([String])
}

nonisolated enum ContentFiles {
    static let manifest = "manifest.json"
    static let quotes = "quotes.tr.json"
    static let prompts = "prompts.tr.json"
    static let evergreen = "themes/evergreen.tr.json"
    static let echoes = "echoes.tr.json"
    static let emotions = "catalogs/emotions.tr.json"
    static let causes = "catalogs/causes.tr.json"
    static let badges = "catalogs/badges.tr.json"
    static let paths = "catalogs/paths.tr.json"
    /// Şema v2 (08 §3.1).
    static let thinkers = "catalogs/thinkers.tr.json"

    static func isWeeklyTheme(_ path: String) -> Bool {
        path.hasPrefix("themes/") && path != evergreen
    }

    static func isGuided(_ path: String) -> Bool { path.hasPrefix("guided/") }

    static func sha256(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
}

nonisolated enum ContentLoader {

    static func manifest(from source: ContentSource) throws -> ContentManifest {
        guard let data = source.data(at: ContentFiles.manifest) else { throw ContentLoadError.missingManifest }
        let manifest: ContentManifest
        do { manifest = try JSONDecoder().decode(ContentManifest.self, from: data) }
        catch { throw ContentLoadError.corrupt(ContentFiles.manifest) }
        guard let major = manifest.schemaMajor, major <= ContentSchema.supportedMajor else {
            throw ContentLoadError.unsupportedSchema(manifest.schemaVersion)
        }
        return manifest
    }

    /// Manifestteki her dosyayı okur, hash'ini doğrular, çözer.
    static func load(from source: ContentSource) throws -> ContentCatalog {
        let manifest = try manifest(from: source)
        var files: [String: Data] = [:]
        for file in manifest.files {
            guard let data = source.data(at: file.path) else { throw ContentLoadError.missingFile(file.path) }
            guard ContentFiles.sha256(data) == file.sha256.lowercased() else {
                throw ContentLoadError.hashMismatch(file.path)
            }
            files[file.path] = data
        }

        func items<T: Codable & Sendable>(_ path: String, as: T.Type = T.self) throws -> [T] {
            guard let data = files[path] else { return [] }
            do { return try JSONDecoder().decode(ContentFile<T>.self, from: data).items }
            catch { throw ContentLoadError.corrupt(path) }
        }
        func all<T: Codable & Sendable>(_ match: (String) -> Bool, as: T.Type = T.self) throws -> [T] {
            try files.keys.filter(match).sorted().flatMap { try items($0, as: T.self) }
        }

        let catalog = ContentCatalog(
            manifest: manifest,
            quotes: try items(ContentFiles.quotes),
            prompts: try items(ContentFiles.prompts),
            themes: try all(ContentFiles.isWeeklyTheme),
            evergreenThemes: try items(ContentFiles.evergreen),
            guided: try all(ContentFiles.isGuided),
            echoes: try items(ContentFiles.echoes),
            emotions: try items(ContentFiles.emotions),
            causes: try items(ContentFiles.causes),
            badges: try items(ContentFiles.badges),
            paths: try items(ContentFiles.paths),
            thinkers: try items(ContentFiles.thinkers)
        )
        let duplicates = catalog.duplicateIDs
        guard duplicates.isEmpty else { throw ContentLoadError.duplicateIDs(duplicates) }
        return catalog
    }
}

// MARK: - Kaynaklar

/// Uygulama paketindeki içerik (`one/ONE2/Content/Bundled/`). Klasör senkronlu
/// grup kaynakları paket köküne düzleştirebilir; yol bulunamazsa dosya adıyla
/// aranır.
nonisolated struct BundleContentSource: ContentSource {
    let bundle: Bundle
    var subdirectory: String = "Bundled"

    func data(at path: String) -> Data? {
        let name = (path as NSString).lastPathComponent
        let dir = (path as NSString).deletingLastPathComponent
        let candidates: [URL?] = [
            bundle.resourceURL?.appendingPathComponent(subdirectory).appendingPathComponent(path),
            bundle.url(forResource: name, withExtension: nil, subdirectory: dir.isEmpty ? nil : dir),
            bundle.url(forResource: name, withExtension: nil),
        ]
        for case let url? in candidates {
            if let data = try? Data(contentsOf: url) { return data }
        }
        return nil
    }
}

/// Diskteki bir klasör (Application Support/Content).
nonisolated struct DirectoryContentSource: ContentSource {
    let root: URL

    func data(at path: String) -> Data? {
        try? Data(contentsOf: root.appendingPathComponent(path))
    }
}

/// Testler ve katmanlama için bellekte kaynak.
nonisolated struct MemoryContentSource: ContentSource {
    var files: [String: Data]

    func data(at path: String) -> Data? { files[path] }
}

/// Üstteki kaynakta olmayan dosyayı alttakinden okur (kısmi güncelleme).
nonisolated struct LayeredContentSource: ContentSource {
    let top: ContentSource
    let base: ContentSource

    func data(at path: String) -> Data? { top.data(at: path) ?? base.data(at: path) }
}
