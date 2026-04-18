//
//  YearlySummaryViewModel.swift
//  one
//
//  12 ayın özeti — taste profile için yıllık istatistikler.
//

import SwiftUI
import Combine
import CoreData

struct YearlySummaryData {
    let year: Int
    let totalEntries: Int
    let daysLogged: Int
    let uniqueArtists: Int
    let uniqueSongs: Int
    let longestStreak: Int
    let dominantMood: String
    let dominantMoodColor: Color
    /// 12 elements, dominant mood color per month (nil → gray).
    let monthlyMoodColors: [Color]
    /// Per-month entry counts (12 elements).
    let monthlyEntryCounts: [Int]
    let topTracks: [TrackEntry]
    let topArtists: [(name: String, days: Int)]
}

@MainActor
final class YearlySummaryViewModel: ObservableObject {
    @Published var data: YearlySummaryData?
    @Published var isLoading = true

    private let context: NSManagedObjectContext
    private let year: Int

    init(context: NSManagedObjectContext, year: Int) {
        self.context = context
        self.year = year
    }

    func load() {
        let songs = fetchYearSongs()
        data = Self.build(year: year, songs: songs)
        isLoading = false
    }

    private func fetchYearSongs() -> [DailySong] {
        var comps = DateComponents()
        comps.year = year; comps.month = 1; comps.day = 1
        let cal = Calendar.current
        guard let start = cal.date(from: comps),
              let end   = cal.date(byAdding: .year, value: 1, to: start) else { return [] }
        let req: NSFetchRequest<DailySong> = DailySong.fetchRequest()
        req.predicate = NSPredicate(format: "date >= %@ AND date < %@",
                                    start as NSDate, end as NSDate)
        req.sortDescriptors = [NSSortDescriptor(key: "date", ascending: true)]
        return (try? context.fetch(req)) ?? []
    }

    private static func build(year: Int, songs: [DailySong]) -> YearlySummaryData {
        let cal = Calendar.current

        // Unique logged days
        let dayKeys: Set<String> = Set(songs.compactMap { s -> String? in
            guard let d = s.date else { return nil }
            let c = cal.dateComponents([.year, .month, .day], from: d)
            return "\(c.year ?? 0)-\(c.month ?? 0)-\(c.day ?? 0)"
        })
        let daysLogged = dayKeys.count

        // Longest streak across the year
        let sortedDays: [Date] = Array(Set(songs.compactMap { s -> Date? in
            guard let d = s.date else { return nil }
            return cal.startOfDay(for: d)
        })).sorted()
        var longest = 0, current = 0
        var prev: Date?
        for d in sortedDays {
            if let p = prev, let next = cal.date(byAdding: .day, value: 1, to: p), cal.isDate(next, inSameDayAs: d) {
                current += 1
            } else {
                current = 1
            }
            longest = max(longest, current)
            prev = d
        }

        // Dominant mood
        var moodCount: [String: (count: Int, hex: String)] = [:]
        for s in songs {
            guard let w = s.moodWord else { continue }
            let hex = s.moodColorHex ?? "#6B6965"
            var e = moodCount[w] ?? (0, hex); e.count += 1
            moodCount[w] = e
        }
        let dom = moodCount.max { $0.value.count < $1.value.count }
        let dominantMood = dom?.key ?? "—"
        let dominantColor = Color(hex: dom?.value.hex ?? "#C97840")

        // Monthly breakdown — 12 colors + 12 counts
        var monthlyCounts = Array(repeating: 0, count: 12)
        var monthlyMoodTally: [Int: [String: (Int, String)]] = [:]
        for s in songs {
            guard let d = s.date else { continue }
            let m = cal.component(.month, from: d) - 1
            guard (0..<12).contains(m) else { continue }
            monthlyCounts[m] += 1
            if let w = s.moodWord {
                let hex = s.moodColorHex ?? "#6B6965"
                var tally = monthlyMoodTally[m] ?? [:]
                var e = tally[w] ?? (0, hex); e.0 += 1
                tally[w] = e
                monthlyMoodTally[m] = tally
            }
        }
        let monthlyColors: [Color] = (0..<12).map { m in
            guard let best = monthlyMoodTally[m]?.max(by: { $0.value.0 < $1.value.0 }) else {
                return Color.gray.opacity(0.15)
            }
            return Color(hex: best.value.1)
        }

        // Top tracks
        var songCount: [String: Int] = [:]
        var songEmoji: [String: String] = [:]
        for s in songs {
            guard let n = s.songName, let a = s.artistName else { continue }
            let k = "\(n)|\(a)"
            songCount[k, default: 0] += 1
            if songEmoji[k] == nil { songEmoji[k] = s.emoji ?? "🎵" }
        }
        let gradientPairs: [[Color]] = [
            [Color(hex: "#D96A3E"), Color(hex: "#E6A73E")],
            [Color(hex: "#3E70CC"), Color(hex: "#3EA89C")],
            [Color(hex: "#7840CC"), Color(hex: "#CC4040")],
            [Color(hex: "#CC4040"), Color(hex: "#D97A1A")],
            [Color(hex: "#3EA89C"), Color(hex: "#3E70CC")]
        ]
        let topTracks: [TrackEntry] = songCount
            .sorted { $0.value > $1.value }
            .prefix(10)
            .enumerated()
            .map { idx, pair in
                let parts = pair.key.components(separatedBy: "|")
                return TrackEntry(
                    rank: idx + 1,
                    name: parts.first ?? "",
                    artist: parts.count > 1 ? parts[1] : "",
                    days: pair.value,
                    gradientColors: gradientPairs[idx % gradientPairs.count],
                    emoji: songEmoji[pair.key] ?? "🎵"
                )
            }

        // Top artists (by unique days)
        var artistDays: [String: Set<String>] = [:]
        for s in songs {
            guard let a = s.artistName, let d = s.date else { continue }
            let c = cal.dateComponents([.year, .month, .day], from: d)
            let key = "\(c.year ?? 0)-\(c.month ?? 0)-\(c.day ?? 0)"
            artistDays[a, default: []].insert(key)
        }
        let topArtists: [(name: String, days: Int)] = artistDays
            .map { (name: $0.key, days: $0.value.count) }
            .sorted { $0.days > $1.days }
            .prefix(5)
            .map { $0 }

        let uniqueArtists = artistDays.count
        let uniqueSongs = songCount.count

        return YearlySummaryData(
            year: year,
            totalEntries: songs.count,
            daysLogged: daysLogged,
            uniqueArtists: uniqueArtists,
            uniqueSongs: uniqueSongs,
            longestStreak: longest,
            dominantMood: dominantMood,
            dominantMoodColor: dominantColor,
            monthlyMoodColors: monthlyColors,
            monthlyEntryCounts: monthlyCounts,
            topTracks: topTracks,
            topArtists: topArtists
        )
    }
}
