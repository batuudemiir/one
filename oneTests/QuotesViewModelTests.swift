//
//  QuotesViewModelTests.swift
//  oneTests
//
//  UX-7 / UX-11: Sözler ekranının motora bağlanması — yükleme, sayfalama,
//  mod seçimi, kart eylemleri, durumlar, görünür oran.
//

import Testing
import Foundation
import CoreGraphics
@testable import OneDailyBatuhan

/// Sayfaları sırayla veren, çağrıları kaydeden motor.
final class FakeQuoteEngine: QuoteEngine {
    var pages: [[QuoteFeedItem]] = []
    var state: QuoteFeedState = .available(unseen: 0)
    private(set) var requests: [(mode: QuoteFeedMode, count: Int)] = []
    private(set) var seen: [QuoteID] = []
    private(set) var actions: [QuoteAction] = []
    private(set) var actionIDs: [QuoteID] = []

    func nextItems(mode: QuoteFeedMode, count: Int) async -> [QuoteFeedItem] {
        requests.append((mode, count))
        return pages.isEmpty ? [] : pages.removeFirst()
    }
    func feedState(mode: QuoteFeedMode) async -> QuoteFeedState { state }
    func nextBatch(mode: QuoteFeedMode, count: Int) async -> [Quote] { [] }
    func markSeen(_ id: QuoteID, dwell: Duration) async { seen.append(id) }
    func record(_ action: QuoteAction, for id: QuoteID) async { actions.append(action); actionIDs.append(id) }
    func dailyQuote(for day: DayKey) async -> Quote? { nil }
    func remainingUnseen(mode: QuoteFeedMode) async -> Int { 0 }
    func resurfacingCandidate(on day: DayKey) async -> ResurfacedQuote? { nil }
}

@MainActor
struct QuotesViewModelTests {

    static func items(_ range: Range<Int>, liked: Bool = false) -> [QuoteFeedItem] {
        range.map { i in
            QuoteFeedItem(quote: Quote(id: String(format: "q_%06d", i), text: "Söz \(i).", kind: .reflection),
                          reason: .regular, liked: liked, writtenCount: 0)
        }
    }

    static let options: [QuoteModeOption] = [
        QuoteModeOption(mode: .forYou, title: "Sana özel", group: .main, isLocked: false),
        QuoteModeOption(mode: .path("sakin"), title: "Sakin", group: .path, isLocked: false),
        QuoteModeOption(mode: .path("cesur"), title: "Cesur", group: .path, isLocked: true),
        QuoteModeOption(mode: .favorites, title: "Beğendiklerin", group: .list, isLocked: false),
    ]

    static func model(_ engine: FakeQuoteEngine) -> QuotesViewModel {
        QuotesViewModel(engine: engine) { options }
    }

    // MARK: - Yükleme

    @Test("Yükleme: ilk sayfa akışa gelir; boşsa modun durumu, kilitliyse kilit")
    func loadPhases() async {
        let engine = FakeQuoteEngine()
        engine.pages = [Self.items(0..<10)]
        let model = Self.model(engine)
        #expect(model.phase == .loading)
        await model.load()
        #expect(model.phase == .feed && model.items.count == 10)
        #expect(engine.requests.map(\.count) == [QuotesViewModel.pageSize])
        #expect(model.selectedOption?.title == "Sana özel")

        engine.state = .exhausted(alternatives: [.path("sakin")])
        await model.load()
        #expect(model.phase == .ended(.exhausted(alternatives: [.path("sakin")])) && model.items.isEmpty)
        #expect(model.options(for: [.path("sakin"), .theme("yok")]).map(\.title) == ["Sakin"])

        engine.state = .locked
        await model.load()
        #expect(model.phase == .locked)
    }

    @Test("Sayfalama: sona 3 kart kala yeni sayfa; tekrar eden kart eklenmez; akış bitince durum sayfası")
    func paging() async {
        let engine = FakeQuoteEngine()
        engine.pages = [Self.items(0..<10), Self.items(8..<15)]
        let model = Self.model(engine)
        await model.load()

        await model.cardAppeared("q_000003")
        #expect(engine.requests.count == 1)
        await model.cardAppeared("q_000007")
        #expect(engine.requests.count == 2)
        #expect(model.items.map(\.id) == Self.items(0..<15).map(\.id))

        engine.state = .exhausted(alternatives: [])
        await model.cardAppeared("q_000014")
        #expect(model.footer == .exhausted(alternatives: []))
        await model.cardAppeared("q_000014")
        #expect(engine.requests.count == 3) // bittikten sonra istek yok
    }

