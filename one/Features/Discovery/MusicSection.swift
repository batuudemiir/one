import SwiftUI

struct MusicSection: View {
    @ObservedObject var vm: KesfetViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionHead
                .padding(.horizontal, 24)
                .padding(.bottom, 14)
                .padding(.top, 36)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 14) {
                    ForEach(vm.orderedSongs()) { song in
                        songCard(song)
                    }
                }
                .padding(.horizontal, 24)
            }
        }
    }

    private var sectionHead: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 4) {
                Text("HİSSİNE GÖRE DİNLE")
                    .font(.system(size: 10.5, weight: .semibold))
                    .tracking(1.89)
                    .foregroundColor(ONETokens.oneInk.opacity(0.35))
                Text("Bu akşamın sesi")
                    .font(.system(size: 22, weight: .bold))
                    .tracking(-0.44)
                    .foregroundColor(ONETokens.oneInk)
            }
            Spacer()
            Button {
            } label: {
                HStack(spacing: 2) {
                    Text("Yenile")
                        .font(.system(size: 13, weight: .medium))
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 10, weight: .semibold))
                }
                .foregroundColor(ONETokens.oneInk.opacity(0.35))
            }
        }
    }

    @ViewBuilder
    private func songCard(_ song: KesfetSong) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            ZStack {
                LinearGradient(
                    colors: song.gradientColors,
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                Text(song.mono)
                    .font(.system(size: 28, weight: .black))
                    .foregroundColor(.white.opacity(0.35))
            }
            .frame(width: 144, height: 144)
            .clipShape(RoundedRectangle(cornerRadius: 12))

            Text(song.title)
                .font(.system(size: 13.5, weight: .bold))
                .foregroundColor(ONETokens.oneInk)
                .lineLimit(1)
                .frame(width: 144, alignment: .leading)

            Text(song.artist)
                .font(.system(size: 11.5, weight: .regular))
                .foregroundColor(ONETokens.oneInk.opacity(0.55))
                .lineLimit(1)
                .frame(width: 144, alignment: .leading)

            HStack(spacing: 4) {
                Circle()
                    .fill(vm.mood?.color ?? ONETokens.oneBrand)
                    .frame(width: 6, height: 6)
                Text("\((vm.mood?.label ?? "").lowercased(with: Locale(identifier: "tr_TR"))) eşleşmesi")
                    .font(.system(size: 10.5, weight: .regular))
                    .foregroundColor(ONETokens.oneInk.opacity(0.35))
            }
        }
    }
}
