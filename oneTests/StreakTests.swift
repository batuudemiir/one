//
//  StreakTests.swift
//  oneTests
//
//  Seri saklanmaz, `DayRecord`'lardan hesaplanır. Kurallar Streak.swift
//  başlığında; buradaki her test bir kuralın kod karşılığı.
//

import Testing
import Foundation
@testable import OneDailyBatuhan

struct StreakTests {

    private let today = DayKey("2026-09-23")!
    private let t = Date(timeIntervalSince1970: 1_790_000_000)

    private func days(_ offsets: [Int]) -> Set<DayKey> {
        Set(offsets.map { today.adding(days: -$0) })
    }

    @Test("Hiç tamam gün yoksa seri 0")
    func empty() {
        #expect(Streak.current(completed: [], today: today) == 0)
        #expect(Streak.longest(completed: []) == 0)
    }

    @Test("Bugün tamamsa bugün dahil sayılır")
    func countsToday() {
        #expect(Streak.current(completed: days([0, 1, 2]), today: today) == 3)
    }

    @Test("Bugün henüz tamam değilse seri dünden sayılır, kırılmaz")
    func todayPendingKeepsStreak() {
        #expect(Streak.current(completed: days([1, 2, 3]), today: today) == 3)
    }

    @Test("Dün boşsa seri 0 (bugün de boşken)")
    func brokenYesterday() {
        #expect(Streak.current(completed: days([2, 3, 4]), today: today) == 0)
    }

    @Test("Aradaki boşluk seriyi keser")
    func gapBreaks() {
        #expect(Streak.current(completed: days([0, 1, 3, 4, 5]), today: today) == 2)
    }

    @Test("Geriye dönük doldurma boşluğu kapatır, seri yeniden hesaplanır")
    func backfillHealsGap() {
        var completed = days([0, 1, 3, 4, 5])
        completed.insert(today.adding(days: -2))
        #expect(Streak.current(completed: completed, today: today) == 6)
    }

    @Test("En uzun seri geçmişteki en uzun kesintisiz dizi")
    func longest() {
        #expect(Streak.longest(completed: days([0, 1, 5, 6, 7, 8, 20])) == 4)
    }

    @Test("Seri ay ve yıl sınırını geçer")
    func crossesYear() {
        let newYear = DayKey("2027-01-02")!
        let completed: Set<DayKey> = [DayKey("2026-12-30")!, DayKey("2026-12-31")!,
                                      DayKey("2027-01-01")!, newYear]
        #expect(Streak.current(completed: completed, today: newYear) == 4)
    }

    @Test("Günlük modda günlük kart yeter")
    func dailyMode() {
        let record = DayCompletion(day: today, dailyCompletedAt: t)
        #expect(record.isComplete(in: .daily))
        #expect(!record.isComplete(in: .morningEvening))
    }

    @Test("Sabah-akşam modunda iki kart da gerekli")
    func morningEveningMode() {
        var record = DayCompletion(day: today, morningCompletedAt: t)
        #expect(!record.isComplete(in: .morningEvening))
        record.eveningCompletedAt = t
        #expect(record.isComplete(in: .morningEvening))
    }

    @Test("Mod değişince aynı kayıtlardan farklı seri çıkar")
    func modeAffectsStreak() {
        let records = [
            DayCompletion(day: today, dailyCompletedAt: t, morningCompletedAt: t, eveningCompletedAt: t),
            DayCompletion(day: today.adding(days: -1), dailyCompletedAt: t, morningCompletedAt: t),
            DayCompletion(day: today.adding(days: -2), dailyCompletedAt: t, morningCompletedAt: t, eveningCompletedAt: t)
        ]
        #expect(Streak.current(records, mode: .daily, today: today) == 3)
        #expect(Streak.current(records, mode: .morningEvening, today: today) == 1)
    }
}
