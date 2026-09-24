//
//  FlowShellView.swift
//  ONE 2.0
//
//  Tüm akışların ortak kabuğu (06 › Akış kabuğu): tam ekran; üstte kapat,
//  isteğe bağlı adımda "Atla", adım sayısı kadar ince ilerleme çizgisi.
//  Başlık `title` rolünde, soru serif `prompt`. Alt buton klavyenin üstünde
//  kalır. Skor adımında VoiceOver kapalıyken otomatik ileri; açıkken "Devam".
//

import SwiftUI

struct FlowShellView: View {
    let model: FlowViewModel
    let onDismiss: () -> Void

    var body: some View {
        Group {
            switch model.phase {
            case .steps:
                FlowStepsView(model: model, onClose: {
                    model.close()
                    onDismiss()
                })
            case .closing:
                FlowClosingView(closing: model.flow.closing) { carryOver in
                    model.complete(carryOver: carryOver)
                    onDismiss()
                }
                .transition(.opacity)
            }
        }
        .oneScreenGround()
    }
}

private struct FlowStepsView: View {
    let model: FlowViewModel
    let onClose: () -> Void

    @AccessibilityFocusState private var titleFocused: Bool
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOver
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Skor seçiminden sonra otomatik ileri (06 › Akış 1).
    static let autoAdvanceDelay: Duration = .milliseconds(300)

    var body: some View {
        VStack(spacing: 0) {
            header
            FlowProgressLine(completed: model.stepIndex + 1, total: model.steps.count)
                .padding(.horizontal, V3Tokens.channel)
                .padding(.bottom, V3Tokens.spacingLG)
            if let step = model.current {
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: V3Tokens.spacingXL) {
                        Text(step.title)
                            .displayMD()
                            .foregroundColor(V3Tokens.ink)
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityAddTraits(.isHeader)
                            .accessibilityFocused($titleFocused)
                        if let prompt = step.prompt {
                            Text(prompt)
                                .font(V3Typography.quote(22))
                                .foregroundColor(V3Tokens.ink)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        FlowStepContent(step: step, model: model, onAutoAdvance: autoAdvance)
                    }
                    .padding(.bottom, V3Tokens.spacingXL3)
                    .oneScreenBody()
                }
                .scrollDismissesKeyboard(.interactively)
                .id(step.id)
                .transition(.opacity)
                .safeAreaInset(edge: .bottom) { bottomButton(step) }
            }
        }
        .animation(reduceMotion ? nil : ONEAnimation.easing, value: model.stepIndex)
        .task(id: model.stepIndex) {
            // Yeni adımın başlığı ilk odak.
            try? await Task.sleep(for: .milliseconds(100))
            titleFocused = true
        }
    }

    private var header: some View {
        HStack {
            V3TopBarIconButton(systemName: "xmark",
                               label: NSLocalizedString("one2.action.dismiss", comment: "Close"),
                               action: onClose)
            Spacer(minLength: 0)
            if model.canSkip {
                Button { model.skip() } label: {
                    Text(NSLocalizedString("one2.flow.skip", comment: "Skip an optional step"))
                        .bodyMDSemibold()
                        .foregroundColor(V3Tokens.ink)
                        .padding(.horizontal, V3Tokens.spacingSM)
                        .frame(minWidth: V3Tokens.minTouchTarget, minHeight: V3Tokens.minTouchTarget)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.onePressable)
            }
        }
        .padding(.horizontal, V3Tokens.barInset)
        .padding(.bottom, V3Tokens.spacingSM)
    }

    @ViewBuilder
    private func bottomButton(_ step: FlowStepViewData) -> some View {
        // Skor adımı dokunuşla ilerler; VoiceOver'da otomatik ileri yok, "Devam" var.
        if step.kind != .score || voiceOver {
            V3PrimaryButton(title: model.isLastStep
                            ? NSLocalizedString("one2.reflection.done", comment: "Finish")
                            : NSLocalizedString("one2.flow.next", comment: "Next step"),
                            isEnabled: model.canContinue, isFullWidth: true) {
                model.next()
            }
            .padding(.vertical, V3Tokens.spacingMD)
            .oneScreenBody()
            .background(V3Tokens.paper)
        }
    }

    private func autoAdvance() {
        guard !voiceOver else { return }
        let index = model.stepIndex
        Task {
            try? await Task.sleep(for: Self.autoAdvanceDelay)
            guard model.stepIndex == index else { return }
            model.next()
        }
    }
}

/// Adım türüne göre içerik. Ekran adımları sabit kodlamaz; türün
/// bileşenini çizer.
struct FlowStepContent: View {
    let step: FlowStepViewData
    let model: FlowViewModel
    let onAutoAdvance: () -> Void

    var body: some View {
        switch step.kind {
        case .score:    ScoreStep(step: step, model: model, onAutoAdvance: onAutoAdvance)
        case .emotions: EmotionsStep(step: step, model: model)
        case .causes:   CausesStep(step: step, model: model)
        case .text:     TextStep(step: step, model: model)
        case .list3:    List3Step(step: step, model: model)
        default:        EmptyView()
        }
    }
}
