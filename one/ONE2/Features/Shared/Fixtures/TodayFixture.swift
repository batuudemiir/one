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

    // MARK: - Hafta şeridi ve gün kaynağı

    /// Son dört haftanın tamamlanması: bu hafta `weekFew` ile aynı (çarşamba
    /// boş), önceki haftalarda birkaç boşluk ve yarım gün.
    static var completions: [DayKey: WeekDayState.Completion] {
        var result: [DayKey: WeekDayState.Completion] = [:]
        let pattern: [WeekDayState.Completion] = [.done, .done, .none, .done, .half, .done, .none]
        for offset in 4...27 {
            result[today.adding(days: -offset)] = pattern[offset % pattern.count]
        }
        result[today.adding(days: -3)] = .done
        result[today.adding(days: -2)] = .done
        return result
    }

    /// Eskiden yeniye dört hafta; sonuncusu bu hafta.
    static var weeks: [WeekStripData] {
        let done = completions
        return (0..<4).reversed().map { back in
            WeekStripData.week(containing: today.adding(days: -7 * back), today: today, completions: done)
        }
    }

    /// Geçmiş bir günün görünümü: tamamlandıysa check-in özeti, değilse boş.
    static func pastDay(_ day: DayKey) -> TodayData {
        let completion = completions[day] ?? .none
        let echoes = [
            "Yavaş bir gündü; yavaşlık da bir cevap.",
            "Yorgunluğunu adlandırmak onu biraz hafifletti.",
            "Küçük bir şey iyi gitti ve bunu gördün.",
        ]
        let seed = day.string.unicodeScalars.reduce(0) { $0 + Int($1.value) }
        let summary = completion == .none ? nil : CheckInSummary(
            id: "fx_checkin_\(day.string)",
            time: FixtureClock.daysAgo(day.days(to: today), 21, 10),
            slot: .daily,
            score: [2, 3, 4, 4, 5][seed % 5],
            emotions: [EmotionCatalogFixture.emotion("huzur.sakin")],
            causes: ["İş"],
            echo: echoes[seed % echoes.count]
        )
        return TodayData(
            week: few.week,
            streak: few.streak,
            checkIns: [CheckInCardData(slot: .daily, summary: summary)],
            practices: few.practices,
            theme: nil
        )
    }

    /// Bugün `data`, geçmiş günler `pastDay`.
    static func source(_ data: TodayData, isOffline: Bool = false) -> TodaySource {
        let today = today
        return TodaySource(today: today, weeks: weeks, isOffline: isOffline) { day in
            .loaded(day == today ? data : pastDay(day))
        }
    }

    /// Uygulamanın kabukta gösterdiği varsayılan (UX-11'e kadar).
    static var app: TodaySource { source(few) }

    static var loading: TodaySource {
        TodaySource(today: today, weeks: weeks) { _ in .loading }
    }

    static var failed: TodaySource {
        TodaySource(today: today, weeks: weeks) { _ in .failed(message: "fixture") }
    }

    /// Seri profil ayarından gizli.
    static let streakHidden = TodayData(
        week: many.week,
        streak: StreakData(current: 12, longest: 21, isVisible: false, isAtRisk: false),
        checkIns: many.checkIns,
        practices: many.practices,
        theme: many.theme
    )
}
