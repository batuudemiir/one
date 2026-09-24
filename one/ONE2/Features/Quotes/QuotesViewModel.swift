//
//  QuotesViewModel.swift
//  ONE 2.0
//
//  Sözler sekmesinin durumu (UX-7, UX-11). Motorla `QuoteEngine` protokolü
//  üzerinden konuşur; testte sahte motorla kurulur.
//
//  - Mod değişince akış baştan yüklenir; sonuna yaklaşınca sayfa eklenir.
//  - Akış boş dönerse modun durumu (`feedState`) ekrana gelir: kilitli,
//    tükendi (diğer yollar), boş liste.
//  - Görülme ölçümü ekrandadır (`QuoteVisibilityTracker`); sonuçları
//    `QuoteFeedActions` üzerinden buraya, buradan motora gider.
//

import Foundation
import Observation
#if canImport(CoreGraphics)
import CoreGraphics
#endif

/// Kartın görülme ölçümünün dışarı açılan sözleşmesi (UX-7).
protocol QuoteFeedActions: AnyObject {
    /// Kart ≥%60 görünür şekilde ≥1,2 sn kaldı.
    func onSeen(_ id: QuoteID, dwell: Duration) async
    /// Kart hızlı geçildi; görülmüş sayılmaz, oturum bitince kuyruğa döner.
    func onSkipped(_ id: QuoteID) async
}

nonisolated enum QuotesPhase: Hashable, Sendable {
    case loading
    case feed
    case locked
    /// Akış boş: modun durumu (tükendi, boş liste…).
    case ended(QuoteFeedState)
}

@Observable
final class QuotesViewModel: QuoteFeedActions {
    static let pageSize = 10
    /// Sondan bu kadar kart kala yeni sayfa istenir.
    static let prefetchDistance = 3
    /// Liste modları (favoriler, yazılanlar) tek seferde gelir.
    static let listLimit = 500

    private(set) var mode: QuoteFeedMode = .forYou
    private(set) var items: [QuoteFeedItem] = []
    private(set) var phase: QuotesPhase = .loading
    /// Akışın sonu: son kartın altındaki durum sayfası.
    private(set) var footer: QuoteFeedState?
    private(set) var options: [QuoteModeOption] = []

    /// Kilitli moda dokunuldu → paywall.
    @ObservationIgnored var onLocked: () -> Void = {}
    /// "Bunun hakkında yaz" → QuoteReflection.
    @ObservationIgnored var onWrite: (Quote) -> Void = { _ in }

    @ObservationIgnored private let engine: QuoteEngine
    @ObservationIgnored private let makeOptions: () -> [QuoteModeOption]
    @ObservationIgnored private var isLoadingMore = false
    /// Mod değişince eski isteklerin sonucu atılır.
    @ObservationIgnored private var generation = 0

    init(engine: QuoteEngine, options: @escaping () -> [QuoteModeOption]) {
        self.engine = engine
        self.makeOptions = options
    }

    var selectedOption: QuoteModeOption? { options.first { $0.mode == mode } }

    // MARK: - Yükleme

    func load() async {
        generation += 1
        let current = generation
        options = makeOptions()
        phase = .loading
        items = []
        footer = nil
        let batch = await engine.nextItems(mode: mode, count: mode.isList ? Self.listLimit : Self.pageSize)
        guard current == generation else { return }
        if !batch.isEmpty {
            items = batch
            phase = .feed
            return
        }
        let state = await engine.feedState(mode: mode)
        guard current == generation else { return }
        phase = state == .locked ? .locked : .ended(state)
    }

    func select(_ option: QuoteModeOption) async {
        guard !option.isLocked else { onLocked(); return }
        guard option.mode != mode || phase != .feed else { return }
        mode = option.mode
        await load()
    }

    /// Kart ekrana geldi: sona yaklaşıldıysa sonraki sayfa.
    func cardAppeared(_ id: QuoteID) async {
        guard !mode.isList, footer == nil, !isLoadingMore,
              let index = items.firstIndex(where: { $0.id == id }),
              index >= items.count - Self.prefetchDistance else { return }
        isLoadingMore = true
        defer { isLoadingMore = false }
        let current = generation
        let more = await engine.nextItems(mode: mode, count: Self.pageSize)
        guard current == generation else { return }
        let known = Set(items.map(\.id))
        let fresh = more.filter { !known.contains($0.id) }
        if fresh.isEmpty {
            let state = await engine.feedState(mode: mode)
            guard current == generation else { return }
            footer = state
        } else {
            items.append(contentsOf: fresh)
        }
    }

    /// Tükenen modun önerdiği modlar, menüdeki adlarıyla.
    func options(for modes: [QuoteFeedMode]) -> [QuoteModeOption] {
        modes.compactMap { mode in options.first { $0.mode == mode } }
    }

    // MARK: - Kart eylemleri

    func toggleLike(_ id: QuoteID) async {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        let item = items[index]
        let liked = !item.liked
        items[index] = QuoteFeedItem(quote: item.quote, reason: item.reason, liked: liked, writtenCount: item.writtenCount)
        await engine.record(liked ? .liked : .unliked, for: id)
    }

    func didShare(_ id: QuoteID) async {
        await engine.record(.shared, for: id)
    }

    func write(_ id: QuoteID) {
        guard let item = items.first(where: { $0.id == id }) else { return }
        onWrite(item.quote)
    }

    // MARK: - QuoteFeedActions

    func onSeen(_ id: QuoteID, dwell: Duration) async {
        await engine.markSeen(id, dwell: dwell)
    }

    /// Motor hızlı geçilen kartı oturum sonunda kuyruğa kendisi döndürür;
    /// burada yapılacak iş yok.
    func onSkipped(_ id: QuoteID) async {}
}

extension QuotesViewModel {
    /// Uygulamanın gerçek motoruyla.
    static func live(_ environment: AppEnvironment) -> QuotesViewModel {
        let engine = environment.quotes, content = environment.content, profile = environment.profile
        return QuotesViewModel(engine: engine) {
            let p = profile.profile
            return QuoteModeOptions.make(paths: content.catalog.paths, userPaths: p.quotePaths, lang: p.contentLang,
                                         isAccessible: { engine.isAccessible($0) })
        }
    }
}

/// Kartın görünür oranı: kart çerçevesi kaydırma alanının koordinatında,
/// görünen yükseklik `viewportHeight`.
nonisolated enum QuoteCardVisibility {
    static func fraction(of card: CGRect, viewportHeight: CGFloat) -> Double {
        guard card.height > 0, viewportHeight > 0 else { return 0 }
        let visible = min(card.maxY, viewportHeight) - max(card.minY, 0)
        return Double(max(0, visible) / card.height)
    }
}
