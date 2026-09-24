//
//  FlowSteps.swift
//  ONE 2.0
//
//  Akış adımlarının gövdeleri (07 §5.2). Her adım verisini ve mevcut
//  cevabı alır, yeni cevabı yukarı bildirir; ilerleme ve taslak kabukta
//  (`FlowScreen`). Seçimler 180 ms + `selection` haptiği (07 §7).
//

import SwiftUI

/// Adım türüne göre gövde.
struct FlowStepBody: View {
    let step: FlowStepViewData
    let answer: FlowAnswerData?
    let onAnswer: (FlowAnswerData?) -> Void

    var body: some View {
        switch step.kind {
        case .score:
            ScoreScale(selection: answer.flatMap { if case .score(let v) = $0 { v } else { nil } }) {
                onAnswer(.score($0))
            }
        case .sleep:
            SleepStep(answer: answer, onAnswer: onAnswer)
        case .emotions:
            EmotionsStep(emotions: step.emotions ?? [], answer: answer, onAnswer: onAnswer)
        case .causes:
            CausesStep(options: step.options ?? [], answer: answer, onAnswer: onAnswer)
        case .focus:
            FocusStep(options: step.options ?? [], answer: answer, onAnswer: onAnswer)
        case .text:
            TextStep(previous: step.previous, answer: answer, onAnswer: onAnswer)
        case .list3:
            List3Step(answer: answer, onAnswer: onAnswer)
        case .quote:
            QuoteStep(quote: step.quote, answer: answer, onAnswer: onAnswer)
        case .practices:
            PracticesStep(practices: step.practices ?? [], answer: answer, onAnswer: onAnswer)
        case .intentionReview:
            IntentionStep(answer: answer, onAnswer: onAnswer)
        }
    }
}

// MARK: - Seçim adımları

private struct SleepStep: View {
    let answer: FlowAnswerData?
    let onAnswer: (FlowAnswerData?) -> Void

    static let hoursRange: ClosedRange<Double> = 4...12
    static let hoursStep = 0.5
    static let defaultHours = 7.5

    private var current: (score: Int?, hours: Double?) {
        if case .sleep(let score, let hours) = answer { return (score, hours) }
        return (nil, nil)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: ONE2Space.s8) {
            ScoreScale(selection: current.score, labels: (1...5).map { one2String("one2.flow.sleep.\($0)") }) { score in
                onAnswer(.sleep(score: score, hours: current.hours))
            }
            if let hours = current.hours {
                HStack(spacing: ONE2Space.s4) {
                    ONE2RoundButton(icon: .minus, accessibilityLabel: one2String("one2.flow.sleep.less")) {
                        change(hours - Self.hoursStep)
                    }
                    .disabled(hours <= Self.hoursRange.lowerBound)
                    Text(String(format: one2String("one2.flow.sleep.hours"), hours.formatted(.number.precision(.fractionLength(0...1)))))
                        .one2Type(.numeralLg)
                        .foregroundStyle(ONE2Color.ink)
                        .frame(minWidth: ONE2Size.skeletonPill)
                    ONE2RoundButton(icon: .add, accessibilityLabel: one2String("one2.flow.sleep.more")) {
                        change(hours + Self.hoursStep)
                    }
                    .disabled(hours >= Self.hoursRange.upperBound)
                }
                .accessibilityElement(children: .combine)
            } else if let score = current.score {
                Button {
                    onAnswer(.sleep(score: score, hours: Self.defaultHours))
                } label: {
                    Text(one2String("one2.flow.sleep.addHours")).contentShape(Rectangle())
                }
                .buttonStyle(.one2(.text))
            }
        }
    }

    private func change(_ hours: Double) {
        guard let score = current.score else { return }
        ONE2Haptics.selection()
        onAnswer(.sleep(score: score, hours: min(max(hours, Self.hoursRange.lowerBound), Self.hoursRange.upperBound)))
    }
}

private struct EmotionsStep: View {
    let emotions: [EmotionItem]
    let answer: FlowAnswerData?
    let onAnswer: (FlowAnswerData?) -> Void

