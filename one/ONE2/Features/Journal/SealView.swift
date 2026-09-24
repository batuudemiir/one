//
//  SealView.swift
//  ONE 2.0
//
//  Kapanış (Seal.md, UX-6): mühür, tek cümle, dolan hafta. Disk 0.9 → 1.0 +
//  opaklık, tek sefer, yumuşak haptik; bugünün hücresi bu anda tike döner.
//  2 sn sonra ya da dokunuşla kapanır. Konfeti, ses, ünlem yok.
//
//  Disk `SealMark` (akış kapanışlarıyla aynı mühür).
//

import SwiftUI

struct SealView: View {
    let seal: ReflectionSeal
    let onDone: () -> Void

    @State private var appeared = false
    @State private var finished = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static let holdDuration: Duration = .seconds(2)

    var body: some View {
        Button(action: finish) {
            VStack(spacing: V3Tokens.spacingXL) {
                Spacer(minLength: 0)
                SealMark(half: false)
                    .scaleEffect(appeared || reduceMotion ? 1 : 0.9)
                    .opacity(appeared ? 1 : 0)

                VStack(spacing: V3Tokens.spacingSM) {
                    Text(JournalCopy.sealTitle(completedDay: seal.completedDay))
                        .displaySM()
                        .foregroundColor(V3Tokens.ink)
                    Text(verbatim: "\(JournalCopy.words(seal.wordCount)) · \(JournalCopy.kindTitle(.quoteReflection))")
                        .font(V3Typography.journal(17))
                        .italic()
                        .foregroundColor(V3Tokens.mutedText)
                }
                .multilineTextAlignment(.center)

                WeekStripView(days: WeekStripAdapter.viewData(seal.week), revealToday: seal.completedDay)
                    .padding(.top, V3Tokens.spacingSM)

                ForEach(seal.badges, id: \.self) { badge in
                    Text(String(format: NSLocalizedString("one2.seal.badge", comment: "Seal: new badge earned"), badge))
                        .bodySMMedium()
                        .foregroundColor(V3Tokens.ink)
                }
                Spacer(minLength: 0)
            }
            .oneScreenBody()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(V3Tokens.paper.ignoresSafeArea())
            .contentShape(Rectangle())
        }
        .buttonStyle(.onePressable)
        .accessibilityHint(NSLocalizedString("one2.seal.continue", comment: "Seal: tap to continue"))
        .task {
            ONEHaptics.feelingSelected()
            withAnimation(ONEAnimation.easingSaved) { appeared = true }
            try? await Task.sleep(for: Self.holdDuration)
            finish()
        }
    }

    private func finish() {
        guard !finished else { return }
        finished = true
        onDone()
    }
}
