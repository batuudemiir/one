//
//  DiscoverView.swift
//  one
//
//  Keşfet sekmesi — Minimalist Redesign
//  İki sekme: Etkinlikler (Biletix) + Müzik (kişisel öneriler)
//

import SwiftUI
import CoreData

struct DiscoverView: View {
    @StateObject private var vm: DiscoverViewModel
    @AppStorage(ONETokens.cityPreferenceKey) private var preferredCity: String = ONETokens.defaultCity
    @Namespace private var tabNamespace
    @State private var appeared = false
    private let context: NSManagedObjectContext

    init(context: NSManagedObjectContext) {
        self.context = context
        _vm = StateObject(wrappedValue: DiscoverViewModel(context: context))
    }

    private var moodColor: Color {
        vm.todayEntry?.moodColor ?? ONETokens.oneBrand
    }

    // MARK: - Body

    var body: some View {
        ZStack(alignment: .top) {
            ONETokens.oneCream.ignoresSafeArea()

            VStack(spacing: 0) {
                // ── Sabit header ─────────────────────────────────────────
                headerRow
                    .padding(.top, 56)
                    .padding(.horizontal, 24)

                // ── Mood context strip ───────────────────────────────────
                moodContextStrip
                    .padding(.horizontal, 24)
                    .padding(.top, 18)

                // ── Tab switcher ─────────────────────────────────────────
                tabSwitcher
                    .padding(.top, 22)

                // ── Tab içeriği ──────────────────────────────────────────
                tabContent
            }
        }
        .navigationBarHidden(true)
        .task {
            await vm.fetchContent()
            withAnimation(ONEAnimation.cardSpring) { appeared = true }
        }
    }

    // MARK: - Header

    private var headerRow: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                Text(NSLocalizedString("discover.title", comment: ""))
                    .displayLG()
                    .foregroundColor(ONETokens.oneInk)
                Text(greetingText)
                    .bodySM()
                    .foregroundColor(ONETokens.oneAsh)
            }
            Spacer()
            cityPill
        }
    }

    private var cityPill: some View {
        HStack(spacing: 5) {
            Image(systemName: "location.fill")
                .font(.system(size: 9, weight: .semibold))
            Text(preferredCity)
                .monoSM(tracking: 0.5)
        }
        .foregroundColor(ONETokens.oneStone)
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(
            Capsule()
                .fill(.regularMaterial)
                .shadow(color: .black.opacity(0.06), radius: 10, x: 0, y: 2)
        )
    }

    private var greetingText: String {
        let h = Calendar.current.component(.hour, from: Date())
        if h < 12 { return NSLocalizedString("discover.greeting.morning", comment: "") }
        if h < 18 { return NSLocalizedString("discover.greeting.afternoon", comment: "") }
        return NSLocalizedString("discover.greeting.evening", comment: "")
    }

    // MARK: - Mood Context Strip

    @ViewBuilder
    private var moodContextStrip: some View {
        if let entry = vm.todayEntry {
            HStack(spacing: 14) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(
                        LinearGradient(
                            colors: [entry.moodColor, entry.moodColor.opacity(0.35)],
                            startPoint: .top, endPoint: .bottom
                        )
                    )
                    .frame(width: 3, height: 40)

                VStack(alignment: .leading, spacing: 3) {
                    Text(entry.songName)
                        .bodySMMedium()
                        .foregroundColor(ONETokens.oneInk)
                        .lineLimit(1)
                    Text(entry.artistName)
                        .monoSM(tracking: 0)
                        .foregroundColor(ONETokens.oneAsh)
                        .lineLimit(1)
                }

                Spacer(minLength: 8)

                if !entry.moodLabel.isEmpty {
                    Text(entry.moodLabel)
                        .monoLabel(tracking: 0.8)
                        .foregroundColor(entry.moodColor)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Capsule().fill(entry.moodColor.opacity(0.12)))
                }
            }
        }
        // todayEntry yoksa strip gösterilmez
    }

    // MARK: - Tab Switcher

    private var tabSwitcher: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                ForEach(DiscoverTab.allCases, id: \.self) { tab in
                    Button {
                        withAnimation(ONEAnimation.tabSwitch) {
                            vm.selectedTab = tab
                        }
                    } label: {
                        VStack(spacing: 0) {
                            Text(tab.rawValue)
                                .bodySMMedium()
                                .foregroundColor(
                                    vm.selectedTab == tab
                                        ? ONETokens.oneInk
                                        : ONETokens.oneAsh
                                )
                                .padding(.vertical, 12)
                                .frame(maxWidth: .infinity)

                            // Aktif sekme alt çizgisi
                            if vm.selectedTab == tab {
                                Rectangle()
                                    .fill(moodColor)
                                    .frame(height: 2)
                                    .matchedGeometryEffect(id: "tabLine", in: tabNamespace)
                            } else {
                                Rectangle()
                                    .fill(Color.clear)
                                    .frame(height: 2)
                            }
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.horizontal, 24)

            Divider()
                .background(ONETokens.oneCreamMid)
        }
    }

    // MARK: - Tab İçeriği

    @ViewBuilder
    private var tabContent: some View {
        switch vm.selectedTab {
        case .etkinlikler:
            EtkinliklerTabView(
                events: vm.upcomingEvents,
                isLoading: vm.isLoadingEvents,
                moodColor: moodColor,
                hasTodayEntry: vm.todayEntry != nil,
                appeared: appeared,
                onRefresh: { await vm.refresh() }
            )
            .transition(.opacity)
        case .muzik:
            MuzikTabView(
                engine: vm.recommendationEngine,
                moodColor: moodColor,
                appeared: appeared,
                context: context,
                onRefresh: { await vm.refresh() },
                onTap: { openSong($0) }
            )
            .transition(.opacity)
        }
    }

    // MARK: - Helper

    private func openSong(_ rec: SongRecommendation) {
        if let urlStr = rec.spotifyURL, let url = URL(string: urlStr) {
            UIApplication.shared.open(url)
        }
    }
}

