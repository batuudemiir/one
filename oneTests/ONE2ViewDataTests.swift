//
//  ONE2ViewDataTests.swift
//  oneTests
//
//  UX view data'sının saf mantığı: hafta şeridi (ISO hafta, 7 günlük
//  doldurma penceresi), selamlama saatleri, içgörü eşikleri, duygu kataloğu.
//

import Testing
import Foundation
@testable import OneDailyBatuhan

struct WeekStripDataTests {

    private let today = DayKey("2026-09-24")! // perşembe

    @Test("Hafta pazartesi başlar, perşembe 4. gün")
    func isoWeek() {
        let week = WeekStripData.week(containing: today, today: today, completions: [:])
        #expect(week.days.count == 7)
        #expect(week.days.first?.day == DayKey("2026-09-21"))
        #expect(week.days.last?.day == DayKey("2026-09-27"))
        #expect(week.days.map(\.weekday) == Array(1...7))
        #expect(WeekStripData.isoWeekday(today) == 4)
        #expect(WeekStripData.isoWeekday(DayKey("2026-09-27")!) == 7)
    }

    @Test("Hücre türleri: done / half / gap / today / future")
    func kinds() {
        let week = WeekStripData.week(containing: today, today: today, completions: [
            DayKey("2026-09-21")!: .done,
            DayKey("2026-09-22")!: .half,
            today: .done,
        ])
        #expect(week.days.map(\.kind) == [.done, .half, .gap, .today, .future, .future, .future])
    }

    @Test("Boş gün son 7 gün içindeyse doldurulabilir, daha eskisi değil")
    func backfillWindow() {
        let lastWeek = WeekStripData.week(containing: today.adding(days: -7), today: today, completions: [:])
        let sixDaysAgo = try! #require(lastWeek.days.first { $0.day == today.adding(days: -6) })
        let eightDaysAgo = try! #require(lastWeek.days.first { $0.day == today.adding(days: -8) })
        #expect(lastWeek.canBackfill(sixDaysAgo))
        #expect(!lastWeek.canBackfill(eightDaysAgo))

        let thisWeek = WeekStripData.week(containing: today, today: today, completions: [:])
        #expect(!thisWeek.canBackfill(thisWeek.days[3])) // bugün
        #expect(!thisWeek.canBackfill(thisWeek.days[4])) // gelecek
    }
}

struct GreetingTests {

    private func at(_ hour: Int) -> Greeting {
        Greeting.at(FixtureClock.date(2026, 9, 24, hour), calendar: FixtureClock.calendar)
    }

    @Test("Saat aralıkları")
    func ranges() {
        #expect(at(4) == .evening)
        #expect(at(5) == .morning)
        #expect(at(11) == .morning)
        #expect(at(12) == .day)
        #expect(at(17) == .day)
        #expect(at(18) == .evening)
        #expect(at(23) == .evening)
    }
}

struct InsightStateTests {

    @Test("Kalan check-in sayısı eşikten hesaplanır")
    func remaining() {
        #expect(InsightState<Int>.insufficient(required: InsightThreshold.average, current: 4).remaining == 3)
        #expect(InsightState<Int>.insufficient(required: 5, current: 9).remaining == 0)
        #expect(InsightState<Int>.ready(1).remaining == nil)
    }

    @Test("Hiç kayıt yoksa ekran boş; yazı varsa boş değil")
    func isEmpty() {
        #expect(InsightsFixture.empty.isEmpty)
        #expect(!InsightsFixture.few.isEmpty)
        #expect(!InsightsFixture.many.isEmpty)
    }
}

struct EmotionCatalogFixtureTests {

    @Test("Her ailede 4–6 duygu; ID'ler benzersiz, ASCII ve aileyle önekli")
    func catalog() {
        let all = EmotionCatalogFixture.all
        #expect(Set(all.map(\.id)).count == all.count)
        for family in ONE2EmotionFamily.allCases {
            let count = all.filter { $0.family == family }.count
            #expect((4...6).contains(count), "\(family.rawValue): \(count)")
        }
        for item in all {
            #expect(item.id.hasPrefix(item.family.rawValue + "."))
            #expect(item.id.allSatisfy { $0.isASCII && ($0.isLowercase || $0 == ".") }, "\(item.id)")
        }
    }
}
