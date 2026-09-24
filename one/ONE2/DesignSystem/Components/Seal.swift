//
//  Seal.swift
//  ONE 2.0
//
//  Ritüel kapanışı (components/Seal.md, 07 §5.5): 96pt `brand` disk + tik,
//  dışında `ground` boşluk ve ince `brand` halka; yarım mühürde disk yarı
//  dolu. Küçük harf başlık, altında Literata italik özet. Hareket: disk
//  0.9 → 1.0 + opaklık, 320 ms, tek sefer; `soft` haptik. Reduce Motion'da
//  yalnız opaklık. Konfeti, ses, "Harika!" yok.
//  Hafta şeridi, rozet ve seri kilometre taşı satırları UX-6'da.
//

import SwiftUI

struct Seal: View {
    let title: String
    var summary: String? = nil
    /// Sabah akışı: "gün hazır." yarım mühür.
    var isHalf = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false

    var body: some View {
        VStack(spacing: ONE2Space.s6) {
            disk
                .scaleEffect(appeared || reduceMotion ? 1 : ONE2Motion.sealStartScale)
                .opacity(appeared ? 1 : 0)
                .accessibilityHidden(true)
            VStack(spacing: ONE2Space.s3) {
                Text(title)
                    .one2Type(.greeting)
                    .foregroundStyle(ONE2Color.ink)
                    .accessibilityAddTraits(.isHeader)
                if let summary {
                    Text(summary)
                        .one2Type(.affirmation)
                        .foregroundStyle(ONE2Color.inkMuted)
                }
            }
            .multilineTextAlignment(.center)
        }
        .onAppear {
            ONE2Haptics.soft()
            withAnimation(ONE2Motion.animation(.seal, reduceMotion: reduceMotion)) { appeared = true }
        }
    }

    private var disk: some View {
        ZStack {
            Circle().strokeBorder(ONE2Color.brand, lineWidth: ONE2Size.hairline)
            Group {
                if isHalf {
                    Circle().fill(ONE2Color.brand)
                        .mask(alignment: .leading) { Rectangle().frame(width: ONE2Size.sealDisc / 2) }
                    Circle().strokeBorder(ONE2Color.brand, lineWidth: ONE2Size.focusRing)
                } else {
                    Circle().fill(ONE2Color.brand)
                    ONE2Icon.check.image(size: ONE2Size.iconLarge)
                        .fontWeight(.semibold)
                        .foregroundStyle(ONE2Color.onBrand)
                }
            }
            .padding(2 * ONE2Size.focusRing)
        }
        .frame(width: ONE2Size.sealDisc, height: ONE2Size.sealDisc)
    }
}

#if DEBUG
private struct SealSamples: View {
    var body: some View {
        VStack(spacing: ONE2Space.s10) {
            Seal(title: "bugün kapandı.", summary: "Yarım kalan da bir şey söyler; bugün dinledin.")
            Seal(title: "gün hazır.", summary: "Sabır bugün senin kelimen.", isHalf: true)
        }
    }
}

#Preview("Gece") { SealSamples().one2Preview(.gece) }
#Preview("Gün") { SealSamples().one2Preview(.gun) }
#Preview("AX3") { SealSamples().one2Preview(.ax3) }
#endif
