//
//  QuoteSchemaV2Tests.swift
//  oneTests
//
//  08 › S1: şema v2 (Thinker, SourceRef, authorID, tones, düşünce yolları),
//  loader v1 + v2, v1 ad → ID eşleme.
//

import Testing
import Foundation
@testable import OneDailyBatuhan

struct QuoteSchemaV2Tests {

    private static func v1Quote(_ id: String, author: String?, kind: String = "quote") -> [String: Any] {
        var q: [String: Any] = [
            "id": id, "text": "Bazı şeyler senin elindedir, bazıları değildir.", "kind": kind,
            "license": "publicDomain", "translation": "oneTranslation",
            "themes": ["kabul"], "paths": ["filozof", "sakin"], "premium": false, "active": true, "addedIn": 1, "lang": "tr",
        ]
        if let author { q["author"] = author; q["source"] = "Encheiridion, 1" }
        return q
    }

    private static let seneca: [String: Any] = [
        "id": "th_seneca", "displayName": "Seneca", "aliases": ["Lucius Annaeus Seneca"], "kind": "philosopher",
        "birthYear": -4, "deathYear": 65, "eraDisplay": "MÖ 4 – MS 65", "pathIDs": ["stoacilar"],
        "coreIdea": "PLACEHOLDER", "bioShort": "PLACEHOLDER", "active": true, "addedIn": 2, "lang": "tr",
    ]

    private static let epiktetos: [String: Any] = [
        "id": "th_epiktetos", "displayName": "Epiktetos", "aliases": ["Epiktet"], "kind": "philosopher",
        "birthYear": 50, "deathYear": 135, "eraDisplay": "MS 50 – 135", "pathIDs": ["stoacilar"],
        "coreIdea": "PLACEHOLDER", "bioShort": "PLACEHOLDER", "active": true, "addedIn": 2, "lang": "tr",
    ]

    @Test("v1 dosyası: ad → authorID, kaynak metni → SourceRef, ses yolları → tones")
    func v1File() throws {
        let source = ContentFixture.source([ContentFiles.quotes: ContentFixture.quotes([Self.v1Quote("q_000001", author: "Epiktetos")])])
        let catalog = try ContentLoader.load(from: source)
        let q = try #require(catalog.quote("q_000001"))
        #expect(q.authorID == "th_epiktetos")
        #expect(q.attribution == "Epiktetos") // katalogda düşünür yok: v1 adı
        #expect(q.sourceRef == SourceRef(work: "Encheiridion, 1", translation: .oneTranslation))
        #expect(q.tones == ["derin", "sakin"])
        #expect(q.paths.isEmpty)
        #expect(q.verified && q.active)
        #expect(catalog.unmatchedAuthors.isEmpty)
    }

    @Test("v1 söz + v2 düşünür kataloğu: ad satırı displayName, yol düşünürden, takma ad eşler")
    func v1WithThinkers() throws {
        let source = ContentFixture.source([
            ContentFiles.quotes: ContentFixture.quotes([Self.v1Quote("q_000001", author: "Epiktet"),
                                                        Self.v1Quote("q_000002", author: "Lucius Annaeus Seneca")]),
            ContentFiles.thinkers: ["items": [Self.epiktetos, Self.seneca]],
        ], schema: "2.0")
        let catalog = try ContentLoader.load(from: source)
        #expect(catalog.thinkers.count == 2)
        let q = try #require(catalog.quote("q_000001"))
        #expect(q.authorID == "th_epiktetos" && q.attribution == "Epiktetos" && q.paths == ["stoacilar"])
        #expect(catalog.quote("q_000002")?.attribution == "Seneca")
        #expect(catalog.thinker("th_seneca")?.rights == .publicDomain)
    }

