//
//  ContentSchema.swift
//  ONE 2.0
//
//  İçerik şeması v1 (04_arka_plan_motorlari.md › E1, E2.1). İçerik kullanıcı
//  verisi değil: bundle'da gelir, `one.forvibe.app/content/v1/`'den
//  güncellenir, kayıtlarda yalnız ID ile geçer (02_veri_modeli.md, ilke 5).
//
//  Kurallar:
//  - ID'ler kalıcıdır, asla yeniden kullanılmaz. Silinen öğe `active: false`
//    olur, dosyadan çıkmaz.
//  - Her öğede `active`, `premium`, `lang`, `addedIn` (contentVersion) var.
//  - Bilinmeyen alanlar yok sayılır: şema ileriye dönük genişler, `schemaVersion`
//    major'ı yalnız kıran değişiklikte artar.
//

import Foundation

// MARK: - Manifest

nonisolated enum ContentSchema {
    /// Uygulamanın okuyabildiği en büyük şema major'ı.
    static let supportedMajor = 2
}

nonisolated struct ContentManifest: Codable, Hashable, Sendable {
    /// `"1.0"`, `"1.3"`. Major uygulamanınkinden büyükse içerik yok sayılır.
    let schemaVersion: String
    /// Monoton artan içerik sürümü; öğelerin `addedIn` alanı buna bağlı.
    let contentVersion: Int
    let generatedAt: String
    let files: [File]

    nonisolated struct File: Codable, Hashable, Sendable {
        /// Manifest köküne göre yol: `quotes.tr.json`, `themes/2026-w40.tr.json`.
        let path: String
        /// Küçük harf onaltılık SHA-256.
        let sha256: String
        let bytes: Int?
    }

    var schemaMajor: Int? {
        schemaVersion.split(separator: ".").first.flatMap { Int($0) }
    }

    func file(_ path: String) -> File? { files.first { $0.path == path } }
}

/// Tüm katalog dosyalarının zarfı: `{ "items": [...] }`. `_note` gibi
/// ek alanlar yok sayılır.
nonisolated struct ContentFile<Item: Codable & Sendable>: Codable, Sendable {
    let items: [Item]
}

// MARK: - Ortak

nonisolated enum DayPart: String, Codable, Sendable, CaseIterable {
    case morning, day, evening, any

    /// Saat → gün dilimi: 05–11 sabah, 11–18 gün, diğerleri akşam.
    static func of(hour: Int) -> DayPart {
        switch hour {
        case 5..<11: return .morning
        case 11..<18: return .day
        default: return .evening
        }
    }

    func matches(_ current: DayPart) -> Bool {
        self == .any || current == .any || self == current
    }
}

/// Kataloglarda aranabilen her öğenin ortak alanları.
nonisolated protocol ContentItem: Codable, Sendable, Identifiable where ID == String {
    var id: String { get }
    var active: Bool { get }
    var premium: Bool { get }
    var lang: String { get }
    var addedIn: Int { get }
}

// MARK: - Sözler (E2.1)

typealias QuoteID = String

nonisolated enum QuoteKind: String, Codable, Sendable, CaseIterable {
    /// Kişiye ait söz; `author` + `source` + `license` zorunlu.
    case quote
    /// ONE'ın yazdığı olumlama.
    case affirmation
    /// Atasözü ya da deyim.
    case proverb
    /// ONE'ın düşünce cümlesi.
    case reflection
}

nonisolated enum QuoteTranslation: String, Codable, Sendable {
    case original, oneTranslation, publicDomainTranslation
}

nonisolated enum ContentLicense: String, Codable, Sendable {
    case publicDomain, original, licensed
}

nonisolated enum QuoteLength: String, Codable, Sendable, CaseIterable {
    case short, medium, long

    /// <60 kısa, 60–140 orta, >140 uzun (karakter).
    static func of(_ text: String) -> QuoteLength {
        switch text.count {
        case ..<60: return .short
        case ...140: return .medium
        default: return .long
        }
    }
}

