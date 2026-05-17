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
        .background(ONETokens.onePaper)
        .clipShape(RoundedRectangle(cornerRadius: ONETokens.radiusCardLg))
        .shadow(color: .black.opacity(0.05), radius: 16, y: 6)
        .overlay(
            RoundedRectangle(cornerRadius: ONETokens.radiusCardLg)
                .stroke(ONETokens.oneSilver, lineWidth: 0.5)
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
        HStack(spacing: 4) {
            Image(systemName: "pin.fill")
                .font(.system(size: 9, weight: .medium))
            Text("sabitlenmiş")
                .monoLabel(tracking: 0.3)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Capsule().fill(.black.opacity(0.22)))
    }

    // MARK: - Song info

    private var songInfo: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(song.songName)
                .displaySM()
                .foregroundStyle(ONETokens.oneInk)
                .lineLimit(1)
            Text(song.artistName)
                .monoSM(tracking: 0)
                .foregroundStyle(ONETokens.oneCharcoal)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}
