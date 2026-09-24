//
//  QuoteCardView.swift
//  ONE 2.0
//
//  Sözler sekmesinin tam ekran kartı (QuoteCard.md, UX-7). Fotoğraf zemin
//  ve fırça seçici içerik gelince; şimdilik kart `surface` zeminde.
//  Alt çubuk: paylaş · "Bunun hakkında yaz" · beğen. Ortadaki yazma eylemi
//  kartın asıl amacı.
//

import Foundation
import SwiftUI

struct QuoteCardView: View {
    let item: QuoteFeedItem
    let onLike: () -> Void
    let onWrite: () -> Void
    let onShare: () -> Void

    private var quote: Quote { item.quote }

    var body: some View {
        VStack(alignment: .leading, spacing: V3Tokens.spacingLG) {
            header
            Spacer(minLength: 0)
            Text(quote.text)
                .font(V3Typography.quote(26))
                .foregroundColor(V3Tokens.ink)
                .lineSpacing(6)
                .minimumScaleFactor(0.6)
            if let attribution = quote.attribution {
                Text(attribution)
                    .monoSM()
                    .foregroundColor(V3Tokens.mutedText)
            }
            if item.writtenCount > 0 {
                Text(String.localizedStringWithFormat(
                    NSLocalizedString("one2.quotes.writtenCount", comment: "Badge: how many times the user wrote about this quote"),
                    item.writtenCount))
                    .bodySM()
                    .foregroundColor(V3Tokens.mutedText)
            }
            Spacer(minLength: 0)
            actionBar
        }
        .padding(V3Tokens.spacingXL2)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .oneCardBackground(radius: V3Tokens.radiusHero)
        .accessibilityElement(children: .contain)
    }

    // MARK: - Üst satır

    private var header: some View {
        HStack(spacing: V3Tokens.spacingSM) {
            Image(systemName: QuoteModeOptions.symbol(for: quote.kind))
                .iconSM()
                .foregroundColor(V3Tokens.mutedText)
                .accessibilityHidden(true)
            Text(headerLabel)
                .v3MicroLabel()
                .foregroundColor(V3Tokens.mutedText)
            Spacer(minLength: 0)
        }
    }

    private var headerLabel: String {
        switch item.reason {
        case .regular:
            return QuoteModeOptions.title(for: quote.kind)
        case .daily:
            return NSLocalizedString("one2.quotes.daily", comment: "Label on the quote of the day card")
        case .resurfaced(let writtenAt, _):
            return String(format: NSLocalizedString("one2.quotes.resurfaced", comment: "Label: you wrote about this quote on <date>"),
                          writtenAt.formatted(.dateTime.day().month(.wide)))
        }
    }

    // MARK: - Alt çubuk

    private var actionBar: some View {
        HStack(spacing: V3Tokens.spacingMD) {
            ShareLink(item: QuoteShareCard(text: quote.text, attribution: quote.attribution),
                      preview: SharePreview(quote.text)) {
                icon("square.and.arrow.up")
            }
            .buttonStyle(.onePressable)
            .simultaneousGesture(TapGesture().onEnded { onShare() })
            .accessibilityLabel(NSLocalizedString("one2.quotes.share", comment: "Share quote"))

            Spacer(minLength: 0)

            Button(action: onWrite) {
                Text(NSLocalizedString("one2.quotes.write", comment: "Write about this quote"))
                    .bodyMDSemibold()
                    .foregroundColor(V3Tokens.paper)
                    .padding(.horizontal, V3Tokens.spacingXL)
                    .frame(minHeight: V3Tokens.minTouchTarget)
                    .background(Capsule(style: .continuous).fill(V3Tokens.ink))
                    .contentShape(Rectangle())
            }
            .buttonStyle(.onePressable)

            Spacer(minLength: 0)

            Button {
                ONEHaptics.pick()
                onLike()
            } label: {
                icon(item.liked ? "heart.fill" : "heart")
            }
            .buttonStyle(.onePressable)
            .accessibilityLabel(item.liked
                                ? NSLocalizedString("one2.quotes.unlike", comment: "Remove like from quote")
                                : NSLocalizedString("one2.quotes.like", comment: "Like quote"))
        }
    }

    private func icon(_ systemName: String) -> some View {
        Image(systemName: systemName)
            .iconMD()
            .foregroundColor(V3Tokens.ink)
            .frame(width: V3Tokens.minTouchTarget, height: V3Tokens.minTouchTarget)
            .contentShape(Rectangle())
    }
}
