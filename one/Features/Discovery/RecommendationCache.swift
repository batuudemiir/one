//
//  RecommendationCache.swift
//  one
//
//  Caches song recommendations with 24-hour expiry
//

import Foundation

class RecommendationCache {
    
    private let cacheKey = "cached_recommendations"
    
    // MARK: - Save Recommendations
    
    func saveRecommendations(_ recommendations: [SongRecommendation], profile: TasteProfile? = nil) {
        let cached = CachedRecommendations(
            recommendations: recommendations,
            timestamp: Date(),
            profileSnapshot: profile,
            cachedTotalEntries: profile?.totalEntries
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
    
    func getCachedRecommendations(currentTotalEntries: Int? = nil) -> [SongRecommendation]? {
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

        guard cached.isValid(currentTotalEntries: currentTotalEntries) else {
            if let current = currentTotalEntries,
               let cachedCount = cached.cachedTotalEntries,
               current > cachedCount {
                ONELogger.info("Cache busted: profile has \(current) entries, cache had \(cachedCount)", category: .discovery)
            } else {
                ONELogger.info("Cache expired (not from today), clearing", category: .discovery)
            }
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
        
        return cached.isValid()
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
