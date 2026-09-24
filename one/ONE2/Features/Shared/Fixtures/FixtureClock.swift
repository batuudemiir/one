//
//  FixtureClock.swift
//  ONE 2.0
//
//  ÖRNEK VERİ. Tüm fixture'lar tek bir güne bağlı: Perşembe, 24 Eylül 2026,
//  20:15, İstanbul. Önizlemeler ve testler aynı "şimdi"yi görür.
//

import Foundation

nonisolated enum FixtureClock {
    static let timeZone = TimeZone(identifier: "Europe/Istanbul")!

    static let calendar: Calendar = {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = timeZone
        cal.firstWeekday = 2
        cal.locale = Locale(identifier: "tr_TR")
        return cal
    }()

    /// 2026-09-24 20:15 (perşembe akşamı).
    static let now: Date = date(2026, 9, 24, 20, 15)

    static let clock = FixedClock(now, timeZone: timeZone)

    static var today: DayKey { DayKey(date: now, calendar: calendar) }

    static func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 12, _ min: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: y, month: m, day: d, hour: h, minute: min))!
    }

    /// Bugünden `days` önceki gün, verilen saatte.
    static func daysAgo(_ days: Int, _ h: Int, _ min: Int = 0) -> Date {
        let d = calendar.date(byAdding: .day, value: -days, to: now)!
        let c = calendar.dateComponents([.year, .month, .day], from: d)
        return date(c.year!, c.month!, c.day!, h, min)
    }
}
