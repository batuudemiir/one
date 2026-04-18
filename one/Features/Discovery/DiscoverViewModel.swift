//
//  DiscoverViewModel.swift
//  one
//
//  Keşfet sekmesi — ViewModel
//

import SwiftUI
import Combine
import CoreData

enum DiscoverTab: String, CaseIterable {
    case etkinlikler = "Etkinlikler"
    case muzik       = "Müzik"
}

@MainActor
class DiscoverViewModel: ObservableObject {
    @Published var todayEntry: DailyEntry? = nil
    @Published var upcomingEvents: [MoodEvent] = []
    @Published var isLoadingEvents: Bool = false
    @Published var selectedTab: DiscoverTab = .etkinlikler

    let recommendationEngine: RecommendationEngine
    private let context: NSManagedObjectContext
    let preferredCity: String
    private let eventCache = EventCache()
    // Session-level cache: skips fetchRecommendations when mood hasn't changed and results are present
    private var lastRecommendationMoodKey: String = ""

    init(context: NSManagedObjectContext) {
        self.context = context
        self.recommendationEngine = RecommendationEngine(context: context)
        self.preferredCity = UserDefaults.standard.string(forKey: ONETokens.cityPreferenceKey) ?? ONETokens.defaultCity
        loadTodayEntry()
    }

    // MARK: - Load today's entry

    func loadTodayEntry() {
        let today = Calendar.current.startOfDay(for: Date())
        let fetchRequest: NSFetchRequest<DailySong> = DailySong.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "date == %@", today as NSDate)
        fetchRequest.fetchLimit = 1

        do {
            if let item = try context.fetch(fetchRequest).first {
                todayEntry = dailyEntryFrom(item)
            } else {
                todayEntry = nil
            }
        } catch {
            ONELogger.debug("DiscoverViewModel: fetch error \(error)", category: .general)
        }
    }

    // MARK: - Fetch all content

    func fetchContent() async {
        let moodKey = todayEntry.map { "\($0.moodLabel):\($0.moodColorHex)" } ?? ""
        if recommendationEngine.recommendations.isEmpty || moodKey != lastRecommendationMoodKey {
            // Mood context'i engine'e aktar — kişisel açıklamalar için
            if let entry = todayEntry {
                recommendationEngine.currentMoodLabel   = entry.moodLabel
                recommendationEngine.currentMoodColorHex = entry.moodColorHex
                recommendationEngine.currentFeeling     = entry.feeling.rawValue
            }
            await recommendationEngine.fetchRecommendations()
            lastRecommendationMoodKey = moodKey
        }
        guard let entry = todayEntry else { return }
        await loadUpcomingEvents(for: entry)
    }

    // MARK: - Refresh

    func refresh() async {
        loadTodayEntry()
        await recommendationEngine.refreshRecommendations()
        guard let entry = todayEntry else {
            upcomingEvents = []
            return
        }
        eventCache.clear()
        await loadUpcomingEvents(for: entry)
    }

    // MARK: - Upcoming Events

    private func loadUpcomingEvents(for entry: DailyEntry) async {
        // Return cached result if mood + date match (avoids repeated Ticketmaster calls)
        if let cached = eventCache.get(moodColorHex: entry.moodColorHex, moodLabel: entry.moodLabel) {
            upcomingEvents = cached
            return
        }

        isLoadingEvents = true
        let apiEvents = (try? await TicketmasterManager.shared.fetchLiveEvents(for: entry, city: preferredCity)) ?? []
        // Merge real Ticketmaster results with curated local walking/outdoor spots
        let walking = cityWalkingSpots(for: preferredCity)
        let merged = apiEvents + walking
        var seen = Set<String>()
        let deduped = merged.filter { seen.insert($0.title).inserted }
        let sorted  = Array(deduped.sorted { $0.matchPercent > $1.matchPercent }.prefix(16))
        upcomingEvents = sorted
        isLoadingEvents = false

        // Persist for subsequent opens (same mood, same day)
        if !sorted.isEmpty {
            eventCache.save(sorted, moodColorHex: entry.moodColorHex, moodLabel: entry.moodLabel)
        }
    }

    // MARK: - Helper

    private func dailyEntryFrom(_ item: DailySong) -> DailyEntry? {
        guard let date = item.date,
              let songName = item.songName,
              let artistName = item.artistName else { return nil }

        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        let timeStr = item.createdAt.map { formatter.string(from: $0) } ?? "--:--"

        var photoURL: URL? = nil
        if let data = item.photoData {
            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent("\(item.id?.uuidString ?? UUID().uuidString).jpg")
            try? data.write(to: url)
            photoURL = url
        }

        return DailyEntry(
            id: item.id ?? UUID(),
            date: date,
            songName: songName,
            artistName: artistName,
            genre: item.genre ?? "",
            moodColor: Color(hex: item.moodColorHex ?? "#5B8DEF"),
            moodColorHex: item.moodColorHex ?? "#5B8DEF",
            moodLabel: item.moodLabel ?? item.moodWord ?? "",
            feeling: FeelingType(rawValue: item.feeling ?? "calm") ?? .calm,
            feelingLabel: item.feelingLabel ?? "",
            time: timeStr,
            photoURL: photoURL,
            shareWithCircle: item.shareWithCircle,
            weatherIcon: item.weatherIcon ?? "☀️",
            weatherDesc: item.weatherDesc ?? "",
            spotifyURL: nil,
            platform: "Spotify",
            note: item.dailyNote
        )
    }
}