    private var selected: [String] {
        if case .emotions(let ids) = answer { return ids }
        return []
    }

    var body: some View {
        WrapLayout {
            ForEach(emotions) { item in
                EmotionChip(title: item.name, family: item.family, isSelected: selected.contains(item.id)) {
                    toggle(item.id)
                }
            }
        }
    }

    private func toggle(_ id: String) {
        var ids = selected
        if let index = ids.firstIndex(of: id) { ids.remove(at: index) } else { ids.append(id) }
        onAnswer(ids.isEmpty ? nil : .emotions(ids))
    }
}

private struct CausesStep: View {
    let options: [FlowOptionData]
    let answer: FlowAnswerData?
    let onAnswer: (FlowAnswerData?) -> Void

    @State private var isAdding = false
    @State private var draft = ""
    @FocusState private var fieldFocused: Bool

    /// Seçili etiketler: katalog ID'si ya da kullanıcının yazdığı ad.
    private var selected: [String] {
        if case .causes(let ids) = answer { return ids }
        return []
    }

    private var customTags: [String] {
        selected.filter { tag in !options.contains { $0.id == tag } }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: ONE2Space.s4) {
            WrapLayout {
                ForEach(options.filter { !$0.isCustomEntry }) { option in
                    CauseTag(title: option.title, isSelected: selected.contains(option.id)) { toggle(option.id) }
                }
                ForEach(customTags, id: \.self) { tag in
                    CauseTag(title: tag, isSelected: true) { toggle(tag) }
                }
                if let add = options.first(where: \.isCustomEntry), !isAdding {
                    CauseTag(title: add.title, isSelected: false) {
                        isAdding = true
                        fieldFocused = true
                    }
                }
            }
            if isAdding {
                TextField(one2String("one2.flow.causes.placeholder"), text: $draft)
                    .one2Type(.body)
                    .foregroundStyle(ONE2Color.ink)
                    .focused($fieldFocused)
                    .submitLabel(.done)
                    .onSubmit(commit)
                    .padding(.horizontal, ONE2Space.s4)
                    .frame(minHeight: ONE2Size.minTouch)
                    .background(ONE2Color.raised, in: ONE2Radius.shape(ONE2Radius.sm))
            }
        }
    }

    private func toggle(_ id: String) {
        var ids = selected
        if let index = ids.firstIndex(of: id) { ids.remove(at: index) } else { ids.append(id) }
        onAnswer(ids.isEmpty ? nil : .causes(ids))
    }

    private func commit() {
        let tag = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        draft = ""
        isAdding = false
        guard !tag.isEmpty, !selected.contains(tag) else { return }
        ONE2Haptics.selection()
        onAnswer(.causes(selected + [tag]))
    }
}

private struct FocusStep: View {
    let options: [FlowOptionData]
    let answer: FlowAnswerData?
    let onAnswer: (FlowAnswerData?) -> Void

    @State private var isWriting = false
    @State private var own = ""
    @FocusState private var fieldFocused: Bool

    private var selected: String? {
        if case .focus(let value) = answer { return value }
        return nil
    }

    private var isOwnWord: Bool {
        guard let selected else { return false }
        return !options.contains { $0.title == selected }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: ONE2Space.s4) {
            WrapLayout {
                ForEach(options) { option in
                    if option.isCustomEntry {
                        ChoicePill(title: isOwnWord ? (selected ?? option.title) : option.title, isSelected: isOwnWord) {
                            isWriting = true
                            fieldFocused = true
                        }
                    } else {
                        ChoicePill(title: option.title, isSelected: selected == option.title) {
                            isWriting = false
                            onAnswer(.focus(option.title))
                        }
                    }
                }
            }
            if isWriting {
                TextField(one2String("one2.flow.focus.placeholder"), text: $own)
                    .one2Type(.body)
                    .foregroundStyle(ONE2Color.ink)
                    .focused($fieldFocused)
                    .submitLabel(.done)
                    .onSubmit {
                        let word = own.trimmingCharacters(in: .whitespacesAndNewlines)
                        isWriting = false
                        if !word.isEmpty { onAnswer(.focus(word)) }
                    }
                    .padding(.horizontal, ONE2Space.s4)
                    .frame(minHeight: ONE2Size.minTouch)
                    .background(ONE2Color.raised, in: Capsule())
            }
        }
    }
}

