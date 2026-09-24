# Implementation Plan: Personalized Song Recommendations

## Overview

This implementation adds intelligent song recommendations to the ONE app's Today section. The system analyzes user listening history from Core Data, generates personalized recommendations using Spotify's API, and caches results for performance. The feature includes taste profile analysis, Spotify API integration, caching, and wabi-sabi UI components.

## Tasks

- [x] 1. Create core data models and protocols
  - Create `TasteProfile` struct with topGenres, topArtists, moodPatterns, totalEntries, averageMoodScore, createdAt
  - Create `MoodPattern` struct with moodKey, frequency, percentage
  - Create `SongRecommendation` struct with id, name, artist, coverURL, spotifyURL, genre, recommendationReason
  - Create `RecommendationError` enum with cases: notAuthenticated, insufficientHistory, spotifyAPIError, networkError, cacheError
  - Create `CachedRecommendations` struct with recommendations array, timestamp, profileSnapshot, and isValid() method
  - Requirements: 1.1, 1.3, 10.5, 10.6, 10.7

- [x] 2. Implement TasteProfileAnalyzer
  - [x] 2.1 Create TasteProfileAnalyzer struct with analyzeTasteProfile() method
    - Implement Core Data fetch for all DailySong entries
    - Return nil if entries count < 3
    - Extract top 5 genres by frequency
    - Extract top 5 artists by frequency
    - Calculate mood patterns with frequency and percentage
    - Calculate average mood score (0.0 for dark, 1.0 for light)
    - Ensure averageMoodScore is in range [0.0, 1.0]
    - Requirements: 2.1, 2.2, 2.3, 2.4, 2.5, 2.6, 10.1, 10.2, 10.3, 10.4
  
  - [ ]* 2.2 Write unit tests for TasteProfileAnalyzer
    - Test with 0, 1, 2, 3, 10, 100 entries
    - Test genre frequency calculation accuracy
    - Test artist frequency calculation accuracy
    - Test mood score calculation (all dark, all light, mixed)
    - Test with missing/nil genre or artist fields
    - Requirements: 2.1, 2.2, 2.3, 2.4, 2.5, 2.6

- [x] 3. Implement RecommendationCache
  - [x] 3.1 Create RecommendationCache class with UserDefaults storage
    - Implement saveRecommendations() to serialize and store with timestamp
    - Implement getCachedRecommendations() to deserialize from UserDefaults
    - Implement isCacheValid() checking 24-hour expiry (86400 seconds)
    - Implement clearCache() to remove stored data
    - Implement getCacheAge() returning TimeInterval
    - Handle corrupted data gracefully by returning nil
    - Requirements: 5.1, 5.2, 5.3, 5.4, 5.5, 10.6, 10.7
  
  - [ ]* 3.2 Write unit tests for RecommendationCache
    - Test cache save and retrieve
    - Test cache expiry (fresh vs stale)
    - Test cache invalidation
    - Test with corrupted data
    - Requirements: 5.1, 5.2, 5.3, 5.4, 5.5

- [x] 4. Checkpoint - Ensure all tests pass
  - Ensure all tests pass, ask the user if questions arise.

- [x] 5. Implement SpotifyRecommendationService
  - [x] 5.1 Create SpotifyRecommendationService class with Spotify API integration
    - Implement getRecommendations(profile:limit:) using taste profile
    - Use up to 3 genre seeds from profile.topGenres
    - Use up to 2 artist seeds from profile.topArtists (resolve names to IDs)
    - Ensure total seeds <= 5 (Spotify constraint)
    - Set target_valence=0.7, target_energy=0.6 when averageMoodScore > 0.6
    - Set target_valence=0.3, target_energy=0.4 when averageMoodScore < 0.4
    - Transform SpotifyTrack responses to SongRecommendation objects
    - Handle API errors (401, 429, 500) with appropriate RecommendationError
    - Requirements: 3.1, 3.2, 3.3, 3.4, 3.5, 3.6, 3.7, 7.3, 7.4, 7.5
  
  - [x] 5.2 Implement getGenericRecommendations(limit:) for fallback
    - Use default seed genres: ["indie", "alternative", "pop"]
    - Set target_valence=0.5, target_energy=0.5 (neutral)
    - Transform responses to SongRecommendation objects
    - Requirements: 4.1, 4.2, 4.3, 4.4
  
  - [x] 5.3 Implement resolveArtistIds() helper method
    - Use Spotify search API to convert artist names to IDs
    - Take first result for each artist name
    - Return array of artist IDs
    - Omit artists that cannot be resolved
    - Requirements: 3.6
  
  - [ ]* 5.4 Write unit tests for SpotifyRecommendationService
    - Mock Spotify API responses
    - Test successful recommendation fetch
    - Test error handling (401, 429, 500 status codes)
    - Test seed parameter construction
    - Test artist ID resolution
    - Requirements: 3.1, 3.2, 3.3, 3.4, 3.5, 3.6, 3.7

