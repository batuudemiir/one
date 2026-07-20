//
//  TabGlyph.swift
//  one
//
//  Sekme simgeleri. Prototipteki glifler geometrik primitif — SF Symbols'ta
//  karşılıkları yok, o yüzden çiziliyorlar.
//

import SwiftUI

/// Prototipin sekme glifleri: ◎ ▦ ◠ ◍
///
/// SF Symbols denendi ve tutmadı: `dot.radiowaves.left.and.right` bir wifi
/// dalgası, `waveform` ses çubukları, `person.crop.circle` bir insan silüeti
/// çiziyor. Prototipin dili ise **soyut geometri** — ne anlattığı değil,
/// nasıl durduğu önemli. Dört glif de birkaç çemberden ibaret olduğu için
/// çizmek, yaklaşık bir sembol seçmekten hem daha sadık hem daha ucuz.
enum TabGlyph {
    case frequency   // ◎  iç içe iki çember
    case archive     // ▦  ızgara
    case echo        // ◠  yay
    case profile     // ◍  içi dolu çember
}

struct TabGlyphView: View {
    let glyph: TabGlyph
    /// Prototipte 16pt. Seçili sekmede çizgi kalınlaşıyor, boyut değişmiyor.
    var size: CGFloat = 16
    var isSelected: Bool = false

    private var line: CGFloat { isSelected ? 1.9 : 1.4 }

    var body: some View {
        Canvas { context, canvasSize in
            let rect = CGRect(origin: .zero, size: canvasSize)
                .insetBy(dx: line / 2, dy: line / 2)
            draw(in: &context, rect: rect)
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }

    private func draw(in context: inout GraphicsContext, rect: CGRect) {
        let shading = GraphicsContext.Shading.color(.primary)

        switch glyph {
        case .frequency:
            // ◎ — dış çember + merkezde dolu küçük çember.
            context.stroke(Path(ellipseIn: rect), with: shading, lineWidth: line)
            let inner = rect.insetBy(dx: rect.width * 0.30, dy: rect.height * 0.30)
            context.fill(Path(ellipseIn: inner), with: shading)

        case .archive:
            // ▦ — 3×3 ızgara. Dolu kareler mozaiği çağrıştırıyor.
            let cell = rect.width / 3
            for row in 0..<3 {
                for col in 0..<3 {
                    let r = CGRect(
                        x: rect.minX + CGFloat(col) * cell + cell * 0.14,
                        y: rect.minY + CGFloat(row) * cell + cell * 0.14,
                        width: cell * 0.72,
                        height: cell * 0.72
                    )
                    context.fill(
                        Path(roundedRect: r, cornerRadius: cell * 0.16),
                        with: shading
                    )
                }
            }

        case .echo:
            // ◠ — iki eş merkezli yay. Yankının görsel karşılığı:
            // aynı şey, gittikçe zayıflayarak tekrar ediyor.
            for (index, scale) in [1.0, 0.55].enumerated() {
                let r = rect.insetBy(
                    dx: rect.width * (1 - scale) / 2,
                    dy: rect.height * (1 - scale) / 2
                )
                var path = Path()
                path.addArc(
                    center: CGPoint(x: r.midX, y: r.maxY),
                    radius: r.width / 2,
                    startAngle: .degrees(180),
                    endAngle: .degrees(0),
                    clockwise: false
                )
                context.stroke(
                    path,
                    with: shading,
                    style: StrokeStyle(lineWidth: line, lineCap: .round)
                )
                _ = index
            }

        case .profile:
            // ◍ — çember + içinde dolu daire.
            context.stroke(Path(ellipseIn: rect), with: shading, lineWidth: line)
            let core = rect.insetBy(dx: rect.width * 0.26, dy: rect.height * 0.26)
            context.fill(Path(ellipseIn: core), with: shading)
        }
    }
}

#Preview {
    HStack(spacing: 22) {
        ForEach([TabGlyph.frequency, .archive, .echo, .profile], id: \.self) { g in
            VStack(spacing: 8) {
                TabGlyphView(glyph: g, isSelected: false)
                TabGlyphView(glyph: g, isSelected: true)
            }
        }
    }
    .padding(40)
    .background(ONETokens.oneCream)
}

extension TabGlyph: Hashable {}
