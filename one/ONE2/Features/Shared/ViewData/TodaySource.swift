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
    /// Çevrimdışı ve önbellekteki içerik eski: üstte uyarı şeridi (07 §6).
    /// Yalnız çevrimdışı olmak şerit göstermez; yerel veri eksiksizdir.
    let isContentStale: Bool
    let day: @Sendable (DayKey) -> Loadable<TodayData>

    init(
        today: DayKey,
        weeks: [WeekStripData],
        isContentStale: Bool = false,
        day: @escaping @Sendable (DayKey) -> Loadable<TodayData>
    ) {
        self.today = today
        self.weeks = weeks
        self.isContentStale = isContentStale
        self.day = day
    }
}
