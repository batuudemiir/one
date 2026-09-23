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

    @Test("Sabah-akşam modu: tek kart yarım gün, ikisi tam gün; seri için yarım gün yeter (E8)")
    func morningEveningMode() {
        var record = DayCompletion(day: today, morningCompletedAt: t)
        #expect(record.status(in: .morningEvening) == .half)
        #expect(record.isComplete(in: .morningEvening))
        record.eveningCompletedAt = t
        #expect(record.status(in: .morningEvening) == .full)
        #expect(DayCompletion(day: today).status(in: .morningEvening) == .none)
    }

    @Test("Mod değişince aynı kayıtlardan farklı seri çıkar")
    func modeAffectsStreak() {
        let records = [
            DayCompletion(day: today, morningCompletedAt: t, eveningCompletedAt: t),
            DayCompletion(day: today.adding(days: -1), eveningCompletedAt: t),
            DayCompletion(day: today.adding(days: -2), dailyCompletedAt: t, morningCompletedAt: t, eveningCompletedAt: t)
        ]
        #expect(Streak.current(records, mode: .daily, today: today) == 0)
        #expect(Streak.current(records, mode: .morningEvening, today: today) == 3)
    }

    @Test("Yalnız yazılı girdiyle tamamlanan gün her iki modda tam")
    func writingCompletes() {
        let record = DayCompletion(day: today, completedBy: .writing)
        #expect(record.status(in: .daily) == .full)
        #expect(record.status(in: .morningEvening) == .full)
        #expect(DayCompletion(day: today, morningCompletedAt: t, completedBy: .writing).status(in: .morningEvening) == .full)
    }

    @Test("Seri durumu: bugün tamam değilse risk altında; gizliyken de hesaplanır")
    func streakState() {
        let records = [DayCompletion(day: today.adding(days: -1), dailyCompletedAt: t),
                       DayCompletion(day: today.adding(days: -2), dailyCompletedAt: t)]
        let state = Streak.state(records, mode: .daily, today: today, visible: false)
        #expect(state == StreakState(count: 2, atRisk: true, isVisible: false, longest: 2))
        let done = Streak.state(records + [DayCompletion(day: today, dailyCompletedAt: t)], mode: .daily, today: today)
        #expect(done.count == 3 && !done.atRisk)
        #expect(!Streak.state([], mode: .daily, today: today).atRisk)
    }

    @Test("Geriye dönük pencere: dün…7 gün önce açık, 8. gün ve bugün/gelecek değil")
    func backfillWindow() {
        #expect(DayCompletionRules.canBackfill(today.adding(days: -1), today: today))
        #expect(DayCompletionRules.canBackfill(today.adding(days: -7), today: today))
        #expect(!DayCompletionRules.canBackfill(today.adding(days: -8), today: today))
        #expect(!DayCompletionRules.canBackfill(today, today: today))
        #expect(!DayCompletionRules.canBackfill(today.adding(days: 1), today: today))
    }

    @Test("Yazılı girdi eşiği: ≥ 20 kelime ve ritüel olmayan tür")
    func writingThreshold() {
        #expect(DayCompletionRules.countsAsWriting(.freeform, words: 20))
        #expect(!DayCompletionRules.countsAsWriting(.freeform, words: 19))
        #expect(DayCompletionRules.countsAsWriting(.quoteReflection, words: 40))
        #expect(!DayCompletionRules.countsAsWriting(.dailyCheckIn, words: 200))
    }
}