/// Kaynak (08 §3.2). Kartta yazmaz; kaynak sheet'inde görünür.
nonisolated struct SourceRef: Codable, Hashable, Sendable {
    /// Eser, Türkçe yerleşik adıyla ("Ahlak Mektupları").
    var work: String
    /// Mektup/bölüm/paragraf/sayfa ("Mektup 1, 1"). v1 dosyalarında boş.
    var locator: String
    var translation: QuoteTranslation
    var translator: String?
    var verifiedBy: String?
    /// `yyyy-MM-dd`.
    var verifiedAt: String?

    init(work: String, locator: String = "", translation: QuoteTranslation = .original,
         translator: String? = nil, verifiedBy: String? = nil, verifiedAt: String? = nil) {
        self.work = work; self.locator = locator; self.translation = translation
        self.translator = translator; self.verifiedBy = verifiedBy; self.verifiedAt = verifiedAt
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(work: try c.decode(String.self, forKey: .work),
                  locator: try c.decodeIfPresent(String.self, forKey: .locator) ?? "",
                  translation: try c.decodeIfPresent(QuoteTranslation.self, forKey: .translation) ?? .original,
                  translator: try c.decodeIfPresent(String.self, forKey: .translator),
                  verifiedBy: try c.decodeIfPresent(String.self, forKey: .verifiedBy),
                  verifiedAt: try c.decodeIfPresent(String.self, forKey: .verifiedAt))
    }
}

/// Söz tonu (08 §3.2): eski "ses" yolları buraya taşındı.
nonisolated enum QuoteTone: String, Codable, Sendable, CaseIterable {
    case sakin, cesur, sefkatli, uretken, derin

    /// v1 yol ID'si → ton (`filozof` → `derin`).
    static func fromV1Path(_ id: String) -> QuoteTone? {
        id == "filozof" ? .derin : QuoteTone(rawValue: id)
    }
}

