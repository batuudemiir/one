//
//  QuoteShareCard.swift
//  ONE 2.0
//
//  Sözün paylaşım görseli (UX-7): 1080×1920 PNG, `ImageRenderer` ile.
//  Görsel yalnız paylaşım anında çizilir (`DataRepresentation`), kart
//  kaydırılırken değil. Dışa aktarılan yüzey olduğu için `V3Tokens.Export`
//  renkleri ve ölçeklenmeyen (`*Fixed`) yüzler kullanılır.
//

import SwiftUI
import UIKit
import UniformTypeIdentifiers

nonisolated struct QuoteShareCard: Transferable, Sendable {
    let text: String
    let attribution: String?

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .png) { card in
            try await card.renderPNG()
        }
    }

    @MainActor
    func renderPNG() throws -> Data {
        let renderer = ImageRenderer(content: QuoteShareImage(text: text, attribution: attribution))
        renderer.scale = 1
        guard let data = renderer.uiImage?.pngData() else { throw CocoaError(.fileWriteUnknown) }
        return data
    }
}

struct QuoteShareImage: View {
    static let size = CGSize(width: 1080, height: 1920)

    let text: String
    let attribution: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 48) {
            Spacer(minLength: 0)
            Image(systemName: "quote.opening")
                .font(V3Typography.quoteFixed(72))
                .foregroundColor(V3Tokens.Export.onDarkMuted)
            Text(text)
                .font(V3Typography.quoteFixed(text.count > 140 ? 64 : 80))
                .foregroundColor(V3Tokens.Export.onDark)
                .lineSpacing(18)
                .minimumScaleFactor(0.5)
            if let attribution {
                Text(attribution)
                    .font(V3Typography.monoFixed(32))
                    .foregroundColor(V3Tokens.Export.onDarkMuted)
            }
            Spacer(minLength: 0)
            Text(verbatim: "ONE")
                .font(V3Typography.displayFixed(44))
                .foregroundColor(V3Tokens.Export.onDark)
        }
        .padding(.horizontal, 112)
        .padding(.vertical, 160)
        .frame(width: Self.size.width, height: Self.size.height, alignment: .leading)
        .background(V3Tokens.Export.ground)
    }
}
