//
//  WeeklyPlaylistView.swift
//  one
//
//  Haftalık mood playlist — Apple Design Award kalitesinde karanlık, sürükleyici tasarım.
//

import SwiftUI
import CoreData

struct WeeklyPlaylistView: View {
    @StateObject private var service: WeeklyPlaylistService
    @Environment(\.dismiss) var dismiss
    @State private var appeared = false
    @State private var selectedMoodBubble: String? = nil

    init(context: NSManagedObjectContext) {
        _service = StateObject(wrappedValue: WeeklyPlaylistService(context: context))
    }

    // MARK: - Dominant Mood Color

    private var dominantColor: Color {
        guard let top = service.moodDistribution.first else { return ONETokens.oneBlue }
        return Color(hex: top.color)
    }

    // MARK: - Week Date Range

    private var weekDateRangeString: String {
        guard let first = service.weekEntries.last?.date,
              let last  = service.weekEntries.first?.date else { return "" }
        let fmt = DateFormatter()
        fmt.locale = LanguageManager.shared.currentLocale
        fmt.dateFormat = "d MMM"
        return "\(fmt.string(from: first)) – \(fmt.string(from: last))"
    }

    // MARK: - Body

    var body: some View {
        ZStack(alignment: .top) {
            Color.black.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {

                    // Full-bleed hero header
                    heroSection
                        .opacity(appeared ? 1 : 0)
                        .animation(.easeOut(duration: 0.5), value: appeared)

                    if service.weekEntries.count < 3 {
                        insufficientDataView
                            .padding(.top, 48)
                            .padding(.horizontal, 24)
                            .opacity(appeared ? 1 : 0)
                            .animation(.easeOut(duration: 0.5).delay(0.1), value: appeared)
                    } else {

                        // Week in Review
                        weekReviewSection
                            .padding(.top, 32)
                            .padding(.horizontal, 20)
                            .offset(y: appeared ? 0 : 16)
                            .opacity(appeared ? 1 : 0)
                            .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.12), value: appeared)

                        // Recommendations
                        recommendationsSection
                            .padding(.top, 28)
                            .padding(.horizontal, 20)
                            .offset(y: appeared ? 0 : 16)
                            .opacity(appeared ? 1 : 0)
                            .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.2), value: appeared)