// MARK: - Etkinlikler Tab

private struct EtkinliklerTabView: View {
    let events: [MoodEvent]
    let isLoading: Bool
    let moodColor: Color
    let hasTodayEntry: Bool
    let appeared: Bool
    let onRefresh: () async -> Void

    // ── Data split ───────────────────────────────────────────────────────
    private var featuredEvent: MoodEvent? {
        events.sorted {
            let aArtist = $0.kind == .artistConcert || $0.kind == .similarConcert
            let bArtist = $1.kind == .artistConcert || $1.kind == .similarConcert
            if aArtist != bArtist { return aArtist }
            return $0.matchPercent > $1.matchPercent
        }.first
    }

    private var gridEvents: [MoodEvent] {
        guard let featured = featuredEvent else { return events }
        return events.filter { $0.id != featured.id }
    }

    // ── Grid columns ─────────────────────────────────────────────────────
    private let gridColumns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                if !hasTodayEntry {
                    emptyMoodState
                        .padding(.top, 52)
                        .padding(.horizontal, 24)
                } else if isLoading {
                    skeletonView
                } else if events.isEmpty {
                    emptyEventsState
                        .padding(.top, 52)
                        .padding(.horizontal, 24)
                } else {
                    // ── Featured card (single, full-width) ────────────────
                    if let featured = featuredEvent {
                        sectionLabel("BİZİM ÖNERİMİZ")
                            .padding(.horizontal, 24)
                            .padding(.top, 16)

                        DiscoverFeaturedEventCard(event: featured, moodColor: moodColor)
                            .padding(.horizontal, 24)
                            .padding(.top, 12)
                            .opacity(appeared ? 1 : 0)
                            .offset(y: appeared ? 0 : 12)
                            .animation(ONEAnimation.cardSpring, value: appeared)
                    }

                    // ── 2-column grid ─────────────────────────────────────
                    if !gridEvents.isEmpty {
                        sectionLabel("ETKİNLİKLER")
                            .padding(.horizontal, 24)
                            .padding(.top, 8)

                        LazyVGrid(columns: gridColumns, spacing: 12) {
                            ForEach(Array(gridEvents.enumerated()), id: \.element.id) { index, event in
                                DiscoverGridEventCard(event: event, moodColor: moodColor)
                                    .opacity(appeared ? 1 : 0)
                                    .offset(y: appeared ? 0 : 10)
                                    .animation(
                                        ONEAnimation.cardSpring.delay(Double(index) * 0.04 + 0.18),
                                        value: appeared
                                    )
                            }
                        }
                        .padding(.horizontal, 24)
                        .padding(.top, 8)
                    }
                }
            }
            .padding(.bottom, 120)
        }
        .refreshable { await onRefresh() }
    }

    // MARK: - Skeleton

    private var skeletonView: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Featured skeleton
            sectionLabel("BİZİM ÖNERİMİZ")
                .padding(.horizontal, 24)
                .padding(.top, 16)
            RoundedRectangle(cornerRadius: ONETokens.radiusCard)
                .fill(ONETokens.oneCreamMid)
                .frame(maxWidth: .infinity, minHeight: 200)
                .padding(.horizontal, 24)
                .padding(.top, 12)
                .shimmering()
            // Grid skeleton
            sectionLabel("ETKİNLİKLER")
                .padding(.horizontal, 24)
                .padding(.top, 8)
            LazyVGrid(columns: gridColumns, spacing: 12) {
                ForEach(0..<4, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: ONETokens.radiusCard)
                        .fill(ONETokens.oneCreamMid)
                        .frame(height: 148)
                        .shimmering()
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 8)
        }
    }

    // MARK: - Empty states

    private var emptyMoodState: some View {
        VStack(spacing: 12) {
            Image(systemName: "sparkles")
                .font(.system(size: 32, weight: .light))
                .foregroundColor(ONETokens.oneAsh)
            Text(NSLocalizedString("discover.selectMood", comment: ""))
                .displayXS()
                .foregroundColor(ONETokens.oneInk)
            Text(NSLocalizedString("discover.noSuggestionsHint", comment: ""))
                .bodySM()
                .foregroundColor(ONETokens.oneAsh)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
        }
        .frame(maxWidth: .infinity)
    }

    private var emptyEventsState: some View {
        VStack(spacing: 16) {
            Image(systemName: "calendar.badge.exclamationmark")
                .font(.system(size: 32, weight: .light))
                .foregroundColor(ONETokens.oneAsh)
            VStack(spacing: 6) {
                Text(NSLocalizedString("discover.noEvents", comment: ""))
                    .displayXS()
                    .foregroundColor(ONETokens.oneInk)
                Text(NSLocalizedString("discover.selectMoodHint", comment: ""))
                    .bodySM()
                    .foregroundColor(ONETokens.oneAsh)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }
            // Biletix CTA
            if let url = URL(string: "https://www.biletix.com") {
                Button {
                    UIApplication.shared.open(url)
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "ticket.fill")
                            .font(.system(size: 11, weight: .semibold))
                        Text(NSLocalizedString("discover.searchBiletix", comment: ""))
                            .monoBase(tracking: 0.5)
                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 10, weight: .semibold))
                    }
                    .foregroundColor(ONETokens.oneBrand)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(
                        Capsule()
                            .fill(ONETokens.oneBrand.opacity(0.08))
                            .overlay(Capsule().stroke(ONETokens.oneBrand.opacity(0.2), lineWidth: 1))
                    )
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Helpers

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .monoLabel(tracking: 1.4)
            .foregroundColor(ONETokens.oneAsh)
    }
}

