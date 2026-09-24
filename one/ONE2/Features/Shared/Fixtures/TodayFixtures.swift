//
//  TodayFixtures.swift
//  ONE 2.0
//
//  Bugün ekranının örnek durumları (06 › Önizlemeler). Hafta 21–27 Eylül
//  2026, bugün perşembe (24'ü).
//

import Foundation

nonisolated enum TodayFixtures {
    static let monday = DateComponents(year: 2026, month: 9, day: 21)
    static let todayIndex = 3

    /// Pazartesi–pazar; bugünden öncekiler verilen durumlarda, sonrası gelecek.
    static func week(past: [WeekDayStatus] = [.done, .half, .gap], todayStatus: WeekDayStatus = .today,
                     calendar: Calendar = .current) -> [WeekDayViewData] {
        guard let start = calendar.date(from: monday) else { return [] }
        return (0..<7).map { offset in
            let date = calendar.date(byAdding: .day, value: offset, to: start) ?? start
            let status: WeekDayStatus
            if offset < todayIndex { status = past.indices.contains(offset) ? past[offset] : .gap }
            else if offset == todayIndex { status = todayStatus }
            else { status = .future }
            let age = todayIndex - offset
            let weekdayIndex = calendar.component(.weekday, from: date) - 1
            return WeekDayViewData(
                id: String(format: "%04d-%02d-%02d", calendar.component(.year, from: date),
                           calendar.component(.month, from: date), calendar.component(.day, from: date)),
                weekdayLabel: calendar.shortStandaloneWeekdaySymbols[weekdayIndex],
                dayNumber: calendar.component(.day, from: date),
                status: status,
                isToday: offset == todayIndex,
                canBackfill: status == .gap && age >= 1 && age <= TodayRules.backfillDays,
                longLabel: date.formatted(.dateTime.weekday(.wide).day().month(.wide)),
                relativeLabel: age == 1 ? NSLocalizedString("one2.day.yesterday", comment: "Yesterday, capitalised")
                                        : date.formatted(.dateTime.weekday(.wide))
            )
        }
    }

    // MARK: Kartlar

    static func card(_ flow: FlowKind, _ state: RitualCardState) -> RitualCardViewData {
        RitualCardViewData(flow: flow, title: RitualCopy.title(flow),
                           durationLabel: FlowDuration.label(FlowFixtures.steps(flow)), state: state)
    }

    static func done(_ flow: FlowKind, content c: UXFixtureContent = UXFixtures.content) -> RitualCardState {
        let mood = MoodPillViewData(score: 4, label: FlowFixtures.scoreLabel(4), emotions: c.moodEmotions)
        let summary: String?
        switch flow {
        case .morning: summary = RitualCopy.focusSummary(FlowFixtures.focusLabel(c.morningFocus))
        case .evening: summary = RitualCopy.practicesSummary(min(2, c.practices.count))
        default:       summary = nil
        }
        return .done(echo: c.echo(flow), mood: mood, summary: summary)
    }

    private static func base(hour: Int, layout: RitualLayout, rituals: [RitualCardViewData],
                             todayStatus: WeekDayStatus, content c: UXFixtureContent) -> TodayViewData {
        TodayViewData(
            streak: c.streak, hour: hour, week: week(todayStatus: todayStatus), layout: layout,
            rituals: layout == .morningEvening ? TodayRules.ordered(rituals, hour: hour) : rituals,
            practices: c.practices.map { PracticeTileViewData(id: $0.id, title: $0.label, symbol: $0.group ?? "circle") },
            theme: c.theme.map { WeeklyThemeViewData(name: $0.name, dayIndex: $0.dayIndex, prompt: $0.prompt) })
    }

    // MARK: Önizleme durumları

    /// Günlük mod, başlamadı (sabah 9).
    static func dailyNotStarted(content c: UXFixtureContent = UXFixtures.content) -> TodayViewData {
        base(hour: 9, layout: .daily, rituals: [card(.daily, .notStarted)], todayStatus: .today, content: c)
    }

    /// Günlük mod, yarıda.
    static func dailyInProgress(content c: UXFixtureContent = UXFixtures.content) -> TodayViewData {
        let total = FlowFixtures.steps(.daily).filter(\.isEnabled).count
        return base(hour: 13, layout: .daily, rituals: [card(.daily, .inProgress(step: 3, total: total))],
                    todayStatus: .today, content: c)
    }

    /// Sabah+akşam, sabah tamam, akşam başlamadı (öğleden sonra: akşam önde).
    static func morningDone(content c: UXFixtureContent = UXFixtures.content) -> TodayViewData {
        base(hour: 16, layout: .morningEvening,
             rituals: [card(.morning, done(.morning, content: c)), card(.evening, .notStarted)],
             todayStatus: .half, content: c)
    }

    /// Sabah+akşam, ikisi tamam.
    static func bothDone(content c: UXFixtureContent = UXFixtures.content) -> TodayViewData {
        var data = base(hour: 21, layout: .morningEvening,
                        rituals: [card(.morning, done(.morning, content: c)), card(.evening, done(.evening, content: c))],
                        todayStatus: .done, content: c)
        data.theme?.writtenFirstLine = c.theme?.writtenFirstLine
        return data
    }

    /// Sabah+akşam, sabah kaçırıldı (15:00).
    static func morningMissed(content c: UXFixtureContent = UXFixtures.content) -> TodayViewData {
        base(hour: 15, layout: .morningEvening,
             rituals: [card(.morning, TodayRules.morningState(.notStarted, hour: 15)), card(.evening, .notStarted)],
             todayStatus: .today, content: c)
    }
}
