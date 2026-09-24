//
//  JourneyViewData.swift
//  ONE 2.0
//
//  Yolculuk: gün başlıkları altında girdiler (components/HistoryCard.md).
//  Legacy "ONE 1" kartları v3 mood'u taşır (yalnız görünüm; ADR-001 §7).
//

import Foundation

nonisolated struct HistoryDay: Identifiable, Equatable, Sendable {
    let day: DayKey
    let items: [HistoryItem]

    var id: DayKey { day }
}

nonisolated struct HistoryItem: Identifiable, Equatable, Sendable {
    enum Content: Equatable, Sendable {
        case checkIn(CheckInSummary)
        /// Günlük: başlık (soru ya da "Boş sayfa"), ilk satırlar, kelime sayısı.
        case journal(title: String, excerpt: String, wordCount: Int)
        case quoteReflection(quoteID: String, quote: String, source: String, excerpt: String)
        /// Fotoğraf anısı; yerel dosya ya da asset adı.
        case photo(asset: String)
        /// v3 anı kartı: `V3Mood` ham değeri, not, şarkı.
        case legacy(v3Mood: String, note: String?, song: String?)
    }

    let id: String
    let time: Date
    let content: Content
}

nonisolated enum JourneyPeriod: String, CaseIterable, Hashable, Sendable {
    case days, weeks, months, years
}
