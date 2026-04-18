//
//  FeaturedSongCard.swift
//  one
//
//  Keşfet sekmesi — Cinematic featured song card
//  · Full-bleed album art with mood-tinted gradient overlay
//  · Mood-coloured glow shadow — the card glows with the user's emotion
//  · Play indicator + platform badge + recommendation reason
//

import SwiftUI

struct FeaturedSongCard: View {
    let recommendation: SongRecommendation
    let moodColor: Color?
    let onTap: () -> Void

    private var accent: Color { moodColor ?? ONETokens.oneBrand }

    var body: some View {
        Button(action: {
            ONEHaptics.feelingSelected()
            onTap()
        }) {
            ZStack(alignment: .bottom) {

                // ── Album artwork — full bleed ─────────────────────────
                artworkLayer
                    .frame(height: 232)
                    .clipped()

                // ── Cinematic gradient overlay ─────────────────────────
                // Mood colour bleeds in from the bottom, dark fade from top
                LinearGradient(
                    colors: [
                        .clear,
                        .black.opacity(0.08),
                        accent.opacity(0.25),
                        .black.opacity(0.78)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )

                // ── Play indicator (top-right) ─────────────────────────
                VStack {
                    HStack {
                        Spacer()
                        Image(systemName: "play.circle.fill")
                            .font(.system(size: 30, weight: .medium))
                            .foregroundStyle(.white.opacity(0.85))
                            .shadow(color: .black.opacity(0.25), radius: 6, x: 0, y: 2)
                            .padding(16)
                    }
                    Spacer()
                }

                // ── Song info (bottom) ─────────────────────────────────
                VStack(alignment: .leading, spacing: 7) {
                    // Recommendation reason
                    if let reason = recommendation.recommendationReason {
                        HStack(spacing: 4) {
                            Image(systemName: "sparkles")
                                .font(.system(size: 8, weight: .medium))
                            Text(reason.uppercased())
                                .monoLabel(tracking: 0.9)
                        }
                        .foregroundColor(.white.opacity(0.65))
                    }

                    // Song title
                    Text(recommendation.name)
                        .displayXS()
                        .foregroundColor(.white)
                        .lineLimit(2)
                        .shadow(color: .black.opacity(0.35), radius: 4, x: 0, y: 2)

                    // Artist
                    Text(recommendation.artist)
                        .bodySM()
                        .foregroundColor(.white.opacity(0.82))

                    // Platform badge
                    HStack(spacing: 5) {
                        Image(systemName: recommendation.source == .spotify ? "music.note" : "applelogo")
                            .font(.system(size: 9, weight: .semibold))
                        Text(recommendation.source == .spotify
                             ? NSLocalizedString("discover.listenOnSpotify", comment: "")
                             : NSLocalizedString("discover.listenOnAppleMusic", comment: ""))
                            .monoLabel(tracking: 0.5)
                    }
                    .foregroundColor(.white.opacity(0.70))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(
                        Capsule()
                            .fill(.white.opacity(0.14))
                            .overlay(Capsule().strokeBorder(.white.opacity(0.18), lineWidth: 0.5))
                    )
                    .padding(.top, 2)
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(height: 232)
            .clipShape(RoundedRectangle(cornerRadius: ONETokens.radiusCard))
            // Mood glow — the card emanates the user's emotional colour
            .shadow(color: accent.opacity(0.34), radius: 28, x: 0, y: 12)
            .shadow(color: .black.opacity(0.08), radius: 4, x: 0, y: 2)
        }
        .buttonStyle(RecommendationCardButtonStyle())
    }

    // MARK: - Artwork

    @ViewBuilder
    private var artworkLayer: some View {
        if let url = recommendation.coverURL {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                case .failure:
                    fallbackGradient
                case .empty:
                    ZStack {
                        accent.opacity(0.28)
                        ProgressView()
                            .tint(.white.opacity(0.6))
                    }
                @unknown default:
                    fallbackGradient
                }
            }
        } else {
            fallbackGradient
        }
    }

    private var fallbackGradient: some View {
        ZStack {
            LinearGradient(
                colors: [accent.opacity(0.65), ONETokens.oneShadow],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Image(systemName: "music.note")
                .font(.system(size: 52, weight: .light))
                .foregroundColor(.white.opacity(0.28))
        }
    }
}
