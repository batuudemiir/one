//
//  QuoteEngine.swift
//  ONE 2.0
//
//  Söz motoru (04_arka_plan_motorlari.md › E2). Kararları `QuoteSelection`
//  verir; bu sınıf onu içerik, maruz kalma kaydı, profil ve kalıcı kuyrukla
//  besler.
//
//  - Mod başına kalıcı kuyruk (yerel, cihaz başına): 30 söz önden seçilir,
//    sıra saklanır; 10'dan az kalınca doldurulur. Profil, yetki ya da içerik
//    sürümü değişirse kuyruk yeniden kurulur.
//  - Oturum: `startSession()` ile başlar; bir oturumda aynı söz iki kez
//    gösterilmez. Ekranda ≥1,2 sn kalan ya da etkileşim alan kart "görüldü"
//    sayılır (E3'e yazılır). Hızlı geçilen kart görülmüş sayılmaz; oturum
//    bitince kuyruğun sonuna döner.
//  - Günün sözü: `quote.daily.<dayKey>` KVS anahtarı; ilk seçen cihaz
//    belirler, diğerleri okur. Seçim kullanıcı tuzu + gün ile tohumlanır.
//  - Ekran akışı `nextItems` ile alır: "Sana özel"de günün ilk kartı günün
//    sözü, sonra (varsa) yazılan sözün geri dönüşü; her kart künyesiyle.
//    Modun tükenip tükenmediği `feedState` ile (E2.2 kural 3, UX-7).
//

import Foundation

nonisolated enum QuoteAction: Hashable, Sendable {
    case liked, unliked, shared
    case wroteAbout(UUID)
}

/// Kullanıcının yazdığı sözün bilinçli geri dönüşü (E2.2 kural 4).
nonisolated struct ResurfacedQuote: Hashable, Sendable {
    let quote: Quote
    /// "Bu söze 12 Haziran'da yazmıştın" etiketi için.
    let writtenAt: Date
    let entryID: UUID?
}

protocol QuoteEngine: AnyObject {
    func nextBatch(mode: QuoteFeedMode, count: Int) async -> [Quote]
    func nextItems(mode: QuoteFeedMode, count: Int) async -> [QuoteFeedItem]
    func feedState(mode: QuoteFeedMode) async -> QuoteFeedState
    func markSeen(_ id: QuoteID, dwell: Duration) async
    func record(_ action: QuoteAction, for id: QuoteID) async
    func dailyQuote(for day: DayKey) async -> Quote?
    func remainingUnseen(mode: QuoteFeedMode) async -> Int
    func resurfacingCandidate(on day: DayKey) async -> ResurfacedQuote?
}

final class LiveQuoteEngine: QuoteEngine {
    static let queueTarget = 30
    static let queueRefillThreshold = 10
    static let seenDwell = QuoteVisibilityTracker.seenDwell
    /// Geri dönen söz akışta bu sıraya girer (günün sözünden sonra, hemen değil).
    static let resurfacePosition = 2
    /// Tükenen modun boş durumunda önerilen en fazla mod sayısı.
    static let alternativeLimit = 3
    static let poolLowThreshold = 150
    static let resurfaceAfter: TimeInterval = 90 * 86_400

    private let content: ContentRepository
    private let exposure: ExposureStore
    private let profile: ProfileStore
    private let clock: AppClock
    /// Cihazlar arası (KVS): günün sözü.
    private let cloud: KeyValueBacking
    /// Cihaz başına: kuyruklar, geri dönüş kaydı.
    private let local: KeyValueBacking
    private let hasPremium: () -> Bool
    private let moodScore: () -> Int?
    /// `content_pool_low` (E2.6); analitik E17'de bağlanır.
    var onPoolLow: ((QuoteFeedMode, Int) -> Void)?

    private var sessionShown: Set<QuoteID> = []
    private var sessionUnseen: [String: [QuoteID]] = [:]
    private var poolLowReported: Set<String> = []

    init(content: ContentRepository, exposure: ExposureStore, profile: ProfileStore, clock: AppClock,
         cloud: KeyValueBacking = NSUbiquitousKeyValueStore.default,
         local: KeyValueBacking = UserDefaults(suiteName: "group.com.batudemir.ones") ?? .standard,
         hasPremium: @escaping () -> Bool = { false },
         moodScore: @escaping () -> Int? = { nil }) {
        self.content = content; self.exposure = exposure; self.profile = profile; self.clock = clock
        self.cloud = cloud; self.local = local; self.hasPremium = hasPremium; self.moodScore = moodScore
    }

