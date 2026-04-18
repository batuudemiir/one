# Requirements Document: Personalized Song Recommendations

## Introduction

This document specifies the requirements for adding intelligent song recommendations to the ONE mood tracking app. The system analyzes user listening history from Core Data, generates personalized recommendations using Spotify's API, and presents them in the "Bugün" (Today) section when no song has been selected yet. The feature aims to reduce friction in song selection while maintaining the app's minimal, wabi-sabi aesthetic.

## Glossary

- **System**: The personalized song recommendation feature within the ONE app
- **RecommendationEngine**: Component that orchestrates the recommendation workflow
- **TasteProfileAnalyzer**: Component that analyzes user listening history to build taste profiles
- **SpotifyRecommendationService**: Component that interfaces with Spotify's recommendation API
- **RecommendationCache**: Component that stores and manages cached recommendations
- **TasteProfile**: Data structure containing user's music preferences (genres, artists, moods)
- **SongRecommendation**: Data structure representing a recommended song with metadata
- **DailySong**: Core Data entity storing user's daily song selections
- **Cache**: Temporary storage for recommendations with 24-hour validity
- **Seed**: Parameter used by Spotify API (genre, artist, or track) to generate recommendations
- **Generic Recommendations**: Fallback recommendations for users without sufficient history

## Requirements

### Requirement 1: Recommendation Display

**User Story:** As a user, I want to see personalized song recommendations when I open the Today section, so that I can quickly find music that matches my taste without searching.

#### Acceptance Criteria

1. WHEN a user opens the Today section without having selected a song THEN the System SHALL display 5-10 personalized recommendations
2. WHEN recommendations are loading THEN the System SHALL display a skeleton loading state
3. WHEN recommendations are displayed THEN the System SHALL show song name, artist name, and album artwork for each recommendation
4. WHEN a user taps a recommendation THEN the System SHALL provide haptic feedback and select that song
5. WHEN a recommendation is selected THEN the System SHALL display the mood and feeling selection interface

### Requirement 2: Taste Profile Analysis

**User Story:** As a user, I want the system to learn from my listening history, so that recommendations become more personalized over time.

#### Acceptance Criteria

1. WHEN analyzing taste profile THEN the TasteProfileAnalyzer SHALL query all DailySong entries from Core Data
2. WHEN the user has fewer than 3 song entries THEN the TasteProfileAnalyzer SHALL return nil
3. WHEN the user has 3 or more song entries THEN the TasteProfileAnalyzer SHALL extract the top 5 most frequent genres
4. WHEN the user has 3 or more song entries THEN the TasteProfileAnalyzer SHALL extract the top 5 most frequent artists
5. WHEN analyzing mood patterns THEN the TasteProfileAnalyzer SHALL calculate the average mood score in range [0.0, 1.0]
6. WHEN creating a TasteProfile THEN the System SHALL include genre frequency, artist frequency, mood patterns, and total entry count

### Requirement 3: Personalized Recommendation Fetching

**User Story:** As a user with listening history, I want to receive recommendations based on my preferences, so that I discover music I'm likely to enjoy.

#### Acceptance Criteria

1. WHEN the user has a valid TasteProfile THEN the SpotifyRecommendationService SHALL use up to 3 genre seeds from the profile
2. WHEN the user has a valid TasteProfile THEN the SpotifyRecommendationService SHALL use up to 2 artist seeds from the profile
3. WHEN calling Spotify API THEN the SpotifyRecommendationService SHALL ensure total seeds (genres + artists + tracks) do not exceed 5
4. WHEN the user's average mood score is above 0.6 THEN the SpotifyRecommendationService SHALL set target valence to 0.7 and target energy to 0.6
5. WHEN the user's average mood score is below 0.4 THEN the SpotifyRecommendationService SHALL set target valence to 0.3 and target energy to 0.4
6. WHEN artist names need to be resolved THEN the SpotifyRecommendationService SHALL convert artist names to Spotify artist IDs using the search API
7. WHEN the Spotify API returns results THEN the SpotifyRecommendationService SHALL transform them into SongRecommendation objects

### Requirement 4: Generic Recommendation Fallback

**User Story:** As a new user without listening history, I want to see music recommendations, so that I can start using the app immediately.

#### Acceptance Criteria

1. WHEN the user has no TasteProfile THEN the System SHALL fetch generic recommendations
2. WHEN the user has fewer than 3 song entries THEN the System SHALL fetch generic recommendations
3. WHEN fetching generic recommendations THEN the SpotifyRecommendationService SHALL use default seed genres ["indie", "alternative", "pop"]
4. WHEN fetching generic recommendations THEN the SpotifyRecommendationService SHALL set target valence to 0.5 and target energy to 0.5
5. WHEN displaying generic recommendations THEN the System SHALL show a "Keşfet" badge instead of "Senin için"

### Requirement 5: Recommendation Caching

**User Story:** As a user, I want recommendations to load quickly on subsequent visits, so that I don't waste time waiting for API calls.

#### Acceptance Criteria

