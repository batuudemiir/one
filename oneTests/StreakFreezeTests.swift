//
//  StreakFreezeTests.swift
//  oneTests
//
//  StreakEngine freeze mantığı testleri.
//  Özellikle düzeltilen bug: frozenDates.contains(yesterday) yerine
//  !frozenDates.isEmpty kullanıldığında banner her zaman açık kalıyordu.
//

import Testing
import Foundation
@testable import OneDailyBatuhan

@Suite(.serialized)
struct StreakFreezeTests {

    // MARK: - Helpers

    private func day(_ offset: Int, from base: Date = Calendar.current.startOfDay(for: Date())) -> Date {
        Calendar.current.date(byAdding: .day, value: offset, to: base)!
    }

    private func yesterdayFrozen(result: StreakComputation, today: Date) -> Bool {
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: today)!
        return result.frozenDates.contains(yesterday)
    }

    // MARK: - Temel Freeze Senaryoları

    @Test("Ardışık entry'lerde dün frozen değil → banner gösterilmemeli")
    func testConsecutiveEntriesYesterdayNotFrozen() {
        let today = Calendar.current.startOfDay(for: Date())
        StreakEngine.resetFreezesForTesting()

        // Son 5 gün ardışık dolu — dün (day -1) kesinlikle frozen olmamalı
        let filled: Set<Date> = [
            day(-4, from: today),
            day(-3, from: today),
            day(-2, from: today),
            day(-1, from: today),
            today
        ]

        let result = StreakEngine.compute(filledDates: filled, today: today, includeToday: true)

        // Banner mantığı: frozenDates.contains(yesterday) — dün filled olduğu için false olmalı
        #expect(!yesterdayFrozen(result: result, today: today),
                "Dün dolu → freeze banner gösterilmemeli")
    }

    @Test("Dün boştu, bugün entry girildi → banner gösterilmeli")
    func testMissedYesterdaySavedTodayShowsBanner() {
        let today = Calendar.current.startOfDay(for: Date())
        StreakEngine.resetFreezesForTesting()

        // Perşembe entry var, Cuma (dün) boş, Cumartesi (bugün) entry var
        let filled: Set<Date> = [
            day(-2, from: today), // iki gün önce
            today                 // bugün
            // dün yok
        ]

        let result = StreakEngine.compute(filledDates: filled, today: today, includeToday: true)

        #expect(yesterdayFrozen(result: result, today: today), "Dün dondurulmuş olmalı → banner gösterilmeli")
        #expect(!result.newlyConsumedFreezes.isEmpty, "Freeze yeni tüketilmiş olmalı")
        #expect(result.count == 3)
    }

    @Test("3 gün önce freeze kullanıldı, dün ve bugün dolu → banner gösterilmemeli (eski bug)")
    func testOldFreezeNotTriggersBanner() {
        let today = Calendar.current.startOfDay(for: Date())
        StreakEngine.resetFreezesForTesting()

        // İlk compute: 3 gün önce boştu → freeze tüketilir
        let firstFilled: Set<Date> = [
            day(-4, from: today),
            // 3 gün önce (day(-3)) boş → freeze
            day(-2, from: today),
            day(-1, from: today)
        ]
        _ = StreakEngine.compute(filledDates: firstFilled, today: day(-1, from: today), includeToday: true)

        // İkinci compute: bugün entry girildi (dün de dolu)
        let currentFilled: Set<Date> = [
            day(-4, from: today),
            day(-2, from: today),
            day(-1, from: today),
            today
        ]
        let result = StreakEngine.compute(filledDates: currentFilled, today: today, includeToday: true)

        // Eski bug: !result.frozenDates.isEmpty → true (3 gün önceki freeze hâlâ var)
        // Yeni doğru davranış: frozenDates.contains(yesterday) → false
        #expect(!yesterdayFrozen(result: result, today: today),
                "Dün dolu, 3 gün önceki freeze banner'ı tetiklemememli")
        #expect(result.newlyConsumedFreezes.isEmpty, "Bu save'de yeni freeze tüketilmemiş olmalı")
    }

    @Test("7 gün içinde ikinci freeze kullanılamaz")
    func testOnlyOneFreezePerWindow() {
        let today = Calendar.current.startOfDay(for: Date())
        StreakEngine.resetFreezesForTesting()

        // 5 gün önce boştu → freeze tüketildi
        let firstFilled: Set<Date> = [
            day(-6, from: today),
            day(-4, from: today),
            day(-3, from: today)
        ]
        _ = StreakEngine.compute(filledDates: firstFilled, today: day(-3, from: today), includeToday: true)

        // Şimdi dün de boş, bugün entry var — ikinci freeze kullanılabilir mi?
        let secondFilled: Set<Date> = [
            day(-6, from: today),
            day(-4, from: today),
            day(-3, from: today),
            today
        ]
        let result = StreakEngine.compute(filledDates: secondFilled, today: today, includeToday: true)

        // 7 günlük pencere içinde ikinci freeze kullanılmamalı → streak kırılır
        #expect(result.newlyConsumedFreezes.isEmpty, "7 gün içinde ikinci freeze tüketilmemeli")
        #expect(!result.freezeAvailable, "Freeze hakkı tükenmiş olmalı")
    }

    @Test("Bugün henüz entry yok, freeze mevcut → streak 0")
    func testNoEntryTodayNoFreeze() {
        let today = Calendar.current.startOfDay(for: Date())
        StreakEngine.resetFreezesForTesting()

        // Dün entry var, bugün yok ve freeze tüketilmemiş
        let filled: Set<Date> = [
            day(-1, from: today)
        ]

        let result = StreakEngine.compute(filledDates: filled, today: today, includeToday: false)

        // Bugün ne entry ne freeze → streak 0
        #expect(result.count == 0)
        #expect(result.frozenDates.isEmpty)
    }

    @Test("Freeze idempotent — aynı gün için iki kez tüketilmez")
    func testFreezeIdempotent() {
        let today = Calendar.current.startOfDay(for: Date())
        StreakEngine.resetFreezesForTesting()

        let filled: Set<Date> = [
            day(-2, from: today),
            today
        ]

        let result1 = StreakEngine.compute(filledDates: filled, today: today, includeToday: true)
        let result2 = StreakEngine.compute(filledDates: filled, today: today, includeToday: true)

        #expect(!result1.newlyConsumedFreezes.isEmpty, "İlk compute'da freeze tüketilmeli")
        #expect(result2.newlyConsumedFreezes.isEmpty, "İkinci compute'da freeze yeniden tüketilmemeli")
        #expect(result1.count == result2.count, "Streak sayısı aynı olmalı")
    }

    @Test("freezeAvailable doğru raporlanıyor")
    func testFreezeAvailableFlag() {
        let today = Calendar.current.startOfDay(for: Date())
        StreakEngine.resetFreezesForTesting()

        // Freeze yok → available
        #expect(StreakEngine.isFreezeAvailable(today: today))

        // Dün boştu, bugün entry → freeze tüketilir
        let filled: Set<Date> = [day(-2, from: today), today]
        _ = StreakEngine.compute(filledDates: filled, today: today, includeToday: true)

        // Artık pencerede freeze kullanıldı → not available
        #expect(!StreakEngine.isFreezeAvailable(today: today))
    }
}
