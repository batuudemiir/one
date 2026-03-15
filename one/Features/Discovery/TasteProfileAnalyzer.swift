//
//  TasteProfileAnalyzer.swift
//  one
//
//  Analyzes user listening history to build taste profile
//

import Foundation
import CoreData

struct TasteProfileAnalyzer {
    
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
            
            // Step 3: Extract top genres
            let topGenres = self.extractTopGenres(from: entries, limit: 5)
            
            // Step 4: Extract top artists
            let topArtists = self.extractTopArtists(from: entries, limit: 5)
            
            // Step 5: Calculate mood patterns
            let moodPatterns = self.extractMoodPatterns(from: entries)
            
            // Step 6: Calculate average mood score
            let averageMoodScore = self.calculateAverageMoodScore(from: entries)
            
            // Step 7: Build and return profile
            return TasteProfile(
                topGenres: topGenres,
                topArtists: topArtists,
                moodPatterns: moodPatterns,
                totalEntries: entries.count,
                averageMoodScore: averageMoodScore,
                createdAt: Date()
            )
        }
    }
    
    // MARK: - Genre Extraction
    
    func extractTopGenres(from entries: [DailySong], limit: Int) -> [String] {
        var genreFrequency: [String: Int] = [:]
        
        for entry in entries {
            if let genre = entry.genre, !genre.isEmpty {
                genreFrequency[genre, default: 0] += 1
            }
        }
        
        return genreFrequency
            .sorted { $0.value > $1.value }
            .prefix(limit)
            .map { $0.key }
    }
    
    // MARK: - Artist Extraction
    
    func extractTopArtists(from entries: [DailySong], limit: Int) -> [String] {
        var artistFrequency: [String: Int] = [:]
        
        for entry in entries {
            if let artist = entry.artistName, !artist.isEmpty {
                artistFrequency[artist, default: 0] += 1
            }
        }
        
        return artistFrequency
            .sorted { $0.value > $1.value }
            .prefix(limit)
            .map { $0.key }
    }
    
    // MARK: - Mood Pattern Extraction
    
    func extractMoodPatterns(from entries: [DailySong]) -> [MoodPattern] {
        var moodFrequency: [String: Int] = [:]
        
        for entry in entries {
            if let moodLabel = entry.moodLabel, !moodLabel.isEmpty {
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
