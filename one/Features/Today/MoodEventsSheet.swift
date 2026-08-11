//
//  MoodEventsSheet.swift
//  one
//
//  Mood-matched event recommendations sheet — UI only.
//  Models: MoodEventsModels.swift  ·  Mock data: MoodEventMockData.swift
//  Networking: TicketmasterManager.swift
//  Refactored in Faz 3.1 (2026-04-26): 1721 → ~365 LOC.
//

import SwiftUI
import Foundation

// MARK: - Main Sheet View

struct MoodEventsSheet: View {
    let entry: DailyEntry
    @Environment(\.dismiss) private var dismiss
    @State private var selectedCategory: EventCategory? = nil
    @AppStorage(ONETokens.cityPreferenceKey) private var preferredCity: String = ONETokens.defaultCity

    @State private var sections: [RecommendationSection] = []
    @State private var isLoading: Bool = true

    private var filteredSections: [RecommendationSection] {
        guard let cat = selectedCategory else { return sections }

        return sections.compactMap { section in
            let items = section.items.filter { $0.category == cat }
            guard !items.isEmpty else { return nil }

            return RecommendationSection(
                id: section.id,
                title: section.title,
                subtitle: section.subtitle,
                items: items
            )
        }
    }

    private var filteredItemCount: Int {
        filteredSections.reduce(0) { $0 + $1.items.count }
    }

    private var fallbackCity: String? {
        let allItems = sections.flatMap(\.items)
        guard allItems.allSatisfy({ $0.isNearbyCity }), let first = allItems.first else { return nil }
        return first.city
    }

    private var visibleCategories: [EventCategory] {
        EventCategory.allCases.filter { ![.spor, .sinema].contains($0) }
    }

