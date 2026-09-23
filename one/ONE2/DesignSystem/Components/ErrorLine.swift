//
//  ErrorLine.swift
//  ONE 2.0
//
//  Hata durumu (components/States.md): `danger` kelime + ne yapılacağı.
//  Yeniden deneme isteğe bağlı text buton; varsa gerçekten bir şey yapar.
//

import SwiftUI

struct ErrorLine: View {
    /// Kısa, `danger` renkli kelime ("Kaydedilemedi.").
    let title: String
    /// Ne yapılacağı ("Bağlantını kontrol et, sonra yeniden dene.").
    let message: String
    var retry: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: ONE2Space.s1) {
            Text("\(Text(title).foregroundStyle(ONE2Color.danger)) \(Text(message).foregroundStyle(ONE2Color.inkMuted))")
                .one2Type(.bodySm)
            if let retry {
                Button(action: retry) {
                    Text(one2String("one2.action.retry")).contentShape(Rectangle())
                }
                .buttonStyle(.one2(.text, size: .compact))
            }
        }
    }
}

#if DEBUG
private struct ErrorLineSamples: View {
    var body: some View {
        VStack(alignment: .leading, spacing: ONE2Space.s5) {
            ErrorLine(title: "Kaydedilemedi.", message: "Bağlantını kontrol et, sonra yeniden dene.") {}
            ErrorLine(title: "Yüklenemedi.", message: "Birazdan kendiliğinden yeniden denenecek.")
        }
    }
}

#Preview("Gece") { ErrorLineSamples().one2Preview(.gece) }
#Preview("Gün") { ErrorLineSamples().one2Preview(.gun) }
#Preview("AX3") { ErrorLineSamples().one2Preview(.ax3) }
#endif
