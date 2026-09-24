//
//  ContentRepository.swift
//  ONE 2.0
//
//  İçeriğin tek sahibi (ADR-001 §5, 04 › E1). Açılışta önbellek ya da bundle
//  yüklenir; günde en fazla bir kez uzak manifest sorulur, değişen dosyalar
//  indirilir, doğrulanır ve `Application Support/Content/`'e atomik yazılır.
//  İçerik değişince `catalog` güncellenir ve `didUpdate` yayınlanır;
//  motorlar önbelleklerini buna göre tazeler.
//
//  Öncelik: geçerli önbellek (bundle'dan yeni ya da eşitse) → bundle.
//  Bozuk/eksik/uyumsuz uzak içerik hiçbir zaman yüklenmez.
//

import Foundation
import Observation

/// Uzak içerik isteği (URLSession'ın ince sarmalayıcısı; testte sahte).
nonisolated protocol ContentFetching: Sendable {
    /// `etag` verilirse `If-None-Match` gönderilir; 304'te `nil` döner.
    func fetch(_ url: URL, etag: String?) async throws -> (data: Data, etag: String?)?
}

nonisolated struct URLSessionContentFetcher: ContentFetching {
    var session: URLSession = .shared

    func fetch(_ url: URL, etag: String?) async throws -> (data: Data, etag: String?)? {
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 20)
        if let etag { request.setValue(etag, forHTTPHeaderField: "If-None-Match") }
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
        if http.statusCode == 304 { return nil }
        guard (200..<300).contains(http.statusCode) else { throw URLError(.badServerResponse) }
        return (data, http.value(forHTTPHeaderField: "ETag"))
    }
}

nonisolated enum ContentUpdateResult: Equatable, Sendable {
    /// Yeni içerik yüklendi.
    case updated(contentVersion: Int)
    /// Uzakta yeni bir şey yok (304 ya da aynı/eski sürüm).
    case upToDate
    /// Bugün zaten soruldu.
    case skipped
    /// İndirildi ama reddedildi; mevcut içerik kaldı.
    case rejected(ContentLoadError)
    /// Ağ hatası; mevcut içerik kaldı.
    case failed
}

@Observable
final class ContentRepository {
    static let didUpdate = Notification.Name("one2.content.didUpdate")
    static let remoteBase = URL(string: "https://one.forvibe.app/content/v1/")!

    private(set) var catalog: ContentCatalog
    /// Yüklenen içeriğin nereden geldiği (tanı ve test için).
    private(set) var origin: Origin

    enum Origin: Equatable { case bundle, cache, none }

    @ObservationIgnored private let bundle: ContentSource
    @ObservationIgnored private let cacheDirectory: URL
    @ObservationIgnored private let fetcher: ContentFetching
    @ObservationIgnored private let clock: AppClock
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let remoteBase: URL

    private static let lastCheckKey = "one2.content.lastCheckDay"
    private static let etagKey = "one2.content.manifestETag"

    init(bundle: ContentSource = BundleContentSource(bundle: .main),
         cacheDirectory: URL = ContentRepository.defaultCacheDirectory,
         fetcher: ContentFetching = URLSessionContentFetcher(),
         clock: AppClock = SystemClock(),
         defaults: UserDefaults = .standard,
         remoteBase: URL = ContentRepository.remoteBase) {
        self.bundle = bundle
        self.cacheDirectory = cacheDirectory
        self.fetcher = fetcher
        self.clock = clock
        self.defaults = defaults
        self.remoteBase = remoteBase
        (catalog, origin) = Self.loadLocal(bundle: bundle, cache: cacheDirectory)
    }

