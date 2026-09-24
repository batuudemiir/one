//
//  FlowSteps.swift
//  ONE 2.0
//
//  Adım içerikleri (06 › Akış 1–4). Her biri `FlowStepViewData` + modeli
//  alır, cevabı modele yazar; başlık ve soru metnini kabuk çizer.
//

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
