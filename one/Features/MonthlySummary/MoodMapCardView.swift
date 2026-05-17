//
//  MoodMapCardView.swift
//  one
//
//  Kart 2 — Ruh Hali Haritası
//  28 günlük takvim grid + legend + duygu bar chart (animasyonlu)
//
//  Tipografi: `ONETypography.displayXXL` (başlık) ve `ONETypography.monoMicro`/`monoLabel` (etiketler).
//

import SwiftUI

struct MoodMapCardView: View {
    let data: MonthlySummaryData
    var isExport: Bool = false
    var showWatermark: Bool = false

    // Bar chart animasyon için her duygunun genişliği
    @State private var animatedWidths: [CGFloat] = []
    @State private var appeared = false

    var body: some View {
        GeometryReader { geo in
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {

                    Spacer().frame(height: geo.size.height * 0.10)

                    // Başlık
                    VStack(alignment: .leading, spacing: 0) {
                        Text(NSLocalizedString("monthly.moodTitle", comment: ""))
                            .displayXXL()
                            .foregroundColor(.white)
                        Text(NSLocalizedString("monthly.moodMap", comment: ""))
                            .displayXXL()
                            .foregroundColor(.white.opacity(0.30))
                    }
                    .padding(.bottom, 32)
                    .opacity(appeared || isExport ? 1 : 0)
                    .offset(y: appeared || isExport ? 0 : 16)

                    // Takvim Grid
                    calendarGrid
                        .padding(.bottom, 20)

                    // Legend
                    legend
                        .padding(.bottom, 36)

                    // Duygu Bar Chart
                    emotionBars(containerWidth: geo.size.width - 56)
                        .padding(.bottom, 60)
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
            // Başlangıç genişlikleri sıfır
            animatedWidths = Array(repeating: 0, count: data.emotionBreakdown.count)
            withAnimation(.easeOut(duration: 0.5)) {
                appeared = true
            }
            // Bar animasyonunu gecikme ile başlat
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                for i in data.emotionBreakdown.indices {
                    withAnimation(.easeInOut(duration: 1.2).delay(Double(i) * 0.15)) {
                        animatedWidths[i] = 1.0  // normalize 0…1, gerçek genişlik GeometryReader ile
                    }
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
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundColor(.white.opacity(0.7))
                    .tracking(3)
            }
        }
        .padding(.trailing, 20)
        .padding(.bottom, 32)
    }

    // MARK: — Takvim Grid
    private var calendarGrid: some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: 5), count: 7)

        return VStack(alignment: .leading, spacing: 0) {
            // Gün adları başlığı
            HStack(spacing: 0) {
                ForEach(["Pt", "Sa", "Ça", "Pe", "Cu", "Ct", "Pz"], id: \.self) { d in
                    Text(d)
                        .monoMicro()
                        .foregroundColor(.white.opacity(0.25))
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.bottom, 6)

            LazyVGrid(columns: columns, spacing: 5) {
                ForEach(Array(data.dailyMoods.enumerated()), id: \.offset) { idx, color in
                    ZStack(alignment: .topLeading) {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(color)
                            .frame(height: 40)
                            .opacity(appeared || isExport ? 1 : 0)
                            .animation(
                                .easeOut(duration: 0.4)
                                .delay(Double(idx) * 0.025),
                                value: appeared
                            )

                        Text("\(idx + 1)")
                            .monoMicro()
                            .foregroundColor(.white.opacity(0.20))
                            .padding(3)
                    }
                }
            }
        }
    }

    // MARK: — Legend
    private var legend: some View {
        let moodColors: [(label: String, color: Color)] = [
            ("Ateşli",    ONETokens.oneRed),
            ("Coşkulu",   ONETokens.moodOrange),
            ("Mutlu",     ONETokens.moodYellow),
            ("Doğal",     ONETokens.moodLime),
            ("Huzurlu",   ONETokens.oneGreen),
            ("Özgür",     ONETokens.moodTeal),
            ("Derin",     ONETokens.oneBlue),
            ("Nostaljik", ONETokens.moodIndigo),
            ("Gizemli",   ONETokens.moodPurple),
            ("Hassas",    ONETokens.moodRose),
            ("Sessiz",    ONETokens.moodDark),
            ("Nötr",      ONETokens.oneIvory),
        ]

        let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 4)

        return LazyVGrid(columns: columns, alignment: .leading, spacing: 8) {
            ForEach(moodColors, id: \.label) { item in
                HStack(spacing: 6) {
                    Circle()
                        .fill(item.color)
                        .frame(width: 6, height: 6)
                    Text(item.label)
                        .monoMicro()
                        .foregroundColor(.white.opacity(0.55))
                }
            }
        }
    }

    // MARK: — Emotion Bar Chart
    private func emotionBars(containerWidth: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(NSLocalizedString("monthly.emotionDistribution", comment: ""))
                .monoMicro(tracking: 2)
                .foregroundColor(.white.opacity(0.35))
                .padding(.bottom, 12)

            ForEach(Array(data.emotionBreakdown.enumerated()), id: \.offset) { i, item in
                HStack(spacing: 12) {
                    Text(item.name)
                        .monoLabel()
                        .foregroundColor(.white.opacity(0.65))
                        .frame(width: 80, alignment: .leading)

                    let maxBarWidth = containerWidth - 80 - 44  // name + percentage
                    let targetWidth = maxBarWidth * item.percentage
                    let currentWidth = isExport ? targetWidth : (i < animatedWidths.count
                        ? targetWidth * animatedWidths[i]
                        : 0)

                    ZStack(alignment: .leading) {
                        // Arka plan
                        Capsule()
                            .fill(Color.white.opacity(0.07))
                            .frame(width: maxBarWidth, height: 8)
                        // Dolu kısım
                        Capsule()
                            .fill(item.color)
                            .frame(width: max(0, currentWidth), height: 8)
                    }

                    Text("\(Int(item.percentage * 100))%")
                        .monoMicro()
                        .foregroundColor(.white.opacity(0.35))
                        .frame(width: 32, alignment: .trailing)
                }
                .padding(.vertical, 6)
            }
        }
    }
}

#Preview {
    MoodMapCardView(data: .mock)
}
