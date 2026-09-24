//
//  FlowSteps.swift
//  ONE 2.0
//
//  Adım içerikleri (06 › Akış 1–4). Her biri `FlowStepViewData` + modeli
//  alır, cevabı modele yazar; başlık ve soru metnini kabuk çizer.
//

import Foundation
import SwiftUI

// MARK: - score

struct ScoreStep: View {
    let step: FlowStepViewData
    let model: FlowViewModel
    let onAutoAdvance: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: V3Tokens.spacingXL) {
            ScoreScaleView(options: step.options ?? FlowFixtures.scoreOptions(), selected: selected) { value in
                model.setAnswer(.score(value), for: step.id)
                onAutoAdvance()
            }
            // Sabah: duygular varsayılan kapalı ek adım; tek dokunuşla açılır.
            if let extra = model.optionalStepAfterCurrent, extra.kind == .emotions {
                Button { model.enableStep(extra.id) } label: {
                    Label(NSLocalizedString("one2.flow.addEmotions", comment: "Add the optional emotions step"),
                          systemImage: "plus")
                        .bodyMDSemibold()
                        .foregroundColor(V3Tokens.ink)
                        .frame(minHeight: V3Tokens.minTouchTarget)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.onePressable)
            }
        }
    }

    private var selected: Int? {
        if case .score(let value) = model.answer(for: step.id) { return value }
        return nil
    }
}

// MARK: - emotions

struct EmotionsStep: View {
    let step: FlowStepViewData
    let model: FlowViewModel

    var body: some View {
        WrapLayout {
            ForEach(model.options(for: step)) { option in
                EmotionChipView(option: option, isSelected: chosen.contains(option.id)) {
                    toggle(option.id)
                }
            }
        }
    }

    private var chosen: [String] {
        if case .choices(let ids) = model.answer(for: step.id) { return ids }
        return []
    }

    private func toggle(_ id: String) {
        var ids = chosen
        if let index = ids.firstIndex(of: id) { ids.remove(at: index) } else { ids.append(id) }
        model.setAnswer(ids.isEmpty ? nil : .choices(ids), for: step.id)
    }
}

// MARK: - causes

struct CausesStep: View {
    let step: FlowStepViewData
    let model: FlowViewModel

    @State private var isAdding = false
    @State private var newLabel = ""
    @FocusState private var fieldFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: V3Tokens.spacingLG) {
            WrapLayout {
                ForEach(model.options(for: step)) { option in
                    CauseTagView(label: option.label, isSelected: chosen.contains(option.id)) {
                        toggle(option.id)
                    }
                }
                if !isAdding {
                    CauseTagView(label: NSLocalizedString("one2.flow.causes.add", comment: "Add a tag"),
                                 isSelected: false, systemImage: "plus") {
                        isAdding = true
                        fieldFocused = true
                    }
                }
            }
            if isAdding {
                TextField(NSLocalizedString("one2.flow.causes.placeholder", comment: "New tag field"), text: $newLabel)
                    .bodyLG()
                    .foregroundColor(V3Tokens.ink)
                    .tint(V3Tokens.ink)
                    .submitLabel(.done)
                    .focused($fieldFocused)
                    .onSubmit(commit)
                    .padding(.horizontal, V3Tokens.spacingMD)
                    .frame(minHeight: V3Tokens.minTouchTarget)
                    .overlay(
                        RoundedRectangle(cornerRadius: V3Tokens.radiusChip, style: .continuous)
                            .strokeBorder(V3Tokens.lineStrong, lineWidth: 1)
                    )
            }
        }
    }

    private var chosen: [String] {
        if case .choices(let ids) = model.answer(for: step.id) { return ids }
        return []
    }

    private func toggle(_ id: String) {
        var ids = chosen
        if let index = ids.firstIndex(of: id) { ids.remove(at: index) } else { ids.append(id) }
        model.setAnswer(ids.isEmpty ? nil : .choices(ids), for: step.id)
    }

    private func commit() {
        model.addOption(newLabel, to: step.id)
        newLabel = ""
        isAdding = false
    }
}

// MARK: - text

struct TextStep: View {
    let step: FlowStepViewData
    let model: FlowViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: V3Tokens.spacingLG) {
            GrowingSerifField(text: binding, accessibilityLabel: step.prompt)
            if let previous = step.previousAnswer, !previous.isEmpty {
                PreviousAnswerBox(text: previous)
            }
        }
    }

    private var binding: Binding<String> {
        Binding(
            get: {
                if case .text(let value) = model.answer(for: step.id) { return value }
                return ""
            },
            set: { model.setAnswer(.text($0), for: step.id) }
        )
    }
}

