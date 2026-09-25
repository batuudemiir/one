//
//  QuoteCitation.swift
//  ONE 2.0
//
//  Söz künyesi (QuoteReflection.md): serif italik söz + mono kaynak, kuyu
//  zemininde. Yazarken tek satıra küçülür. Söze yazı ekranı, önceki yazı
//  ve girdi detayı aynı künyeyi kullanır.
//

import SwiftUI

struct QuoteCitation: View {
    let quote: Quote
    var compact = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: V3Tokens.spacingXS) {
            Text(quote.text)
                .font(V3Typography.quote(compact ? 15 : 18))
                .italic()
                .foregroundColor(V3Tokens.ink)
                .lineLimit(compact ? 1 : nil)
                .fixedSize(horizontal: false, vertical: !compact)
            if !compact, let attribution = quote.citation {
                Text(attribution)
                    .monoSM()
                    .foregroundColor(V3Tokens.mutedText)
            }
        }
        .padding(compact ? V3Tokens.spacingMD : V3Tokens.spacingLG)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: V3Tokens.radiusPanel, style: .continuous)
                .fill(V3Tokens.wash)
        )
        .animation(reduceMotion ? nil : ONEAnimation.easing, value: compact)
        .accessibilityElement(children: .combine)
    }
}
