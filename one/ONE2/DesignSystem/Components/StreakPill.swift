//
//  StreakPill.swift
//  ONE 2.0
//
//  Bugün üst çubuğunun seri hapı (07 §4.1): alev ikonu yok; `brand`
//  renkli mono sayı + "gün", `raised` hap. Yalnız gösterge; dokunma eylemi
//  yok (işlevsiz kontrol olmasın diye buton değil). Seri gizliyse ya da ilk
//  günse ekran hapı hiç çizmez.
//

import SwiftUI

struct StreakPill: View {
    let count: Int

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: ONE2Space.s1) {
            Text(verbatim: "\(count)")
                .one2Type(.time)
                .foregroundStyle(ONE2Color.brand)
            Text(one2String("one2.today.streak.unit"))
                .one2Type(.callout)
                .foregroundStyle(ONE2Color.ink)
        }
        .lineLimit(1)
        .padding(.horizontal, ONE2Size.pillPadding)
        .frame(minHeight: ONE2Size.control)
        .background(ONE2Color.raised, in: Capsule())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(String(format: one2String("one2.today.streak.a11y"), count)))
    }
}

#if DEBUG
private struct StreakPillSamples: View {
    var body: some View {
        HStack(spacing: ONE2Space.s3) {
            StreakPill(count: 0)
            StreakPill(count: 12)
            StreakPill(count: 365)
        }
    }
}

#Preview("Gece") { StreakPillSamples().one2Preview(.gece) }
#Preview("Gün") { StreakPillSamples().one2Preview(.gun) }
#Preview("AX3") { StreakPillSamples().one2Preview(.ax3) }
#endif
