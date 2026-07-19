//
//  WeeklyPlaylistService.swift
//  one
//
//  Haftalık mood playlist — haftanın mood dağılımına göre şarkı önerileri
//

import SwiftUI
import Combine
import CoreData
import MusicKit

@MainActor
class WeeklyPlaylistService: ObservableObject {

    @Published var weekEntries: [DailyEntry] = []
    @Published var playlistSongs: [SongRecommendation] = []
    @Published var isLoading = false
    @Published var dominantMood: String? = nil
    @Published var moodDistribution: [(mood: String, color: String, count: Int)] = []

    private let context: NSManagedObjectContext

    init(context: NSManagedObjectContext) {
        self.context = context
    }

    // MARK: - Load Week Data

    func loadCurrentWeek() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        guard let weekStart = calendar.date(byAdding: .day, value: -6, to: today) else { return }

        let fetchRequest: NSFetchRequest<DailySong> = DailySong.fetchRequest()
        fetchRequest.predicate = NSPredicate(
            format: "date >= %@ AND date <= %@",
            weekStart as NSDate,
            today as NSDate
        )
        fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \DailySong.date, ascending: true)]

        do {
            let items = try context.fetch(fetchRequest)
            weekEntries = items.compactMap { item -> DailyEntry? in
                guard let date = item.date,
                      let songName = item.songName,
                      let artistName = item.artistName else { return nil }

                let formatter = DateFormatter()
                formatter.dateFormat = "HH:mm"
                let timeStr = item.createdAt.map { formatter.string(from: $0) } ?? "--:--"

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
                    photoURL: nil,
                    shareWithCircle: item.shareWithCircle,
                    weatherIcon: item.weatherIcon ?? "☀️",
                    weatherDesc: item.weatherDesc ?? "",
                    spotifyURL: nil,
                    platform: item.platform ?? "Spotify",
                    note: item.dailyNote,
                    passed: item.passed
                )
            }

            analyzeMoodDistribution()
        } catch {
            ONELogger.error("WeeklyPlaylist: fetch error \(error)", category: .general)
        }
    }

    // MARK: - Mood Analysis

    private func analyzeMoodDistribution() {
        var moodCounts: [String: (color: String, count: Int)] = [:]

        for entry in weekEntries {
            let mood = entry.normalizedMoodLabel
            if let existing = moodCounts[mood] {
                moodCounts[mood] = (color: existing.color, count: existing.count + 1)
            } else {
                moodCounts[mood] = (color: entry.moodColorHex, count: 1)
            }
        }

        moodDistribution = moodCounts
            .map { (mood: $0.key, color: $0.value.color, count: $0.value.count) }
            .sorted { $0.count > $1.count }

        dominantMood = moodDistribution.first?.mood
    }

    // MARK: - Fetch Playlist

    func fetchPlaylist() async {
        guard weekEntries.count >= 3 else { return }
        isLoading = true
        defer { isLoading = false }

        // Build genre frequency map to produce a weighted pool (preserves how often
        // each genre appeared this week — dominant styles get more seeds).
        var genreFreq: [String: Int] = [:]
        for entry in weekEntries where !entry.genre.isEmpty {
            genreFreq[entry.genre, default: 0] += 1
        }
        let topGenres = genreFreq.sorted { $0.value > $1.value }.prefix(5).map { $0.key }
        let maxFreq = Double(genreFreq.values.max() ?? 1)
        var weightedGenres: [String] = []
        for (genre, count) in genreFreq.sorted(by: { $0.value > $1.value }) {
            let slots = max(1, Int((Double(count) / maxFreq * 3).rounded()))
            weightedGenres += Array(repeating: genre, count: slots)
        }

        let artists = weekEntries.map { $0.artistName }
        let uniqueArtists = Array(Set(artists)).prefix(5).map { String($0) }

        let profile = TasteProfile(
            topGenres: topGenres,
            topArtists: uniqueArtists,
            topTrackIds: [],
            moodPatterns: moodDistribution.map {
                MoodPattern(moodKey: $0.mood, frequency: $0.count, percentage: Double($0.count) / Double(weekEntries.count))
            },
            totalEntries: weekEntries.count,
            averageMoodScore: 0.5,
            createdAt: Date(),
            weightedGenres: weightedGenres
        )

        // Try Spotify first, then Apple Music
        let useSpotify = SpotifyManager.shared.isAuthenticated

        do {
            if useSpotify {
                let service = SpotifyRecommendationService()
                playlistSongs = try await service.getRecommendations(profile: profile, limit: 10)
            } else {
                let service = AppleMusicRecommendationService()
                playlistSongs = try await service.getRecommendations(profile: profile, limit: 10)
            }
        } catch {
            ONELogger.error("WeeklyPlaylist: fetch error \(error)", category: .discovery)
            playlistSongs = RecommendationEngine.curatedFallback
        }
    }

    // MARK: - Create Apple Music Playlist (ONE+ Premium)

    @Published var isCreatingPlaylist = false
    @Published var createdPlaylistURL: URL? = nil
    @Published var playlistError: String? = nil

    /// Creates an Apple Music playlist from this week's recommendations (ONE+ Premium).
    func createAppleMusicPlaylist() async {
        guard !playlistSongs.isEmpty else {
            playlistError = NSLocalizedString("premium.playlist.noSongs", comment: "")
            return
        }

        isCreatingPlaylist = true
        playlistError = nil
        defer { isCreatingPlaylist = false }

        // MusicKit authorization
        let status = await MusicAuthorization.request()
        guard status == .authorized else {
            playlistError = NSLocalizedString("premium.playlist.authRequired", comment: "")
            return
        }
        // Playlist name: "ONE+ Huzur — 14 Nis"
        let fmt = DateFormatter()
            fmt.locale = LanguageManager.shared.currentLocale
            fmt.dateFormat = "d MMM"
            let moodLabel = dominantMood ?? "ONE"
            let playlistName = "ONE+ \(moodLabel) — \(fmt.string(from: Date()))"
            let playlistDesc = NSLocalizedString("premium.playlist.description", comment: "")

            if #available(iOS 16, *) {
                // Step 2: Create the playlist
                let playlist: MusicKit.Playlist
                do {
                    playlist = try await MusicLibrary.shared.createPlaylist(
                        name: playlistName,
                        description: playlistDesc,
                        authorDisplayName: "ONE"
                    )
                } catch {
                    playlistError = "Playlist oluşturulamadı: \(error.localizedDescription)"
                    ONELogger.error("createPlaylist failed", error: error, category: .discovery)
                    return
                }

                // Allow the playlist to propagate to Apple's servers before adding tracks
                try? await Task.sleep(nanoseconds: 500_000_000) // 500ms

                // Step 3: Search each recommended song in the Apple Music catalog
                var foundSongs: [MusicKit.Song] = []
                for rec in playlistSongs {
                    var req = MusicCatalogSearchRequest(
                        term: "\(rec.name) \(rec.artist)",
                        types: [MusicKit.Song.self]
                    )
                    req.limit = 1
                    do {
                        let resp = try await req.response()
                        if let song = resp.songs.first { foundSongs.append(song) }
                    } catch {
                        ONELogger.warning("Could not find '\(rec.name)' on Apple Music", category: .discovery)
                    }
                }

                guard !foundSongs.isEmpty else {
                    playlistError = NSLocalizedString("premium.playlist.noMatchFound", comment: "")
                    return
                }

                // Step 4: Add songs — try batch first, fall back to per-song
                do {
                    for song in foundSongs {
                        try await MusicLibrary.shared.add(song, to: playlist)
                    }
                    ONELogger.success("Added \(foundSongs.count) tracks to '\(playlistName)'", category: .discovery)
                } catch {
                    ONELogger.warning("Playlist add failed: \(error.localizedDescription)", category: .discovery)
                    playlistError = "Şarkılar eklenemedi: \(error.localizedDescription)"
                    return
                }

                // Open the playlist in Apple Music
                createdPlaylistURL = URL(string: "music://music.apple.com/library/playlist/\(playlist.id.rawValue)")
                    ?? URL(string: "music://")
                ONELogger.success("Apple Music playlist created: \(playlistName)", category: .discovery)
            } else {
                playlistError = NSLocalizedString("premium.playlist.iosTooOld", comment: "")
            }
    }
}
