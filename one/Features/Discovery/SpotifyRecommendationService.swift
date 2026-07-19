//
//  SpotifyRecommendationService.swift
//  one
//
//  Interfaces with Spotify API to fetch personalized recommendations
//

import Foundation

class SpotifyRecommendationService {
    
    // MARK: - Get Personalized Recommendations
    
    func getRecommendations(profile: TasteProfile, limit: Int = 8) async throws -> [SongRecommendation] {
        guard let token = SpotifyManager.shared.accessToken else {
            throw RecommendationError.notAuthenticated
        }
        
        // Step 1: Prepare seed parameters (Spotify allows max 5 seeds total)
        // Priority: seed_tracks (URL-based or derived via artist top-tracks) > seed_genres > seed_artists
        let urlTrackIds: [String] = Array(profile.topTrackIds.shuffled().prefix(3))
        var derivedTrackIds: [String] = []   // resolved via artist top-tracks when urlTrackIds is empty
        var seedGenres: [String] = []
        var seedArtists: [String] = []

        // Map user genres to Spotify-compatible genres using the weighted pool.
        let weightedMapped = profile.weightedGenres.compactMap { mapToSpotifyGenre($0) }
        let uniqueShuffled: [String] = {
            var seen = Set<String>()
            var result: [String] = []
            for g in weightedMapped.shuffled() {
                if seen.insert(g).inserted { result.append(g) }
                else if result.filter({ $0 == g }).count < 2 { result.append(g) }
            }
            return result
        }()

        if urlTrackIds.isEmpty {
            // No URL-based seeds — resolve artist IDs, then fetch each artist's top track.
            // This gives real seed_tracks even when the user only searched songs by name.
            let artistNames = Array(profile.topArtists.shuffled().prefix(2))
            var resolvedArtistIds: [String] = []
            if !artistNames.isEmpty {
                do {
                    resolvedArtistIds = try await resolveArtistIds(artistNames: artistNames, token: token)
                } catch {
                    ONELogger.warning("Could not resolve artist IDs: \(error)", category: .discovery)
                }
            }

            for artistId in resolvedArtistIds.prefix(2) {
                if let tid = await getTopTrackIdForArtist(artistId: artistId, token: token) {
                    derivedTrackIds.append(tid)
                }
            }

            // Resolve track IDs from user's saved song names
            if derivedTrackIds.isEmpty && !profile.topSongs.isEmpty {
                for song in profile.topSongs.prefix(3) {
                    if let tid = await resolveTrackId(songName: song.name, artistName: song.artist, token: token) {
                        derivedTrackIds.append(tid)
                    }
                    if derivedTrackIds.count >= 3 { break }
                }
            }

            if derivedTrackIds.isEmpty {
                // True fallback: genre + artist seeds (original behaviour)
                seedGenres = Array(uniqueShuffled.prefix(3))
                if seedGenres.isEmpty { seedGenres = ["indie", "alternative", "pop"].shuffled() }
                if seedGenres.count < 2 && uniqueShuffled.count >= 2 {
                    seedGenres = Array(uniqueShuffled.prefix(2))
                }
                seedArtists = resolvedArtistIds
                if seedGenres.isEmpty && seedArtists.isEmpty {
                    seedGenres = ["indie", "alternative", "pop"]
                }
            }
        } else {
            // Have URL-based track seeds: fill remaining slots with genres
            let remainingSlots = max(0, 5 - urlTrackIds.count)
            seedGenres = Array(uniqueShuffled.prefix(remainingSlots))
            if seedGenres.isEmpty && remainingSlots > 0 {
                seedGenres = Array(["indie", "alternative", "pop"].prefix(remainingSlots))
            }
        }

        // Effective track seeds: prefer URL-based, fall back to derived
        let effectiveTrackIds = urlTrackIds.isEmpty ? derivedTrackIds : urlTrackIds

        // Step 2: Build URL with query parameters
        var components = URLComponents(string: "https://api.spotify.com/v1/recommendations")!
        var queryItems: [URLQueryItem] = []

        if !effectiveTrackIds.isEmpty {
            queryItems.append(URLQueryItem(name: "seed_tracks", value: effectiveTrackIds.joined(separator: ",")))
            // When using derived tracks, fill remaining 5-seed slots with genres
            if urlTrackIds.isEmpty {
                let genreSlots = max(0, 5 - effectiveTrackIds.count)
                let fillGenres = Array(uniqueShuffled.prefix(genreSlots))
                if !fillGenres.isEmpty {
                    queryItems.append(URLQueryItem(name: "seed_genres", value: fillGenres.joined(separator: ",")))
                }
            }
        }

        if !seedGenres.isEmpty {
            queryItems.append(URLQueryItem(name: "seed_genres", value: seedGenres.joined(separator: ",")))
        }

        if !seedArtists.isEmpty {
            queryItems.append(URLQueryItem(name: "seed_artists", value: seedArtists.joined(separator: ",")))
        }
        
        queryItems.append(URLQueryItem(name: "limit", value: String(limit * 2))) // Request more for variety
        
        // Add target valence/energy computed from Turkish mood label distribution (A2 fix)
        if let features = computeTargetAudioFeatures(from: profile.moodPatterns) {
            let jitter = Double.random(in: -0.08...0.08)
            let v = min(1.0, max(0.0, features.valence + jitter))
            let e = min(1.0, max(0.0, features.energy  + jitter))
            queryItems.append(URLQueryItem(name: "target_valence", value: String(format: "%.2f", v)))
            queryItems.append(URLQueryItem(name: "target_energy",  value: String(format: "%.2f", e)))
        }
        
        components.queryItems = queryItems
        
        // Step 3: Make API request
        guard let url = components.url else {
            throw RecommendationError.spotifyAPIError("Invalid URL")
        }
        
        ONELogger.debug("Spotify Recommendations URL: \(url.absoluteString)", category: .discovery)
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw RecommendationError.networkError
            }
            
