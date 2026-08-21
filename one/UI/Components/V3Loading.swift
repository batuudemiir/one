//
//  V3Loading.swift
//  one
//
//  Uygulamanın tek "bekleme" dili.
//
//  Neden: 26 ayrı yerde çıplak `ProgressView()` vardı ve her biri kendi
//  ölçeğini uyduruyordu — `scaleEffect(0.65)`, `(0.7)`, `(0.75)`, `(0.8)`,
//  `(1.2)`, `controlSize(.small)`, kimi `.tint(.white)`, kimi tintsiz. Aynı
//  akışın iki adımında iki farklı boyutta çark dönüyordu.
//
//  Üç rol var, çünkü bekleme üç farklı yerde oluyor ve üçünün de kısıtı
//  farklı:
//
//    .inline  — bir düğmenin ya da satırın içinde, eylem sürerken. Metnin
//               yerini almalı, satır yüksekliğini oynatmamalı.
//    .region  — bir liste/bölüm henüz doluyor. Ortalanır, kendi nefes
//               alanı vardır.
//    .media   — fotoğraf ya da koyu zemin üstünde. Açık tinte ihtiyacı var;
//               `ink` orada kaybolur.
//

import SwiftUI

enum V3LoadingRole {
    /// Düğme / satır içi — metnin yerini alır.
    case inline
    /// Liste veya bölüm dolarken — ortalanmış, boşluklu.
    case region
    /// Fotoğraf / koyu zemin üstü.
    case media
}

struct V3Loading: View {
    var role: V3LoadingRole = .region
    /// VoiceOver etiketi. Varsayılan "Yükleniyor" katalogdan geliyor;
    /// bağlam taşıyan bir metin verilebilir ("Arkadaşlar yükleniyor").
    var label: String?

    init(_ role: V3LoadingRole = .region, label: String? = nil) {
        self.role = role
        self.label = label
    }

    private var tint: Color {
        switch role {
        case .inline, .region: return V3Tokens.mutedText
        case .media:           return V3Tokens.darkText
        }
    }

    var body: some View {
        Group {
            switch role {
            case .inline, .media:
                ProgressView()
                    .controlSize(.small)
            case .region:
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, V3Tokens.spacingXL3)
            }
        }
        .tint(tint)
        .accessibilityLabel(label ?? NSLocalizedString("general.loading", comment: ""))
    }
}

// MARK: - Skeleton parıltısı

private struct V3ShimmerModifier: ViewModifier {
    let cornerRadius: CGFloat
    @State private var phase: CGFloat = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .overlay(
                LinearGradient(
                    colors: [.clear, V3Tokens.surface.opacity(0.4), .clear],
                    startPoint: .init(x: phase - 0.5, y: 0.5),
                    endPoint: .init(x: phase + 0.5, y: 0.5)
                )
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            )
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                    phase = 1.5
                }
            }
    }
}

extension View {
    /// İskelet kart parıltısı. Yarıçapı çağıran veriyor çünkü iskelet
    /// altındaki gerçek kartın köşesini taklit etmeli.
    ///
    /// Reduce Motion açıkken parıltı hiç başlamıyor — sonsuz tekrar eden
    /// yatay hareket tam da o ayarın kapattığı şey.
    func v3Shimmer(cornerRadius: CGFloat = V3Tokens.radiusPanel) -> some View {
        modifier(V3ShimmerModifier(cornerRadius: cornerRadius))
    }
}

#Preview("Roller") {
    VStack(spacing: V3Tokens.spacingXL2) {
        V3Loading(.region)
        HStack { Text("Kaydediliyor"); V3Loading(.inline) }
        ZStack {
            V3Tokens.darkGround
            V3Loading(.media)
        }
        .frame(height: 80)
        .clipShape(RoundedRectangle(cornerRadius: V3Tokens.radiusCard))
    }
    .padding()
    .background(V3Tokens.paper)
}
