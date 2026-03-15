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
        var seedGenres: [String] = []
        var seedArtists: [String] = []
        
        // Map user genres to Spotify-compatible genres
        let mappedGenres = profile.topGenres.compactMap { mapToSpotifyGenre($0) }
        seedGenres = Array(Set(mappedGenres).shuffled().prefix(3)) // Remove duplicates and shuffle
        
        // If no valid genres, use fallback genres
        if seedGenres.isEmpty {
            seedGenres = ["indie", "alternative", "pop"].shuffled()
        }
        
        // Randomize artist selection for variety
        let shuffledArtists = profile.topArtists.shuffled()
        let artistNames = Array(shuffledArtists.prefix(2))
        
        // Resolve artist names to IDs
        if !artistNames.isEmpty {
            do {
                seedArtists = try await resolveArtistIds(artistNames: artistNames, token: token)
            } catch {
                ONELogger.warning("Could not resolve artist IDs: \(error)", category: .discovery)
                // Continue with just genres
            }
        }
        
        // Ensure we have at least some seeds
        if seedGenres.isEmpty && seedArtists.isEmpty {
            seedGenres = ["indie", "alternative", "pop"]
        }
        
        // Step 2: Build URL with query parameters
        var components = URLComponents(string: "https://api.spotify.com/v1/recommendations")!
        var queryItems: [URLQueryItem] = []
        
        if !seedGenres.isEmpty {
            queryItems.append(URLQueryItem(
                name: "seed_genres",
                value: seedGenres.joined(separator: ",")
            ))
        }
        
        if !seedArtists.isEmpty {
            queryItems.append(URLQueryItem(
                name: "seed_artists",
                value: seedArtists.joined(separator: ",")
            ))
        }
        
        queryItems.append(URLQueryItem(name: "limit", value: String(limit * 2))) // Request more for variety
        
        // Add target parameters based on mood with slight randomization
        let moodVariation = Double.random(in: -0.1...0.1)
        if profile.averageMoodScore > 0.6 {
            // User prefers upbeat/light moods
            let valence = min(1.0, max(0.0, 0.7 + moodVariation))
            let energy = min(1.0, max(0.0, 0.6 + moodVariation))
            queryItems.append(URLQueryItem(name: "target_valence", value: String(format: "%.2f", valence)))
            queryItems.append(URLQueryItem(name: "target_energy", value: String(format: "%.2f", energy)))
        } else if profile.averageMoodScore < 0.4 {
            // User prefers darker/calmer moods
            let valence = min(1.0, max(0.0, 0.3 + moodVariation))
            let energy = min(1.0, max(0.0, 0.4 + moodVariation))
            queryItems.append(URLQueryItem(name: "target_valence", value: String(format: "%.2f", valence)))
            queryItems.append(URLQueryItem(name: "target_energy", value: String(format: "%.2f", energy)))
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
                    recommendationReason: generateReason(track, profile),
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
        
        // Check if artist matches
        if profile.topArtists.contains(where: { track.artistName.contains($0) }) {
            return "Sevdiğin sanatçılara benzer"
        }
        
        // Check if mood matches
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