    var body: some View {
        ZStack(alignment: .top) {
            ONEBrand.bone.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {

                    // Header
                    VStack(alignment: .leading, spacing: 14) {
                        // Mood + city pill row
                        HStack(spacing: 0) {
                            // Mood pill (static)
                            HStack(spacing: 7) {
                                Circle()
                                    .fill(entry.moodColor)
                                    .frame(width: 8, height: 8)
                                Text(entry.normalizedMoodLabel.uppercased())
                                    .monoBase(tracking: 1.5)
                                    .foregroundColor(V3Tokens.mutedText)
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(Capsule().fill(entry.moodColor.opacity(0.15)))

                            Text(" · ")
                                .monoBase(tracking: 0.5)
                                .foregroundColor(V3Tokens.mutedText)
                                .padding(.horizontal, 2)

                            // City pill — tappable Menu
                            Menu {
                                ForEach(ONETokens.availableCities, id: \.self) { city in
                                    Button(action: { preferredCity = city }) {
                                        HStack {
                                            Text(city)
                                            if city == preferredCity {
                                                Image(systemName: "checkmark")
                                            }
                                        }
                                    }
                                }
                            } label: {
                                HStack(spacing: 5) {
                                    Text(preferredCity.uppercased())
                                        .monoBase(tracking: 1.5)
                                        .foregroundColor(V3Tokens.mutedText)
                                    Image(systemName: "chevron.down")
                                        .monoMicro().fontWeight(.semibold)
                                        .foregroundColor(V3Tokens.mutedText)
                                }
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(
                                    Capsule()
                                        .fill(V3Tokens.surface)
                                        .overlay(Capsule().stroke(V3Tokens.faintText, lineWidth: 0.5))
                                )
                            }
            .accessibilityLabel(String(format: NSLocalizedString("accessibility.discover.city", comment: ""), preferredCity))
                        }

                        // Headline — bold italic serif
                        Text(NSLocalizedString("moodEvents.ourPicks", comment: ""))
                            .displayHero().fontWeight(.black)
                            .italic()
                            .foregroundColor(V3Tokens.ink)
                            .lineSpacing(2)
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 32)
                    .padding(.bottom, 22)

                    // Fallback city notice
                    if let fb = fallbackCity {
                        HStack(spacing: 10) {
                            Image(systemName: "location.slash.fill")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(V3Tokens.faintText)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("\(preferredCity) için etkinlik bulunamadı")
                                    .font(ONETypography.monoSM)
                                    .foregroundColor(V3Tokens.mutedText)
                                Text("\(fb) etkinlikleri gösteriliyor")
                                    .font(ONETypography.monoMicro)
                                    .foregroundColor(V3Tokens.faintText)
                            }
                            Spacer()
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .background(RoundedRectangle(cornerRadius: 12).fill(V3Tokens.surface))
                        .padding(.horizontal, 20)
                        .padding(.bottom, 12)
                    }

                    // Category filter pills
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            EventFilterPill(label: NSLocalizedString("discover.all", comment: ""), isSelected: selectedCategory == nil) {
                                withAnimation(ONEAnimation.micro) { selectedCategory = nil }
                            }
                            ForEach(visibleCategories) { cat in
                                EventFilterPill(label: cat.rawValue, isSelected: selectedCategory == cat) {
                                    withAnimation(ONEAnimation.micro) {
                                        selectedCategory = selectedCategory == cat ? nil : cat
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 24)
                    }
                    .padding(.bottom, 20)

                    // Recommendation cards
                    VStack(spacing: 20) {
                        if isLoading {
                            ProgressView()
                                .padding(.top, 40)
                                .tint(V3Tokens.ink)
                        } else if filteredItemCount == 0 {
                            Text(NSLocalizedString("moodEvents.noEvents", comment: ""))
                                .bodyLG().fontWeight(.medium)
                                .foregroundColor(V3Tokens.mutedText)
                                .padding(.top, 40)
                        } else {
                            ForEach(filteredSections) { section in
                                VStack(alignment: .leading, spacing: 10) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(section.title)
                                            .bodyXL().fontWeight(.bold)
                                            .foregroundColor(V3Tokens.ink)
                                        Text(section.subtitle)
                                            .monoSM(tracking: 0.3)
                                            .foregroundColor(V3Tokens.mutedText)
                                    }

                                    ForEach(section.items) { event in
                                        MoodEventCard(event: event)
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 48)
                    .animation(.spring(response: 0.32, dampingFraction: 0.82), value: selectedCategory)
                    .animation(.spring(response: 0.32, dampingFraction: 0.82), value: isLoading)
                }
            }
        }
        .presentationDragIndicator(.visible)
        .presentationDetents([.medium, .large])
        .presentationContentInteraction(.scrolls)
        .task(id: preferredCity) {
            if preferredCity == "İzmit" {
                preferredCity = "Kocaeli"
                return
            }
            isLoading = true
            sections = await ActivityRecommendationEngine.shared.fetchSections(for: entry, city: preferredCity)
            withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
                isLoading = false
            }
        }
    }
}

// MARK: - Filter Pill

private struct EventFilterPill: View {
    let label: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .bodySMMedium()
                .foregroundColor(isSelected ? .white : V3Tokens.mutedText)
                .padding(.horizontal, 18)
                .padding(.vertical, 9)
                .background(
                    Capsule().fill(isSelected ? V3Tokens.ink : V3Tokens.surface)
                )
                .overlay(
                    isSelected ? nil :
                    Capsule().stroke(V3Tokens.wash, lineWidth: 1)
                )
        }
        .buttonStyle(PlainButtonStyle())
        .accessibilityLabel(label)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}

// MARK: - Event Card

private struct MoodEventCard: View {
    let event: MoodEvent

