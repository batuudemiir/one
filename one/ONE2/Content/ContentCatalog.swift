//
//  ContentCatalog.swift
//  ONE 2.0
//
//  Yüklenmiş ve doğrulanmış içeriğin tamamı; motorların tek girdisi (E1).
//  Değer tipi: motorlar bir anlık görüntü alır, içerik güncellenince yenisini.
//

import Foundation

nonisolated struct ContentCatalog: Sendable {
    let manifest: ContentManifest
    let quotes: [Quote]
    let prompts: [Prompt]
    /// Takvime bağlı temalar (`week` dolu).
    let themes: [WeeklyTheme]
    let evergreenThemes: [WeeklyTheme]
    let guided: [GuidedJournal]
    let echoes: [Echo]
    let emotions: [EmotionDefinition]
    let causes: [CauseDefinition]
    let badges: [BadgeDefinition]
    let paths: [QuotePath]

    private let quoteIndex: [QuoteID: Quote]
    private let promptIndex: [PromptID: Prompt]
    private let themeByWeek: [String: WeeklyTheme]

    init(manifest: ContentManifest, quotes: [Quote] = [], prompts: [Prompt] = [], themes: [WeeklyTheme] = [],
         evergreenThemes: [WeeklyTheme] = [], guided: [GuidedJournal] = [], echoes: [Echo] = [],
         emotions: [EmotionDefinition] = [], causes: [CauseDefinition] = [], badges: [BadgeDefinition] = [],
         paths: [QuotePath] = []) {
        self.manifest = manifest
        self.quotes = quotes; self.prompts = prompts; self.themes = themes
        self.evergreenThemes = evergreenThemes; self.guided = guided; self.echoes = echoes
        self.emotions = emotions; self.causes = causes; self.badges = badges; self.paths = paths
        quoteIndex = Dictionary(quotes.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        promptIndex = Dictionary(prompts.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        themeByWeek = Dictionary(themes.compactMap { t in t.week.map { ($0, t) } }, uniquingKeysWith: { a, _ in a })
    }

    var contentVersion: Int { manifest.contentVersion }

    /// Son içerik güncellemesiyle eklendi mi (Keşfet "Yeni" rozeti).
    func isNew<T: ContentItem>(_ item: T) -> Bool {
        contentVersion > 1 && item.addedIn >= contentVersion
    }

    func quote(_ id: QuoteID) -> Quote? { quoteIndex[id] }
    func prompt(_ id: PromptID) -> Prompt? { promptIndex[id] }
    /// `2026-W40` biçiminde ISO hafta.
    func theme(week: String) -> WeeklyTheme? { themeByWeek[week] }
    func theme(id: String) -> WeeklyTheme? {
        themes.first { $0.id == id } ?? evergreenThemes.first { $0.id == id }
    }

    /// Duygu ID'si → aile.
    func emotionFamily(_ emotionID: String) -> String? {
        emotions.first { $0.id == emotionID }?.family
    }

    /// Aynı türde tekrarlanan ID'ler. Boş değilse katalog reddedilir.
    var duplicateIDs: [String] {
        let groups: [[String]] = [
            quotes.map(\.id), prompts.map(\.id), (themes + evergreenThemes).map(\.id), guided.map(\.id),
            echoes.map(\.id), emotions.map(\.id), causes.map(\.id), badges.map(\.id), paths.map(\.id),
        ]
        return groups.flatMap { ids in
            Dictionary(grouping: ids, by: { $0 }).filter { $0.value.count > 1 }.keys
        }.sorted()
    }

    static let empty = ContentCatalog(
        manifest: ContentManifest(schemaVersion: "1.0", contentVersion: 0, generatedAt: "", files: [])
    )
}
