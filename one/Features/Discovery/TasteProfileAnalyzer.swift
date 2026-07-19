//
//  TasteProfileAnalyzer.swift
//  one
//
//  Analyzes user listening history to build taste profile
//  v2: Recency-weighted analysis + rediscovery song extraction
//

import Foundation
import CoreData

struct TasteProfileAnalyzer {
    
    // MARK: - Recency Weight Tiers
    
    /// Son 7 gün → 3× ağırlık, son 30 gün → 2×, 30+ gün → 1×
    /// Kullanıcının güncel zevki daha belirleyici olur.
    private func recencyWeight(for date: Date?) -> Double {
        guard let date = date else { return 1.0 }
        let daysAgo = Calendar.current.dateComponents([.day], from: date, to: Date()).day ?? 0
        if daysAgo <= 7 { return 3.0 }
        if daysAgo <= 30 { return 2.0 }
        return 1.0
    }

    // MARK: - Main Analysis Method
    
    func analyzeTasteProfile(context: NSManagedObjectContext) async -> TasteProfile? {
        return await context.perform {
            // Step 1: Fetch all DailySong entries (limit to last 100 for performance)
            let fetchRequest: NSFetchRequest<DailySong> = DailySong.fetchRequest()
            fetchRequest.sortDescriptors = [NSSortDescriptor(key: "date", ascending: false)]
            fetchRequest.fetchLimit = 100 // Optimize for large datasets
            
            guard let entries = try? context.fetch(fetchRequest) else {
                return nil
            }
            
            // Step 2: Check minimum threshold
            guard entries.count >= 3 else {
                return nil
            }
            
            // Step 3: Extract top genres (recency-weighted)
            let topGenres = self.extractTopGenres(from: entries, limit: 5)

            // Step 3b: Build frequency-weighted genre pool for smarter seed selection
            let weightedGenres = self.extractWeightedGenres(from: entries, maxRepeats: 3)

            // Step 4: Extract top artists (recency-weighted)
            let topArtists = self.extractTopArtists(from: entries, limit: 5)

            // Step 4b: Extract Spotify track IDs from saved entries (recency-biased)
            let topTrackIds = self.extractSpotifyTrackIds(from: entries, limit: 5)

            // Step 5: Calculate mood patterns
            let moodPatterns = self.extractMoodPatterns(from: entries)

            // Step 6: Calculate average mood score
            let averageMoodScore = self.calculateAverageMoodScore(from: entries)

            // Step 7: Extract rediscovery songs (14+ gün öncesi, max 2)
            let rediscoverySongs = self.extractRediscoverySongs(from: entries, limit: 2)

            // Step 7b: Extract top songs (name+artist pairs for direct seed resolution)
            let topSongs = self.extractTopSongs(from: entries, limit: 5)

            // Step 8: Build and return profile
            return TasteProfile(
                topGenres: topGenres,
                topArtists: topArtists,
                topTrackIds: topTrackIds,
                moodPatterns: moodPatterns,
                totalEntries: entries.count,
                averageMoodScore: averageMoodScore,
                createdAt: Date(),
                weightedGenres: weightedGenres,
                rediscoverySongs: rediscoverySongs,
                topSongs: topSongs
            )
        }
    }
    
    // MARK: - Genre Extraction (Recency-Weighted)

    func extractTopGenres(from entries: [DailySong], limit: Int) -> [String] {
        var genreWeight: [String: Double] = [:]

        for entry in entries {
            if let genre = entry.genre, !genre.isEmpty {
                let weight = recencyWeight(for: entry.date)
                genreWeight[genre, default: 0] += weight
            }
        }

        return genreWeight
            .sorted { $0.value > $1.value }
            .prefix(limit)
            .map { $0.key }
    }

    /// Returns a frequency-weighted genre pool where each genre appears proportional
    /// to how often the user has logged it, boosted by recency. More-played genres
    /// are repeated up to `maxRepeats` times; less-played genres appear at least once.
    func extractWeightedGenres(from entries: [DailySong], maxRepeats: Int = 3) -> [String] {
        var genreWeight: [String: Double] = [:]
        for entry in entries {
            if let genre = entry.genre, !genre.isEmpty {
                let weight = recencyWeight(for: entry.date)
                genreWeight[genre, default: 0] += weight
            }
        }
        guard !genreWeight.isEmpty else { return [] }

        let sorted = genreWeight.sorted { $0.value > $1.value }
        let maxWeight = sorted.first?.value ?? 1.0

        var weighted: [String] = []
        for (genre, weight) in sorted {
            // Scale: top genre gets maxRepeats slots, others scale proportionally (min 1)
            let slots = max(1, Int((weight / maxWeight * Double(maxRepeats)).rounded()))
            for _ in 0..<slots {
                weighted.append(genre)
            }
        }
        return weighted
    }
    
    // MARK: - Artist Extraction (Recency-Weighted)
    
