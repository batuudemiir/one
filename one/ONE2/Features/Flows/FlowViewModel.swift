//
//  FlowViewModel.swift
//  ONE 2.0
//
//  Akış kabuğunun durumu (06 › Akış kabuğu). Adımlar veriyle gelir; model
//  sırayı, cevapları, atlamayı ve taslağı yönetir, adım türünü bilmez.
//
//  - Yalnız zorunlu adım (skor) cevapsız geçilemez; diğerleri atlanabilir.
//    Atlanan adımın cevabı silinir, hiçbir yerde "boş kaldı" denmez.
//  - Her adım bitince taslak kaydedilir; kapatınca da. Açınca kaldığı
//    adımdan devam eder. Akış bitince taslak silinir.
//  - Varsayılan kapalı ek adım (sabahta duygular) önceki adımdan açılır.
//

import Foundation
import Observation

/// Akış taslağının saklandığı yer (UX_istekleri.md › 5). Motor bağlaması
/// cihazda kalıcı bir uygulama verir; fixture bellekte tutar.
protocol FlowDraftStoring: AnyObject {
    func load(_ flow: FlowKind) -> FlowProgress?
    func save(_ progress: FlowProgress)
    func clear(_ flow: FlowKind)
}

nonisolated enum FlowPhase: Hashable, Sendable {
    case steps
    case closing
}

@Observable
final class FlowViewModel {
    let flow: FlowViewData
    private(set) var progress: FlowProgress
    private(set) var phase: FlowPhase = .steps
    /// Kapanıştaki "Bitti" / "Taşı" / "Bırak" ile bir kez çağrılır.
    @ObservationIgnored var onComplete: (FlowResult) -> Void

    @ObservationIgnored private let drafts: FlowDraftStoring
    @ObservationIgnored private var completed = false

    init(flow: FlowViewData, drafts: FlowDraftStoring, onComplete: @escaping (FlowResult) -> Void = { _ in }) {
        self.flow = flow
        self.drafts = drafts
        self.onComplete = onComplete
        var restored = drafts.load(flow.kind) ?? FlowProgress(flow: flow.kind)
        restored.enabledSteps.formIntersection(flow.steps.map(\.id))
        progress = restored
        progress.stepIndex = min(max(0, restored.stepIndex), max(0, steps.count - 1))
    }

    // MARK: Adımlar

    /// Görünen adımlar: açık olanlar + kullanıcının açtığı ek adımlar.
    var steps: [FlowStepViewData] {
        flow.steps.filter { $0.isEnabled || progress.enabledSteps.contains($0.id) }
    }

    var stepIndex: Int { progress.stepIndex }
    var current: FlowStepViewData? { steps.indices.contains(stepIndex) ? steps[stepIndex] : nil }
    var isLastStep: Bool { stepIndex >= steps.count - 1 }
    var durationLabel: String { FlowDuration.label(steps) }

    /// Mevcut adımın hemen ardındaki kapalı ek adım ("Duygu ekle").
    var optionalStepAfterCurrent: FlowStepViewData? {
        guard let current, let position = flow.steps.firstIndex(where: { $0.id == current.id }),
              flow.steps.indices.contains(position + 1) else { return nil }
        let next = flow.steps[position + 1]
        return next.isEnabled || progress.enabledSteps.contains(next.id) ? nil : next
    }

    func enableStep(_ id: String) {
        guard flow.steps.contains(where: { $0.id == id }) else { return }
        progress.enabledSteps.insert(id)
        drafts.save(progress)
    }

    // MARK: Cevaplar

    func answer(for stepID: String) -> FlowAnswer? { progress.answers[stepID] }

    func setAnswer(_ answer: FlowAnswer?, for stepID: String) {
        progress.answers[stepID] = answer
    }

    /// Adımın seçenekleri + kullanıcının ekledikleri (neden etiketi).
    func options(for step: FlowStepViewData) -> [FlowOptionViewData] {
        (step.options ?? []) + (progress.addedOptions[step.id] ?? [])
    }

    /// Yeni seçenek ekler ve seçer. Aynı adlı varsa onu seçer.
    @discardableResult
    func addOption(_ label: String, to stepID: String) -> FlowOptionViewData? {
        let trimmed = label.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let step = flow.steps.first(where: { $0.id == stepID }) else { return nil }
        let option = options(for: step).first { $0.label.localizedCaseInsensitiveCompare(trimmed) == .orderedSame }
            ?? FlowOptionViewData(id: "custom:\(trimmed.lowercased())", label: trimmed)
        if !options(for: step).contains(option) { progress.addedOptions[stepID, default: []].append(option) }
        var chosen: [String] = []
        if case .choices(let ids) = answer(for: stepID) { chosen = ids }
        if !chosen.contains(option.id) { chosen.append(option.id) }
        setAnswer(.choices(chosen), for: stepID)
        return option
    }

    // MARK: Gezinme

    var canContinue: Bool {
        guard let current else { return false }
        return current.optional || (answer(for: current.id)?.isMeaningful ?? false)
    }

    var canSkip: Bool { current?.optional ?? false }

    func next() {
        guard phase == .steps, canContinue else { return }
        advance()
    }

    /// İsteğe bağlı adımı cevapsız geçer.
    func skip() {
        guard phase == .steps, let current, current.optional else { return }
        progress.answers[current.id] = nil
        advance()
    }

    /// Kapat: kaldığı yer ve o ana kadarki cevaplar saklanır.
    func close() {
        guard phase == .steps else { return }
        drafts.save(progress)
    }

    private func advance() {
        if isLastStep {
            drafts.clear(flow.kind)
            phase = .closing
        } else {
            progress.stepIndex = stepIndex + 1
            drafts.save(progress)
        }
    }

    // MARK: Kapanış

    /// Sonuç: yalnız anlamlı cevaplar, görünen adımlardan.
    var result: FlowResult {
        let visible = Set(steps.map(\.id))
        return FlowResult(flow: flow.kind,
                          answers: progress.answers.filter { visible.contains($0.key) && $0.value.isMeaningful })
    }

    /// Kapanıştaki son dokunuş. `carryOver`: "Taşı" / "Bırak"; soru yoksa nil.
    func complete(carryOver: Bool? = nil) {
        guard phase == .closing, !completed else { return }
        completed = true
        var r = result
        r.carryOver = flow.closing.carryOver.isEmpty ? nil : carryOver
        onComplete(r)
    }
}

/// `fullScreenCover(item:)` için kimlikli sarmalayıcı.
nonisolated struct FlowPresentation: Identifiable {
    let id = UUID()
    let model: FlowViewModel
}
