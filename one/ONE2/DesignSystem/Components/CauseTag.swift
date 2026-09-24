//
//  CauseTag.swift
//  ONE 2.0
//
//  Neden etiketi (components/CauseTag.md, `.o-tag`): duygu hapından bilerek
//  farklı. Çerçeveli (`line-strong`), radius-sm, ink-muted; seçili
//  `brand-soft` + `on-brand-soft`, çerçevesiz. Görünür yükseklik 36pt,
//  dokunma alanı 44pt.
//

import SwiftUI

struct CauseTag: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button {
            ONE2Haptics.selection()
            action()
        } label: {
            Text(title)
                .one2Type(.callout)
                .foregroundStyle(isSelected ? ONE2Color.onBrandSoft : ONE2Color.inkMuted)
                .padding(.horizontal, ONE2Size.tagPadding)
                .padding(.vertical, ONE2Space.s1)
                .frame(minHeight: ONE2Size.tagHeight)
                .background(isSelected ? ONE2Color.brandSoft : .clear, in: ONE2Radius.shape(ONE2Radius.sm))
                .overlay {
                    if !isSelected {
                        ONE2Radius.shape(ONE2Radius.sm)
                            .strokeBorder(ONE2Color.lineStrong, lineWidth: ONE2Size.hairline)
                    }
                }
                .frame(minHeight: ONE2Size.minTouch)
                .contentShape(Rectangle())
                .animation(ONE2Motion.animation(.chip, reduceMotion: reduceMotion), value: isSelected)
        }
        .buttonStyle(.one2Press)
        .accessibilityLabel(Text(title))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

#if DEBUG
private struct CauseTagSamples: View {
    @State private var selected: Set<String> = ["Uyku"]
    private let tags = ["Uyku", "İş", "Aile", "Hareket", "Hava"]

    var body: some View {
        VStack(alignment: .leading, spacing: ONE2Space.s1) {
            ForEach(tags, id: \.self) { tag in
                CauseTag(title: tag, isSelected: selected.contains(tag)) {
                    if selected.contains(tag) { selected.remove(tag) } else { selected.insert(tag) }
                }
            }
        }
    }
}

#Preview("Gece") { CauseTagSamples().one2Preview(.gece) }
#Preview("Gün") { CauseTagSamples().one2Preview(.gun) }
#Preview("AX3") { CauseTagSamples().one2Preview(.ax3) }
#endif
