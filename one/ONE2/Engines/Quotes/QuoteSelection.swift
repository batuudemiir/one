//
//  QuoteSelection.swift
//  ONE 2.0
//
//  Söz motorunun saf çekirdeği (04_arka_plan_motorlari.md › E2.2, E2.3).
//  Girdi: katalog + maruz kalma geçmişi + bağlam + tohum → sıralı söz listesi.
//  Core Data, UserDefaults ve UI yok; `QuoteEngine` bunu besler.
//

import Foundation

/// Akış modu (E2.5).
nonisolated enum QuoteFeedMode: Hashable, Sendable {
    case forYou
    case path(String)
    case theme(String)
    case kind(QuoteKind)
    case favorites
    case written

    /// Kalıcı kuyruk ve tohum anahtarı.
    var key: String {
        switch self {
        case .forYou: return "forYou"
        case .path(let id): return "path:\(id)"
        case .theme(let id): return "theme:\(id)"
        case .kind(let kind): return "kind:\(kind.rawValue)"
        case .favorites: return "favorites"
        case .written: return "written"
        }
    }

    /// Favoriler ve yazılanlar kendi listeleri; akış kuralları uygulanmaz (E2.2 kural 5).
    var isList: Bool { self == .favorites || self == .written }
}

/// Puan bileşenlerinin ağırlıkları (E2.3 tablo); `quotes` yapılandırmasıyla değişebilir.
nonisolated struct QuoteWeights: Hashable, Sendable {
    var path = 0.30
    var theme = 0.15
    var timeOfDay = 0.10
    var mood = 0.20
    var interest = 0.15
    var random = 0.10

    static let `default` = QuoteWeights()
}

/// Seçim anındaki kullanıcı bağlamı.
nonisolated struct QuoteContext: Sendable {
    var quotePaths: [String] = []
    var lang = "tr"
    var hasPremium = false
    /// Bu haftanın tema etiketleri (E5).
    var weekThemeTags: Set<String> = []
    /// Bu haftanın teması; değişince kalıcı kuyruk yeniden kurulur.
    var weekThemeID: String?
    var dayPart: DayPart = .any
    /// Son check-in skoru (1–5).
    var moodScore: Int?
    var now: Date
    var weights: QuoteWeights = .default
}

/// Beğenilen ve yazılan sözlerden türetilen ilgi (son 90 gün).
nonisolated struct QuoteInterest: Sendable {
    var themeWeights: [String: Double] = [:]
    var kindWeights: [QuoteKind: Double] = [:]

    static func from(_ exposure: ExposureSnapshot, catalog: ContentCatalog, now: Date,
                     window: TimeInterval = 90 * 86_400) -> QuoteInterest {
        var themes: [String: Double] = [:]
        var kinds: [QuoteKind: Double] = [:]
        let since = now.addingTimeInterval(-window)
        for record in exposure.records.values {
            let liked = record.liked && (record.likedAt ?? .distantPast) >= since
            let written = (record.lastWrittenAt ?? .distantPast) >= since
            guard liked || written, let quote = catalog.quote(record.contentID) else { continue }
            let w = (liked ? 1.0 : 0) + (written ? 2.0 : 0)
            for t in quote.themes { themes[t, default: 0] += w }
            kinds[quote.kind, default: 0] += w
        }
        let tMax = themes.values.max() ?? 1, kTotal = kinds.values.reduce(0, +)
        return QuoteInterest(themeWeights: themes.mapValues { $0 / tMax },
                             kindWeights: kTotal > 0 ? kinds.mapValues { $0 / kTotal } : [:])
    }

    var isEmpty: Bool { themeWeights.isEmpty && kindWeights.isEmpty }
}

