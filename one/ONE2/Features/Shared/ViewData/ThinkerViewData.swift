//
//  ThinkerViewData.swift
//  ONE 2.0
//
//  Düşünür sayfası (07 §5.7) ve düşünür listeleri (Keşfet, Sözler menüsü).
//  Görsel ONE illüstrasyonu; fotoğraf yok.
//

import Foundation

/// Listelerde düşünür (yuvarlak illüstrasyon + ad).
nonisolated struct ThinkerSummaryData: Identifiable, Equatable, Sendable {
    let id: String
    let name: String
    /// İllüstrasyon asset adı.
    let art: String
    let pathName: String
    let isLocked: Bool
}

/// Düşünür sayfasındaki söz satırı; dokununca söze yazı.
nonisolated struct ThinkerQuoteRowData: Identifiable, Equatable, Sendable {
    let id: String
    let text: String
    /// Premium yol düşünüründe ilk üç söz dışındakiler.
    let isLocked: Bool
}

nonisolated struct ThinkerViewData: Identifiable, Equatable, Sendable {
    /// Premium yol düşünürü ücretsiz kullanıcıda: ilk üç söz açık.
    static let freeQuoteLimit = 3

    let id: String
    let name: String
    /// Mono dönem ("MS 4–65").
    let era: String
    let pathID: String
    /// Mono yol adı ("Stoacılar"; etikette büyük harf).
    let pathName: String
    /// "Ana fikri" tek cümle (Literata).
    let idea: String
    /// 3–4 cümle; "Devamı" ile açılır.
    let bio: String
    let art: String
    let isFollowed: Bool
    /// "Bu hafta onunla" etkin (7 gün sürer).
    let isThisWeek: Bool
    let isPathLocked: Bool
    let quotes: [ThinkerQuoteRowData]
    /// Bu düşünürün sözlerine yazılanlar.
    let reflections: [HistoryItem]
    let similar: [ThinkerSummaryData]
}
