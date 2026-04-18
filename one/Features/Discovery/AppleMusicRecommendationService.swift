//
//  AppleMusicRecommendationService.swift
//  one
//
//  Apple Music recommendation service using MusicKit
//

import Foundation
import MusicKit

class AppleMusicRecommendationService {
    
    // MARK: - Get Personalized Recommendations
    
    func getRecommendations(profile: TasteProfile, limit: Int = 8) async throws -> [SongRecommendation] {
        // Check authorization
        let status = await MusicAuthorization.request()
        guard status == .authorized else {
            throw RecommendationError.notAuthenticated
        }
        
        // Build recommendation request based on taste profile
        var recommendations: [SongRecommendation] = []

        // Use weighted genre pool: dominant genres appear more often in the pool.
        // Shuffle and take a prefix to naturally bias toward the user's style mix.
        let weightedPool = profile.weightedGenres
        var seenGenres = Set<String>()
        let shuffledGenres: [String] = weightedPool.shuffled().filter { seenGenres.insert($0).inserted }
        let shuffledArtists = profile.topArtists.shuffled()

        // Strategy 1: Search by top artists — fetches other songs by the same artists the user chose
        if !shuffledArtists.isEmpty {
            let artistRecommendations = try await searchByArtists(
                artists: Array(shuffledArtists.prefix(3)),
                limit: limit
            )
            recommendations.append(contentsOf: artistRecommendations)
        }

        // Strategy 2: Search by weighted genres for breadth (use up to 3 for variety)
        if !shuffledGenres.isEmpty && recommendations.count < limit * 2 {
            let genreRecommendations = try await searchByGenres(
                genres: Array(shuffledGenres.prefix(3)),
                limit: limit
            )
            recommendations.append(contentsOf: genreRecommendations)
        }

        // If still not enough, get generic recommendations
        if recommendations.count < limit * 2 {
            let genericRecs = try await getGenericRecommendations(limit: limit)
            recommendations.append(contentsOf: genericRecs)
        }
        
        // Shuffle and return subset for variety
        return Array(recommendations.shuffled().prefix(limit))
    }
    
    // MARK: - Get Generic Recommendations
    
    func getGenericRecommendations(limit: Int = 8) async throws -> [SongRecommendation] {
        let status = await MusicAuthorization.request()
        guard status == .authorized else {
            throw RecommendationError.notAuthenticated
        }
        
        // Search for popular songs with randomized genres
        let allGenres = ["indie", "alternative", "pop", "rock", "electronic", "chill"]
        let genres = Array(allGenres.shuffled().prefix(3))
        var recommendations: [SongRecommendation] = []
        
        for genre in genres {
            if recommendations.count >= limit * 2 { break }
            
            let genreRecs = try await searchByGenres(
                genres: [genre],
                limit: limit
            )
            recommendations.append(contentsOf: genreRecs)
        }
        
        // Shuffle and return subset
        return Array(recommendations.shuffled().prefix(limit))
    }
    
    // MARK: - Helper: Search by Genres
    
    private func searchByGenres(genres: [String], limit: Int) async throws -> [SongRecommendation] {
        var allSongs: [SongRecommendation] = []
        
        for genre in genres {
            do {
                var searchRequest = MusicCatalogSearchRequest(term: genre, types: [MusicKit.Song.self])
                searchRequest.limit = limit
                
                let searchResponse = try await searchRequest.response()
                
                let songs = searchResponse.songs.map { song in
                    SongRecommendation(
                        id: song.id.rawValue,
                        name: song.title,
                        artist: song.artistName,
                        coverURL: song.artwork?.url(width: 300, height: 300),
                        spotifyURL: "https://music.apple.com/song/\(song.id.rawValue)",
                        genre: genre,
                        recommendationReason: "Senin için seçtik",
                        source: .appleMusic
                    )
                }
                
                allSongs.append(contentsOf: songs)
            } catch {
                ONELogger.warning("Failed to search genre \(genre): \(error)", category: .discovery)
                continue
            }
        }
        
        return Array(allSongs.prefix(limit))
    }
    
    // MARK: - Helper: Search by Artists
    
    private func searchByArtists(artists: [String], limit: Int) async throws -> [SongRecommendation] {
        var allSongs: [SongRecommendation] = []
        
        for artistName in artists {
            do {
                var searchRequest = MusicCatalogSearchRequest(term: artistName, types: [MusicKit.Song.self])
                searchRequest.limit = max(6, limit) // each artist contributes a full pool; we shuffle+deduplicate below
                
                let searchResponse = try await searchRequest.response()
                
                let songs = searchResponse.songs.map { song in
                    SongRecommendation(
                        id: song.id.rawValue,
                        name: song.title,
                        artist: song.artistName,
                        coverURL: song.artwork?.url(width: 300, height: 300),
                        spotifyURL: "https://music.apple.com/song/\(song.id.rawValue)",
                        genre: nil,
                        recommendationReason: "Sevdiğin sanatçılara benzer",
                        source: .appleMusic
                    )
                }
                
                allSongs.append(contentsOf: songs)
            } catch {
                ONELogger.warning("Failed to search artist \(artistName): \(error)", category: .discovery)
                continue
            }
        }
        
        return Array(allSongs.prefix(limit))
    }
}
