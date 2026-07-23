//
//  SplashScreen.swift
//  one
//
//  Wabi-Sabi inspired splash screen
//

import SwiftUI

struct SplashScreen: View {
    @Binding var isActive: Bool

    // Her harf için ayrı durum — yukarıdan damgalanma efekti
    @State private var letterOffsets: [CGFloat] = [-50, -50, -50]
    @State private var letterOpacities: [Double] = [0, 0, 0]
    @State private var letterScales: [CGFloat] = [1.2, 1.2, 1.2]

    // 5 mood karesi — bouncy pop + idle dalga
    @State private var squareScales: [CGFloat] = [0.1, 0.1, 0.1, 0.1, 0.1]
    @State private var squareOpacities: [Double] = [0, 0, 0, 0, 0]
    @State private var squareOffsets: [CGFloat] = [0, 0, 0, 0, 0]

    // Slogan
    @State private var sloganOpacity: Double = 0

    // Figma renk sırası: kırmızı · turuncu · sarı · mavi · mor
    private let moodColors: [Color] = [
        ONETokens.oneRed,
        ONETokens.moodOrange,
        ONETokens.moodYellow,
        ONETokens.oneBlue,
        ONETokens.moodPurple
    ]

    private let letters = ["O", "N", "E"]

    var body: some View {
        ZStack {
            Color.white
                .ignoresSafeArea()

            VStack(spacing: ONETokens.spacingXL3) {

                // "ONE" — her harf bağımsız olarak yukarıdan damgalanır
                HStack(spacing: 2) {
                    ForEach(0..<3) { i in
                        Text(letters[i])
                            .font(.system(size: 96, weight: .bold, design: .default))
                            .foregroundColor(ONETokens.oneInk)
                            .scaleEffect(letterScales[i])
                            .offset(y: letterOffsets[i])
                            .opacity(letterOpacities[i])
                    }
                }

                // 5 ruh hali karesi — sıralı pop, sonra idle dalga
                HStack(spacing: ONETokens.spacingSM) {
                    ForEach(0..<5) { i in
                        RoundedRectangle(cornerRadius: ONETokens.radiusCard)
                            .fill(moodColors[i])
                            .frame(width: 52, height: 44)
                            .scaleEffect(squareScales[i])
                            .opacity(squareOpacities[i])
                            .offset(y: squareOffsets[i])
                    }
                }

                // Slogan — mood karelerinden sonra belirir
                Text(NSLocalizedString("splash.slogan", comment: ""))
                    .font(ONETypography.bodyMD)
                    .tracking(1.8)
                    .foregroundColor(ONETokens.oneAsh)
                    .opacity(sloganOpacity)
            }
        }
        .colorScheme(.light)
        .onAppear { startAnimation() }
    }

    private func startAnimation() {
        // ── Faz 1: O → N → E yukarıdan "damgalanır" (120ms aralıklı) ──
        for i in 0..<3 {
            let delay = Double(i) * 0.12
            withAnimation(
                .spring(response: 0.45, dampingFraction: 0.58)
                .delay(delay)
            ) {
                letterOffsets[i] = 0
                letterScales[i] = 1
                letterOpacities[i] = 1
            }
        }

        // ── Faz 2: Kareler bouncy pop ile sırayla belirir (t=0.55s …) ──
        for i in 0..<5 {
            let delay = 0.55 + Double(i) * 0.08
            withAnimation(
                .spring(response: 0.38, dampingFraction: 0.52)
                .delay(delay)
            ) {
                squareScales[i] = 1
                squareOpacities[i] = 1
            }
        }

        // ── Faz 3: Kareler dalga gibi idle'da yüzer (t=1.30s) ──
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.30) {
            for i in 0..<5 {
                let waveDelay = Double(i) * 0.15
                withAnimation(
                    .easeInOut(duration: 1.0)
                    .repeatForever(autoreverses: true)
                    .delay(waveDelay)
                ) {
                    squareOffsets[i] = -5
                }
            }
        }

        // ── Faz 3.5: Slogan belirir (t=1.70s) ──
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.70) {
            withAnimation(.easeIn(duration: ONEAnimation.durationMedium)) {
                sloganOpacity = 1
            }
        }

        // ── Faz 4: Ana uygulamaya geçiş (t=1.90s) ──
        // Slogan 1.70s'de fade-in başlıyor; 200ms sonra pickera geçiyoruz.
        // Cold start TTI'yi ~900ms kısalttı.
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.90) {
            isActive = true
        }
    }
}

#Preview {
    SplashScreen(isActive: .constant(false))
}
