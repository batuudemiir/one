//
//  OfflineBanner.swift
//  ONE 2.0
//
//  Çevrimdışı durumu (components/States.md, `.o-banner`): üstte raised hap
//  şerit + `warning` ikon + tek cümle. Kontrol değil, bilgi.
//

import SwiftUI

struct OfflineBanner: View {
    var message: String = one2String("one2.state.offline")

    var body: some View {
        HStack(spacing: ONE2Space.s2) {
            ONE2Icon.offline.image(size: ONE2Size.iconSmall)
                .foregroundStyle(ONE2Color.warning)
                .accessibilityHidden(true)
            Text(message)
                .one2Type(.callout)
                .foregroundStyle(ONE2Color.ink)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, ONE2Space.s4)
        .padding(.vertical, ONE2Space.s3)
        .background(ONE2Color.raised, in: Capsule())
        .accessibilityElement(children: .combine)
    }
}

#if DEBUG
#Preview("Gece") { OfflineBanner().one2Preview(.gece) }
#Preview("Gün") { OfflineBanner().one2Preview(.gun) }
#Preview("AX3") { OfflineBanner().one2Preview(.ax3) }
#endif