    // MARK: - Oturum

    /// Yeni oturum: önceki oturumda gösterilip görülmeyen kartlar kuyruğun sonuna döner.
    func startSession() {
        endSession()
        sessionShown = []
    }

    func endSession() {
        for (modeKey, ids) in sessionUnseen where !ids.isEmpty {
            var queue = loadQueue(modeKey)
            let returning = ids.filter { queue.ids.contains($0) }
            queue.ids.removeAll { returning.contains($0) }
            queue.ids.append(contentsOf: returning)
            saveQueue(queue, modeKey)
        }
        sessionUnseen = [:]
    }

    // MARK: - API

    func nextBatch(mode: QuoteFeedMode, count: Int) async -> [Quote] {
        let catalog = content.catalog
        guard let snapshot = try? exposure.snapshot(.quote) else { return [] }
        if mode.isList { return list(mode, catalog: catalog, snapshot: snapshot, count: count) }

        let context = makeContext()
        var queue = validQueue(mode, context: context, catalog: catalog)
        let cycleTwo = Set(queue.cycleTwo)
        queue.ids.removeAll { snapshot[$0]?.wasSeen == true && !cycleTwo.contains($0) }

        var batch: [Quote] = []
        for id in queue.ids where batch.count < count {
            guard !sessionShown.contains(id), let q = catalog.quote(id) else { continue }
            batch.append(q)
        }
        if batch.count < count || queue.ids.count - batch.count < Self.queueRefillThreshold {
            refill(&queue, mode: mode, context: context, catalog: catalog, snapshot: snapshot)
            for id in queue.ids where batch.count < count {
                guard !sessionShown.contains(id), !batch.contains(where: { $0.id == id }),
                      let q = catalog.quote(id) else { continue }
                batch.append(q)
            }
        }
        saveQueue(queue, mode.key)
        for q in batch {
            sessionShown.insert(q.id)
            sessionUnseen[mode.key, default: []].append(q.id)
        }
        return batch
    }

    /// Ekranın akışı: `nextBatch` + künye. "Sana özel"de, cihazda günün ilk
    /// akışında önce günün sözü (UX-7), sonra varsa geri dönen söz (E2.2 kural
    /// 4) bir kez yer alır. İkisi de zaten görülmüş sayılır; kuyruğa girmez.
    func nextItems(mode: QuoteFeedMode, count: Int) async -> [QuoteFeedItem] {
        guard count > 0 else { return [] }
        let today = clock.today
        var daily: Quote?
        var resurfaced: ResurfacedQuote?
        if mode == .forYou {
            if local.object(forKey: Self.dailyShownKey) as? String != today.string,
               let q = await dailyQuote(for: today), !sessionShown.contains(q.id) {
                local.set(today.string, forKey: Self.dailyShownKey)
                sessionShown.insert(q.id)
                daily = q
            }
            let lead = daily == nil ? 0 : 1
            if count - lead > 1, local.object(forKey: Self.resurfaceShownKey) as? String != today.string,
               let r = await resurfacingCandidate(on: today), r.quote.id != daily?.id, !sessionShown.contains(r.quote.id) {
                local.set(today.string, forKey: Self.resurfaceShownKey)
                sessionShown.insert(r.quote.id)
                resurfaced = r
            }
        }
        let special = (daily == nil ? 0 : 1) + (resurfaced == nil ? 0 : 1)
        let regular = await nextBatch(mode: mode, count: count - special)
        let snapshot = (try? exposure.snapshot(.quote)) ?? ExposureSnapshot(kind: .quote)
        func item(_ q: Quote, _ reason: QuoteFeedReason) -> QuoteFeedItem {
            let r = snapshot[q.id]
            return QuoteFeedItem(quote: q, reason: reason, liked: r?.liked ?? false, writtenCount: r?.writtenCount ?? 0)
        }
        var items = regular.map { item($0, .regular) }
        if let resurfaced {
            items.insert(item(resurfaced.quote, .resurfaced(writtenAt: resurfaced.writtenAt, entryID: resurfaced.entryID)),
                         at: min(Self.resurfacePosition, items.count))
        }
        if let daily { items.insert(item(daily, .daily), at: 0) }
        return items
    }

