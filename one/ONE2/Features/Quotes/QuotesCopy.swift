//
//  QuotesCopy.swift
//  ONE 2.0
//
//  Sözler ekranının saf metin kararları: durum kartı kopyası ve söz künyesi.
//

import Foundation

/// Durum kartının kopyası; saf, test edilebilir.
nonisolated struct QuotesStateCopy: Hashable, Sendable {
    let title: String
    let message: String

    static func make(_ state: QuoteFeedState, mode: QuoteFeedMode) -> QuotesStateCopy {
        switch state {
        case .locked:
            return .init(title: NSLocalizedString("one2.quotes.state.locked.title", comment: "Quotes: premium mode"),
                         message: NSLocalizedString("one2.quotes.state.locked.body", comment: "Quotes: premium mode body"))
        case .exhausted where mode == .forYou:
            return .init(title: NSLocalizedString("one2.quotes.state.allSeen.title", comment: "Quotes: every quote seen"),
                         message: NSLocalizedString("one2.quotes.state.allSeen.body", comment: "Quotes: every quote seen body"))
        case .exhausted:
            return .init(title: NSLocalizedString("one2.quotes.state.exhausted.title", comment: "Quotes: this path fully seen"),
                         message: NSLocalizedString("one2.quotes.state.exhausted.body", comment: "Quotes: try another path"))
        case .empty where mode == .favorites, .list where mode == .favorites:
            return .init(title: NSLocalizedString("one2.quotes.state.favorites.title", comment: "Quotes: no liked quotes"),
                         message: NSLocalizedString("one2.quotes.state.favorites.body", comment: "Quotes: liked quotes collect here"))
        case .empty where mode == .written, .list where mode == .written:
            return .init(title: NSLocalizedString("one2.quotes.state.written.title", comment: "Quotes: none written about"),
                         message: NSLocalizedString("one2.quotes.state.written.body", comment: "Quotes: written quotes collect here"))
        case .empty, .list:
            return .init(title: NSLocalizedString("one2.quotes.state.empty.title", comment: "Quotes: no quotes here"),
                         message: NSLocalizedString("one2.quotes.state.empty.body", comment: "Quotes: look at another section"))
        case .available, .revisiting:
            return .init(title: NSLocalizedString("one2.quotes.state.pause.title", comment: "Quotes: session ran out of cards"),
                         message: NSLocalizedString("one2.quotes.state.pause.body", comment: "Quotes: come back later"))
        }
    }
}

extension Quote {
    /// "Epiktetos · Encheiridion, 5". Yazarsız türlerde `nil`.
    var attribution: String? {
        let parts = [author, source].compactMap { $0?.isEmpty == false ? $0 : nil }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }
}
