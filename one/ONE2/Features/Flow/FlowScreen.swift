//
//  FlowScreen.swift
//  ONE 2.0
//
//  Giriş akışlarının ortak kabuğu (07 §5.2), fullScreenCover:
//  - Üstte adım sayısı kadar ince çizgi; solda ×, sağda "Atla" (yalnız
//    isteğe bağlı adımda).
//  - Adım başlığı `title`, soru Literata `prompt`; gövde veriden
//    (`FlowStepBody`). Her adımda ilk odak başlık.
//  - Skor seçilince 300 ms sonra otomatik ileri; VoiceOver açıksa yerine
//    "Devam et" düğmesi (07 §9).
//  - Her adım bitince taslak; kapatınca uyarı yok (kart "Devam et · n/m").
//  - Soldan geri kaydırma önceki adım. Adım geçişi yatay kayma + opaklık,
//    280 ms; Reduce Motion'da yalnız opaklık (07 §7).
//  - Alt düğme klavyenin üstünde kalır (`safeAreaInset`).
//

import SwiftUI

struct FlowScreen: View {
    let onDraft: (FlowDraftData) -> Void
    let onFinish: (FlowSession) -> Void
    let onCarryOver: (Bool) -> Void
    let onClose: () -> Void

    @State private var session: FlowSession
    @State private var forward = true
    @State private var isClosing = false
    @State private var advanceTask: Task<Void, Never>?
    @AccessibilityFocusState private var titleFocused: Bool
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOver
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Skor seçiminden sonra otomatik ilerleme (07 §5.2).
    static let autoAdvanceMS = 300
    /// Soldan geri kaydırmanın başlangıç şeridi ve eşiği.
    static let edgeWidth: CGFloat = ONE2Space.s6
    static let swipeThreshold: CGFloat = ONE2Size.iconWell

    init(
        flow: FlowViewData,
        onDraft: @escaping (FlowDraftData) -> Void = { _ in },
        onFinish: @escaping (FlowSession) -> Void = { _ in },
        onCarryOver: @escaping (Bool) -> Void = { _ in },
        onClose: @escaping () -> Void
    ) {
        _session = State(initialValue: FlowSession(flow: flow))
        self.onDraft = onDraft
        self.onFinish = onFinish
        self.onCarryOver = onCarryOver
        self.onClose = onClose
    }

    private var step: FlowStepViewData { session.step }

    var body: some View {
        ZStack {
            ONE2Color.ground.ignoresSafeArea()
            if isClosing {
                FlowClosing(flow: session.flow, onCarryOver: onCarryOver, onDone: onClose)
                    .transition(.opacity)
            } else {
                steps
            }
        }
    }

    // MARK: - Adımlar

    private var steps: some View {
        VStack(spacing: 0) {
            FlowHeader(
                total: session.total,
                index: session.index,
                showsSkip: session.showsSkip,
                onClose: close,
                onSkip: skip
            )
            ScrollView {
                VStack(alignment: .leading, spacing: ONE2Space.s6) {
                    VStack(alignment: .leading, spacing: ONE2Space.s3) {
                        Text(step.title)
                            .one2Type(.title)
                            .foregroundStyle(ONE2Color.ink)
                            .accessibilityAddTraits(.isHeader)
                            .accessibilityFocused($titleFocused)
                        if let prompt = step.prompt {
                            Text(prompt)
                                .one2Type(.prompt)
                                .foregroundStyle(ONE2Color.ink)
                        }
                    }
                    FlowStepBody(step: step, answer: session.answer(for: step), onAnswer: answer)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, ONE2Space.gutter)
                .padding(.top, ONE2Space.s6)
                .padding(.bottom, ONE2Space.s8)
                .id(session.index)
                .transition(stepTransition)
            }
            .scrollDismissesKeyboard(.interactively)
            .scrollIndicators(.hidden)
        }
        .safeAreaInset(edge: .bottom) { bottomBar }
        .simultaneousGesture(backSwipe)
        .accessibilityAction(named: Text(one2String("one2.flow.previousStep"))) { back() }
        .onAppear { titleFocused = true }
    }

