//
//  LiveFlowMappingTests.swift
//  oneTests
//
//  UX-11 bağlaması: akış sonucunun kayıt karşılıkları, cihazdaki taslak ve
//  kart kaydı.
//

import Testing
import Foundation
@testable import OneDailyBatuhan

@MainActor
struct LiveFlowMappingTests {

    static func result(_ kind: FlowKind, _ answers: [String: FlowAnswer]) -> FlowResult {
        FlowResult(flow: kind, answers: answers)
    }

    @Test("Mood: skor + duygular + nedenler; skor yoksa mood yok")
    func mood() {
        let steps = FlowFixtures.steps(.daily)
        let full = Self.result(.daily, ["daily.score": .score(2), "daily.emotions": .choices(["e_yorgun"]),
                                        "daily.causes": .choices(["c_uyku", "custom:trafik"])])
        #expect(FlowEntryMapping.mood(full, steps: steps)
                == .init(score: 2, emotionIDs: ["e_yorgun"], causeIDs: ["c_uyku", "custom:trafik"]))
        #expect(FlowEntryMapping.mood(Self.result(.daily, [:]), steps: steps) == nil)
    }

    @Test("Girdi cevapları: adım sırasıyla, mood adımları hariç, boş cevaplar atlanır")
    func answers() {
        let steps = FlowFixtures.steps(.morning)
        let r = Self.result(.morning, [
            "morning.sleep": .sleep(score: 4, hours: 7.5),
            "morning.score": .score(3),
            "morning.focus": .focus("sabir", custom: false),
            "morning.quote": .text("  Bugün acele etmeyeceğim.  "),
            "morning.priorities": .list(["Rapor", "", "Yürüyüş"]),
            "morning.challenge": .text("   "),
        ])
        let a = FlowEntryMapping.answers(r, steps: steps)
        #expect(a.map(\.stepRef) == ["morning.sleep", "morning.sleep.hours", "morning.focus", "morning.quote", "morning.priorities"])
        #expect(a.map(\.order) == [0, 1, 2, 3, 4])
        #expect(a[0].kind == .scale5 && a[0].number == 4)
        #expect(a[1].number == 7.5)
        #expect(a[2].kind == .singleChoice && a[2].choices == ["sabir"])
        #expect(a[3].text == "Bugün acele etmeyeceğim." && a[3].questionSnapshot == steps[4].prompt)
        #expect(a[4].kind == .todo && a[4].choices == ["Rapor", "Yürüyüş"])
        #expect(FlowEntryMapping.body(a) == "Bugün acele etmeyeceğim.\n\nRapor\nYürüyüş")
        #expect(FlowEntryMapping.focus(r, steps: steps) == "sabir")
        #expect(FlowEntryMapping.quoteReflection(r, steps: steps)?.text == "Bugün acele etmeyeceğim.")
    }

    @Test("Akşam: niyet ve pratikler; pratik adımı varsa sayı, yoksa nil")
    func evening() {
        let steps = FlowFixtures.steps(.evening)
        let r = Self.result(.evening, ["evening.intention": .intention("kept"),
                                       "evening.practices": .practices(["pr_nefes"])])
        let a = FlowEntryMapping.answers(r, steps: steps)
        #expect(a.map(\.kind) == [.singleChoice, .multiChoice])
        #expect(FlowEntryMapping.practicesDone(r, steps: steps) == 1)
        #expect(FlowEntryMapping.practicesDone(Self.result(.evening, [:]), steps: steps) == 0)
        #expect(FlowEntryMapping.practicesDone(r, steps: FlowFixtures.steps(.evening, variant: .withoutPractices)) == nil)
        #expect(FlowEntryMapping.body(a) == nil)
    }

    @Test("Tür eşlemesi: girdi türü, ritüel kartı, mühür")
    func kinds() {
        #expect(FlowKind.allCases.map(FlowEntryMapping.entryKind) == [.emotionCheckIn, .dailyCheckIn, .morning, .evening])
        #expect(FlowKind.allCases.map(FlowEntryMapping.ritualCard) == [nil, .daily, .morning, .evening])
        #expect(FlowKind.allCases.map(FlowEntryMapping.seal) == [.none, .full, .half, .full])
    }

    @Test("Cihazdaki taslak gün ve akış başına; kart kaydı okunur")
    func stores() {
        let backing = MemoryKeyValueStore()
        let today = DefaultsFlowDraftStore(day: DayKey("2026-09-24")!, backing: backing)
        let yesterday = DefaultsFlowDraftStore(day: DayKey("2026-09-23")!, backing: backing)
        var progress = FlowProgress(flow: .evening, stepIndex: 3, answers: ["evening.score": .score(4)])
        progress.enabledSteps = ["x"]
        today.save(progress)
        #expect(today.load(.evening) == progress)
        #expect(yesterday.load(.evening) == nil && today.load(.morning) == nil)
        today.clear(.evening)
        #expect(today.load(.evening) == nil)

        let records = FlowCompletionStore(backing: backing)
        let record = FlowCompletionRecord(echo: "Yankı", score: 4, emotionLabels: ["Huzurlu"], practicesDone: 2)
        records.save(record, .evening, on: DayKey("2026-09-24")!)
        #expect(records.load(.evening, on: DayKey("2026-09-24")!) == record)
        #expect(records.load(.morning, on: DayKey("2026-09-24")!) == nil)
    }
}
