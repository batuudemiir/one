//
//  ScoreDisc.swift
//  ONE 2.0
//
//  1–5 skor diski (`.o-score__dot`, `.o-moodpill i`): `score-N` dolgu,
//  `on-score-N` rakam. 60pt ve küçük 20pt varyant. Seçili: `ground` boşluk
//  + `ink` halka. Yalnız görünüm; seçilebilir ölçek `ScoreScale`'de
//  (butonla sarılır). Disk sabit boyutlu, rakam gerekirse küçülür.
//

import SwiftUI

struct ScoreDisc: View {
    enum Size: Sendable { case regular, small }

    let score: Int
    var size: Size = .regular
    var isSelected = false

    private var diameter: CGFloat {
        size == .regular ? ONE2Size.scoreDisc : ONE2Size.scoreDiscSmall
    }

    var body: some View {
        Text(verbatim: "\(score)")
            .one2Type(size == .regular ? .numeralLg : .label)
            .lineLimit(1)
            .minimumScaleFactor(0.5)
            .foregroundStyle(ONE2Score.onFill(score))
            .frame(width: diameter, height: diameter)
            .background(ONE2Score.fill(score), in: Circle())
            .background {
                if isSelected {
                    ZStack {
                        Circle().fill(ONE2Color.ink).padding(-2 * ONE2Size.focusRing)
                        Circle().fill(ONE2Color.ground).padding(-ONE2Size.focusRing)
                    }
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(ONE2Score.accessibilityLabel(score)))
            .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

#if DEBUG
private struct ScoreDiscSamples: View {
    var body: some View {
        VStack(alignment: .leading, spacing: ONE2Space.s5) {
            HStack(spacing: ONE2Space.s3) {
                ForEach(ONE2Score.range, id: \.self) { ScoreDisc(score: $0, isSelected: $0 == 4) }
            }
            HStack(spacing: ONE2Space.s3) {
                ForEach(ONE2Score.range, id: \.self) { ScoreDisc(score: $0, size: .small) }
            }
        }
    }
}

#Preview("Gece") { ScoreDiscSamples().one2Preview(.gece) }
#Preview("Gün") { ScoreDiscSamples().one2Preview(.gun) }
#Preview("AX3") { ScoreDiscSamples().one2Preview(.ax3) }
#endif