nonisolated struct Quote: ContentItem, Hashable {
    let id: QuoteID
    let text: String
    let kind: QuoteKind
    /// Düşünür (08 §3.2); `quote` için zorunlu.
    var authorID: ThinkerID?
    /// Kartın ad satırı: düşünürün `displayName`'i (UX başına "— " ekler).
    /// Katalog doldurur; düşünür bilinmiyorsa v1 ad metni.
    var attribution: String?
    var sourceRef: SourceRef?
    let license: ContentLicense
    let licenseNote: String?
    /// `false` ise yayın yok (akışa girmez).
    let verified: Bool
    /// Eserdeki cümlenin kısaltılmış/yaygın biçimi: kaynak sheet'inde "uyarlama".
    let paraphrase: Bool
    let tones: [String]
    let themes: [String]
    /// Düşünce yolları (08 §3.3); boşsa düşünürün `pathIDs`'i.
    var paths: [String]
    let emotionFit: [String]
    let moodFit: [Int]
    let timeOfDay: DayPart
    /// Doğrulayıcı hesaplar; dosyada yoksa metinden türetilir.
    let length: QuoteLength
    let reflectionPromptIDs: [String]?
    let premium: Bool
    var active: Bool
    let addedIn: Int
    let lang: String
    /// v1 dosyasındaki serbest `author` metni; katalog `authorID`'ye eşler.
    /// Kodlanmaz.
    var legacyAuthorName: String?

    // MARK: Eski (v1) erişimler — mevcut çağıranlar için

    /// Görünen ad (v1'deki `author`).
    var author: String? { attribution }
    /// Eser adı (v1'deki `source`).
    var source: String? { sourceRef?.work }
    var translation: QuoteTranslation? { sourceRef?.translation }

    init(id: QuoteID, text: String, kind: QuoteKind,
         authorID: ThinkerID? = nil, attribution: String? = nil, sourceRef: SourceRef? = nil,
         license: ContentLicense = .original, licenseNote: String? = nil,
         verified: Bool = true, paraphrase: Bool = false, tones: [String] = [],
         themes: [String] = [], paths: [String] = [], emotionFit: [String] = [], moodFit: [Int] = [],
         timeOfDay: DayPart = .any, length: QuoteLength? = nil, reflectionPromptIDs: [String]? = nil,
         premium: Bool = false, active: Bool = true, addedIn: Int = 1, lang: String = "tr") {
        self.id = id; self.text = text; self.kind = kind
        self.authorID = authorID; self.attribution = attribution; self.sourceRef = sourceRef
        self.license = license; self.licenseNote = licenseNote
        self.verified = verified; self.paraphrase = paraphrase; self.tones = tones
        self.themes = themes; self.paths = paths; self.emotionFit = emotionFit; self.moodFit = moodFit
        self.timeOfDay = timeOfDay; self.length = length ?? .of(text)
        self.reflectionPromptIDs = reflectionPromptIDs
        self.premium = premium; self.active = active; self.addedIn = addedIn; self.lang = lang
    }

    /// v1 biçimli kurucu (ad metni + eser adı). Ad eşleme tablosunda varsa o
    /// düşünüre, yoksa addan türetilen kararlı bir ID'ye bağlanır.
    init(id: QuoteID, text: String, kind: QuoteKind, author: String?, source: String? = nil,
         translation: QuoteTranslation? = nil, license: ContentLicense = .original, licenseNote: String? = nil,
         themes: [String] = [], paths: [String] = [], emotionFit: [String] = [], moodFit: [Int] = [],
         timeOfDay: DayPart = .any, length: QuoteLength? = nil, reflectionPromptIDs: [String]? = nil,
         premium: Bool = false, active: Bool = true, addedIn: Int = 1, lang: String = "tr") {
        self.init(id: id, text: text, kind: kind,
                  authorID: author.map { ThinkerNames.id(for: $0) ?? ThinkerNames.syntheticID(for: $0) },
                  attribution: author,
                  sourceRef: source.map { SourceRef(work: $0, translation: translation ?? .original) },
                  license: license, licenseNote: licenseNote, themes: themes, paths: paths,
                  emotionFit: emotionFit, moodFit: moodFit, timeOfDay: timeOfDay, length: length,
                  reflectionPromptIDs: reflectionPromptIDs, premium: premium, active: active,
                  addedIn: addedIn, lang: lang)
    }

    private enum CodingKeys: String, CodingKey {
        case id, text, kind, authorID, author, source, translation, license, licenseNote, verified, paraphrase
        case tones, themes, paths, emotionFit, moodFit, timeOfDay, length, reflectionPromptIDs
        case premium, active, addedIn, lang
    }

    /// v1 ve v2'yi okur (08 §3.2): v1 `author` metni → `legacyAuthorName`,
    /// v1 `source` metni + üst düzey `translation` → `SourceRef`, v1 ses
    /// yolları (`tones` yokken `paths` içindekiler) → `tones`.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let text = try c.decode(String.self, forKey: .text)
        let kind = try c.decode(QuoteKind.self, forKey: .kind)
        let sourceRef: SourceRef?
        if let object = try? c.decodeIfPresent(SourceRef.self, forKey: .source) {
            sourceRef = object
        } else if let work = try? c.decodeIfPresent(String.self, forKey: .source) {
            sourceRef = SourceRef(work: work,
                                  translation: try c.decodeIfPresent(QuoteTranslation.self, forKey: .translation) ?? .original)
        } else {
            sourceRef = nil
        }
        var paths = try c.decodeIfPresent([String].self, forKey: .paths) ?? []
        var tones = try c.decodeIfPresent([String].self, forKey: .tones)
        if tones == nil {
            tones = paths.compactMap { QuoteTone.fromV1Path($0)?.rawValue }
            paths.removeAll { QuoteTone.fromV1Path($0) != nil }
        }
        self.init(
            id: try c.decode(String.self, forKey: .id),
            text: text, kind: kind,
            authorID: try c.decodeIfPresent(String.self, forKey: .authorID),
            sourceRef: sourceRef,
            license: try c.decode(ContentLicense.self, forKey: .license),
            licenseNote: try c.decodeIfPresent(String.self, forKey: .licenseNote),
            // v1'de alan yok: v1 doğrulayıcısı `quote` için kaynağı zaten şart koşuyordu.
            verified: try c.decodeIfPresent(Bool.self, forKey: .verified) ?? (kind != .quote || sourceRef != nil),
            paraphrase: try c.decodeIfPresent(Bool.self, forKey: .paraphrase) ?? false,
            tones: tones ?? [],
            themes: try c.decodeIfPresent([String].self, forKey: .themes) ?? [],
            paths: paths,
            emotionFit: try c.decodeIfPresent([String].self, forKey: .emotionFit) ?? [],
            moodFit: try c.decodeIfPresent([Int].self, forKey: .moodFit) ?? [],
            timeOfDay: try c.decodeIfPresent(DayPart.self, forKey: .timeOfDay) ?? .any,
            length: try c.decodeIfPresent(QuoteLength.self, forKey: .length),
            reflectionPromptIDs: try c.decodeIfPresent([String].self, forKey: .reflectionPromptIDs),
            premium: try c.decodeIfPresent(Bool.self, forKey: .premium) ?? false,
            active: try c.decodeIfPresent(Bool.self, forKey: .active) ?? true,
            addedIn: try c.decodeIfPresent(Int.self, forKey: .addedIn) ?? 1,
            lang: try c.decodeIfPresent(String.self, forKey: .lang) ?? "tr"
        )
        if authorID == nil { legacyAuthorName = try c.decodeIfPresent(String.self, forKey: .author) }
    }

    /// Her zaman v2 biçiminde yazar (`attribution` ve `legacyAuthorName` yazılmaz).
    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id); try c.encode(text, forKey: .text); try c.encode(kind, forKey: .kind)
        try c.encodeIfPresent(authorID, forKey: .authorID)
        try c.encodeIfPresent(sourceRef, forKey: .source)
        try c.encode(license, forKey: .license); try c.encodeIfPresent(licenseNote, forKey: .licenseNote)
        try c.encode(verified, forKey: .verified); try c.encode(paraphrase, forKey: .paraphrase)
        try c.encode(tones, forKey: .tones); try c.encode(themes, forKey: .themes); try c.encode(paths, forKey: .paths)
        try c.encode(emotionFit, forKey: .emotionFit); try c.encode(moodFit, forKey: .moodFit)
        try c.encode(timeOfDay, forKey: .timeOfDay); try c.encode(length, forKey: .length)
        try c.encodeIfPresent(reflectionPromptIDs, forKey: .reflectionPromptIDs)
        try c.encode(premium, forKey: .premium); try c.encode(active, forKey: .active)
        try c.encode(addedIn, forKey: .addedIn); try c.encode(lang, forKey: .lang)
    }
}

