//
//  TodayFixture.swift
//  ONE 2.0
//
//  ÖRNEK VERİ (ID'ler `fx_` önekli). Bugün ekranı: boş (ilk gün), az
//  (check-in yok, 2 günlük seri risk altında), çok (check-in yapıldı, tema yazıldı),
//  sabah+akşam modu.
//

import Foundation

nonisolated enum TodayFixture {

    private static var today: DayKey { FixtureClock.today }

    /// Pazartesi ve salı tamam, çarşamba boş, bugün (perşembe) açık.
    static var weekFew: WeekStripData {
        WeekStripData.week(containing: today, today: today, completions: [
            today.adding(days: -3): .done,
            today.adding(days: -2): .done,
        ])
    }

    static var weekEmpty: WeekStripData {
        WeekStripData.week(containing: today, today: today, completions: [:])
    }

    static var weekMany: WeekStripData {
        WeekStripData.week(containing: today, today: today, completions: [
            today.adding(days: -3): .done,
            today.adding(days: -2): .half,
            today.adding(days: -1): .done,
            today: .done,
        ])
    }

    static let checkInEvening = CheckInSummary(
        id: "fx_checkin_1",
        time: FixtureClock.daysAgo(0, 19, 42),
        slot: .daily,
        score: 3,
        emotions: [EmotionCatalogFixture.emotion("yorgun.yorgun"), EmotionCatalogFixture.emotion("huzur.sakin")],
        causes: ["İş", "Uyku"],
        echo: "Adım adım da varılır; bugün de bir adımdı."
    )

    static let checkInMorning = CheckInSummary(
        id: "fx_checkin_2",
        time: FixtureClock.daysAgo(0, 8, 5),
        slot: .morning,
        score: 4,
        emotions: [EmotionCatalogFixture.emotion("enerji.merakli")],
        causes: ["Hareket"],
        echo: "Güne merakla başlamak da bir niyet."
    )

    /// + sayfasındaki "Günlük önerisi"nin sorusu (E4 serbest havuz; UX-11'de motor).
    static let freePromptID = "fx_prompt_free_01"

    static let practices: [PracticeTileData] = [
        PracticeTileData(id: "fx_practice_morning", title: "Sabah hazırlığı", icon: .today, contentID: "fx_ritual_morning"),
        PracticeTileData(id: "fx_practice_evening", title: "Akşam refleksiyonu", icon: .moon, contentID: "fx_ritual_evening"),
        PracticeTileData(id: "fx_practice_gratitude", title: "Üç küçük minnet", icon: .leaf, contentID: "fx_guided_gratitude"),
    ]

    static let theme = ThemeCardData(
        id: "t_2026w39",
        name: "Yavaşlık",
        day: 4,
        unlockedDays: 4,
        promptID: "fx_prompt_theme_w39_d4",
        question: "Bugün seni en çok ne yavaşlattı, ve buna izin verdin mi?",
        isWritten: false,
        firstLine: nil
    )

    static let themeWritten = ThemeCardData(
        id: theme.id, name: theme.name, day: theme.day, unlockedDays: theme.unlockedDays,
        promptID: theme.promptID, question: theme.question,
        isWritten: true,
        firstLine: "Durakta on iki dakika bekledim ve ilk kez telefona bakmadım."
    )

    static let empty = TodayData(
        week: weekEmpty,
        streak: StreakData(current: 0, longest: 0, isVisible: true, isAtRisk: false),
        checkIns: [CheckInCardData(slot: .daily, summary: nil)],
        practices: [],
        theme: theme
    )

    static let few = TodayData(
        week: weekFew,
        streak: StreakData(current: 2, longest: 2, isVisible: true, isAtRisk: true),
        checkIns: [CheckInCardData(slot: .daily, summary: nil)],
        practices: Array(practices.prefix(2)),
        theme: theme
    )

    static let many = TodayData(
        week: weekMany,
        streak: StreakData(current: 12, longest: 21, isVisible: true, isAtRisk: false),
        checkIns: [CheckInCardData(slot: .daily, summary: checkInEvening)],
        practices: practices,
        theme: themeWritten
    )

    static let morningEvening = TodayData(
        week: weekMany,
        streak: StreakData(current: 12, longest: 21, isVisible: true, isAtRisk: false),
        checkIns: [
            CheckInCardData(slot: .morning, summary: checkInMorning),
            CheckInCardData(slot: .evening, summary: nil),
        ],
        practices: practices,
        theme: theme
    )

    /// Seri profil ayarından gizli.
    static let streakHidden = TodayData(
        week: many.week,
        streak: StreakData(current: 12, longest: 21, isVisible: false, isAtRisk: false),
        checkIns: many.checkIns,
        practices: many.practices,
        theme: many.theme
    )
}