// MARK: - Grid Event Card

private struct DiscoverGridEventCard: View {
    let event: MoodEvent
    let moodColor: Color

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
            VStack(alignment: .leading, spacing: 0) {

                // ── Category accent band ──────────────────────────────────
                ZStack {
                    RoundedRectangle(cornerRadius: ONETokens.radiusCard)
                        .fill(event.category.accentColor.opacity(0.10))
                        .frame(height: 52)
                    Image(systemName: categoryIcon(event.category))
                        .font(.system(size: 22, weight: .light))
                        .foregroundColor(event.category.accentColor.opacity(0.8))
                }
                .frame(maxWidth: .infinity)

                // ── Text content ──────────────────────────────────────────
                VStack(alignment: .leading, spacing: 4) {
                    Text(event.title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(ONETokens.oneInk)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)

                    if !event.venue.isEmpty {
                        Text(event.venue)
                            .monoSM(tracking: 0)
                            .foregroundColor(ONETokens.oneAsh)
                            .lineLimit(1)
                    }

                    HStack(spacing: 4) {
                        if !event.timing.isEmpty {
                            Text(event.timing)
                                .monoLabel(tracking: 0)
                                .foregroundColor(ONETokens.oneStone)
                                .lineLimit(1)
                        }
                        if !event.price.isEmpty {
                            Text("·")
                                .monoLabel(tracking: 0)
                                .foregroundColor(ONETokens.oneStone)
                            Text(event.price == "Ücretsiz" ? NSLocalizedString("discover.free", comment: "") : event.price)
                                .monoLabel(tracking: 0)
                                .foregroundColor(event.price == "Ücretsiz" ? ONETokens.oneGreen : ONETokens.oneStone)
                                .lineLimit(1)
                        }
                    }

                    // Mood accent line at bottom
                    RoundedRectangle(cornerRadius: 1)
                        .fill(moodColor.opacity(0.5))
                        .frame(height: 2)
                        .padding(.top, 4)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
            }
            .background(
                RoundedRectangle(cornerRadius: ONETokens.radiusCard)
                    .fill(ONETokens.onePaper)
                    .shadow(color: .black.opacity(0.05), radius: 6, x: 0, y: 2)
            )
            .clipShape(RoundedRectangle(cornerRadius: ONETokens.radiusCard))
        }
        .buttonStyle(PlainButtonStyle())
    }

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

