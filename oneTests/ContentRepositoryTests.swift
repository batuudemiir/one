//
//  ContentRepositoryTests.swift
//  oneTests
//
//  E1: içerik şeması v1, doğrulama ve güncelleme (04_arka_plan_motorlari.md).
//

import Testing
import Foundation
@testable import OneDailyBatuhan

/// Test içeriği: dosya yolu → JSON nesnesi; manifest hash'leri otomatik.
nonisolated enum ContentFixture {
    static func data(_ object: Any) -> Data {
        try! JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
    }

    static func source(_ files: [String: Any], schema: String = "1.0", version: Int = 1,
                       manifestOverride: ((inout [[String: Any]]) -> Void)? = nil) -> MemoryContentSource {
        var raw = files.mapValues { data($0) }
        var entries: [[String: Any]] = raw.keys.sorted().map { path in
            ["path": path, "sha256": ContentFiles.sha256(raw[path]!), "bytes": raw[path]!.count]
        }
        manifestOverride?(&entries)
        raw[ContentFiles.manifest] = data([
            "schemaVersion": schema, "contentVersion": version, "generatedAt": "2026-09-23T00:00:00Z", "files": entries,
        ])
        return MemoryContentSource(files: raw)
    }

    static func quote(_ id: String, _ text: String = "Küçük bir adım da sayılır.", kind: String = "affirmation") -> [String: Any] {
        ["id": id, "text": text, "kind": kind, "license": "original", "themes": ["cesaret"], "paths": ["cesur"],
         "timeOfDay": "any", "premium": false, "active": true, "addedIn": 1, "lang": "tr"]
    }

    static func quotes(_ items: [[String: Any]]) -> [String: Any] { ["items": items] }
}

@MainActor
struct ContentRepositoryTests {

    private var bundleSource: BundleContentSource {
        BundleContentSource(bundle: Bundle(for: PersistenceController.self))
    }

    // MARK: - Bundle

    @Test("Bundle içeriği yükleniyor ve her dosya 20–50 öğe (tekil dosyalar hariç)")
    func bundleLoads() throws {
        let catalog = try ContentLoader.load(from: bundleSource)
        #expect(catalog.manifest.schemaMajor == 1)
        #expect((20...50).contains(catalog.quotes.count))
        #expect((20...50).contains(catalog.prompts.count))
        #expect((20...50).contains(catalog.echoes.count))
        #expect((20...50).contains(catalog.emotions.count))
        #expect((20...50).contains(catalog.causes.count))
        #expect((20...50).contains(catalog.badges.count))
        #expect((20...50).contains(catalog.evergreenThemes.count))
        #expect(catalog.paths.count == 5)
        #expect(!catalog.themes.isEmpty && !catalog.guided.isEmpty)
        #expect(Set(catalog.quotes.map(\.kind)) == Set(QuoteKind.allCases))
        #expect(catalog.duplicateIDs.isEmpty)
    }

