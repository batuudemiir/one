//
//  DayDetailCarouselView.swift
//  one
//
//  Premium multi-entry day detail — swipeable card carousel
//

import SwiftUI
import CloudKit

struct DayDetailCarouselView: View {
    let entries: [DailyEntry]
    let onDismiss: () -> Void

    @State private var selectedIndex: Int = 0
    @State private var dismissOffset: CGFloat = 0
    @State private var backgroundOpacity: Double = 1.0

    private let dismissThreshold: CGFloat = 120

    var body: some View {
        ZStack {
            // Background
            Color.black.opacity(0.85 * backgroundOpacity)
                .ignoresSafeArea()
                .onTapGesture { dismiss() }

            VStack(spacing: 0) {
                // Header bar
                HStack {
                    // Date
                    if let first = entries.first {
                        Text(formatDate(first.date))
                            .font(ONETypography.bodyMDMedium)
                            .foregroundStyle(.white)
                    }

                    Spacer()

                    // Close button
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.7))
                            .frame(width: 44, height: 44)
                            .background(Circle().fill(.white.opacity(0.15)).frame(width: 32, height: 32))
                    }
                    .accessibilityLabel(NSLocalizedString("general.close", comment: ""))
                }
                .padding(.horizontal, ONETokens.spacingXL2)
                .padding(.top, ONETokens.spacingXL)

                // Page indicator
                HStack(spacing: ONETokens.spacingSM) {
                    ForEach(0..<entries.count, id: \.self) { idx in
                        Circle()
                            .fill(idx == selectedIndex
                                  ? Color(hex: entries[idx].moodColorHex)
                                  : Color.white.opacity(0.3))
                            .frame(width: idx == selectedIndex ? 8 : 6,
                                   height: idx == selectedIndex ? 8 : 6)
                    }

                    Text(String(format: NSLocalizedString("premium.today.entryCount", comment: ""),
                               selectedIndex + 1, entries.count))
                        .font(ONETypography.monoLabel)
                        .foregroundStyle(.white.opacity(0.6))
                }
                .padding(.top, ONETokens.spacingMD)

                // Card carousel
                TabView(selection: $selectedIndex) {
                    ForEach(Array(entries.enumerated()), id: \.element.id) { idx, entry in
                        entryCard(entry)
                            .tag(idx)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .padding(.top, ONETokens.spacingLG)

                Spacer()
            }
            .offset(y: dismissOffset)
        }
        .gesture(
            DragGesture()
                .onChanged { value in
                    let dy = value.translation.height
                    if dy > 0 {
                        dismissOffset = dy
                        backgroundOpacity = max(0.3, 1.0 - dy / 300)
                    }
                }
                .onEnded { value in
                    if value.translation.height > dismissThreshold {
                        dismiss()
                    } else {
                        withAnimation(ONEAnimation.cardSpring) {
                            dismissOffset = 0
                            backgroundOpacity = 1.0
                        }
                    }
                }
        )
    }

    // MARK: - Entry Card

    private func entryCard(_ entry: DailyEntry) -> some View {
        VStack(spacing: 0) {
            // Photo or mood gradient
            if let photoURL = entry.photoURL {
                CachedAsyncImage(url: photoURL) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    LinearGradient(
                        colors: [entry.moodColor.opacity(0.18), entry.moodColor.opacity(0.06)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                }
                .frame(height: 220)
                .clipped()
            } else {
                LinearGradient(
                    colors: [entry.moodColor.opacity(0.18), entry.moodColor.opacity(0.06)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .frame(height: 140)
            }

            // Song info
            VStack(alignment: .leading, spacing: ONETokens.spacingSM) {
                // Mood badge + time
                HStack {
                    Text(entry.normalizedMoodLabel)
                        .font(ONETypography.monoBase)
                        .tracking(0.5)
                        .foregroundStyle(.white)
                        .padding(.horizontal, ONETokens.spacingSM)
                        .padding(.vertical, ONETokens.spacingXS)
                        .background((ONEMood(hex: entry.moodColorHex)?.pastelColor ?? entry.moodColor).opacity(0.15))
                        .clipShape(Capsule())

                    Spacer()

                    Text(entry.time)
                        .font(ONETypography.monoSM)
                        .foregroundStyle(ONETokens.oneAsh)
                }

                // Song name + artist
                Text(entry.songName)
                    .font(ONETypography.displaySM)
                    .foregroundStyle(ONETokens.oneInk)
                    .lineLimit(2)

                Text(entry.artistName)
                    .font(ONETypography.bodySM)
                    .foregroundStyle(ONETokens.oneAsh)

                // Note
                if let note = entry.note, !note.isEmpty {
                    Text(note)
                        .font(ONETypography.bodyXS)
                        .foregroundStyle(ONETokens.oneAsh)
                        .lineLimit(3)
                        .padding(.top, ONETokens.spacingXS)
                }

                // Efemer karşılıklar yalnız bugüne ait; arşivde (geçmiş) yok.
            }
            .padding(ONETokens.spacingLG)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(ONETokens.onePaper)
        }
        .clipShape(RoundedRectangle(cornerRadius: ONETokens.radiusCardLg))
        .shadow(color: .black.opacity(0.15), radius: 12, y: 6)
        .padding(.horizontal, ONETokens.spacingXL2)
    }

    // MARK: - Helpers

    private func dismiss() {
        withAnimation(ONEAnimation.cardSpring) {
            dismissOffset = 800
            backgroundOpacity = 0
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            onDismiss()
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMMM yyyy"
        formatter.locale = LanguageManager.shared.currentLocale
        return formatter.string(from: date)
    }
}
