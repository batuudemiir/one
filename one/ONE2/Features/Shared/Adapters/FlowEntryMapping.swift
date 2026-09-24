//
//  FlowEntryMapping.swift
//  ONE 2.0
//
//  Akış sonucunun kayıt karşılıkları (UX_istekleri.md › 8), saf. Yazma
//  `LiveFlows`'ta; burada yalnız hangi cevabın nereye gideceği.
//
//  - score + emotions + causes → tek mood check-in
//  - diğer anlamlı cevaplar → tek girdi (`morning` / `evening` /
//    `dailyCheckIn` / `emotionCheckIn`), her adım bir `EntryAnswer`
//    (`stepRef` = adım ID'si, `questionSnapshot` = gösterilen soru)
//  - uyku saati için alan yok (karar gerekli): ikinci cevap
//    `<adım>.hours`, `number` = saat
//

import Foundation

nonisolated enum FlowEntryMapping {

    static func entryKind(_ flow: FlowKind) -> EntryKind {
        switch flow {
        case .moodCheckIn: return .emotionCheckIn
        case .daily:       return .dailyCheckIn
        case .morning:     return .morning
        case .evening:     return .evening
        case .guided:      return .guided
        }
    }

    /// Gün kaydındaki ritüel kartı; mood check-in ve rehberli günlük günü
    /// ritüel olarak tamamlamaz (rehberli yazı ≥ 20 kelimeyse yazıyla tamamlar).
    static func ritualCard(_ flow: FlowKind) -> RitualCard? {
        switch flow {
        case .moodCheckIn, .guided: return nil
        case .daily:       return .daily
        case .morning:     return .morning
        case .evening:     return .evening
        }
    }

    static func seal(_ flow: FlowKind) -> FlowSeal {
        switch flow {
        case .moodCheckIn:     return .none
        case .morning:         return .half
        case .daily, .evening: return .full
        case .guided:          return .saved
        }
    }

    struct Mood: Equatable {
        let score: Int
        let emotionIDs: [String]
        let causeIDs: [String]
    }

    /// Skor adımı cevaplıysa mood check-in (duygu ve nedenlerle).
    static func mood(_ result: FlowResult, steps: [FlowStepViewData]) -> Mood? {
        func choices(_ kind: FlowStepKind) -> [String] {
            steps.filter { $0.kind == kind }.flatMap { step -> [String] in
                if case .choices(let ids)? = result.answers[step.id] { return ids }
                return []
            }
        }
        guard let scoreStep = steps.first(where: { $0.kind == .score }),
              case .score(let score)? = result.answers[scoreStep.id], (1...5).contains(score) else { return nil }
        return Mood(score: score, emotionIDs: choices(.emotions), causeIDs: choices(.causes))
    }

    /// Mood dışındaki anlamlı cevaplar, adım sırasıyla. `includeMoodSteps`:
    /// skor ve seçim adımları da girdiye yazılır (rehberli günlük; mood
    /// check-in değildir).
    static func answers(_ result: FlowResult, steps: [FlowStepViewData],
                        includeMoodSteps: Bool = false) -> [EntryAnswer] {
        var out: [EntryAnswer] = []
        for step in steps where includeMoodSteps || ![.score, .emotions, .causes].contains(step.kind) {
            guard let answer = result.answers[step.id], answer.isMeaningful else { continue }
            let question = step.prompt ?? step.title
            switch answer {
            case .text(let text):
                out.append(EntryAnswer(kind: .text, stepRef: step.id, questionSnapshot: question,
                                       text: text.trimmingCharacters(in: .whitespacesAndNewlines)))
            case .list(let items):
                let filled = items.map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
                out.append(EntryAnswer(kind: .todo, stepRef: step.id, questionSnapshot: question, choices: filled))
            case .sleep(let score, let hours):
                if score > 0 {
                    out.append(EntryAnswer(kind: .scale5, stepRef: step.id, questionSnapshot: question, number: Double(score)))
                }
                if let hours {
                    out.append(EntryAnswer(kind: .text, stepRef: "\(step.id).hours", questionSnapshot: question, number: hours))
                }
            case .focus(let value, _):
                out.append(EntryAnswer(kind: .singleChoice, stepRef: step.id, questionSnapshot: question,
                                       choices: [value.trimmingCharacters(in: .whitespaces)]))
            case .practices(let ids):
                out.append(EntryAnswer(kind: .multiChoice, stepRef: step.id, questionSnapshot: question, choices: ids))
            case .intention(let id):
                out.append(EntryAnswer(kind: .singleChoice, stepRef: step.id, questionSnapshot: question, choices: [id]))
            case .score(let value):
                out.append(EntryAnswer(kind: .scale5, stepRef: step.id, questionSnapshot: question, number: Double(value)))
            case .choices(let ids):
                out.append(EntryAnswer(kind: .multiChoice, stepRef: step.id, questionSnapshot: question, choices: ids))
            }
        }
        for index in out.indices { out[index].order = index }
        return out
    }

    /// Girdi gövdesi: yazı cevapları ve maddeler (arama, kelime sayısı).
    static func body(_ answers: [EntryAnswer]) -> String? {
        let parts = answers.compactMap { answer -> String? in
            switch answer.kind {
            case .text: return answer.text
            case .todo: return answer.choices.isEmpty ? nil : answer.choices.joined(separator: "\n")
            default:    return nil
            }
        }.filter { !$0.isEmpty }
        return parts.isEmpty ? nil : parts.joined(separator: "\n\n")
    }

    /// Sabahın odağı (gün kaydına yazılır, akşam niyet adımı okur).
    static func focus(_ result: FlowResult, steps: [FlowStepViewData]) -> String? {
        for step in steps where step.kind == .focus {
            if case .focus(let value, _)? = result.answers[step.id] {
                let trimmed = value.trimmingCharacters(in: .whitespaces)
                if !trimmed.isEmpty { return trimmed }
            }
        }
        return nil
    }

    /// Söz adımına yazılan cevap: ayrıca söze yazı girdisi olur.
    static func quoteReflection(_ result: FlowResult, steps: [FlowStepViewData]) -> (quote: FlowQuoteViewData, prompt: String?, text: String)? {
        for step in steps where step.kind == .quote {
            if let quote = step.quote, case .text(let text)? = result.answers[step.id] {
                let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty { return (quote, step.prompt, trimmed) }
            }
        }
        return nil
    }

    /// Sabahın öncelik maddeleri (akşam "Yarına taşıyayım mı?").
    static let prioritiesStepID = "morning.priorities"

    static func priorities(in entries: [JournalEntry]) -> [String] {
        entries.filter { $0.kind == .morning }
            .flatMap { $0.answers.filter { $0.stepRef == prioritiesStepID }.flatMap(\.choices) }
    }

    /// Akşam özeti: tamamlanan pratik sayısı; pratik adımı yoksa nil.
    static func practicesDone(_ result: FlowResult, steps: [FlowStepViewData]) -> Int? {
        guard let step = steps.first(where: { $0.kind == .practices }) else { return nil }
        if case .practices(let ids)? = result.answers[step.id] { return ids.count }
        return 0
    }
}