    func extractTopArtists(from entries: [DailySong], limit: Int) -> [String] {
        var artistWeight: [String: Double] = [:]
        
        for entry in entries {
            if let artist = entry.artistName, !artist.isEmpty {
                let weight = recencyWeight(for: entry.date)
                artistWeight[artist, default: 0] += weight
            }
        }
        
        return artistWeight
            .sorted { $0.value > $1.value }
            .prefix(limit)
            .map { $0.key }
    }
    
    // MARK: - Mood Pattern Extraction
    
    func extractMoodPatterns(from entries: [DailySong]) -> [MoodPattern] {
        var moodFrequency: [String: Int] = [:]
        
        for entry in entries {
            if let raw = entry.moodLabel, !raw.isEmpty {
                let moodLabel = DailyEntry.moodLabelMigrationMap[raw] ?? raw
                moodFrequency[moodLabel, default: 0] += 1
            }
        }
        
        let totalCount = entries.count
        
        return moodFrequency.map { key, value in
            MoodPattern(
                moodKey: key,
                frequency: value,
                percentage: Double(value) / Double(totalCount)
            )
        }.sorted { $0.frequency > $1.frequency }
    }
    
    // MARK: - Spotify Track ID Extraction (Recency-Biased)

    /// Extracts Spotify track IDs from `spotifyURL` field.
    /// Recent entries (son 14 gün) are prioritized as seeds for better personalization.
    func extractSpotifyTrackIds(from entries: [DailySong], limit: Int) -> [String] {
        var recentIds: [String] = []
        var olderIds: [String] = []
        var seen = Set<String>()
        
        for entry in entries {
            guard let raw = entry.spotifyURL,
                  let url = URL(string: raw) else { continue }
            let parts = url.pathComponents
            guard let idx = parts.firstIndex(of: "track"), parts.count > idx + 1 else { continue }
            let tid = parts[idx + 1]
            guard seen.insert(tid).inserted else { continue }
            
            let daysAgo = Calendar.current.dateComponents([.day], from: entry.date ?? Date(), to: Date()).day ?? 0
            if daysAgo <= 14 {
                recentIds.append(tid)
            } else {
                olderIds.append(tid)
            }
        }
        
        // Recent entries first, fill remaining with older
        var result = Array(recentIds.prefix(limit))
        if result.count < limit {
            result.append(contentsOf: olderIds.prefix(limit - result.count))
        }
        return result
    }

    // MARK: - Rediscovery Song Extraction

    /// Kullanıcının en az 14 gün önce seçtiği şarkılardan rastgele birkaç tanesini
    /// `SongRecommendation` formatında döndürür. "Tekrar keşfet" nostalji özelliği.
    func extractRediscoverySongs(from entries: [DailySong], limit: Int) -> [RediscoverySong] {
        let threshold = Calendar.current.date(byAdding: .day, value: -14, to: Date()) ?? Date()
        
        // 14+ gün önceki unique şarkılar
        var seen = Set<String>()
        let eligible = entries.filter { entry in
            guard let date = entry.date, date < threshold,
                  let name = entry.songName, !name.isEmpty,
                  let artist = entry.artistName, !artist.isEmpty else { return false }
            let key = "\(name.lowercased())|\(artist.lowercased())"
            return seen.insert(key).inserted
        }
        
        // Rastgele seç
        let selected = Array(eligible.shuffled().prefix(limit))
        
        return selected.map { entry in
            RediscoverySong(
                songName: entry.songName ?? "",
                artistName: entry.artistName ?? "",
                genre: entry.genre,
                artworkURL: entry.artworkURL,
                spotifyURL: entry.spotifyURL,
                date: entry.date ?? Date()
            )
        }
    }

    // MARK: - Top Songs Extraction

    func extractTopSongs(from entries: [DailySong], limit: Int) -> [SavedSong] {
        var seen = Set<String>()
        return entries.compactMap { entry -> SavedSong? in
            guard let name = entry.songName, !name.isEmpty,
                  let artist = entry.artistName, !artist.isEmpty else { return nil }
            let key = "\(name.lowercased())|\(artist.lowercased())"
            guard seen.insert(key).inserted else { return nil }
            return SavedSong(name: name, artist: artist, genre: entry.genre)
        }.prefix(limit).map { $0 }
    }

    // MARK: - Mood Score Calculation
    
    func calculateAverageMoodScore(from entries: [DailySong]) -> Double {
        var totalMoodScore: Double = 0.0
        var moodCount = 0
        
        for entry in entries {
            if entry.moodIsDark {
                totalMoodScore += 0.0  // Dark mood = 0
            } else {
                totalMoodScore += 1.0  // Light mood = 1
            }
            moodCount += 1
        }
        
        guard moodCount > 0 else { return 0.5 }
        
        let average = totalMoodScore / Double(moodCount)
        
        // Ensure result is in valid range [0.0, 1.0]
        return max(0.0, min(1.0, average))
    }
}
