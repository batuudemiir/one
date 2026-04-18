//
//  DiscoverEventCard.swift
//  one
//
//  Minimalist event card for the Keşfet tab.
//  Replaces the complex EventCardView — no match %, no category colour blocks.
//

import SwiftUI

struct DiscoverEventCard: View {
    let event: MoodEvent
    let moodColor: Color

    private var isFree: Bool {
        event.price.lowercased().contains("ucret") || event.price == "Ücretsiz"
    }

    private var isOutdoor: Bool {
        event.kind == .microActivity || event.category == .aktivite
    }

    private var actionURL: URL? {
        isOutdoor
            ? appleMapsURL(venue: event.venue, city: event.city)
            : event.sourceURL
    }

    var body: some View {
        Button(action: {
            ONEHaptics.feelingSelected()
            if let url = actionURL {
                UIApplication.shared.open(url)
            }
        }) {
            HStack(spacing: 0) {

                // ── Mood accent line ─────────────────────────────────────
                RoundedRectangle(cornerRadius: 2)
                    .fill(
                        LinearGradient(
                            colors: [moodColor, moodColor.opacity(0.4)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: 3)
                    .padding(.vertical, 14)
                    .padding(.leading, 14)

                // ── Category icon ────────────────────────────────────────
                ZStack {
                    RoundedRectangle(cornerRadius: ONETokens.radiusCover)
                        .fill(event.category.accentColor.opacity(0.10))
                        .frame(width: 36, height: 36)
                    Image(systemName: categoryIcon(event.category))
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(event.category.accentColor)
                }
                .padding(.leading, 12)

                // ── Event info ───────────────────────────────────────────
                VStack(alignment: .leading, spacing: 3) {
                    Text(event.title)
                        .displayXS()
                        .foregroundColor(ONETokens.oneInk)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)

                    let venueCity = [event.venue, event.city]
                        .filter { !$0.isEmpty }
                        .joined(separator: " · ")
                    if !venueCity.isEmpty {
                        Text(venueCity)
                            .bodyMD()
                            .foregroundColor(ONETokens.oneAsh)
                            .lineLimit(1)
                    }

                    HStack(spacing: 6) {
                        if !event.timing.isEmpty {
                            Text(event.timing)
                                .monoSM(tracking: 0.2)
                                .foregroundColor(ONETokens.oneStone)
                        }
                        if !event.price.isEmpty {
                            Text(isFree ? NSLocalizedString("discover.free", comment: "") : event.price)
                                .monoSM(tracking: 0.2)
                                .foregroundColor(isFree ? ONETokens.oneGreen : ONETokens.oneStone)
                        }
                    }
                }
                .padding(.leading, 12)
                .padding(.vertical, 14)

                Spacer(minLength: 8)

                // ── CTA indicator ────────────────────────────────────────
                if actionURL != nil {
                    VStack(spacing: 3) {
                        Image(systemName: isOutdoor ? "map.fill" : "ticket.fill")
                            .font(.system(size: 11, weight: .semibold))
                        Text(isOutdoor ? NSLocalizedString("discover.ctaMap", comment: "") : NSLocalizedString("discover.ctaBiletix", comment: ""))
                            .monoLabel(tracking: 0.4)
                    }
                    .foregroundColor(
                        isOutdoor
                            ? ONETokens.oneBlue.opacity(0.85)
                            : ONETokens.oneBrand.opacity(0.85)
                    )
                    .padding(.trailing, 14)
                }
            }
            .frame(minHeight: 76)
            .background(
                RoundedRectangle(cornerRadius: ONETokens.radiusCard)
                    .fill(ONETokens.onePaper)
                    .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 2)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }

    // MARK: - Helpers

    private func appleMapsURL(venue: String, city: String) -> URL? {
        let parts = [venue, city].filter { !$0.isEmpty }
        guard !parts.isEmpty,
              let encoded = parts.joined(separator: ", ")
                .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)
        else { return nil }
        return URL(string: "https://maps.apple.com/?q=\(encoded)")
    }

    private func categoryIcon(_ category: EventCategory) -> String {
        switch category {
        case .aktivite: return "figure.walk"
        case .konser:   return "music.mic"
        case .spor:     return "sportscourt"
        case .sinema:   return "film"
        case .tiyatro:  return "theatermasks"
        case .sergi:    return "paintpalette"
        }
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 12) {
        DiscoverEventCard(
            event: MoodEvent(
                category: .konser,
                title: "Müzik Festivali · İstanbul",
                venue: "Zorlu PSM",
                city: "İstanbul",
                timing: "Cmt 20:00",
                price: "₺350",
                matchPercent: 87,
                sourceURL: URL(string: "https://www.biletix.com"),
                kind: .liveEvent
            ),
            moodColor: Color(hex: "#E84040")
        )

        DiscoverEventCard(
            event: MoodEvent(
                category: .aktivite,
                title: "Sabahçı Yürüyüşü",
                venue: "Belgrad Ormanı",
                city: "İstanbul",
                timing: "Paz 08:00",
                price: "Ücretsiz",
                matchPercent: 92,
                kind: .microActivity
            ),
            moodColor: Color(hex: "#4CAF82")
        )
    }
    .padding(24)
    .background(Color(hex: "#F7F6F3"))
}
