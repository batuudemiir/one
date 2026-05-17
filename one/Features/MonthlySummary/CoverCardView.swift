//
//  CoverCardView.swift
//  one
//
//  Kart 1 — Kapak ekranı. Animasyonlu gradient, grain texture, dev ay yazısı,
//  istatistik kutuları ve "kaydır" ipucu.
//

import SwiftUI

struct CoverCardView: View {
    let data: MonthlySummaryData
    var showWatermark: Bool = false

    // Gradient animasyonu
    @State private var gradientPulse = false
    // Kaydır hint bounce animasyonu
    @State private var swipeOffset: CGFloat = 0

    var body: some View {
        GeometryReader { geo in
            let size = geo.size

            ZStack(alignment: .bottomLeading) {

                // MARK: — Arka Plan: Animasyonlu Gradient Mesh
                gradientBackground

                // MARK: — Grain Texture (yarı saydam overlay)
                Rectangle()
                    .fill(Color.white.opacity(0.03))
                    .blendMode(.overlay)
                    .ignoresSafeArea()

                // MARK: — Dev "AY" yazısı sol alta
                Text(monthAbbrev.uppercased())
                    .displayXXL()
                    .fontWeight(.black)
                    .foregroundColor(.white.opacity(0.04))
                    .offset(x: -10, y: 30)
                    .allowsHitTesting(false)

                // MARK: — İçerik
                VStack(alignment: .leading, spacing: 0) {
                    Spacer().frame(height: size.height * 0.12)

                    // Küçük etiket
                    Text("ONE MOOD · \(data.year)")
                        .monoLabel(tracking: 3)
                        .foregroundColor(.white.opacity(0.40))
                        .padding(.bottom, 18)

                    // Büyük başlık
                    VStack(alignment: .leading, spacing: 0) {
                        Text(data.month)
                            .displayXXL()
                            .fontWeight(.black)
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [ONETokens.summaryGradientStart,
                                             ONETokens.summaryGradientEnd],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)

                        Text(NSLocalizedString("monthly.summary", comment: ""))
                            .displayXXL()
                            .fontWeight(.black)
                            .foregroundColor(.white)
                    }
                    .padding(.bottom, 16)

                    // Storytelling Alt Yazı
                    VStack(alignment: .leading, spacing: 6) {
                        Text(data.storyTitle)
                            .displaySM()
                            .fontWeight(.bold)
                            .foregroundColor(.white)

                        Text(data.storySubtitle)
                            .bodyLG()
                            .foregroundColor(.white.opacity(0.80))
                            .lineSpacing(2)
                    }
                    .padding(.bottom, 28)

                    // Mood Badge
                    moodBadge
                        .padding(.bottom, 28)

                    // Stats Grid
                    statsGrid
                        .padding(.bottom, 0)

                    Spacer()
                }
                .padding(.horizontal, 28)
                .frame(width: size.width)

                // MARK: — Alt Bilgi (su işareti + kaydır ipucu)
                VStack {
                    Spacer()
                    HStack(alignment: .bottom) {
                        // Kaydır hint
                        HStack(spacing: 6) {
                            Text("→")
                                .bodySM()
                            Text(NSLocalizedString("monthly.swipe", comment: ""))
                                .monoSM()
                        }
                        .foregroundColor(.white.opacity(0.35))
                        .offset(x: swipeOffset)
                        .onAppear {
                            withAnimation(
                                .easeInOut(duration: 1.2)
                                .repeatForever(autoreverses: true)
                            ) {
                                swipeOffset = 10
                            }
                        }

                        Spacer()

                        // Watermark
                        Text(NSLocalizedString("monthly.oneMood", comment: ""))
                            .monoMicro()
                            .foregroundColor(.white.opacity(0.18))
                    }
                    .padding(.horizontal, 28)
                    .padding(.bottom, 48)
                }
                .frame(width: size.width)
            }
        }
        .overlay(alignment: .bottomTrailing) {
            if showWatermark { watermarkView }
        }
        .background(ONETokens.oneCinematicDark)
        .ignoresSafeArea()
        .onAppear {
            withAnimation(
                .easeInOut(duration: 6)
                .repeatForever(autoreverses: true)
            ) {
                gradientPulse.toggle()
            }
        }
    }

    // MARK: — Watermark
    private var watermarkView: some View {
        Group {
            if let _ = UIImage(named: "ONE_Watermark") {
                Image("ONE_Watermark")
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .foregroundColor(.white.opacity(0.85))
                    .frame(width: 80, height: 28)
            } else {
                Text("ONE")
                    .bodySM()
                    .fontWeight(.bold)
                    .foregroundColor(.white.opacity(0.7))
                    .tracking(3)
            }
        }
        .padding(.trailing, 20)
        .padding(.bottom, 32)
    }

    // MARK: — Gradient Background
    private var gradientBackground: some View {
        ZStack {
            ONETokens.oneCinematicDark

            // Sol üst — turuncu-kırmızı
            RadialGradient(
                colors: [ONETokens.summaryFireSpark.opacity(gradientPulse ? 1.0 : 0.8),
                         Color.clear],
                center: .topLeading,
                startRadius: 0,
                endRadius: 420
            )

            // Sağ orta — amber
            RadialGradient(
                colors: [ONETokens.summaryAmberGlow.opacity(gradientPulse ? 0.90 : 0.70),
                         Color.clear],
                center: UnitPoint(x: 0.85, y: 0.45),
                startRadius: 0,
                endRadius: 340
            )

            // Alt — sarı
            RadialGradient(
                colors: [ONETokens.summarySunshine.opacity(gradientPulse ? 0.70 : 0.50),
                         Color.clear],
                center: .bottom,
                startRadius: 0,
                endRadius: 300
            )
        }
        .ignoresSafeArea()
    }

    // MARK: — Mood Badge
    private var moodBadge: some View {
        HStack(spacing: 10) {
            // Amber glow dot
            Circle()
                .fill(data.dominantMoodColor)
                .frame(width: 8, height: 8)
                .shadow(color: data.dominantMoodColor.opacity(0.8), radius: 6)

            Text(data.dominantMood)
                // Gerçek font: Font.custom("Syne-Regular", size: 14)
                .bodySM()
                .fontWeight(.bold)
                .foregroundColor(.white)

            Text(NSLocalizedString("monthly.dominantMood", comment: ""))
                .monoSM()
                .fontWeight(.light)
                .foregroundColor(.white.opacity(0.45))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .overlay(
            Capsule()
                .stroke(Color.white.opacity(0.18), lineWidth: 1)
        )
    }

    // MARK: — Stats Grid
    private var statsGrid: some View {
        HStack(spacing: 1) {
            statBox(value: "\(data.daysLogged)", label: NSLocalizedString("monthly.statLogged", comment: ""))
            statBox(value: "\(data.uniqueArtists)", label: NSLocalizedString("monthly.statArtists", comment: ""))
            statBox(value: "\(data.monthStreak)", label: NSLocalizedString("monthly.statStreak", comment: ""), highlight: data.monthStreak >= 7)
        }
        .background(Color.white.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }

    private func statBox(value: String, label: String, highlight: Bool = false) -> some View {
        VStack(alignment: .center, spacing: 4) {
            Text(value)
                .displayMD()
                .fontWeight(.black)
                .foregroundColor(highlight ? ONETokens.summaryHighlightAmber : .white)
            Text(label)
                .monoMicro(tracking: 1.5)
                .foregroundColor(.white.opacity(highlight ? 0.65 : 0.45))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
    }

    // MARK: — Helpers
    private var monthAbbrev: String {
        // "Şubat" → "ŞUB"
        String(data.month.prefix(3)).uppercased()
    }
}

#Preview {
    CoverCardView(data: .mock)
}
