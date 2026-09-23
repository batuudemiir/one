//
//  ONE2OutlineCard.swift
//  ONE 2.0
//
//  Çerçeveli kart: ground zemin + 1px `line`, radius-lg. Check-in kartı
//  (`.o-checkin`), boş durum (`.o-empty-cta`) ve "+ Ekle" karosu için.
//  Increased Contrast'ta `line` kendiliğinden `lineStrong` olur.
//

import SwiftUI

struct ONE2OutlineCard<Content: View>: View {
    var padding: CGFloat = ONE2Space.s6
    @ViewBuilder let content: () -> Content

    var body: some View {
        content()
            .frame(maxWidth: .infinity)
            .padding(padding)
            .background(ONE2Color.ground, in: ONE2Radius.shape(ONE2Radius.lg))
            .overlay {
                ONE2Radius.shape(ONE2Radius.lg)
                    .strokeBorder(ONE2Color.line, lineWidth: ONE2Size.hairline)
            }
    }
}

#if DEBUG
private struct OutlineSamples: View {
    var body: some View {
        ONE2OutlineCard {
            Text(verbatim: "Adım adım da varılır; bugün de bir adımdı.")
                .one2Type(.affirmation)
                .foregroundStyle(ONE2Color.inkMuted)
                .multilineTextAlignment(.center)
        }
    }
}

#Preview("Gece") { OutlineSamples().one2Preview(.gece) }
#Preview("Gün") { OutlineSamples().one2Preview(.gun) }
#Preview("AX3") { OutlineSamples().one2Preview(.ax3) }
#endif