private struct IntentionStep: View {
    let answer: FlowAnswerData?
    let onAnswer: (FlowAnswerData?) -> Void

    private var selected: IntentionOutcome? {
        if case .intentionReview(let value) = answer { return value }
        return nil
    }

    var body: some View {
        WrapLayout {
            ForEach(IntentionOutcome.allCases, id: \.self) { outcome in
                ChoicePill(title: one2String("one2.flow.intention.\(outcome.rawValue)"), isSelected: selected == outcome) {
                    onAnswer(.intentionReview(outcome))
                }
            }
        }
    }
}

private struct PracticesStep: View {
    let practices: [PracticeTileData]
    let answer: FlowAnswerData?
    let onAnswer: (FlowAnswerData?) -> Void

    /// Cevap yoksa Bugün'deki işaretler.
    private var marks: [String: Bool] {
        if case .practices(let marks) = answer { return marks }
        return Dictionary(uniqueKeysWithValues: practices.map { ($0.id, $0.isDoneToday) })
    }

    var body: some View {
        VStack(spacing: ONE2Space.s2) {
            ForEach(practices) { practice in
                let isDone = marks[practice.id] ?? false
                Button {
                    ONE2Haptics.light()
                    var next = marks
                    next[practice.id] = !isDone
                    onAnswer(.practices(next))
                } label: {
                    HStack(spacing: ONE2Space.s4) {
                        practice.icon.image()
                            .foregroundStyle(ONE2Color.ink)
                            .frame(width: ONE2Size.control, height: ONE2Size.control)
                            .background(ONE2Color.raised, in: Circle())
                            .accessibilityHidden(true)
                        Text(practice.title)
                            .one2Type(.headline)
                            .foregroundStyle(ONE2Color.ink)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        CheckCircle(isOn: isDone)
                    }
                    .padding(.vertical, ONE2Space.s2)
                    .frame(minHeight: ONE2Size.minTouch)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.one2Press)
                .accessibilityElement(children: .combine)
                .accessibilityAddTraits(isDone ? [.isButton, .isSelected] : .isButton)
            }
        }
    }
}

// MARK: - Yazı adımları

/// Tek satırdan büyüyen Literata yazı alanı.
private struct GrowingField: View {
    let placeholder: String
    @Binding var text: String

    var body: some View {
        TextField(placeholder, text: $text, axis: .vertical)
            .one2Type(.journal)
            .foregroundStyle(ONE2Color.ink)
            .tint(ONE2Color.brand)
            .lineLimit(1...)
    }
}

private struct TextStep: View {
    let previous: PreviousAnswerData?
    let answer: FlowAnswerData?
    let onAnswer: (FlowAnswerData?) -> Void

    @State private var showsPrevious = false

    private var text: Binding<String> {
        Binding(
            get: { if case .text(let value) = answer { value } else { "" } },
            set: { onAnswer($0.isEmpty ? nil : .text($0)) }
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: ONE2Space.s6) {
            if let previous {
                Button { showsPrevious = true } label: {
                    VStack(alignment: .leading, spacing: ONE2Space.s1) {
                        Text(one2String("one2.flow.previous"))
                            .one2Type(.caption)
                            .foregroundStyle(ONE2Color.inkMuted)
                        Text(previous.text)
                            .one2Type(.bodySm)
                            .foregroundStyle(ONE2Color.ink)
                            .lineLimit(2)
                    }
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(ONE2Space.s4)
                    .background(ONE2Color.raised, in: ONE2Radius.shape(ONE2Radius.md))
                    .contentShape(Rectangle())
                }
                .buttonStyle(.one2Press)
                .sheet(isPresented: $showsPrevious) { PreviousAnswerSheet(previous: previous) }
            }
            GrowingField(placeholder: one2String("one2.flow.placeholder"), text: text)
        }
    }
}

private struct List3Step: View {
    let answer: FlowAnswerData?
    let onAnswer: (FlowAnswerData?) -> Void