- [x] 6. Implement RecommendationEngine orchestrator
  - [x] 6.1 Create RecommendationEngine class as @MainActor ObservableObject
    - Add @Published properties: recommendations, isLoading, error
    - Inject dependencies: TasteProfileAnalyzer, SpotifyRecommendationService, RecommendationCache
    - Implement fetchRecommendations() async method
    - Check cache validity first, return cached if valid
    - Check Spotify authentication, set error if not authenticated
    - Analyze taste profile using TasteProfileAnalyzer
    - Fetch personalized recommendations if profile.totalEntries >= 3
    - Fetch generic recommendations if profile is nil or totalEntries < 3
    - Save successful results to cache
    - Set isLoading states appropriately
    - Map errors to RecommendationError
    - Requirements: 1.1, 1.2, 2.1, 2.2, 3.1, 4.1, 4.2, 5.2, 5.3, 6.1, 6.2, 6.3, 6.4, 7.1, 7.2, 7.6
  
  - [x] 6.2 Implement refreshRecommendations() method
    - Clear cache before fetching
    - Call fetchRecommendations()
    - Requirements: 11.1, 11.2, 11.3, 11.4, 11.5
  
  - [x] 6.3 Implement clearCache() method
    - Delegate to RecommendationCache.clearCache()
    - Clear recommendations array
    - Requirements: 5.6, 11.1
  
  - [ ]* 6.4 Write unit tests for RecommendationEngine
    - Test full recommendation flow
    - Test cache-first behavior
    - Test fallback to generic recommendations
    - Test error state management
    - Test loading state transitions
    - Requirements: 1.1, 1.2, 5.2, 5.3, 6.1, 6.2, 6.3, 6.4

- [x] 7. Checkpoint - Ensure all tests pass
  - Ensure all tests pass, ask the user if questions arise.

- [x] 8. Create UI components
  - [x] 8.1 Create RecommendationCardView
    - Display album artwork using AsyncImage
    - Display song name in GeistMono-Regular font
    - Display artist name in GeistMono-Regular font with lighter color
    - Add subtle "Önerildi" badge
    - Handle tap gesture with haptic feedback
    - Animate selection state
    - Match wabi-sabi aesthetic (neutral colors, minimal design)
    - Requirements: 1.3, 1.4, 8.3, 8.4
  
  - [x] 8.2 Create RecommendationsSection view
    - Display "Senin için seçtik" header in GeistMono-Regular
    - Show loading state with skeleton UI matching card design
    - Render horizontal ScrollView with recommendation cards
    - Handle error states with localized messages
    - Show "Keşfet" badge for generic recommendations
    - Add refresh button that calls engine.refreshRecommendations()
    - Requirements: 1.1, 1.2, 1.3, 4.5, 8.1, 8.2, 8.5, 8.6, 11.1, 11.2, 11.3
  
  - [x] 8.3 Integrate RecommendationsSection into TodayEmptyView
    - Add @StateObject for RecommendationEngine
    - Display RecommendationsSection below song search
    - Handle recommendation selection by converting to SongResult
    - Trigger staggered entrance animation on selection
    - Call fetchRecommendations() in .task modifier
    - Requirements: 1.1, 1.4, 1.5, 8.5

- [x] 9. Implement error handling UI
  - [x] 9.1 Add error message views for each error type
    - Display "Spotify'a giriş yapman gerekiyor" with login button for notAuthenticated
    - Display "Daha fazla şarkı seç, sana özel öneriler gelsin" for insufficientHistory
    - Display "Önbellekten" indicator when showing cached data during network error
    - Display error message with retry button for network errors without cache
    - Display "Çok fazla istek, lütfen biraz bekle" for rate limit errors
    - Use GeistMono-Regular font and appropriate colors from design system
    - Requirements: 6.1, 6.2, 7.1, 7.2, 7.3, 7.4, 7.5
  
  - [x] 9.2 Implement Spotify login flow integration
    - Add login button that calls SpotifyManager.shared.authenticate()
    - Auto-fetch recommendations after successful authentication
    - Requirements: 6.2, 6.4

- [x] 10. Add cache management on logout
  - [x] 10.1 Clear recommendation cache when user logs out of Spotify
    - Hook into SpotifyManager logout flow
    - Call recommendationEngine.clearCache()
    - Clear recommendations array
    - Requirements: 5.6

- [x] 11. Performance optimization
  - [x] 11.1 Optimize taste profile analysis for large datasets
    - Limit Core Data fetch to last 100 entries if history is very large
    - Perform analysis on background thread
    - Ensure completion in < 200ms for 100 entries
    - Requirements: 9.3
  
  - [x] 11.2 Implement memory warning handling
    - Clear cache when memory warning received
    - Requirements: 9.5
  
  - [ ]* 11.3 Verify performance benchmarks
    - Test cache load time < 100ms
    - Test API fetch time < 2 seconds
    - Test taste profile analysis < 200ms for 100 entries
    - Test scroll performance at 60 FPS
    - Requirements: 9.1, 9.2, 9.3, 9.4

- [x] 12. Final integration and testing
  - [x] 12.1 Test end-to-end recommendation flow
    - Test with new user (no history)
    - Test with user having 3-10 songs
    - Test with user having 100+ songs
    - Test cache behavior across app restarts
    - Test error scenarios (no network, not authenticated, rate limit)
    - Requirements: 1.1, 1.2, 1.3, 1.4, 1.5, 2.1, 2.2, 3.1, 4.1, 5.1, 5.2, 5.3, 6.1, 7.1, 7.2, 7.3, 7.4
  
  - [x] 12.2 Verify UI matches wabi-sabi design
    - Check font usage (GeistMono-Regular)
    - Check color usage matches design system
    - Check animations are smooth and subtle
    - Check loading states are elegant
    - Requirements: 8.1, 8.2, 8.3, 8.4, 8.5, 8.6

- [x] 13. Final checkpoint - Ensure all tests pass
  - Ensure all tests pass, ask the user if questions arise.

## Notes

- Tasks marked with `*` are optional and can be skipped for faster MVP
- Each task references specific requirements for traceability
- Checkpoints ensure incremental validation
- The design uses Swift, so all implementation will be in Swift
- SpotifyManager already exists and provides authentication and search functionality
- Core Data DailySong entity already exists with necessary fields
- Focus on minimal, elegant implementation matching the app's wabi-sabi aesthetic
