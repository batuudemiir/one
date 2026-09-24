//
//  QuotesViewData.swift
//  ONE 2.0
//
//  Sözler akışı. `QuoteFeedModeData` E2.5 `QuoteFeedMode`'un aynası;
//  premium yollar kilitli (E15, karar 4: ücretsiz "Sana özel" + 1 yol).
//

import Foundation

nonisolated enum QuoteCardKind: String, Hashable, Sendable {
    case affirmation, quote, proverb, thought
}

nonisolated enum QuoteBackground: Hashable, Sendable {
    /// Paketteki fotoğraf seti; ad asset adı.
    case photo(String)
    /// Düz renk; değer bir `emo-*` / `score-*` token adı.
    case token(String)
    /// Kullanıcının seçtiği fotoğraf (yerel dosya).
    case userPhoto(URL)
}

nonisolated struct QuoteCardData: Identifiable, Equatable, Sendable {
    let id: String
    let text: String
    let source: String
    let kind: QuoteCardKind
    let background: QuoteBackground
    /// "Bu söze 2 kez yazdın"; 0 ise satır yok.
    let writtenCount: Int
    let isLiked: Bool
}

nonisolated enum QuoteFeedModeData: Hashable, Sendable {
    case forYou
    case path(id: String, title: String, isLocked: Bool)
    case kind(QuoteCardKind)
    case favorites
    case written
}