    private var items: [String] {
        let saved = if case .list3(let items) = answer { items } else { [String]() }
        return (0..<3).map { saved.indices.contains($0) ? saved[$0] : "" }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: ONE2Space.s4) {
            ForEach(0..<3, id: \.self) { index in
                HStack(alignment: .firstTextBaseline, spacing: ONE2Space.s3) {
                    Text(verbatim: "\(index + 1)")
                        .one2Type(.time)
                        .foregroundStyle(ONE2Color.inkMuted)
                        .accessibilityHidden(true)
                    GrowingField(placeholder: one2String("one2.flow.placeholder"), text: binding(index))
                        .accessibilityLabel(Text(verbatim: "\(index + 1)"))
                }
                .padding(.vertical, ONE2Space.s2)
                .overlay(alignment: .bottom) {
                    Rectangle().fill(ONE2Color.line).frame(height: ONE2Size.hairline)
                }
            }
        }
    }

    private func binding(_ index: Int) -> Binding<String> {
        Binding(
            get: { items[index] },
            set: { value in
                var next = items
                next[index] = value
                onAnswer(next.allSatisfy { $0.isEmpty } ? nil : .list3(next))
            }
        )
    }
}

private struct QuoteStep: View {
    let quote: QuoteCardData?
    let answer: FlowAnswerData?
    let onAnswer: (FlowAnswerData?) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: ONE2Space.s6) {
            if let quote {
                VStack(alignment: .leading, spacing: ONE2Space.s3) {
                    Text(quote.text)
                        .one2Type(.prompt)
                        .italic()
                        .foregroundStyle(ONE2Color.ink)
                    ONE2Label(quote.source)
                }
                .padding(ONE2Space.s5)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(ONE2Color.surface, in: ONE2Radius.shape(ONE2Radius.lg))
                .accessibilityElement(children: .combine)
            }
            TextStep(previous: nil, answer: answer, onAnswer: onAnswer)
        }
    }
}

private struct PreviousAnswerSheet: View {
    let previous: PreviousAnswerData

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: ONE2Space.s3) {
                ONE2Label(previous.date.formatted(.dateTime.day().month(.abbreviated).year()))
                Text(previous.text)
                    .one2Type(.journal)
                    .foregroundStyle(ONE2Color.ink)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, ONE2Space.gutter)
            .padding(.vertical, ONE2Space.s8)
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(ONE2Radius.xl)
        .presentationBackground(ONE2Color.surface)
    }
}

// MARK: - Küçük parçalar

/// Tek seçimli hap (odak, niyet): `raised`; seçili `ink` dolgu + `ground` metin.
private struct ChoicePill: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button {
            ONE2Haptics.selection()
            action()
        } label: {
            Text(title)
                .one2Type(.callout)
                .foregroundStyle(isSelected ? ONE2Color.ground : ONE2Color.ink)
                .padding(.horizontal, ONE2Space.s4)
                .padding(.vertical, ONE2Space.s2)
                .frame(minHeight: ONE2Size.minTouch)
                .background(isSelected ? ONE2Color.ink : ONE2Color.raised, in: Capsule())
                .contentShape(Rectangle())
                .animation(ONE2Motion.animation(.chip, reduceMotion: reduceMotion), value: isSelected)
        }
        .buttonStyle(.one2Press)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}

/// Pratik satırının işareti: boş halka ya da `ink` disk + tik (180 ms).
private struct CheckCircle: View {
    let isOn: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            Circle().strokeBorder(ONE2Color.lineStrong, lineWidth: ONE2Size.hairline)
            if isOn {
                Circle().fill(ONE2Color.ink)
                ONE2Icon.check.image(size: ONE2Size.weekTick)
                    .fontWeight(.semibold)
                    .foregroundStyle(ONE2Color.ground)
            }
        }
        .frame(width: ONE2Size.weekGlyph, height: ONE2Size.weekGlyph)
        .animation(ONE2Motion.animation(.chip, reduceMotion: reduceMotion), value: isOn)
        .accessibilityHidden(true)
    }
}
