//
//  QuoteSelection.swift
//  ONE 2.0
//
//  Söz motorunun saf çekirdeği (04_arka_plan_motorlari.md › E2.2, E2.3).
//  Girdi: katalog + maruz kalma geçmişi + bağlam + tohum → sıralı söz listesi.
//  Core Data, UserDefaults ve UI yok; `QuoteEngine` bunu besler.
//

import Foundation

/// Akış modu (E2.5, 08 §4.2). Tür modu kalktı: akışta yalnız `quote` var (08 §1).
nonisolated enum QuoteFeedMode: Hashable, Sendable {
    case forYou
    case path(PathID)
    /// Düşünür sayfası ve "Bu hafta onunla": yalnız o düşünürün sözleri.
    case thinker(ThinkerID)
    case theme(String)
    case favorites
    case written

    /// Kalıcı kuyruk ve tohum anahtarı.
    var key: String {
        switch self {
        case .forYou: return "forYou"
        case .path(let id): return "path:\(id)"
        case .thinker(let id): return "thinker:\(id)"
        case .theme(let id): return "theme:\(id)"
        case .favorites: return "favorites"
        case .written: return "written"
        }
    }

    /// Favoriler ve yazılanlar kendi listeleri; akış kuralları uygulanmaz (E2.2 kural 5).
    var isList: Bool { self == .favorites || self == .written }

}

/// Puan bileşenlerinin ağırlıkları (08 §4.3 tablo; E2.3'ü geçersiz kılar).
/// Yapılandırmayla değişebilir; testte varsayılan sabit.
nonisolated struct QuoteWeights: Hashable, Sendable {
    var path = 0.20
    var affinity = 0.15
    var theme = 0.10
    /// Ruh hali ve ton.
    var mood = 0.15
    var timeOfDay = 0.05
    var interest = 0.10
    var novelty = 0.15
    var random = 0.10

    static let `default` = QuoteWeights()
}