            if httpResponse.statusCode != 200 {
                // Log error response for debugging
                if let errorString = String(data: data, encoding: .utf8) {
                    ONELogger.error("Spotify API Error Response: \(errorString)", category: .discovery)
                }
            }
            
            guard httpResponse.statusCode == 200 else {
                if httpResponse.statusCode == 401 {
                    throw RecommendationError.notAuthenticated
                } else if httpResponse.statusCode == 429 {
                    throw RecommendationError.spotifyAPIError("Rate limit exceeded")
                } else {
                    throw RecommendationError.spotifyAPIError("Status \(httpResponse.statusCode)")
                }
            }
            
            // Step 4: Parse response
            let decoder = JSONDecoder()
            let recommendationResponse = try decoder.decode(SpotifyRecommendationResponse.self, from: data)
            
            // Transform to SongRecommendation and shuffle for variety
            let allRecommendations = recommendationResponse.tracks.map { track in
                SongRecommendation(
                    id: track.id,
                    name: track.name,
                    artist: track.artistName,
                    coverURL: track.album.artworkURL,
                    spotifyURL: nil,
                    genre: nil,
                    recommendationReason: nil,
                    source: .spotify
                )
            }

            // Return shuffled subset
            return Array(allRecommendations.shuffled().prefix(limit))
            
        } catch let error as RecommendationError {
            throw error
        } catch {
            throw RecommendationError.networkError
        }
    }
    
    // MARK: - Map to Spotify Genre
    
    private func mapToSpotifyGenre(_ userGenre: String) -> String? {
        let normalized = userGenre.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Spotify valid genres (common ones)
        let validGenres = [
            "acoustic", "afrobeat", "alt-rock", "alternative", "ambient", "anime",
            "black-metal", "bluegrass", "blues", "bossanova", "brazil", "breakbeat",
            "british", "cantopop", "chicago-house", "children", "chill", "classical",
            "club", "comedy", "country", "dance", "dancehall", "death-metal", "deep-house",
            "detroit-techno", "disco", "disney", "drum-and-bass", "dub", "dubstep",
            "edm", "electro", "electronic", "emo", "folk", "forro", "french", "funk",
            "garage", "german", "gospel", "goth", "grindcore", "groove", "grunge",
            "guitar", "happy", "hard-rock", "hardcore", "hardstyle", "heavy-metal",
            "hip-hop", "holidays", "honky-tonk", "house", "idm", "indian", "indie",
            "indie-pop", "industrial", "iranian", "j-dance", "j-idol", "j-pop", "j-rock",
            "jazz", "k-pop", "kids", "latin", "latino", "malay", "mandopop", "metal",
            "metal-misc", "metalcore", "minimal-techno", "movies", "mpb", "new-age",
            "new-release", "opera", "pagode", "party", "philippines-opm", "piano",
            "pop", "pop-film", "post-dubstep", "power-pop", "progressive-house",
            "psych-rock", "punk", "punk-rock", "r-n-b", "rainy-day", "reggae",
            "reggaeton", "road-trip", "rock", "rock-n-roll", "rockabilly", "romance",
            "sad", "salsa", "samba", "sertanejo", "show-tunes", "singer-songwriter",
            "ska", "sleep", "songwriter", "soul", "soundtracks", "spanish", "study",
            "summer", "swedish", "synth-pop", "tango", "techno", "trance", "trip-hop",
            "turkish", "work-out", "world-music"
        ]
        
        // Direct match
        if validGenres.contains(normalized) {
            return normalized
        }
        
        // Fuzzy matching
        if normalized.contains("rock") { return "rock" }
        if normalized.contains("pop") { return "pop" }
        if normalized.contains("indie") { return "indie" }
        if normalized.contains("electronic") || normalized.contains("elektro") { return "electronic" }
        if normalized.contains("hip") || normalized.contains("rap") { return "hip-hop" }
        if normalized.contains("jazz") { return "jazz" }
        if normalized.contains("classical") || normalized.contains("klasik") { return "classical" }
        if normalized.contains("metal") { return "metal" }
        if normalized.contains("folk") { return "folk" }
        if normalized.contains("blues") { return "blues" }
        if normalized.contains("country") { return "country" }
        if normalized.contains("soul") { return "soul" }
        if normalized.contains("funk") { return "funk" }
        if normalized.contains("reggae") { return "reggae" }
        if normalized.contains("latin") { return "latin" }
        if normalized.contains("ambient") || normalized.contains("chill") { return "ambient" }
        if normalized.contains("alternative") || normalized.contains("alternatif") { return "alternative" }
        
        // No match found
        return nil
    }
    
    // MARK: - Get Generic Recommendations
    
    func getGenericRecommendations(limit: Int = 8) async throws -> [SongRecommendation] {
        guard let token = SpotifyManager.shared.accessToken else {
            throw RecommendationError.notAuthenticated
        }
        
        // Use randomized seed genres for variety
        let allGenres = ["indie", "alternative", "pop", "rock", "electronic", "chill"]
        let seedGenres = Array(allGenres.shuffled().prefix(3))
        
        var components = URLComponents(string: "https://api.spotify.com/v1/recommendations")!
        var queryItems: [URLQueryItem] = []
        
        queryItems.append(URLQueryItem(
            name: "seed_genres",
            value: seedGenres.joined(separator: ",")
        ))
        queryItems.append(URLQueryItem(name: "limit", value: String(limit * 2))) // Request more for variety
        
        // Neutral mood parameters with slight randomization
        let valenceVariation = Double.random(in: -0.15...0.15)
        let energyVariation = Double.random(in: -0.15...0.15)
        let valence = min(1.0, max(0.0, 0.5 + valenceVariation))
        let energy = min(1.0, max(0.0, 0.5 + energyVariation))
        
        queryItems.append(URLQueryItem(name: "target_valence", value: String(format: "%.2f", valence)))
        queryItems.append(URLQueryItem(name: "target_energy", value: String(format: "%.2f", energy)))
        
        components.queryItems = queryItems
        
        guard let url = components.url else {
            throw RecommendationError.spotifyAPIError("Invalid URL")
        }
        
        ONELogger.debug("Spotify Generic Recommendations URL: \(url.absoluteString)", category: .discovery)
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw RecommendationError.networkError
            }
            
            // Log error response for debugging
            if httpResponse.statusCode != 200 {
                if let errorString = String(data: data, encoding: .utf8) {
                    ONELogger.error("Spotify API Error Response: \(errorString)", category: .discovery)
                }
            }
            
            guard httpResponse.statusCode == 200 else {
                if httpResponse.statusCode == 401 {
                    throw RecommendationError.notAuthenticated
                } else if httpResponse.statusCode == 429 {
                    throw RecommendationError.spotifyAPIError("Rate limit exceeded")
                } else {
                    throw RecommendationError.spotifyAPIError("Status \(httpResponse.statusCode)")
                }
            }
            
            let decoder = JSONDecoder()
            let recommendationResponse = try decoder.decode(SpotifyRecommendationResponse.self, from: data)
            
            let allRecommendations = recommendationResponse.tracks.map { track in
                SongRecommendation(
                    id: track.id,
                    name: track.name,
                    artist: track.artistName,
                    coverURL: track.album.artworkURL,
                    spotifyURL: nil,
                    genre: nil,
                    recommendationReason: nil,
                    source: .spotify
                )
            }

            // Return shuffled subset
            return Array(allRecommendations.shuffled().prefix(limit))
            
        } catch let error as RecommendationError {
            throw error
        } catch {
            throw RecommendationError.networkError
        }
    }
    
    // MARK: - Helper: Resolve Track ID by Song Name

    private func resolveTrackId(songName: String, artistName: String, token: String) async -> String? {
        let query = "\(songName) \(artistName)"
            .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let urlStr = "https://api.spotify.com/v1/search?q=\(query)&type=track&limit=1"
        guard let url = URL(string: urlStr) else { return nil }
        var req = URLRequest(url: url)
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        guard let (data, resp) = try? await URLSession.shared.data(for: req),
              (resp as? HTTPURLResponse)?.statusCode == 200,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let tracks = (json["tracks"] as? [String: Any])?["items"] as? [[String: Any]],
              let firstId = tracks.first?["id"] as? String
        else { return nil }
        return firstId
    }

    // MARK: - Helper: Get Top Track for Artist

    /// Fetches the #1 track from an artist's top-tracks (market=TR).
    /// Used to build real seed_tracks even when no spotifyURL is stored.
    private func getTopTrackIdForArtist(artistId: String, token: String) async -> String? {
        guard let url = URL(string: "https://api.spotify.com/v1/artists/\(artistId)/top-tracks?market=TR") else { return nil }
        var req = URLRequest(url: url)
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        guard let (data, resp) = try? await URLSession.shared.data(for: req),
              (resp as? HTTPURLResponse)?.statusCode == 200,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let tracks = json["tracks"] as? [[String: Any]],
              let firstId = tracks.first?["id"] as? String else { return nil }
        return firstId
    }

    // MARK: - Helper: Mood Label → Spotify Audio Features (A2)

    /// Maps Turkish mood labels to (valence, energy) targets.
    private static let moodAudioFeatures: [String: (valence: Double, energy: Double)] = [
        "Ateşli":    (0.70, 0.88),
        "Coşkulu":   (0.80, 0.75),
        "Mutlu":     (0.85, 0.65),
        "Doğal":     (0.60, 0.50),
        "Huzurlu":   (0.65, 0.35),
        "Özgür":     (0.70, 0.55),
        "Derin":     (0.35, 0.40),
        "Nostaljik": (0.45, 0.45),
        "Gizemli":   (0.30, 0.50),
        "Hassas":    (0.40, 0.30),
        "Sessiz":    (0.30, 0.20),
        "Nötr":      (0.50, 0.50),
    ]

    /// Weighted average of valence/energy across all mood patterns that have a mapping.
    /// Returns nil when no known mood labels are present (caller skips target parameters).
    private func computeTargetAudioFeatures(from moodPatterns: [MoodPattern]) -> (valence: Double, energy: Double)? {
        var totalWeight = 0.0
        var wValence = 0.0
        var wEnergy  = 0.0
        for pattern in moodPatterns {
            guard let f = Self.moodAudioFeatures[pattern.moodKey] else { continue }
            let w = pattern.percentage
            wValence    += f.valence * w
            wEnergy     += f.energy  * w
            totalWeight += w
        }
        guard totalWeight > 0 else { return nil }
        return (wValence / totalWeight, wEnergy / totalWeight)
    }

    // MARK: - Helper: Resolve Artist IDs

    private func resolveArtistIds(artistNames: [String], token: String) async throws -> [String] {
        var artistIds: [String] = []
        
        for artistName in artistNames {
            let encodedName = artistName.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
            let urlString = "https://api.spotify.com/v1/search?q=\(encodedName)&type=artist&limit=1"
            
            guard let url = URL(string: urlString) else { continue }
            
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            
            do {
                let (data, response) = try await URLSession.shared.data(for: request)
                
                guard let httpResponse = response as? HTTPURLResponse,
                      httpResponse.statusCode == 200 else {
                    continue
                }
                
                let decoder = JSONDecoder()
                let searchResponse = try decoder.decode(SpotifyArtistSearchResponse.self, from: data)
                
                if let firstArtist = searchResponse.artists.items.first {
                    artistIds.append(firstArtist.id)
                }
            } catch {
                // Skip artists that can't be resolved
                continue
            }
        }
        
        return artistIds
    }
    
    // MARK: - Helper: Generate Recommendation Reason
    
    private func generateReason(_ track: SpotifyTrack, _ profile: TasteProfile?) -> String? {
        guard let profile = profile else { return nil }

        // Artist or track seeds used → most personalised signal
        if !profile.topArtists.isEmpty {
            if profile.topArtists.contains(where: { track.artistName.localizedCaseInsensitiveContains($0) }) {
                return "Sevdiğin sanatçılara benzer"
            }
        }
        if !profile.topTrackIds.isEmpty {
            return "Seçtiğin şarkılara göre"
        }

        // Fallback: artist or mood match
        if profile.topArtists.contains(where: { track.artistName.localizedCaseInsensitiveContains($0) }) {
            return "Sevdiğin sanatçılara benzer"
        }
        if profile.averageMoodScore > 0.6 {
            return "Ruh haline uygun"
        } else if profile.averageMoodScore < 0.4 {
            return "Sakin anların için"
        }
        return "Senin için seçtik"
    }
}

// MARK: - Response Models

struct SpotifyRecommendationResponse: Codable {
    let tracks: [SpotifyTrack]
}

struct SpotifyArtistSearchResponse: Codable {
    let artists: SpotifyArtistResults
}

struct SpotifyArtistResults: Codable {
    let items: [SpotifyArtistItem]
}

struct SpotifyArtistItem: Codable {
    let id: String
    let name: String
}
