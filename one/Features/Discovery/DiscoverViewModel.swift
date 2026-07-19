//  DiscoverViewModel.swift
//  one

import SwiftUI
import Combine
import CoreData
import CloudKit

// MARK: - MoodColorPalette

private enum MoodColorPalette {
    static func saturated(for canonicalMood: String) -> Color {
        switch canonicalMood {
        case "Ateşli":    return Color(hex: "#E8533A")
        case "Coşkulu":   return Color(hex: "#F0954A")
        case "Mutlu":     return Color(hex: "#F5C842")
        case "Doğal":     return Color(hex: "#6DB574")
        case "Huzurlu":   return Color(hex: "#5B8DEF")
        case "Özgür":     return Color(hex: "#4BBFA8")
        case "Derin":     return Color(hex: "#5C6BC0")
        case "Nostaljik": return Color(hex: "#A1887F")
        case "Gizemli":   return Color(hex: "#7E57C2")
        case "Hassas":    return Color(hex: "#EC407A")
        case "Sessiz":    return Color(hex: "#78909C")
        default:          return Color(hex: "#8E9AAF") // Nötr
        }
    }

    static func pastel(for canonicalMood: String) -> Color {
        switch canonicalMood {
        case "Ateşli":    return Color(hex: "#FAD4CC")
        case "Coşkulu":   return Color(hex: "#FAE0C8")
        case "Mutlu":     return Color(hex: "#FDF3C2")
        case "Doğal":     return Color(hex: "#C8E6CA")
        case "Huzurlu":   return Color(hex: "#C5D8FA")
        case "Özgür":     return Color(hex: "#B2EBE0")
        case "Derin":     return Color(hex: "#C5CAE9")
        case "Nostaljik": return Color(hex: "#D7CCC8")
        case "Gizemli":   return Color(hex: "#D1C4E9")
        case "Hassas":    return Color(hex: "#FCE4EC")
        case "Sessiz":    return Color(hex: "#CFD8DC")
        default:          return Color(hex: "#E8EAF0") // Nötr
        }
    }
}

// MARK: - CrossMoodSection

struct CrossMoodSection: Identifiable {
    let id = UUID()
    let moodLabel: String
    let isContrast: Bool
    let events: [MoodEvent]

    var moodColor: Color {
        MoodColorPalette.saturated(for: canonicalMoodLabel(moodLabel))
    }
    var moodPastel: Color {
        MoodColorPalette.pastel(for: canonicalMoodLabel(moodLabel))
    }
}

// MARK: - DiscoverViewModel

@MainActor
class DiscoverViewModel: ObservableObject {
    @Published var selectedMoodId: String = "huzurlu"
    @Published var todayEntry: DailyEntry? = nil
    @Published var featuredEvent: MoodEvent? = nil
    @Published var upcomingEvents: [MoodEvent] = []
    @Published var musicRecommendations: [SongRecommendation] = []
    @Published var recommendationSections: [RecommendationSection] = []
    @Published var crossMoodSections: [CrossMoodSection] = []
    @Published var generalSections: [RecommendationSection] = []
    @Published var generalMusicRecommendations: [SongRecommendation] = []
    @Published var socialMusicRecommendations: [SongRecommendation] = []
    @Published var headlineCopy: MoodHeadlineCopy = MoodHeadlines.copy(for: "Nötr")
    @Published var recommendationCount: Int = 0
    @Published var isLoadingEvents: Bool = false
    @Published var isLoadingMusic: Bool = false
    @Published var totalEntries: Int = 0

    let recommendationEngine: RecommendationEngine
    private let context: NSManagedObjectContext
    @Published var preferredCity: String
    private let eventCache = EventCache()

    init(context: NSManagedObjectContext) {
        self.context = context
        self.recommendationEngine = RecommendationEngine(context: context)
        self.preferredCity = UserDefaults.standard.string(forKey: ONETokens.cityPreferenceKey) ?? ONETokens.defaultCity
        loadTodayEntry()
        loadTotalEntries()
    }

    func loadTotalEntries() {
        let request: NSFetchRequest<DailySong> = DailySong.fetchRequest()
        totalEntries = (try? context.count(for: request)) ?? 0
    }

