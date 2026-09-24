//
//  ExploreFixture.swift
//  ONE 2.0
//
//  ÖRNEK VERİ. Keşfet: öne çıkan hafta ve içerik satırları.
//

import Foundation

nonisolated enum ExploreFixture {

    static let featured = FeaturedData(
        id: "fx_featured_minnet",
        start: FixtureClock.date(2026, 9, 21),
        end: FixtureClock.date(2026, 9, 27),
        title: "Minnet haftası",
        summary: "Yedi gün, yedi küçük soru: seni bugün ayakta tutan neydi?",
        art: .leaf,
        isLocked: false
    )

    static let evening = ContentCardData(
        id: "fx_content_evening", kind: .guidedJournal, tone: .aksam, category: "Günlük",
        title: "Akşamı yavaşlat", summary: "Günü dört soruyla kapat, uykuya hafif gir.",
        isLocked: false, badge: .new, steps: 4, minutes: 5)

    static let anxiety = ContentCardData(
        id: "fx_content_anxiety", kind: .guidedJournal, tone: .neutral, category: "Rehberli",
        title: "Kaygıyı yazıya dök", summary: "Kafandakini sayfaya boşalt, sonra ayıkla.",
        isLocked: true, badge: .featured, steps: 6, minutes: 8)

    static let morning = ContentCardData(
        id: "fx_content_morning", kind: .exercise, tone: .sabah, category: "Sabah",
        title: "Bir niyet seç", summary: "Güne tek bir cümleyle başla.",
        isLocked: false, badge: nil, steps: 3, minutes: 3)

    static let collection = ContentCardData(
        id: "fx_content_quotes_calm", kind: .quoteCollection, tone: .neutral, category: "Söz koleksiyonu",
        title: "Sakin sözler", summary: "Yavaşlamayı hatırlatan on iki söz.",
        isLocked: false, badge: nil, steps: nil, minutes: nil)

    static let many = ExploreData(
        featured: featured,
        rows: [
            ContentRowData(id: "fx_row_foryou", title: "Sana özel", items: [evening, anxiety, morning]),
            ContentRowData(id: "fx_row_guided", title: "Rehberli günlükler", items: [anxiety, evening]),
            ContentRowData(id: "fx_row_morning", title: "Sabah", items: [morning]),
            ContentRowData(id: "fx_row_evening", title: "Akşam", items: [evening]),
            ContentRowData(id: "fx_row_quotes", title: "Söz koleksiyonları", items: [collection]),
        ]
    )

    static let few = ExploreData(
        featured: featured,
        rows: [ContentRowData(id: "fx_row_foryou", title: "Sana özel", items: [evening, anxiety])]
    )

    static let empty = ExploreData(featured: nil, rows: [])
}
