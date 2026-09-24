//
//  TodaySource.swift
//  ONE 2.0
//
//  Bugün ekranının veri kapısı: hafta şeridi ve gün başına `TodayData`.
//  Ekran hangi günü gösterirse onu ister (hafta şeridinde seçilen gün).
//  UX-4'te fixture; UX-11'de motor adaptörü aynı şekli doldurur.
//

import Foundation

nonisolated struct TodaySource: Sendable {
    let today: DayKey
    /// Eskiden yeniye; sonuncusu bugünün haftası.
    let weeks: [WeekStripData]
    let isOffline: Bool
    let day: @Sendable (DayKey) -> Loadable<TodayData>

    init(
        today: DayKey,
        weeks: [WeekStripData],
        isOffline: Bool = false,
        day: @escaping @Sendable (DayKey) -> Loadable<TodayData>
    ) {
        self.today = today
        self.weeks = weeks
        self.isOffline = isOffline
        self.day = day
    }
}