    /// Modun durumu (E2.2 kural 3). Tükenen modda görülmemiş sözü kalan
    /// erişilebilir modlar önerilir: önce kullanıcının yolları, sonra diğer
    /// yollar (en çok görülmemişi olan önce), en son "Sana özel".
    func feedState(mode: QuoteFeedMode) async -> QuoteFeedState {
        let context = makeContext()
        guard QuoteSelection.isAccessible(mode, context: context) else { return .locked }
        guard let snapshot = try? exposure.snapshot(.quote) else { return .empty }
        if mode.isList {
            let count = snapshot.records.values.filter { mode == .favorites ? $0.liked : $0.wasWritten }
                .filter { content.catalog.quote($0.contentID) != nil }.count
            return count == 0 ? .empty : .list(count: count)
        }
        let eligible = QuoteSelection.eligible(content.catalog.quotes, mode: mode, context: context)
        guard !eligible.isEmpty else { return .empty }
        let (pool, cycle) = QuoteSelection.candidates(eligible, exposure: snapshot, excluding: [], now: context.now)
        if cycle == 1 { return .available(unseen: pool.count) }
        if !pool.isEmpty { return .revisiting(count: pool.count) }
        return .exhausted(alternatives: alternatives(to: mode, context: context, snapshot: snapshot))
    }

    func markSeen(_ id: QuoteID, dwell: Duration) async {
        guard dwell >= Self.seenDwell else { return }
        seen(id)
    }

    func record(_ action: QuoteAction, for id: QuoteID) async {
        switch action {
        case .liked: try? exposure.setLiked(true, id: id, kind: .quote); seen(id)
        case .unliked: try? exposure.setLiked(false, id: id, kind: .quote)
        case .shared: seen(id)
        case .wroteAbout(let entryID): try? exposure.recordWritten(id, kind: .quote, entryID: entryID); seen(id)
        }
    }

    func dailyQuote(for day: DayKey) async -> Quote? {
        let catalog = content.catalog
        let key = "quote.daily.\(day.string)"
        if let id = cloud.object(forKey: key) as? String, let q = catalog.quote(id), q.active { return q }
        guard let q = Self.chooseDaily(for: day, catalog: catalog, context: dailyContext(for: day),
                                       exposure: (try? exposure.snapshot(.quote)) ?? ExposureSnapshot(kind: .quote),
                                       salt: profile.profile.userSalt) else { return nil }
        cloud.set(q.id, forKey: key)
        // E2.4: günün sözü akışta ayrıca görüldü sayılır.
        exposure.recordSeen(q.id, kind: .quote)
        return q
    }

    /// Günün sözünü yazmadan önizler: KVS'de varsa o, yoksa aynı deterministik
    /// seçim. Bildirim penceresi ve widget'ın ertesi gün sözü için (E13, E14).
    func previewDailyQuote(for day: DayKey) -> Quote? {
        let catalog = content.catalog
        if let id = cloud.object(forKey: "quote.daily.\(day.string)") as? String, let q = catalog.quote(id), q.active {
            return q
        }
        return Self.chooseDaily(for: day, catalog: catalog, context: dailyContext(for: day),
                                exposure: (try? exposure.snapshot(.quote)) ?? ExposureSnapshot(kind: .quote),
                                salt: profile.profile.userSalt)
    }

    func remainingUnseen(mode: QuoteFeedMode) async -> Int {
        let context = makeContext()
        guard let snapshot = try? exposure.snapshot(.quote) else { return 0 }
        let count = QuoteSelection.eligible(content.catalog.quotes, mode: mode, context: context)
            .filter { snapshot[$0.id]?.wasSeen != true }.count
        if count < Self.poolLowThreshold, !mode.isList, !poolLowReported.contains(mode.key) {
            poolLowReported.insert(mode.key)
            onPoolLow?(mode, count)
        }
        return count
    }

