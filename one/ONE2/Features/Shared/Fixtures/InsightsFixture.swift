//
//  InsightsFixture.swift
//  ONE 2.0
//
//  ÖRNEK VERİ. Eğilimler: boş (hiç kayıt yok), az (4 check-in: çizgi
//  hazır, diğer kartlar eşik altında), çok (her kart hazır).
//

import Foundation

nonisolated enum InsightsFixture {

    private static var today: DayKey { FixtureClock.today }

    /// ScreenEgilimler.preview.html'deki 14 günlük seri.
    static let fourteenDays: TrendSeries = {
        let scores: [Double] = [3, 2, 3, 4, 4, 5, 3, 2, 3, 4, 4, 3, 5, 4]
        let points = scores.enumerated().map { i, s in
            TrendPoint(day: today.adding(days: i - 13), score: s, isToday: i == 13)
        }
        return TrendSeries(period: .days14, points: points)
    }()

    static let shares: [EmotionShare] = [
        EmotionShare(family: .nese, share: 0.42, count: 21),
        EmotionShare(family: .huzur, share: 0.28, count: 14),
        EmotionShare(family: .kaygi, share: 0.18, count: 9),
        EmotionShare(family: .yorgun, share: 0.12, count: 6),
    ]

    static let many = InsightsData(
        period: .days14,
        checkInCount: 38,
        moodLine: .ready(fourteenDays),
        average: .ready(AverageData(average: 3.5, delta: 0.3)),
        distribution: .ready(shares),
        tagRelations: .ready([TagRelation(tag: "Uyku", withTag: 2.8, withoutTag: 3.6, sampleCount: 9)]),
        writing: .ready(WritingStats(entries: 42, words: 6_380, longestStreak: 21)),
        onThisDay: .locked,
        changePairs: .locked
    )

    static let few = InsightsData(
        period: .days14,
        checkInCount: 4,
        moodLine: .ready(TrendSeries(period: .days14, points: Array(fourteenDays.points.suffix(4)))),
        average: .insufficient(required: InsightThreshold.average, current: 4),
        distribution: .insufficient(required: InsightThreshold.distribution, current: 4),
        tagRelations: .insufficient(required: InsightThreshold.tagRelation, current: 4),
        writing: .ready(WritingStats(entries: 2, words: 212, longestStreak: 2)),
        onThisDay: .insufficient(required: 1, current: 0),
        changePairs: .insufficient(required: 2, current: 0)
    )

    static let empty = InsightsData(
        period: .days14,
        checkInCount: 0,
        moodLine: .insufficient(required: InsightThreshold.moodLine, current: 0),
        average: .insufficient(required: InsightThreshold.average, current: 0),
        distribution: .insufficient(required: InsightThreshold.distribution, current: 0),
        tagRelations: .insufficient(required: InsightThreshold.tagRelation, current: 0),
        writing: .insufficient(required: 1, current: 0),
        onThisDay: .insufficient(required: 1, current: 0),
        changePairs: .insufficient(required: 2, current: 0)
    )
}
