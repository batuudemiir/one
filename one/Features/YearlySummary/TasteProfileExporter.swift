//
//  TasteProfileExporter.swift
//  one
//
//  Yıllık özet verisini JSON olarak dışa aktarır.
//

import Foundation

enum TasteProfileExporter {
    struct Payload: Codable {
        let year: Int
        let totalEntries: Int
        let daysLogged: Int
        let uniqueArtists: Int
        let uniqueSongs: Int
        let longestStreak: Int
        let dominantMood: String
        let monthlyEntryCounts: [Int]
        let topTracks: [TrackPayload]
        let topArtists: [ArtistPayload]
        let generatedAt: Date
        let appVersion: String
    }

    struct TrackPayload: Codable {
        let rank: Int
        let name: String
        let artist: String
        let days: Int
    }

    struct ArtistPayload: Codable {
        let name: String
        let days: Int
    }

    static func exportJSON(data: YearlySummaryData) -> URL? {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        let payload = Payload(
            year: data.year,
            totalEntries: data.totalEntries,
            daysLogged: data.daysLogged,
            uniqueArtists: data.uniqueArtists,
            uniqueSongs: data.uniqueSongs,
            longestStreak: data.longestStreak,
            dominantMood: data.dominantMood,
            monthlyEntryCounts: data.monthlyEntryCounts,
            topTracks: data.topTracks.map {
                TrackPayload(rank: $0.rank, name: $0.name, artist: $0.artist, days: $0.days)
            },
            topArtists: data.topArtists.map {
                ArtistPayload(name: $0.name, days: $0.days)
            },
            generatedAt: Date(),
            appVersion: version
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        guard let encoded = try? encoder.encode(payload) else { return nil }
        let filename = "one-taste-profile-\(data.year).json"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        do {
            try encoded.write(to: url, options: .atomic)
            ONELogger.success("Exported taste profile: \(filename)", category: .general)
            return url
        } catch {
            ONELogger.error("Failed to write taste profile: \(error)", category: .general)
            return nil
        }
    }
}
