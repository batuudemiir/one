//
//  RecommendationModels.swift
//  one
//
//  Data models for song recommendation system
//

import Foundation

// MARK: - Recommendation Source

enum RecommendationSource: String, Codable {
    case spotify
    case appleMusic
}

// MARK: - Song Recommendation

struct SongRecommendation: Identifiable, Codable, Hashable {
    let id: String
    let name: String
    let artist: String
    let coverURL: URL?
    let spotifyURL: String?
    let genre: String?
    let recommendationReason: String?
    let source: RecommendationSource
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: SongRecommendation, rhs: SongRecommendation) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Taste Profile

struct TasteProfile: Codable {
    let topGenres: [String]
    let topArtists: [String]
    let moodPatterns: [MoodPattern]
    let totalEntries: Int
    let averageMoodScore: Double
    let createdAt: Date
}

// MARK: - Mood Pattern

struct MoodPattern: Codable {
    let moodKey: String
    let frequency: Int
    let percentage: Double
}

// MARK: - Cached Recommendations

struct CachedRecommendations: Codable {
    let recommendations: [SongRecommendation]
    let timestamp: Date
    let profileSnapshot: TasteProfile?
    
    func isValid(maxAge: TimeInterval) -> Bool {
        let age = Date().timeIntervalSince(timestamp)
        return age < maxAge
    }
}

// MARK: - Recommendation Error

enum RecommendationError: Error, LocalizedError {
    case notAuthenticated
    case insufficientHistory
    case networkError
    case spotifyAPIError(String)
    case cacheError
    
    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "Müzik servisi ile giriş yapılmadı"
        case .insufficientHistory:
            return "Yeterli dinleme geçmişi yok"
        case .networkError:
            return "İnternet bağlantısı hatası"
        case .spotifyAPIError(let message):
            return "Spotify API hatası: \(message)"
        case .cacheError:
            return "Önbellek hatası"
        }
    }
}
