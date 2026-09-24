//
//  ThemeCalendarTests.swift
//  oneTests
//
//  E5: haftalık tema takvimi ve SeededRandom (04_arka_plan_motorlari.md).
//

import Testing
import Foundation
@testable import OneDailyBatuhan

struct ThemeCalendarTests {

    private static let salt = UUID(uuidString: "11111111-2222-3333-4444-555555555555")!

    private static func theme(_ id: String, week: String?) -> WeeklyTheme {
        WeeklyTheme(id: id, week: week, title: id, summary: "", tags: [],
                    days: (1...7).map { WeeklyTheme.Day(day: $0, prompt: "\(id) gün \($0)") },
                    premium: false, active: true, addedIn: 1, lang: "tr")
    }

    private static func catalog(weeks: [String], evergreen: Int = 5) -> ContentCatalog {
        ContentCatalog(
            manifest: ContentManifest(schemaVersion: "1.0", contentVersion: 1, generatedAt: "", files: []),
            themes: weeks.map { theme(ISOWeek($0)!.themeID, week: $0) },
            evergreenThemes: (1...max(evergreen, 1)).prefix(evergreen).map { theme(String(format: "t_ev_%03d", $0), week: nil) }
        )
    }

    private static func day(_ s: String) -> DayKey { DayKey(s)! }

    // MARK: - ISO hafta

    @Test("ISO hafta: pazartesi başlar, yıl sonu 53. hafta, yıl başı önceki yıla düşebilir")
    func isoWeeks() {
        #expect(ISOWeek(containing: Self.day("2026-09-28")).description == "2026-W40") // pazartesi
        #expect(ISOWeek(containing: Self.day("2026-09-27")).description == "2026-W39") // pazar
        #expect(ISOWeek(containing: Self.day("2026-12-31")).description == "2026-W53")
        #expect(ISOWeek(containing: Self.day("2027-01-01")).description == "2026-W53")
        #expect(ISOWeek(containing: Self.day("2027-01-04")).description == "2027-W01")
        #expect(ISOWeek(containing: Self.day("2024-12-30")).description == "2025-W01")
        #expect(ISOWeek("2026-W53")?.days.first == Self.day("2026-12-28"))
        #expect(ISOWeek("2025-W53") == nil) // 2025'in 52 haftası var
        #expect(ISOWeek("2026-W40")?.themeID == "t_2026w40")
        #expect(ISOWeek("2026-W53")!.adding(weeks: 1).description == "2027-W01")
    }

    @Test("Haftanın günü: pazartesi 1, pazar 7")
    func weekday() {
        #expect(Self.day("2026-09-28").isoWeekday == 1)
        #expect(Self.day("2026-10-04").isoWeekday == 7)
        #expect(Self.day("2027-01-03").isoWeekday == 7)
    }

    // MARK: - Tema seçimi

    @Test("Takvimde tema varsa herkes aynı temayı görür")
    func calendarTheme() throws {
        let c = Self.catalog(weeks: ["2026-W40"])
        let a = try #require(ThemeCalendar.theme(for: Self.day("2026-09-30"), catalog: c, salt: UUID()))
        let b = try #require(ThemeCalendar.theme(for: Self.day("2026-10-04"), catalog: c, salt: UUID()))
        #expect(a.source == .calendar && a.theme.id == "t_2026w40")
        #expect(b.theme.id == a.theme.id)
        #expect(a.prompt(on: Self.day("2026-09-30")) == "t_2026w40 gün 3")
        #expect(a.prompt(on: Self.day("2026-10-05")) == nil) // başka hafta
    }

