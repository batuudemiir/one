//
//  RecommendationEngine.swift
//  one
//
//  Orchestrates the recommendation workflow
//

import Foundation
import CoreData
import SwiftUI
import Combine
import UIKit
import MusicKit

@MainActor
class RecommendationEngine: ObservableObject {
    
    @Published var recommendations: [SongRecommendation] = []
    @Published var isLoading: Bool = false
    @Published var error: RecommendationError?
    /// The taste profile built from the user's history — used by the UI to show genre chips.
    @Published var tasteProfile: TasteProfile?
    /// When set, the next fetch will prioritise this genre as the primary seed.
    @Published var pinnedGenre: String? = nil
    /// Bugünkü mood context — öneriler için kişiselleştirme kaynağı
    var currentMoodLabel: String = ""
    var currentMoodColorHex: String = ""
    var currentFeeling: String = ""

    private let tasteAnalyzer: TasteProfileAnalyzer
    private let spotifyService: SpotifyRecommendationService
    private let appleMusicService: AppleMusicRecommendationService
    private let cache: RecommendationCache
    private let context: NSManagedObjectContext
    private var cachedAppleMusicAuth: Bool? = nil
    
    init(context: NSManagedObjectContext) {
        self.context = context
        self.tasteAnalyzer = TasteProfileAnalyzer()
        self.spotifyService = SpotifyRecommendationService()
        self.appleMusicService = AppleMusicRecommendationService()
        self.cache = RecommendationCache()
        
        // Setup memory warning observer
        NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self = self else { return }
            Task { @MainActor in
                self.handleMemoryWarning()
            }
        }
        
        // Observe Spotify authentication changes
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("SpotifyAuthenticationChanged"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self = self else { return }
            Task { @MainActor in
                await self.fetchRecommendations()
            }
        }
        
