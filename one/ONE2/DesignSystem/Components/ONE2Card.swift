//
//  ONE2Card.swift
//  ONE 2.0
//
//  Kart yüzeyi (README "Boşluk, köşe, yüzey"): surface, radius-lg, gölgesiz;
//  ayrım zemin tonuyla. İsteğe bağlı 1px `line` çerçeve.
//

import SwiftUI

struct ONE2Card<Content: View>: View {
    var padding: CGFloat = ONE2Space.s5
    var bordered = false
    @ViewBuilder let content: () -> Content

    var body: some View {
        content()
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(padding)
            .background(ONE2Color.surface, in: ONE2Radius.shape(ONE2Radius.lg))
            .overlay {
                if bordered {
                    ONE2Radius.shape(ONE2Radius.lg)
                        .strokeBorder(ONE2Color.line, lineWidth: ONE2Size.hairline)
                }
            }
    }
}

#if DEBUG
private struct CardSamples: View {
    var body: some View {
        VStack(spacing: ONE2Space.cardGap) {
            ONE2Card {
                VStack(alignment: .leading, spacing: ONE2Space.s3) {
                    Text(verbatim: "Mood check-in").one2Type(.titleSm).foregroundStyle(ONE2Color.ink)
                    Text(verbatim: "Sabah otobüsü kaçırdım ve ilk kez koşmadım.")
                        .one2Type(.journal).foregroundStyle(ONE2Color.inkMuted)
                }
            }
            ONE2Card(bordered: true) {
                Text(verbatim: "Çerçeveli kart").one2Type(.body).foregroundStyle(ONE2Color.ink)
            }
        }
    }
}

#Preview("Gece") { CardSamples().one2Preview(.gece) }
#Preview("Gün") { CardSamples().one2Preview(.gun) }
#Preview("AX3") { CardSamples().one2Preview(.ax3) }
#endif
