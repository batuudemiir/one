//
//  PaywallView.swift
//  one
//

import SwiftUI

struct PaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var premium = PremiumManager.shared

    private let features: [(icon: String, title: String, detail: String)] = [
        ("plus.square.on.square", "Birden fazla kayıt", "Günde istediğin kadar müzik ekle"),
        ("music.note.list",        "Haftalık çalma listesi", "Ruh halinden otomatik playlist"),
        ("calendar.badge.clock",   "Aylık özet",             "Duygusal harita ve istatistikler"),
        ("rectangle.3.group",      "Premium widget'lar",     "Kilit ekranında mood göstergesi"),
    ]

    var body: some View {
        ZStack(alignment: .topTrailing) {
            ONETokens.oneCream
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    // Hero
                    VStack(spacing: 8) {
                        HStack(spacing: 0) {
                            Text("ONE")
                                .displayHero()
                                .foregroundColor(ONETokens.oneVoid)
                            Text("+")
                                .displayHero()
                                .foregroundColor(ONEBrand.kor)
                        }

                        Text("Hissetmeyi derinleştir")
                            .bodyLG()
                            .foregroundColor(V3Tokens.mutedText)
                    }
                    .padding(.top, 56)
                    .padding(.bottom, 40)
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("ONE+ — Hissetmeyi derinleştir")

                    // Feature list
                    VStack(spacing: 0) {
                        ForEach(features, id: \.title) { feature in
                            FeatureRow(icon: feature.icon, title: feature.title, detail: feature.detail)
                            if feature.title != features.last?.title {
                                Divider()
                                    .background(V3Tokens.mutedText.opacity(0.15))
                                    .padding(.leading, 52)
                            }
                        }
                    }
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.white.opacity(0.6))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(V3Tokens.mutedText.opacity(0.2), lineWidth: 1)
                            )
                    )
                    .padding(.horizontal, 20)

                    // Price badge
                    Text("Yakında geliyor")
                        .font(ONETypography.monoLabel)
                        .foregroundColor(V3Tokens.mutedText)
                        .padding(.vertical, 6)
                        .padding(.horizontal, 14)
                        .background(
                            Capsule()
                                .stroke(V3Tokens.mutedText.opacity(0.3), lineWidth: 1)
                        )
                        .padding(.top, 24)
                        .accessibilityLabel("Fiyatlandırma yakında açıklanacak")

                    // CTA
                    Button {
                        // premium aktif değil — tap no-op
                    } label: {
                        Text("ONE+ Başla")
                            .bodyLG()
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(ONEBrand.kor.opacity(0.45))
                            )
                    }
                    .disabled(true)
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    .accessibilityLabel("ONE+ aboneliği başlat — yakında geliyor")
                    .accessibilityHint("Premium özellikler henüz aktif değil")

                    // Restore / legal
                    Button("Satın alımları geri yükle") { }
                        .font(ONETypography.monoMicro)
                        .foregroundColor(V3Tokens.mutedText.opacity(0.6))
                        .disabled(true)
                        .padding(.top, 12)
                        .accessibilityLabel("Önceki satın alımları geri yükle — yakında geliyor")

                    Spacer(minLength: 40)
                }
            }

            // Dismiss
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(V3Tokens.mutedText)
                    .frame(width: 32, height: 32)
                    .background(
                        Circle()
                            .stroke(V3Tokens.mutedText.opacity(0.3), lineWidth: 1)
                            .background(Circle().fill(Color.white.opacity(0.6)))
                    )
            }
            .padding(.top, 16)
            .padding(.trailing, 20)
            .accessibilityLabel("Kapat")
            .accessibilityHint("Ödeme ekranını kapat")
        }
    }
}

private struct FeatureRow: View {
    let icon: String
    let title: String
    let detail: String

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(ONEBrand.kor)
                .frame(width: 36, height: 36)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(ONETypography.bodyMD)
                    .fontWeight(.medium)
                    .foregroundColor(ONETokens.oneVoid)
                Text(detail)
                    .font(ONETypography.bodyXS)
                    .foregroundColor(V3Tokens.mutedText)
            }
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title): \(detail)")
    }
}

#Preview {
    PaywallView()
}