    static var defaultCacheDirectory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("Content", isDirectory: true)
    }

    /// Önbellek geçerliyse ve bundle'dan eski değilse önbellek; değilse bundle.
    static func loadLocal(bundle: ContentSource, cache: URL) -> (ContentCatalog, Origin) {
        let bundled = try? ContentLoader.load(from: bundle)
        // Önbellek ancak kendi manifesti varsa sayılır; yoksa katmanlı kaynak
        // bundle'ın kendisi olur.
        let cacheSource = DirectoryContentSource(root: cache)
        let cached = cacheSource.data(at: ContentFiles.manifest) == nil ? nil
            : try? ContentLoader.load(from: LayeredContentSource(top: cacheSource, base: bundle))
        if let cached, cached.contentVersion >= (bundled?.contentVersion ?? -1) { return (cached, .cache) }
        if let bundled { return (bundled, .bundle) }
        ONELogger.error("[content] bundled content failed to load")
        return (.empty, .none)
    }

    /// Günde en fazla bir kez uzak manifesti sorar (Tier 2). `force` testler ve
    /// DEBUG menüsü içindir.
    @discardableResult
    func refreshIfNeeded(force: Bool = false) async -> ContentUpdateResult {
        let today = clock.today.string
        if !force, defaults.string(forKey: Self.lastCheckKey) == today { return .skipped }
        defaults.set(today, forKey: Self.lastCheckKey)

        let remoteManifestData: Data
        do {
            guard let response = try await fetcher.fetch(remoteBase.appendingPathComponent(ContentFiles.manifest),
                                                         etag: force ? nil : defaults.string(forKey: Self.etagKey))
            else { return .upToDate }
            remoteManifestData = response.data
            if let etag = response.etag { defaults.set(etag, forKey: Self.etagKey) }
        } catch {
            return .failed
        }

        let manifest: ContentManifest
        do { manifest = try ContentLoader.manifest(from: MemoryContentSource(files: [ContentFiles.manifest: remoteManifestData])) }
        catch let error as ContentLoadError { return .rejected(error) }
        catch { return .failed }
        guard manifest.contentVersion > catalog.contentVersion else { return .upToDate }

        // Yalnız hash'i değişen dosyalar indirilir; diğerleri mevcut içerikten.
        let current = LayeredContentSource(top: DirectoryContentSource(root: cacheDirectory), base: bundle)
        var downloaded: [String: Data] = [ContentFiles.manifest: remoteManifestData]
        for file in manifest.files {
            if let local = current.data(at: file.path), ContentFiles.sha256(local) == file.sha256.lowercased() {
                downloaded[file.path] = local
                continue
            }
            do {
                guard let response = try await fetcher.fetch(remoteBase.appendingPathComponent(file.path), etag: nil)
                else { return .failed }
                downloaded[file.path] = response.data
            } catch {
                return .failed
            }
        }

        let candidate = MemoryContentSource(files: downloaded)
        let loaded: ContentCatalog
        do { loaded = try ContentLoader.load(from: candidate) }
        catch let error as ContentLoadError {
            ONELogger.error("[content] remote content rejected: \(String(describing: error))")
            return .rejected(error)
        } catch { return .failed }

        do { try Self.writeAtomically(downloaded, to: cacheDirectory) }
        catch { return .failed }

        catalog = loaded
        origin = .cache
        NotificationCenter.default.post(name: Self.didUpdate, object: self)
        return .updated(contentVersion: loaded.contentVersion)
    }

    /// Önce geçici klasöre yazar, sonra tek adımda yer değiştirir: yarıda
    /// kalan güncelleme eski önbelleği bozmaz.
    static func writeAtomically(_ files: [String: Data], to directory: URL) throws {
        let fm = FileManager.default
        let parent = directory.deletingLastPathComponent()
        try fm.createDirectory(at: parent, withIntermediateDirectories: true)
        let staging = parent.appendingPathComponent("Content-staging-\(UUID().uuidString)", isDirectory: true)
        defer { try? fm.removeItem(at: staging) }
        for (path, data) in files {
            let url = staging.appendingPathComponent(path)
            try fm.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try data.write(to: url, options: .atomic)
        }
        if fm.fileExists(atPath: directory.path) {
            _ = try fm.replaceItemAt(directory, withItemAt: staging)
        } else {
            try fm.moveItem(at: staging, to: directory)
        }
    }
}
