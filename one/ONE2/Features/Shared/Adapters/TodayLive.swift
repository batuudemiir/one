//
//  TodayLive.swift
//  ONE 2.0
//
//  Bugün ekranının motora bağlanması (UX-11, UX_istekleri.md › 7).
//
//  - Seri: `DayStore.streakState` (profilde gizliyse yok)
//  - Hafta: `WeekStripModel` + `WeekStripAdapter`
//  - Kartlar: gün kaydından tamam; cihazdaki taslaktan yarıda; sabah
//    14:00'ten sonra başlamadıysa kaçırıldı. Tamam kartın yankısı ve mood
//    hapı `FlowCompletionStore`'dan; yoksa günün son check-in'i.
//  - Pratikler: `LibraryStore.practices()` (açma/ekleme ekranı yok,
//    karolar dokunulamaz)
//  - Haftalık tema: `ThemeCalendar` + bugünün sorusuna yazılan ilk satır
//

import Foundation

enum TodayLive {

    struct Loaded {
        let data: TodayViewData
        let seed: FlowSeedContent
    }

    static func load(_ env: AppEnvironment, notice: String?) async -> Loaded {
        let today = env.clock.today
        let profile = env.profile.profile
        let seed = await LiveFlows.seed(env, on: today)
        let completion = try? env.day.completion(on: today)
        let drafts = DefaultsFlowDraftStore(day: today)
        let records = FlowCompletionStore()
        let hour = env.clock.calendar.component(.hour, from: env.clock.now)
        let lastMood = (try? env.mood.logs(on: today))?.last

        let layout: RitualLayout = profile.ritualMode == .daily ? .daily : .morningEvening
        let flows: [FlowKind] = layout == .daily ? [.daily] : [.morning, .evening]
        let cards = flows.map { flow -> RitualCardViewData in
            let steps = LiveFlows.steps(flow, on: today, env: env, seed: seed)
            var state: RitualCardState
            if isDone(flow, completion) {
                let record = records.load(flow, on: today)
                let mood = record?.score.map { MoodPillViewData(score: $0, label: FlowFixtures.scoreLabel($0),
                                                               emotions: record?.emotionLabels ?? []) }
                    ?? lastMood.map { MoodPillViewData(score: $0.score, label: FlowFixtures.scoreLabel($0.score)) }
                state = .done(echo: record?.echo ?? "", mood: mood, summary: summary(flow, record: record, seed: seed))
            } else if let draft = drafts.load(flow) {
                let total = steps.filter { $0.isEnabled || draft.enabledSteps.contains($0.id) }.count
                state = .inProgress(step: min(draft.stepIndex + 1, total), total: total)
            } else {
                state = .notStarted
            }
            if flow == .morning { state = TodayRules.morningState(state, hour: hour) }
            return RitualCardViewData(flow: flow, title: RitualCopy.title(flow),
                                      durationLabel: FlowDuration.label(steps), state: state)
        }

        let streak = try? env.day.streakState(mode: profile.ritualMode, visible: profile.streakVisible)
        let data = TodayViewData(
            streak: streak.flatMap { $0.isVisible ? $0.count : nil },
            hour: hour,
            week: WeekStripAdapter.viewData(WeekStripModel.load(env)),
            layout: layout,
            rituals: layout == .morningEvening ? TodayRules.ordered(cards, hour: hour) : cards,
            practices: seed.practices.map { PracticeTileViewData(id: $0.id, title: $0.label, symbol: $0.group ?? "circle") },
            theme: theme(env, on: today),
            notice: notice)
        return Loaded(data: data, seed: seed)
    }

    static func isDone(_ flow: FlowKind, _ completion: DayCompletion?) -> Bool {
        switch flow {
        case .daily:       return completion?.dailyCompletedAt != nil
        case .morning:     return completion?.morningCompletedAt != nil
        case .evening:     return completion?.eveningCompletedAt != nil
        case .moodCheckIn, .guided: return false
        }
    }

    static func summary(_ flow: FlowKind, record: FlowCompletionRecord?, seed: FlowSeedContent) -> String? {
        switch flow {
        case .morning:
            let focus = seed.morningFocus.trimmingCharacters(in: .whitespaces)
            return focus.isEmpty ? nil : RitualCopy.focusSummary(FlowFixtures.focusLabel(focus))
        case .evening:
            return record?.practicesDone.map(RitualCopy.practicesSummary)
        default:
            return nil
        }
    }

    static func theme(_ env: AppEnvironment, on day: DayKey) -> WeeklyThemeViewData? {
        guard let week = ThemeCalendar.theme(for: day, catalog: env.content.catalog, salt: env.profile.profile.userSalt),
              let prompt = week.prompt(on: day) else { return nil }
        let ref = PromptSuggestion.themeRef(week: week.week, weekday: day.isoWeekday)
        let written = ((try? env.journal.entries(kind: .prompt, contentRef: ref)) ?? []).last
        return WeeklyThemeViewData(name: week.theme.title, dayIndex: day.isoWeekday, prompt: prompt,
                                   writtenFirstLine: written.map { JournalCopy.firstLine($0.body) })
    }
}
