//
//  PublicProfilePinnedSongCard.swift
//  one
//
//  Başkasının profilinde "sabitlenmiş şarkı" kartı — salt okunur.
//

import SwiftUI

struct PublicProfilePinnedSongCard: View {
    let song: PinnedSong

    private var moodColor: Color {
        Color(hex: song.moodColorHex ?? "#9B7FD4")
    }

    var body: some View {
        VStack(spacing: 0) {
            artworkStrip
            songInfo
        }
        .background(V3Tokens.surface)
        .clipShape(RoundedRectangle(cornerRadius: V3Tokens.radiusCard))
        .shadow(color: .black.opacity(0.05), radius: 16, y: 6)
        .overlay(
            RoundedRectangle(cornerRadius: V3Tokens.radiusCard)
                .stroke(V3Tokens.hairline, lineWidth: 0.5)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Sabitlenmiş şarkı: \(song.songName), \(song.artistName)")
    }

    // MARK: - Artwork strip

    private var artworkStrip: some View {
        ZStack(alignment: .topTrailing) {
            artworkBackground

            LinearGradient(
                colors: [moodColor.opacity(0.30), .clear],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 72)

            pinChip
                .padding(10)
        }
        .frame(height: 72)
        .clipped()
    }

    @ViewBuilder
    private var artworkBackground: some View {
        if let urlStr = song.artworkURLString, urlStr.hasPrefix("https://"), let url = URL(string: urlStr) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().aspectRatio(contentMode: .fill)
                default:
                    moodColor.opacity(0.3)
                }
            }
            .frame(height: 72)
            .clipped()
        } else {
            moodColor.opacity(0.30).frame(height: 72)
        }
    }

    private var pinChip: some View {
        HStack(spacing: V3Tokens.spacingXS) {
            Image(systemName: "pin.fill")
                .font(.system(size: 9, weight: .medium))
            Text(NSLocalizedString("profile.pinned", comment: ""))
                .monoLabel(tracking: 0.3)
        }
        .foregroundStyle(V3Tokens.darkText)
        .padding(.horizontal, V3Tokens.spacingSM)
        .padding(.vertical, V3Tokens.spacingXS)
        .background(Capsule().fill(.black.opacity(0.22)))
    }

    // MARK: - Song info

    private var songInfo: some View {
        VStack(alignment: .leading, spacing: V3Tokens.spacingXS) {
            Text(song.songName)
                .displaySM()
                .foregroundStyle(V3Tokens.ink)
                .lineLimit(1)
            Text(song.artistName)
                .monoSM(tracking: 0)
                .foregroundStyle(V3Tokens.mutedText)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, V3Tokens.spacingLG)
        .padding(.vertical, V3Tokens.spacingMD)
    }
}