/// Çeşitlilik kurallarının moda göre açık olanları (08 §4.4).
nonisolated struct DiversityRules: Hashable, Sendable {
    /// Aynı düşünür 8 kartta 1, günde 2.
    var sameThinker = true
    /// Aynı yol en fazla 3 arka arkaya.
    var samePath = true

    static let all = DiversityRules()

    static func `for`(_ mode: QuoteFeedMode) -> DiversityRules {
        switch mode {
        case .thinker: return DiversityRules(sameThinker: false, samePath: false)
        case .path: return DiversityRules(sameThinker: true, samePath: false)
        default: return .all
        }
    }
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

    /// Ücretsiz kullanıcının açık yolu: onboarding'de seçilen ilk yol,
    /// seçilmediyse `stoacilar` (08 §3.3).
    var freePath: PathID { quotePaths.first ?? QuotePath.defaultFreeID }
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
    /// Skor ≤ 2 iken artı ve eksi tonlar (08 §4.3).
    static let lowMoodTones: Set<String> = [QuoteTone.sefkatli.rawValue, QuoteTone.sakin.rawValue]
    static let highEnergyTones: Set<String> = [QuoteTone.cesur.rawValue, QuoteTone.uretken.rawValue]
    /// Düşünür günde en fazla bu kadar (düşünür modu hariç).
    static let thinkerDailyLimit = 2
    /// Keşif payı: her 10 kartta 1; ücretsizde tanıtım kartı günde en fazla 2.
    static let discoveryEvery = 10
    static let introDailyLimit = 2

    // MARK: - Aday havuzu

    /// Moda açık mı? Ücretsiz: Sana özel + açık yol (08 §3.3). Düşünür sayfası,
    /// düşünür açık yoldaysa açık; `catalog` verilmezse karar söz kapısına kalır.
    static func isAccessible(_ mode: QuoteFeedMode, context: QuoteContext,
                             catalog: ContentCatalog? = nil) -> Bool {
        if context.hasPremium { return true }
        switch mode {
        case .forYou, .favorites, .written: return true
        case .path(let id): return id == context.freePath
        case .thinker(let id): return catalog.map { $0.thinker(id)?.pathIDs.contains(context.freePath) == true } ?? true
        case .theme: return false
        }
    }

    /// Söz ücretsiz kullanıcıya açık mı: premium işaretsiz ve açık yolda.
    static func isOpen(_ q: Quote, context: QuoteContext) -> Bool {
        context.hasPremium || (!q.premium && q.paths.contains(context.freePath))
    }

    /// Akışa girebilir mi (08 §1): yalnız doğrulanmış `quote`.
    static func isFeedItem(_ q: Quote) -> Bool { q.kind == .quote && q.verified }

    /// `active` ∧ `lang` ∧ `quote` ∧ doğrulanmış ∧ yetki ∧ moda uygun.
    /// Görülme filtresi yok. Listeler (favoriler, yazılanlar) kullanıcının
    /// kendi kaydıdır; tür ve yetki filtresi uygulanmaz.
    static func eligible(_ quotes: [Quote], mode: QuoteFeedMode, context: QuoteContext) -> [Quote] {
        guard isAccessible(mode, context: context) else { return [] }
        return quotes.filter { q in
            guard q.active, q.lang == context.lang else { return false }
            if mode.isList { return true }
            guard isFeedItem(q), isOpen(q, context: context) else { return false }
            switch mode {
            case .forYou, .favorites, .written: return true
            case .path(let id): return q.paths.contains(id)
            case .thinker(let id): return q.authorID == id
            case .theme(let id): return q.themes.contains(id)
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

    /// Keşif adayları (08 §4.4): kullanıcının seçmediği bir yoldan görülmemiş
    /// sözler. Yetki kapısı yok: ücretsizde tanıtım kartı. Sıralamayı
    /// `discoveryOrder` verir.
    static func discoveryCandidates(_ quotes: [Quote], context: QuoteContext,
                                    exposure: ExposureSnapshot, excluding: Set<QuoteID>) -> [Quote] {
        let selected = Set(context.quotePaths.isEmpty ? [context.freePath] : context.quotePaths)
        return quotes.filter { q in
            q.active && q.lang == context.lang && isFeedItem(q) && !excluding.contains(q.id)
                && exposure[q.id]?.wasSeen != true
                && !q.paths.isEmpty && selected.isDisjoint(with: q.paths) && q.authorID != nil
        }
    }

    /// Önce hiç görülmemiş düşünürler (puan sırasıyla), sonra en uzun süredir
    /// görülmeyenler. Havuz büyüdükçe ilk grup kalıcı olarak tükenir; ikinci
    /// grup payın kurumasını önler.
    static func discoveryOrder(_ ranked: [Quote], signals: ThinkerSignals) -> [Quote] {
        ranked.enumerated().sorted { a, b in
            let la = a.element.authorID.flatMap { signals.lastSeen[$0] } ?? .distantPast
            let lb = b.element.authorID.flatMap { signals.lastSeen[$0] } ?? .distantPast
            return la != lb ? la < lb : a.offset < b.offset
        }.map(\.element)
    }

    /// Ücretsiz kullanıcıya kilitli olan (tanıtım) kart mı?
    static func isIntro(_ q: Quote, context: QuoteContext) -> Bool { !isOpen(q, context: context) }

    // MARK: - Puan

    static func score(_ q: Quote, context: QuoteContext, interest: QuoteInterest, catalog: ContentCatalog,
                      signals: ThinkerSignals = .empty, rng: inout SeededRandom) -> Double {
        let w = context.weights
        return w.path * pathScore(q, context: context, catalog: catalog)
            + w.affinity * signals.scaled(q.authorID)
            + w.theme * (context.weekThemeTags.isDisjoint(with: q.themes) ? 0 : 1)
            + w.timeOfDay * timeScore(q, context.dayPart)
            + w.mood * moodScore(q, context.moodScore)
            + w.interest * interestScore(q, interest)
            + w.novelty * signals.novelty(q.authorID, now: context.now)
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

    /// `moodFit` uyumu; skor ≤ 2 iken `sefkatli`/`sakin` artı, `cesur`/`uretken`
    /// eksi, yumuşak tema küçük artı (08 §4.3). 0–1.
    static func moodScore(_ q: Quote, _ score: Int?) -> Double {
        guard let score else { return 0.5 }
        var s = q.moodFit.isEmpty ? 0.5 : (q.moodFit.contains(score) ? 1 : 0)
        if score <= 2 {
            let tones = Set(q.tones)
            if !tones.isDisjoint(with: lowMoodTones) { s += 0.5 }
            if !tones.isDisjoint(with: highEnergyTones) { s -= 0.5 }
            if !softThemes.isDisjoint(with: q.themes) { s += 0.25 }
        }
        return min(1, max(0, s))
    }

    static func interestScore(_ q: Quote, _ interest: QuoteInterest) -> Double {
        guard !interest.isEmpty else { return 0.5 }
        let theme = q.themes.map { interest.themeWeights[$0] ?? 0 }.max() ?? 0
        return 0.7 * theme + 0.3 * (interest.kindWeights[q.kind] ?? 0)
    }

    /// Puana göre azalan; eşitlikte ID. Döngü 2'de puan yerine en eski görülme sırası korunur.
    static func ranked(_ quotes: [Quote], context: QuoteContext, interest: QuoteInterest,
                       catalog: ContentCatalog, signals: ThinkerSignals = .empty,
                       rng: inout SeededRandom) -> [Quote] {
        let scored = quotes.map {
            ($0, score($0, context: context, interest: interest, catalog: catalog, signals: signals, rng: &rng))
        }
        return scored.sorted { ($0.1, $1.0.id) > ($1.1, $0.0.id) }.map(\.0)
    }

    // MARK: - Çeşitlilik (E2.3, 08 §4.4)

    /// Sıralı adaylardan `count` tanesini çeşitlilik kısıtlarıyla dizer
    /// (`violations`). `history` kuyrukta zaten sırada olan (ya da son
    /// gösterilen) kartlardır; pencere onlarla devam eder. Kısıtı sağlayan
    /// aday yoksa en az kısıt çiğneyen seçilir (havuz tükenirken boş akış yok).
    static func diversified(_ ranked: [Quote], count: Int, history: [Quote] = [],
                            rules: DiversityRules = .all, dayCounts: [ThinkerID: Int] = [:]) -> [Quote] {
        assemble(ranked, discovery: [], count: count, history: history, rules: rules, dayCounts: dayCounts).quotes
    }

    /// `diversified` + keşif payı: sıra numarası (`startIndex` + yerleşen)
    /// her `discoveryEvery`. karta geldiğinde kısıt çiğnemeyen ilk keşif adayı
    /// konur; yoksa sıradaki kartta yeniden denenir. `introLimit` ücretsizde
    /// kalan tanıtım hakkıdır (nil = sınırsız); `isIntro` hangi kartın hakkı
    /// tükettiğini söyler. Keşif düşünürü bir kez kullanılır; normal akışta
    /// yer alan düşünür keşif havuzundan düşer.
    static func assemble(_ ranked: [Quote], discovery: [Quote], count: Int, history: [Quote] = [],
                         startIndex: Int = 0, rules: DiversityRules = .all, dayCounts: [ThinkerID: Int] = [:],
                         introLimit: Int? = nil, isIntro: (Quote) -> Bool = { _ in false })
        -> (quotes: [Quote], discoveryIDs: [QuoteID]) {
        var remaining = ranked
        var pool = discovery
        var placed: [Quote] = []
        var discoveryIDs: [QuoteID] = []
        var counts = dayCounts
        var intros = introLimit
        func best(_ list: [Quote], _ sequence: [Quote]) -> Int? {
            var bestIndex: Int?, bestViolations = Int.max
            for (i, q) in list.enumerated() {
                let v = violations(q, after: sequence, rules: rules, dayCounts: counts)
                if v < bestViolations { bestIndex = i; bestViolations = v }
                if v == 0 { break }
            }
            return bestIndex
        }
        var due = false
        while placed.count < count {
            let sequence = history + placed
            let position = startIndex + placed.count
            if position % discoveryEvery == discoveryEvery - 1 { due = true }
            if due {
                let allowed = pool.filter { q in intros.map { $0 > 0 || !isIntro(q) } ?? true }
                if let i = best(allowed, sequence),
                   violations(allowed[i], after: sequence, rules: rules, dayCounts: counts) == 0 {
                    due = false
                    let q = allowed[i]
                    pool.removeAll { $0.authorID == q.authorID }
                    remaining.removeAll { $0.id == q.id }
                    if isIntro(q) { intros = intros.map { $0 - 1 } }
                    placed.append(q)
                    discoveryIDs.append(q.id)
                    if let id = q.authorID { counts[id, default: 0] += 1 }
                    continue
                }
            }
            guard let i = best(remaining, sequence) else { break }
            let q = remaining.remove(at: i)
            pool.removeAll { $0.id == q.id || $0.authorID == q.authorID }
            placed.append(q)
            if let id = q.authorID { counts[id, default: 0] += 1 }
        }
        return (placed, discoveryIDs)
    }

    /// Kısıt ihlali sayısı; 0 = uygun.
    /// - Aynı düşünür 8 kartta en fazla 1, günde en fazla 2 (`rules.sameThinker`).
    /// - Aynı yol en fazla 3 arka arkaya (`rules.samePath`). 2+ yolda "her 10
    ///   kartta en az 2 yol" bundan çıkar.
    /// - Her 5 kartta en az 1 kısa; aynı tema en fazla 2 arka arkaya.
    /// - Söz dışı türde aynı tür en fazla 3 arka arkaya (akış yalnız `quote`).
    static func violations(_ q: Quote, after sequence: [Quote], rules: DiversityRules = .all,
                           dayCounts: [ThinkerID: Int] = [:]) -> Int {
        var v = 0
        // Aynı düşünür: kimlik `authorID` (08); ad satırı yalnız gösterim.
        if rules.sameThinker, let author = q.authorID ?? q.author {
            if sequence.suffix(7).contains(where: { ($0.authorID ?? $0.author) == author }) { v += 1 }
            if (dayCounts[author] ?? 0) >= thinkerDailyLimit { v += 1 }
        }
        let lastThree = sequence.suffix(3)
        if rules.samePath, lastThree.count == 3, !q.paths.isEmpty,
           !lastThree.reduce(Set(q.paths), { $0.intersection($1.paths) }).isEmpty { v += 1 }
        if q.kind != .quote, lastThree.count == 3, lastThree.allSatisfy({ $0.kind == q.kind }) { v += 1 }
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
