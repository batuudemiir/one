//
//  ResurfaceCard.swift
//  ONE 2.0
//
//  Geri dönüş kartı (07 §5.11): hafta şeridinin altında, günde en fazla
//  bir. Mono etiket ("BİR YIL ÖNCE BUGÜN" / "30 GÜN ÖNCE"), eski metnin ilk
//  iki satırı (Literata), eylemler: `Tekrar yaz` (karşılaştırma modu) ·
//  `Oku` · × (bugün için gizle). `Tekrar yaz` ikincil: ekranın birincil
//  eylemi ritüel kartında.
//

import SwiftUI

struct ResurfaceCard: View {
    let data: ResurfaceCardData
    let onRewrite: () -> Void
    let onRead: () -> Void
    let onDismiss: () -> Void

    private var label: String {
        switch data.kind {
        case .yearAgo:
            return one2String("one2.resurface.yearAgo")
        case .questionAgain(let days), .quoteReturn(let days):
            return String(format: one2String("one2.resurface.daysAgo"), days)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: ONE2Space.s3) {
            HStack(alignment: .center, spacing: ONE2Space.s3) {
                ONE2Label(label)
                    .frame(maxWidth: .infinity, alignment: .leading)
                ONE2RoundButton(icon: .close, accessibilityLabel: one2String("one2.resurface.hide"), filled: false, action: onDismiss)
            }
            Text(data.excerpt)
                .one2Type(.journal)
                .foregroundStyle(ONE2Color.ink)
                .lineLimit(2)
            HStack(spacing: ONE2Space.s2) {
                Button(action: onRewrite) {
                    Text(one2String("one2.resurface.rewrite")).contentShape(Rectangle())
                }
                .buttonStyle(.one2(.secondary, size: .compact))
                Button(action: onRead) {
                    Text(one2String("one2.resurface.read")).contentShape(Rectangle())
                }
                .buttonStyle(.one2(.text, size: .compact))
            }
        }
        .padding(.leading, ONE2Space.s5)
        .padding([.trailing, .top], ONE2Space.s2)
        .padding(.bottom, ONE2Space.s5)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(ONE2Color.surface, in: ONE2Radius.shape(ONE2Radius.lg))
    }
}

#if DEBUG
private struct ResurfaceCardSamples: View {
    var body: some View {
        VStack(spacing: ONE2Space.s5) {
            ResurfaceCard(data: TodayFixture.resurfaceYearAgo, onRewrite: {}, onRead: {}, onDismiss: {})
            ResurfaceCard(data: TodayFixture.resurfaceQuestion, onRewrite: {}, onRead: {}, onDismiss: {})
        }
    }
}

#Preview("Gece") { ResurfaceCardSamples().one2Preview(.gece) }
#Preview("Gün") { ResurfaceCardSamples().one2Preview(.gun) }
#Preview("AX3") { ResurfaceCardSamples().one2Preview(.ax3) }
#endif
