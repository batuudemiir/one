//
//  MonthPosterView.swift
//  one
//
//  Prototip 15 — paylaşım posteri.
//

import SwiftUI

/// Aylık renk posteri.
///
/// Prototipte poster bir "paylaş" butonundan çıkan hazır görsel değil,
/// **ayarlanabilir bir kart**: biçim (story / kare / duvar kağıdı) ve neyin
/// görüneceği (şarkılar / renk ızgarası / notlar) kullanıcıda. Sebebi
/// mahremiyet: aynı ay farklı yerlerde farklı miktarda paylaşılabilmeli —
/// Story'ye renkler, arkadaşa şarkılar, kimseye notlar.
struct MonthPosterView: View {
    let data: MonthlySummaryData
    let onBack: () -> Void

    enum Format: CaseIterable {
        case story, square, wallpaper

        var ratio: CGFloat {
            switch self {
            case .story:     return 9.0 / 16.0
            case .square:    return 1
            case .wallpaper: return 9.0 / 19.5
            }
        }

        var labelKey: String {
            switch self {
            case .story:     return "poster.fmtStory"
            case .square:    return "poster.fmtSquare"
            case .wallpaper: return "poster.fmtWallpaper"
            }
        }
    }

    @State private var format: Format = .story
    @State private var showSongs = true
    @State private var showGrid = true
    @State private var showNotes = false
    @State private var shareItem: PosterShareItem? = nil

    var body: some View {
        SubScreen(
            title: String(format: NSLocalizedString("poster.title", comment: ""), data.month),
            onBack: onBack
        ) {
            VStack(alignment: .leading, spacing: 0) {
                poster
                    .aspectRatio(format.ratio, contentMode: .fit)
                    .frame(maxWidth: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                    .animation(.easeOut(duration: 0.22), value: format)

                sectionLabel(NSLocalizedString("poster.format", comment: ""))
                HStack(spacing: 6) {
                    ForEach(Format.allCases, id: \.self) { f in
                        FilterChip(
                            title: NSLocalizedString(f.labelKey, comment: ""),
                            isSelected: format == f
                        ) {
                            ONEHaptics.feelingSelected()
                            format = f
                        }
                    }
                }

                sectionLabel(NSLocalizedString("poster.show", comment: ""))
                HStack(spacing: 6) {
                    FilterChip(
                        title: NSLocalizedString("poster.songs", comment: ""),
                        isSelected: showSongs
                    ) { showSongs.toggle() }
                    FilterChip(
                        title: NSLocalizedString("poster.colourGrid", comment: ""),
                        isSelected: showGrid
                    ) { showGrid.toggle() }
                    FilterChip(
                        title: NSLocalizedString("poster.notes", comment: ""),
                        isSelected: showNotes
                    ) { showNotes.toggle() }
                }

                Rectangle()
                    .fill(V3Tokens.ink.opacity(0.09))
                    .frame(height: 1)
                    .padding(.vertical, ONETokens.spacingXL)

                VStack(spacing: 8) {
                    Button { share() } label: {
                        Text(NSLocalizedString("general.share", comment: ""))
                            .bodySMMedium()
                            .foregroundColor(ONEBrand.bone)
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .background(Capsule(style: .continuous).fill(V3Tokens.ink))
                    }
                    .buttonStyle(.plain)

                    Button { saveToPhotos() } label: {
                        Text(NSLocalizedString("poster.saveImage", comment: ""))
                            .bodySMMedium()
                            .foregroundColor(V3Tokens.mutedText)
                            .frame(maxWidth: .infinity, minHeight: 44)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .sheet(item: $shareItem) { item in
            ShareSheet(items: [item.image])
        }
    }

    // MARK: Poster

    /// Ayın baskın renginden koyuya inen bir zemin; içerik üç katmanda:
    /// üstte kimlik, ortada renk ızgarası, altta özet.
    private var poster: some View {
        ZStack {
            LinearGradient(
                colors: [
                    data.dominantMoodColor,
                    data.dominantMoodColor.opacity(0.72)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            VStack(alignment: .leading, spacing: 0) {
                Text("one · \(data.month.lowercased()) \(String(data.year))")
                    .font(.system(size: 9.5, weight: .semibold))
                    .tracking(2)
                    .foregroundColor(.white.opacity(0.7))

                Text("\(data.daysLogged) \(NSLocalizedString("poster.days", comment: ""))\n\(data.emotionBreakdown.count) \(NSLocalizedString("poster.colours", comment: ""))")
                    .font(.system(size: 40, weight: .bold))
                    .foregroundColor(.white)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 10)

                Spacer(minLength: ONETokens.spacingLG)

                if showGrid {
                    LazyVGrid(
                        columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 7),
                        spacing: 4
                    ) {
                        ForEach(Array(data.dailyMoods.enumerated()), id: \.offset) { _, c in
                            RoundedRectangle(cornerRadius: 3, style: .continuous)
                                .fill(c.opacity(0.9))
                                .aspectRatio(1, contentMode: .fit)
                        }
                    }
                }

                Spacer(minLength: ONETokens.spacingLG)

                VStack(alignment: .leading, spacing: 3) {
                    Text(String(
                        format: NSLocalizedString("poster.mostly", comment: ""),
                        data.dominantMood
                    ))
                    .font(.system(size: 12.5))
                    .foregroundColor(.white.opacity(0.85))

                    if showSongs, let top = data.topTracks.first {
                        Text(String(
                            format: NSLocalizedString("poster.mostPlayed", comment: ""),
                            top.name
                        ))
                        .font(.system(size: 12.5))
                        .foregroundColor(.white.opacity(0.6))
                        .lineLimit(1)
                    }

                    if showNotes {
                        Text(NSLocalizedString("poster.notesHint", comment: ""))
                            .font(.system(size: 12.5))
                            .foregroundColor(.white.opacity(0.6))
                            .lineLimit(1)
                    }
                }
            }
            .padding(26)
        }
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .monoLabel(tracking: 1.3)
            .foregroundColor(V3Tokens.faintText)
            .padding(.top, ONETokens.spacingXL)
            .padding(.bottom, ONETokens.spacingSM)
    }

    // MARK: Dışa aktarma

    /// Seçili biçimin gerçek piksel boyutunda render — ekrandaki önizleme
    /// yerine posterin kendisi paylaşılıyor.
    @MainActor
    private func renderPoster() -> UIImage? {
        let width: CGFloat = 1080
        let size = CGSize(width: width, height: width / format.ratio)

        let renderer = ImageRenderer(
            content: poster.frame(width: size.width, height: size.height)
        )
        renderer.scale = 2
        return renderer.uiImage
    }

    private func share() {
        guard let image = renderPoster() else { return }
        shareItem = PosterShareItem(image: image)
    }

    private func saveToPhotos() {
        guard let image = renderPoster() else { return }
        UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
        ONEHaptics.songSaved()
    }
}

// MARK: - Paylaşım yardımcıları

struct PosterShareItem: Identifiable {
    let id = UUID()
    let image: UIImage
}

