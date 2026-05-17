//
//  DiscoverFeaturedEventCard.swift
//  one
//
//  Featured event card — horizontal scroll strip ("Bizim Önerimiz").
//  Sinematik, koyu arka plan + mood rengi gradient.
//

import SwiftUI

struct DiscoverFeaturedEventCard: View {
    let event: MoodEvent
    let moodColor: Color

    private var isArtistMatch: Bool {
        event.kind == .artistConcert || event.kind == .similarConcert
    }

    private var isOutdoor: Bool {
        event.kind == .microActivity || event.category == .aktivite
    }

    private var actionURL: URL? {
        isOutdoor
            ? appleMapsURL(venue: event.venue, city: event.city)
            : event.sourceURL
    }

    private var badgeLabel: String? {
        if isArtistMatch { return NSLocalizedString("discover.artistConcert", comment: "") }
        if event.isNearbyCity { return NSLocalizedString("discover.nearby", comment: "") }
        return nil
    }

    private var badgeIcon: String {
        isArtistMatch ? "music.mic" : "location.fill"
    }

    var body: some View {
        Button(action: {
            ONEHaptics.feelingSelected()
            if let url = actionURL {
                UIApplication.shared.open(url)
            }
        }) {
            ZStack(alignment: .bottomLeading) {

                // ── Dark cinematic background ─────────────────────────────
                RoundedRectangle(cornerRadius: ONETokens.radiusCard)
                    .fill(ONETokens.oneCinematicDark)
                    .overlay(
                        // Mood colour gradient wash
                        LinearGradient(
                            colors: [moodColor.opacity(0.40), moodColor.opacity(0.08), .clear],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        .clipShape(RoundedRectangle(cornerRadius: ONETokens.radiusCard))
                    )
                    .overlay(
                        // Subtle grain lines
                        Canvas { ctx, size in
                            ctx.opacity = 0.035
                            for i in stride(from: -2, through: 6, by: 1) {
                                var path = Path()
                                let sx = size.width * (Double(i) * 0.22 - 0.05)
                                path.move(to: CGPoint(x: sx, y: size.height))
                                path.addLine(to: CGPoint(x: sx + size.width * 0.6, y: 0))
                                ctx.stroke(path, with: .color(.white), lineWidth: 0.7)
                            }
                        }
                        .clipShape(RoundedRectangle(cornerRadius: ONETokens.radiusCard))
                    )

                // ── Content ───────────────────────────────────────────────
                VStack(alignment: .leading, spacing: 0) {

                    // Badge (top-left)
                    if let label = badgeLabel {
                        HStack(spacing: 5) {
                            Image(systemName: badgeIcon)
                                .font(.system(size: 9, weight: .bold))
                            Text(label)
                                .monoLabel(tracking: 1.3)
                        }
                        .foregroundColor(moodColor)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(
                            Capsule()
                                .fill(moodColor.opacity(0.18))
                                .overlay(Capsule().stroke(moodColor.opacity(0.3), lineWidth: 0.5))
                        )
                    }

                    Spacer()

                    // Category icon (subtle)
                    Image(systemName: categoryIcon(event.category))
                        .font(.system(size: 20, weight: .ultraLight))
                        .foregroundColor(.white.opacity(0.28))
                        .padding(.bottom, 8)

                    // Title
                    Text(event.title)
                        .bodyLG()
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)

                    // Venue · City · Timing
                    let meta = [event.venue, event.city, event.timing]
                        .filter { !$0.isEmpty }
                        .joined(separator: " · ")
                    if !meta.isEmpty {
                        Text(meta)
                            .monoSM(tracking: 0.2)
                            .foregroundColor(.white.opacity(0.48))
                            .lineLimit(1)
                            .padding(.top, 4)
                    }

                    // CTA row
                    HStack {
                        // Nearby city label
                        if event.isNearbyCity && !event.city.isEmpty {
                            HStack(spacing: 3) {
                                Image(systemName: "location.fill")
                                    .font(.system(size: 8, weight: .semibold))
                                Text(event.city)
                            }
                            .monoLabel(tracking: 0.5)
                            .foregroundColor(.white.opacity(0.45))
                        }
                        Spacer()
                        if actionURL != nil {
                            HStack(spacing: 4) {
                                Text(isOutdoor
                                     ? NSLocalizedString("discover.showOnMap", comment: "")
                                     : NSLocalizedString("discover.buyOnBiletix", comment: ""))
                                    .monoLabel(tracking: 0.5)
                                Image(systemName: isOutdoor ? "map.fill" : "ticket.fill")
                                    .font(.system(size: 10, weight: .semibold))
                            }
                            .foregroundColor(moodColor.opacity(0.9))
                        }
                    }
                    .padding(.top, 8)
                }
                .padding(16)
            }
            .frame(maxWidth: .infinity, minHeight: 200)
        }
        .buttonStyle(PlainButtonStyle())
        .accessibilityLabel(event.title)
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
    VStack(spacing: 16) {
        DiscoverFeaturedEventCard(
            event: MoodEvent(
                category: .konser,
                title: "Duman — Akustik Türkiye Turu",
                venue: "Zorlu PSM",
                city: "İstanbul",
                timing: "Cmt 20:00",
                price: "₺850+",
                matchPercent: 96,
                sourceURL: URL(string: "https://www.biletix.com"),
                kind: .artistConcert
            ),
            moodColor: ONETokens.oneRed
        )
    }
    .padding(.horizontal, 24)
    .padding(.vertical, 24)
    .background(ONETokens.oneCream)
}