    @Test("Mod seçimi: kilitli mod paywall açar; diğeri akışı baştan yükler; listeler tek seferde")
    func modeSelection() async {
        let engine = FakeQuoteEngine()
        engine.pages = [Self.items(0..<10), Self.items(20..<22, liked: true)]
        let model = Self.model(engine)
        var paywall = 0
        model.onLocked = { paywall += 1 }
        await model.load()

        await model.select(Self.options[2])
        #expect(paywall == 1 && model.mode == .forYou && engine.requests.count == 1)

        await model.select(Self.options[3])
        #expect(model.mode == .favorites && model.items.map(\.id) == ["q_000020", "q_000021"])
        #expect(engine.requests.last?.count == QuotesViewModel.listLimit)
        await model.cardAppeared("q_000021")
        #expect(engine.requests.count == 2) // listede sayfalama yok
    }

    // MARK: - Kart eylemleri

    @Test("Beğeni kartta hemen değişir ve motora gider; paylaş, yaz, görüldü motora iletilir")
    func cardActions() async {
        let engine = FakeQuoteEngine()
        engine.pages = [Self.items(0..<3)]
        let model = Self.model(engine)
        var written: [QuoteID] = []
        model.onWrite = { written.append($0.id) }
        await model.load()

        await model.toggleLike("q_000001")
        #expect(model.items[1].liked)
        await model.toggleLike("q_000001")
        #expect(!model.items[1].liked)
        await model.didShare("q_000002")
        #expect(engine.actions == [.liked, .unliked, .shared])
        #expect(engine.actionIDs == ["q_000001", "q_000001", "q_000002"])

        model.write("q_000000")
        #expect(written == ["q_000000"])

        await model.onSeen("q_000000", dwell: .seconds(2))
        await model.onSkipped("q_000001")
        #expect(engine.seen == ["q_000000"])
    }

    // MARK: - Saf parçalar

    @Test("Mod menüsü: Sana özel, kullanıcının yolları önce, diğer yollar, türler, listeler; kilit erişimden")
    func modeOptions() {
        func path(_ id: String, active: Bool = true, lang: String = "tr") -> QuotePath {
            QuotePath(id: id, title: id.capitalized, summary: "", kindWeights: nil, premium: false,
                      active: active, addedIn: 1, lang: lang)
        }
        let options = QuoteModeOptions.make(
            paths: [path("filozof"), path("sakin"), path("cesur"), path("eski", active: false), path("en", lang: "en")],
            userPaths: ["sakin", "yok"], lang: "tr",
            isAccessible: { $0 == .forYou || $0 == .path("sakin") || $0 == .favorites || $0 == .written })
        #expect(options.map(\.mode) == [.forYou, .path("sakin"), .path("cesur"), .path("filozof"),
                                        .favorites, .written])
        #expect(options.filter(\.isLocked).map(\.mode) == [.path("cesur"), .path("filozof")])
        #expect(options[1].title == "Sakin")
    }

    @Test("Görünür oran: tam, yarım, dışarıda, üstten taşan")
    func visibleFraction() {
        let h: CGFloat = 800
        #expect(QuoteCardVisibility.fraction(of: CGRect(x: 0, y: 0, width: 300, height: 800), viewportHeight: h) == 1)
        #expect(QuoteCardVisibility.fraction(of: CGRect(x: 0, y: 400, width: 300, height: 800), viewportHeight: h) == 0.5)
        #expect(QuoteCardVisibility.fraction(of: CGRect(x: 0, y: 900, width: 300, height: 800), viewportHeight: h) == 0)
        #expect(QuoteCardVisibility.fraction(of: CGRect(x: 0, y: -600, width: 300, height: 800), viewportHeight: h) == 0.25)
        #expect(QuoteCardVisibility.fraction(of: .zero, viewportHeight: h) == 0)
    }

    @Test("Durum kopyası moda göre ayrışır; yazar künyesi yazarsız sözde yok")
    func stateCopyAndAttribution() {
        let favorites = QuotesStateCopy.make(.empty, mode: .favorites)
        let written = QuotesStateCopy.make(.empty, mode: .written)
        let allSeen = QuotesStateCopy.make(.exhausted(alternatives: []), mode: .forYou)
        let path = QuotesStateCopy.make(.exhausted(alternatives: []), mode: .path("sakin"))
        #expect(Set([favorites, written, allSeen, path]).count == 4)
        #expect(QuotesStateCopy.make(.list(count: 0), mode: .favorites) == favorites)

        #expect(Quote(id: "q", text: "t", kind: .quote, author: "Epiktetos", source: "Encheiridion, 5").attribution
                == "Epiktetos · Encheiridion, 5")
        #expect(Quote(id: "q", text: "t", kind: .affirmation).attribution == nil)
    }
}
