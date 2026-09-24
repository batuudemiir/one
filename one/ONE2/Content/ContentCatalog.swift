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
    let thinkers: [Thinker]
    /// v1 dosyasında düşünüre eşlenemeyen `quote` öğeleri: pasifleşti (08 §3.2).
    let unmatchedAuthors: [(quoteID: QuoteID, name: String)]

    private let quoteIndex: [QuoteID: Quote]
    private let promptIndex: [PromptID: Prompt]
    private let themeByWeek: [String: WeeklyTheme]
    private let thinkerIndex: [ThinkerID: Thinker]

    init(manifest: ContentManifest, quotes: [Quote] = [], prompts: [Prompt] = [], themes: [WeeklyTheme] = [],
         evergreenThemes: [WeeklyTheme] = [], guided: [GuidedJournal] = [], echoes: [Echo] = [],
         emotions: [EmotionDefinition] = [], causes: [CauseDefinition] = [], badges: [BadgeDefinition] = [],
         paths: [QuotePath] = [], thinkers: [Thinker] = []) {
        self.manifest = manifest
        let thinkerIndex = Dictionary(thinkers.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        let (quotes, unmatched) = Self.resolveAuthors(quotes, thinkers: thinkers, index: thinkerIndex)
        self.thinkers = thinkers; self.thinkerIndex = thinkerIndex; self.unmatchedAuthors = unmatched
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
    func thinker(_ id: ThinkerID) -> Thinker? { thinkerIndex[id] }
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
            thinkers.map(\.id),
        ]
        return groups.flatMap { ids in
            Dictionary(grouping: ids, by: { $0 }).filter { $0.value.count > 1 }.keys
        }.sorted()
    }

    /// v1 ad metnini düşünüre bağlar, ad satırını ve boş yolları düşünürden
    /// doldurur (08 §3.2). Eşleşmeyen `quote` pasifleşir ve listelenir.
    static func resolveAuthors(_ quotes: [Quote], thinkers: [Thinker],
                               index: [ThinkerID: Thinker]) -> ([Quote], [(quoteID: QuoteID, name: String)]) {
        var names: [String: ThinkerID] = [:]
        for t in thinkers {
            for n in [t.displayName, t.shortName] + t.aliases { names[ThinkerNames.key(n)] = t.id }
        }
        var unmatched: [(quoteID: QuoteID, name: String)] = []
        let resolved = quotes.map { original -> Quote in
            var q = original
            if q.authorID == nil, let name = q.legacyAuthorName {
                q.authorID = names[ThinkerNames.key(name)] ?? ThinkerNames.id(for: name)
                if q.authorID == nil, q.kind == .quote {
                    q.active = false
                    unmatched.append((q.id, name))
                }
            }
            if let id = q.authorID, let t = index[id] {
                q.attribution = t.displayName
                if q.paths.isEmpty { q.paths = t.pathIDs }
            } else if q.attribution == nil {
                q.attribution = q.legacyAuthorName
            }
            return q
        }
        return (resolved, unmatched)
    }

    static let empty = ContentCatalog(
        manifest: ContentManifest(schemaVersion: "1.0", contentVersion: 0, generatedAt: "", files: [])
    )
}
