import SwiftUI

struct WeekSection: View {
    @ObservedObject var vm: KesfetViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionHead
                .padding(.horizontal, 24)
                .padding(.bottom, 14)
                .padding(.top, 36)

            VStack(spacing: 10) {
                ForEach(Array(KESFET_WEEK_EVENTS.enumerated()), id: \.element.id) { idx, event in
                    let weekIdx = vm.curation?.weekIdx ?? -1
                    let starred = KESFET_WEEK_EVENTS.indices.contains(weekIdx) && idx == weekIdx
                    eventRow(event, isStarred: starred, index: idx)
                }
            }
            .padding(.horizontal, 24)
        }
    }

    private var sectionHead: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 4) {
                Text("HAFTA İÇİ")
                    .font(V3Typography.sans(10.5, weight: .semibold))
                    .tracking(1.89)
                    .foregroundColor(V3Tokens.ink.opacity(0.35))
                Text("Sonraki günlerde")
                    .font(V3Typography.sans(22, weight: .bold))
                    .tracking(-0.44)
                    .foregroundColor(V3Tokens.ink)
            }
            Spacer()
            Button {
                if let url = URL(string: "calshow://") {
                    UIApplication.shared.open(url)
                }
            } label: {
                HStack(spacing: 2) {
                    Text("Takvim")
                        .font(V3Typography.sans(13, weight: .medium))
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                }
                .foregroundColor(V3Tokens.ink.opacity(0.35))
            }
        }
    }

    @ViewBuilder
    private func eventRow(_ event: KesfetWeekEvent, isStarred: Bool, index: Int) -> some View {
        let eventMood = moodFor(event.moodId)
        VStack(spacing: 0) {
            if isStarred {
                HStack {
                    Text("SENİN İÇİN")
                        .font(V3Typography.sans(9, weight: .bold))
                        .tracking(1.2)
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(eventMood.color))
                        .padding(.leading, 16)
                    Spacer()
                }
                .padding(.bottom, -6)
                .zIndex(1)
            }

            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(eventMood.color.opacity(0.10))
                        .frame(width: 50, height: 50)
                    VStack(spacing: 0) {
                        Text(event.day)
                            .font(V3Typography.sans(9, weight: .semibold))
                            .foregroundColor(eventMood.color)
                        Text(event.date)
                            .font(V3Typography.sans(19, weight: .bold))
                            .foregroundColor(V3Tokens.ink)
                    }
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(event.title)
                        .font(V3Typography.sans(15, weight: .semibold))
                        .foregroundColor(V3Tokens.ink)
                    Text("\(event.venue) · \(event.time)")
                        .font(V3Typography.sans(12, weight: .regular))
                        .foregroundColor(V3Tokens.ink.opacity(0.55))
                }

                Spacer()

                Text(eventMood.label)
                    .font(V3Typography.sans(10, weight: .semibold))
                    .tracking(0.5)
                    .foregroundColor(eventMood.color)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule().fill(eventMood.color.opacity(0.14))
                    )
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(ONEBrand.bone)
                    .overlay(
                        isStarred
                        ? RoundedRectangle(cornerRadius: 16).stroke(eventMood.color.opacity(0.55), lineWidth: 1.5)
                        : nil
                    )
            )
            .padding(.top, isStarred ? 8 : 0)
        }
        .onTapGesture {
            vm.venueSheetPayload = vm.weekPayload(for: event)
        }
    }
}