    func loadTodayEntry() {
        let today = Calendar.current.startOfDay(for: Date())
        let fetchRequest: NSFetchRequest<DailySong> = DailySong.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "date == %@", today as NSDate)
        fetchRequest.fetchLimit = 1
        if let item = try? context.fetch(fetchRequest).first {
            todayEntry = dailyEntryFrom(item)
        } else {
            todayEntry = nil
        }
    }

    func fetchContent() async {
        guard let entry = todayEntry else { return }
        headlineCopy = MoodHeadlines.copy(for: entry.normalizedMoodLabel)
        async let eventsTask: Void = loadUpcomingEvents(for: entry)
        async let musicTask: Void = loadMusicRecommendations(for: entry)
        _ = await (eventsTask, musicTask)
        updateRecommendationCount()
    }

    func refresh() async {
        loadTodayEntry()
        guard let entry = todayEntry else {
            featuredEvent = nil
            upcomingEvents = []
            crossMoodSections = []
            musicRecommendations = []
            recommendationCount = 0
            return
        }
        eventCache.clear()
        recommendationEngine.clearCache()
        headlineCopy = MoodHeadlines.copy(for: entry.normalizedMoodLabel)
        async let eventsTask: Void = loadUpcomingEvents(for: entry)
        async let musicTask: Void = loadMusicRecommendations(for: entry)
        _ = await (eventsTask, musicTask)
        updateRecommendationCount()
    }

    func fetchContentFor(moodId: String?, kesfetMood: KesfetMood?) async {
        guard let moodId = moodId, let kesfetMood = kesfetMood else {
            // No mood selected. Only fetch general content.
            isLoadingEvents = true
            
            async let generalSectionsTask = ActivityRecommendationEngine.shared.fetchGeneralSections(city: preferredCity)
            async let generalMusicTask = loadGeneralMusicRecommendations()
            async let socialMusicTask = loadSocialMusicRecommendations()
            
            self.generalSections = await generalSectionsTask
            _ = await generalMusicTask
            _ = await socialMusicTask
            
            self.recommendationSections = []
            self.musicRecommendations = []
            self.crossMoodSections = []
            self.upcomingEvents = []
            self.featuredEvent = nil
            
            isLoadingEvents = false
            updateRecommendationCount()
            return
        }

        let canonicalLabel = canonicalMoodLabel(from: moodId)
        
        let syntheticEntry: DailyEntry
        if let baseEntry = todayEntry {
            syntheticEntry = DailyEntry(
                id: baseEntry.id,
                date: baseEntry.date,
                songName: baseEntry.songName,
                artistName: baseEntry.artistName,
                genre: baseEntry.genre,
                moodColor: kesfetMood.color,
                moodColorHex: kesfetMood.color.toHex(),
                moodLabel: canonicalLabel,
                feeling: baseEntry.feeling,
                feelingLabel: baseEntry.feelingLabel,
                time: baseEntry.time,
                photoURL: baseEntry.photoURL,
                shareWithCircle: baseEntry.shareWithCircle,
                weatherIcon: baseEntry.weatherIcon,
                weatherDesc: baseEntry.weatherDesc,
                spotifyURL: baseEntry.spotifyURL,
                platform: baseEntry.platform,
                note: baseEntry.note,
                passed: baseEntry.passed
            )
        } else {
            // Minimal entry to drive mood recommendations if no todayEntry
            syntheticEntry = DailyEntry(
                id: UUID(),
                date: Date(),
                songName: "",
                artistName: "",
                genre: "",
                moodColor: kesfetMood.color,
                moodColorHex: kesfetMood.color.toHex(),
                moodLabel: canonicalLabel,
                feeling: .calm,
                feelingLabel: "Sakin",
                time: "12:00",
                photoURL: nil,
                shareWithCircle: false,
                weatherIcon: "☀️",
                weatherDesc: "Açık",
                spotifyURL: nil,
                platform: "Spotify",
                note: nil,
                passed: false
            )
        }
        
        isLoadingEvents = true
        headlineCopy = MoodHeadlines.copy(for: syntheticEntry.normalizedMoodLabel)
        
        self.recommendationEngine.currentMoodLabel = syntheticEntry.normalizedMoodLabel
        self.recommendationEngine.currentMoodColorHex = syntheticEntry.moodColorHex
        self.recommendationEngine.currentFeeling = syntheticEntry.feeling.rawValue
        self.recommendationEngine.pinnedGenre = syntheticEntry.genre.isEmpty ? nil : syntheticEntry.genre
        
        async let sectionsTask = ActivityRecommendationEngine.shared.fetchSections(for: syntheticEntry, city: preferredCity)
        async let musicTask: Void = loadMusicRecommendations(for: syntheticEntry)
        async let crossMoodTask: Void = loadCrossMoodSections(for: syntheticEntry.normalizedMoodLabel)
        
        // General tasks
        async let generalSectionsTask = ActivityRecommendationEngine.shared.fetchGeneralSections(city: preferredCity)
        async let generalMusicTask = loadGeneralMusicRecommendations()
        async let socialMusicTask = loadSocialMusicRecommendations()
        
        let fetchedSections = await sectionsTask
        _ = await musicTask
        _ = await crossMoodTask
        let fetchedGeneralSections = await generalSectionsTask
        _ = await generalMusicTask
        _ = await socialMusicTask
        
        self.recommendationSections = fetchedSections
        self.generalSections = fetchedGeneralSections
        self.upcomingEvents = fetchedSections.flatMap(\.items)
        self.featuredEvent = self.upcomingEvents.first
        
        isLoadingEvents = false
        updateRecommendationCount()
    }

    // MARK: - Private: Events

    private func loadUpcomingEvents(for entry: DailyEntry) async {
        if let cached = eventCache.get(moodColorHex: entry.moodColorHex, moodLabel: entry.normalizedMoodLabel, city: preferredCity) {
            applyEvents(cached, moodLabel: entry.normalizedMoodLabel)
            await loadCrossMoodSections(for: entry.normalizedMoodLabel)
            return
        }
        isLoadingEvents = true
        defer { isLoadingEvents = false }
        let apiEvents = (try? await TicketmasterManager.shared.fetchLiveEvents(for: entry, city: preferredCity)) ?? []
        let activities = MoodActivityPool.pickActivities(for: entry.normalizedMoodLabel, city: preferredCity)
        let merged = apiEvents + activities
        var seen = Set<String>()
        let deduped = merged.filter { seen.insert($0.title).inserted }
        let sorted = Array(deduped.sorted { $0.matchPercent > $1.matchPercent }.prefix(16))
        if !sorted.isEmpty {
            eventCache.save(sorted, moodColorHex: entry.moodColorHex, moodLabel: entry.normalizedMoodLabel, city: preferredCity)
        }
        applyEvents(sorted, moodLabel: entry.normalizedMoodLabel)
        await loadCrossMoodSections(for: entry.normalizedMoodLabel)
    }

    private func applyEvents(_ events: [MoodEvent], moodLabel: String) {
        upcomingEvents = events
        featuredEvent = events.sorted {
            let aArtist = $0.kind == .artistConcert
            let bArtist = $1.kind == .artistConcert
            if aArtist != bArtist { return aArtist }
            return $0.matchPercent > $1.matchPercent
        }.first
    }

    private func loadCrossMoodSections(for moodLabel: String) async {
        let neighbors = MoodAdjacency.neighbors(for: moodLabel)
        let contrast = MoodAdjacency.contrastMood(for: moodLabel)
        var sections: [CrossMoodSection] = []

        for neighbor in neighbors {
            let events = MoodActivityPool.pickActivities(for: neighbor, city: preferredCity, count: 4)
            if !events.isEmpty {
                sections.append(CrossMoodSection(moodLabel: neighbor, isContrast: false, events: events))
            }
        }
        if let contrast {
            let events = MoodActivityPool.pickActivities(for: contrast, city: preferredCity, count: 4)
            if !events.isEmpty {
                sections.append(CrossMoodSection(moodLabel: contrast, isContrast: true, events: events))
            }
        }
        crossMoodSections = sections
    }

    // MARK: - Private: Music

    private func loadMusicRecommendations(for entry: DailyEntry) async {
        guard musicRecommendations.isEmpty else { return }
        isLoadingMusic = true
        recommendationEngine.currentMoodLabel    = entry.normalizedMoodLabel
        recommendationEngine.currentMoodColorHex = entry.moodColorHex
        recommendationEngine.currentFeeling      = entry.feeling.rawValue
        await recommendationEngine.fetchRecommendations()
        musicRecommendations = recommendationEngine.recommendations
        isLoadingMusic = false
    }
    
    private func loadGeneralMusicRecommendations() async {
        guard generalMusicRecommendations.isEmpty else { return }
        isLoadingMusic = true
        // fetch general
        let oldMood = recommendationEngine.currentMoodLabel
        recommendationEngine.currentMoodLabel = "" // bypass mood to get generic
        await recommendationEngine.fetchRecommendations()
        generalMusicRecommendations = recommendationEngine.recommendations
        recommendationEngine.currentMoodLabel = oldMood // restore
        isLoadingMusic = false
    }

    private func loadSocialMusicRecommendations() async {
        // Build recommendations from friend shares
        let shares = (try? await CloudKitManager.shared.fetchFriendsDailySharesAsync(for: Date())) ?? []
        var socialRecs: [SongRecommendation] = []
        for data in shares {
            guard let share = data.share,
                  let songName = share["songName"] as? String, !songName.isEmpty,
                  let artistName = share["artistName"] as? String, !artistName.isEmpty else {
                continue
            }
            
            let friendName = data.user["displayName"] as? String ?? "Bir arkadaşın"
            let genre = share["genre"] as? String ?? ""
            
            // Try parsing album art if available, otherwise nil
            var coverURL: URL? = nil
            if let artStr = share["albumArtURL"] as? String, let url = URL(string: artStr) {
                coverURL = url
            }
            
            let rec = SongRecommendation(
                id: share.recordID.recordName,
                name: songName,
                artist: artistName,
                coverURL: coverURL,
                spotifyURL: share["spotifyURL"] as? String,
                genre: genre,
                recommendationReason: "\(friendName) dinledi",
                source: .spotify // assume spotify or defaults
            )
            socialRecs.append(rec)
        }
        
        // Remove duplicates by song name
        var seen = Set<String>()
        var deduped: [SongRecommendation] = []
        for rec in socialRecs {
            let key = "\(rec.name)-\(rec.artist)".lowercased()
            if !seen.contains(key) {
                seen.insert(key)
                deduped.append(rec)
            }
        }
        
        await MainActor.run {
            self.socialMusicRecommendations = Array(deduped.prefix(10))
        }
    }

    // MARK: - Private: Count

    private func updateRecommendationCount() {
        recommendationCount = recommendationSections.reduce(0) { $0 + $1.items.count }
            + musicRecommendations.count
            + crossMoodSections.reduce(0) { $0 + $1.events.count }
    }

    // MARK: - Private: Conversion

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
            note: item.dailyNote,
            passed: item.passed
        )
    }
}
