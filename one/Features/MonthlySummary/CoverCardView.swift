//
//  CoverCardView.swift
//  one
//
//  Kart 1 — Kapak ekranı. Animasyonlu gradient, grain texture, dev ay yazısı,
//  istatistik kutuları ve "kaydır" ipucu.
//
//  Fontlar:
//    Gerçek font: "BebasNeue-Regular" ve "Syne-Regular" / "SyneMono-Regular"
//    Bundle'a eklendiğinde UIAppFonts array içinde tanımlı olmalı.
//    Şu an system font ile fallback yapılıyor.
//

import SwiftUI

struct CoverCardView: View {
    let data: MonthlySummaryData

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
                    // Gerçek font: Font.custom("BebasNeue-Regular", size: 220)
                    .font(.system(size: 220, weight: .black))
                    .foregroundColor(.white.opacity(0.04))
                    .offset(x: -10, y: 30)
                    .allowsHitTesting(false)

                // MARK: — İçerik
                VStack(alignment: .leading, spacing: 0) {
                    Spacer().frame(height: size.height * 0.12)

                    // Küçük etiket
                    Text("ONE MOOD · \(data.year)")
                        // Gerçek font: Font.custom("SyneMono-Regular", size: 10)
                        .font(.system(size: 10, weight: .regular, design: .monospaced))
                        .tracking(3)
                        .foregroundColor(.white.opacity(0.40))
                        .padding(.bottom, 18)

                    // Büyük başlık
                    VStack(alignment: .leading, spacing: 0) {
                        Text(data.month)
                            // Gerçek font: Font.custom("BebasNeue-Regular", size: 88)
                            .font(.system(size: 88, weight: .black))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [Color(red: 0.90, green: 0.35, blue: 0.10),
                                             Color(red: 0.95, green: 0.60, blue: 0.10)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)

                        Text("özetin.")
                            // Gerçek font: Font.custom("BebasNeue-Regular", size: 88)
                            .font(.system(size: 88, weight: .black))
                            .foregroundColor(.white)
                    }
                    .padding(.bottom, 16)

                    // Alt yazı
                    Text("\(data.totalDays) gün · \(data.topTracks.count) şarkı · 1 sen")
                        // Gerçek font: Font.custom("Syne-Regular", size: 14)
                        .font(.system(size: 14, weight: .light))
                        .foregroundColor(.white.opacity(0.50))
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
                                .font(.system(size: 13))
                            Text("kaydır")
                                // Gerçek font: Font.custom("SyneMono-Regular", size: 11)
                                .font(.system(size: 11, weight: .regular, design: .monospaced))
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
                        Text("one mood")
                            // Gerçek font: Font.custom("SyneMono-Regular", size: 9)
                            .font(.system(size: 9, weight: .regular, design: .monospaced))
                            .foregroundColor(.white.opacity(0.18))
                    }
                    .padding(.horizontal, 28)
                    .padding(.bottom, 48)
                }
                .frame(width: size.width)
            }
        }
        .background(Color.black)
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

    // MARK: — Gradient Background
    private var gradientBackground: some View {
        ZStack {
            Color.black

            // Sol üst — turuncu-kırmızı
            RadialGradient(
                colors: [Color(red: 0.85, green: 0.25, blue: 0.10).opacity(gradientPulse ? 1.0 : 0.8),
                         Color.clear],
                center: .topLeading,
                startRadius: 0,
                endRadius: 420
            )

            // Sağ orta — amber
            RadialGradient(
                colors: [Color(red: 0.90, green: 0.60, blue: 0.10).opacity(gradientPulse ? 0.90 : 0.70),
                         Color.clear],
                center: UnitPoint(x: 0.85, y: 0.45),
                startRadius: 0,
                endRadius: 340
            )

            // Alt — sarı
            RadialGradient(
                colors: [Color(red: 0.95, green: 0.80, blue: 0.15).opacity(gradientPulse ? 0.70 : 0.50),
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
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.white)

            Text("baskın ruh hali")
                .font(.system(size: 12, weight: .light))
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
            statBox(value: "\(data.totalDays)", label: "GÜN")
            statBox(value: "\(data.uniqueArtists)", label: "SANATÇI")
            statBox(value: "\(data.maxRepeat)×", label: "EN FAZLA")
        }
        .background(Color.white.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }

    private func statBox(value: String, label: String) -> some View {
        VStack(alignment: .center, spacing: 4) {
            Text(value)
                // Gerçek font: Font.custom("BebasNeue-Regular", size: 36)
                .font(.system(size: 36, weight: .black))
                .foregroundColor(.white)
            Text(label)
                // Gerçek font: Font.custom("SyneMono-Regular", size: 9)
                .font(.system(size: 9, weight: .regular, design: .monospaced))
                .tracking(1.5)
                .foregroundColor(.white.opacity(0.45))
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