                        // Save CTA
                        saveCTASection
                            .padding(.top, 24)
                            .padding(.horizontal, 20)
                            .offset(y: appeared ? 0 : 16)
                            .opacity(appeared ? 1 : 0)
                            .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.28), value: appeared)
                    }

                    Spacer().frame(height: 80)
                }
            }

            // Close button (top-leading)
            VStack {
                HStack {
                    Button(action: { dismiss() }) {
                        ZStack {
                            Circle()
                                .fill(Color.white.opacity(0.14))
                                .frame(width: 36, height: 36)
                            Image(systemName: "xmark")
                                .bodySM().fontWeight(.semibold)
                                .foregroundColor(.white.opacity(0.85))
                        }
                    }
                    .padding(.leading, 20)
                    .padding(.top, 56)
                    Spacer()
                }
                Spacer()
            }
        }
        .navigationBarHidden(true)
        .task {
            service.loadCurrentWeek()
            await service.fetchPlaylist()
            withAnimation { appeared = true }
        }
    }

    // MARK: - Hero Section

    private var heroSection: some View {
        ZStack(alignment: .bottomLeading) {
            // Gradient background derived from dominant mood
            LinearGradient(
                colors: [
                    dominantColor.opacity(0.80),
                    dominantColor.opacity(0.30),
                    Color.black
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 280)

            // Decorative blurred circle for depth
            Circle()
                .fill(dominantColor.opacity(0.35))
                .frame(width: 200, height: 200)
                .blur(radius: 60)
                .offset(x: 220, y: -60)
                .allowsHitTesting(false)

            VStack(alignment: .leading, spacing: 16) {
                Spacer()

                // Title
                VStack(alignment: .leading, spacing: 6) {
                    Text("HAFTALIK MİX")
                        .monoSM().fontWeight(.semibold)
                        .tracking(2.5)
                        .foregroundColor(.white.opacity(0.55))

                    if !weekDateRangeString.isEmpty {
                        Text(weekDateRangeString)
                            .font(ONETypography.displayHero)
                            .fontWeight(.black)
                            .foregroundColor(.white)
                            .lineSpacing(2)
                    }
                }

                // Mood pills
                if !service.moodDistribution.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(service.moodDistribution, id: \.mood) { item in
                                moodPill(item: item)
                            }
                        }
                        .padding(.horizontal, 24)
                    }
                    .padding(.horizontal, -24)
                }

                // Stats row
                HStack(spacing: 16) {
                    if !service.weekEntries.isEmpty {
                        Label("\(service.weekEntries.count) gün", systemImage: "calendar")
                            .font(ONETypography.monoBase)
                            .fontWeight(.medium)
                            .foregroundColor(.white.opacity(0.6))
                    }
                    if let mood = service.dominantMood {
                        Rectangle()
                            .fill(Color.white.opacity(0.25))
                            .frame(width: 1, height: 12)
                        Label(mood, systemImage: "waveform")
                            .font(ONETypography.monoBase)
                            .fontWeight(.medium)
                            .foregroundColor(.white.opacity(0.6))
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 28)
        }
        .frame(height: 280)
    }

    private func moodPill(item: (mood: String, color: String, count: Int)) -> some View {
        let isSelected = selectedMoodBubble == item.mood
        return Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                selectedMoodBubble = isSelected ? nil : item.mood
            }
        } label: {
            HStack(spacing: 6) {
                Circle()
                    .fill(Color(hex: item.color))
                    .frame(width: 8, height: 8)
                Text(item.mood)
                    .monoBase().fontWeight(.semibold)
                    .foregroundColor(.white)
                Text("×\(item.count)")
                    .monoLabel()
                    .foregroundColor(.white.opacity(0.6))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(
                Capsule()
                    .fill(isSelected
                          ? Color(hex: item.color).opacity(0.55)
                          : Color.white.opacity(0.15))
            )
            .overlay(
                Capsule()
                    .stroke(Color.white.opacity(isSelected ? 0.4 : 0.18), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Insufficient Data

    private var insufficientDataView: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.06))
                    .frame(width: 72, height: 72)
                Image(systemName: "music.note.list")
                    .displayMD()
                    .foregroundColor(.white.opacity(0.4))
            }

            VStack(spacing: 8) {
                Text(NSLocalizedString("discover.minSelections", comment: ""))
                    .bodyXL().fontWeight(.bold)
                    .foregroundColor(.white)

                Text(NSLocalizedString("discover.minSelectionsHint", comment: ""))
                    .bodySM()
                    .foregroundColor(.white.opacity(0.55))
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }

            Text(String(format: NSLocalizedString("discover.daysCompleted", comment: ""), service.weekEntries.count))
                .monoBase().fontWeight(.semibold)
                .foregroundColor(.white.opacity(0.4))
                .tracking(0.6)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Week in Review

    private var weekReviewSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("HAFTANIN GEZİNTİSİ")
                .monoLabel().fontWeight(.semibold)
                .tracking(2)
                .foregroundColor(.white.opacity(0.45))

            VStack(spacing: 0) {
                ForEach(Array(service.weekEntries.enumerated()), id: \.element.id) { idx, entry in
                    weekEntryRow(entry: entry, index: idx)

                    if idx < service.weekEntries.count - 1 {
                        Divider()
                            .background(Color.white.opacity(0.07))
                            .padding(.leading, 16)
                    }
                }
            }
            .background(
                RoundedRectangle(cornerRadius: ONETokens.radiusCardLg)
                    .fill(Color.white.opacity(0.06))
            )
            .overlay(
                RoundedRectangle(cornerRadius: ONETokens.radiusCardLg)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )
        }
    }

    private func weekEntryRow(entry: DailyEntry, index: Int) -> some View {
        let dayFmt: DateFormatter = {
            let f = DateFormatter()
            f.locale = LanguageManager.shared.currentLocale
            f.dateFormat = "EEE"
            return f
        }()
        let numFmt: DateFormatter = {
            let f = DateFormatter()
            f.dateFormat = "d"
            return f
        }()

        return HStack(spacing: 14) {
            // Day column
            VStack(spacing: 1) {
                Text(dayFmt.string(from: entry.date).uppercased())
                    .monoMicro().fontWeight(.semibold)
                    .tracking(0.5)
                    .foregroundColor(.white.opacity(0.4))
                Text(numFmt.string(from: entry.date))
                    .bodyXL().fontWeight(.black)
                    .foregroundColor(.white.opacity(0.85))
            }
            .frame(width: 32)

            // Mood color thumbnail
            RoundedRectangle(cornerRadius: 10)
                .fill(entry.moodColor.opacity(0.35))
                .frame(width: 46, height: 46)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(entry.moodColor.opacity(0.5), lineWidth: 1)
                )
                .overlay(
                    Image(systemName: "music.note")
                        .bodySMMedium()
                        .foregroundColor(entry.moodColor)
                )

            // Song info
            VStack(alignment: .leading, spacing: 3) {
                Text(entry.songName)
                    .bodySM().fontWeight(.semibold)
                    .foregroundColor(.white)
                    .lineLimit(1)
                Text(entry.artistName)
                    .monoBase()
                    .foregroundColor(.white.opacity(0.5))
                    .lineLimit(1)
            }

            Spacer()

            // Mood label capsule
            if !entry.normalizedMoodLabel.isEmpty {
                Text(entry.normalizedMoodLabel)
                    .monoMicro().fontWeight(.semibold)
                    .foregroundColor(entry.moodColor)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(entry.moodColor.opacity(0.15)))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
    }

    // MARK: - Recommendations

    private var recommendationsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("ÖNERİLER")
                    .monoLabel().fontWeight(.semibold)
                    .tracking(2)
                    .foregroundColor(.white.opacity(0.45))
                Spacer()
                if !service.playlistSongs.isEmpty {
                    Text("\(service.playlistSongs.count) şarkı")
                        .monoSM()
                        .foregroundColor(.white.opacity(0.3))
                }
            }

            if service.isLoading {
                HStack {
                    Spacer()
                    ProgressView()
                        .tint(.white)
                        .scaleEffect(0.85)
                    Spacer()
                }
                .padding(.vertical, 30)
            } else {
                VStack(spacing: 12) {
                    ForEach(service.playlistSongs) { song in
                        recommendationCard(song: song)
                    }
                }
            }
        }
    }

    private func recommendationCard(song: SongRecommendation) -> some View {
        Button {
            if let urlStr = song.spotifyURL, let url = URL(string: urlStr) {
                UIApplication.shared.open(url)
            }
        } label: {
            HStack(spacing: 14) {
                // Artwork
                CachedAsyncImage(url: song.coverURL) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    ZStack {
                        RoundedRectangle(cornerRadius: ONETokens.radiusCover)
                            .fill(Color.white.opacity(0.08))
                        Image(systemName: "music.note")
                            .bodyXL()
                            .foregroundColor(.white.opacity(0.3))
                    }
                }
                .frame(width: 72, height: 72)
                .clipShape(RoundedRectangle(cornerRadius: ONETokens.radiusCover))
                .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)

                // Info
                VStack(alignment: .leading, spacing: 5) {
                    Text(song.name)
                        .bodySM().fontWeight(.semibold)
                        .foregroundColor(.white)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)

                    Text(song.artist)
                        .monoBase()
                        .foregroundColor(.white.opacity(0.5))
                        .lineLimit(1)

                    HStack(spacing: 6) {
                        Image(systemName: song.source == .spotify ? "music.note" : "applelogo")
                            .monoMicro()
                            .foregroundColor(.white.opacity(0.3))
                    }
                }

                Spacer()

                Image(systemName: "arrow.up.right")
                    .monoSM().fontWeight(.semibold)
                    .foregroundColor(.white.opacity(0.25))
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: ONETokens.radiusCardLg)
                    .fill(Color.white.opacity(0.06))
            )
            .overlay(
                RoundedRectangle(cornerRadius: ONETokens.radiusCardLg)
                    .stroke(Color.white.opacity(0.07), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Save CTA

    private var saveCTASection: some View {
        VStack(spacing: 12) {
            if let url = service.createdPlaylistURL {
                // Success state
                Button { UIApplication.shared.open(url) } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "checkmark.circle.fill")
                            .bodyLG()
                            .foregroundStyle(ONETokens.oneGreen)
                        Text(NSLocalizedString("premium.playlist.openAppleMusic", comment: ""))
                            .bodyMD().fontWeight(.semibold)
                            .foregroundStyle(.white)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(
                        RoundedRectangle(cornerRadius: ONETokens.radiusCardLg)
                            .fill(ONETokens.oneGreen.opacity(0.18))
                            .overlay(
                                RoundedRectangle(cornerRadius: ONETokens.radiusCardLg)
                                    .stroke(ONETokens.oneGreen.opacity(0.35), lineWidth: 1)
                            )
                    )
                }
                .buttonStyle(.plain)
            } else {
                // Save button
                Button {
                    Task { await service.createAppleMusicPlaylist() }
                } label: {
                    HStack(spacing: 10) {
                        if service.isCreatingPlaylist {
                            ProgressView()
                                .tint(.white)
                                .scaleEffect(0.85)
                        } else {
                            Image(systemName: "music.note.list")
                                .bodyMD().fontWeight(.semibold)
                        }
                        Text(NSLocalizedString("premium.playlist.saveAppleMusic", comment: ""))
                            .bodyMD().fontWeight(.semibold)
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(
                        RoundedRectangle(cornerRadius: ONETokens.radiusCardLg)
                            .fill(
                                LinearGradient(
                                    colors: [ONETokens.oneBrand, ONETokens.oneBrandLight],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                    )
                    .shadow(color: ONETokens.oneBrand.opacity(0.4), radius: 12, x: 0, y: 6)
                }
                .buttonStyle(.plain)
                .disabled(service.isCreatingPlaylist || service.playlistSongs.isEmpty)
                .opacity(service.playlistSongs.isEmpty ? 0.5 : 1)
            }

            if let error = service.playlistError {
                Text(error)
                    .monoBase()
                    .foregroundStyle(ONETokens.oneBrandLight)
                    .multilineTextAlignment(.center)
            }
        }
    }
}
