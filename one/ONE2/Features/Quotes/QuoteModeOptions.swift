//
//  QuoteModeOptions.swift
//  ONE 2.0
//
//  Sözler mod hapının menüsü (UX-7): Sana özel, yollar, türler,
//  Beğendiklerin, Yazdıkların. Kilitli seçenek menüde kalır; seçilince
//  paywall açılır. Saf: katalog + profil + erişim → seçenek listesi.
//

import Foundation

nonisolated struct QuoteModeOption: Hashable, Sendable, Identifiable {
    enum Group: Hashable, Sendable { case main, path, kind, list }

    let mode: QuoteFeedMode
    let title: String
    let group: Group
    let isLocked: Bool

    var id: String { mode.key }
}

nonisolated enum QuoteModeOptions {

    /// - Parameters:
    ///   - paths: katalogdaki söz yolları.
    ///   - userPaths: kullanıcının seçtiği yollar (sırası korunur, önce gelir).
    ///   - isAccessible: motorun erişim kuralı (ücretsiz: Sana özel + ilk yol).
    static func make(paths: [QuotePath], userPaths: [String], lang: String,
                     isAccessible: (QuoteFeedMode) -> Bool) -> [QuoteModeOption] {
        func option(_ mode: QuoteFeedMode, _ title: String, _ group: QuoteModeOption.Group) -> QuoteModeOption {
            QuoteModeOption(mode: mode, title: title, group: group, isLocked: !isAccessible(mode))
        }
        let available = paths.filter { $0.active && $0.lang == lang }
        let own = userPaths.compactMap { id in available.first { $0.id == id } }
        let others = available.filter { !userPaths.contains($0.id) }.sorted { $0.id < $1.id }

        return [option(.forYou, NSLocalizedString("one2.quotes.mode.forYou", comment: "Quotes feed mode: personalised"), .main)]
            + (own + others).map { option(.path($0.id), $0.title, .path) }
            + QuoteKind.allCases.map { option(.kind($0), title(for: $0), .kind) }
            + [option(.favorites, NSLocalizedString("one2.quotes.mode.favorites", comment: "Quotes feed mode: liked quotes"), .list),
               option(.written, NSLocalizedString("one2.quotes.mode.written", comment: "Quotes feed mode: quotes the user wrote about"), .list)]
    }

    static func title(for kind: QuoteKind) -> String {
        switch kind {
        case .quote:       return NSLocalizedString("one2.quotes.kind.quote", comment: "Quote kind: attributed quote")
        case .affirmation: return NSLocalizedString("one2.quotes.kind.affirmation", comment: "Quote kind: affirmation")
        case .proverb:     return NSLocalizedString("one2.quotes.kind.proverb", comment: "Quote kind: proverb")
        case .reflection:  return NSLocalizedString("one2.quotes.kind.reflection", comment: "Quote kind: ONE reflection line")
        }
    }

    /// Tür ikonu (dekoratif; tür adı erişilebilirlikte metinle söylenir).
    static func symbol(for kind: QuoteKind) -> String {
        switch kind {
        case .quote:       return "quote.opening"
        case .affirmation: return "sun.max"
        case .proverb:     return "text.book.closed"
        case .reflection:  return "lightbulb"
        }
    }
}
