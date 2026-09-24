//
//  V3MoodPattern.swift
//  one
//
//  Renk körlüğü için mood başına **doku**.
//
//  ONE'ın birincil gösterimi renk: dokuz duygu dokuz renk. Bu, deuteranopi
//  ve tritanopi için okunamaz bir arayüz demek — dört sıcak mood
//  (`#FF3B1F` ateşli · `#FF8A00` coşkulu · `#FFC300` mutlu · `#C8F135` enerjik)
//  kırmızı-yeşil körlüğünde birbirine çöküyor, `#5C6BC0` hüzünlü ile
//  `#2B4CF0` odaklı mavi-sarı körlüğünde ayırt edilemiyor. Erkek nüfusun
//  yaklaşık %8'i bu uygulamanın ana ekranını okuyamıyordu.
//
//  Çözüm ikinci bir kanal: her mood'un kendi çizgi/nokta deseni var. Desen
//  yalnız **Differentiate Without Color** açıkken çiziliyor — normal
//  koşulda arayüz sade kalıyor, ihtiyaç duyanda ikinci kanal beliriyor.
//
//  Desenler mood'un kendi `ink` çiftiyle çiziliyor, yani kontrast garanti:
//  sarı üstünde koyu, mor üstünde açık.
//

import SwiftUI

/// Bir mood'un ayırt edici deseni. Dokuzu da tek bakışta farklı okunur:
/// yön (yatay/dikey/çapraz), yoğunluk (seyrek/sık) ve tür (çizgi/nokta/halka)
/// üç bağımsız eksen — dokuz kombinasyon birbirine karışmıyor.
struct V3MoodPattern: Shape {
    let mood: V3Mood

    func path(in rect: CGRect) -> Path {
        var p = Path()
        // Adım, karenin kısa kenarına göre ölçekleniyor: 9pt'lik yıl mini
        // hücresinde de 108pt'lik mood karesinde de aynı sıklık okunuyor.
        let unit = max(rect.width, rect.height)
        let step = max(3, unit / 5)

        switch mood {
        case .atesli:   diagonal(&p, in: rect, step: step, ascending: true)
        case .huzunlu:  diagonal(&p, in: rect, step: step, ascending: false)
        case .gergin:   vertical(&p, in: rect, step: step)
        case .mutlu:    horizontal(&p, in: rect, step: step)
        case .enerjik:
            vertical(&p, in: rect, step: step * 1.4)
            horizontal(&p, in: rect, step: step * 1.4)
        case .coskulu:  dots(&p, in: rect, step: step, radius: unit / 22)
        case .yorgun:   dots(&p, in: rect, step: step * 1.8, radius: unit / 26)
        case .odakli:   rings(&p, in: rect, unit: unit)
        case .huzurlu:  waves(&p, in: rect, step: step * 1.3)
        }
        return p
    }

    // MARK: - Desen çizicileri

    private func diagonal(_ p: inout Path, in r: CGRect, step: CGFloat, ascending: Bool) {
        var x = r.minX - r.height
        while x < r.maxX + r.height {
            p.move(to: CGPoint(x: x, y: ascending ? r.maxY : r.minY))
            p.addLine(to: CGPoint(x: x + r.height, y: ascending ? r.minY : r.maxY))
            x += step
        }
    }

    private func vertical(_ p: inout Path, in r: CGRect, step: CGFloat) {
        var x = r.minX + step / 2
        while x < r.maxX {
            p.move(to: CGPoint(x: x, y: r.minY))
            p.addLine(to: CGPoint(x: x, y: r.maxY))
            x += step
        }
    }

    private func horizontal(_ p: inout Path, in r: CGRect, step: CGFloat) {
        var y = r.minY + step / 2
        while y < r.maxY {
            p.move(to: CGPoint(x: r.minX, y: y))
            p.addLine(to: CGPoint(x: r.maxX, y: y))
            y += step
        }
    }

    private func dots(_ p: inout Path, in r: CGRect, step: CGFloat, radius: CGFloat) {
        let rad = max(0.6, radius)
        var y = r.minY + step / 2
        var row = 0
        while y < r.maxY {
            // Şaşırtmalı dizilim — düz ızgara, çizgi desenleriyle karışıyor.
            var x = r.minX + step / 2 + (row % 2 == 0 ? 0 : step / 2)
            while x < r.maxX {
                p.addEllipse(in: CGRect(x: x - rad, y: y - rad, width: rad * 2, height: rad * 2))
                x += step
            }
            y += step
            row += 1
        }
    }

    private func rings(_ p: inout Path, in r: CGRect, unit: CGFloat) {
        let c = CGPoint(x: r.midX, y: r.midY)
        for factor in [0.22, 0.40] {
            let rad = unit * factor
            p.addEllipse(in: CGRect(x: c.x - rad, y: c.y - rad, width: rad * 2, height: rad * 2))
        }
    }

    private func waves(_ p: inout Path, in r: CGRect, step: CGFloat) {
        var y = r.minY + step / 2
        let amp = step / 3
        while y < r.maxY {
            p.move(to: CGPoint(x: r.minX, y: y))
            var x = r.minX
            var up = true
            while x < r.maxX {
                let next = min(x + step, r.maxX)
                p.addQuadCurve(
                    to: CGPoint(x: next, y: y),
                    control: CGPoint(x: (x + next) / 2, y: y + (up ? -amp : amp))
                )
                x = next
                up.toggle()
            }
            y += step
        }
    }
}

// MARK: - Uygulama

extension View {
    /// Renk taşıyan bir yüzeye mood desenini bindirir.
    ///
    /// Yalnız **Differentiate Without Color** açıkken çizer. Kapalıyken
    /// hiçbir maliyet yok, hiçbir görsel değişiklik yok.
    ///
    /// - Parameters:
    ///   - mood: yüzeyin taşıdığı duygu; `nil` ise (boş gün) desen çizilmez.
    ///   - lineWidth: ince yüzeylerde (6pt şerit) 0.8, kare hücrede 1.
    func moodPattern(_ mood: V3Mood?, lineWidth: CGFloat = 1) -> some View {
        modifier(MoodPatternModifier(mood: mood, lineWidth: lineWidth))
    }
}

private struct MoodPatternModifier: ViewModifier {
    let mood: V3Mood?
    let lineWidth: CGFloat
    @Environment(\.accessibilityDifferentiateWithoutColor) private var differentiate

    func body(content: Content) -> some View {
        content.overlay {
            if differentiate, let mood {
                V3MoodPattern(mood: mood)
                    .stroke(mood.ink.opacity(0.55), lineWidth: lineWidth)
                    .allowsHitTesting(false)
            }
        }
    }
}

#if DEBUG
#Preview("Desenler") {
    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: V3Tokens.spacingSM), count: 3), spacing: V3Tokens.spacingSM) {
        ForEach(V3Mood.allCases) { mood in
            RoundedRectangle(cornerRadius: V3Tokens.radiusTile, style: .continuous)
                .fill(mood.color)
                .aspectRatio(1, contentMode: .fit)
                .overlay {
                    V3MoodPattern(mood: mood).stroke(mood.ink.opacity(0.55), lineWidth: 1)
                }
                .overlay(alignment: .bottomLeading) {
                    Text(mood.label).font(.caption).foregroundColor(mood.ink).padding(V3Tokens.spacingSM)
                }
        }
    }
    .padding(V3Tokens.spacingXL2)
}
#endif
