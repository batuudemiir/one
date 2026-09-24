//
//  V3HandText.swift
//  one
//
//  El yazısı damgası — "Aug 17", "August", "21:14".
//
//  Neden ayrı bir view: bu öğenin iki kuralı var ve ikisi de her çağrı
//  yerinde tekrar edilmemeli.
//
//  **1. Her dilde İngilizce.** Damga çevrilmiyor. `CaveatBrush-Regular`
//  Kiril ve CJK taşımıyor (ölçüldü: Türkçe ve rakamlar tam, `ru/ja/ko/zh`
//  eksik), ama asıl sebep font değil: bu bir metin değil, fotoğrafa basılan
//  bir tarih damgası. Filmin kenarındaki tarih gibi — nerede olursan ol
//  aynı görünür.
//
//  **2. VoiceOver'dan gizli.** Türkçe bir arayüzde ekran okuyucunun "Aug
//  seventeen" demesi kırık bir deneyim. Damga `accessibilityHidden`;
//  okunacak tarih ekranın kendi label'ında, kullanıcının dilinde duruyor.
//  Bu yüzden damgayı çıplak `Text` olarak yazmak **yanlış** — bilgi
//  görsel olarak var ama ekran okuyucuda kayboluyor ya da yanlış dilde
//  okunuyor. Her zaman bu view, her zaman yanında yerelleştirilmiş karşılık.
//

import SwiftUI

struct V3HandText: View {
    /// Basılacak damga — `ONEFormatters.handDayMonth` / `.handMonth` /
    /// `.time` çıktısı.
    let text: String
    var size: CGFloat = 44
    var color: Color = V3Tokens.ink
    /// Sağa dayalı (kart damgası) ya da sola (başlık).
    var alignment: Alignment = .trailing

    var body: some View {
        Text(text)
            .font(V3Typography.hand(size))
            .foregroundColor(color)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .frame(maxWidth: .infinity, alignment: alignment)
            .accessibilityHidden(true)
    }
}

// MARK: - Kısayollar

extension V3HandText {
    /// "Aug 17" — gün seviyesi.
    static func day(
        _ date: Date,
        size: CGFloat = 44,
        color: Color = V3Tokens.ink,
        alignment: Alignment = .trailing
    ) -> V3HandText {
        V3HandText(
            text: ONEFormatters.handDayMonth.string(from: date),
            size: size,
            color: color,
            alignment: alignment
        )
    }

    /// "August" — ay seviyesi.
    static func month(
        _ date: Date,
        size: CGFloat = 44,
        color: Color = V3Tokens.ink,
        alignment: Alignment = .trailing
    ) -> V3HandText {
        V3HandText(
            text: ONEFormatters.handMonth.string(from: date),
            size: size,
            color: color,
            alignment: alignment
        )
    }

    /// "21:14" — an seviyesi. Saat rakam olduğu için her dilde güvenli;
    /// yine de damga kuralı aynı, VoiceOver'a bırakılmıyor.
    static func time(
        _ date: Date,
        size: CGFloat = 44,
        color: Color = V3Tokens.ink,
        alignment: Alignment = .trailing
    ) -> V3HandText {
        V3HandText(
            text: ONEFormatters.time.string(from: date),
            size: size,
            color: color,
            alignment: alignment
        )
    }
}

#Preview("Damga kademeleri") {
    VStack(alignment: .leading, spacing: V3Tokens.spacingXL2) {
        V3HandText.month(Date(), alignment: .leading)
        V3HandText.day(Date(), alignment: .leading)
        V3HandText.time(Date(), alignment: .leading)
    }
    .padding(V3Tokens.spacingXL3)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(V3Tokens.paper)
}
