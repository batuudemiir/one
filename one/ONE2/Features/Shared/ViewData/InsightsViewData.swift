//
//  InsightsViewData.swift
//  ONE 2.0
//
//  Eğilimler kartları (E10). Her kart kendi eşiğini taşır: veri yetmezse
//  "N check-in daha" gösterir. Hiç veri yoksa ekranın tamamı ScoreScale boş
//  durumuna düşer (`InsightsData.isEmpty`).
//

import Foundation

/// Bir içgörü kartının hâli.
nonisolated enum InsightState<Value: Equatable & Sendable>: Equatable, Sendable {
    case ready(Value)
    /// `required`: kartın eşiği; `current`: mevcut kayıt sayısı.
    case insufficient(required: Int, current: Int)
    /// Premium kilitli: bulanık değil; başlık + açıklama + "ONE+ ile aç".
    case locked

    var remaining: Int? {
        if case .insufficient(let required, let current) = self { return max(required - current, 0) }
        return nil
    }
}

/// E10 minimum veri eşikleri.
nonisolated enum InsightThreshold {
    static let moodLine = 3
    static let average = 7
    static let distribution = 5
    static let tagRelation = 21
}

nonisolated enum TrendPeriod: String, CaseIterable, Hashable, Sendable {
    case days14, days30, months, years
}

nonisolated struct TrendPoint: Identifiable, Equatable, Sendable {
    let day: DayKey
    /// Gün ortalaması, 1…5.
    let score: Double
    let isToday: Bool

    var id: DayKey { day }
}

nonisolated struct TrendSeries: Equatable, Sendable {
    let period: TrendPeriod
    let points: [TrendPoint]
}

nonisolated struct AverageData: Equatable, Sendable {
    let average: Double
    /// Bir önceki döneme göre fark; ilk dönemde nil.
    let delta: Double?
}

nonisolated struct EmotionShare: Identifiable, Equatable, Sendable {
    let family: ONE2EmotionFamily
    /// 0…1.
    let share: Double
    let count: Int

    var id: ONE2EmotionFamily { family }
}

/// "Uyku etiketli günlerde ortalama 2,8, diğerlerinde 3,6" (yalnız gözlem).
nonisolated struct TagRelation: Identifiable, Equatable, Sendable {
    let tag: String
    let withTag: Double
    let withoutTag: Double
    let sampleCount: Int

    var id: String { tag }
}

nonisolated struct WritingStats: Equatable, Sendable {
    let entries: Int
    let words: Int
    let longestStreak: Int
}

/// Aynı soruya ya da söze farklı zamanlarda verilen iki cevap.
nonisolated struct ChangePair: Identifiable, Equatable, Sendable {
    let id: String
    let prompt: String
    let earlier: HistoryItem
    let later: HistoryItem
}

nonisolated struct InsightsData: Equatable, Sendable {
    let period: TrendPeriod
    let checkInCount: Int
    let moodLine: InsightState<TrendSeries>
    let average: InsightState<AverageData>
    let distribution: InsightState<[EmotionShare]>
    let tagRelations: InsightState<[TagRelation]>
    let writing: InsightState<WritingStats>
    let onThisDay: InsightState<[HistoryItem]>
    let changePairs: InsightState<[ChangePair]>

    /// Hiç check-in ve girdi yok: ekran boş duruma düşer.
    var isEmpty: Bool {
        guard checkInCount == 0 else { return false }
        if case .ready = writing { return false }
        return true
    }
}