    @Test("Pazar gece yarısı geçişi yeni haftanın temasına geçer")
    func sundayMidnight() throws {
        let c = Self.catalog(weeks: ["2026-W39", "2026-W40"])
        let clock = FixedClock(ISO8601DateFormatter().date(from: "2026-09-27T20:59:00Z")!) // 23:59 İstanbul, pazar
        let before = try #require(ThemeCalendar.theme(for: clock.today, catalog: c, salt: Self.salt))
        let after = try #require(ThemeCalendar.theme(
            for: FixedClock(clock.now.addingTimeInterval(120)).today, catalog: c, salt: Self.salt))
        #expect(before.theme.id == "t_2026w39")
        #expect(after.theme.id == "t_2026w40")
    }

    @Test("Saat dilimi değişimi: aynı an yerel güne göre farklı haftaya düşebilir")
    func timeZoneChange() throws {
        let c = Self.catalog(weeks: ["2026-W39", "2026-W40"])
        let instant = ISO8601DateFormatter().date(from: "2026-09-28T02:00:00Z")!
        let istanbul = FixedClock(instant) // pazartesi 05:00
        let newYork = FixedClock(instant, timeZone: TimeZone(identifier: "America/New_York")!) // pazar 22:00
        #expect(ThemeCalendar.theme(for: istanbul.today, catalog: c, salt: Self.salt)?.theme.id == "t_2026w40")
        #expect(ThemeCalendar.theme(for: newYork.today, catalog: c, salt: Self.salt)?.theme.id == "t_2026w39")
    }

    @Test("Tema eksik haftada evergreen: görülmemiş olan seçilir, hafta boyunca sabit kalır")
    func evergreenFallback() throws {
        let c = Self.catalog(weeks: ["2026-W39"], evergreen: 5)
        let monday = Self.day("2026-09-28")
        let first = try #require(ThemeCalendar.theme(for: monday, catalog: c, salt: Self.salt))
        #expect(first.source == .evergreen)

        // Bu hafta görülmesi seçimi değiştirmez.
        let seenThisWeek = [first.theme.id: monday]
        let later = try #require(ThemeCalendar.theme(for: monday.adding(days: 4), catalog: c,
                                                     firstSeen: seenThisWeek, salt: Self.salt))
        #expect(later.theme.id == first.theme.id)

        // Önceki haftalarda görülenler seçilmez.
        let seenBefore = Dictionary(uniqueKeysWithValues: c.evergreenThemes.dropLast().map { ($0.id, Self.day("2026-08-01")) })
        let pick = try #require(ThemeCalendar.theme(for: monday, catalog: c, firstSeen: seenBefore, salt: Self.salt))
        #expect(pick.theme.id == c.evergreenThemes.last!.id)

        // Hepsi görüldüyse yine bir tema var (boş ekran yok).
        let all = Dictionary(uniqueKeysWithValues: c.evergreenThemes.map { ($0.id, Self.day("2026-08-01")) })
        #expect(ThemeCalendar.theme(for: monday, catalog: c, firstSeen: all, salt: Self.salt) != nil)
    }

    @Test("Evergreen seçimi kullanıcı tuzuna göre dağılır ama deterministik")
    func evergreenDeterminism() {
        let c = Self.catalog(weeks: [], evergreen: 20)
        let day = Self.day("2026-10-07")
        let a = ThemeCalendar.theme(for: day, catalog: c, salt: Self.salt)?.theme.id
        #expect(a == ThemeCalendar.theme(for: day, catalog: c, salt: Self.salt)?.theme.id)
        let picks = Set((0..<40).compactMap { _ in ThemeCalendar.theme(for: day, catalog: c, salt: UUID())?.theme.id })
        #expect(picks.count > 3)
    }

    @Test("Gün kilidi: geçmiş ve bugün açık, gelecek kilitli; hafta ortası katılımda geçmiş de açık")
    func dayLocks() throws {
        let c = Self.catalog(weeks: ["2026-W40"])
        let today = Self.day("2026-10-01") // perşembe
        let week = try #require(ThemeCalendar.theme(for: today, catalog: c, salt: Self.salt))
        let states = ThemeCalendar.dayStates(of: week, today: today)
        #expect(states.map(\.weekday) == Array(1...7))
        #expect(states.map(\.isLocked) == [false, false, false, false, true, true, true])
        #expect(states[3].prompt == "t_2026w40 gün 4")
    }

    @Test("Geçmiş temalar: ücretsizde son 4 hafta, premium'da hepsi, yeniden eskiye")
    func pastThemes() {
        let weeks = (30...40).map { "2026-W\($0)" }
        let c = Self.catalog(weeks: weeks)
        let today = Self.day("2026-09-30") // W40
        let free = ThemeCalendar.pastThemes(catalog: c, today: today, hasPremium: false)
        #expect(free.map(\.id) == ["t_2026w39", "t_2026w38", "t_2026w37", "t_2026w36"])
        let premium = ThemeCalendar.pastThemes(catalog: c, today: today, hasPremium: true)
        #expect(premium.count == 10)
        #expect(premium.first?.id == "t_2026w39")
    }

    @Test("Gelecek haftanın teması yoksa uyarı")
    func nextWeekMissing() {
        let c = Self.catalog(weeks: ["2026-W40", "2026-W41"])
        #expect(!ThemeCalendar.isNextWeekMissing(catalog: c, today: Self.day("2026-09-30")))
        #expect(ThemeCalendar.isNextWeekMissing(catalog: c, today: Self.day("2026-10-07")))
    }

    @Test("Bundle kataloğunda bu haftanın teması var")
    func bundleHasCurrentWeek() throws {
        let catalog = try ContentLoader.load(from: BundleContentSource(bundle: Bundle(for: PersistenceController.self)))
        let week = try #require(ThemeCalendar.theme(for: Self.day("2026-09-23"), catalog: catalog, salt: Self.salt))
        #expect(week.source == .calendar)
        #expect(ThemeCalendar.dayStates(of: week, today: Self.day("2026-09-23")).allSatisfy { $0.prompt != nil })
    }

    // MARK: - SeededRandom

    @Test("SeededRandom: aynı tohum aynı dizi, farklı tohum farklı dizi, sabit referans değeri")
    func seededRandom() {
        var a = SeededRandom("x", "2026-09-23"), b = SeededRandom("x", "2026-09-23"), c = SeededRandom("x", "2026-09-24")
        let sa = (0..<5).map { _ in a.next() }
        #expect(sa == (0..<5).map { _ in b.next() })
        #expect(sa != (0..<5).map { _ in c.next() })
        // Cihazlar ve sürümler arası sabitlik: FNV-1a referansı.
        #expect(SeededRandom.fnv1a("") == 0xCBF2_9CE4_8422_2325)
        #expect(SeededRandom.fnv1a("a") == 0xAF63_DC4C_8601_EC8C)
    }

    @Test("Ağırlıklı seçim ağırlığa uyuyor, sıfır ağırlık seçilmiyor")
    func weighted() {
        var rng = SeededRandom(seed: 42)
        var counts = [0, 0, 0]
        for _ in 0..<3_000 { counts[rng.weightedIndex([1, 0, 3])!] += 1 }
        #expect(counts[1] == 0)
        #expect(counts[2] > counts[0] * 2)
        #expect(rng.weightedIndex([]) == nil)
    }
}
