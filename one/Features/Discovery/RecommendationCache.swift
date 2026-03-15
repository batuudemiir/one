//
//  RecommendationCache.swift
//  one
//
//  Caches song recommendations with 24-hour expiry
//

import Foundation

class RecommendationCache {
    
    private let cacheKey = "cached_recommendations"
    private let maxAge: TimeInterval = 3600 // 1 hour (reduced for more frequent refreshes)
    
    // MARK: - Save Recommendations
    
    func saveRecommendations(_ recommendations: [SongRecommendation], profile: TasteProfile? = nil) {
        let cached = CachedRecommendations(
            recommendations: recommendations,
            timestamp: Date(),
            profileSnapshot: profile
        )
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        
        guard let data = try? encoder.encode(cached) else {
            ONELogger.error("Failed to encode recommendations for cache", category: .discovery)
            return
        }
        
        UserDefaults.standard.set(data, forKey: cacheKey)
        ONELogger.success("Cached \(recommendations.count) recommendations", category: .discovery)
    }
    
    // MARK: - Get Cached Recommendations
    
    func getCachedRecommendations() -> [SongRecommendation]? {
        guard let data = UserDefaults.standard.data(forKey: cacheKey) else {
            return nil
        }
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        guard let cached = try? decoder.decode(CachedRecommendations.self, from: data) else {
            ONELogger.warning("Failed to decode cached recommendations, clearing cache", category: .discovery)
            clearCache()
            return nil
        }
        
        guard cached.isValid(maxAge: maxAge) else {
            ONELogger.info("Cache expired, clearing", category: .discovery)
            clearCache()
            return nil
        }
        
        ONELogger.success("Loaded \(cached.recommendations.count) recommendations from cache", category: .discovery)
        return cached.recommendations
    }
    
    // MARK: - Cache Validity Check
    
    func isCacheValid() -> Bool {
        guard let data = UserDefaults.standard.data(forKey: cacheKey) else {
            return false
        }
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        guard let cached = try? decoder.decode(CachedRecommendations.self, from: data) else {
            return false
        }
        
        return cached.isValid(maxAge: maxAge)
    }
    
    // MARK: - Clear Cache
    
    func clearCache() {
        UserDefaults.standard.removeObject(forKey: cacheKey)
        ONELogger.debug("Recommendation cache cleared", category: .discovery)
    }
    
    // MARK: - Get Cache Age
    
    func getCacheAge() -> TimeInterval {
        guard let data = UserDefaults.standard.data(forKey: cacheKey) else {
            return TimeInterval.infinity
        }
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        guard let cached = try? decoder.decode(CachedRecommendations.self, from: data) else {
            return TimeInterval.infinity
        }
        
        return Date().timeIntervalSince(cached.timestamp)
    }
}
