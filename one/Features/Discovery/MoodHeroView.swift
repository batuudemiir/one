import SwiftUI

struct MoodHeroView: View {
    @ObservedObject var vm: KesfetViewModel

    private let ink = ONETokens.oneInk
    private let sub = ONETokens.oneInk.opacity(0.55)
    private let dim = ONETokens.oneInk.opacity(0.35)

    var body: some View {
        if let mood = vm.mood, let curation = vm.curation {
            ZStack {
                decorativeCircles(mood: mood)
                content(mood: mood, curation: curation)
            }
            .padding(.horizontal, 0)
            .animation(.easeInOut(duration: 0.4), value: vm.selectedMoodId)
        }
    }

    private func gradientBg(mood: KesfetMood) -> some View {
        LinearGradient(
            gradient: Gradient(stops: [
                .init(color: mood.color.opacity(0.15), location: 0),
                .init(color: mood.color.opacity(0.04), location: 0.6),
                .init(color: .clear, location: 1),
            ]),
            startPoint: UnitPoint(x: 0.5, y: 0),
            endPoint: UnitPoint(x: 0.1, y: 1)
        )
    }

    private func decorativeCircles(mood: KesfetMood) -> some View {
        GeometryReader { geo in
            Circle()
                .fill(mood.color.opacity(0.18))
                .frame(width: 200, height: 200)
                .blur(radius: 40)
                .offset(x: geo.size.width - 60, y: -60)
            Circle()
                .fill(mood.color.opacity(0.10))
                .frame(width: 160, height: 160)
                .blur(radius: 30)
                .offset(x: -40, y: geo.size.height - 40)
        }
    }

    private func content(mood: KesfetMood, curation: MoodCuration) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("ŞU AN HİSSEDİYORSUN")
                .font(.system(size: 10, weight: .semibold))
                .tracking(2.64)
                .foregroundColor(dim)
                .padding(.bottom, 10)

            moodPillButton(mood: mood)
                .padding(.bottom, 18)

            headlineText(mood: mood, curation: curation)
                .padding(.bottom, 8)

            Text(curation.line)
                .font(.system(size: 14, weight: .regular, design: .default))
                .italic()
                .foregroundColor(sub)
                .lineLimit(2)
                .frame(maxWidth: 290, alignment: .leading)
                .padding(.bottom, 12)

            inviteText(curation: curation)
                .padding(.bottom, 20)

            songChip(mood: mood)
        }
        .padding(.top, 26)
        .padding(.horizontal, 24)
        .padding(.bottom, 30)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func moodPillButton(mood: KesfetMood) -> some View {
        Button {
            NotificationCenter.default.post(name: NSNotification.Name("switchToTodayTab"), object: nil)
        } label: {
            HStack(spacing: 8) {
                Circle()
                    .fill(mood.color)
                    .frame(width: 16, height: 16)
                Text(mood.label.lowercased(with: Locale(identifier: "tr_TR")))
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(ONETokens.oneInk)
                Image(systemName: "chevron.down")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(dim)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(mood.color.opacity(0.10))
                    .overlay(Capsule().stroke(mood.color.opacity(0.55), lineWidth: 1))
            )
        }
        .buttonStyle(PlainButtonStyle())
    }

    private func headlineText(mood: KesfetMood, curation: MoodCuration) -> some View {
        Group {
            Text("Şehir ")
                .font(.system(size: 36, weight: .heavy, design: .default))
                .foregroundColor(ONETokens.oneInk)
            + Text(curation.quality)
                .font(.system(size: 36, weight: .heavy, design: .default))
                .italic()
                .foregroundColor(mood.color)
            + Text(" akşamlar için.")
                .font(.system(size: 36, weight: .heavy, design: .default))
                .foregroundColor(ONETokens.oneInk)
        }
        .tracking(-1.08)
        .lineSpacing(-1)
    }

    private func inviteText(curation: MoodCuration) -> some View {
        Group {
            Text("Bu hisle eşleşen, ")
                .font(.system(size: 13, weight: .regular))
                .foregroundColor(sub)
            + Text(curation.invite + " 14 öneri.")
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(sub)
        }
    }

    private func songChip(mood: KesfetMood) -> some View {
        Group {
            if let song = vm.orderedSongs().first {
                HStack(spacing: 10) {
                    ZStack {
                        LinearGradient(
                            colors: song.gradientColors,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        Text(song.mono)
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.white)
                    }
                    .frame(width: 28, height: 28)
                    .clipShape(RoundedRectangle(cornerRadius: 6))

                    Text(song.title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(ONETokens.oneInk)

                    Text("·")
                        .foregroundColor(dim)

                    Text(song.artist)
                        .font(.system(size: 12, weight: .regular))
                        .foregroundColor(sub)
                        .lineLimit(1)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(ONETokens.oneInk.opacity(0.04))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(mood.color.opacity(0.33), lineWidth: 1)
                        )
                )
            }
        }
    }
}
