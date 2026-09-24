//
//  FlowViewModelTests.swift
//  oneTests
//
//  06 › Akış kabuğu: yalnız skor zorunlu, atlama, taslak (her adımda ve
//  kapatınca), kaldığı yerden devam, ek adım, sonuç.
//

import Testing
import Foundation
@testable import OneDailyBatuhan

@MainActor
struct FlowViewModelTests {

    static func model(_ kind: FlowKind, drafts: InMemoryFlowDraftStore? = nil,
                      variant: FlowFixtureVariant = .standard) -> FlowViewModel {
        FlowViewModel(flow: FlowFixtures.flow(kind, variant: variant), drafts: drafts ?? InMemoryFlowDraftStore())
    }

    @Test("Skor cevapsız geçilemez; diğer adımlar atlanabilir, atlanan cevap silinir")
    func requiredScore() {
        let m = Self.model(.moodCheckIn)
        #expect(m.current?.kind == .score && !m.canContinue && !m.canSkip)
        m.next()
        #expect(m.stepIndex == 0)
        m.setAnswer(.score(2), for: "moodCheckIn.score")
        m.next()
        #expect(m.current?.kind == .emotions && m.canContinue && m.canSkip)
        m.setAnswer(.choices(["e_yorgun"]), for: "moodCheckIn.emotions")
        m.skip()
        #expect(m.answer(for: "moodCheckIn.emotions") == nil)
        #expect(m.current?.kind == .causes)
    }

    @Test("Taslak her adım bitince ve kapatınca kaydedilir; açınca kaldığı adımdan devam")
    func draftResume() {
        let drafts = InMemoryFlowDraftStore()
        let first = Self.model(.daily, drafts: drafts)
        first.setAnswer(.score(4), for: "daily.score")
        first.next()
        #expect(drafts.load(.daily)?.stepIndex == 1)
        first.setAnswer(.choices(["e_huzurlu"]), for: "daily.emotions")
        #expect(drafts.load(.daily)?.answers["daily.emotions"] == nil) // yazarken değil
        first.close()
        #expect(drafts.load(.daily)?.answers["daily.emotions"] == .choices(["e_huzurlu"]))

        let reopened = Self.model(.daily, drafts: drafts)
        #expect(reopened.stepIndex == 1 && reopened.current?.id == "daily.emotions")
        #expect(reopened.answer(for: "daily.score") == .score(4))
    }

    @Test("Son adımdan sonra kapanış; taslak silinir; sonuç yalnız anlamlı cevaplar; tamamlama bir kez")
    func finish() {
        let drafts = InMemoryFlowDraftStore()
        let m = Self.model(.moodCheckIn, drafts: drafts)
        var results: [FlowResult] = []
        m.onComplete = { results.append($0) }
        m.setAnswer(.score(5), for: "moodCheckIn.score")
        m.next(); m.skip(); m.skip()
        m.setAnswer(.text("   "), for: "moodCheckIn.note")
        #expect(m.isLastStep)
        m.next()
        #expect(m.phase == .closing && drafts.load(.moodCheckIn) == nil)
        #expect(m.result.answers == ["moodCheckIn.score": .score(5)])
        m.complete(carryOver: true)
        m.complete()
        #expect(results.count == 1 && results[0].carryOver == nil) // mood akışında taşıma sorusu yok
    }

    @Test("Sabah: duygular kapalı ek adım; skordan tek dokunuşla açılır ve sayılır")
    func optionalEmotionsStep() {
        let drafts = InMemoryFlowDraftStore()
        let m = Self.model(.morning, drafts: drafts)
        #expect(!m.steps.map(\.kind).contains(.emotions))
        let total = m.steps.count
        m.next() // uyku isteğe bağlı
        #expect(m.current?.kind == .score)
        let extra = m.optionalStepAfterCurrent
        #expect(extra?.kind == .emotions)
        m.enableStep(extra?.id ?? "")
        #expect(m.steps.count == total + 1 && m.optionalStepAfterCurrent == nil)
        #expect(drafts.load(.morning)?.enabledSteps == ["morning.emotions"])
        #expect(Self.model(.morning, drafts: drafts).steps.count == total + 1)
    }

    @Test("Neden etiketi eklenir ve seçilir; aynı ad ikinci kez eklenmez")
    func addCause() {
        let m = Self.model(.moodCheckIn)
        let step = FlowFixtures.flow(.moodCheckIn).steps[2]
        let before = m.options(for: step).count
        let added = m.addOption("  Trafik ", to: step.id)
        #expect(added?.label == "Trafik")
        #expect(m.options(for: step).count == before + 1)
        m.addOption("trafik", to: step.id)
        #expect(m.options(for: step).count == before + 1)
        #expect(m.answer(for: step.id) == .choices([added?.id ?? ""]))
        #expect(m.addOption("   ", to: step.id) == nil)
    }

    @Test("Akşam kapanışı: taşıma kararı sonuca girer")
    func carryOverDecision() {
        let m = Self.model(.evening)
        var result: FlowResult?
        m.onComplete = { result = $0 }
        m.setAnswer(.score(3), for: "evening.score")
        m.next()
        while m.phase == .steps { m.skip() }
        #expect(!m.flow.closing.carryOver.isEmpty)
        m.complete(carryOver: false)
        #expect(result?.carryOver == false && result?.answers.count == 1)
    }

    @Test("Bozuk taslak: adım sayısını aşan indeks son adıma çekilir")
    func clampedDraft() {
        let drafts = InMemoryFlowDraftStore([.daily: FlowProgress(flow: .daily, stepIndex: 40)])
        let m = Self.model(.daily, drafts: drafts)
        #expect(m.stepIndex == m.steps.count - 1)
    }
}