        // Observe Apple Music authentication changes
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("AppleMusicAuthenticationChanged"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self = self else { return }
            Task { @MainActor in
                await self.fetchRecommendations()
            }
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - Memory Warning Handler
    
    private func handleMemoryWarning() {
        ONELogger.warning("Memory warning received, clearing recommendation cache", category: .discovery)
        cache.clearCache()
        recommendations = []
    }
    
    // MARK: - Fetch Recommendations
    
    func fetchRecommendations() async {
        // Step 1: Set loading state
        isLoading = true
        error = nil
        
        // Step 1.5: Check services in parallel to avoid sequential waiting
        let useSpotify = SpotifyManager.shared.isAuthenticated
        async let appleMusicAuthCheck = checkAppleMusicAuthorization()
        let useAppleMusic = await appleMusicAuthCheck
        
        ONELogger.debug("Music Service Status:", category: .discovery)
        ONELogger.debug("Spotify authenticated: \(useSpotify)", category: .discovery)
        ONELogger.debug("Spotify has token: \(SpotifyManager.shared.accessToken != nil)", category: .discovery)
        ONELogger.debug("Apple Music authorized: \(useAppleMusic)", category: .discovery)
        
        // If no service is connected, serve curated fallback
        if !useSpotify && !useAppleMusic {
            ONELogger.warning("No music service connected — serving curated fallback", category: .discovery)
            recommendations = Self.curatedFallback
            isLoading = false
            return
        }
        
        // Step 2: Check cache (single JSON decode — getCachedRecommendations handles expiry)
        if let cached = cache.getCachedRecommendations() {
            recommendations = cached
            isLoading = false
            ONELogger.success("Loaded \(cached.count) recommendations from cache", category: .discovery)
            return
        }
        
        // Step 3: Analyze taste profile
        var profile = await tasteAnalyzer.analyzeTasteProfile(context: context)

        // If a genre is pinned (user tapped a chip), use ONLY that genre as seed.
        // topTrackIds and topArtists are cleared so they don't override the genre filter
        // (e.g. user has Turkish pop tracks in history but wants Techno recommendations).
        if let pinned = pinnedGenre, let base = profile {
            profile = TasteProfile(
                topGenres: [pinned],
                topArtists: [],
                topTrackIds: [],
                moodPatterns: base.moodPatterns,
                totalEntries: base.totalEntries,
                averageMoodScore: base.averageMoodScore,
                createdAt: base.createdAt,
                weightedGenres: [pinned, pinned, pinned]
            )
        }

        tasteProfile = profile

        if let profile = profile {
            ONELogger.debug("Taste Profile:", category: .discovery)
            ONELogger.debug("Total entries: \(profile.totalEntries)", category: .discovery)
            ONELogger.debug("Top genres: \(profile.topGenres.joined(separator: ", "))", category: .discovery)
            ONELogger.debug("Weighted genres: \(profile.weightedGenres.prefix(8).joined(separator: ", "))", category: .discovery)
            ONELogger.debug("Top artists: \(profile.topArtists.joined(separator: ", "))", category: .discovery)
        } else {
            ONELogger.info("No taste profile available", category: .discovery)
        }
        
        // Step 4: Fetch recommendations with 5s timeout
        // Capture as immutable constant to satisfy Swift 6 concurrency rules
        let capturedProfile = profile
        do {
            let fetchedRecommendations: [SongRecommendation] = try await withTimeout(seconds: 8) {
                if useSpotify {
                    do {
                        if let profile = capturedProfile, profile.totalEntries >= 3 {
                            await MainActor.run { ONELogger.success("Fetching personalized Spotify recommendations (history: \(profile.totalEntries) songs)", category: .discovery) }
                            return try await self.spotifyService.getRecommendations(
                                profile: profile,
                                limit: 8
                            )
                        } else {
                            await MainActor.run { ONELogger.info("Fetching generic Spotify recommendations", category: .discovery) }
                            return try await self.spotifyService.getGenericRecommendations(
                                limit: 8
                            )
                        }
                    } catch {
                        if useAppleMusic {
                            await MainActor.run { ONELogger.warning("Spotify failed, falling back to Apple Music", category: .discovery) }
                            if let profile = capturedProfile, profile.totalEntries >= 3 {
                                return try await self.appleMusicService.getRecommendations(
                                    profile: profile,
                                    limit: 8
                                )
                            } else {
                                return try await self.appleMusicService.getGenericRecommendations(
                                    limit: 8
                                )
                            }
                        } else {
                            throw error
                        }
                    }
                } else if useAppleMusic {
                    if let profile = capturedProfile, profile.totalEntries >= 3 {
                        await MainActor.run { ONELogger.success("Fetching personalized Apple Music recommendations (history: \(profile.totalEntries) songs)", category: .discovery) }
                        return try await self.appleMusicService.getRecommendations(
                            profile: profile,
                            limit: 8
                        )
                    } else {
                        await MainActor.run { ONELogger.info("Fetching generic Apple Music recommendations", category: .discovery) }
                        return try await self.appleMusicService.getGenericRecommendations(
                            limit: 8
                        )
                    }
                } else {
                    throw RecommendationError.notAuthenticated
                }
            }
            
            // Step 5: Kişiselleştirme — mood context'e göre reason text zenginleştir
            let enriched = Self.enrichReasons(
                recommendations: fetchedRecommendations,
                moodLabel: currentMoodLabel,
                feeling: currentFeeling,
                tasteProfile: profile
            )
            // Step 6: Dismissed olanları filtrele
            let dismissed = dismissedTrackIDs
            let filtered = enriched.filter { !dismissed.contains($0.id) }

            // Step 7: Mood affinity re-rank — bugünkü mood'la eşleşen reason öne çıksın
            let moodKey = currentMoodLabel.lowercased()
            let reranked: [SongRecommendation] = {
                guard !moodKey.isEmpty else { return filtered }
                var arr = filtered
                if let bestIdx = arr.indices.first(where: { arr[$0].recommendationReason?.lowercased().contains(moodKey) == true }),
                   bestIdx != 0 {
                    arr.swapAt(0, bestIdx)
                }
                return arr
            }()
            recommendations = reranked

            // Step 8: Cache results
            cache.saveRecommendations(reranked, profile: profile)

            ONELogger.success("Loaded \(enriched.count) recommendations (mood: \(currentMoodLabel))", category: .discovery)
            
        } catch is CancellationError {
            if let cached = cache.getCachedRecommendations(), !cached.isEmpty {
                recommendations = cached
            } else if recommendations.isEmpty {
                recommendations = Self.curatedFallback
            }
        } catch let recommendationError as RecommendationError {
            ONELogger.error("Recommendation error: \(recommendationError.localizedDescription)", category: .discovery)
            error = recommendationError
            if let cached = cache.getCachedRecommendations(), !cached.isEmpty {
                ONELogger.info("Serving stale cache after error", category: .discovery)
                recommendations = cached
            } else if recommendations.isEmpty {
                recommendations = Self.curatedFallback
            }
        } catch {
            ONELogger.error("Network error: \(error.localizedDescription)", category: .discovery)
            self.error = .networkError
            if let cached = cache.getCachedRecommendations(), !cached.isEmpty {
                ONELogger.info("Serving stale cache after network error", category: .discovery)
                recommendations = cached
            } else if recommendations.isEmpty {
                recommendations = Self.curatedFallback
            }
        }
        
        isLoading = false
    }
    
    // MARK: - Check Apple Music Authorization

    private func checkAppleMusicAuthorization() async -> Bool {
        if let cached = cachedAppleMusicAuth { return cached }
        let status = await MusicAuthorization.request()
        let result = status == .authorized
        cachedAppleMusicAuth = result
        return result
    }
    
    // MARK: - Refresh Recommendations

    func refreshRecommendations() async {
        ONELogger.debug("Refreshing recommendations...", category: .discovery)

        // Clear cache to force fresh fetch
        cache.clearCache()

        // Clear current recommendations immediately for better UX
        recommendations = []

        // Fetch fresh recommendations
        await fetchRecommendations()
    }

    // MARK: - Filter By Genre (chip tap)

    /// Pins a genre as the primary seed and immediately re-fetches.
    /// Pass nil to clear the filter and fetch normally.
    func filterByGenre(_ genre: String?) async {
        pinnedGenre = genre
        cache.clearCache()
        recommendations = []
        await fetchRecommendations()
    }
    
    // MARK: - Clear Cache

    func clearCache() {
        cache.clearCache()
        recommendations = []
        ONELogger.debug("Cleared recommendations and cache", category: .discovery)
    }

    // MARK: - Dismissed Tracks

    private static let dismissedTracksKey = "dismissedRecommendationTrackIDs"
    private let maxDismissedTracks = 50

    /// Kullanıcının "ilginç değil" dediği track ID listesi (UserDefaults).
    private var dismissedTrackIDs: Set<String> {
        let arr = UserDefaults.standard.stringArray(forKey: Self.dismissedTracksKey) ?? []
        return Set(arr)
    }

    /// Bir öneriyi kalıcı olarak gizle. Bir sonraki fetch bu track'i atlar.
    func dismissRecommendation(_ rec: SongRecommendation) {
        var dismissed = UserDefaults.standard.stringArray(forKey: Self.dismissedTracksKey) ?? []
        let id = rec.id
        guard !dismissed.contains(id) else { return }
        dismissed.append(id)
        // Son 50'yi tut (sonsuz büyümeyi önle)
        if dismissed.count > maxDismissedTracks {
            dismissed = Array(dismissed.suffix(maxDismissedTracks))
        }
        UserDefaults.standard.set(dismissed, forKey: Self.dismissedTracksKey)
        // UI'dan hemen kaldır
        recommendations.removeAll { $0.id == id }
        ONELogger.info("Dismissed track: \(id)", category: .discovery)
    }

    // MARK: - Curated Fallback

    // MARK: - Timeout Helper

    private func withTimeout<T: Sendable>(seconds: TimeInterval, operation: @escaping @Sendable () async throws -> T) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask { try await operation() }
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                throw RecommendationError.networkError
            }
            guard let result = try await group.next() else {
                throw RecommendationError.networkError
            }
            group.cancelAll()
            return result
        }
    }

    // MARK: - Reason Enrichment (mood + taste)

    /// Önerilere kullanıcının mood'una ve zevkine göre kişisel açıklama metni ekler.
    static func enrichReasons(
        recommendations: [SongRecommendation],
        moodLabel: String,
        feeling: String,
        tasteProfile: TasteProfile?
    ) -> [SongRecommendation] {
        guard !recommendations.isEmpty else { return recommendations }

        let topGenre = tasteProfile?.topGenres.first ?? ""
        let topArtist = tasteProfile?.topArtists.first ?? ""

        // Mood'a göre açıklama kategorileri
        let moodKey = moodLabel.lowercased()
        let moodReason: String = {
            if moodKey.contains("huzur") || moodKey.contains("sakin") || feeling == "calm" {
                return "Huzurlu hissin için"
            } else if moodKey.contains("enerjik") || moodKey.contains("güçlü") || feeling == "energetic" {
                return "Enerjini yükseltiyor"
            } else if moodKey.contains("mutlu") || moodKey.contains("neşe") || feeling == "happy" {
                return "Mutlu mood'una göre"
            } else if moodKey.contains("melankolik") || moodKey.contains("hüzün") || feeling == "melancholic" {
                return "Duygusal tonuna uygun"
            } else if moodKey.contains("odak") || moodKey.contains("konsantre") || feeling == "focused" {
                return "Odaklanmana destek"
            } else if moodKey.contains("özgür") || moodKey.contains("rahat") {
                return "Özgür hissin gibi"
            } else if !moodLabel.isEmpty {
                return "\(moodLabel) hissine göre"
            } else {
                return "Zevkine göre seçildi"
            }
        }()

        // Artist match reason
        let artistReason: String? = topArtist.isEmpty ? nil : "\(topArtist) dinleyenler için"

        // Genre match reason
        let genreReason: String? = topGenre.isEmpty ? nil : "\(topGenre) zevkine uygun"

        return recommendations.enumerated().map { index, rec in
            // Featured kart (0. index) mood'a göre, diğerleri dönüşümlü
            let reason: String
            if index == 0 {
                reason = moodReason
            } else if index % 3 == 1, let ar = artistReason {
                reason = ar
            } else if index % 3 == 2, let gr = genreReason {
                reason = gr
            } else {
                reason = moodReason
            }
            return SongRecommendation(
                id: rec.id,
                name: rec.name,
                artist: rec.artist,
                coverURL: rec.coverURL,
                spotifyURL: rec.spotifyURL,
                genre: rec.genre,
                recommendationReason: reason,
                source: rec.source
            )
        }
    }

    static let curatedFallback: [SongRecommendation] = [
        SongRecommendation(id: "cur-1", name: "Redbone", artist: "Childish Gambino", coverURL: nil, spotifyURL: nil, genre: "Soul", recommendationReason: "Keşfet için seçtik", source: .appleMusic),
        SongRecommendation(id: "cur-2", name: "Midnight City", artist: "M83", coverURL: nil, spotifyURL: nil, genre: "Synth-pop", recommendationReason: "Keşfet için seçtik", source: .appleMusic),
        SongRecommendation(id: "cur-3", name: "Blinding Lights", artist: "The Weeknd", coverURL: nil, spotifyURL: nil, genre: "Synth-pop", recommendationReason: "Keşfet için seçtik", source: .appleMusic),
        SongRecommendation(id: "cur-4", name: "Teardrop", artist: "Massive Attack", coverURL: nil, spotifyURL: nil, genre: "Trip-Hop", recommendationReason: "Keşfet için seçtik", source: .appleMusic),
        SongRecommendation(id: "cur-5", name: "Last Last", artist: "Burna Boy", coverURL: nil, spotifyURL: nil, genre: "Afrobeats", recommendationReason: "Keşfet için seçtik", source: .appleMusic),
        SongRecommendation(id: "cur-6", name: "Strobe", artist: "deadmau5", coverURL: nil, spotifyURL: nil, genre: "Electronic", recommendationReason: "Keşfet için seçtik", source: .appleMusic),
    ]
}