    var body: some View {
        HStack(spacing: 0) {
            // Colored left border
            Rectangle()
                .fill(event.category.accentColor)
                .frame(width: 3)
                .cornerRadius(1.5)

            VStack(alignment: .leading, spacing: 6) {
                // Category + match %
                HStack(alignment: .center) {
                    HStack(spacing: 6) {
                        Text(event.category.rawValue.uppercased())
                            .monoLabel(tracking: 1.5)
                            .foregroundColor(V3Tokens.mutedText)

                        if let sourceLabel = event.sourceLabel {
                            Text(sourceLabel.uppercased())
                                .monoLabel(tracking: 1.0)
                                .foregroundColor(event.category.accentColor)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Capsule().fill(event.category.accentColor.opacity(0.10)))
                        }
                    }
                    Spacer()
                    Text(String(format: NSLocalizedString("moodEvents.matchPercent", comment: ""), event.matchPercent))
                        .monoLabel(tracking: 0.8)
                        .foregroundColor(ONETokens.moodOrange)
                }

                // Nearby city badge
                if event.isNearbyCity {
                    HStack(spacing: 4) {
                        Image(systemName: "location.circle.fill")
                            .monoMicro()
                        Text(String(format: NSLocalizedString("moodEvents.nearbyCity", comment: ""), event.city))
                            .monoLabel(tracking: 0.5)
                    }
                    .foregroundColor(V3Tokens.faintText)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(V3Tokens.surface))
                }

                // Event title
                Text(event.title)
                    .bodyXL().fontWeight(.bold)
                    .foregroundColor(V3Tokens.ink)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                // Venue
                Text("\(event.venue), \(event.city)")
                    .monoSM(tracking: 0.5)
                    .foregroundColor(V3Tokens.mutedText)

                if let reason = event.reason {
                    Text(reason)
                        .bodySMMedium()
                        .foregroundColor(V3Tokens.mutedText)
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer().frame(height: 2)

                // Timing + Price
                HStack(alignment: .center) {
                    Text(event.timing)
                        .monoSM(tracking: 0.5)
                        .foregroundColor(V3Tokens.mutedText)
                    Spacer()
                    Text(event.price)
                        .bodyLG().fontWeight(.bold)
                        .foregroundColor(V3Tokens.ink)
                }

                // Smart CTA: bilet gerektiren → Biletix, aktivite/micro → Harita, diğer → gizle
                eventCTA(for: event)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 16)
        }
        .background(V3Tokens.surface)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 2)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(event.category.rawValue): \(event.title), \(event.venue), \(event.city), \(event.timing), \(event.price)")
        .accessibilityHint(NSLocalizedString("accessibility.discover.eventHint", comment: ""))
    }

    // MARK: - Smart CTA
    // Bilet gerektiren (konser/tiyatro/sergi) → Biletix butonu
    // Aktivite / micro-activity → Apple Haritalar butonu
    // sourceURL yoksa ve harita da üretilemiyorsa → hiçbir şey

    @ViewBuilder
    private func eventCTA(for event: MoodEvent) -> some View {
        let isTicketed = event.kind != .microActivity && event.category != .aktivite

        if isTicketed, let url = event.sourceURL {
            HStack {
                Spacer()
                Link(destination: url) {
                    HStack(spacing: 5) {
                        Image(systemName: "ticket.fill")
                            .monoLabel().fontWeight(.semibold)
                        // "Ara" for search pages (never 404), "Bak" for direct event pages
                        Text(event.isFallbackURL ? NSLocalizedString("discover.buyOnBiletix", comment: "") : NSLocalizedString("discover.viewOnBiletix", comment: ""))
                            .monoSM(tracking: 0.6)
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Capsule().fill(ONEBrand.kor))
                }
            }
        } else if !isTicketed, let url = appleMapsURL(venue: event.venue, city: event.city) {
            HStack {
                Spacer()
                Link(destination: url) {
                    HStack(spacing: 5) {
                        Image(systemName: "map.fill")
                            .monoLabel().fontWeight(.semibold)
                        Text(NSLocalizedString("discover.showOnMap", comment: ""))
                            .monoSM(tracking: 0.6)
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Capsule().fill(ONETokens.oneBlue))
                }
            }
        }
    }

    private func appleMapsURL(venue: String, city: String) -> URL? {
        let parts = [venue, city].filter { !$0.isEmpty }
        guard !parts.isEmpty,
              let encoded = parts.joined(separator: ", ")
                .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else { return nil }
        return URL(string: "https://maps.apple.com/?q=\(encoded)")
    }
}
