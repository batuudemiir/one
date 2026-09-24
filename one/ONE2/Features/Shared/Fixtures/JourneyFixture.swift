//
//  JourneyFixture.swift
//  ONE 2.0
//
//  ÖRNEK VERİ. Yolculuk: bugün, dün ve daha eski günler; bir legacy
//  "ONE 1" kartı (v3 mood ham değeri).
//

import Foundation

nonisolated enum JourneyFixture {

    private static var today: DayKey { FixtureClock.today }

    static let todayItems: [HistoryItem] = [
        HistoryItem(id: "fx_h_1", time: FixtureClock.daysAgo(0, 8, 12), content: .photo(asset: "fx_memory_street")),
        HistoryItem(id: "fx_h_2", time: FixtureClock.daysAgo(0, 11, 39), content: .checkIn(CheckInSummary(
            id: "fx_checkin_h2", time: FixtureClock.daysAgo(0, 11, 39), slot: .daily, score: 5,
            emotions: [EmotionCatalogFixture.emotion("nese.minnettar")], causes: ["Aile"], echo: nil))),
        HistoryItem(id: "fx_h_3", time: FixtureClock.daysAgo(0, 16, 20), content: .quoteReflection(
            quoteID: "fx_q_001", quote: "Acele eden, aynı yolu iki kez yürür.", source: "Atasözü",
            excerpt: "Bugün iki kez aynı hatayı yaptım çünkü ilkinde durup bakmadım.")),
    ]

    static let yesterdayItems: [HistoryItem] = [
        HistoryItem(id: "fx_h_4", time: FixtureClock.daysAgo(1, 1, 53), content: .journal(
            title: "Akşam refleksiyonu",
            excerpt: "Sabah otobüsü kaçırdım ve ilk kez koşmadım. Durakta on iki dakika bekledim. Kimse beklemedi beni ama ben kendimi bekledim.",
            wordCount: 146)),
    ]

    static let olderItems: [HistoryItem] = [
        HistoryItem(id: "fx_h_5", time: FixtureClock.daysAgo(3, 21, 5), content: .checkIn(CheckInSummary(
            id: "fx_checkin_h5", time: FixtureClock.daysAgo(3, 21, 5), slot: .daily, score: 2,
            emotions: [EmotionCatalogFixture.emotion("kaygi.gergin"), EmotionCatalogFixture.emotion("yorgun.tukenmis")],
            causes: ["İş"], echo: nil))),
        HistoryItem(id: "fx_h_6", time: FixtureClock.daysAgo(400, 22, 10), content: .legacy(
            v3Mood: "huzurlu", note: "Deniz kenarında uzun yürüyüş.", song: nil)),
    ]

    static let many: [HistoryDay] = [
        HistoryDay(day: today, items: todayItems),
        HistoryDay(day: today.adding(days: -1), items: yesterdayItems),
        HistoryDay(day: today.adding(days: -3), items: [olderItems[0]]),
        HistoryDay(day: today.adding(days: -400), items: [olderItems[1]]),
    ]

    static let few: [HistoryDay] = [
        HistoryDay(day: today, items: [todayItems[1]]),
    ]

    static let empty: [HistoryDay] = []
}
