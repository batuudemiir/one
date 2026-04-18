//
//  YearlySummaryTests.swift
//  oneTests
//
//  Tests YearlySummaryViewModel.build and TasteProfileExporter JSON shape.
//

import Testing
import Foundation
import CoreData
@testable import OneDailyBatuhan

struct YearlySummaryTests {

    private func makePersistence() -> PersistenceController {
        PersistenceController(inMemory: true)
    }

    /// Insert a DailySong in the given context.
    @discardableResult
    private func insertSong(
        context: NSManagedObjectContext,
        songName: String = "Test",
        artist: String = "Artist",
        mood: String = "Huzurlu",
        moodHex: String = "#3EA89C",
        date: Date,
        emoji: String = "🎵"
    ) -> DailySong {
        let s = DailySong(context: context)
        s.id = UUID()
        s.songName = songName
        s.artistName = artist
        s.moodWord = mood
        s.moodColorHex = moodHex
        s.date = date
        s.emoji = emoji
        return s
    }

    private func date(_ y: Int, _ m: Int, _ d: Int) -> Date {
        var c = DateComponents(); c.year = y; c.month = m; c.day = d; c.hour = 12
        return Calendar.current.date(from: c)!
    }

    // MARK: - build()

    @Test func buildAggregatesEntriesAndUniqueDays() {
        let ctx = makePersistence().container.viewContext
        // 3 entries on day 5, 1 on day 6 — 2 unique days, 4 entries.
        insertSong(context: ctx, date: date(2026, 3, 5))
        insertSong(context: ctx, songName: "Another", date: date(2026, 3, 5))
        insertSong(context: ctx, songName: "Third", date: date(2026, 3, 5))
        insertSong(context: ctx, date: date(2026, 3, 6))

        let songs = (try? ctx.fetch(DailySong.fetchRequest() as NSFetchRequest<DailySong>)) ?? []
        let data = YearlySummaryViewModel.build(year: 2026, songs: songs)

        #expect(data.totalEntries == 4)
        #expect(data.daysLogged == 2)
        #expect(data.year == 2026)
    }

    @Test func buildComputesLongestStreak() {
        let ctx = makePersistence().container.viewContext
        // 3 consecutive days then gap then 5 consecutive days → longest = 5
        for day in 1...3 { insertSong(context: ctx, date: date(2026, 1, day)) }
        for day in 10...14 { insertSong(context: ctx, date: date(2026, 1, day)) }

        let songs = (try? ctx.fetch(DailySong.fetchRequest() as NSFetchRequest<DailySong>)) ?? []
        let data = YearlySummaryViewModel.build(year: 2026, songs: songs)

        #expect(data.longestStreak == 5)
    }

    @Test func buildPicksDominantMood() {
        let ctx = makePersistence().container.viewContext
        for i in 1...5 { insertSong(context: ctx, mood: "Huzurlu", date: date(2026, 2, i)) }
        for i in 1...2 { insertSong(context: ctx, mood: "Ateşli", date: date(2026, 3, i)) }

        let songs = (try? ctx.fetch(DailySong.fetchRequest() as NSFetchRequest<DailySong>)) ?? []
        let data = YearlySummaryViewModel.build(year: 2026, songs: songs)

        #expect(data.dominantMood == "Huzurlu")
    }

    @Test func buildMonthlyCountsMatch() {
        let ctx = makePersistence().container.viewContext
        insertSong(context: ctx, date: date(2026, 1, 1))
        insertSong(context: ctx, date: date(2026, 3, 1))
        insertSong(context: ctx, date: date(2026, 3, 2))

        let songs = (try? ctx.fetch(DailySong.fetchRequest() as NSFetchRequest<DailySong>)) ?? []
        let data = YearlySummaryViewModel.build(year: 2026, songs: songs)

        #expect(data.monthlyEntryCounts[0] == 1)  // Jan
        #expect(data.monthlyEntryCounts[2] == 2)  // Mar
        #expect(data.monthlyEntryCounts[5] == 0)  // Jun
    }

    @Test func buildTopTracksOrderedByCount() {
        let ctx = makePersistence().container.viewContext
        for i in 1...4 { insertSong(context: ctx, songName: "A", artist: "X", date: date(2026, 4, i)) }
        for i in 1...2 { insertSong(context: ctx, songName: "B", artist: "Y", date: date(2026, 5, i)) }

        let songs = (try? ctx.fetch(DailySong.fetchRequest() as NSFetchRequest<DailySong>)) ?? []
        let data = YearlySummaryViewModel.build(year: 2026, songs: songs)

        #expect(data.topTracks.first?.name == "A")
        #expect(data.topTracks.first?.days == 4)
        #expect(data.topTracks.first?.rank == 1)
    }

    @Test func buildHandlesEmptyInput() {
        let data = YearlySummaryViewModel.build(year: 2026, songs: [])
        #expect(data.totalEntries == 0)
        #expect(data.daysLogged == 0)
        #expect(data.longestStreak == 0)
        #expect(data.topTracks.isEmpty)
        #expect(data.monthlyEntryCounts.count == 12)
    }

    // MARK: - Exporter

    @Test func exporterWritesValidJSON() throws {
        let ctx = makePersistence().container.viewContext
        insertSong(context: ctx, date: date(2026, 6, 1))
        insertSong(context: ctx, date: date(2026, 6, 2))

        let songs = (try? ctx.fetch(DailySong.fetchRequest() as NSFetchRequest<DailySong>)) ?? []
        let data = YearlySummaryViewModel.build(year: 2026, songs: songs)

        let url = try #require(TasteProfileExporter.exportJSON(data: data))
        defer { try? FileManager.default.removeItem(at: url) }

        let raw = try Data(contentsOf: url)
        let decoded = try JSONDecoder().decode(TasteProfileExporter.Payload.self, from: raw)

        #expect(decoded.year == 2026)
        #expect(decoded.totalEntries == 2)
        #expect(decoded.monthlyEntryCounts.count == 12)
        #expect(url.pathExtension == "json")
    }
}