/// "Geçen sefer şöyle yazmıştın: …" — önceki cevabın ilk iki satırı.
struct PreviousAnswerBox: View {
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: V3Tokens.spacingXS) {
            Text(NSLocalizedString("one2.flow.previous", comment: "Label above the previous answer"))
                .v3MicroLabel()
                .foregroundColor(V3Tokens.mutedText)
            Text(text)
                .font(V3Typography.journal(16))
                .foregroundColor(V3Tokens.mutedText)
                .lineLimit(2)
        }
        .padding(V3Tokens.spacingLG)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: V3Tokens.radiusPanel, style: .continuous)
                .fill(V3Tokens.wash)
        )
        .accessibilityElement(children: .combine)
    }
}

// MARK: - list3

/// 1–3 madde; her biri tek satırdan büyüyen serif alan, önünde mono sıra.
struct List3Step: View {
    let step: FlowStepViewData
    let model: FlowViewModel

    static let count = 3

    var body: some View {
        VStack(alignment: .leading, spacing: V3Tokens.spacingMD) {
            ForEach(0..<Self.count, id: \.self) { index in
                HStack(alignment: .firstTextBaseline, spacing: V3Tokens.spacingMD) {
                    Text(verbatim: "\(index + 1)")
                        .monoSM()
                        .foregroundColor(V3Tokens.mutedText)
                        .accessibilityHidden(true)
                    GrowingSerifField(text: binding(index), accessibilityLabel: String.localizedStringWithFormat(
                        NSLocalizedString("one2.flow.list.item", comment: "List item n"), index + 1))
                }
            }
        }
    }

    private var items: [String] {
        if case .list(let values) = model.answer(for: step.id) {
            return values + Array(repeating: "", count: max(0, Self.count - values.count))
        }
        return Array(repeating: "", count: Self.count)
    }

    private func binding(_ index: Int) -> Binding<String> {
        Binding(
            get: { items[index] },
            set: { value in
                var values = items
                values[index] = value
                model.setAnswer(.list(values), for: step.id)
            }
        )
    }
}

// MARK: - sleep

/// Uyku kalitesi 1–5 + isteğe bağlı saat (4–12, 0,5 adım).
struct SleepStep: View {
    let step: FlowStepViewData
    let model: FlowViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: V3Tokens.spacingXL) {
            ScoreScaleView(options: step.options ?? FlowFixtures.sleepOptions(), selected: score > 0 ? score : nil) { value in
                model.setAnswer(.sleep(score: value, hours: hours), for: step.id)
            }
            if let hours {
                hoursPicker(hours)
            } else {
                Button { set(hours: SleepHours.initial) } label: {
                    Label(NSLocalizedString("one2.flow.sleep.addHours", comment: "Add sleep hours"), systemImage: "plus")
                        .bodyMDSemibold()
                        .foregroundColor(V3Tokens.ink)
                        .frame(minHeight: V3Tokens.minTouchTarget)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.onePressable)
            }
        }
    }

    private func hoursPicker(_ hours: Double) -> some View {
        HStack(spacing: V3Tokens.spacingMD) {
            stepButton("minus", NSLocalizedString("one2.flow.sleep.less", comment: "Fewer hours"),
                       enabled: hours > SleepHours.range.lowerBound) { set(hours: SleepHours.adjusted(hours, by: -SleepHours.step)) }
            Text(hoursLabel(hours))
                .displaySM()
                .foregroundColor(V3Tokens.ink)
                .frame(minWidth: V3Tokens.spacingXL5 * 2)
                .accessibilityAdjustableAction { direction in
                    switch direction {
                    case .increment: set(hours: SleepHours.adjusted(hours, by: SleepHours.step))
                    case .decrement: set(hours: SleepHours.adjusted(hours, by: -SleepHours.step))
                    @unknown default: break
                    }
                }
            stepButton("plus", NSLocalizedString("one2.flow.sleep.more", comment: "More hours"),
                       enabled: hours < SleepHours.range.upperBound) { set(hours: SleepHours.adjusted(hours, by: SleepHours.step)) }
            Spacer(minLength: 0)
            stepButton("xmark", NSLocalizedString("one2.flow.sleep.removeHours", comment: "Remove sleep hours"),
                       enabled: true) { set(hours: nil) }
        }
    }

    private func stepButton(_ symbol: String, _ label: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .iconMD()
                .foregroundColor(enabled ? V3Tokens.ink : V3Tokens.faintText)
                .frame(width: V3Tokens.minTouchTarget, height: V3Tokens.minTouchTarget)
                .background(Circle().fill(V3Tokens.wash))
                .contentShape(Rectangle())
        }
        .buttonStyle(.onePressable)
        .disabled(!enabled)
        .accessibilityLabel(label)
    }

    private func hoursLabel(_ hours: Double) -> String {
        String(format: NSLocalizedString("one2.flow.sleep.hours", comment: "Sleep hours value"),
               hours.formatted(.number.precision(.fractionLength(0...1))))
    }

    private var score: Int {
        if case .sleep(let score, _) = model.answer(for: step.id) { return score }
        return 0
    }

    private var hours: Double? {
        if case .sleep(_, let hours) = model.answer(for: step.id) { return hours }
        return nil
    }

    private func set(hours: Double?) {
        let answer = FlowAnswer.sleep(score: score, hours: hours)
        model.setAnswer(answer.isMeaningful ? answer : nil, for: step.id)
    }
}