    /// En fazla haftada bir; aynı gün tekrar sorulursa aynı sözü döner.
    func resurfacingCandidate(on day: DayKey) async -> ResurfacedQuote? {
        guard profile.profile.resurfaceWritten,
              let snapshot = try? exposure.snapshot(.quote) else { return nil }
        let catalog = content.catalog
        let lastKey = "quote.resurface.last"
        if let last = (local.object(forKey: lastKey) as? String)?.split(separator: "|"), last.count == 2,
           let lastDay = DayKey(String(last[0])) {
            if lastDay == day, let q = catalog.quote(String(last[1])), let r = snapshot[q.id], let at = r.lastWrittenAt {
                return ResurfacedQuote(quote: q, writtenAt: at, entryID: r.lastEntryID)
            }
            if lastDay.days(to: day) < 7 { return nil }
        }
        let cutoff = clock.now.addingTimeInterval(-Self.resurfaceAfter)
        let pick = snapshot.records.values
            .filter { ($0.lastWrittenAt ?? .distantFuture) <= cutoff && ($0.lastSeenAt ?? .distantPast) <= cutoff }
            .compactMap { r in catalog.quote(r.contentID).map { (r, $0) } }
            .filter { $0.1.active }
            .min { ($0.0.lastWrittenAt!, $0.1.id) < ($1.0.lastWrittenAt!, $1.1.id) }
        guard let (record, quote) = pick else { return nil }
        local.set("\(day.string)|\(quote.id)", forKey: lastKey)
        return ResurfacedQuote(quote: quote, writtenAt: record.lastWrittenAt!, entryID: record.lastEntryID)
    }

    /// Modun erişilebilir olup olmadığı (arayüz kilidi için).
    func isAccessible(_ mode: QuoteFeedMode) -> Bool {
        QuoteSelection.isAccessible(mode, context: makeContext())
    }

    // MARK: - Günün sözü (saf)

    /// "Sana özel" adaylarından, gün + tuz ile tohumlanmış seçim. Bağlam
    /// cihazdan bağımsızdır (ruh hali ve saat dilimi katılmaz): aynı veriyle
    /// iki cihaz aynı sözü seçer.
    static func chooseDaily(for day: DayKey, catalog: ContentCatalog, context: QuoteContext,
                            exposure: ExposureSnapshot, salt: UUID) -> Quote? {
        let eligible = QuoteSelection.eligible(catalog.quotes, mode: .forYou, context: context)
        let pool = QuoteSelection.candidates(eligible, exposure: exposure, excluding: [], now: context.now).quotes
        let candidates = pool.isEmpty ? eligible : pool
        var rng = SeededRandom("quote.daily", salt.uuidString, day.string)
        let interest = QuoteInterest.from(exposure, catalog: catalog, now: context.now)
        return QuoteSelection.ranked(candidates, context: context, interest: interest, catalog: catalog, rng: &rng).first
    }

    // MARK: - Private

    private static let dailyShownKey = "quote.feed.dailyShown"
    private static let resurfaceShownKey = "quote.feed.resurfaceShown"

    private func alternatives(to mode: QuoteFeedMode, context: QuoteContext, snapshot: ExposureSnapshot) -> [QuoteFeedMode] {
        let catalog = content.catalog
        let own = context.quotePaths
        let others = catalog.paths.filter { $0.active && $0.lang == context.lang && !own.contains($0.id) }
            .map(\.id).sorted()
        let modes: [QuoteFeedMode] = [.forYou] + (own + others).map { .path($0) }
        let unseen: [(mode: QuoteFeedMode, count: Int, rank: Int)] = modes.compactMap { m in
            guard m != mode, QuoteSelection.isAccessible(m, context: context) else { return nil }
            let n = QuoteSelection.eligible(catalog.quotes, mode: m, context: context)
                .filter { snapshot[$0.id]?.wasSeen != true }.count
            guard n > 0 else { return nil }
            guard case .path(let id) = m else { return (m, n, 2) }
            return (m, n, own.contains(id) ? 0 : 1)
        }
        return unseen
            .sorted { ($0.rank, -$0.count, $0.mode.key) < ($1.rank, -$1.count, $1.mode.key) }
            .prefix(Self.alternativeLimit).map(\.mode)
    }

    private func seen(_ id: QuoteID) {
        exposure.recordSeen(id, kind: .quote)
        for key in sessionUnseen.keys { sessionUnseen[key]?.removeAll { $0 == id } }
        for key in sessionUnseen.keys {
            var queue = loadQueue(key)
            if queue.ids.contains(id) { queue.ids.removeAll { $0 == id }; saveQueue(queue, key) }
        }
    }

    private func makeContext() -> QuoteContext {
        let p = profile.profile
        let today = clock.today
        let week = ThemeCalendar.theme(for: today, catalog: content.catalog, salt: p.userSalt)
        let hour = clock.calendar.component(.hour, from: clock.now)
        return QuoteContext(quotePaths: p.quotePaths, lang: p.contentLang, hasPremium: hasPremium(),
                            weekThemeTags: week.map { Set($0.theme.tags) } ?? [], weekThemeID: week?.theme.id,
                            dayPart: .of(hour: hour), moodScore: moodScore(), now: clock.now)
    }

