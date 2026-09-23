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
    static let supportedMajor = 1
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

nonisolated struct Quote: ContentItem, Hashable {
    let id: QuoteID
    let text: String
    let kind: QuoteKind
    let author: String?
    let source: String?
    let translation: QuoteTranslation?
    let license: ContentLicense
    let licenseNote: String?
    let themes: [String]
    let paths: [String]
    let emotionFit: [String]
    let moodFit: [Int]
    let timeOfDay: DayPart
    /// Doğrulayıcı hesaplar; dosyada yoksa metinden türetilir.
    let length: QuoteLength
    let reflectionPromptIDs: [String]?
    let premium: Bool
    let active: Bool
    let addedIn: Int
    let lang: String

    init(id: QuoteID, text: String, kind: QuoteKind, author: String? = nil, source: String? = nil,
         translation: QuoteTranslation? = nil, license: ContentLicense = .original, licenseNote: String? = nil,
         themes: [String] = [], paths: [String] = [], emotionFit: [String] = [], moodFit: [Int] = [],
         timeOfDay: DayPart = .any, length: QuoteLength? = nil, reflectionPromptIDs: [String]? = nil,
         premium: Bool = false, active: Bool = true, addedIn: Int = 1, lang: String = "tr") {
        self.id = id; self.text = text; self.kind = kind; self.author = author; self.source = source
        self.translation = translation; self.license = license; self.licenseNote = licenseNote
        self.themes = themes; self.paths = paths; self.emotionFit = emotionFit; self.moodFit = moodFit
        self.timeOfDay = timeOfDay; self.length = length ?? .of(text)
        self.reflectionPromptIDs = reflectionPromptIDs
        self.premium = premium; self.active = active; self.addedIn = addedIn; self.lang = lang
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let text = try c.decode(String.self, forKey: .text)
        self.init(
            id: try c.decode(String.self, forKey: .id),
            text: text,
            kind: try c.decode(QuoteKind.self, forKey: .kind),
            author: try c.decodeIfPresent(String.self, forKey: .author),
            source: try c.decodeIfPresent(String.self, forKey: .source),
            translation: try c.decodeIfPresent(QuoteTranslation.self, forKey: .translation),
            license: try c.decode(ContentLicense.self, forKey: .license),
            licenseNote: try c.decodeIfPresent(String.self, forKey: .licenseNote),
            themes: try c.decodeIfPresent([String].self, forKey: .themes) ?? [],
            paths: try c.decodeIfPresent([String].self, forKey: .paths) ?? [],
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
    }
}

/// Söz yolu: onboarding'de seçilen "ses" (`filozof`, `sakin`…).
nonisolated struct QuotePath: ContentItem, Hashable {
    let id: String
    let title: String
    let summary: String
    /// Bu yolda tür ağırlıkları (E2.3 yol uyumu); yoksa eşit.
    let kindWeights: [String: Double]?
    let premium: Bool
    let active: Bool
    let addedIn: Int
    let lang: String
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
    /// `emo_huzurlu`.
    let id: String
    let label: String
    /// Aile: `nese`, `huzur`, `sevgi`, `merak`, `huzun`, `kaygi`, `ofke`, `yorgunluk`.
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
