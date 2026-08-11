import SwiftUI

struct KesfetFeaturedCard: View {
    @ObservedObject var vm: KesfetViewModel

    var body: some View {
        if let featured = vm.curation?.featured, let mood = vm.mood {
            VStack(alignment: .leading, spacing: 14) {
                sectionEyebrow
                card(featured: featured, mood: mood)
            }
            .padding(.horizontal, 24)
            .padding(.top, 32)
            .animation(.easeInOut(duration: 0.4), value: vm.selectedMoodId)
        }
    }

    private var sectionEyebrow: some View {
        Text("BU AKŞAMIN GÖZDESİ")
            .font(V3Typography.sans(10.5, weight: .semibold))
            .tracking(1.89)
            .foregroundColor(V3Tokens.ink.opacity(0.35))
    }

    private func card(featured: FeaturedCuration, mood: KesfetMood) -> some View {
        ZStack(alignment: .topLeading) {
            cardBackground(mood: mood)
            arcOverlay
            cardContent(featured: featured)
        }
        .clipShape(RoundedRectangle(cornerRadius: 22))
        .shadow(color: Color.black.opacity(0.35), radius: 18, x: 0, y: 18)
        .shadow(color: Color.black.opacity(0.18), radius: 7, x: 0, y: 6)
        .frame(minHeight: 280)
        .onTapGesture {
            vm.venueSheetPayload = vm.featuredPayload()
        }
    }

    private func cardBackground(mood: KesfetMood) -> some View {
        LinearGradient(
            colors: [mood.color, Color(hex: "#112a20")],
            startPoint: UnitPoint(x: 0.2, y: 0),
            endPoint: UnitPoint(x: 0.8, y: 1)
        )
    }

    private var arcOverlay: some View {
        GeometryReader { geo in
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.18), lineWidth: 1.5)
                    .frame(width: 120, height: 120)
                    .offset(x: geo.size.width - 30, y: -30)
                Circle()
                    .stroke(Color.white.opacity(0.18), lineWidth: 1.5)
                    .frame(width: 190, height: 190)
                    .offset(x: geo.size.width - 65, y: -65)
                Circle()
                    .stroke(Color.white.opacity(0.18), lineWidth: 1.5)
                    .frame(width: 260, height: 260)
                    .offset(x: geo.size.width - 100, y: -100)
            }
        }
        .clipped()
    }

    private func cardContent(featured: FeaturedCuration) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                tagPill(featured: featured)
                Spacer()
                matchPill
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)

            Spacer()

            VStack(alignment: .leading, spacing: 6) {
                titleText(featured: featured)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 2)

                Text("\(featured.sub) · \(featured.time)")
                    .font(V3Typography.sans(13, weight: .regular))
                    .foregroundColor(.white.opacity(0.75))
                    .padding(.horizontal, 16)

                Text("\(featured.going) kişi gidiyor · \(featured.distance)")
                    .font(V3Typography.sans(12, weight: .regular))
                    .foregroundColor(.white.opacity(0.55))
                    .padding(.horizontal, 16)

                HStack {
                    ticketButton
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 18)
            }
        }
        .frame(minHeight: 280)
    }

    private func titleText(featured: FeaturedCuration) -> some View {
        Text(featured.title)
            .font(V3Typography.sans(28, weight: .bold))
            .foregroundColor(.white)
            .lineLimit(nil)
            .fixedSize(horizontal: false, vertical: true)
            .multilineTextAlignment(.leading)
    }

    private func tagPill(featured: FeaturedCuration) -> some View {
        HStack(spacing: 5) {
            Image(systemName: "mic.fill")
                .font(.system(size: 10))
            Text(featured.tag)
                .font(V3Typography.sans(11, weight: .semibold))
                .tracking(0.5)
        }
        .foregroundColor(.white)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(.white.opacity(0.14))
                .background(
                    Capsule().fill(.ultraThinMaterial)
                )
        )
    }

    private var matchPill: some View {
        HStack(spacing: 4) {
            Image(systemName: "sparkles")
                .font(.system(size: 10))
            Text("hissine uyar")
                .font(V3Typography.sans(11, weight: .semibold))
        }
        .foregroundColor(.white)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(.white.opacity(0.14))
                .background(
                    Capsule().fill(.ultraThinMaterial)
                )
        )
    }

    private var ticketButton: some View {
        Text("Bilet Al")
            .font(V3Typography.sans(13, weight: .semibold))
            .foregroundColor(V3Tokens.ink)
            .padding(.horizontal, 20)
            .padding(.vertical, 8)
            .background(Capsule().fill(.white))
    }
}
