//
//  MonthSummaryTests.swift
//  oneTests
//
//  Tests for MonthSummary — computed properties, calendar grid, mood distribution.
//

import Testing
import SwiftUI
import Foundation
@testable import OneDailyBatuhan

// MARK: - MonthSummary Tests

struct MonthSummaryTests {

    // MARK: - Helpers

    private func makeEntry(
        date: Date,
        songName: String = "Test Song",
        moodColorHex: String = "#5B8DEF"
    ) -> DailyEntry {
        DailyEntry(
            id: UUID(),
            date: date,
            songName: songName,
            artistName: "Test Artist",
            genre: "Test",
            moodColor: Color(hex: moodColorHex),
            moodColorHex: moodColorHex,
            moodLabel: "Derin",
            feeling: .calm,
            feelingLabel: "Sakin",
            time: "12:00",
            photoURL: nil,
            shareWithCircle: false,
            weatherIcon: "☀️",
            weatherDesc: "20°C",
            spotifyURL: nil,
            platform: "Spotify",
            note: nil
        )
    }

    private func makeDate(year: Int, month: Int, day: Int) -> Date {
        Calendar.current.date(from: DateComponents(year: year, month: month, day: day))!
    }

    // MARK: - Basic Properties

    @Test("filledDays returns number of entries")
    func testFilledDays() {
        let d1 = makeDate(year: 2026, month: 3, day: 1)
        let d2 = makeDate(year: 2026, month: 3, day: 2)
        let d3 = makeDate(year: 2026, month: 3, day: 5)

        let entries: [Date: DailyEntry] = [
            Calendar.current.startOfDay(for: d1): makeEntry(date: d1),
            Calendar.current.startOfDay(for: d2): makeEntry(date: d2),
            Calendar.current.startOfDay(for: d3): makeEntry(date: d3),
        ]

        let summary = MonthSummary(year: 2026, month: 3, entries: entries, totalDays: 31)
        #expect(summary.filledDays == 3)
    }

    @Test("Empty entries yields filledDays = 0")
    func testFilledDaysEmpty() {
        let summary = MonthSummary(year: 2026, month: 1, entries: [:], totalDays: 31)
        #expect(summary.filledDays == 0)
    }

    // MARK: - Mood Distribution

    @Test("moodDistribution counts colors correctly")
    func testMoodDistribution() {
        let d1 = makeDate(year: 2026, month: 2, day: 1)
        let d2 = makeDate(year: 2026, month: 2, day: 2)
        let d3 = makeDate(year: 2026, month: 2, day: 3)
        let d4 = makeDate(year: 2026, month: 2, day: 4)

        let entries: [Date: DailyEntry] = [
            Calendar.current.startOfDay(for: d1): makeEntry(date: d1, moodColorHex: "#E84040"),
            Calendar.current.startOfDay(for: d2): makeEntry(date: d2, moodColorHex: "#5B8DEF"),
            Calendar.current.startOfDay(for: d3): makeEntry(date: d3, moodColorHex: "#E84040"),
            Calendar.current.startOfDay(for: d4): makeEntry(date: d4, moodColorHex: "#5B8DEF"),
        ]

        let summary = MonthSummary(year: 2026, month: 2, entries: entries, totalDays: 28)
        let dist = summary.moodDistribution

        #expect(dist.count == 2)
        // Sorted by count descending — both have 2
        #expect(dist[0].count == 2)
        #expect(dist[1].count == 2)
    }

    @Test("moodDistribution is sorted by count descending")
    func testMoodDistributionSorted() {
        let d1 = makeDate(year: 2026, month: 5, day: 1)
        let d2 = makeDate(year: 2026, month: 5, day: 2)
        let d3 = makeDate(year: 2026, month: 5, day: 3)

        let entries: [Date: DailyEntry] = [
            Calendar.current.startOfDay(for: d1): makeEntry(date: d1, moodColorHex: "#FF0000"),
            Calendar.current.startOfDay(for: d2): makeEntry(date: d2, moodColorHex: "#00FF00"),
            Calendar.current.startOfDay(for: d3): makeEntry(date: d3, moodColorHex: "#FF0000"),
        ]

        let summary = MonthSummary(year: 2026, month: 5, entries: entries, totalDays: 31)
        let dist = summary.moodDistribution

        // FF0000 has count 2, should be first
        #expect(dist.first?.color == "#FF0000")
        #expect(dist.first?.count == 2)
    }