// MARK: - Müzik Tab

private struct MuzikTabView: View {
    @ObservedObject var engine: RecommendationEngine
    let moodColor: Color
    let appeared: Bool
    let context: NSManagedObjectContext
    let onRefresh: () async -> Void
    let onTap: (SongRecommendation) -> Void

    private let gridColumns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {

                // ── Genre chips (dinleme geçmişinden) ───────────────
                if let profile = engine.tasteProfile, !profile.topGenres.isEmpty {
                    GenreChipsView(
                        genres: profile.topGenres,
                        artists: profile.topArtists,
                        selectedGenre: Binding(
                            get: { engine.pinnedGenre },
                            set: { _ in }
                        ),
                        onGenreSelected: { genre in
                            Task { await engine.filterByGenre(genre) }
                        }
                    )
                    .padding(.bottom, 20)
                    .opacity(appeared ? 1 : 0)
                    .animation(ONEAnimation.cardSpring.delay(0.05), value: appeared)
                }

                if engine.isLoading && engine.recommendations.isEmpty {
                    // Yükleniyor
                    RecommendationsSection(engine: engine) { onTap($0) }

                } else if !engine.recommendations.isEmpty {

                    // ── "SENİN İÇİN" — featured ──────────────────────
                    sectionLabel("SENİN İÇİN")
                        .padding(.bottom, 12)
                        .opacity(appeared ? 1 : 0)
                        .animation(ONEAnimation.cardSpring.delay(0.08), value: appeared)

                    if let featured = engine.recommendations.first {
                        FeaturedSongCard(
                            recommendation: featured,
                            moodColor: moodColor,
                            onTap: { onTap(featured) }
                        )
                        .opacity(appeared ? 1 : 0)
                        .animation(ONEAnimation.cardSpring, value: appeared)
                        .padding(.bottom, 28)
                    }

                    // ── Keşfiyat grid ────────────────────────────────
                    if engine.recommendations.count > 1 {
                        sectionLabel("KEŞFET")
                            .padding(.bottom, 12)
                            .opacity(appeared ? 1 : 0)
                            .animation(ONEAnimation.cardSpring.delay(0.12), value: appeared)

                        LazyVGrid(columns: gridColumns, spacing: 16) {
                            ForEach(Array(engine.recommendations.dropFirst().enumerated()), id: \.element.id) { index, rec in
                                RecommendationCardView(recommendation: rec) { onTap(rec) }
                                    .opacity(appeared ? 1 : 0)
                                    .offset(y: appeared ? 0 : 12)
                                    .animation(
                                        ONEAnimation.cardSpring.delay(Double(index) * 0.04 + 0.14),
                                        value: appeared
                                    )
                            }
                        }
                    }

                } else if engine.error != nil {
                    // Hata durumu
                    RecommendationsSection(engine: engine) { onTap($0) }
                } else {
                    // Boş durum — müzik servisi bağlı değil / giriş yok
                    emptyMusicState
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 16)
            .padding(.bottom, 120)
        }
        .refreshable { await onRefresh() }
    }

    // MARK: - Helpers

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .monoLabel(tracking: 1.4)
            .foregroundColor(ONETokens.oneAsh)
    }

    private var emptyMusicState: some View {
        VStack(spacing: 14) {
            Image(systemName: "waveform.badge.magnifyingglass")
                .font(.system(size: 34, weight: .light))
                .foregroundColor(ONETokens.oneAsh)
            Text(NSLocalizedString("discover.music.connect", comment: ""))
                .displayXS()
                .foregroundColor(ONETokens.oneInk)
                .multilineTextAlignment(.center)
            Text(NSLocalizedString("discover.music.connectHint", comment: ""))
                .bodySM()
                .foregroundColor(ONETokens.oneAsh)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
        }
        .padding(.top, 60)
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Shimmer

private struct ShimmerModifier: ViewModifier {
    @State private var phase: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .overlay(
                LinearGradient(
                    gradient: Gradient(colors: [.clear, .white.opacity(0.35), .clear]),
                    startPoint: .init(x: phase - 0.5, y: 0.5),
                    endPoint: .init(x: phase + 0.5, y: 0.5)
                )
                .clipShape(RoundedRectangle(cornerRadius: ONETokens.radiusCard))
            )
            .onAppear {
                withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                    phase = 1.5
                }
            }
    }
}

private extension View {
    func shimmering() -> some View { modifier(ShimmerModifier()) }
}
