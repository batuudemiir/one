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

    /// Bu sürümde gerçekten değişenler.
    ///
    /// Eski liste bayat kalmakla kalmıyor, artık **var olmayan** şeyleri
    /// anlatıyordu: "16 Şarkı Önerisi" (öneri bloğu ritüelden kaldırıldı),
    /// "Gelişmiş Kamera" (foto artık ritüelin adımı değil), "Kayıt
    /// Kutlaması" (beş varyant tek imzayla değiştirildi). Yeniliklerde
    /// olmayan bir özelliği vaat etmek en pahalı hata türü.
    private let features: [WhatsNewFeature] = [
        .init(
            icon: "dot.radiowaves.left.and.right",
            color: Color(hex: "#26A69A"),
            title: "Çevre artık açılışta",
            body: "Uygulamayı açtığında önce arkadaşlarının\nbugünkü rengini görüyorsun."
        ),
        .init(
            icon: "circle.hexagongrid.fill",
            color: Color(hex: "#E63946"),
            title: "İki adımda bitiyor",
            body: "Renk seç, şarkı seç, bırak.\nFotoğraf ve not artık isteğe bağlı."
        ),
        .init(
            icon: "chart.dots.scatter",
            color: Color(hex: "#5B8DEF"),
            title: "Haftalık ritim",
            body: "Hedef her gün değil, haftada dört gün.\nKaçırdığın günü sonradan doldurabilirsin."
        ),
        .init(
            icon: "waveform.circle.fill",
            color: Color(hex: "#7C5CBF"),
            title: "Yeni kayıt anı",
            body: "Rengini bıraktığında ekran\nbir dalgayla karşılık veriyor."
        ),
        .init(
            icon: "square.grid.3x3.fill",
            color: Color(hex: "#F4A228"),
            title: "Arşiv mozaiği",
            body: "Aylar tek akışta, renk renk.\nGeçen yıl bugün ne hissettiğini de görüyorsun."
        ),
        .init(
            icon: "flag.fill",
            color: Color(hex: "#4CAF82"),
            title: "Kilometre taşları",
            body: "Neyi açtığını ve sırada ne olduğunu\nprofilinden görebilirsin."
        ),
    ]

    private var isLastPage: Bool { currentPage == features.count - 1 }

    var body: some View {
        VStack(spacing: 0) {
            // Progress dots
            HStack(spacing: 6) {
                ForEach(features.indices, id: \.self) { i in
                    Capsule()
                        .fill(i <= currentPage ? V3Tokens.ink : V3Tokens.wash)
                        .frame(width: i == currentPage ? 20 : 6, height: 6)
                        .animation(ONEAnimation.micro, value: currentPage)
                }
            }
            .padding(.top, V3Tokens.spacingXL)
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
                    .foregroundStyle(isLastPage ? ONEBrand.bone : .white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, V3Tokens.spacingLG)
                    .background(
                        isLastPage
                            ? AnyShapeStyle(LinearGradient(
                                colors: [ONEBrand.kor, ONEBrand.korLight],
                                startPoint: .leading, endPoint: .trailing))
                            : AnyShapeStyle(V3Tokens.ink),
                        in: Capsule()
                    )
                    .animation(.easeInOut(duration: 0.2), value: isLastPage)
            }
            .padding(.horizontal, V3Tokens.spacingXL3)
            .padding(.bottom, V3Tokens.spacingXL5)
            .opacity(contentVisible ? 1 : 0)
            .offset(y: contentVisible ? 0 : 20)
            .animation(
                reduceMotion ? .easeOut(duration: 0.15) :
                    ONEAnimation.panelSpring.delay(0.35),
                value: contentVisible
            )
        }
        .background(V3Tokens.paper.ignoresSafeArea())
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
                    ONEAnimation.cardSpring
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
            .padding(.bottom, V3Tokens.spacingXL3)

            // Text
            VStack(spacing: V3Tokens.spacingMD) {
                Text(feature.title)
                    .displayMD()
                    .foregroundStyle(V3Tokens.ink)
                    .multilineTextAlignment(.center)

                Text(feature.body)
                    .bodyLG()
                    .foregroundStyle(V3Tokens.mutedText)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }
            .opacity(textOpacity)
            .offset(y: textOffset)
        }
        .padding(.horizontal, V3Tokens.spacingXL4)
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
        withAnimation(ONEAnimation.panelSpring.delay(0.18)) {
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
