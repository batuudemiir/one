//
//  EchoOverviewView.swift
//  one
//
//  Prototipteki yankı: yedi bölümlü pano değil, iki içgörü kartı.
//

import SwiftUI

/// Yankı prototipte bir **cümle** söylüyor, bir rapor sunmuyor.
///
/// Eski ekran yedi kart yığıyordu (istatistik, hafta, dağılım, sync, tekrar
/// eden şarkılar, saat, seri) — hepsi doğru ama hiçbiri akılda kalmıyor.
/// Prototip ikiye indiriyor: ayın rengi, ve müzikle mood'un kesiştiği yer.
struct EchoOverviewView: View {
    let data: EchoData
    /// Prototip 15 — aylık poster girişi.
    var onPoster: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: ONETokens.spacingMD) {
            Text(NSLocalizedString("echo.title", comment: ""))
                .displayLG()
                .foregroundColor(V3Tokens.ink)

            HStack(alignment: .firstTextBaseline) {
                Text(NSLocalizedString("echo.subtitle", comment: ""))
                    .bodySM()
                    .foregroundColor(V3Tokens.mutedText)

                Spacer()

                if let onPoster {
                    Button {
                        ONEHaptics.feelingSelected()
                        onPoster()
                    } label: {
                        Text(NSLocalizedString("year.poster", comment: ""))
                            .font(V3Typography.sans(13, weight: .semibold))
                            .foregroundColor(ONEBrand.kor)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.top, -5)

            glanceCard
                .padding(.top, ONETokens.spacingSM)

            if let pattern = musicPattern {
                patternCard(pattern)
            }
        }
        .padding(.horizontal, ONETokens.spacingXL)
        .padding(.bottom, 116)
    }

    // MARK: Tek bakışta

    private var topMood: MoodStat? {
        data.moodDistribution.max { $0.count < $1.count }
    }

    /// Grafikte en çok 7 mood — hepsini çizmek çubukları okunmaz inceltiyor.
    private var chartMoods: [MoodStat] {
        Array(data.moodDistribution.sorted { $0.count > $1.count }.prefix(7))
    }

    private var glanceCard: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(NSLocalizedString("echo.glance", comment: ""))
                .monoLabel(tracking: 1.3)
                .foregroundColor(V3Tokens.faintText)

            if let top = topMood {
                (
                    Text(monthName + NSLocalizedString("echo.mostlyPrefix", comment: ""))
                        .foregroundColor(V3Tokens.ink)
                    + Text(top.label)
                        .foregroundColor(Color(hex: top.colorHex))
                        .fontWeight(.semibold)
                    + Text(NSLocalizedString("echo.mostlySuffix", comment: ""))
                        .foregroundColor(V3Tokens.ink)
                )
                .font(.system(size: 19, weight: .semibold))
            }

            bars
                .padding(.top, ONETokens.spacingSM)
        }
        .padding(ONETokens.spacingXL)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackground)
    }

    private var bars: some View {
        let maxCount = max(chartMoods.map(\.count).max() ?? 1, 1)

        return VStack(spacing: 7) {
            HStack(alignment: .bottom, spacing: 6) {
                ForEach(chartMoods) { mood in
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(Color(hex: mood.colorHex))
                        .frame(height: max(CGFloat(mood.count) / CGFloat(maxCount) * 110, 6))
                        .frame(maxWidth: .infinity)
                        .accessibilityLabel("\(mood.label), \(mood.count)")
                }
            }
            .frame(height: 110, alignment: .bottom)

            HStack(spacing: 6) {
                ForEach(chartMoods) { mood in
                    Text(mood.label)
                        .monoSM(tracking: 0.4)
                        .foregroundColor(V3Tokens.faintText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .accessibilityElement(children: .contain)
    }

    // MARK: Müzik × mood

    /// Prototip burada tempo (BPM) gösteriyor — uygulamada tempo verisi yok,
    /// uydurmak yerine aynı işi gören gerçek bir örüntü kullanıyoruz:
    /// en çok tekrar edilen şarkı. İkisi de "müzik seni ele veriyor" diyor.
    private var musicPattern: RepeatedSong? {
        data.repeatedSongs.first
    }

    private func patternCard(_ song: RepeatedSong) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(NSLocalizedString("echo.musicMood", comment: ""))
                .monoLabel(tracking: 1.3)
                .foregroundColor(V3Tokens.faintText)

            Text("\(song.songName) — \(song.artistName)")
                .bodySM()
                .fontWeight(.semibold)
                .foregroundColor(V3Tokens.ink)

            Text(String(
                format: NSLocalizedString("echo.repeatedFormat", comment: ""),
                song.count
            ))
            .bodySM()
            .foregroundColor(V3Tokens.mutedText)
        }
        .padding(ONETokens.spacingXL)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackground)
    }

    // MARK: Chrome

    private var monthName: String {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.setLocalizedDateFormatFromTemplate("MMMM")
        return formatter.string(from: Date())
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: ONETokens.radiusSheet, style: .continuous)
            .fill(Color.white.opacity(0.75))
            .overlay(
                RoundedRectangle(cornerRadius: ONETokens.radiusSheet, style: .continuous)
                    .stroke(V3Tokens.ink.opacity(0.09), lineWidth: 1)
            )
    }
}