    @ViewBuilder private var bottomBar: some View {
        if step.kind != .score || voiceOver {
            Button(action: advance) {
                Text(one2String(session.isLast ? "one2.flow.done" : "one2.flow.continue"))
                    .contentShape(Rectangle())
            }
            .buttonStyle(.one2(.primary, fullWidth: true))
            .disabled(!session.canContinue)
            .padding(.horizontal, ONE2Space.gutter)
            .padding(.vertical, ONE2Space.s3)
            .background(ONE2Color.ground)
        }
    }

    private var stepTransition: AnyTransition {
        let moving: AnyTransition = .asymmetric(
            insertion: .move(edge: forward ? .trailing : .leading).combined(with: .opacity),
            removal: .move(edge: forward ? .leading : .trailing).combined(with: .opacity)
        )
        return ONE2Motion.transition(moving, reduceMotion: reduceMotion)
    }

    private var backSwipe: some Gesture {
        DragGesture(minimumDistance: ONE2Space.s4)
            .onEnded { value in
                guard value.startLocation.x < Self.edgeWidth,
                      value.translation.width > Self.swipeThreshold else { return }
                back()
            }
    }

    // MARK: - Eylemler

    private func answer(_ value: FlowAnswerData?) {
        session.set(value, for: step.id)
        guard step.kind == .score, value != nil, !voiceOver else { return }
        let index = session.index
        advanceTask?.cancel()
        advanceTask = Task {
            try? await Task.sleep(for: .milliseconds(Self.autoAdvanceMS))
            guard !Task.isCancelled, session.index == index else { return }
            advance()
        }
    }

    private func advance() {
        move(forward: true) { $0.next() }
    }

    private func skip() {
        move(forward: true) { $0.skip() }
    }

    private func back() {
        guard !session.isFirst else { return }
        move(forward: false) { $0.back() }
    }

    private func move(forward: Bool, _ change: (inout FlowSession) -> Void) {
        advanceTask?.cancel()
        self.forward = forward
        withAnimation(ONE2Motion.animation(.screen, reduceMotion: reduceMotion)) {
            change(&session)
        }
        if session.isFinished {
            onFinish(session)
            withAnimation(ONE2Motion.animation(.screen, reduceMotion: reduceMotion)) { isClosing = true }
        } else {
            onDraft(session.draft(at: Date()))
            titleFocused = true
        }
    }

    /// Kapatınca uyarı yok; bir şey yazıldıysa ya da ilerlendiyse taslak kalır.
    private func close() {
        advanceTask?.cancel()
        if session.index > 0 || !session.answers.isEmpty {
            onDraft(session.draft(at: Date()))
        }
        onClose()
    }
}

/// Üst şerit: ×, adım çizgileri, Atla.
private struct FlowHeader: View {
    let total: Int
    let index: Int
    let showsSkip: Bool
    let onClose: () -> Void
    let onSkip: () -> Void

