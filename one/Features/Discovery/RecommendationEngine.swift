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
    
    private let tasteAnalyzer: TasteProfileAnalyzer
    private let spotifyService: SpotifyRecommendationService
    private let appleMusicService: AppleMusicRecommendationService
    private let cache: RecommendationCache
    private let context: NSManagedObjectContext
    
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
        
        // Step 1.5: Check if any service is connected
        let useSpotify = SpotifyManager.shared.isAuthenticated
        let useAppleMusic = await checkAppleMusicAuthorization()
        
        ONELogger.debug("Music Service Status:", category: .discovery)
        ONELogger.debug("Spotify authenticated: \(useSpotify)", category: .discovery)
        ONELogger.debug("Spotify has token: \(SpotifyManager.shared.accessToken != nil)", category: .discovery)
        ONELogger.debug("Apple Music authorized: \(useAppleMusic)", category: .discovery)
        
        // If no service is connected, show error immediately
        if !useSpotify && !useAppleMusic {
            ONELogger.warning("No music service connected", category: .discovery)
            error = .notAuthenticated
            recommendations = []
            isLoading = false
            return
        }
        
        // Step 2: Check cache validity (only if service is connected)
        if cache.isCacheValid() {
            if let cached = cache.getCachedRecommendations() {
                recommendations = cached
                isLoading = false
                ONELogger.success("Loaded \(cached.count) recommendations from cache", category: .discovery)
                return
            }
        }
        
        // Step 3: Analyze taste profile
        let profile = await tasteAnalyzer.analyzeTasteProfile(context: context)
        
        if let profile = profile {
            ONELogger.debug("Taste Profile:", category: .discovery)
            ONELogger.debug("Total entries: \(profile.totalEntries)", category: .discovery)
            ONELogger.debug("Top genres: \(profile.topGenres.joined(separator: ", "))", category: .discovery)
            ONELogger.debug("Top artists: \(profile.topArtists.joined(separator: ", "))", category: .discovery)
        } else {
            ONELogger.info("No taste profile available", category: .discovery)
        }
        
        // Step 4: Fetch recommendations based on profile and service
        do {
            let fetchedRecommendations: [SongRecommendation]
            
            if useSpotify {
                // Priority 1: Spotify
                do {
                    if let profile = profile, profile.totalEntries >= 3 {
                        ONELogger.success("Fetching personalized Spotify recommendations (history: \(profile.totalEntries) songs)", category: .discovery)
                        fetchedRecommendations = try await spotifyService.getRecommendations(
                            profile: profile,
                            limit: 8
                        )
                    } else {
                        ONELogger.info("Fetching generic Spotify recommendations", category: .discovery)
                        fetchedRecommendations = try await spotifyService.getGenericRecommendations(
                            limit: 8
                        )
                    }
                } catch {
                    // Spotify failed, try Apple Music if available
                    if useAppleMusic {
                        ONELogger.warning("Spotify failed, falling back to Apple Music", category: .discovery)
                        if let profile = profile, profile.totalEntries >= 3 {
                            fetchedRecommendations = try await appleMusicService.getRecommendations(
                                profile: profile,
                                limit: 8
                            )
                        } else {
                            fetchedRecommendations = try await appleMusicService.getGenericRecommendations(
                                limit: 8
                            )
                        }
                    } else {
                        // No fallback available, rethrow error
                        throw error
                    }
                }
            } else if useAppleMusic {
                // Priority 2: Apple Music
                if let profile = profile, profile.totalEntries >= 3 {
                    ONELogger.success("Fetching personalized Apple Music recommendations (history: \(profile.totalEntries) songs)", category: .discovery)
                    fetchedRecommendations = try await appleMusicService.getRecommendations(
                        profile: profile,
                        limit: 8
                    )
                } else {
                    ONELogger.info("Fetching generic Apple Music recommendations", category: .discovery)
                    fetchedRecommendations = try await appleMusicService.getGenericRecommendations(
                        limit: 8
                    )
                }
            } else {
                // This should never happen because we check at the beginning
                ONELogger.warning("No music service connected (unexpected)", category: .discovery)
                error = .notAuthenticated
                recommendations = []
                isLoading = false
                return
            }
            
            // Step 5: Update state
            recommendations = fetchedRecommendations
            
            // Step 6: Cache results
            cache.saveRecommendations(fetchedRecommendations, profile: profile)
            
            ONELogger.success("Loaded \(fetchedRecommendations.count) recommendations", category: .discovery)
            
        } catch let recommendationError as RecommendationError {
            // Handle recommendation errors
            ONELogger.error("Recommendation error: \(recommendationError.localizedDescription)", category: .discovery)
            error = recommendationError
            recommendations = []
        } catch {
            ONELogger.error("Network error: \(error.localizedDescription)", category: .discovery)
            self.error = .networkError
            recommendations = []
        }
        
        isLoading = false
    }
    
    // MARK: - Check Apple Music Authorization
    
    private func checkAppleMusicAuthorization() async -> Bool {
        let status = await MusicAuthorization.request()
        return status == .authorized
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
    
    // MARK: - Clear Cache
    
    func clearCache() {
        cache.clearCache()
        recommendations = []
        ONELogger.debug("Cleared recommendations and cache", category: .discovery)
    }
}
