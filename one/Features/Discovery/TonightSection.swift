import SwiftUI

struct TonightSection: View {
    @ObservedObject var  vm: KesfetViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionHead
                .padding(.horizontal, 24)
                .padding(.bottom, 14)
                .padding(.top, 36)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 12) {
                    ForEach(vm.orderedVenues()) { venue in
                        venueCard(venue)
                    }
                }
                .padding(.horizontal, 24)
            }
        }
    }

    private var sectionHead: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 4) {
                Text("BU AKŞAM İSTANBUL'DA")
                    .font(.system(size: 10.5, weight: .semibold))
                    .tracking(1.89)
                    .foregroundColor(ONETokens.oneInk.opacity(0.35))
                Text("Sana yakın sahneler")
                    .font(.system(size: 22, weight: .bold))
                    .tracking(-0.44)
                    .foregroundColor(ONETokens.oneInk)
            }
            Spacer()
        }
    }

    @ViewBuilder
    private func venueCard(_ venue: KesfetVenue) -> some View {
        let isMatch = venue.moodId == vm.selectedMoodId
        VStack(alignment: .leading, spacing: 6) {
            ZStack(alignment: .topTrailing) {
                ZStack(alignment: .bottom) {
                    cardBackground(venue)
                    monogramOverlay(venue)
                    bottomGlass(venue)
                }
                .clipShape(RoundedRectangle(cornerRadius: 18))
                .frame(width: 180)
                .aspectRatio(5.0/7.0, contentMode: .fit)

                if isMatch {
                    Circle()
                        .fill(.white)
                        .frame(width: 8, height: 8)
                        .padding(10)
                }
            }

            HStack {
                Text("\(venue.neighborhood) · \(venue.distance)")
                    .font(.system(size: 11, weight: .regular))
                    .foregroundColor(ONETokens.oneInk.opacity(0.35))
                Spacer()
                Text(venue.time)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(ONETokens.oneInk.opacity(0.55))
            }
            .frame(width: 180)

            if isMatch {
                Text("hissinle aynı")
                    .font(.system(size: 10.5, weight: .semibold))
                    .foregroundColor(vm.mood?.color ?? ONETokens.oneBrand)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(
                        Capsule().fill((vm.mood?.color ?? ONETokens.oneBrand).opacity(0.12))
                    )
            }
        }
        .onTapGesture {
            vm.venueSheetPayload = vm.venuePayload(for: venue)
        }
    }

    private func cardBackground(_ venue: KesfetVenue) -> some View {
        ZStack {
            LinearGradient(
                colors: venue.gradientColors,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            RadialGradient(
                colors: [.white.opacity(0.14), .clear],
                center: .topLeading,
                startRadius: 0,
                endRadius: 120
            )
        }
    }

    private func monogramOverlay(_ venue: KesfetVenue) -> some View {
        Text(venue.poster)
            .font(.system(size: 48, weight: .black))
            .foregroundColor(.white.opacity(0.18))
            .frame(width: 96, height: 96)
    }

    private func bottomGlass(_ venue: KesfetVenue) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(venue.kind.uppercased())
                .font(.system(size: 9.5, weight: .semibold))
                .tracking(1.2)
                .foregroundColor(.white.opacity(0.7))
            Text(venue.name)
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.white)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
    }
}