/// Düşünce yolu (08 §3.3). v1'deki "ses" yolları `QuoteTone`'a taşındı.
nonisolated struct QuotePath: ContentItem, Hashable {
    let id: String
    let title: String
    let summary: String
    /// v1 alanı; v2 yollarında yok.
    let kindWeights: [String: Double]?
    let premium: Bool
    let active: Bool
    let addedIn: Int
    let lang: String

    /// Onboarding'de yol seçilmediyse ücretsiz yol.
    static let defaultFreeID = "stoacilar"
}

// MARK: - Düşünürler (08 §3.1)

typealias ThinkerID = String
typealias PathID = String

nonisolated enum ThinkerKind: String, Codable, Sendable, CaseIterable {
    case philosopher, psychologist, thinker, mystic, writer
}

nonisolated enum RightsStatus: String, Codable, Sendable {
    case publicDomain, protected

    /// 08 §5: ölüm yılı + 70 < bu yıl → kamu malı; yaşayan ya da yılı
    /// bilinmeyen → korumalı. Hukuki görüş değildir.
    static func of(deathYear: Int?, currentYear: Int) -> RightsStatus {
        guard let deathYear else { return .protected }
        return deathYear + 70 < currentYear ? .publicDomain : .protected
    }
}

nonisolated struct Thinker: ContentItem, Hashable {
    let id: ThinkerID
    let displayName: String
    let shortName: String
    let aliases: [String]
    let kind: ThinkerKind
    /// MÖ için negatif.
    let birthYear: Int?
    let deathYear: Int?
    let eraDisplay: String
    let pathIDs: [PathID]
    let coreIdea: String
    let bioShort: String
    let portraitAsset: String?
    let rights: RightsStatus
    let premium: Bool
    let active: Bool
    let addedIn: Int
    let lang: String

    init(id: ThinkerID, displayName: String, shortName: String? = nil, aliases: [String] = [],
         kind: ThinkerKind = .philosopher, birthYear: Int? = nil, deathYear: Int? = nil, eraDisplay: String = "",
         pathIDs: [PathID] = [], coreIdea: String = "", bioShort: String = "", portraitAsset: String? = nil,
         rights: RightsStatus? = nil, premium: Bool = false, active: Bool = true, addedIn: Int = 1,
         lang: String = "tr", currentYear: Int = Thinker.currentYear) {
        self.id = id; self.displayName = displayName; self.shortName = shortName ?? displayName
        self.aliases = aliases; self.kind = kind; self.birthYear = birthYear; self.deathYear = deathYear
        self.eraDisplay = eraDisplay; self.pathIDs = pathIDs; self.coreIdea = coreIdea; self.bioShort = bioShort
        self.portraitAsset = portraitAsset
        self.rights = rights ?? .of(deathYear: deathYear, currentYear: currentYear)
        self.premium = premium; self.active = active; self.addedIn = addedIn; self.lang = lang
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let name = try c.decode(String.self, forKey: .displayName)
        self.init(
            id: try c.decode(String.self, forKey: .id), displayName: name,
            shortName: try c.decodeIfPresent(String.self, forKey: .shortName),
            aliases: try c.decodeIfPresent([String].self, forKey: .aliases) ?? [],
            kind: try c.decodeIfPresent(ThinkerKind.self, forKey: .kind) ?? .thinker,
            birthYear: try c.decodeIfPresent(Int.self, forKey: .birthYear),
            deathYear: try c.decodeIfPresent(Int.self, forKey: .deathYear),
            eraDisplay: try c.decodeIfPresent(String.self, forKey: .eraDisplay) ?? "",
            pathIDs: try c.decodeIfPresent([String].self, forKey: .pathIDs) ?? [],
            coreIdea: try c.decodeIfPresent(String.self, forKey: .coreIdea) ?? "",
            bioShort: try c.decodeIfPresent(String.self, forKey: .bioShort) ?? "",
            portraitAsset: try c.decodeIfPresent(String.self, forKey: .portraitAsset),
            rights: try c.decodeIfPresent(RightsStatus.self, forKey: .rights),
            premium: try c.decodeIfPresent(Bool.self, forKey: .premium) ?? false,
            active: try c.decodeIfPresent(Bool.self, forKey: .active) ?? true,
            addedIn: try c.decodeIfPresent(Int.self, forKey: .addedIn) ?? 1,
            lang: try c.decodeIfPresent(String.self, forKey: .lang) ?? "tr"
        )
    }

    static var currentYear: Int { Calendar(identifier: .gregorian).component(.year, from: Date()) }
}

