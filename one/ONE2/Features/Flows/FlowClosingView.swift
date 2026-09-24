//
//  FlowClosingView.swift
//  ONE 2.0
//
//  Akış kapanışı (06 › Akış kabuğu, Seal.md). Mühür 0.9 → 1.0 + opaklık,
//  320 ms, tek sefer, yumuşak haptik; yankı cümlesi; hafta şeridinde gün
//  tike (yarım mühürde yarım diske) döner; "Bitti".
//  Mühürsüz (mood check-in): yalnız yankı, 2 sn ya da dokunuşla kapanır.
//

import SwiftUI

struct FlowClosingView: View {
    let closing: FlowClosingViewData
    /// "Bitti"; akşamda "Taşı" (true) / "Bırak" (false).
    let onDone: (Bool?) -> Void

    @State private var appeared = false
    @State private var finished = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    static let echoHold: Duration = .seconds(2)

    var body: some View {
        Group {
            if closing.seal == .none {
                echoOnly
            } else {
                sealed
            }
        }
        .task {
            ONEHaptics.feelingSelected()
            withAnimation(ONEAnimation.easing) { appeared = true }
            guard closing.seal == .none else { return }
            try? await Task.sleep(for: Self.echoHold)
            finish(nil)
        }
    }

    // MARK: Mühürsüz

    private var echoOnly: some View {
        Button { finish(nil) } label: {
            Text(closing.echo)
                .font(V3Typography.quote(26))
                .italic()
                .foregroundColor(V3Tokens.mutedText)
                .multilineTextAlignment(.center)
                .opacity(appeared ? 1 : 0)
                .oneScreenBody()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
        }
        .buttonStyle(.onePressable)
        .accessibilityHint(NSLocalizedString("one2.seal.continue", comment: "Tap to continue"))
    }

    // MARK: Mühür

    private var sealed: some View {
        VStack(spacing: V3Tokens.spacingXL) {
            Spacer(minLength: 0)
            SealMark(half: closing.seal == .half)
                .scaleEffect(appeared || reduceMotion ? 1 : 0.9)
                .opacity(appeared ? 1 : 0)
            VStack(spacing: V3Tokens.spacingSM) {
                Text(closing.seal == .half
                     ? NSLocalizedString("one2.seal.ready", comment: "Seal title after the morning flow")
                     : NSLocalizedString("one2.seal.dayClosed", comment: "Seal title: the day is complete"))
                    .displayMD()
                    .foregroundColor(V3Tokens.ink)
                    .accessibilityAddTraits(.isHeader)
                Text(closing.echo)
                    .font(V3Typography.quote(20))
                    .italic()
                    .foregroundColor(V3Tokens.mutedText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .multilineTextAlignment(.center)
            if !closing.week.isEmpty {
                WeekStripView(days: closing.week, revealToday: true)
            }
            Spacer(minLength: 0)
            actions
        }
        .padding(.vertical, V3Tokens.spacingXL)
        .oneScreenBody()
    }

    /// Akşam: sabah maddelerinden işaretlenmeyenler varsa "Taşı" / "Bırak";
    /// yoksa "Bitti".
    @ViewBuilder
    private var actions: some View {
        if closing.carryOver.isEmpty {
            V3PrimaryButton(title: NSLocalizedString("one2.reflection.done", comment: "Finish"), isFullWidth: true) {
                finish(nil)
            }
        } else {
            VStack(alignment: .leading, spacing: V3Tokens.spacingMD) {
                Text(NSLocalizedString("one2.flow.carry.question", comment: "Carry unchecked items to tomorrow?"))
                    .bodyLGSemibold()
                    .foregroundColor(V3Tokens.ink)
                Text(closing.carryOver.joined(separator: " · "))
                    .bodyMD()
                    .foregroundColor(V3Tokens.mutedText)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: V3Tokens.spacingMD) {
                    V3OutlineButton(title: NSLocalizedString("one2.flow.carry.drop", comment: "Let the items go"),
                                    isFullWidth: true) { finish(false) }
                    V3PrimaryButton(title: NSLocalizedString("one2.flow.carry.move", comment: "Carry items to tomorrow"),
                                    isFullWidth: true) { finish(true) }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func finish(_ carryOver: Bool?) {
        guard !finished else { return }
        finished = true
        onDone(carryOver)
    }
}

/// 96pt `brand` mühür diski: tam ya da alttan dolu yarım (sabah: gün yarım).
struct SealMark: View {
    let half: Bool

    static let size: CGFloat = 96

    var body: some View {
        ZStack {
            if half {
                Circle()
                    .strokeBorder(V3Tokens.brand, lineWidth: 2)
                Circle()
                    .trim(from: 0, to: 0.5)
                    .fill(V3Tokens.brand)
            } else {
                Circle()
                    .fill(V3Tokens.brand)
                Image(systemName: "checkmark")
                    .iconLG(weight: .semibold)
                    .foregroundColor(V3Tokens.onBrand)
            }
        }
        .frame(width: Self.size, height: Self.size)
        .accessibilityHidden(true)
    }
}

#Preview("Closing · half · dark") {
    FlowClosingView(closing: FlowFixtures.flow(.morning).closing) { _ in }
        .oneScreenGround()
        .preferredColorScheme(.dark)
}

#Preview("Closing · full · light") {
    FlowClosingView(closing: FlowFixtures.flow(.daily).closing) { _ in }
        .oneScreenGround()
        .preferredColorScheme(.light)
}

#Preview("Closing · echo only · AX3") {
    FlowClosingView(closing: FlowFixtures.flow(.moodCheckIn).closing) { _ in }
        .oneScreenGround()
        .dynamicTypeSize(.accessibility3)
}