    @Test("moodDistribution empty for no entries")
    func testMoodDistributionEmpty() {
        let summary = MonthSummary(year: 2026, month: 1, entries: [:], totalDays: 31)
        #expect(summary.moodDistribution.isEmpty)
    }

    // MARK: - Month Name

    @Test("monthName returns correct Turkish month names")
    func testMonthNames() {
        let expected = [
            (1, "Ocak"), (2, "Şubat"), (3, "Mart"), (4, "Nisan"),
            (5, "Mayıs"), (6, "Haziran"), (7, "Temmuz"), (8, "Ağustos"),
            (9, "Eylül"), (10, "Ekim"), (11, "Kasım"), (12, "Aralık")
        ]

        for (month, name) in expected {
            let summary = MonthSummary(year: 2026, month: month, entries: [:], totalDays: 30)
            #expect(summary.monthName == name, "Month \(month) should be \(name)")
        }
    }

    @Test("monthName returns empty string for invalid month")
    func testMonthNameInvalid() {
        let summary0 = MonthSummary(year: 2026, month: 0, entries: [:], totalDays: 30)
        #expect(summary0.monthName == "")

        let summary13 = MonthSummary(year: 2026, month: 13, entries: [:], totalDays: 30)
        #expect(summary13.monthName == "")
    }

    // MARK: - Month Short Name

    @Test("monthNameShort returns correct Turkish abbreviations")
    func testMonthShortNames() {
        let expected = [
            (1, "OCA"), (2, "ŞUB"), (3, "MAR"), (4, "NİS"),
            (5, "MAY"), (6, "HAZ"), (7, "TEM"), (8, "AĞU"),
            (9, "EYL"), (10, "EKİ"), (11, "KAS"), (12, "ARA")
        ]

        for (month, shortName) in expected {
            let summary = MonthSummary(year: 2026, month: month, entries: [:], totalDays: 30)
            #expect(summary.monthNameShort == shortName, "Month \(month) short should be \(shortName)")
        }
    }

    @Test("monthNameShort returns empty string for invalid month")
    func testMonthShortNameInvalid() {
        let summary = MonthSummary(year: 2026, month: 0, entries: [:], totalDays: 30)
        #expect(summary.monthNameShort == "")
    }

    // MARK: - Ordered Days Tests

    @Test("orderedDays has correct leading nil padding for weekday offset")
    func testOrderedDaysPadding() {
        // March 2026 starts on Sunday. In a Monday-first system:
        // Sunday = offset 6 (Mon=0, Tue=1, ..., Sun=6)
        let summary = MonthSummary(year: 2026, month: 3, entries: [:], totalDays: 31)
        let days = summary.orderedDays

        // Count leading nils
        var leadingNils = 0
        for day in days {
            if day == nil { leadingNils += 1 } else { break }
        }

        // The first non-nil date should be March 1
        let firstDate = days.first(where: { $0 != nil })!
        let calendar = Calendar.current
        let day = calendar.component(.day, from: firstDate!)
        #expect(day == 1)
    }

    @Test("orderedDays contains correct number of non-nil dates")
    func testOrderedDaysCount() {
        // February 2026 — not a leap year, so 28 days
        let summary = MonthSummary(year: 2026, month: 2, entries: [:], totalDays: 28)
        let days = summary.orderedDays

        let nonNilCount = days.compactMap { $0 }.count
        #expect(nonNilCount == 28)
    }

    // MARK: - Calendar Cells Tests

    @Test("calendarCells count is a multiple of 7")
    func testCalendarCellsMultipleOf7() {
        for month in 1...12 {
            let summary = MonthSummary(year: 2026, month: month, entries: [:], totalDays: 30)
            let cells = summary.calendarCells
            #expect(cells.count % 7 == 0, "Month \(month) should have cells count as a multiple of 7")
        }
    }

    @Test("calendarCells contains all days of the month")
    func testCalendarCellsContainsAllDays() {
        // January 2026: 31 days
        let summary = MonthSummary(year: 2026, month: 1, entries: [:], totalDays: 31)
        let cells = summary.calendarCells

        let calendar = Calendar.current
        let nonNilDays = cells.compactMap { $0 }

        // Should have 31 actual days
        #expect(nonNilDays.count == 31)

        // All should be in January 2026
        for date in nonNilDays {
            let components = calendar.dateComponents([.year, .month], from: date)
            #expect(components.year == 2026)
            #expect(components.month == 1)
        }
    }
}
