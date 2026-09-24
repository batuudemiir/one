//
//  FlowSession.swift
//  ONE 2.0
//
//  Bir giriş akışının ilerleyişi (07 §5.2), görünümden bağımsız:
//  hangi adımdayız, cevaplar, ileri/geri/atla, taslak. Zorunlu olan yalnız
//  `score`; diğer her adım boş geçilebilir (07 §2.3). "Atla" yalnız
//  `optional` işaretli adımda görünür.
//

import Foundation

nonisolated struct FlowSession: Equatable, Sendable {
    let flow: FlowViewData
    private(set) var index: Int
    private(set) var answers: [String: FlowAnswerData]
    private(set) var isFinished = false

    init(flow: FlowViewData) {
        self.flow = flow
        self.index = flow.startIndex
        self.answers = flow.draft?.answers ?? [:]
    }

    var step: FlowStepViewData { flow.steps[index] }
    var total: Int { flow.steps.count }
    var isFirst: Bool { index == 0 }
    var isLast: Bool { index == flow.steps.count - 1 }

    func answer(for step: FlowStepViewData) -> FlowAnswerData? { answers[step.id] }

    /// Skor seçilmeden ilerlenmez; diğer adımlar boş da geçilebilir.
    var canContinue: Bool {
        step.kind != .score || answers[step.id] != nil
    }

    /// "Atla" görünür mü.
    var showsSkip: Bool { step.optional && step.kind != .score }

    mutating func set(_ answer: FlowAnswerData?, for stepID: String) {
        answers[stepID] = answer
    }

    /// Sonraki adım; son adımdaysa akış biter.
    mutating func next() {
        guard canContinue else { return }
        if isLast { isFinished = true } else { index += 1 }
    }

    /// Adımın cevabını bırakıp ilerler.
    mutating func skip() {
        guard showsSkip else { return }
        answers[step.id] = nil
        if isLast { isFinished = true } else { index += 1 }
    }

    mutating func back() {
        guard index > 0 else { return }
        index -= 1
    }

    /// Kaldığı yerin taslağı: kapatınca kart "Devam et · (n+1)/m" olur.
    func draft(at date: Date) -> FlowDraftData {
        FlowDraftData(day: flow.day, stepIndex: index, answers: answers, updatedAt: date)
    }

    /// Kapanışta gösterilen skor (varsa).
    var score: Int? {
        for step in flow.steps where step.kind == .score {
            if case .score(let value) = answers[step.id] { return value }
        }
        return nil
    }
}

extension FlowAnswerData {
    /// Cevap gerçekten bir şey içeriyor mu (boş yazı ve boş seçim sayılmaz).
    var hasContent: Bool {
        switch self {
        case .score, .sleep, .intentionReview: return true
        case .focus(let text), .text(let text): return !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .emotions(let ids), .causes(let ids): return !ids.isEmpty
        case .list3(let items): return items.contains { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        case .practices(let marks): return !marks.isEmpty
        }
    }
}
