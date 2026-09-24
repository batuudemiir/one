//
//  TodayViewDataTests.swift
//  oneTests
//
//  06_giris_akislari.md › Bugün ekranı: saat kuralları, süre etiketleri,
//  hafta şeridi durumları, fixture içeriği.
//

import Testing
import Foundation
@testable import OneDailyBatuhan

@MainActor
struct TodayViewDataTests {

    @Test("Selamlama: 05–12 günaydın, 12–18 iyi günler, 18–05 iyi akşamlar")
    func greeting() {
        let morning = TodayRules.greeting(hour: 5), day = TodayRules.greeting(hour: 12), evening = TodayRules.greeting(hour: 18)
        #expect(Set([morning, day, evening]).count == 3)
        #expect(TodayRules.greeting(hour: 11) == morning)
        #expect(TodayRules.greeting(hour: 17) == day)
        #expect(TodayRules.greeting(hour: 23) == evening && TodayRules.greeting(hour: 4) == evening)
    }

    @Test("Kart sırası: 05–14 sabah önde, 14 sonrası akşam önde")
    func ritualOrder() {
        let cards = [TodayFixtures.card(.evening, .notStarted), TodayFixtures.card(.morning, .notStarted)]
        #expect(TodayRules.ordered(cards, hour: 5).map(\.flow) == [.morning, .evening])
        #expect(TodayRules.ordered(cards, hour: 13).map(\.flow) == [.morning, .evening])
        #expect(TodayRules.ordered(cards, hour: 14).map(\.flow) == [.evening, .morning])
        #expect(TodayRules.ordered(cards, hour: 2).map(\.flow) == [.evening, .morning])
    }

    @Test("Sabah 14:00'ten sonra başlamadıysa kaçırıldı; yarıda ya da tamamsa değil")
    func missedMorning() {
        #expect(TodayRules.morningState(.notStarted, hour: 13) == .notStarted)
        #expect(TodayRules.morningState(.notStarted, hour: 14) == .missed)
        #expect(TodayRules.morningState(.inProgress(step: 2, total: 6), hour: 20) == .inProgress(step: 2, total: 6))
    }

    @Test("Süre: skor adımları 10 sn, yazı adımları 30 sn; kapalı ek adım sayılmaz")
    func durations() {
        #expect(FlowDuration.seconds(FlowFixtures.steps(.moodCheckIn)) == 60)
        #expect(FlowDuration.seconds(FlowFixtures.steps(.daily)) == 90)
        #expect(FlowDuration.seconds(FlowFixtures.steps(.morning)) == 120) // duygular kapalı
        #expect(FlowDuration.seconds(FlowFixtures.steps(.evening)) == 170)
        #expect(FlowDuration.seconds(FlowFixtures.steps(.evening, variant: .withoutMorning)) == 160)
        let short = [FlowStepViewData(id: "a", kind: .score, title: "", optional: false)]
        #expect(FlowDuration.label(short) != FlowDuration.label(FlowFixtures.steps(.evening)))
    }

    @Test("Adım listeleri: yalnız skor zorunlu; sabahta duygular kapalı; akşam varyantları")
    func stepLists() {
        for kind in FlowKind.rituals {
            let steps = FlowFixtures.steps(kind)
            #expect(steps.filter { !$0.optional }.allSatisfy { $0.kind == .score })
            #expect(Set(steps.map(\.id)).count == steps.count)
        }
        #expect(FlowFixtures.steps(.morning).first { $0.kind == .emotions }?.isEnabled == false)
        #expect(FlowFixtures.steps(.evening).map(\.kind).contains(.intentionReview))
        #expect(!FlowFixtures.steps(.evening, variant: .withoutMorning).map(\.kind).contains(.intentionReview))
        #expect(!FlowFixtures.steps(.evening, variant: .withoutPractices).map(\.kind).contains(.practices))
        #expect(FlowFixtures.flow(.evening, variant: .withoutMorning).closing.carryOver.isEmpty)
        #expect(FlowFixtures.flow(.moodCheckIn).closing.seal == .none)
        #expect(FlowFixtures.flow(.morning).closing.seal == .half)
    }

    @Test("Hafta: bugünden önceki boş gün 7 gün içindeyse doldurulabilir; bugün ve gelecek değil")
    func weekFixture() {
        let week = TodayFixtures.week(past: [.done, .half, .gap])
        #expect(week.map(\.status) == [.done, .half, .gap, .today, .future, .future, .future])
        #expect(week.map(\.canBackfill) == [false, false, true, false, false, false, false])
        #expect(week[2].relativeLabel == NSLocalizedString("one2.day.yesterday", comment: ""))
        #expect(week.filter(\.isToday).map(\.id) == ["2026-09-24"])
    }

    @Test("Canlı hücre → view data: açık geçmiş gün gap, bugün today; 7 günden eski doldurulamaz")
    func weekAdapter() {
        let today = DayKey("2026-09-24")!
        let cells = WeekStripModel.week(containing: today, completions: [
            DayCompletion(day: DayKey("2026-09-21")!, dailyCompletedAt: Date()),
        ], mode: .daily)
        let days = WeekStripAdapter.viewData(cells)
        #expect(days.map(\.status) == [.done, .gap, .gap, .today, .future, .future, .future])
        #expect(days.map(\.canBackfill) == [false, true, true, false, false, false, false])

        let old = WeekStripAdapter.viewData([WeekDayCell(day: DayKey("2026-09-10")!, state: .open, isToday: false),
                                             WeekDayCell(day: today, state: .done, isToday: true)])
        #expect(old[0].status == .gap && !old[0].canBackfill)
        #expect(old[1].status == .done && old[1].isToday)
    }

    @Test("Fixture içeriği paketten yüklenir; Bugün durumları kurulur")
    func fixtures() {
        let c = UXFixtures.content
        #expect(!c.emotions.isEmpty && !c.causes.isEmpty && !c.practices.isEmpty && c.dailyPrompts.count == 3)
        #expect(Set(c.emotions.compactMap(\.group)).count == 8)
        let both = TodayFixtures.bothDone()
        #expect(both.rituals.map(\.flow) == [.evening, .morning]) // 21:00: akşam önde
        #expect(both.rituals.allSatisfy { if case .done = $0.state { true } else { false } })
        #expect(TodayFixtures.morningMissed().rituals.first { $0.flow == .morning }?.state == .missed)
        #expect(TodayFixtures.dailyNotStarted().layout == .daily)
    }

    @Test("Cevap anlamlı mı: boş metin ve boş liste cevap sayılmaz")
    func meaningfulAnswers() {
        #expect(FlowAnswer.score(3).isMeaningful)
        #expect(!FlowAnswer.text("  \n").isMeaningful && FlowAnswer.text("a").isMeaningful)
        #expect(!FlowAnswer.list(["", " "]).isMeaningful && FlowAnswer.list(["", "b"]).isMeaningful)
        #expect(!FlowAnswer.choices([]).isMeaningful && !FlowAnswer.focus(" ", custom: true).isMeaningful)
    }
}
