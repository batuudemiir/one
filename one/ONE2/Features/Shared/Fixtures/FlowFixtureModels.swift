//
//  FlowFixtureModels.swift
//  ONE 2.0
//
//  Önizleme ve testlerde akış view modeli: bellekteki taslak deposu
//  (oturum boyunca "kaldığı yerden devam" çalışır).
//

import Foundation

final class InMemoryFlowDraftStore: FlowDraftStoring {
    private(set) var drafts: [FlowKind: FlowProgress] = [:]
    private(set) var saveCount = 0

    init(_ drafts: [FlowKind: FlowProgress] = [:]) { self.drafts = drafts }

    func load(_ flow: FlowKind) -> FlowProgress? { drafts[flow] }
    func save(_ progress: FlowProgress) { drafts[progress.flow] = progress; saveCount += 1 }
    func clear(_ flow: FlowKind) { drafts[flow] = nil }
}

enum FlowFixtureModels {
    /// Önizleme oturumunun ortak taslak deposu.
    static let drafts = InMemoryFlowDraftStore()

    static func model(_ kind: FlowKind) -> FlowViewModel {
        FlowViewModel(flow: FlowFixtures.flow(kind), drafts: drafts)
    }

    /// Belirli bir adımda açık model (adım önizlemeleri).
    static func model(_ kind: FlowKind, at stepID: String, variant: FlowFixtureVariant = .standard) -> FlowViewModel {
        let flow = FlowFixtures.flow(kind, variant: variant)
        var progress = FlowProgress(flow: kind)
        let visible = flow.steps.filter { $0.isEnabled || $0.id == stepID }
        progress.stepIndex = visible.firstIndex { $0.id == stepID } ?? 0
        if !(flow.steps.first { $0.id == stepID }?.isEnabled ?? true) { progress.enabledSteps.insert(stepID) }
        return FlowViewModel(flow: flow, drafts: InMemoryFlowDraftStore([kind: progress]))
    }
}