    @Test("Bundle dosyalarının hepsi PLACEHOLDER CONTENT işaretli")
    func bundleIsMarkedPlaceholder() throws {
        let manifest = try ContentLoader.manifest(from: bundleSource)
        for path in manifest.files.map(\.path) + [ContentFiles.manifest] {
            let text = String(decoding: try #require(bundleSource.data(at: path)), as: UTF8.self)
            #expect(text.contains("// PLACEHOLDER CONTENT"), "\(path)")
        }
    }

    @Test("Bundle içeriğinde çapraz referanslar çözülüyor")
    func bundleCrossReferences() throws {
        let c = try ContentLoader.load(from: bundleSource)
        let pathIDs = Set(c.paths.map(\.id))
        let families = Set(c.emotions.map(\.family))
        let causeIDs = Set(c.causes.map(\.id))
        for q in c.quotes {
            #expect(Set(q.paths).isSubset(of: pathIDs), "\(q.id) paths")
            #expect(Set(q.emotionFit).isSubset(of: families), "\(q.id) emotionFit")
            #expect(q.moodFit.allSatisfy { (1...5).contains($0) }, "\(q.id) moodFit")
            for pid in q.reflectionPromptIDs ?? [] { #expect(c.prompt(pid)?.pool == .reflection, "\(q.id) → \(pid)") }
            if q.kind == .quote { #expect(q.author != nil && q.source != nil, "\(q.id) kaynak") }
        }
        for p in c.prompts { for qid in p.quoteIDs { #expect(c.quote(qid) != nil, "\(p.id) → \(qid)") } }
        for e in c.echoes {
            #expect(Set(e.conditions.causeAny ?? []).isSubset(of: causeIDs), "\(e.id) causeAny")
            #expect(Set(e.conditions.emotionFamilyAny ?? []).isSubset(of: families), "\(e.id) family")
        }
        for t in c.themes + c.evergreenThemes { #expect(t.days.map(\.day) == Array(1...7), "\(t.id)") }
        // UX sözleşmesi (UX_istekleri.md §1): 38 duygu, <aile>.<ad>, sekiz aile.
        #expect(families == ["nese", "huzur", "enerji", "sevgi", "kaygi", "huzun", "ofke", "yorgun"])
        #expect(c.emotions.count == 38 && c.emotions.first?.id == "nese.minnettar")
        #expect(c.emotions.allSatisfy { $0.id.hasPrefix($0.family + ".") })
    }

    // MARK: - Doğrulama

    @Test("Bozuk JSON reddediliyor")
    func corruptJSON() {
        var source = ContentFixture.source([ContentFiles.quotes: ContentFixture.quotes([ContentFixture.quote("q_000001")])])
        let bad = Data("{\"items\": [".utf8)
        source.files[ContentFiles.quotes] = bad
        // Hash'i bozuk dosyaya göre yeniden yaz: yalnız JSON hatası kalsın.
        let manifest = ContentFixture.data([
            "schemaVersion": "1.0", "contentVersion": 1, "generatedAt": "",
            "files": [["path": ContentFiles.quotes, "sha256": ContentFiles.sha256(bad)]],
        ])
        source.files[ContentFiles.manifest] = manifest
        #expect(throws: ContentLoadError.corrupt(ContentFiles.quotes)) { try ContentLoader.load(from: source) }
    }

    @Test("Hash uyuşmazlığı reddediliyor")
    func hashMismatch() {
        var source = ContentFixture.source([ContentFiles.quotes: ContentFixture.quotes([ContentFixture.quote("q_000001")])])
        source.files[ContentFiles.quotes] = ContentFixture.data(ContentFixture.quotes([ContentFixture.quote("q_000002")]))
        #expect(throws: ContentLoadError.hashMismatch(ContentFiles.quotes)) { try ContentLoader.load(from: source) }
    }

    @Test("schemaVersion major'ı büyükse reddediliyor (v1 ve v2 okunur, 08)")
    func schemaTooNew() {
        let source = ContentFixture.source([:], schema: "3.0")
        #expect(throws: ContentLoadError.unsupportedSchema("3.0")) { try ContentLoader.load(from: source) }
        #expect((try? ContentLoader.load(from: ContentFixture.source([:], schema: "1.7"))) != nil)
        #expect((try? ContentLoader.load(from: ContentFixture.source([:], schema: "2.0"))) != nil)
    }

    @Test("Manifestteki dosya eksikse reddediliyor")
    func missingFile() {
        var source = ContentFixture.source([ContentFiles.quotes: ContentFixture.quotes([])])
        source.files[ContentFiles.quotes] = nil
        #expect(throws: ContentLoadError.missingFile(ContentFiles.quotes)) { try ContentLoader.load(from: source) }
        #expect(throws: ContentLoadError.missingManifest) { try ContentLoader.load(from: MemoryContentSource(files: [:])) }
    }

    @Test("Aynı türde ID çakışması reddediliyor")
    func duplicateIDs() {
        let source = ContentFixture.source([ContentFiles.quotes: ContentFixture.quotes([
            ContentFixture.quote("q_000001"), ContentFixture.quote("q_000001", "Başka bir metin burada."),
        ])])
        #expect(throws: ContentLoadError.duplicateIDs(["q_000001"])) { try ContentLoader.load(from: source) }
    }

    @Test("Uzunluk dosyada yoksa metinden türetiliyor")
    func lengthDerived() throws {
        let long = String(repeating: "uzun cümle ", count: 16)
        let source = ContentFixture.source([ContentFiles.quotes: ContentFixture.quotes([
            ContentFixture.quote("q_000001", "Kısa bir söz."), ContentFixture.quote("q_000002", long),
        ])])
        let catalog = try ContentLoader.load(from: source)
        #expect(catalog.quote("q_000001")?.length == .short)
        #expect(catalog.quote("q_000002")?.length == .long)
    }

    // MARK: - Depo ve güncelleme

    private func makeRepository(fetcher: FakeContentFetcher, bundle: ContentSource? = nil,
                                cache: URL = Self.tempDirectory()) -> ContentRepository {
        ContentRepository(bundle: bundle ?? ContentFixture.source(
                              [ContentFiles.quotes: ContentFixture.quotes([ContentFixture.quote("q_000001")])]),
                          cacheDirectory: cache, fetcher: fetcher, clock: FixedClock(Date(timeIntervalSince1970: 1_790_000_000)),
                          defaults: UserDefaults(suiteName: "ContentRepositoryTests-\(UUID().uuidString)")!,
                          remoteBase: URL(string: "https://example.invalid/content/v1/")!)
    }

    nonisolated private static func tempDirectory() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("ContentTests-\(UUID().uuidString)/Content")
    }

    @Test("Çevrimdışı ilk açılış bundle ile çalışıyor")
    func offlineFirstLaunch() async {
        let repo = makeRepository(fetcher: FakeContentFetcher(files: nil))
        #expect(repo.origin == .bundle)
        #expect(repo.catalog.quotes.count == 1)
        #expect(await repo.refreshIfNeeded() == .failed)
        #expect(repo.catalog.quotes.count == 1)
    }

    @Test("Geçerli uzak güncelleme yükleniyor, önbelleğe yazılıyor, sonraki açılışta önbellekten geliyor")
    func remoteUpdate() async throws {
        let cache = Self.tempDirectory()
        let remote = ContentFixture.source([ContentFiles.quotes: ContentFixture.quotes([
            ContentFixture.quote("q_000001"), ContentFixture.quote("q_000002", "Yeni bir söz daha geldi."),
        ])], version: 2)
        var posted = false
        let token = NotificationCenter.default.addObserver(forName: ContentRepository.didUpdate, object: nil, queue: nil) { _ in
            posted = true
        }
        defer { NotificationCenter.default.removeObserver(token) }

        let repo = makeRepository(fetcher: FakeContentFetcher(files: remote.files), cache: cache)
        #expect(await repo.refreshIfNeeded() == .updated(contentVersion: 2))
        #expect(repo.catalog.quotes.count == 2)
        #expect(posted)

        let reopened = makeRepository(fetcher: FakeContentFetcher(files: nil), cache: cache)
        #expect(reopened.origin == .cache)
        #expect(reopened.catalog.contentVersion == 2)
        // Aynı gün ikinci kez sorulmaz.
        #expect(await repo.refreshIfNeeded() == .skipped)
    }

    @Test("Hash'i tutmayan uzak içerik reddediliyor, mevcut içerik ve önbellek korunuyor")
    func remoteRejected() async {
        let cache = Self.tempDirectory()
        var remote = ContentFixture.source([ContentFiles.quotes: ContentFixture.quotes([ContentFixture.quote("q_000009")])],
                                           version: 2)
        remote.files[ContentFiles.quotes] = Data("bozuk".utf8)
        let repo = makeRepository(fetcher: FakeContentFetcher(files: remote.files), cache: cache)
        #expect(await repo.refreshIfNeeded() == .rejected(.hashMismatch(ContentFiles.quotes)))
        #expect(repo.catalog.quote("q_000001") != nil)
        #expect(!FileManager.default.fileExists(atPath: cache.path))
    }

    @Test("Uzak şema büyükse güncelleme yok sayılıyor")
    func remoteSchemaTooNew() async {
        let remote = ContentFixture.source([:], schema: "3.0", version: 9)
        let repo = makeRepository(fetcher: FakeContentFetcher(files: remote.files))
        #expect(await repo.refreshIfNeeded() == .rejected(.unsupportedSchema("3.0")))
        #expect(repo.catalog.contentVersion == 1)
    }

    @Test("Eski ya da aynı sürüm indirilmiyor")
    func remoteNotNewer() async {
        let remote = ContentFixture.source([ContentFiles.quotes: ContentFixture.quotes([])], version: 1)
        let fetcher = FakeContentFetcher(files: remote.files)
        let repo = makeRepository(fetcher: fetcher)
        #expect(await repo.refreshIfNeeded() == .upToDate)
        #expect(fetcher.requested == [ContentFiles.manifest])
    }

    @Test("Bozuk önbellek bundle'a düşüyor")
    func corruptCacheFallsBack() throws {
        let cache = Self.tempDirectory()
        try FileManager.default.createDirectory(at: cache, withIntermediateDirectories: true)
        try Data("{".utf8).write(to: cache.appendingPathComponent(ContentFiles.manifest))
        let repo = makeRepository(fetcher: FakeContentFetcher(files: nil), cache: cache)
        #expect(repo.origin == .bundle)
        #expect(repo.catalog.quotes.count == 1)
    }
}

/// `files == nil`: çevrimdışı.
final class FakeContentFetcher: ContentFetching, @unchecked Sendable {
    let files: [String: Data]?
    private(set) var requested: [String] = []

    init(files: [String: Data]?) { self.files = files }

    func fetch(_ url: URL, etag: String?) async throws -> (data: Data, etag: String?)? {
        guard let files else { throw URLError(.notConnectedToInternet) }
        let path = url.pathComponents.drop { $0 != "v1" }.dropFirst().joined(separator: "/")
        requested.append(path)
        guard let data = files[path] else { throw URLError(.fileDoesNotExist) }
        return (data, nil)
    }
}
