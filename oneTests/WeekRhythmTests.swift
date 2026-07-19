//
//  WeekRhythmTests.swift
//  oneTests
//
//  Faz 3 — haftalık ritim modeli: gün üretimi, telafi penceresi, tamamlanma.
//

import Testing
import Foundation
@testable import OneDailyBatuhan

// MARK: - Helpers

private func makeCalendar() -> Calendar {
    // Sabit takvim: firstWeekday ve timezone testten teste kaymasın.
    var cal = Calendar(identifier: .gregorian)
    cal.firstWeekday = 2 // Pazartesi
    cal.timeZone = TimeZone(identifier: "Europe/Istanbul")!
    return cal
}

/// 2026-07-15 Çarşamba — haftanın ortası, hem geçmiş hem gelecek gün bırakır.
private func referenceToday(_ cal: Calendar) -> Date {
    var comps = DateComponents()
    comps.year = 2026; comps.month = 7; comps.day = 15
    return cal.startOfDay(for: cal.date(from: comps)!)
}

private func day(_ offset: Int, from today: Date, _ cal: Calendar) -> Date {
    cal.startOfDay(for: cal.date(byAdding: .day, value: offset, to: today)!)
}

// MARK: - Tests

struct WeekRhythmTests {

    @Test("Hafta her zaman 7 gün üretir ve sıralıdır")
    func producesSevenOrderedDays() {
        let cal = makeCalendar()
        let days = WeekRhythm.days(filled: [:], today: referenceToday(cal), calendar: cal)

        #expect(days.count == 7)
        #expect(days == days.sorted { $0.date < $1.date })
    }

    @Test("Tam olarak bir gün bugün olarak işaretlenir")
    func exactlyOneToday() {
        let cal = makeCalendar()
        let today = referenceToday(cal)
        let days = WeekRhythm.days(filled: [:], today: today, calendar: cal)

        #expect(days.filter(\.isToday).count == 1)
        #expect(days.first(where: \.isToday)?.date == today)
    }

    @Test("Dolu günler renklerini taşır, boşlar taşımaz")
    func filledDaysCarryColor() {
        let cal = makeCalendar()
        let today = referenceToday(cal)
        let yesterday = day(-1, from: today, cal)
        let days = WeekRhythm.days(
            filled: [yesterday: "#5B8DEF"],
            today: today,
            calendar: cal
        )

        let filled = days.first { $0.date == yesterday }
        #expect(filled?.isFilled == true)
        #expect(filled?.moodColorHex == "#5B8DEF")
        #expect(days.first { $0.date == today }?.isFilled == false)
    }

    @Test("Gelecek günler ne telafi edilebilir ne dolu")
    func futureDaysAreInert() {
        let cal = makeCalendar()
        let today = referenceToday(cal)
        let days = WeekRhythm.days(filled: [:], today: today, calendar: cal)

        let future = days.filter(\.isFuture)
        #expect(!future.isEmpty)
        #expect(future.allSatisfy { !$0.isBackfillable && !$0.isFilled })
        #expect(future.allSatisfy { $0.date > today })
    }

    @Test("Telafi penceresi bugünden geriye 2 günü kapsar, 3. günü kapsamaz")
    func backfillWindowBoundaries() {
        let cal = makeCalendar()
        let today = referenceToday(cal)
        let days = WeekRhythm.days(filled: [:], today: today, calendar: cal)

        func backfillable(_ offset: Int) -> Bool? {
            days.first { $0.date == day(offset, from: today, cal) }?.isBackfillable
        }

        #expect(backfillable(-1) == true)   // dün
        #expect(backfillable(-2) == true)   // evvelsi gün — sınır içi
        #expect(backfillable(-3) == false)  // sınır dışı
        #expect(backfillable(0) == false)   // bugün telafi değil, normal akış
    }

    @Test("Dolu bir gün telafi edilebilir sayılmaz")
    func filledDayIsNotBackfillable() {
        let cal = makeCalendar()
        let today = referenceToday(cal)
        let yesterday = day(-1, from: today, cal)
        let days = WeekRhythm.days(
            filled: [yesterday: "#E8734A"],
            today: today,
            calendar: cal
        )

        #expect(days.first { $0.date == yesterday }?.isBackfillable == false)
    }

    @Test("isBackfillable serbest fonksiyonu gün listesiyle aynı kuralı verir")
    func standaloneCheckMatchesDayList() {
        let cal = makeCalendar()
        let today = referenceToday(cal)

        #expect(WeekRhythm.isBackfillable(day(-1, from: today, cal), today: today, calendar: cal))
        #expect(WeekRhythm.isBackfillable(day(-2, from: today, cal), today: today, calendar: cal))
        #expect(!WeekRhythm.isBackfillable(day(-3, from: today, cal), today: today, calendar: cal))
        #expect(!WeekRhythm.isBackfillable(today, today: today, calendar: cal))
        #expect(!WeekRhythm.isBackfillable(day(1, from: today, cal), today: today, calendar: cal))
    }

    @Test("Gün içi saat farkı telafi kararını değiştirmez")
    func timeOfDayDoesNotAffectBackfill() {
        let cal = makeCalendar()
        let today = referenceToday(cal)
        // Dünün 23:59'u — startOfDay'e normalize edilmeli.
        let lateYesterday = cal.date(byAdding: .hour, value: -1, to: today)!

        #expect(WeekRhythm.isBackfillable(lateYesterday, today: today, calendar: cal))
    }

    @Test("Tamamlanma eşiği 4 dolu gün")
    func completionThreshold() {
        let cal = makeCalendar()
        let today = referenceToday(cal)

        func days(filledOffsets: [Int]) -> [WeekRhythm.Day] {
            let filled = Dictionary(
                uniqueKeysWithValues: filledOffsets.map { (day($0, from: today, cal), "#5B8DEF") }
            )
            return WeekRhythm.days(filled: filled, today: today, calendar: cal)
        }

        let three = days(filledOffsets: [-2, -1, 0])
        #expect(WeekRhythm.filledCount(three) == 3)
        #expect(!WeekRhythm.isComplete(three))

        let four = days(filledOffsets: [-3, -2, -1, 0])
        #expect(WeekRhythm.filledCount(four) == 4)
        #expect(WeekRhythm.isComplete(four))
    }

    @Test("Hafta dışındaki dolu günler sayıma girmez")
    func ignoresEntriesOutsideThisWeek() {
        let cal = makeCalendar()
        let today = referenceToday(cal)
        // 10 gün öncesi kesinlikle geçen hafta.
        let lastWeek = day(-10, from: today, cal)
        let days = WeekRhythm.days(
            filled: [lastWeek: "#9B7EDE"],
            today: today,
            calendar: cal
        )

        #expect(WeekRhythm.filledCount(days) == 0)
        #expect(!days.contains { $0.date == lastWeek })
    }

    @Test("Pazar günü bile hafta 7 gün ve bugün içeride kalır")
    func weekStartEdgeCase() {
        var cal = makeCalendar()
        cal.firstWeekday = 2 // Pazartesi başlangıç → Pazar haftanın son günü
        var comps = DateComponents()
        comps.year = 2026; comps.month = 7; comps.day = 19 // Pazar
        let sunday = cal.startOfDay(for: cal.date(from: comps)!)

        let days = WeekRhythm.days(filled: [:], today: sunday, calendar: cal)
        #expect(days.count == 7)
        #expect(days.filter(\.isToday).count == 1)
        #expect(days.last?.isToday == true)
        #expect(days.contains { $0.isFuture } == false)
    }
}
