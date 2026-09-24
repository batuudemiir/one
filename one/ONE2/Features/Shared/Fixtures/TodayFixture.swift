//
//  TodayFixture.swift
//  ONE 2.0
//
//  ÖRNEK VERİ (ID'ler `fx_` önekli). Bugün ekranı (07 §5.1) durumları:
//  ilk gün, başlamadı, yarıda, tamam, sabah+akşam (sabah tamam / sabah
//  kaçırıldı), seri gizli; hafta şeridi ve geçmiş günler.
//

import Foundation

nonisolated enum TodayFixture {

    private static var today: DayKey { FixtureClock.today }

    // MARK: - Parçalar

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
        causes: ["Spor"],
        echo: "Güne merakla başlamak da bir niyet."
    )

    /// + sayfasındaki "Günlük önerisi"nin sorusu (E4 serbest havuz; UX-11'de motor).
    static let freePromptID = "fx_prompt_free_01"

    static let practices: [PracticeTileData] = [
        PracticeTileData(id: "fx_practice_breath", title: "Üç nefes", icon: .leaf, contentID: "fx_guided_breath", isDoneToday: true),
        PracticeTileData(id: "fx_practice_walk", title: "Kısa yürüyüş", icon: .today, contentID: "fx_exercise_walk", isDoneToday: false),
        PracticeTileData(id: "fx_practice_read", title: "On sayfa okuma", icon: .library, contentID: "fx_exercise_read", isDoneToday: false),
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

    static let resurfaceYearAgo = ResurfaceCardData(
        id: "fx_resurface_1",
        kind: .yearAgo,
        entryID: UUID(uuidString: "00000000-0000-0000-0000-00000000F001")!,
        writtenAt: FixtureClock.daysAgo(365, 22, 10),
        excerpt: "Bugün ilk kez yalnız başına sinemaya gittim. Salon neredeyse boştu ve bu hiç de kötü değildi.",
        promptID: nil,
        quoteID: nil
    )

    static let resurfaceQuestion = ResurfaceCardData(
        id: "fx_resurface_2",
        kind: .questionAgain(daysAgo: 30),
        entryID: UUID(uuidString: "00000000-0000-0000-0000-00000000F002")!,
        writtenAt: FixtureClock.daysAgo(30, 21, 0),
        excerpt: "Beni en çok yoran şey başkalarının beklentisi değil, benim onları tahmin etmeye çalışmam.",
        promptID: "fx_prompt_free_07",
        quoteID: nil
    )

    // MARK: - Kartlar

    static func dailyCard(_ status: RitualStatus) -> CheckInCardData {
        CheckInCardData(slot: .daily, flow: .dailyCheckIn, status: status, minutes: 2)
    }

    static func morningCard(_ status: RitualStatus) -> CheckInCardData {
        CheckInCardData(slot: .morning, flow: .morning, status: status, minutes: 2)
    }

    static func eveningCard(_ status: RitualStatus) -> CheckInCardData {
        CheckInCardData(slot: .evening, flow: .evening, status: status, minutes: 3)
    }

    private static let streak2 = StreakData(current: 2, longest: 2, isVisible: true, isAtRisk: true)
    private static let streak12 = StreakData(current: 12, longest: 21, isVisible: true, isAtRisk: false)

    // MARK: - Günler

    /// İlk gün: seri hapı yok, hafta şeridinde yalnız bugün, geri dönüş yok.
    static let firstDay = TodayData(
        userName: nil,
        mode: .daily,
        isFirstDay: true,
        streak: StreakData(current: 0, longest: 0, isVisible: true, isAtRisk: false),
        resurface: nil,
        checkIns: [dailyCard(.notStarted)],
        practices: [],
        theme: theme
    )

    /// Ritüel başlamadı; iki günlük seri risk altında.
    static let notStarted = TodayData(
        userName: "Deniz",
        mode: .daily,
        isFirstDay: false,
        streak: streak2,
        resurface: resurfaceQuestion,
        checkIns: [dailyCard(.notStarted)],
        practices: Array(practices.prefix(2)),
        theme: theme
    )

    /// Akış yarıda kaldı: "Devam et · 3/5".
    static let inProgress = TodayData(
        userName: "Deniz",
        mode: .daily,
        isFirstDay: false,
        streak: streak2,
        resurface: nil,
        checkIns: [dailyCard(.inProgress(step: 3, total: 5))],
        practices: Array(practices.prefix(2)),
        theme: theme
    )

    /// Ritüel tamam, tema yazıldı.
    static let done = TodayData(
        userName: "Deniz",
        mode: .daily,
        isFirstDay: false,
        streak: streak12,
        resurface: resurfaceYearAgo,
        checkIns: [dailyCard(.done(checkInEvening, detail: nil))],
        practices: practices,
        theme: themeWritten
    )

    /// Sabah tamam (odak), akşam başlamadı.
    static let morningEvening = TodayData(
        userName: "Deniz",
        mode: .morningEvening,
        isFirstDay: false,
        streak: streak12,
        resurface: nil,
        checkIns: [
            morningCard(.done(checkInMorning, detail: "Odak: Sabır")),
            eveningCard(.notStarted),
        ],
        practices: practices,
        theme: theme
    )

    /// Sabah 14:00'e kadar yapılmadı; akşam başlamadı.
    static let morningMissed = TodayData(
        userName: nil,
        mode: .morningEvening,
        isFirstDay: false,
        streak: streak2,
        resurface: nil,
        checkIns: [morningCard(.missed), eveningCard(.notStarted)],
        practices: practices,
        theme: theme
    )

    /// Seri profil ayarından gizli.
    static let streakHidden = TodayData(
        userName: done.userName,
        mode: done.mode,
        isFirstDay: false,
        streak: StreakData(current: 12, longest: 21, isVisible: false, isAtRisk: false),
        resurface: nil,
        checkIns: done.checkIns,
        practices: done.practices,
        theme: done.theme
    )

    // MARK: - Hafta şeridi ve gün kaynağı

    /// Bu hafta: pazartesi ve salı tamam, çarşamba (dün) boş, bugün açık.
    static var weekFew: WeekStripData {
        WeekStripData.week(containing: today, today: today, completions: completions)
    }

    /// Son dört haftanın tamamlanması: önceki haftalarda boşluk ve yarım gün var.
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

    /// Geçmiş bir günün görünümü: tamamlandıysa özet; boş ve son 7 gündeyse
    /// doldurulabilir (başlamadı); daha eskiyse kayıt yok. Pratik ve tema yok.
    static func pastDay(_ day: DayKey) -> TodayData {
        let completion = completions[day] ?? .none
        let distance = day.days(to: today)
        let echoes = [
            "Yavaş bir gündü; yavaşlık da bir cevap.",
            "Yorgunluğunu adlandırmak onu biraz hafifletti.",
            "Küçük bir şey iyi gitti ve bunu gördün.",
        ]
        let seed = day.string.unicodeScalars.reduce(0) { $0 + Int($1.value) }
        let status: RitualStatus
        if completion == .none {
            status = distance <= WeekStripData.backfillWindow ? .notStarted : .empty
        } else {
            status = .done(CheckInSummary(
                id: "fx_checkin_\(day.string)",
                time: FixtureClock.daysAgo(distance, 21, 10),
                slot: .daily,
                score: [2, 3, 4, 4, 5][seed % 5],
                emotions: [EmotionCatalogFixture.emotion("huzur.sakin")],
                causes: ["İş"],
                echo: echoes[seed % echoes.count]
            ), detail: nil)
        }
        return TodayData(
            userName: notStarted.userName,
            mode: .daily,
            isFirstDay: false,
            streak: notStarted.streak,
            resurface: nil,
            checkIns: [dailyCard(status)],
            practices: [],
            theme: nil
        )
    }

    /// Bugün `data`, geçmiş günler `pastDay`.
    static func source(_ data: TodayData, isContentStale: Bool = false) -> TodaySource {
        let today = today
        return TodaySource(today: today, weeks: weeks, isContentStale: isContentStale) { day in
            .loaded(day == today ? data : pastDay(day))
        }
    }

    /// Uygulamanın kabukta gösterdiği varsayılan (UX-11'e kadar).
    static var app: TodaySource { app(drafts: [:], finished: [:]) }

    /// Kabuk oturumunda yarıda bırakılan ve biten akışlar kartlara yansır:
    /// taslak → "Devam et · n/m", bitiş → tamam (skor ve yankıyla).
    static func app(drafts: [FlowKind: FlowDraftData], finished: [FlowKind: FlowSession]) -> TodaySource {
        let cards = notStarted.checkIns.map { card -> CheckInCardData in
            if let session = finished[card.flow] {
                let summary = CheckInSummary(
                    id: "fx_checkin_session_\(card.flow.rawValue)",
                    time: FixtureClock.now,
                    slot: card.slot,
                    score: session.score ?? 3,
                    emotions: [],
                    causes: [],
                    echo: session.flow.echo
                )
                return CheckInCardData(slot: card.slot, flow: card.flow, status: .done(summary, detail: nil), minutes: card.minutes)
            }
            if let draft = drafts[card.flow] {
                let total = FlowFixture.flow(card.flow).steps.count
                return CheckInCardData(slot: card.slot, flow: card.flow,
                                       status: .inProgress(step: draft.stepIndex + 1, total: total), minutes: card.minutes)
            }
            return card
        }
        let data = TodayData(
            userName: notStarted.userName, mode: notStarted.mode, isFirstDay: false, streak: notStarted.streak,
            resurface: notStarted.resurface, checkIns: cards, practices: notStarted.practices, theme: notStarted.theme
        )
        return source(data)
    }

    /// Profil › açılış check-in'i (UX-11'de ayar deposundan).
    static let launchCheckInEnabled = true

    static var loading: TodaySource {
        TodaySource(today: today, weeks: weeks) { _ in .loading }
    }

    static var failed: TodaySource {
        TodaySource(today: today, weeks: weeks) { _ in .failed(message: "fixture") }
    }
}
