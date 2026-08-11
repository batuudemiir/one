//
//  EchoV3Sections.swift
//  one
//
//  Yankı ekranının v3 spec'ine göre eksik bölümleri: cover (340pt hero),
//  mood map (7-col heatmap + dağılım barı), en çok dinlenenler, sayısal
//  breakdown ve ay hikayesi (horizontal pager). Her biri EchoData'dan okur;
//  yeni veri katmanı ekleme yok.
//
//  Tasarım kararları:
//  - Renkler: mood dominant renk hero'da; nötr yüzeyler V3Tokens.paper/surface.
//  - Tipografi: sayılar Archivo 22–52pt, meta DM Mono 10pt / 1.4 tracking.
//  - Streak/rozet YOK — v3 spec (bilinçli yapmayacaklar).
//

import SwiftUI

// MARK: - Cover (hero mood card)

/// Ayın rengi kartı — 340pt yükseklik, dominant mood zemin, "Ay hikayesini izle" CTA.
struct EchoCoverSection: View {
    let data: EchoData
    let monthName: String
    let onStory: () -> Void

    private var top: MoodStat? { data.thisMonthMoodDistribution.first ?? data.moodDistribution.first }
    private var accent: Color { Color(hex: top?.colorHex ?? "#14141A") }
    private var ink: Color { accent.readableInk() }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Text("\(monthName.uppercased()) · AYIN RENGİ")
                    .font(V3Typography.mono(10, weight: .regular))
                    .tracking(1.5)
                    .foregroundColor(ink.opacity(0.68))
                Spacer()
            }
            .padding(.top, 24)
            .padding(.horizontal, 24)

            Spacer(minLength: 0)

            VStack(alignment: .leading, spacing: 14) {
                if let top {
                    Text(top.label.lowercased())
                        .font(V3Typography.display(52, weight: .semibold))
                        .tracking(-1.6)
                        .foregroundColor(ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                }
                Text(factualLine)
                    .font(V3Typography.sans(14))
                    .foregroundColor(ink.opacity(0.72))
                    .lineSpacing(2)

                Button(action: {
                    ONEHaptics.feelingSelected()
                    onStory()
                }) {
                    HStack(spacing: 8) {
                        Text("Ay hikayesini izle")
                            .font(V3Typography.sans(14, weight: .semibold))
                        Image(systemName: "arrow.right")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundColor(accent)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 12)
                    .background(Capsule().fill(ink.opacity(0.94)))
                }
                .buttonStyle(.plain)
                .padding(.top, 6)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 340)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(accent)
        )
        .padding(.horizontal, 20)
    }

    private var factualLine: String {
        let entries = data.thisMonthSongs
        let mood = (top?.label ?? "—").lowercased()
        if entries == 0 { return "Bu ay henüz an bırakmadın." }
        let anStr = entries == 1 ? "1 an" : "\(entries) an"
        return "\(anStr) · en sık \(mood)"
    }
}

// MARK: - Mood map (7-col heatmap + distribution bars)

/// 30 gün ısı haritası (7 sütun) + mood dağılım barları.
struct EchoMoodMapSection: View {
    let data: EchoData

