//
//  WhatsNewView.swift
//  one
//

import SwiftUI

struct WhatsNewView: View {
    let onDismiss: () -> Void

    @State private var currentPage = 0
    @State private var contentVisible = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let features: [WhatsNewFeature] = [
        .init(
            icon: "bubble.left.and.bubble.right.fill",
            color: Color(hex: "#5B8DEF"),
            title: "Yorum Sistemi",
            body: "Arkadaşlarının paylaşımlarına yorum yap.\nAnı birlikte hisset."
        ),
        .init(
            icon: "bell.badge.fill",
            color: Color(hex: "#E63946"),
            title: "Akıllı Bildirimler",
            body: "Yorum, beğeni ve çevre etkileşimlerini\nanında gör."
        ),
        .init(
            icon: "camera.fill",
            color: Color(hex: "#4CAF82"),
            title: "Gelişmiş Kamera",
            body: "Daha hızlı, daha temiz fotoğraf deneyimi.\nYeni filtreler."
        ),
        .init(
            icon: "music.note.list",
            color: Color(hex: "#7C5CBF"),
            title: "16 Şarkı Önerisi",
            body: "Bugün için 16 kişisel öneri.\nHer gün sıfırdan yenilenir."
        ),
        .init(
            icon: "sparkles",
            color: Color(hex: "#F4A228"),
            title: "Kayıt Kutlaması",
            body: "Mood'unu kaydettiğinde seni\nözel bir an karşılıyor."
        ),
        .init(
            icon: "play.circle.fill",
            color: Color(hex: "#E63946"),
            title: "Şarkı Önizleme",
            body: "Şarkı seçiminde ve arkadaş paylaşımlarında\ndokunarak dinle."
        ),
    ]

    private var isLastPage: Bool { currentPage == features.count - 1 }

    var body: some View {
        VStack(spacing: 0) {
            // Progress dots
            HStack(spacing: 6) {
                ForEach(features.indices, id: \.self) { i in
                    Capsule()
                        .fill(i <= currentPage ? ONETokens.oneInk : ONETokens.oneCreamLow)
                        .frame(width: i == currentPage ? 20 : 6, height: 6)
                        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: currentPage)
                }
            }
            .padding(.top, 20)
            .padding(.bottom, 0)

            Spacer()

            // Feature card — cross-fade between pages
            FeaturePage(feature: features[currentPage], visible: contentVisible)
                .id(currentPage)
                .transition(
                    reduceMotion ? .opacity :
                        .asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .move(edge: .leading).combined(with: .opacity)
                        )
                )

            Spacer()

            // CTA button
            Button(action: advance) {
                Text(isLastPage ? "Harika!" : "İlerle")
                    .monoBase()
                    .foregroundStyle(isLastPage ? ONETokens.oneCream : .white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        isLastPage
                            ? AnyShapeStyle(LinearGradient(
                                colors: [ONETokens.oneBrand, ONETokens.oneBrandLight],
                                startPoint: .leading, endPoint: .trailing))
                            : AnyShapeStyle(ONETokens.oneInk),
                        in: Capsule()
                    )
                    .animation(.easeInOut(duration: 0.2), value: isLastPage)
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 52)
            .opacity(contentVisible ? 1 : 0)
            .offset(y: contentVisible ? 0 : 20)
            .animation(
                reduceMotion ? .easeOut(duration: 0.15) :
                    .spring(response: 0.5, dampingFraction: 0.78).delay(0.35),
                value: contentVisible
            )
        }
        .background(ONETokens.oneCream.ignoresSafeArea())
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                withAnimation { contentVisible = true }
                ONEHaptics.moodSelected()
            }
        }
    }

    private func advance() {
        if isLastPage {
            ONEHaptics.friendConnected()
            onDismiss()
        } else {
            ONEHaptics.feelingSelected()
            withAnimation(
                reduceMotion ? .easeInOut(duration: 0.2) :
                    .spring(response: 0.48, dampingFraction: 0.82)
            ) {
                currentPage += 1
            }
        }
    }
}

// MARK: - Feature Page

private struct FeaturePage: View {
    let feature: WhatsNewFeature
    let visible: Bool

    @State private var iconScale: CGFloat = 0.5
    @State private var iconOpacity: Double = 0
    @State private var textOpacity: Double = 0
    @State private var textOffset: CGFloat = 16
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 0) {
            // Icon
            ZStack {
                Circle()
                    .fill(feature.color.opacity(0.12))
                    .frame(width: 120, height: 120)

                Circle()
                    .strokeBorder(feature.color.opacity(0.2), lineWidth: 1.5)
                    .frame(width: 120, height: 120)

                Image(systemName: feature.icon)
                    .font(.system(size: 44, weight: .medium))
                    .foregroundStyle(feature.color)
            }
            .scaleEffect(iconScale)
            .opacity(iconOpacity)
            .padding(.bottom, 36)

            // Text
            VStack(spacing: 12) {
                Text(feature.title)
                    .displayMD()
                    .foregroundStyle(ONETokens.oneInk)
                    .multilineTextAlignment(.center)

                Text(feature.body)
                    .bodyLG()
                    .foregroundStyle(ONETokens.oneAsh)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }
            .opacity(textOpacity)
            .offset(y: textOffset)
        }
        .padding(.horizontal, 40)
        .onAppear { animateIn() }
    }

    private func animateIn() {
        if reduceMotion {
            iconScale = 1; iconOpacity = 1; textOpacity = 1; textOffset = 0
            return
        }
        withAnimation(.spring(response: 0.5, dampingFraction: 0.62).delay(0.05)) {
            iconScale = 1
            iconOpacity = 1
        }
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.18)) {
            textOpacity = 1
            textOffset = 0
        }
    }
}

// MARK: - Model

private struct WhatsNewFeature {
    let icon: String
    let color: Color
    let title: String
    let body: String
}

#Preview {
    WhatsNewView(onDismiss: {})
        .preferredColorScheme(.light)
}