    @Test("Eşleşmeyen yazar: quote pasifleşir ve listelenir; diğer türler etkilenmez")
    func unmatchedAuthor() throws {
        var affirmation = Self.v1Quote("q_000003", author: nil, kind: "affirmation")
        affirmation["text"] = "Bugün yavaş gitmek de ilerlemektir."
        let source = ContentFixture.source([ContentFiles.quotes: ContentFixture.quotes([
            Self.v1Quote("q_000001", author: "İnternette Dolaşan Biri"),
            Self.v1Quote("q_000002", author: "Seneca"),
            affirmation,
        ])])
        let catalog = try ContentLoader.load(from: source)
        #expect(catalog.quote("q_000001")?.active == false)
        #expect(catalog.unmatchedAuthors.map(\.quoteID) == ["q_000001"])
        #expect(catalog.unmatchedAuthors.first?.name == "İnternette Dolaşan Biri")
        #expect(catalog.quote("q_000002")?.active == true)
        #expect(catalog.quote("q_000003")?.active == true)
    }

    @Test("v2 dosyası: authorID, kaynak nesnesi, verified, paraphrase, tones ve düşünce yolu")
    func v2File() throws {
        let q: [String: Any] = [
            "id": "q_000010", "text": "Kendini kendine geri al.", "kind": "quote", "authorID": "th_seneca",
            "source": ["work": "Ahlak Mektupları", "locator": "Mektup 1, 1", "translation": "oneTranslation",
                       "verifiedBy": "PLACEHOLDER", "verifiedAt": "2026-09-24"],
            "license": "publicDomain", "verified": false, "paraphrase": true, "tones": ["sakin"],
            "themes": ["dinlenme"], "paths": ["stoacilar"], "reflectionPromptIDs": ["p_000001"],
            "premium": false, "active": true, "addedIn": 2, "lang": "tr",
        ]
        let source = ContentFixture.source([ContentFiles.quotes: ContentFixture.quotes([q]),
                                            ContentFiles.thinkers: ["items": [Self.seneca]]], schema: "2.0")
        let quote = try #require(try ContentLoader.load(from: source).quote("q_000010"))
        #expect(quote.authorID == "th_seneca" && quote.attribution == "Seneca")
        #expect(quote.sourceRef?.locator == "Mektup 1, 1" && quote.sourceRef?.translation == .oneTranslation)
        #expect(quote.sourceRef?.verifiedAt == "2026-09-24")
        #expect(!quote.verified && quote.paraphrase)
        #expect(quote.tones == ["sakin"] && quote.paths == ["stoacilar"])
        // Eski erişimler çalışmaya devam eder.
        #expect(quote.author == "Seneca" && quote.source == "Ahlak Mektupları")
    }

    @Test("v2 kodlama gidiş-dönüş; ad satırı ve v1 adı yazılmaz")
    func roundTrip() throws {
        let original = Quote(id: "q_1", text: "Aynı ırmakta iki kez yıkanılmaz.", kind: .quote, authorID: "th_herakleitos",
                             attribution: "Herakleitos",
                             sourceRef: SourceRef(work: "Fragmanlar", locator: "B91", translation: .oneTranslation),
                             license: .publicDomain, verified: true, paraphrase: true, tones: ["derin"],
                             themes: ["degisim"], paths: ["antik_yunan"])
        let data = try JSONEncoder().encode(original)
        let json = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect(json["attribution"] == nil && json["author"] == nil)
        #expect((json["source"] as? [String: Any])?["locator"] as? String == "B91")
        var decoded = try JSONDecoder().decode(Quote.self, from: data)
        decoded.attribution = "Herakleitos"
        #expect(decoded == original)
    }

    @Test("Ad eşleme tablosu: TR büyük/küçük harf ve aksan duyarsız")
    func nameTable() {
        #expect(ThinkerNames.id(for: "İBN SÎNÂ") == "th_ibn_sina")
        #expect(ThinkerNames.id(for: "ibn sina") == "th_ibn_sina")
        #expect(ThinkerNames.id(for: "  Marcus   Aurelius ") == "th_marcus_aurelius")
        #expect(ThinkerNames.id(for: "Mevlânâ") == "th_mevlana")
        #expect(ThinkerNames.id(for: "Albert Einstein") == nil)
        #expect(QuoteTone.fromV1Path("filozof") == .derin && QuoteTone.fromV1Path("stoacilar") == nil)
    }

