//
//  ONE2Glass.swift
//  ONE 2.0
//
//  Yüzen cam yüzey (tab bar, fotoğraf üstü kontroller): `.ultraThinMaterial`
//  + `glass` tint + 1px `line` iç kenar. Reduce Transparency açıkken düz
//  `raised` zemin (README Hareket ve geri bildirim).
//

import SwiftUI

private struct ONE2GlassBackground<S: InsettableShape>: ViewModifier {
    let shape: S
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    func body(content: Content) -> some View {
        content
            .background {
                if reduceTransparency {
                    shape.fill(ONE2Color.raised)
                } else {
                    shape.fill(.ultraThinMaterial)
                        .overlay(shape.fill(ONE2Color.glass))
                }
            }
            .overlay(shape.strokeBorder(ONE2Color.line, lineWidth: ONE2Size.hairline))
    }
}

extension View {
    /// Cam zemin; varsayılan şekil hap.
    func one2Glass<S: InsettableShape>(in shape: S) -> some View {
        modifier(ONE2GlassBackground(shape: shape))
    }

    func one2Glass() -> some View {
        one2Glass(in: Capsule())
    }
}

#if DEBUG
private struct GlassSamples: View {
    var body: some View {
        ZStack(alignment: .bottom) {
            VStack(spacing: ONE2Space.cardGap) {
                ForEach(1...5, id: \.self) { i in
                    ONE2Radius.shape(ONE2Radius.lg)
                        .fill(ONE2Score.fill(i))
                        .frame(height: ONE2Size.iconWell)
                }
            }
            Text(verbatim: "Cam yüzey")
                .one2Type(.headline)
                .foregroundStyle(ONE2Color.ink)
                .frame(maxWidth: .infinity, minHeight: ONE2Size.addButtonHeight)
                .one2Glass()
                .one2FloatShadow()
                .padding(.bottom, ONE2Space.s8)
        }
    }
}

#Preview("Gece") { GlassSamples().one2Preview(.gece) }
#Preview("Gün") { GlassSamples().one2Preview(.gun) }
#Preview("AX3") { GlassSamples().one2Preview(.ax3) }
#endif
