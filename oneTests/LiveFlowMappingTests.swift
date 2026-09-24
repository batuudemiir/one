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
        #expect(FlowKind.allCases.map(FlowEntryMapping.entryKind) == [.emotionCheckIn, .dailyCheckIn, .morning, .evening, .guided])
        #expect(FlowKind.allCases.map(FlowEntryMapping.ritualCard) == [nil, .daily, .morning, .evening, nil])
        #expect(FlowKind.allCases.map(FlowEntryMapping.seal) == [.none, .full, .half, .full, .saved])
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

    // MARK: - Rehberli günlük, taşıma

    static let journal = GuidedJournal(
        id: "g_test", title: "Deneme", summary: "Kısa bir deneme.", durationMinutes: 3, tags: [], timeOfDay: .any,
        steps: [.init(id: "s1", kind: .scale5, prompt: "Enerjin?", choices: nil),
                .init(id: "s2", kind: .multiChoice, prompt: "Ne var?", choices: ["İş", "Ev"]),
                .init(id: "s3", kind: .todo, prompt: "Üç adım", choices: nil),
                .init(id: "s4", kind: .yesNo, prompt: "Oldu mu?", choices: nil),
                .init(id: "s5", kind: .focus, prompt: "Odak?", choices: nil)],
        premium: false, active: true, addedIn: 1, lang: "tr")

    @Test("Rehberli günlük: içerik adımları akış adımlarına; hepsi isteğe bağlı; skor ve seçim girdiye yazılır")
    func guidedSteps() {
        let steps = GuidedFlows.steps(Self.journal)
        #expect(steps.map(\.kind) == [.score, .causes, .list3, .intentionReview, .text])
        #expect(steps.allSatisfy(\.optional) && steps.allSatisfy { $0.prompt != nil && $0.title == "Deneme" })
        #expect(steps[1].options?.map(\.id) == ["İş", "Ev"] && steps[3].options?.map(\.id) == ["yes", "no"])
        let r = Self.result(.guided, [steps[0].id: .score(4), steps[1].id: .choices(["Ev"]), steps[3].id: .intention("yes")])
        #expect(FlowEntryMapping.answers(r, steps: steps).isEmpty == false)
        #expect(FlowEntryMapping.answers(r, steps: steps).map(\.kind) == [.singleChoice])
        #expect(FlowEntryMapping.answers(r, steps: steps, includeMoodSteps: true).map(\.kind) == [.scale5, .multiChoice, .singleChoice])
        #expect(FlowEntryMapping.mood(r, steps: steps)?.score == 4) // rehberli kayıt mood'u kullanmaz, eşleme yine çalışır
        #expect(GuidedFlows.id(from: "guided:g_test") == "g_test" && GuidedFlows.ref("g_test") == "guided:g_test")
    }

    @Test("Pratik listesi: eklenen işaretli, premium kilitli, başka dil yok")
    func pickerItems() {
        let premium = GuidedJournal(id: "g_p", title: "P", summary: "", durationMinutes: nil, tags: [], timeOfDay: .any,
                                steps: [], premium: true, active: true, addedIn: 1, lang: "tr")
        let english = GuidedJournal(id: "g_en", title: "E", summary: "", durationMinutes: nil, tags: [], timeOfDay: .any,
                                    steps: [], premium: false, active: true, addedIn: 1, lang: "en")
        let items = GuidedFlows.pickerItems([Self.journal, premium, english], added: ["guided:g_test"], lang: "tr", hasPremium: false)
        #expect(items.map(\.id) == ["guided:g_test", "guided:g_p"])
        #expect(items[0].isAdded && !items[0].isLocked && items[0].durationLabel != nil)
        #expect(items[1].isLocked && !items[1].isAdded)
        #expect(!GuidedFlows.pickerItems([premium], added: [], lang: "tr", hasPremium: true)[0].isLocked)
    }

    @Test("Taşıma: sabah öncelikleri okunur; yarına en fazla 3 dolu madde; taslak kapsamı ayrı")
    func carryOver() {
        let morning = JournalEntry(id: UUID(), day: DayKey("2026-09-24")!, timeZoneID: nil, createdAt: Date(), updatedAt: Date(),
                                   kind: .morning, title: nil, body: nil, wordCount: 0, contentRef: nil, contentSnapshot: nil,
                                   isBackfilled: false, sourceContext: nil, comparedEntryID: nil, moodID: nil, tagIDs: [],
                                   answers: [EntryAnswer(kind: .todo, stepRef: "morning.priorities", choices: ["Rapor", "Yürüyüş"])])
        #expect(FlowEntryMapping.priorities(in: [morning]) == ["Rapor", "Yürüyüş"])

        let backing = MemoryKeyValueStore()
        let store = CarryOverStore(backing: backing)
        let tomorrow = DayKey("2026-09-25")!
        store.carry(["Rapor", " ", "Yürüyüş", "Okuma", "Fazla"], to: tomorrow)
        #expect(store.items(for: tomorrow) == ["Rapor", "Yürüyüş", "Okuma"])
        store.clear(tomorrow)
        #expect(store.items(for: tomorrow).isEmpty)

        let a = DefaultsFlowDraftStore(day: tomorrow, scope: "g_a", backing: backing)
        let b = DefaultsFlowDraftStore(day: tomorrow, scope: "g_b", backing: backing)
        a.save(FlowProgress(flow: .guided, stepIndex: 2))
        #expect(a.load(.guided)?.stepIndex == 2 && b.load(.guided) == nil)
    }

    @Test("Başlangıç cevapları yalnız taslak yokken")
    func initialAnswers() {
        let initial: [String: FlowAnswer] = ["morning.priorities": .list(["Rapor"])]
        let fresh = FlowViewModel(flow: FlowFixtures.flow(.morning), drafts: InMemoryFlowDraftStore(), initialAnswers: initial)
        #expect(fresh.answer(for: "morning.priorities") == .list(["Rapor"]))
        let drafted = FlowViewModel(flow: FlowFixtures.flow(.morning),
                                    drafts: InMemoryFlowDraftStore([.morning: FlowProgress(flow: .morning, stepIndex: 1)]),
                                    initialAnswers: initial)
        #expect(drafted.answer(for: "morning.priorities") == nil)
    }
}
