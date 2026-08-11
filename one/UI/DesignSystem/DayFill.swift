//
//  DayFill.swift
//  one
//
//  Tek `dayFill` yardımcısı — mozaik, yıl, widget, hafta şeridi, poster.
//  Talimat: "her yerde aynı fonksiyondan gelmeli — kopyalama."
//
//  Kural (prototipten):
//  - Boş gün: şeffaf zemin + 1.5pt kesikli çerçeve.
//  - 1 an: düz renk.
//  - 2+ an: 135° linear gradient, sert renk durakları
//    (i/n%..((i+1)/n)% aralığında renk[i]).
//

import SwiftUI

/// Bir gün için mozaik/widget kare dolgusu.
struct DayFill: View {
    /// v3 mood hex'leri, an sırasına göre (`Day.fillHexes`).
    /// Legacy (v2 12-mood) hex'leri otomatik olarak v3 palette'ine köprülenir.
    let hexes: [String]
    /// Karenin köşe yuvarlaması. Mozaikte 9, yıl mini'sinde 2, widget 5, poster 4.
    var cornerRadius: CGFloat = 9

    /// Rendera edilecek renkler — legacy hex'ler v3'e mapping'lenir.
    private var normalizedColors: [Color] {
        hexes.map { hex in
            if let v3 = V3Mood.fromHex(hex) {
                return v3.color
            }
            return Color(hex: hex)
        }
    }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        let colors = normalizedColors
        ZStack {
            switch colors.count {
            case 0:
                shape
                    .fill(Color.clear)
                    .overlay(
                        shape.strokeBorder(V3Tokens.hairline,
                                           style: StrokeStyle(lineWidth: 1.5, dash: [3, 3]))
                    )
            case 1:
                shape.fill(colors[0])
            default:
                shape.fill(
                    LinearGradient(stops: stops(colors: colors), startPoint: .topLeading, endPoint: .bottomTrailing)
                )
            }
        }
    }

    /// 135° gradient sert duraklarla: renk[i] = i/n → (i+1)/n aralığında sabit.
    /// Prototipin `linear-gradient(135deg, C0 0% 33%, C1 33% 66%, C2 66% 100%)` karşılığı.
    private func stops(colors: [Color]) -> [Gradient.Stop] {
        let n = Double(colors.count)
        return colors.enumerated().flatMap { i, color -> [Gradient.Stop] in
            [
                Gradient.Stop(color: color, location: Double(i) / n),
                Gradient.Stop(color: color, location: Double(i + 1) / n)
            ]
        }
    }
}

extension DayFill {
    /// Convenience: `Day` doğrudan geçilebilsin.
    init(day: Day, cornerRadius: CGFloat = 9) {
        self.hexes = day.fillHexes
        self.cornerRadius = cornerRadius
    }
}

#Preview {
    VStack(spacing: 16) {
        HStack(spacing: 8) {
            DayFill(hexes: []).frame(width: 46, height: 46)
            DayFill(hexes: ["#FF3B1F"]).frame(width: 46, height: 46)
            DayFill(hexes: ["#FF3B1F", "#00B58C"]).frame(width: 46, height: 46)
            DayFill(hexes: ["#FF3B1F", "#00B58C", "#2B4CF0"]).frame(width: 46, height: 46)
        }
        HStack(spacing: 4) {
            DayFill(hexes: ["#FF8A00", "#C8F135", "#5C6BC0", "#8B2FD6"], cornerRadius: 4)
                .frame(width: 24, height: 24)
        }
    }
    .padding(30)
    .background(ONEBrand.bone)
}
