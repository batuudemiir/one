//
//  ThemeCalendar.swift
//  ONE 2.0
//
//  Haftalık tema takvimi (04_arka_plan_motorlari.md › E5). Saf: katalog +
//  gün + (evergreen için) kullanıcı geçmişi → tema.
//
//  - Hafta ISO 8601, pazartesi başlar. Hesap `DayKey` üzerinden yapılır;
//    `DayKey` zaten cihazın yerel günü olduğu için saat dilimi burada tekrar
//    devreye girmez.
//  - Herkes aynı haftada aynı temayı görür (`t_2026w40`).
//  - O hafta için tema yoksa evergreen havuzundan, kullanıcının önceki
//    haftalarda görmediği bir tema seçilir. Seçim kullanıcı tuzu + hafta ile
//    tohumlanır ve hafta boyunca sabit kalır (bu hafta görülmesi seçimi
//    değiştirmez).
//  - Gün kilidi: haftanın geçmiş günleri ve bugün açık, gelecek günler kilitli.
//

import Foundation

nonisolated struct ISOWeek: Hashable, Comparable, Sendable, CustomStringConvertible {
    let year: Int
    let week: Int

    init(year: Int, week: Int) {
        self.year = year; self.week = week
    }

    init(containing day: DayKey) {
        let date = day.startDate(in: Self.calendar) ?? Date(timeIntervalSince1970: 0)
        let c = Self.calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        year = c.yearForWeekOfYear ?? day.year
        week = c.weekOfYear ?? 1
    }

    /// `2026-W40`.
    init?(_ string: String) {
        let parts = string.split(separator: "-")
        guard parts.count == 2, parts[1].hasPrefix("W"),
              let y = Int(parts[0]), let w = Int(parts[1].dropFirst()), (1...53).contains(w) else { return nil }
        self.init(year: y, week: w)
        guard monday.map({ ISOWeek(containing: $0) == self }) == true else { return nil }
    }

    var description: String { String(format: "%04d-W%02d", year, week) }

    /// Takvim temasının ID'si: `t_2026w40`.
    var themeID: String { String(format: "t_%04dw%02d", year, week) }

    var monday: DayKey? {
        var c = DateComponents()
        c.yearForWeekOfYear = year; c.weekOfYear = week; c.weekday = 2
        return Self.calendar.date(from: c).map { DayKey(date: $0, calendar: Self.calendar) }
    }

    var days: [DayKey] {
        guard let monday else { return [] }
        return (0..<7).map { monday.adding(days: $0) }
    }

    func adding(weeks: Int) -> ISOWeek {
        guard let monday else { return self }
        return ISOWeek(containing: monday.adding(days: 7 * weeks))
    }

    static func < (a: ISOWeek, b: ISOWeek) -> Bool { (a.year, a.week) < (b.year, b.week) }

    /// ISO 8601 takvimi, UTC: yalnız gün/hafta aritmetiği için.
    private static let calendar: Calendar = {
        var cal = Calendar(identifier: .iso8601)
        cal.timeZone = TimeZone(identifier: "UTC")!
        return cal
    }()
}

extension DayKey {
    /// 1 (pazartesi) – 7 (pazar).
    nonisolated var isoWeekday: Int {
        guard let monday = ISOWeek(containing: self).monday else { return 1 }
        return monday.days(to: self) + 1
    }
}

nonisolated enum ThemeSource: Equatable, Sendable {
    case calendar
    case evergreen
}

nonisolated struct ThemeWeek: Equatable, Sendable {
    let week: ISOWeek
    let theme: WeeklyTheme
    let source: ThemeSource

    func prompt(on day: DayKey) -> String? {
        guard ISOWeek(containing: day) == week else { return nil }
        return theme.prompt(forWeekday: day.isoWeekday)
    }
}

nonisolated struct ThemeDayState: Equatable, Sendable {
    let day: DayKey
    let weekday: Int
    let prompt: String?
    let isLocked: Bool
}

nonisolated enum ThemeCalendar {

    /// Ücretsiz kullanıcının görebildiği geçmiş hafta sayısı (E5, E15).
    static let freePastWeeks = 4

    /// `day`'in haftasının teması. Katalogda hiç tema yoksa `nil`.
    /// - Parameter firstSeen: evergreen tema ID'si → ilk görülme günü (E3).
    static func theme(for day: DayKey, catalog: ContentCatalog,
                      firstSeen: [String: DayKey] = [:], salt: UUID) -> ThemeWeek? {
        let week = ISOWeek(containing: day)
        if let theme = catalog.theme(week: week.description), theme.active {
            return ThemeWeek(week: week, theme: theme, source: .calendar)
        }
        let pool = catalog.evergreenThemes.filter(\.active).sorted { $0.id < $1.id }
        guard !pool.isEmpty else { return nil }
        // Bu haftadan önce görülenler dışarıda; bu hafta görülen dahil (sabit kalsın).
        let unseen = pool.filter { t in firstSeen[t.id].map { ISOWeek(containing: $0) >= week } ?? true }
        let candidates = unseen.isEmpty ? pool : unseen
        var rng = SeededRandom("theme.evergreen", salt.uuidString, week.description)
        let index = Int(rng.next() % UInt64(candidates.count))
        return ThemeWeek(week: week, theme: candidates[index], source: .evergreen)
    }

    /// Haftanın 7 günü: geçmiş ve bugün açık, gelecek kilitli.
    static func dayStates(of themeWeek: ThemeWeek, today: DayKey) -> [ThemeDayState] {
        themeWeek.week.days.map { day in
            ThemeDayState(day: day, weekday: day.isoWeekday,
                          prompt: themeWeek.theme.prompt(forWeekday: day.isoWeekday),
                          isLocked: day > today)
        }
    }

    /// Keşfet › Tüm temalar: bu haftadan önceki takvim temaları, yeniden
    /// eskiye. Ücretsizde son 4 hafta.
    static func pastThemes(catalog: ContentCatalog, today: DayKey, hasPremium: Bool) -> [WeeklyTheme] {
        let current = ISOWeek(containing: today)
        let past = catalog.themes
            .filter { $0.active }
            .compactMap { t in t.week.flatMap(ISOWeek.init).map { (t, $0) } }
            .filter { $0.1 < current }
            .sorted { $0.1 > $1.1 }
        let visible = hasPremium ? past : past.filter { $0.1 >= current.adding(weeks: -freePastWeeks) }
        return visible.map(\.0)
    }

    /// Gelecek haftanın teması katalogda yoksa `true`: `theme_missing_next_week`
    /// olayı atılır (tema en az 2 hafta önden yayınlanmalı).
    static func isNextWeekMissing(catalog: ContentCatalog, today: DayKey) -> Bool {
        let next = ISOWeek(containing: today).adding(weeks: 1)
        return catalog.theme(week: next.description) == nil
    }
}
