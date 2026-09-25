//
//  SealView.swift
//  ONE 2.0
//
//  Yazma kapanışı (07 §5.5): tasarım sistemindeki `Seal` (disk, küçük harf
//  başlık, özet: kelime sayısı · tür), varsa kazanılan rozet satırı.
//  2,5 sn ya da dokunuşla kapanır; VoiceOver açıksa kendiliğinden kapanmaz,
//  `Kapat` görünür. Mühür altındaki hafta şeridi UX-6'da `WeekStrip` ile.
//

import SwiftUI

struct SealView: View {
    let seal: ReflectionSeal
    let onDone: () -> Void

    @State private var finished = false
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOver

    static let holdSeconds = 2.5

    var body: some View {
        VStack(spacing: ONE2Space.s8) {
            Spacer(minLength: 0)
            Seal(
                title: JournalCopy.sealTitle(completedDay: seal.completedDay),
                summary: "\(JournalCopy.words(seal.wordCount)) · \(JournalCopy.kindTitle(seal.kind))"
            )
            ForEach(seal.badges, id: \.self) { badge in
                Text(String(format: NSLocalizedString("one2.seal.badge", comment: "Seal: new badge earned"), badge))
                    .one2Type(.bodySm)
                    .foregroundStyle(ONE2Color.ink)
            }
            Spacer(minLength: 0)
            if voiceOver {
                Button(action: finish) {
                    Text(one2String("one2.action.close")).contentShape(Rectangle())
                }
                .buttonStyle(.one2(.secondary, fullWidth: true))
            }
        }
        .padding(.horizontal, ONE2Space.gutter)
        .padding(.bottom, ONE2Space.s6)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(ONE2Color.ground.ignoresSafeArea())
        .contentShape(Rectangle())
        .onTapGesture(perform: finish)
        .accessibilityHint(NSLocalizedString("one2.seal.continue", comment: "Seal: tap to continue"))
        .task {
            guard !voiceOver else { return }
            try? await Task.sleep(for: .seconds(Self.holdSeconds))
            finish()
        }
    }

    private func finish() {
        guard !finished else { return }
        finished = true
        onDone()
    }
}