/// v1 ad metni → düşünür ID'si (08 §3.2 eşleme tablosu). Başlangıç listesi
/// (08 §3.4) ve yaygın yazımlar; katalogdaki `displayName` ve `aliases` de
/// eşlemede kullanılır (`ContentCatalog`). Karşılaştırma TR küçük harf +
/// aksansız: "İbn Sînâ" = "ibn sina". Tablo bu normalize biçimde yazılı.
nonisolated enum ThinkerNames {
    static let table: [String: ThinkerID] = {
        let rows: [(ThinkerID, [String])] = [
            ("th_seneca", ["seneca", "lucius annaeus seneca"]),
            ("th_epiktetos", ["epiktetos", "epictetus", "epiktet"]),
            ("th_marcus_aurelius", ["marcus aurelius", "markus aurelius", "marcus aurelius antoninus"]),
            ("th_zenon", ["zenon", "kitionlu zenon", "zeno"]),
            ("th_musonius_rufus", ["musonius rufus"]),
            ("th_platon", ["platon", "eflatun", "plato"]),
            ("th_sokrates", ["sokrates", "sokrat", "socrates"]),
            ("th_aristoteles", ["aristoteles", "aristo", "aristotle"]),
            ("th_epikuros", ["epikuros", "epikur", "epicurus"]),
            ("th_herakleitos", ["herakleitos", "heraklitos", "heraclitus"]),
            ("th_diogenes", ["diogenes", "sinoplu diogenes"]),
            ("th_kierkegaard", ["kierkegaard", "soren kierkegaard", "soren kierkegaard"]),
            ("th_nietzsche", ["nietzsche", "friedrich nietzsche"]),
            ("th_dostoyevski", ["dostoyevski", "fyodor dostoyevski", "dostoevsky"]),
            ("th_camus", ["camus", "albert camus"]),
            ("th_sartre", ["sartre", "jean-paul sartre"]),
            ("th_beauvoir", ["simone de beauvoir", "beauvoir"]),
            ("th_lao_tzu", ["lao tzu", "lao tse", "laozi"]),
            ("th_konfucyus", ["konfucyus", "konfucyus", "confucius"]),
            ("th_buda", ["buda", "buddha"]),
            ("th_zhuangzi", ["zhuangzi", "chuang tzu"]),
            ("th_tagore", ["tagore", "rabindranath tagore"]),
            ("th_mevlana", ["mevlana", "mevlana", "rumi", "celaleddin rumi"]),
            ("th_yunus_emre", ["yunus emre"]),
            ("th_farabi", ["farabi", "farabi", "al-farabi"]),
            ("th_ibn_sina", ["ibn sina", "ibn sina", "avicenna"]),
            ("th_gazali", ["gazali", "gazali", "al-ghazali"]),
            ("th_ibn_arabi", ["ibn arabi", "ibnu'l-arabi", "ibn arabi"]),
            ("th_ibn_haldun", ["ibn haldun", "ibn khaldun"]),
            ("th_haci_bektas_veli", ["haci bektas veli", "haci bektas-i veli"]),
            ("th_sems_i_tebrizi", ["sems-i tebrizi", "sems", "shams tabrizi"]),
            ("th_william_james", ["william james"]),
            ("th_freud", ["freud", "sigmund freud"]),
            ("th_adler", ["adler", "alfred adler"]),
            ("th_horney", ["karen horney", "horney"]),
            ("th_jung", ["jung", "carl jung", "carl gustav jung"]),
            ("th_frankl", ["viktor frankl", "frankl"]),
            ("th_fromm", ["erich fromm", "fromm"]),
            ("th_rogers", ["carl rogers"]),
            ("th_maslow", ["abraham maslow", "maslow"]),
            ("th_rollo_may", ["rollo may"]),
            ("th_montaigne", ["montaigne", "michel de montaigne"]),
            ("th_pascal", ["pascal", "blaise pascal"]),
            ("th_spinoza", ["spinoza", "baruch spinoza"]),
            ("th_kant", ["kant", "immanuel kant"]),
            ("th_schopenhauer", ["schopenhauer", "arthur schopenhauer"]),
            ("th_goethe", ["goethe", "johann wolfgang von goethe"]),
            ("th_emerson", ["emerson", "ralph waldo emerson"]),
            ("th_thoreau", ["thoreau", "henry david thoreau"]),
            ("th_simone_weil", ["simone weil"]),
            ("th_wittgenstein", ["wittgenstein", "ludwig wittgenstein"]),
            ("th_russell", ["bertrand russell", "russell"]),
        ]
        var map: [String: ThinkerID] = [:]
        for (id, names) in rows { for name in names { map[key(name)] = id } }
        return map
    }()

    static func id(for name: String) -> ThinkerID? { table[key(name)] }

    /// Tablo dışı ad için kararlı ID (yalnız kod içi v1 kurucusu; dosyadan
    /// gelen eşleşmeyen ad pasifleşir).
    static func syntheticID(for name: String) -> ThinkerID {
        "th_" + key(name).map { $0.isLetter || $0.isNumber ? String($0) : "_" }.joined()
    }

    /// TR küçük harf, aksansız, tek boşluk.
    static func key(_ name: String) -> String {
        SearchText.folded(name).split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }
}

