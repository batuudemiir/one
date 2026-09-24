//
//  ScoreScale.swift
//  ONE 2.0
//
//  1–5 mood skoru (components/ScoreScale.md, `.o-score`): beş disk, her biri
//  kendi `score-N` renginde ve rakamlı; altında etiket (07 §5.2: Çok zor ·
//  Zor · İdare eder · İyi · Çok iyi). Yüz ifadesi yok. Seçili: `ground`
//  boşluk + `ink` halka (180 ms, 07 §7), etiket `ink`. Seçimde `selection`
//  haptiği. Diskler 60pt; beşi sığmıyorsa genişliğe göre küçülür.
//  VoiceOver: "4, İyi".
//

import SwiftUI

struct ScoreScale: View {
    var selection: Int? = nil
    /// Beş etiket (1…5); yoksa mood skoru etiketleri. Uyku adımı kendi
    /// etiketlerini verir (07 §5.2 Akış 3).
    var labels: [String]? = nil
    let onSelect: (Int) -> Void

    @State private var width: CGFloat = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private func label(_ score: Int) -> String {
        guard let labels, labels.indices.contains(score - 1) else { return ONE2Score.label(score) }
        return labels[score - 1]
    }

    private var discDiameter: CGFloat {
        let count = CGFloat(ONE2Score.range.count)
        let available = (width - ONE2Space.s2 * (count - 1)) / count
        guard width > 0 else { return ONE2Size.scoreDisc }
        return min(ONE2Size.scoreDisc, max(available, ONE2Size.minTouch))
    }

    var body: some View {
        HStack(alignment: .top, spacing: ONE2Space.s2) {
            ForEach(ONE2Score.range, id: \.self) { score in
                option(score)
            }
        }
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width = $0 }
    }

    private func option(_ score: Int) -> some View {
        let isSelected = selection == score
        return Button {
            ONE2Haptics.selection()
            onSelect(score)
        } label: {
            VStack(spacing: ONE2Space.s2) {
                ScoreDisc(score: score, isSelected: isSelected, fittedDiameter: discDiameter)
                    .animation(ONE2Motion.animation(.chip, reduceMotion: reduceMotion), value: isSelected)
                Text(label(score))
                    .one2Type(.callout)
                    .foregroundStyle(isSelected ? ONE2Color.ink : ONE2Color.inkMuted)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.one2Press)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("\(score), \(label(score))"))
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}

#if DEBUG
private struct ScoreScaleSample: View {
    @State private var selection: Int? = 4

    var body: some View {
        VStack(spacing: ONE2Space.s8) {
            ScoreScale(selection: selection) { selection = $0 }
            ScoreScale { _ in }
                .padding(.horizontal, ONE2Space.s6)
        }
    }
}

#Preview("Gece") { ScoreScaleSample().one2Preview(.gece) }
#Preview("Gün") { ScoreScaleSample().one2Preview(.gun) }
#Preview("AX3") { ScoreScaleSample().one2Preview(.ax3) }
#endif