    private var chartMoods: [MoodStat] {
        Array(data.moodDistribution.sorted { $0.count > $1.count }.prefix(9))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            EchoSectionHeader(eyebrow: "MOOD HARİTASI", title: "Son 30 gün")

            heatmap
                .padding(.top, 4)

            if !chartMoods.isEmpty {
                Rectangle().fill(V3Tokens.hairline).frame(height: 1).padding(.vertical, 4)
                distributionBar
            }
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(V3Tokens.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(V3Tokens.hairline, lineWidth: 1)
                )
        )
        .padding(.horizontal, 20)
    }

    private var heatmap: some View {
        let colors = paddedLast30
        return LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 7), spacing: 6) {
            ForEach(0..<colors.count, id: \.self) { i in
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(colors[i] ?? V3Tokens.hairline)
                    .frame(height: 28)
                    .overlay(
                        Group {
                            if colors[i] == nil {
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .strokeBorder(V3Tokens.hairline, style: StrokeStyle(lineWidth: 1, dash: [2, 3]))
                            }
                        }
                    )
            }
        }
    }

    /// 30 hücreye yuvarlamak yerine grid tam dolsun diye 28'e (4×7) padd'liyoruz.
    private var paddedLast30: [Color?] {
        let src = data.last30DaysColors
        let target = 28
        let start = max(0, src.count - target)
        var out = Array(src[start...])
        while out.count < target { out.insert(nil, at: 0) }
        return out
    }

    private var distributionBar: some View {
        let total = max(chartMoods.reduce(0) { $0 + $1.count }, 1)
        return VStack(alignment: .leading, spacing: 10) {
            GeometryReader { geo in
                HStack(spacing: 2) {
                    ForEach(chartMoods) { m in
                        Rectangle()
                            .fill(Color(hex: m.colorHex))
                            .frame(width: geo.size.width * CGFloat(m.count) / CGFloat(total))
                    }
                }
                .clipShape(Capsule())
            }
            .frame(height: 12)

            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], alignment: .leading, spacing: 6) {
                ForEach(chartMoods) { m in
                    HStack(spacing: 8) {
                        Circle().fill(Color(hex: m.colorHex)).frame(width: 8, height: 8)
                        Text(m.label.lowercased())
                            .font(V3Typography.sans(12, weight: .medium))
                            .foregroundColor(V3Tokens.ink)
                        Spacer(minLength: 0)
                        Text("\(m.count)")
                            .font(V3Typography.mono(11, weight: .regular))
                            .foregroundColor(V3Tokens.mutedText)
                            .contentTransition(.numericText())
                            .animation(.snappy, value: m.count)
                    }
                }
            }
        }
    }
}

// MARK: - En çok dinlenenler

struct EchoTopTracksSection: View {
    let data: EchoData

    private var tracks: [RepeatedSong] { Array(data.repeatedSongs.prefix(5)) }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            EchoSectionHeader(eyebrow: "EN ÇOK DİNLENENLER", title: "Bu ayın tekrarları")

            if tracks.isEmpty {
                Text("Aynı şarkı iki kez geçmedi.")
                    .font(V3Typography.sans(14))
                    .foregroundColor(V3Tokens.mutedText)
                    .padding(.vertical, 8)
            } else {
                VStack(spacing: 10) {
                    ForEach(Array(tracks.enumerated()), id: \.element.id) { idx, t in
                        trackRow(index: idx + 1, track: t)
                    }
                }
            }
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(V3Tokens.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(V3Tokens.hairline, lineWidth: 1)
                )
        )
        .padding(.horizontal, 20)
    }

    private func trackRow(index: Int, track: RepeatedSong) -> some View {
        HStack(spacing: 14) {
            Text(String(format: "%02d", index))
                .font(V3Typography.mono(13, weight: .regular))
                .tracking(1.0)
                .foregroundColor(V3Tokens.faintText)
                .frame(width: 26, alignment: .leading)

            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color(hex: track.moodColorHex))
                .frame(width: 44, height: 44)
                .overlay(
                    Image(systemName: "music.note")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(Color(hex: track.moodColorHex).readableInk())
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(track.songName)
                    .font(V3Typography.sans(14, weight: .semibold))
                    .foregroundColor(V3Tokens.ink)
                    .lineLimit(1)
                Text(track.artistName)
                    .font(V3Typography.sans(12))
                    .foregroundColor(V3Tokens.mutedText)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Text("\(track.count) kez")
                .font(V3Typography.mono(11, weight: .regular))
                .tracking(0.8)
                .foregroundColor(V3Tokens.mutedText)
        }
    }
}

// MARK: - Sayısal breakdown

struct EchoStatsBreakdownSection: View {
    let data: EchoData

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            EchoSectionHeader(eyebrow: "SAYISAL", title: "Kısa özet")

