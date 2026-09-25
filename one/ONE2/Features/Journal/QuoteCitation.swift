//
//  QuoteCitation.swift
//  ONE 2.0
//
//  Söz künyesi (07 §5.4, components/QuoteReflection.md): `raised` kutu,
//  Literata italik söz, mono "DÜŞÜNÜR · ESER". Yazarken tek satıra küçülür
//  (`compact`, 280 ms; Reduce Motion'da anında).
//

import SwiftUI

struct QuoteCitation: View {
    let quote: Quote
    var compact = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: ONE2Space.s2) {
            Text(quote.text)
                .one2Type(compact ? .journal : .prompt)
                .italic()
                .foregroundStyle(ONE2Color.ink)
                .lineLimit(compact ? 1 : nil)
                .fixedSize(horizontal: false, vertical: !compact)
            if !compact, let citation = quote.citation {
                ONE2Label(citation)
            }
        }
        .padding(compact ? ONE2Space.s3 : ONE2Space.s5)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(ONE2Color.raised, in: ONE2Radius.shape(ONE2Radius.md))
        .animation(ONE2Motion.animation(.screen, reduceMotion: reduceMotion), value: compact)
        .accessibilityElement(children: .combine)
    }
}
