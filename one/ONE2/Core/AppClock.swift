//
//  AppClock.swift
//  ONE 2.0
//
//  "Şimdi" ve "bugün" tek kaynaktan gelir (ADR-001 §4). `dayKey` ve seri
//  hesabı `Date()` / `Calendar.current` çağırmaz; testte sabit bir saat verilir.
//

import Foundation

nonisolated protocol AppClock: Sendable {
    var now: Date { get }
    var calendar: Calendar { get }
}

nonisolated extension AppClock {
    var today: DayKey { DayKey(date: now, calendar: calendar) }

    var timeZoneID: String { calendar.timeZone.identifier }
}

/// Cihaz saati ve kullanıcının o anki takvimi.
nonisolated struct SystemClock: AppClock {
    var now: Date { Date() }
    var calendar: Calendar { .autoupdatingCurrent }
}

/// Testler ve önizlemeler için sabit saat.
nonisolated struct FixedClock: AppClock {
    let now: Date
    let calendar: Calendar

    init(_ now: Date, timeZone: TimeZone = TimeZone(identifier: "Europe/Istanbul")!) {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = timeZone
        self.now = now
        self.calendar = cal
    }
}