1. WHEN recommendations are successfully fetched THEN the RecommendationCache SHALL save them to UserDefaults with a timestamp
2. WHEN the RecommendationEngine requests recommendations THEN the System SHALL check cache validity before making API calls
3. WHEN cached recommendations exist and are less than 24 hours old THEN the System SHALL return cached recommendations
4. WHEN cached recommendations are more than 24 hours old THEN the System SHALL fetch fresh recommendations from Spotify
5. WHEN cache data is corrupted or cannot be decoded THEN the System SHALL clear the cache and fetch fresh recommendations
6. WHEN the user logs out of Spotify THEN the System SHALL clear the recommendation cache

### Requirement 6: Authentication Handling

**User Story:** As a user, I want clear feedback when Spotify authentication is required, so that I understand why recommendations aren't showing.

#### Acceptance Criteria

1. WHEN fetching recommendations and the user is not authenticated THEN the System SHALL display the message "Spotify'a giriş yapman gerekiyor"
2. WHEN the user is not authenticated THEN the System SHALL provide a login button that triggers Spotify OAuth flow
3. WHEN calling Spotify API without valid access token THEN the SpotifyRecommendationService SHALL throw a notAuthenticated error
4. WHEN the user completes Spotify authentication THEN the System SHALL automatically fetch recommendations

### Requirement 7: Error Handling

**User Story:** As a user, I want the app to handle errors gracefully, so that I can continue using the app even when recommendations fail to load.

#### Acceptance Criteria

1. WHEN a network error occurs and valid cache exists THEN the System SHALL display cached recommendations with a subtle "Önbellekten" indicator
2. WHEN a network error occurs and no cache exists THEN the System SHALL display an error message with a retry button
3. WHEN Spotify API returns a rate limit error (429) THEN the System SHALL use cached recommendations if available
4. WHEN Spotify API returns a rate limit error and no cache exists THEN the System SHALL display "Çok fazla istek, lütfen biraz bekle"
5. WHEN Spotify API returns invalid seed parameters THEN the System SHALL fall back to generic recommendations without showing an error to the user
6. IF any error occurs during recommendation fetching THEN the System SHALL log the error for debugging purposes

### Requirement 8: UI Integration

**User Story:** As a user, I want recommendations to fit seamlessly into the app's design, so that the experience feels cohesive and calm.

#### Acceptance Criteria

1. WHEN displaying recommendations THEN the System SHALL show a "Senin için seçtik" header in GeistMono-Regular font
2. WHEN displaying recommendation cards THEN the System SHALL arrange them in a horizontal scrollable list
3. WHEN displaying a recommendation card THEN the System SHALL show album artwork, song name, and artist name
4. WHEN a user taps a recommendation card THEN the System SHALL trigger haptic feedback
5. WHEN a recommendation is selected THEN the System SHALL animate the transition to mood selection with staggered entrance
6. WHEN displaying loading state THEN the System SHALL show skeleton UI that matches the card design

### Requirement 9: Performance Optimization

**User Story:** As a user, I want recommendations to load quickly and smoothly, so that the app feels responsive.

#### Acceptance Criteria

1. WHEN loading recommendations from cache THEN the System SHALL complete in less than 100 milliseconds
2. WHEN fetching recommendations from Spotify API THEN the System SHALL complete in less than 2 seconds
3. WHEN analyzing taste profile with 100 entries THEN the TasteProfileAnalyzer SHALL complete in less than 200 milliseconds
4. WHEN rendering recommendation cards THEN the System SHALL maintain 60 FPS scroll performance
5. WHEN the app receives a memory warning THEN the System SHALL clear the recommendation cache

### Requirement 10: Data Validation

**User Story:** As a developer, I want all data to be validated, so that the system remains stable and predictable.

#### Acceptance Criteria

1. WHEN creating a TasteProfile THEN the System SHALL ensure topGenres contains 0-5 elements
2. WHEN creating a TasteProfile THEN the System SHALL ensure topArtists contains 0-5 elements
3. WHEN creating a TasteProfile THEN the System SHALL ensure averageMoodScore is in range [0.0, 1.0]
4. WHEN creating a TasteProfile THEN the System SHALL ensure totalEntries is at least 3
5. WHEN creating a SongRecommendation THEN the System SHALL ensure id, name, and artist are non-empty strings
6. WHEN creating a CachedRecommendations object THEN the System SHALL ensure recommendations array contains 1-10 elements
7. WHEN creating a CachedRecommendations object THEN the System SHALL ensure timestamp is not in the future

### Requirement 11: Manual Refresh

**User Story:** As a user, I want to manually refresh recommendations, so that I can see new suggestions when I want variety.

#### Acceptance Criteria

1. WHEN the user taps the refresh button THEN the System SHALL clear the cache
2. WHEN the user taps the refresh button THEN the System SHALL fetch fresh recommendations from Spotify
3. WHEN refreshing recommendations THEN the System SHALL display a loading state
4. WHEN refresh completes successfully THEN the System SHALL update the displayed recommendations
5. WHEN refresh fails THEN the System SHALL display an error message and keep existing recommendations visible
