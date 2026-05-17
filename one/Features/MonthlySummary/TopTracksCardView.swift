//
//  TopTracksCardView.swift
//  one
//
//  Kart 3 — Bu Ayın Sesi (Top 5 Şarkı)
//  Staggered liste animasyonu + Share butonu (ImageRenderer, iOS 16+)
//

import SwiftUI

struct TopTracksCardView: View {
    let data: MonthlySummaryData
    var isExport: Bool = false
    var showWatermark: Bool = false

    @State private var itemsVisible: [Bool] = []

    // Amber rengi — 1. sıra vurgu
    private let amberColor = ONETokens.summaryAmberGlow  // #E69919

    var body: some View {
        GeometryReader { geo in
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    Spacer().frame(height: geo.size.height * 0.10)

                    // Başlık
                    VStack(alignment: .leading, spacing: 0) {
                        Text(NSLocalizedString("monthly.thisMonth", comment: ""))
                            .displayLG()
                            .fontWeight(.black)
                            .foregroundColor(.white)
                        Text(NSLocalizedString("monthly.sound", comment: ""))
                            .displayLG()
                            .fontWeight(.black)
                            .foregroundColor(.white.opacity(0.30))
                    }
                    .padding(.bottom, 36)

                        // Track Listesi
                        if data.topTracks.isEmpty {
                            // Boş durum
                            VStack(spacing: 12) {
                                Text("🎵")
                                    .font(.system(size: 48))
                                    .opacity(0.4)
                                Text(NSLocalizedString("monthly.noSongs", comment: ""))
                                    .bodyLG()
                                    .fontWeight(.light)
                                    .foregroundColor(.white.opacity(0.40))
                                    .multilineTextAlignment(.center)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.top, 40)
                            .padding(.bottom, 100)
                        } else {
                            VStack(spacing: 2) {
                                ForEach(Array(data.topTracks.enumerated()), id: \.element.id) { i, track in
                                    VStack(spacing: 0) {
                                        trackRow(track: track, index: i)
                                            .opacity(isExport || (i < itemsVisible.count && itemsVisible[i]) ? 1 : 0)
                                            .offset(x: isExport || (i < itemsVisible.count && itemsVisible[i]) ? 0 : 24)

                                        Color.white.opacity(0.05)
                                            .frame(height: 1)
                                            .padding(.top, 2)
                                    }
                                }
                            }
                            .padding(.bottom, 32)
                            
                            // Öngörülebilirlik & Motivasyon Mesajı
                            VStack(spacing: 6) {
                                Text(NSLocalizedString("monthly.expectationTitle", comment: ""))
                                    .bodySM()
                                    .fontWeight(.bold)
                                    .foregroundColor(.white.opacity(0.9))

                                Text(NSLocalizedString("monthly.expectationBody", comment: ""))
                                    .bodySM()
                                    .foregroundColor(.white.opacity(0.6))
                                    .multilineTextAlignment(.center)
                                    .lineSpacing(2)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.bottom, 100)
                        }

                        Spacer()
                    }
                    .padding(.horizontal, 28)
            }
        }
        .overlay(alignment: .bottomTrailing) {
            if showWatermark { watermarkView }
        }
        .background(ONETokens.oneCinematicDark)
        .ignoresSafeArea()
        .onAppear {
            itemsVisible = Array(repeating: false, count: data.topTracks.count)
            for i in data.topTracks.indices {
                withAnimation(
                    .easeOut(duration: 0.5)
                    .delay(Double(i) * 0.10 + 0.3)
                ) {
                    itemsVisible[i] = true
                }
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

    // MARK: — Track Row
    private func trackRow(track: TrackEntry, index: Int) -> some View {
        HStack(spacing: 14) {
            // Sıra numarası
            Text("\(track.rank)")
                .displayMD()
                .fontWeight(.black)
                .foregroundColor(track.rank == 1 ? amberColor : .white.opacity(0.25))
                .frame(width: 28, alignment: .center)

            // Albüm art (gradient + emoji)
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(
                        LinearGradient(
                            colors: track.gradientColors,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 48, height: 48)

                Text(track.emoji)
                    .font(.system(size: 22))
            }

            // İsim + Sanatçı
            VStack(alignment: .leading, spacing: 3) {
                Text(track.name)
                    .bodyLG()
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .lineLimit(1)
                Text(track.artist)
                    .monoSM()
                    .foregroundColor(.white.opacity(0.45))
                    .lineLimit(1)
            }

            Spacer()

            // Seçim sayısı
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(track.days)")
                    .displaySM()
                    .fontWeight(.black)
                    .foregroundColor(.white)
                Text(NSLocalizedString(track.days > 1 ? "monthly.selectionLabel" : "monthly.timesLabel", comment: ""))
                    .monoMicro()
                    .foregroundColor(.white.opacity(0.35))
            }
        }
        .padding(.vertical, 14)
    }
}

#Preview {
    TopTracksCardView(data: .mock)
}
