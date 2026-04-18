//
//  EventCardView.swift
//  one
//
//  Keşfet sekmesi — Editorial event card (inline)
//  · Left category-colour accent bar
//  · Smart CTA: Maps for outdoor/micro activities, Biletix for ticketed events
//  · "Yakın şehir" badge when event is from a nearby city API fallback
//  · isFallbackURL → CTA label becomes "Biletix'te Ara" instead of "Biletix'te Bak"
//

import SwiftUI

// MARK: - CTA Action

private enum CTAAction {
    case biletixDirect(URL)   // direct Biletix event page (tier-1 city)
    case biletixSearch(URL)   // Biletix category search page (never 404s)
    case maps(URL)
    case none

    var label: String {
        switch self {
        case .biletixDirect: return NSLocalizedString("discover.viewOnBiletix", comment: "")
        case .biletixSearch: return NSLocalizedString("discover.viewOnBiletix", comment: "")
        case .maps:          return NSLocalizedString("discover.showOnMap", comment: "")
        case .none:          return ""
        }
    }

    var icon: String {
        switch self {
        case .biletixDirect, .biletixSearch: return "ticket.fill"
        case .maps:                          return "map.fill"
        case .none:                          return ""
        }
    }

    var tintColor: Color {
        switch self {
        case .biletixDirect, .biletixSearch: return Color(hex: "#E63946")
        case .maps:                          return ONETokens.oneBlue
        case .none:                          return .clear
        }
    }

    var url: URL? {
        switch self {
        case .biletixDirect(let u), .biletixSearch(let u), .maps(let u): return u
        case .none: return nil
        }
    }

    var isActive: Bool {
        if case .none = self { return false }
        return true
    }
}

// MARK: - EventCardView

struct EventCardView: View {
    let event: MoodEvent
    let moodColor: Color?

    private var cta: CTAAction {
        switch event.kind {
        case .microActivity:
            return mapsAction()
        case .liveEvent where event.category == .aktivite:
            return mapsAction()
        case .liveEvent, .artistConcert, .similarConcert:
            guard let url = event.sourceURL else { return .none }
            return event.isFallbackURL ? .biletixSearch(url) : .biletixDirect(url)
        }
    }

    private var isFreeEvent: Bool {
        event.price.lowercased().contains("ucret") || event.price == "Ücretsiz"
    }

    var body: some View {
        Button(action: {
            ONEHaptics.feelingSelected()
            if let url = cta.url { UIApplication.shared.open(url) }
        }) {
            HStack(spacing: 0) {

                // ── Left accent bar (category colour) ─────────────────
                RoundedRectangle(cornerRadius: 2)
                    .fill(event.category.accentColor)
                    .frame(width: 3)
                    .padding(.vertical, 14)
                    .padding(.leading, 14)

                // ── Category icon ──────────────────────────────────────
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(event.category.accentColor.opacity(0.11))
                        .frame(width: 44, height: 44)
                    Image(systemName: iconForCategory(event.category))
                        .font(.system(size: 17, weight: .medium))
                        .foregroundColor(event.category.accentColor)
                }
                .padding(.leading, 12)

                // ── Event info ─────────────────────────────────────────
                VStack(alignment: .leading, spacing: 3) {
                    // Nearby city badge
                    if event.isNearbyCity {
                        HStack(spacing: 3) {
                            Image(systemName: "location.circle")
                                .font(.system(size: 8, weight: .medium))
                            Text(String(format: NSLocalizedString("discover.nearbyCity", comment: ""), event.city))
                                .monoMicro(tracking: 0.4)
                        }
                        .foregroundColor(ONETokens.oneStone)
                    }

                    Text(event.title)
                        .bodySMMedium()
                        .foregroundColor(ONETokens.oneInk)
                        .lineLimit(1)

                    if !event.venue.isEmpty {
                        Text(event.venue)
                            .monoSM(tracking: 0)
                            .foregroundColor(ONETokens.oneAsh)
                            .lineLimit(1)
                    }

                    HStack(spacing: 6) {
                        if !event.timing.isEmpty {
                            Text(event.timing)
                                .monoLabel(tracking: 0.4)
                                .foregroundColor(ONETokens.oneStone)
                        }
                        if !event.price.isEmpty {
                            Text("·").foregroundColor(ONETokens.oneCreamLow)
                            Text(isFreeEvent ? NSLocalizedString("discover.free", comment: "") : event.price)
                                .monoLabel(tracking: 0.4)
                                .foregroundColor(isFreeEvent ? ONETokens.oneGreen : ONETokens.oneStone)
                        }
                    }

                    // Smart CTA badge
                    if cta.isActive {
                        HStack(spacing: 4) {
                            Image(systemName: cta.icon)
                                .font(.system(size: 8, weight: .semibold))
                            Text(cta.label)
                                .monoMicro(tracking: 0.6)
                        }
                        .foregroundColor(cta.tintColor.opacity(0.85))
                        .padding(.top, 2)
                    }
                }
                .padding(.leading, 12)
                .padding(.vertical, 14)

                Spacer(minLength: 8)

                // ── Match badge ────────────────────────────────────────
                VStack(spacing: 2) {
                    Text("\(event.matchPercent)%")
                        .monoBase(tracking: 0.4)
                        .foregroundColor(moodColor ?? event.category.accentColor)
                    Text(NSLocalizedString("discover.match", comment: ""))
                        .monoMicro(tracking: 0.6)
                        .foregroundColor(ONETokens.oneAsh)
                }
                .padding(.trailing, 14)
            }
            .frame(minHeight: 82)
            .background(
                RoundedRectangle(cornerRadius: ONETokens.radiusCard)
                    .fill(ONETokens.onePaper)
                    // Nearby city events get a slightly different background tint
                    .overlay(
                        event.isNearbyCity
                            ? RoundedRectangle(cornerRadius: ONETokens.radiusCard)
                                .strokeBorder(ONETokens.oneStone.opacity(0.15), lineWidth: 0.5)
                            : RoundedRectangle(cornerRadius: ONETokens.radiusCard)
                                .strokeBorder(ONETokens.oneCreamMid.opacity(0.8), lineWidth: 0.5)
                    )
                    .shadow(color: .black.opacity(0.04), radius: 10, x: 0, y: 3)
            )
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(!cta.isActive)
        .opacity(!cta.isActive ? 0.82 : 1.0)
        .accessibilityLabel(String(format: NSLocalizedString("accessibility.discovery.openEvent", comment: ""), event.title))
        .accessibilityHint(NSLocalizedString("accessibility.discovery.eventHint", comment: ""))
    }

    // MARK: - Helpers

    private func mapsAction() -> CTAAction {
        guard let url = appleMapsURL(venue: event.venue, city: event.city) else { return .none }
        return .maps(url)
    }

    private func appleMapsURL(venue: String, city: String) -> URL? {
        let parts = [venue, city].filter { !$0.isEmpty }
        guard !parts.isEmpty,
              let encoded = parts.joined(separator: ", ")
                .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)
        else { return nil }
        return URL(string: "https://maps.apple.com/?q=\(encoded)")
    }

    private func iconForCategory(_ category: EventCategory) -> String {
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