    private func dailyContext(for day: DayKey) -> QuoteContext {
        let p = profile.profile
        let tags = ThemeCalendar.theme(for: day, catalog: content.catalog, salt: p.userSalt).map { Set($0.theme.tags) } ?? []
        return QuoteContext(quotePaths: p.quotePaths, lang: p.contentLang, hasPremium: hasPremium(),
                            weekThemeTags: tags, dayPart: .any, moodScore: nil,
                            now: day.startDate(in: clock.calendar) ?? clock.now)
    }

    private func list(_ mode: QuoteFeedMode, catalog: ContentCatalog, snapshot: ExposureSnapshot, count: Int) -> [Quote] {
        let records = snapshot.records.values.filter { mode == .favorites ? $0.liked : $0.wasWritten }
        let sorted = records.sorted {
            let a = mode == .favorites ? $0.likedAt : $0.lastWrittenAt
            let b = mode == .favorites ? $1.likedAt : $1.lastWrittenAt
            return (a ?? .distantPast, $1.contentID) > (b ?? .distantPast, $0.contentID)
        }
        return Array(sorted.compactMap { catalog.quote($0.contentID) }.prefix(count))
    }

    // MARK: Kuyruk

    private struct Queue: Codable {
        var ids: [QuoteID]
        var fingerprint: String
        /// Döngü 2'den gelen (görülmüş ama 60 günü geçmiş) sözler.
        var cycleTwo: [QuoteID] = []
    }

    private func fingerprint(_ context: QuoteContext, catalog: ContentCatalog) -> String {
        "\(catalog.contentVersion)|\(context.hasPremium)|\(context.lang)|\(context.quotePaths.joined(separator: ","))|\(context.weekThemeID ?? "")"
    }

    private func validQueue(_ mode: QuoteFeedMode, context: QuoteContext, catalog: ContentCatalog) -> Queue {
        let fp = fingerprint(context, catalog: catalog)
        let queue = loadQueue(mode.key)
        return queue.fingerprint == fp ? queue : Queue(ids: [], fingerprint: fp)
    }

    private func refill(_ queue: inout Queue, mode: QuoteFeedMode, context: QuoteContext,
                        catalog: ContentCatalog, snapshot: ExposureSnapshot) {
        let need = Self.queueTarget - queue.ids.count
        guard need > 0 else { return }
        let eligible = QuoteSelection.eligible(catalog.quotes, mode: mode, context: context)
        let excluded = Set(queue.ids).union(sessionShown)
        let (candidates, cycle) = QuoteSelection.candidates(eligible, exposure: snapshot, excluding: excluded, now: context.now)
        guard !candidates.isEmpty else { return }
        let history = queue.ids.suffix(8).compactMap(catalog.quote)
        let next: [Quote]
        if cycle == 2 {
            // En uzun süredir görülmeyen önce; yalnız çeşitlilik uygulanır.
            next = QuoteSelection.diversified(candidates, count: need, history: history)
            queue.cycleTwo.append(contentsOf: next.map(\.id))
        } else {
            var rng = SeededRandom("quote.feed", profile.profile.userSalt.uuidString, clock.today.string, mode.key,
                                   String(queue.ids.count), String(snapshot.seenIDs.count))
            let interest = QuoteInterest.from(snapshot, catalog: catalog, now: context.now)
            let ranked = QuoteSelection.ranked(candidates, context: context, interest: interest, catalog: catalog, rng: &rng)
            next = QuoteSelection.diversified(ranked, count: need, history: history)
        }
        queue.ids.append(contentsOf: next.map(\.id))
    }

    private func loadQueue(_ key: String) -> Queue {
        guard let data = local.object(forKey: "quote.queue.\(key)") as? Data,
              let queue = try? JSONDecoder().decode(Queue.self, from: data) else { return Queue(ids: [], fingerprint: "") }
        return queue
    }

    private func saveQueue(_ queue: Queue, _ key: String) {
        var q = queue
        q.cycleTwo.removeAll { !q.ids.contains($0) }
        local.set(try? JSONEncoder().encode(q), forKey: "quote.queue.\(key)")
    }
}
