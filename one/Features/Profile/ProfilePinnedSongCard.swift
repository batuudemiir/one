//
//  ProfilePinnedSongCard.swift
//  one
//
//  Kendi profilindeki sabitlenmiş şarkı kartı — edit modu ile.
//  Tap → PinnedSongPickerView sheet açar.
//

import SwiftUI

struct ProfilePinnedSongCard: View {
    @ObservedObject var vm: ProfileViewModel
    @Environment(\.profilePalette) private var palette
    @Binding var showPicker: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("SABİTLENMİŞ ŞARKI")
                .monoBase(tracking: 1.5)
                .foregroundColor(palette.sectionHeader)
                .padding(.leading, 4)

            if let song = vm.pinnedSong {
                existingCard(song: song)
            } else {
                emptyState
            }
        }
    }

    // MARK: - Existing song

    private func existingCard(song: PinnedSong) -> some View {
        let moodColor = Color(hex: song.moodColorHex ?? "#9B7FD4")

        return VStack(spacing: 0) {
            // Artwork strip
            ZStack(alignment: .topTrailing) {
                artworkBackground(song: song, moodColor: moodColor)
                LinearGradient(colors: [moodColor.opacity(0.30), .clear],
                               startPoint: .top, endPoint: .bottom)
                    .frame(height: 72)

                pinChip
                    .padding(10)
            }
            .frame(height: 72)
            .clipped()

            // Song info + actions
            HStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(song.songName)
                        .displaySM()
                        .foregroundColor(palette.primaryText)
                        .lineLimit(1)
                    Text(song.artistName)
                        .monoSM(tracking: 0)
                        .foregroundColor(palette.secondaryText)
                        .lineLimit(1)
                }

                Spacer()

                contextMenuButton(song: song)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(palette.cardBG)
        .clipShape(RoundedRectangle(cornerRadius: ONETokens.radiusCardLg))
        .overlay(RoundedRectangle(cornerRadius: ONETokens.radiusCardLg).stroke(palette.cardBorder, lineWidth: 0.5))
        .shadow(color: .black.opacity(0.05), radius: 16, y: 6)
        .onTapGesture { showPicker = true }
    }

    @ViewBuilder
    private func artworkBackground(song: PinnedSong, moodColor: Color) -> some View {
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

    private func contextMenuButton(song: PinnedSong) -> some View {
        Menu {
            Button("Değiştir", systemImage: "arrow.triangle.2.circlepath") {
                showPicker = true
            }
            Button("Kaldır", systemImage: "pin.slash", role: .destructive) {
                vm.setPinnedSong(nil)
            }
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(palette.secondaryText)
                .frame(width: 32, height: 32)
        }
    }

    // MARK: - Empty state

    private var emptyState: some View {
        Button(action: { showPicker = true }) {
            HStack(spacing: 8) {
                Image(systemName: "pin")
                    .font(.system(size: 13, weight: .medium))
                Text("Bir şarkı sabitle")
                    .bodySMMedium()
            }
            .foregroundColor(ONEBrand.kor)
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .background(Capsule().fill(ONEBrand.kor.opacity(0.08)))
        }
        .buttonStyle(.plain)
    }
}