            VStack(spacing: 0) {
                statRow(label: "Toplam an", value: "\(data.totalSongs)")
                divider
                statRow(label: "Bu ay", value: "\(data.thisMonthSongs)")
                divider
                statRow(label: "Sessiz gün", value: "\(data.silentDays)")
                if let day = data.mostActiveDayOfWeek {
                    divider
                    statRow(label: "En aktif gün", value: day)
                }
                if data.syncCount > 0 {
                    divider
                    statRow(label: "Rezonans", value: "\(data.syncCount)")
                }
            }
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(V3Tokens.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(V3Tokens.hairline, lineWidth: 1)
                )
        )
        .padding(.horizontal, 20)
    }

    private func statRow(label: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .font(V3Typography.sans(14))
                .foregroundColor(V3Tokens.mutedText)
            Spacer()
            Text(value)
                .font(V3Typography.display(22, weight: .semibold))
                .tracking(-0.4)
                .foregroundColor(V3Tokens.ink)
        }
        .padding(.vertical, 12)
    }

    private var divider: some View {
        Rectangle().fill(V3Tokens.hairline).frame(height: 1)
    }
}

// MARK: - Section header

struct EchoSectionHeader: View {
    let eyebrow: String
    let title: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(eyebrow)
                .font(V3Typography.mono(10, weight: .regular))
                .tracking(1.5)
                .foregroundColor(V3Tokens.faintText)
            Text(title)
                .font(V3Typography.display(22, weight: .semibold))
                .tracking(-0.6)
                .foregroundColor(V3Tokens.ink)
        }
    }
}

// MARK: - Month Story (horizontal pager)

/// 4 sayfa: cover · mood map · en çok dinlenenler · sayısal özet.
/// Üstte progress barlar, yatay scroll-snap. `.paging` behavior TabView ile.
struct EchoMonthStoryView: View {
    let data: EchoData
    let monthName: String
    let onClose: () -> Void

    @State private var page: Int = 0
    private let pageCount = 4

    var body: some View {
        ZStack(alignment: .top) {
            V3Tokens.paper.ignoresSafeArea()

            TabView(selection: $page) {
                storyPage(index: 0) { coverPage }
                storyPage(index: 1) { mapPage }
                storyPage(index: 2) { tracksPage }
                storyPage(index: 3) { statsPage }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .ignoresSafeArea(edges: .bottom)

            VStack(spacing: 12) {
                progressBars
                topBar
            }
            .padding(.top, 12)
            .padding(.horizontal, 20)
        }
    }

    // MARK: - Chrome

    private var progressBars: some View {
        HStack(spacing: 6) {
            ForEach(0..<pageCount, id: \.self) { i in
                Capsule()
                    .fill(i <= page ? V3Tokens.ink : V3Tokens.hairline)
                    .frame(height: 3)
            }
        }
    }

    private var topBar: some View {
        HStack {
            Text("\(monthName.uppercased()) · AY HİKAYESİ")
                .font(V3Typography.mono(10, weight: .regular))
                .tracking(1.4)
                .foregroundColor(V3Tokens.faintText)
            Spacer()
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(V3Tokens.ink)
                    .frame(width: 34, height: 34)
                    .background(Circle().fill(V3Tokens.surface).overlay(Circle().stroke(V3Tokens.hairline, lineWidth: 1)))
            }
            .buttonStyle(.plain)
        }
    }

    /// TabView içinde her sayfa 82% width kart görüntüsü verecek şekilde padd.
    private func storyPage<Content: View>(index: Int, @ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(.top, 72)
            .padding(.horizontal, 8)
            .padding(.bottom, 32)
            .tag(index)
    }

    // MARK: - Pages

    private var coverPage: some View {
        EchoCoverSection(data: data, monthName: monthName, onStory: {})
            .padding(.top, 8)
    }

    private var mapPage: some View {
        VStack {
            EchoMoodMapSection(data: data)
            Spacer(minLength: 0)
        }
    }

    private var tracksPage: some View {
        VStack {
            EchoTopTracksSection(data: data)
            Spacer(minLength: 0)
        }
    }

    private var statsPage: some View {
        VStack {
            EchoStatsBreakdownSection(data: data)
            Spacer(minLength: 0)
        }
    }
}

// MARK: - Contrast helper

private extension Color {
    /// Renk zemini için okunabilir ink tercihi — luminance eşiğinden geçer.
    func readableInk() -> Color {
        // UIColor route — RGB bileşenleri çıkar; luminance > 0.62 ise koyu ink.
        let ui = UIColor(self)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        ui.getRed(&r, green: &g, blue: &b, alpha: &a)
        let luma = 0.2126 * r + 0.7152 * g + 0.0722 * b
        return luma > 0.62 ? Color(hex: "#14141A") : Color(hex: "#FBFAF7")
    }
}