    @Test("Telif durumu: ölüm + 70 < bu yıl kamu malı; yaşayan ya da bilinmeyen korumalı")
    func rights() {
        #expect(RightsStatus.of(deathYear: 65, currentYear: 2026) == .publicDomain)
        #expect(RightsStatus.of(deathYear: 1955, currentYear: 2026) == .publicDomain)
        #expect(RightsStatus.of(deathYear: 1956, currentYear: 2026) == .protected)
        #expect(RightsStatus.of(deathYear: nil, currentYear: 2026) == .protected)
        let t = Thinker(id: "th_x", displayName: "X", deathYear: 1990, currentYear: 2026)
        #expect(t.rights == .protected && t.shortName == "X")
    }
}

// MARK: - S2: ThinkerCatalog

struct ThinkerCatalogTests {

    private static func catalog() -> ContentCatalog {
        let manifest = ContentManifest(schemaVersion: "2.0", contentVersion: 1, generatedAt: "", files: [])
        let thinkers = [
            Thinker(id: "th_a", displayName: "Aa", pathIDs: ["stoacilar"]),
            Thinker(id: "th_b", displayName: "Bb", pathIDs: ["stoacilar"]),
            Thinker(id: "th_c", displayName: "Cc", pathIDs: ["stoacilar"]),
            Thinker(id: "th_d", displayName: "Dd", pathIDs: ["antik_yunan"]),
            Thinker(id: "th_e", displayName: "Ee", pathIDs: ["psikologlar"]),
            Thinker(id: "th_f", displayName: "Ff", pathIDs: ["stoacilar"], active: false),
        ]
        func q(_ id: String, _ author: String, _ themes: [String]) -> Quote {
            Quote(id: id, text: "Söz metni \(id) burada duruyor.", kind: .quote, authorID: author,
                  sourceRef: SourceRef(work: "Eser"), themes: themes)
        }
        let quotes = [
            q("q1", "th_a", ["kabul"]), q("q2", "th_a", ["kabul"]), q("q3", "th_a", ["sabir"]),
            q("q4", "th_b", ["merak"]),
            q("q5", "th_c", ["kabul"]), q("q6", "th_c", ["kabul"]),
            q("q7", "th_d", ["kabul"]),
            q("q8", "th_e", ["merak"]),
        ]
        return ContentCatalog(manifest: manifest, quotes: quotes, thinkers: thinkers)
    }

    @Test("similar: önce ortak yol, sonra tema yoğunluğu; kendisi ve pasif hariç; limit")
    func similarOrdering() {
        let c = Self.catalog()
        // C: aynı yol + aynı tema (kabul) > B: aynı yol, farklı tema > D: farklı yol, aynı tema > E: hiçbiri
        #expect(c.similar(to: "th_a", limit: 10).map(\.id) == ["th_c", "th_b", "th_d", "th_e"])
        #expect(c.similar(to: "th_a", limit: 2).map(\.id) == ["th_c", "th_b"])
        #expect(c.similar(to: "th_yok", limit: 3).isEmpty)
    }

    @Test("thinkers(in:): yoldaki aktif düşünürler, ada göre")
    func thinkersInPath() {
        let c = Self.catalog()
        #expect(c.thinkers(in: "stoacilar").map(\.id) == ["th_a", "th_b", "th_c"])
        #expect(c.thinkers(in: "varoluscular").isEmpty)
    }

    @Test("Bundle: 15 düşünür, sözler düşünüre bağlı, ad satırı displayName, yol düşünürden")
    func bundleThinkers() throws {
        let c = try ContentLoader.load(from: BundleContentSource(bundle: Bundle(for: PersistenceController.self)))
        #expect(c.thinkers.count == 15)
        #expect(c.unmatchedAuthors.isEmpty)
        let pathIDs = Set(c.paths.map(\.id))
        for t in c.thinkers {
            #expect(t.id.hasPrefix("th_") && !t.pathIDs.isEmpty && Set(t.pathIDs).isSubset(of: pathIDs), "\(t.id)")
        }
        for q in c.quotes where q.kind == .quote {
            let t = try #require(q.authorID.flatMap(c.thinker), "\(q.id)")
            #expect(q.attribution == t.displayName && q.paths == t.pathIDs, "\(q.id)")
        }
        #expect(c.thinker("th_marcus_aurelius")?.displayName == "Marcus Aurelius")
        #expect(c.similar(to: "th_seneca", limit: 2).allSatisfy { $0.pathIDs.contains("stoacilar") })
    }
}
