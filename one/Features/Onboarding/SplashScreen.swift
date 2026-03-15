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
                Text("hisset · keşfet · paylaş")
                    .font(ONETypography.bodyMD)
                    .tracking(1.8)
                    .foregroundColor(ONETokens.oneAsh)
                    .opacity(sloganOpacity)
            }
        }
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

        // ── Faz 4: Ana uygulamaya geçiş (t=2.80s) ──
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.80) {
            isActive = true
        }
    }
}

// Alternative: Minimal Dot Animation
struct SplashScreenMinimal: View {
    @Binding var isActive: Bool
    @State private var dotScale: CGFloat = 0
    @State private var dotOpacity: Double = 0
    @State private var textOpacity: Double = 0

    var body: some View {
        ZStack {
            ONETokens.oneCream
                .ignoresSafeArea()

            VStack(spacing: 24) {
                // Single dot
                Circle()
                    .fill(ONETokens.oneInk)
                    .frame(width: 8, height: 8)
                    .scaleEffect(dotScale)
                    .opacity(dotOpacity)

                // App name
                Text("ONE")
                    .displayXL()
                    .foregroundColor(ONETokens.oneInk)
                    .tracking(-1)
                    .opacity(textOpacity)
            }
        }
        .onAppear {
            // Dot pulse
            withAnimation(.easeInOut(duration: ONEAnimation.durationLong).repeatCount(3, autoreverses: true)) {
                dotScale = 1.5
                dotOpacity = 1
            }

            // Text fade in
            withAnimation(.easeIn(duration: 0.6).delay(1.2)) {
                textOpacity = 1
            }

            // Transition
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                withAnimation(.easeInOut(duration: ONEAnimation.durationMedium)) {
                    isActive = true
                }
            }
        }
    }
}

// Alternative: Breathing Circle
struct SplashScreenBreathing: View {
    @Binding var isActive: Bool
    @State private var breathe = false
    @State private var textOpacity: Double = 0

    var body: some View {
        ZStack {
            ONETokens.oneCream
                .ignoresSafeArea()

            VStack(spacing: 40) {
                // Breathing circle
                ZStack {
                    ForEach(0..<3) { i in
                        Circle()
                            .strokeBorder(ONETokens.oneInk.opacity(0.15 - Double(i) * 0.05), lineWidth: 1)
                            .frame(width: breathe ? CGFloat(80 + i * 30) : CGFloat(60 + i * 30))
                    }

                    Circle()
                        .fill(ONETokens.oneInk)
                        .frame(width: 40, height: 40)
                }
                .animation(.easeInOut(duration: ONEAnimation.durationPulse).repeatForever(autoreverses: true), value: breathe)

                // Text
                VStack(spacing: 12) {
                    Text("ONE")
                        .displayXL()
                        .foregroundColor(ONETokens.oneInk)
                        .tracking(-1)

                    Text("Hisset. Keşfet. Paylaş.")
                        .monoBase(tracking: 1.5)
                        .foregroundColor(ONETokens.oneAsh)
                }
                .opacity(textOpacity)
            }
        }
        .onAppear {
            breathe = true

            withAnimation(.easeIn(duration: 0.8).delay(0.5)) {
                textOpacity = 1
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                withAnimation(.easeInOut(duration: ONEAnimation.durationMedium)) {
                    isActive = true
                }
            }
        }
    }
}

#Preview {
    SplashScreen(isActive: .constant(false))
}
