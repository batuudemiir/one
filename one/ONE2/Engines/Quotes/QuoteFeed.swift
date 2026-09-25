//
//  QuoteFeed.swift
//  ONE 2.0
//
//  Sözler akışının ekrana açılan değer tipleri (04_arka_plan_motorlari.md ›
//  E2.2, E2.4; 05_ux_promptlari.md › UX-7). Kart künyesi, modun durumu ve
//  "görüldü" ölçümü. Saf: Core Data ve UI yok.
//

import Foundation

/// Kartın akışta neden bulunduğu.
nonisolated enum QuoteFeedReason: Hashable, Sendable {
    case regular
    /// Günün sözü: Sözler'in o günkü ilk kartı (E2.4, UX-7).
    case daily
    /// Bilinçli geri dönüş: "Bu söze 12 Haziran'da yazmıştın" (E2.2 kural 4).
    case resurfaced(writtenAt: Date, entryID: UUID?)
}

/// Akıştaki tek kart: söz + künye.
nonisolated struct QuoteFeedItem: Hashable, Sendable, Identifiable {
    let quote: Quote
    let reason: QuoteFeedReason
    let liked: Bool
    /// "Bu söze 2 kez yazdın" rozeti; 0 ise rozet yok.
    let writtenCount: Int

    var id: QuoteID { quote.id }
}

/// Bir modun durumu; Sözler ekranı boş/kilitli durumlarını buradan kurar.
nonisolated enum QuoteFeedState: Hashable, Sendable {
    /// Premium gerektirir (04 › karar 4).
    case locked
    /// Döngü 1: görülmemiş söz var.
    case available(unseen: Int)
    /// Döngü 2: hepsi görüldü; 60 günü geçmiş sözler en eskiden dönüyor.
    case revisiting(count: Int)
    /// "Bu yolun hepsini gördün." Tekrar yerine dürüst boş durum; görülmemiş
    /// sözü kalan erişilebilir modlar önerilir (E2.2 kural 3).
    case exhausted(alternatives: [QuoteFeedMode])
    /// Favoriler / yazılanlar listesi.
    case list(count: Int)
    /// Modda hiç söz yok (boş liste, içerik yok).
    case empty
}

// MARK: - Görünürlük ölçer

nonisolated enum QuoteVisibilityEvent: Hashable, Sendable {
    /// ≥%60 görünür şekilde ≥1,2 sn kaldı → `QuoteEngine.markSeen`.
    case seen(QuoteID, dwell: Duration)
    /// Hızlı geçildi; görülmüş sayılmaz, oturum bitince kuyruğa döner.
    case skipped(QuoteID)
}

/// E2.2 "görüldü" tanımı. Ekran kartların görünür oranını bildirir; ölçer
/// kesintisiz görünürlük süresini tutar ve olay üretir. Hareketsiz kalan kart
/// için ekran `tick` çağırır (ör. saniyede bir).
///
/// - Oran eşiğin altına düşünce ya da kart ayrılınca süre biter: eşik aşıldıysa
///   `seen`, aşılmadıysa `skipped`.
/// - Bir kart en fazla bir kez `seen` üretir; sonrasında `skipped` üretmez.
/// - Etkileşim (beğen, paylaş, yaz) motora `record` ile gider ve zaten
///   görüldü sayılır; `noteInteraction` yalnız sonradan `skipped` çıkmasını önler.
nonisolated struct QuoteVisibilityTracker: Sendable {
    static let minimumFraction = 0.6
    static let seenDwell: Duration = .milliseconds(1200)

    private var visibleSince: [QuoteID: Date] = [:]
    private var reported: Set<QuoteID> = []

    init() {}

    mutating func update(_ id: QuoteID, fraction: Double, at now: Date) -> QuoteVisibilityEvent? {
        guard fraction >= Self.minimumFraction else { return end(id, at: now) }
        if visibleSince[id] == nil { visibleSince[id] = now }
        return resolveIfDue(id, at: now)
    }

    /// Ekranda duran kartlar için süre kontrolü.
    mutating func tick(at now: Date) -> [QuoteVisibilityEvent] {
        visibleSince.keys.sorted().compactMap { resolveIfDue($0, at: now) }
    }

    mutating func noteInteraction(_ id: QuoteID) {
        reported.insert(id)
    }

    /// Ekran kaybolunca ya da arka plana geçince: görünen her kartı kapatır.
    mutating func flush(at now: Date) -> [QuoteVisibilityEvent] {
        visibleSince.keys.sorted().compactMap { end($0, at: now) }
    }

    private mutating func resolveIfDue(_ id: QuoteID, at now: Date) -> QuoteVisibilityEvent? {
        guard !reported.contains(id), let since = visibleSince[id] else { return nil }
        let dwell = Duration.seconds(max(0, now.timeIntervalSince(since)))
        guard dwell >= Self.seenDwell else { return nil }
        reported.insert(id)
        return .seen(id, dwell: dwell)
    }

    private mutating func end(_ id: QuoteID, at now: Date) -> QuoteVisibilityEvent? {
        if let event = resolveIfDue(id, at: now) {
            visibleSince[id] = nil
            return event
        }
        guard visibleSince.removeValue(forKey: id) != nil, !reported.contains(id) else { return nil }
        return .skipped(id)
    }
}
