//
//  ColorPickerViewModel.swift
//  one
//
//  ViewModel for the main color picker / song selection flow
//

import SwiftUI
import Combine
import MusicKit
import CoreData

class ColorPickerViewModel: ObservableObject {
    @Published var currentScreen: ScreenType = .today
    @Published var searchQuery: String = ""
    @Published var selectedSong: Song? = nil
    @Published var selectedMood: ONEMood? = nil
    @Published var selectedFeeling: FeelingOption? = nil

    /// P1.2 — Onboarding'de seçilen mood ilk entry için pre-fill edilir.
    /// Kullanıcı ilk save'ini hızlı tamamlayabilsin diye ConfirmScreen
    /// açılır açılmaz mood seçili gelir. Bir kez kullanıldıktan sonra
    /// flag tüketilir.
    init() {
        consumeOnboardingMoodIfNeeded()
    }

    private func consumeOnboardingMoodIfNeeded() {
        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: "onboardingMoodConsumed"),
              let raw = defaults.string(forKey: "onboardingFirstMood"),
              let mood = ONEMood(rawValue: raw) else {
            return
        }
        selectedMood = mood
        defaults.set(true, forKey: "onboardingMoodConsumed")
    }
    @Published var dailyNote: String = ""
    @Published var selectedPhoto: UIImage? = nil
    @Published var shareWithCircle: Bool = false
    @Published var searchResults: [Song] = []
    @Published var errorMessage: String? = nil
    
    // New: Platform Selection
    enum MusicPlatform {
        case appleMusic
        case spotify
    }
    @Published var selectedPlatform: MusicPlatform = .appleMusic
    @Published var showSpotifyAuth = false
    
    private let spotifyManager = SpotifyManager.shared
    private let calendarManager = CalendarManager.shared
    
    // Core Data
    @Published var archiveData: [Date: DailySong] = [:]
    @Published var currentMonthSongs: [DailySong] = []
    @Published var songPatterns: [PersistenceController.SongPattern] = []
    @Published var mostFrequentSong: PersistenceController.SongPattern?
    @Published var calendarSyncEnabled = true
    
    // Archive navigation
    @Published var selectedYear: Int = Calendar.current.component(.year, from: Date())
    @Published var selectedMonth: Int = Calendar.current.component(.month, from: Date())
    
    func saveTodaysSong(context: NSManagedObjectContext) {
        guard let song = selectedSong, let mood = selectedMood else { return }
        
        let platformName = selectedPlatform == .appleMusic ? "Apple Music" : "Spotify"
        
        // Normalize today's date to start of day
        let today = Calendar.current.startOfDay(for: Date())
        
        // Convert ONEMood to legacy Mood struct for persistence
        let legacyMood = Mood(color: mood.color, word: mood.label, isDark: mood.isDark)
        
        PersistenceController.shared.saveDailySong(
            date: today,
            song: song,
            mood: legacyMood,
            note: dailyNote,
            platform: platformName,
            photo: selectedPhoto,
            shareWithCircle: shareWithCircle,
            context: context
        )
        
        // Sync to calendar if enabled
        if calendarSyncEnabled {
            Task {
                let granted = await calendarManager.requestAccess()
                if granted {
                    _ = await calendarManager.createDailySongEvent(
                        date: today,
                        songName: song.name,
                        artistName: song.artist,
                        moodWord: mood.label,
                        note: dailyNote.isEmpty ? nil : dailyNote
                    )
                }
            }
        }
        
        // Reload archive data
        loadArchiveData(context: context)
        loadPatternData(context: context)
    }
    
    func loadArchiveData(context: NSManagedObjectContext) {
        var calendar = Calendar.current
        calendar.locale = LanguageManager.shared.currentLocale
        
        currentMonthSongs = PersistenceController.shared.fetchDailySongsForMonth(
            year: selectedYear,
            month: selectedMonth,
            context: context
        )
        
        // Create dictionary for quick lookup with normalized dates
        var dict: [Date: DailySong] = [:]
        for song in currentMonthSongs {
            if let date = song.date {
                let normalizedDate = calendar.startOfDay(for: date)
                dict[normalizedDate] = song
            }
        }
        archiveData = dict
    }
    
    func navigateMonth(by offset: Int, context: NSManagedObjectContext) {
        var components = DateComponents()
        components.year = selectedYear
        components.month = selectedMonth
        
        guard let currentDate = Calendar.current.date(from: components),
              let newDate = Calendar.current.date(byAdding: .month, value: offset, to: currentDate) else {
            return
        }
        
        selectedYear = Calendar.current.component(.year, from: newDate)
        selectedMonth = Calendar.current.component(.month, from: newDate)
        loadArchiveData(context: context)
    }
    
    func resetToCurrentMonth(context: NSManagedObjectContext) {
        let now = Date()
        selectedYear = Calendar.current.component(.year, from: now)
        selectedMonth = Calendar.current.component(.month, from: now)
        loadArchiveData(context: context)
    }
    
    func getTodaysSong(context: NSManagedObjectContext) -> DailySong? {
        let today = Calendar.current.startOfDay(for: Date())
        return PersistenceController.shared.fetchDailySong(for: today, context: context)
    }
    
    func loadPatternData(context: NSManagedObjectContext) {
        songPatterns = PersistenceController.shared.analyzeSongPatterns(context: context)
        mostFrequentSong = PersistenceController.shared.getMostFrequentSong(context: context)
    }
    
    var filteredSongs: [Song] {
        if searchQuery.isEmpty {
            return mockSongs
        } else {
            if searchResults.isEmpty {
                return mockSongs.filter {
                    $0.name.lowercased().contains(searchQuery.lowercased()) ||
                    $0.artist.lowercased().contains(searchQuery.lowercased())
                }
            }
            return searchResults
        }
    }
    
    func performSearch(query: String) {
        guard !query.isEmpty else {
            DispatchQueue.main.async { 
                self.searchResults = [] 
                self.errorMessage = nil
            }
            return
        }
        
        switch selectedPlatform {
        case .appleMusic:
            performMusicKitSearch(query: query)
        case .spotify:
            performSpotifySearch(query: query)
        }
    }
    
    func performMusicKitSearch(query: String) {
        Task {
            let status = await MusicAuthorization.request()
            guard status == .authorized else { 
                DispatchQueue.main.async {
                    self.errorMessage = "Apple Music izni gerekli."
                    self.searchResults = []
                }
                return 
            }
            
            do {
                var request = MusicCatalogSearchRequest(term: query, types: [MusicKit.Song.self])
                request.limit = 15
                let response = try await request.response()
                
                let fetched = response.songs.map { appleSong in
                    Song(
                        name: appleSong.title,
                        artist: appleSong.artistName,
                        genre: appleSong.genreNames.first ?? "Pop",
                        emoji: "🎵",
                        grad: [Color.blue, Color.purple],
                        shadow: Color.blue.opacity(0.4),
                        artworkURL: appleSong.artwork?.url(width: 300, height: 300)
                    )
                }
                
                DispatchQueue.main.async {
                    self.searchResults = fetched
                    self.errorMessage = nil
                }
            } catch {
                DispatchQueue.main.async {
                    self.errorMessage = error.localizedDescription
                    self.searchResults = []
                    ONELogger.debug("MusicKit search failed: \(error)", category: .music)
                }
            }
        }
    }
    
    func performSpotifySearch(query: String) {
        guard spotifyManager.isAuthenticated else {
            DispatchQueue.main.async {
                self.errorMessage = "Spotify'a bağlanmanız gerekiyor."
                self.searchResults = []
            }
            return
        }
        
        spotifyManager.search(query: query) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let tracks):
                    self?.searchResults = tracks.map { track in
                        Song(
                            name: track.name,
                            artist: track.artistName,
                            genre: "Spotify",
                            emoji: "🎵",
                            grad: [ONETokens.spotifyGreen, ONETokens.spotifyDarkGreen],
                            shadow: ONETokens.spotifyGreen.opacity(0.4),
                            artworkURL: track.album.artworkURL
                        )
                    }
                    self?.errorMessage = nil
                case .failure(let error):
                    self?.errorMessage = error.localizedDescription
                    self?.searchResults = []
                }
            }
        }
    }
    
    func authenticateSpotify() {
        spotifyManager.authenticate()
    }
}