    var body: some View {
        HStack(spacing: ONE2Space.s3) {
            ONE2RoundButton(icon: .close, accessibilityLabel: one2String("one2.action.close"), filled: false, action: onClose)
            HStack(spacing: ONE2Space.s1) {
                ForEach(0..<total, id: \.self) { i in
                    Capsule()
                        .fill(i <= index ? ONE2Color.ink : ONE2Color.raised)
                        .frame(height: ONE2Size.focusRing)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(String(format: one2String("one2.flow.progress.a11y"), index + 1, total)))
            Button(action: onSkip) {
                Text(one2String("one2.flow.skip")).contentShape(Rectangle())
            }
            .buttonStyle(.one2(.text, size: .compact))
            .opacity(showsSkip ? 1 : 0)
            .disabled(!showsSkip)
            .accessibilityHidden(!showsSkip)
        }
        .padding(.horizontal, ONE2Space.s2)
        .frame(minHeight: ONE2Size.control)
    }
}

#if DEBUG
/// Önizleme: akışın belirli bir adımından başlar.
private func flowPreview(_ flow: FlowViewData, step: Int = 0, answers: [String: FlowAnswerData] = [:]) -> some View {
    let draft = FlowDraftData(day: flow.day, stepIndex: step, answers: answers, updatedAt: FixtureClock.now)
    let data = FlowViewData(id: flow.id, kind: flow.kind, day: flow.day, steps: flow.steps, closing: flow.closing,
                            minutes: flow.minutes, draft: step == 0 && answers.isEmpty ? nil : draft,
                            echo: flow.echo, carryOver: flow.carryOver)
    return FlowScreen(flow: data) {}
}

private func stepPreviews(_ flow: FlowViewData) -> some View {
    TabView {
        ForEach(flow.steps.indices, id: \.self) { index in
            flowPreview(flow, step: index)
        }
    }
    .tabViewStyle(.page(indexDisplayMode: .never))
}

// Her akışın her adımı (sayfalı): gece, gün, AX3.
#Preview("Akış 1 · gece") { stepPreviews(FlowFixture.moodCheckIn()).preferredColorScheme(.dark) }
#Preview("Akış 1 · gün") { stepPreviews(FlowFixture.moodCheckIn()).preferredColorScheme(.light) }
#Preview("Akış 1 · AX3") { stepPreviews(FlowFixture.moodCheckIn()).preferredColorScheme(.dark).dynamicTypeSize(.accessibility3) }
#Preview("Akış 2 · gece") { stepPreviews(FlowFixture.dailyCheckIn()).preferredColorScheme(.dark) }
#Preview("Akış 2 · gün") { stepPreviews(FlowFixture.dailyCheckIn()).preferredColorScheme(.light) }
#Preview("Akış 2 · AX3") { stepPreviews(FlowFixture.dailyCheckIn()).preferredColorScheme(.dark).dynamicTypeSize(.accessibility3) }
#Preview("Akış 3 · gece") { stepPreviews(FlowFixture.morning()).preferredColorScheme(.dark) }
#Preview("Akış 3 · gün") { stepPreviews(FlowFixture.morning()).preferredColorScheme(.light) }
#Preview("Akış 3 · AX3") { stepPreviews(FlowFixture.morning()).preferredColorScheme(.dark).dynamicTypeSize(.accessibility3) }
#Preview("Akış 4 · gece") { stepPreviews(FlowFixture.evening()).preferredColorScheme(.dark) }
#Preview("Akış 4 · gün") { stepPreviews(FlowFixture.evening()).preferredColorScheme(.light) }
#Preview("Akış 4 · AX3") { stepPreviews(FlowFixture.evening()).preferredColorScheme(.dark).dynamicTypeSize(.accessibility3) }
#Preview("Akış 4 · sabah yok") { stepPreviews(FlowFixture.evening(morningFocus: nil)).preferredColorScheme(.dark) }

// Taslak devam senaryosu: nedenler adımından, önceki cevaplar dolu.
#Preview("Taslaktan devam") { FlowScreen(flow: FlowFixture.dailyResumed) {}.preferredColorScheme(.dark) }

// Kapanışlar.
#Preview("Kapanış · yankı") {
    FlowClosing(flow: FlowFixture.moodCheckIn(), onCarryOver: { _ in }, onDone: {})
        .background(ONE2Color.ground).preferredColorScheme(.dark)
}
#Preview("Kapanış · ilk gün") {
    FlowClosing(flow: FlowFixture.moodCheckIn(first: true), onCarryOver: { _ in }, onDone: {})
        .background(ONE2Color.ground).preferredColorScheme(.light)
}
#Preview("Kapanış · gün hazır") {
    FlowClosing(flow: FlowFixture.morning(), onCarryOver: { _ in }, onDone: {})
        .background(ONE2Color.ground).preferredColorScheme(.dark)
}
#Preview("Kapanış · akşam, taşı") {
    FlowClosing(flow: FlowFixture.evening(), onCarryOver: { _ in }, onDone: {})
        .background(ONE2Color.ground).preferredColorScheme(.dark).dynamicTypeSize(.accessibility3)
}
#endif