// MARK: - Sorular (E4)

typealias PromptID = String

nonisolated enum PromptPool: String, Codable, Sendable, CaseIterable {
    /// Serbest günlük sorusu ("Günlük önerisi", boş sayfa).
    case free
    /// Söze yazı sorusu; `quoteIDs` boşsa genel havuz.
    case reflection
    /// Check-in sonrası tek isteğe bağlı soru.
    case checkinFollowUp
    case morning
    case evening
}

nonisolated struct Prompt: ContentItem, Hashable {
    let id: PromptID
    let text: String
    let pool: PromptPool
    let themes: [String]
    let timeOfDay: DayPart
    let moodFit: [Int]
    let emotionFit: [String]
    /// Yalnız bu sözlere özel soru (`reflection`).
    let quoteIDs: [String]
    /// Ritüel şablonunun sabit çekirdeği (`morning` / `evening`).
    let isCore: Bool
    let premium: Bool
    let active: Bool
    let addedIn: Int
    let lang: String

    init(id: PromptID, text: String, pool: PromptPool, themes: [String] = [], timeOfDay: DayPart = .any,
         moodFit: [Int] = [], emotionFit: [String] = [], quoteIDs: [String] = [], isCore: Bool = false,
         premium: Bool = false, active: Bool = true, addedIn: Int = 1, lang: String = "tr") {
        self.id = id; self.text = text; self.pool = pool; self.themes = themes; self.timeOfDay = timeOfDay
        self.moodFit = moodFit; self.emotionFit = emotionFit; self.quoteIDs = quoteIDs; self.isCore = isCore
        self.premium = premium; self.active = active; self.addedIn = addedIn; self.lang = lang
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            id: try c.decode(String.self, forKey: .id),
            text: try c.decode(String.self, forKey: .text),
            pool: try c.decode(PromptPool.self, forKey: .pool),
            themes: try c.decodeIfPresent([String].self, forKey: .themes) ?? [],
            timeOfDay: try c.decodeIfPresent(DayPart.self, forKey: .timeOfDay) ?? .any,
            moodFit: try c.decodeIfPresent([Int].self, forKey: .moodFit) ?? [],
            emotionFit: try c.decodeIfPresent([String].self, forKey: .emotionFit) ?? [],
            quoteIDs: try c.decodeIfPresent([String].self, forKey: .quoteIDs) ?? [],
            isCore: try c.decodeIfPresent(Bool.self, forKey: .isCore) ?? false,
            premium: try c.decodeIfPresent(Bool.self, forKey: .premium) ?? false,
            active: try c.decodeIfPresent(Bool.self, forKey: .active) ?? true,
            addedIn: try c.decodeIfPresent(Int.self, forKey: .addedIn) ?? 1,
            lang: try c.decodeIfPresent(String.self, forKey: .lang) ?? "tr"
        )
    }
}