nonisolated enum QuoteSelection {

    /// E2.2 kural 3: döngü 2'ye girebilmek için son görülmeden bu kadar geçmeli.
    static let cycleTwoMinimumAge: TimeInterval = 60 * 86_400
    /// Düşük skorda öne çıkan yumuşak temalar.
    static let softThemes: Set<String> = ["ozsefkat", "kabul", "dinlenme", "umut", "yavaslik"]

    // MARK: - Aday havuzu

    /// Moda açık mı? Ücretsiz: Sana özel + ilk yol (04 › karar 4).
    static func isAccessible(_ mode: QuoteFeedMode, context: QuoteContext) -> Bool {
        if context.hasPremium { return true }
        switch mode {
        case .forYou, .favorites, .written: return true
        case .path(let id): return id == context.quotePaths.first
        case .theme, .kind: return false
        }
    }

    /// `active` ∧ `lang` ∧ (premium ise yetki) ∧ moda uygun. Görülme filtresi yok.
    static func eligible(_ quotes: [Quote], mode: QuoteFeedMode, context: QuoteContext) -> [Quote] {
        guard isAccessible(mode, context: context) else { return [] }
        return quotes.filter { q in
            guard q.active, q.lang == context.lang, context.hasPremium || !q.premium else { return false }
            switch mode {
            case .forYou, .favorites, .written: return true
            case .path(let id): return q.paths.contains(id)
            case .theme(let id): return q.themes.contains(id)
            case .kind(let kind): return q.kind == kind
            }
        }
    }

    /// Akışa girebilecek adaylar ve hangi döngüde olunduğu.
    /// - Döngü 1: görülmemişler (bu oturumda gösterilenler de hariç).
    /// - Döngü 2: görülmemiş kalmadıysa, son 60 günde görülmemişler; en uzun
    ///   süredir görülmeyen önce. Onlar da yoksa boş: "Tümünü gördün".
    static func candidates(_ eligible: [Quote], exposure: ExposureSnapshot, excluding: Set<QuoteID>,
                           now: Date) -> (quotes: [Quote], cycle: Int) {
        let pool = eligible.filter { !excluding.contains($0.id) }
        let unseen = pool.filter { exposure[$0.id]?.wasSeen != true }
        if !unseen.isEmpty { return (unseen, 1) }
        let cutoff = now.addingTimeInterval(-cycleTwoMinimumAge)
        let old = pool
            .filter { (exposure[$0.id]?.lastSeenAt ?? .distantPast) <= cutoff }
            .sorted { (exposure[$0.id]?.lastSeenAt ?? .distantPast, $0.id) < (exposure[$1.id]?.lastSeenAt ?? .distantPast, $1.id) }
        return (old, 2)
    }

    // MARK: - Puan

    static func score(_ q: Quote, context: QuoteContext, interest: QuoteInterest, catalog: ContentCatalog,
                      rng: inout SeededRandom) -> Double {
        let w = context.weights
        return w.path * pathScore(q, context: context, catalog: catalog)
            + w.theme * (context.weekThemeTags.isDisjoint(with: q.themes) ? 0 : 1)
            + w.timeOfDay * timeScore(q, context.dayPart)
            + w.mood * moodScore(q, context.moodScore)
            + w.interest * interestScore(q, interest)
            + w.random * rng.unit()
    }

    static func pathScore(_ q: Quote, context: QuoteContext, catalog: ContentCatalog) -> Double {
        guard !context.quotePaths.isEmpty else { return 0.5 }
        let shared = context.quotePaths.filter(q.paths.contains)
        guard !shared.isEmpty else { return 0 }
        let kindWeights = shared.compactMap { id in catalog.paths.first { $0.id == id }?.kindWeights?[q.kind.rawValue] }
        let kindFit = kindWeights.isEmpty ? 0.5 : kindWeights.reduce(0, +) / Double(kindWeights.count)
        return 0.7 + 0.3 * min(1, kindFit * 2)
    }

    static func timeScore(_ q: Quote, _ part: DayPart) -> Double {
        if q.timeOfDay == .any || part == .any { return 0.5 }
        return q.timeOfDay == part ? 1 : 0
    }

    /// Skor ≤ 2 iken olumlama ve yumuşak temalar öne çıkar.
    static func moodScore(_ q: Quote, _ score: Int?) -> Double {
        guard let score else { return 0.5 }
        if score <= 2 {
            if q.kind == .affirmation { return 1 }
            if !softThemes.isDisjoint(with: q.themes) { return q.moodFit.isEmpty || q.moodFit.contains(score) ? 1 : 0.7 }
        }
        if q.moodFit.isEmpty { return 0.5 }
        return q.moodFit.contains(score) ? 1 : 0
    }

    static func interestScore(_ q: Quote, _ interest: QuoteInterest) -> Double {
        guard !interest.isEmpty else { return 0.5 }
        let theme = q.themes.map { interest.themeWeights[$0] ?? 0 }.max() ?? 0
        return 0.7 * theme + 0.3 * (interest.kindWeights[q.kind] ?? 0)
    }

    /// Puana göre azalan; eşitlikte ID. Döngü 2'de puan yerine en eski görülme sırası korunur.
    static func ranked(_ quotes: [Quote], context: QuoteContext, interest: QuoteInterest,
                       catalog: ContentCatalog, rng: inout SeededRandom) -> [Quote] {
        let scored = quotes.map { ($0, score($0, context: context, interest: interest, catalog: catalog, rng: &rng)) }
        return scored.sorted { ($0.1, $1.0.id) > ($1.1, $0.0.id) }.map(\.0)
    }

    // MARK: - Çeşitlilik (E2.3)

    /// Sıralı adaylardan `count` tanesini çeşitlilik kısıtlarıyla dizer:
    /// aynı yazar arka arkaya gelmez ve 8 kartta en fazla 1; aynı tür en fazla
    /// 3 arka arkaya; her 5 kartta en az 1 kısa; aynı tema en fazla 2 arka
    /// arkaya. `history` kuyrukta zaten sırada olan (ya da son gösterilen)
    /// kartlardır; pencere onlarla devam eder. Kısıtı sağlayan aday yoksa en
    /// az kısıt çiğneyen seçilir (havuz tükenirken boş akış yok).
    static func diversified(_ ranked: [Quote], count: Int, history: [Quote] = []) -> [Quote] {
        var remaining = ranked
        var placed: [Quote] = []
        while placed.count < count, !remaining.isEmpty {
            let sequence = history + placed
            var bestIndex = 0, bestViolations = Int.max
            for (i, q) in remaining.enumerated() {
                let v = violations(q, after: sequence)
                if v < bestViolations { bestIndex = i; bestViolations = v }
                if v == 0 { break }
            }
            placed.append(remaining.remove(at: bestIndex))
        }
        return placed
    }

    /// Kısıt ihlali sayısı; 0 = uygun.
    static func violations(_ q: Quote, after sequence: [Quote]) -> Int {
        var v = 0
        if let author = q.author {
            if sequence.suffix(7).contains(where: { $0.author == author }) { v += 1 }
        }
        let lastThree = sequence.suffix(3)
        if lastThree.count == 3, lastThree.allSatisfy({ $0.kind == q.kind }) { v += 1 }
        let lastFour = sequence.suffix(4)
        if lastFour.count == 4, q.length != .short, !lastFour.contains(where: { $0.length == .short }) { v += 1 }
        let lastTwo = sequence.suffix(2)
        if lastTwo.count == 2 {
            let repeated = Set(lastTwo.first!.themes).intersection(lastTwo.last!.themes).intersection(q.themes)
            if !repeated.isEmpty { v += 1 }
        }
        return v
    }
}
