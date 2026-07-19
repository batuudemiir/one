import SwiftUI

struct ArtistSpotlightCard: View {
    @ObservedObject var vm: KesfetViewModel

    var body: some View {
        if let artist = vm.curation?.artist {
            ZStack {
                artistBackground(for: artist)
                decorativeCircles
                cardContent(for: artist)
            }
            .clipShape(RoundedRectangle(cornerRadius: 22))
            .padding(.horizontal, 24)
            .padding(.top, 36)
            .onTapGesture {
                if let payload = vm.artistPayload() {
                    vm.venueSheetPayload = payload
                }
            }
            .animation(.easeInOut(duration: 0.4), value: vm.selectedMoodId)
        }
    }

    private func artistBackground(for artist: ArtistCuration) -> some View {
        LinearGradient(
            colors: artist.gradientColors,
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var decorativeCircles: some View {
        GeometryReader { geo in
            Circle()
                .fill(.white.opacity(0.08))
                .frame(width: 180, height: 180)
                .offset(x: geo.size.width - 50, y: -50)
            Circle()
                .fill(.black.opacity(0.18))
                .frame(width: 150, height: 150)
                .offset(x: -30, y: geo.size.height - 60)
        }
    }

    private func cardContent(for artist: ArtistCuration) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            topRow(for: artist)
                .padding(.horizontal, 20)
                .padding(.top, 20)

            Divider()
                .background(.white.opacity(0.16))
                .padding(.horizontal, 20)
                .padding(.vertical, 16)

            bottomRow(for: artist)
                .padding(.horizontal, 20)
                .padding(.bottom, 22)
        }
    }

    private func topRow(for artist: ArtistCuration) -> some View {
        HStack(spacing: 14) {
            avatarCircle(for: artist)
            VStack(alignment: .leading, spacing: 3) {
                Text(artist.intent)
                    .font(.system(size: 10.5, weight: .semibold))
                    .tracking(1.89)
                    .foregroundColor(.white.opacity(0.7))
                Text(artist.name)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.white)
            }
        }
    }

    private func avatarCircle(for artist: ArtistCuration) -> some View {
        ZStack {
            Circle()
                .fill(.white.opacity(0.16))
                .background(Circle().fill(.ultraThinMaterial))
                .overlay(Circle().stroke(.white, lineWidth: 1))
            Text(artist.mono)
                .font(.system(size: 22, weight: .black))
                .foregroundColor(.white)
        }
        .frame(width: 64, height: 64)
    }

    private func bottomRow(for artist: ArtistCuration) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text(artist.date)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.white)
                Text(artist.venue)
                    .font(.system(size: 11, weight: .regular))
                    .foregroundColor(.white.opacity(0.7))
            }
            Spacer()
            remindButton
        }
    }

    private var remindButton: some View {
        HStack(spacing: 6) {
            Image(systemName: "bell")
                .font(.system(size: 12, weight: .semibold))
            Text("Hatırlat")
                .font(.system(size: 13, weight: .semibold))
        }
        .foregroundColor(Color(hex: "#1A1A1E"))
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Capsule().fill(.white))
    }
}