// MARK: - Haftalık tema (E5)

nonisolated struct WeeklyTheme: ContentItem, Hashable {
    /// `t_2026w40`; evergreen temalarda `t_ev_…`.
    let id: String
    /// ISO hafta: `2026-W40`. Evergreen temalarda yok.
    let week: String?
    let title: String
    let summary: String
    /// Söz ve soru eşlemesi için tema sözlüğü etiketleri.
    let tags: [String]
    /// 7 gün, pazartesi = 1.
    let days: [Day]
    let premium: Bool
    let active: Bool
    let addedIn: Int
    let lang: String

    nonisolated struct Day: Codable, Hashable, Sendable {
        /// 1 (pazartesi) – 7 (pazar).
        let day: Int
        let prompt: String
    }

    func prompt(forWeekday index: Int) -> String? {
        days.first { $0.day == index }?.prompt
    }
}

// MARK: - Rehberli günlük

nonisolated struct GuidedJournal: ContentItem, Hashable {
    let id: String
    let title: String
    let summary: String
    let durationMinutes: Int?
    let tags: [String]
    let timeOfDay: DayPart
    let steps: [Step]
    let premium: Bool
    let active: Bool
    let addedIn: Int
    let lang: String

    nonisolated struct Step: Codable, Hashable, Sendable {
        let id: String
        let kind: AnswerKind
        let prompt: String
        let choices: [String]?
    }
}

