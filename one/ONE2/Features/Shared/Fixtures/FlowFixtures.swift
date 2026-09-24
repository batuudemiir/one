//
//  FlowFixtures.swift
//  ONE 2.0
//
//  Dört akışın adım listeleri ve durumları (06_giris_akislari.md). Sabit
//  soru ve etiketler Localizable'dan; örnek içerik `ux_fixtures.tr.json`'dan.
//  Motor bağlaması (UX-11) aynı `FlowViewData`'yı şablon seed'inden kurar.
//

import Foundation

nonisolated enum FlowFixtureVariant: Hashable, Sendable {
    case standard
    /// Akşam: sabah yapılmadı → niyet adımı yok, taşınacak madde yok.
    case withoutMorning
    /// Akşam: bugün pratik yok → pratik adımı yok.
    case withoutPractices
}

nonisolated enum FlowFixtureStage: Hashable, Sendable, CaseIterable {
    case empty, inProgress, done
}

nonisolated enum FlowFixtures {

    private static func L(_ key: String) -> String { NSLocalizedString(key, comment: "") }

    // MARK: Sabit seçenekler

    static func scoreOptions() -> [FlowOptionViewData] {
        (1...5).map { FlowOptionViewData(id: "\($0)", label: scoreLabel($0)) }
    }

    static func scoreLabel(_ score: Int) -> String {
        switch score {
        case ...1: return NSLocalizedString("one2.score.1", comment: "Mood score 1")
        case 2:    return NSLocalizedString("one2.score.2", comment: "Mood score 2")
        case 3:    return NSLocalizedString("one2.score.3", comment: "Mood score 3")
        case 4:    return NSLocalizedString("one2.score.4", comment: "Mood score 4")
        default:   return NSLocalizedString("one2.score.5", comment: "Mood score 5")
        }
    }

    static func sleepOptions() -> [FlowOptionViewData] {
        [NSLocalizedString("one2.sleep.1", comment: "Sleep quality 1"),
         NSLocalizedString("one2.sleep.2", comment: "Sleep quality 2"),
         NSLocalizedString("one2.sleep.3", comment: "Sleep quality 3"),
         NSLocalizedString("one2.sleep.4", comment: "Sleep quality 4"),
         NSLocalizedString("one2.sleep.5", comment: "Sleep quality 5")]
            .enumerated().map { FlowOptionViewData(id: "\($0.offset + 1)", label: $0.element) }
    }

    /// Sabah odağı: sabit liste + "Kendi kelimen" (`custom`).
    static func focusOptions() -> [FlowOptionViewData] {
        [("sakinlik", NSLocalizedString("one2.focus.sakinlik", comment: "Focus option")),
         ("sabir", NSLocalizedString("one2.focus.sabir", comment: "Focus option")),
         ("disiplin", NSLocalizedString("one2.focus.disiplin", comment: "Focus option")),
         ("cesaret", NSLocalizedString("one2.focus.cesaret", comment: "Focus option")),
         ("nezaket", NSLocalizedString("one2.focus.nezaket", comment: "Focus option")),
         ("minnet", NSLocalizedString("one2.focus.minnet", comment: "Focus option")),
         ("odak", NSLocalizedString("one2.focus.odak", comment: "Focus option")),
         ("kendine", NSLocalizedString("one2.focus.kendine", comment: "Focus option")),
         ("custom", NSLocalizedString("one2.focus.custom", comment: "Focus option: own word"))]
            .map { FlowOptionViewData(id: $0.0, label: $0.1) }
    }

    static func intentionOptions() -> [FlowOptionViewData] {
        [FlowOptionViewData(id: "kept", label: NSLocalizedString("one2.intention.kept", comment: "Intention review: kept it")),
         FlowOptionViewData(id: "partly", label: NSLocalizedString("one2.intention.partly", comment: "Intention review: partly")),
         FlowOptionViewData(id: "missed", label: NSLocalizedString("one2.intention.missed", comment: "Intention review: did not"))]
    }

    static func focusLabel(_ id: String) -> String {
        focusOptions().first { $0.id == id }?.label ?? id
    }

    // MARK: Adımlar

    static func steps(_ kind: FlowKind, variant: FlowFixtureVariant = .standard,
                      content c: UXFixtureContent = UXFixtures.content) -> [FlowStepViewData] {
        let p = kind.rawValue
        func score(_ titleKey: String) -> FlowStepViewData {
            FlowStepViewData(id: "\(p).score", kind: .score, title: L(titleKey), optional: false, options: scoreOptions())
        }
        let emotions = FlowStepViewData(id: "\(p).emotions", kind: .emotions, title: L("one2.flow.emotions.title"),
                                        optional: true, options: c.emotions)
        let causes = FlowStepViewData(id: "\(p).causes", kind: .causes, title: L("one2.flow.causes.title"),
                                      optional: true, options: c.causes)
        func text(_ id: String, _ titleKey: String, _ promptKey: String) -> FlowStepViewData {
            FlowStepViewData(id: "\(p).\(id)", kind: .text, title: L(titleKey), prompt: L(promptKey), optional: true)
        }
        func list(_ id: String, _ titleKey: String, _ promptKey: String) -> FlowStepViewData {
            FlowStepViewData(id: "\(p).\(id)", kind: .list3, title: L(titleKey), prompt: L(promptKey), optional: true)
        }

        switch kind {
        case .guided:
            // Rehberli günlüğün adımları içerikten gelir (GuidedFlows).
            return []
        case .moodCheckIn:
            return [score("one2.flow.score.now"), emotions, causes,
                    text("note", "one2.flow.note.title", "one2.flow.prompt.moodNote")]
        case .daily:
            var question = FlowStepViewData(id: "daily.question", kind: .text, title: L("one2.flow.dailyQuestion.title"),
                                            prompt: c.dailyPrompts.first, optional: true)
            question.previousAnswer = c.previousAnswer
            return [score("one2.flow.score.today"), emotions, causes, question,
                    list("gratitude", "one2.flow.gratitude.title", "one2.flow.prompt.dailyGratitude")]
        case .morning:
            var hiddenEmotions = emotions
            hiddenEmotions.isEnabled = false
            let quote = c.quote.map { FlowQuoteViewData(id: $0.id, text: $0.text, attribution: $0.attribution) }
            return [
                FlowStepViewData(id: "morning.sleep", kind: .sleep, title: L("one2.flow.sleep.title"),
                                 optional: true, options: sleepOptions()),
                score("one2.flow.score.morning"),
                hiddenEmotions,
                FlowStepViewData(id: "morning.focus", kind: .focus, title: L("one2.flow.focus.title"),
                                 optional: true, options: focusOptions()),
                FlowStepViewData(id: "morning.quote", kind: .quote, title: L("one2.quotes.daily"),
                                 prompt: L("one2.flow.prompt.quote"), optional: true, quote: quote),
                list("priorities", "one2.flow.priorities.title", "one2.flow.prompt.priorities"),
                text("challenge", "one2.flow.prepare.title", "one2.flow.prompt.challenge"),
            ]
        case .evening:
            var steps = [score("one2.flow.score.evening"), emotions, causes]
            if variant != .withoutMorning {
                steps.append(FlowStepViewData(
                    id: "evening.intention", kind: .intentionReview,
                    title: String(format: L("one2.flow.intention.title"), focusLabel(c.morningFocus)),
                    optional: true, options: intentionOptions()))
            }
            if variant != .withoutPractices, !c.practices.isEmpty {
                steps.append(FlowStepViewData(id: "evening.practices", kind: .practices,
                                              title: L("one2.flow.practices.title"), optional: true, options: c.practices))
            }
            steps += [text("wentWell", "one2.flow.wentWell.title", "one2.flow.prompt.wentWell"),
                      text("differently", "one2.flow.differently.title", "one2.flow.prompt.differently"),
                      list("gratitude", "one2.flow.gratitude.title", "one2.flow.prompt.eveningGratitude"),
                      text("note", "one2.flow.note.title", "one2.flow.prompt.eveningNote")]
            return steps
        }
    }

    // MARK: Akış

    static func flow(_ kind: FlowKind, variant: FlowFixtureVariant = .standard,
                     content c: UXFixtureContent = UXFixtures.content) -> FlowViewData {
        let seal: FlowSeal
        switch kind {
        case .moodCheckIn: seal = .none
        case .guided:      seal = .saved
        case .morning:     seal = .half
        case .daily, .evening: seal = .full
        }
        var closing = FlowClosingViewData(seal: seal, echo: c.echo(kind))
        if seal != .none {
            closing.week = TodayFixtures.week(todayStatus: seal == .half ? .half : .done)
        }
        if kind == .evening, variant != .withoutMorning {
            closing.carryOver = c.morningList.enumerated()
                .filter { !c.morningDoneItems.contains($0.offset) }.map(\.element)
        }
        return FlowViewData(kind: kind, steps: steps(kind, variant: variant, content: c), closing: closing)
    }

    /// Örnek cevaplar (yarıda / tamam taslakları).
    static func sampleAnswer(for step: FlowStepViewData, content c: UXFixtureContent = UXFixtures.content) -> FlowAnswer {
        switch step.kind {
        case .score:           return .score(4)
        case .emotions:        return .choices(Array((step.options ?? []).prefix(2).map(\.id)))
        case .causes:          return .choices(Array((step.options ?? []).prefix(1).map(\.id)))
        case .sleep:           return .sleep(score: 3, hours: 7)
        case .focus:           return .focus(c.morningFocus, custom: false)
        case .text:            return .text(c.previousAnswer?.components(separatedBy: "\n").first ?? "")
        case .list3:           return .list(c.morningList)
        case .quote:           return .text(c.theme?.writtenFirstLine ?? "")
        case .practices:       return .practices(Array((step.options ?? []).prefix(2).map(\.id)))
        case .intentionReview: return .intention("partly")
        }
    }

    /// `empty`: taslak yok · `inProgress`: adımların yarısı cevaplı · `done`: hepsi.
    static func progress(_ kind: FlowKind, _ stage: FlowFixtureStage, variant: FlowFixtureVariant = .standard,
                         content c: UXFixtureContent = UXFixtures.content) -> FlowProgress? {
        let enabled = steps(kind, variant: variant, content: c).filter(\.isEnabled)
        let answered: Int
        switch stage {
        case .empty:      return nil
        case .inProgress: answered = max(1, enabled.count / 2)
        case .done:       answered = enabled.count
        }
        var progress = FlowProgress(flow: kind, stepIndex: min(answered, enabled.count - 1))
        for step in enabled.prefix(answered) { progress.answers[step.id] = sampleAnswer(for: step, content: c) }
        return progress
    }
}