// MARK: - focus

/// Tek seçim; "Kendi kelimen" seçilince satır içi alan.
struct FocusStep: View {
    let step: FlowStepViewData
    let model: FlowViewModel

    @State private var customSelected = false
    @FocusState private var fieldFocused: Bool

    static let customID = "custom"

    var body: some View {
        VStack(alignment: .leading, spacing: V3Tokens.spacingLG) {
            WrapLayout {
                ForEach(step.options ?? []) { option in
                    CauseTagView(label: option.label, isSelected: isSelected(option)) {
                        select(option)
                    }
                }
            }
            if showsField {
                GrowingSerifField(text: customBinding,
                                  placeholder: NSLocalizedString("one2.focus.custom", comment: "Focus option: own word"),
                                  singleLine: true)
                    .focused($fieldFocused)
            }
        }
        .onAppear { customSelected = isCustomAnswer }
    }

    private var isCustomAnswer: Bool {
        if case .focus(_, true) = model.answer(for: step.id) { return true }
        return false
    }

    private var showsField: Bool { customSelected || isCustomAnswer }

    private func isSelected(_ option: FlowOptionViewData) -> Bool {
        if option.id == Self.customID { return showsField }
        if case .focus(let id, false) = model.answer(for: step.id) { return id == option.id }
        return false
    }

    private func select(_ option: FlowOptionViewData) {
        if option.id == Self.customID {
            customSelected = true
            fieldFocused = true
            if !isCustomAnswer { model.setAnswer(nil, for: step.id) }
        } else {
            customSelected = false
            model.setAnswer(.focus(option.id, custom: false), for: step.id)
        }
    }

    private var customBinding: Binding<String> {
        Binding(
            get: {
                if case .focus(let text, true) = model.answer(for: step.id) { return text }
                return ""
            },
            set: { model.setAnswer(.focus($0, custom: true), for: step.id) }
        )
    }
}

// MARK: - quote

/// Günün sözü (QuoteCard küçük varyant) + tek satır cevap. Cevap ayrıca
/// söze yazı olarak kaydedilir (UX_istekleri.md › 8).
struct QuoteStep: View {
    let step: FlowStepViewData
    let model: FlowViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: V3Tokens.spacingLG) {
            if let quote = step.quote {
                VStack(alignment: .leading, spacing: V3Tokens.spacingSM) {
                    Image(systemName: "quote.opening")
                        .iconSM()
                        .foregroundColor(V3Tokens.mutedText)
                        .accessibilityHidden(true)
                    Text(quote.text)
                        .font(V3Typography.quote(20))
                        .foregroundColor(V3Tokens.ink)
                        .fixedSize(horizontal: false, vertical: true)
                    if let attribution = quote.attribution {
                        Text(attribution)
                            .monoSM()
                            .foregroundColor(V3Tokens.mutedText)
                    }
                }
                .padding(V3Tokens.spacingXL)
                .frame(maxWidth: .infinity, alignment: .leading)
                .oneCardBackground(radius: V3Tokens.radiusTile)
                .accessibilityElement(children: .combine)
            }
            GrowingSerifField(text: binding, accessibilityLabel: step.prompt, singleLine: true)
        }
    }

    private var binding: Binding<String> {
        Binding(
            get: {
                if case .text(let value) = model.answer(for: step.id) { return value }
                return ""
            },
            set: { model.setAnswer(.text($0), for: step.id) }
        )
    }
}