// MARK: - Yankı (E6)

nonisolated enum MoodTrend: String, Codable, Sendable {
    case up, down, flat
}

nonisolated struct Echo: ContentItem, Hashable {
    let id: String
    let text: String
    let conditions: Conditions
    let weight: Double
    let premium: Bool
    let active: Bool
    let addedIn: Int
    let lang: String

    nonisolated struct Conditions: Codable, Hashable, Sendable {
        var scoreIn: [Int]?
        var emotionFamilyAny: [String]?
        var causeAny: [String]?
        var timeOfDay: DayPart?
        var trend: MoodTrend?
        var firstCheckin: Bool?

        /// Hiç koşul yoksa genel havuz.
        var isGeneral: Bool {
            scoreIn == nil && emotionFamilyAny == nil && causeAny == nil
                && timeOfDay == nil && trend == nil && firstCheckin == nil
        }
    }
}

// MARK: - Kataloglar

nonisolated struct EmotionDefinition: ContentItem, Hashable {
    /// `<aile>.<ad>`: `huzur.sakin` (UX_istekleri.md §1; ID kalıcı).
    let id: String
    let label: String
    /// Aile (tokens.json `emo-*`): `nese`, `huzur`, `enerji`, `sevgi`, `kaygi`, `huzun`, `ofke`, `yorgun`.
    let family: String
    let premium: Bool
    let active: Bool
    let addedIn: Int
    let lang: String
}

nonisolated struct CauseDefinition: ContentItem, Hashable {
    /// `c_uyku`.
    let id: String
    let label: String
    /// SF Symbol adı.
    let icon: String?
    let premium: Bool
    let active: Bool
    let addedIn: Int
    let lang: String
}

/// Rozet kuralı (E9): kod yalnız kural tiplerini bilir, eşikler katalogda.
nonisolated enum BadgeRule: Codable, Hashable, Sendable {
    case streak(Int)
    case entries(kind: EntryKind?, count: Int)
    case words(Int)
    case themeComplete(Int)
    case bothRituals(Int)
    case comparison(Int)
    case firstOf(EntryKind)

    private enum CodingKeys: String, CodingKey { case type, n, kind }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let type = try c.decode(String.self, forKey: .type)
        func n() throws -> Int { try c.decode(Int.self, forKey: .n) }
        switch type {
        case "streak": self = .streak(try n())
        case "entries": self = .entries(kind: try c.decodeIfPresent(EntryKind.self, forKey: .kind), count: try n())
        case "words": self = .words(try n())
        case "themeComplete": self = .themeComplete(try n())
        case "bothRituals": self = .bothRituals(try n())
        case "comparison": self = .comparison(try n())
        case "firstOf": self = .firstOf(try c.decode(EntryKind.self, forKey: .kind))
        default:
            throw DecodingError.dataCorruptedError(forKey: .type, in: c, debugDescription: "Unknown badge rule: \(type)")
        }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .streak(let n): try c.encode("streak", forKey: .type); try c.encode(n, forKey: .n)
        case .entries(let kind, let n):
            try c.encode("entries", forKey: .type); try c.encodeIfPresent(kind, forKey: .kind); try c.encode(n, forKey: .n)
        case .words(let n): try c.encode("words", forKey: .type); try c.encode(n, forKey: .n)
        case .themeComplete(let n): try c.encode("themeComplete", forKey: .type); try c.encode(n, forKey: .n)
        case .bothRituals(let n): try c.encode("bothRituals", forKey: .type); try c.encode(n, forKey: .n)
        case .comparison(let n): try c.encode("comparison", forKey: .type); try c.encode(n, forKey: .n)
        case .firstOf(let kind): try c.encode("firstOf", forKey: .type); try c.encode(kind, forKey: .kind)
        }
    }
}

nonisolated struct BadgeDefinition: ContentItem, Hashable {
    /// `b_streak_7`.
    let id: String
    let title: String
    let summary: String
    let rule: BadgeRule
    let premium: Bool
    let active: Bool
    let addedIn: Int
    let lang: String
}
