//
//  GuidedFlows.swift
//  ONE 2.0
//
//  Rehberli günlükler (pratik karoları) akış kabuğunda (06 › Bugün 4,
//  PracticeTile.md). İçeriğin adımları akış adımlarına eşlenir; sonuç
//  `guided` girdisi olur (`contentRef = guided:<id>`, E7 bunu okur).
//
//  | İçerik adımı | Akış adımı |
//  |---|---|
//  | scale5 | score (isteğe bağlı; mood check-in değil, girdiye yazılır) |
//  | text, focus | text |
//  | todo | list3 |
//  | yesNo | tek seçim (Evet / Hayır) |
//  | singleChoice | tek seçim (içeriğin seçenekleri) |
//  | multiChoice | çoklu seçim (içeriğin seçenekleri, kendi etiketi eklenebilir) |
//

import Foundation

enum GuidedFlows {
    static let refPrefix = "guided:"

    static func ref(_ id: String) -> String { refPrefix + id }

    static func id(from contentRef: String) -> String {
        contentRef.hasPrefix(refPrefix) ? String(contentRef.dropFirst(refPrefix.count)) : contentRef
    }

    /// İçerik adımları → akış adımları. Hepsi isteğe bağlı.
    static func steps(_ journal: GuidedJournal) -> [FlowStepViewData] {
        journal.steps.map { step in
            let id = "guided.\(journal.id).\(step.id)"
            let options = (step.choices ?? []).map { FlowOptionViewData(id: $0, label: $0) }
            switch step.kind {
            case .scale5:
                return FlowStepViewData(id: id, kind: .score, title: journal.title, prompt: step.prompt,
                                        optional: true, options: FlowFixtures.scoreOptions())
            case .todo:
                return FlowStepViewData(id: id, kind: .list3, title: journal.title, prompt: step.prompt, optional: true)
            case .yesNo:
                return FlowStepViewData(id: id, kind: .intentionReview, title: journal.title, prompt: step.prompt,
                                        optional: true, options: [
                                            FlowOptionViewData(id: "yes", label: NSLocalizedString("one2.answer.yes", comment: "Yes")),
                                            FlowOptionViewData(id: "no", label: NSLocalizedString("one2.answer.no", comment: "No")),
                                        ])
            case .singleChoice:
                return FlowStepViewData(id: id, kind: .intentionReview, title: journal.title, prompt: step.prompt,
                                        optional: true, options: options)
            case .multiChoice:
                return FlowStepViewData(id: id, kind: .causes, title: journal.title, prompt: step.prompt,
                                        optional: true, options: options)
            case .text, .focus:
                return FlowStepViewData(id: id, kind: .text, title: journal.title, prompt: step.prompt, optional: true)
            }
        }
    }

    /// Ekleme listesi: etkin, dilde; eklenenler işaretli, premium kilitli.
    static func pickerItems(_ guided: [GuidedJournal], added: Set<String>, lang: String,
                            hasPremium: Bool) -> [PracticePickerItem] {
        guided.filter { $0.active && $0.lang == lang }.map { journal in
            PracticePickerItem(id: ref(journal.id), title: journal.title, summary: journal.summary,
                               durationLabel: journal.durationMinutes.map {
                                   String.localizedStringWithFormat(NSLocalizedString("one2.duration.minutes",
                                                                                      comment: "Duration in minutes, mono"), $0)
                               },
                               isLocked: journal.premium && !hasPremium, isAdded: added.contains(ref(journal.id)))
        }
    }

    static func model(_ journal: GuidedJournal, on day: DayKey, env: AppEnvironment,
                      onSaved: @escaping () -> Void = {}) -> FlowViewModel {
        let steps = steps(journal)
        let flow = FlowViewData(kind: .guided, steps: steps, closing: FlowClosingViewData(seal: .saved, echo: ""))
        let model = FlowViewModel(flow: flow, drafts: DefaultsFlowDraftStore(day: day, scope: journal.id))
        model.onFinish = { result in
            let answers = FlowEntryMapping.answers(result, steps: steps, includeMoodSteps: true)
            if !answers.isEmpty {
                try env.journal.create(EntryDraft(kind: .guided, body: FlowEntryMapping.body(answers),
                                                  contentRef: ref(journal.id), contentSnapshot: journal.title,
                                                  answers: answers, sourceContext: .guided),
                                       on: day == env.clock.today ? nil : day)
            }
            onSaved()
            return FlowClosingViewData(seal: .saved, echo: "", week: WeekStripAdapter.viewData(WeekStripModel.load(env)))
        }
        return model
    }
}

/// Pratik ekleme listesinin satırı.
nonisolated struct PracticePickerItem: Hashable, Sendable, Identifiable {
    /// `guided:<id>`.
    let id: String
    let title: String
    let summary: String
    let durationLabel: String?
    let isLocked: Bool
    let isAdded: Bool
}
