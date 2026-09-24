//
//  UXFixtureContent.swift
//  ONE 2.0
//
//  `ux_fixtures.tr.json`: önizleme ve testlerin örnek içeriği (duygular,
//  pratikler, örnek sorular, yankılar). Gerçek içerik motordan gelir;
//  bu dosya UX-11'den sonra yalnız #Preview ve testlerde kalır.
//

import Foundation

nonisolated struct UXFixtureContent: Decodable, Sendable {
    struct Theme: Decodable, Sendable {
        let name: String
        let dayIndex: Int
        let prompt: String
        let writtenFirstLine: String?
    }

    struct Quote: Decodable, Sendable {
        let id: String
        let text: String
        let attribution: String?
    }

    var streak: Int = 0
    var practices: [FlowOptionViewData] = []
    var theme: Theme?
    var echoes: [String: String] = [:]
    var dailyPrompts: [String] = []
    var previousAnswer: String?
    var quote: Quote?
    var emotions: [FlowOptionViewData] = []
    var causes: [FlowOptionViewData] = []
    var morningList: [String] = []
    var morningDoneItems: [Int] = []
    var morningFocus: String = ""
    var moodEmotions: [String] = []

    init() {}

    func echo(_ flow: FlowKind) -> String { echoes[flow.rawValue] ?? "" }
}

nonisolated enum UXFixtures {
    static let resourceName = "ux_fixtures.tr"

    /// Uygulama paketindeki fixture içeriği; bulunamazsa boş (ekranlar boş
    /// durumlarını gösterir, çökmez).
    static let content: UXFixtureContent = load(from: Bundle.main)

    static func load(from bundle: Bundle) -> UXFixtureContent {
        guard let url = bundle.url(forResource: resourceName, withExtension: "json") else { return UXFixtureContent() }
        return load(url: url)
    }

    static func load(url: URL) -> UXFixtureContent {
        guard let data = try? Data(contentsOf: url),
              let content = try? JSONDecoder().decode(UXFixtureContent.self, from: data) else { return UXFixtureContent() }
        return content
    }
}
