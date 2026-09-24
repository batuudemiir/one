//
//  EmotionChip.swift
//  ONE 2.0
//
//  Duygu chip'i (components/EmotionChip.md, `.o-chip`): çoklu seçim.
//  - seçilmemiş: raised hap + 10pt aile noktası
//  - seçili: aile dolgusu + `on-emo-*` metin ve nokta
//  44pt, seçim 180 ms, selection haptiği; `.isSelected` trait.
//

import SwiftUI

struct EmotionChip: View {
    let title: String
    let family: ONE2EmotionFamily
    let isSelected: Bool
    let action: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button {
            ONE2Haptics.selection()
            action()
        } label: {
            HStack(spacing: ONE2Space.s2) {
                Circle()
                    .fill(isSelected ? family.onFill : family.fill)
                    .frame(width: ONE2Size.emotionDot, height: ONE2Size.emotionDot)
                    .accessibilityHidden(true)
                Text(title)
                    .one2Type(.callout)
                    .foregroundStyle(isSelected ? family.onFill : ONE2Color.ink)
            }
            .padding(.horizontal, ONE2Space.s4)
            .padding(.vertical, ONE2Space.s2)
            .frame(minHeight: ONE2Size.minTouch)
            .background(isSelected ? family.fill : ONE2Color.raised, in: Capsule())
            .contentShape(Rectangle())
            .animation(ONE2Motion.animation(.chip, reduceMotion: reduceMotion), value: isSelected)
        }
        .buttonStyle(.one2Press)
        .accessibilityLabel(Text(title))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

#if DEBUG
private struct EmotionChipSamples: View {
    @State private var selected: Set<ONE2EmotionFamily> = [.nese, .kaygi]

    var body: some View {
        VStack(alignment: .leading, spacing: ONE2Space.s2) {
            ForEach(ONE2EmotionFamily.allCases, id: \.self) { family in
                EmotionChip(title: family.title, family: family, isSelected: selected.contains(family)) {
                    if selected.contains(family) { selected.remove(family) } else { selected.insert(family) }
                }
            }
        }
    }
}

#Preview("Gece") { EmotionChipSamples().one2Preview(.gece) }
#Preview("Gün") { EmotionChipSamples().one2Preview(.gun) }
#Preview("AX3") { EmotionChipSamples().one2Preview(.ax3) }
#endif
