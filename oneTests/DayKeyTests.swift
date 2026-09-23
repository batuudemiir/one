//
//  DayKeyTests.swift
//  oneTests
//
//  `dayKey` her ONE 2.0 kaydının gün kimliği; seri, Yolculuk ve geriye
//  dönük giriş buna bağlı. Saat dilimi ve DST kaymaları burada yakalanır.
//

import Testing
import Foundation
@testable import OneDailyBatuhan

struct DayKeyTests {

    private func calendar(_ id: String) -> Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: id)!
        return cal
    }

    private func date(_ iso: String) -> Date {
        let f = ISO8601DateFormatter()
        return f.date(from: iso)!
    }

    @Test("Metin biçimi yyyy-MM-dd, sıfır dolgulu")
    func formatting() {
        #expect(DayKey(year: 2026, month: 3, day: 7)?.string == "2026-03-07")
    }

    @Test("Geçersiz tarih ve biçim reddedilir")
    func rejectsInvalid() {
        #expect(DayKey(year: 2026, month: 2, day: 30) == nil)
        #expect(DayKey("2026-2-7") == nil)
        #expect(DayKey("2026-13-01") == nil)
        #expect(DayKey("dün") == nil)
        #expect(DayKey("2028-02-29") != nil)
    }

    @Test("Aynı an, farklı saat dilimlerinde farklı gün")
    func dayDependsOnTimeZone() {
        // İstanbul'da 1 Ekim 01:30 = UTC 30 Eylül 22:30
        let instant = date("2026-09-30T22:30:00Z")
        #expect(DayKey(date: instant, calendar: calendar("Europe/Istanbul")).string == "2026-10-01")
        #expect(DayKey(date: instant, calendar: calendar("Europe/London")).string == "2026-09-30")
    }

    @Test("Gün aritmetiği ay, yıl ve artık gün sınırını geçer")
    func arithmetic() {
        let key = DayKey(year: 2028, month: 2, day: 28)!
        #expect(key.adding(days: 1).string == "2028-02-29")
        #expect(key.adding(days: 2).string == "2028-03-01")
        #expect(DayKey(year: 2026, month: 12, day: 31)!.adding(days: 1).string == "2027-01-01")
        #expect(DayKey(year: 2026, month: 1, day: 1)!.adding(days: -1).string == "2025-12-31")
        #expect(key.days(to: key.adding(days: 400)) == 400)
    }

    @Test("DST geçişi gün aritmetiğini bozmaz")
    func dstDoesNotShiftDays() {
        // New York'ta 8 Mart 2026 saat ileri alınıyor (23 saatlik gün).
        let ny = calendar("America/New_York")
        let before = DayKey(date: date("2026-03-08T04:30:00Z"), calendar: ny) // 7 Mart 23:30 EST
        #expect(before.string == "2026-03-07")
        #expect(before.adding(days: 1).string == "2026-03-08")
        #expect(before.adding(days: 2).string == "2026-03-09")
    }

    @Test("Sıralama tarih sırası")
    func ordering() {
        let a = DayKey("2026-09-30")!, b = DayKey("2026-10-01")!
        #expect(a < b)
        #expect([b, a].sorted() == [a, b])
    }

    @Test("Codable tek string olarak yazılır")
    func codable() throws {
        let key = DayKey("2026-09-23")!
        let data = try JSONEncoder().encode([key])
        #expect(String(decoding: data, as: UTF8.self) == "[\"2026-09-23\"]")
        #expect(try JSONDecoder().decode([DayKey].self, from: data) == [key])
    }

    // MARK: - v3 kayıtları (MIGRATION.md §1.2)

    /// v3 `DailySong.date`: yazan cihazın saat diliminde gece yarısı.
    private func v3Date(_ day: String, writtenIn tz: String) -> Date {
        let key = DayKey(day)!
        return key.startDate(in: calendar(tz))!
    }

    @Test("TR'de yazılmış v3 günü batıda okununca kaymaz")
    func legacyWestwardTravel() {
        let stored = v3Date("2026-05-10", writtenIn: "Europe/Istanbul")
        // Düz okuma bir gün geri kayar…
        #expect(DayKey(date: stored, calendar: calendar("Europe/London")).string == "2026-05-09")
        // …yuvarlama doğru günü verir.
        for tz in ["Europe/Istanbul", "Europe/London", "America/New_York"] {
            #expect(DayKey(normalizedMidnight: stored, calendar: calendar(tz)).string == "2026-05-10")
        }
    }

    @Test("Doğuda okunan v3 günü de kaymaz")
    func legacyEastwardTravel() {
        let stored = v3Date("2026-05-10", writtenIn: "America/New_York")
        for tz in ["Europe/Istanbul", "Asia/Dubai"] {
            #expect(DayKey(normalizedMidnight: stored, calendar: calendar(tz)).string == "2026-05-10")
        }
    }

    @Test("12 saati aşan farkta bir gün kayma — bilinen sınır")
    func legacyKnownLimit() {
        // Honolulu (UTC-10) → Kiritimati (UTC+14): 24 saat fark.
        let stored = v3Date("2026-05-10", writtenIn: "Pacific/Honolulu")
        #expect(DayKey(normalizedMidnight: stored, calendar: calendar("Pacific/Kiritimati")).string == "2026-05-11")
    }

    @Test("FixedClock bugünü kendi saat diliminde verir")
    func clockToday() {
        let clock = FixedClock(date("2026-09-30T22:30:00Z"))
        #expect(clock.today.string == "2026-10-01")
        #expect(clock.timeZoneID == "Europe/Istanbul")
    }
}
