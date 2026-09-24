//
//  ExploreViewData.swift
//  ONE 2.0
//
//  Keşfet: öne çıkan kart ve içerik karoları (components/FeaturedCard.md,
//  ContentCard.md).
//

import Foundation

nonisolated enum ContentCardKind: String, Hashable, Sendable {
    case guidedJournal, exercise, theme, quoteCollection, checkIn
}

nonisolated enum ContentBadge: String, Hashable, Sendable {
    case new, featured
}

/// Kemer rengi türü söyler: sabah, akşam ya da nötr.
nonisolated enum ContentTone: String, Hashable, Sendable {
    case sabah, aksam, neutral
}

nonisolated struct FeaturedData: Identifiable, Equatable, Sendable {
    let id: String
    let start: Date
    let end: Date
    let title: String
    let summary: String
    /// ONE'ın kendi çizimi; şimdilik SF Symbol yer tutucusu.
    let art: ONE2Icon
    let isLocked: Bool
}

nonisolated struct ContentCardData: Identifiable, Equatable, Sendable {
    let id: String
    let kind: ContentCardKind
    let tone: ContentTone
    let category: String
    let title: String
    let summary: String
    let isLocked: Bool
    let badge: ContentBadge?
    /// Rehberli akışlarda adım sayısı ve süre (dakika).
    let steps: Int?
    let minutes: Int?
}

nonisolated struct ContentRowData: Identifiable, Equatable, Sendable {
    let id: String
    let title: String
    let items: [ContentCardData]
}

nonisolated struct ExploreData: Equatable, Sendable {
    let featured: FeaturedData?
    let rows: [ContentRowData]
}
