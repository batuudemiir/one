//
//  PersistenceControllerTests.swift
//  oneTests
//
//  Tests for PersistenceController — CRUD operations, pattern analysis, Color hex conversion.
//

import Testing
import SwiftUI
import CoreData
@testable import OneDailyBatuhan

// MARK: - PersistenceController Tests

struct PersistenceControllerTests {

    // MARK: - Helpers

    /// Create a fresh in-memory PersistenceController for each test.
    private func makePersistence() -> PersistenceController {
        PersistenceController(inMemory: true)
    }

    private func makeSong(
        name: String = "Strobe",
        artist: String = "deadmau5",
        genre: String = "Electronic",
        emoji: String = "🎵"
    ) -> Song {
        Song(
            name: name,
            artist: artist,
            genre: genre,
            emoji: emoji,
            grad: [.blue, .purple],
            shadow: .blue
        )
    }

    private func makeMood(
        color: Color = .blue,
        word: String = "Derin",
        isDark: Bool = true
    ) -> Mood {
        Mood(color: color, word: word, isDark: isDark)
    }

    // MARK: - Save & Fetch Single

    @Test("Save and fetch a daily song for a specific date")
    func testSaveAndFetchDailySong() {
        let pc = makePersistence()
        let context = pc.container.viewContext
        let today = Calendar.current.startOfDay(for: Date())

        pc.saveDailySong(
            date: today,
            song: makeSong(),
            mood: makeMood(),
            note: "Test note",
            platform: "Spotify",
            context: context
        )

        let fetched = pc.fetchDailySong(for: today, context: context)
        #expect(fetched != nil)
        #expect(fetched?.songName == "Strobe")
        #expect(fetched?.artistName == "deadmau5")
        #expect(fetched?.genre == "Electronic")
        #expect(fetched?.moodWord == "Derin")
        #expect(fetched?.dailyNote == "Test note")
        #expect(fetched?.platform == "Spotify")
    }

    @Test("Fetch returns nil for a date with no entry")
    func testFetchReturnsNilForMissingDate() {
        let pc = makePersistence()
        let context = pc.container.viewContext
        let randomDate = Calendar.current.date(from: DateComponents(year: 2020, month: 1, day: 1))!

        let fetched = pc.fetchDailySong(for: randomDate, context: context)
        #expect(fetched == nil)
    }

    // MARK: - Update Existing Entry

    @Test("Saving for the same date updates instead of creating duplicate")
    func testUpdateExistingEntry() {
        let pc = makePersistence()
        let context = pc.container.viewContext
        let today = Calendar.current.startOfDay(for: Date())

        // First save
        pc.saveDailySong(
            date: today,
            song: makeSong(name: "Song A"),
            mood: makeMood(word: "Derin"),
            note: "First",
            platform: "Spotify",
            context: context
        )

        // Second save — should update
        pc.saveDailySong(
            date: today,
            song: makeSong(name: "Song B"),
            mood: makeMood(word: "Sakin"),
            note: "Second",
            platform: "Apple Music",
            context: context
        )

        // Verify only one entry exists
        let all = pc.fetchAllDailySongs(context: context)
        #expect(all.count == 1)

        let fetched = pc.fetchDailySong(for: today, context: context)
        #expect(fetched?.songName == "Song B")
        #expect(fetched?.moodWord == "Sakin")
        #expect(fetched?.dailyNote == "Second")
        #expect(fetched?.platform == "Apple Music")
    }

    // MARK: - Fetch All

    @Test("fetchAllDailySongs returns all entries sorted by date descending")
    func testFetchAllDailySongs() {
        let pc = makePersistence()
        let context = pc.container.viewContext
        let calendar = Calendar.current

        let day1 = calendar.date(from: DateComponents(year: 2026, month: 1, day: 1))!
        let day2 = calendar.date(from: DateComponents(year: 2026, month: 1, day: 2))!
        let day3 = calendar.date(from: DateComponents(year: 2026, month: 1, day: 3))!

        pc.saveDailySong(date: day1, song: makeSong(name: "A"), mood: makeMood(), note: "", platform: "Spotify", context: context)
        pc.saveDailySong(date: day2, song: makeSong(name: "B"), mood: makeMood(), note: "", platform: "Spotify", context: context)
        pc.saveDailySong(date: day3, song: makeSong(name: "C"), mood: makeMood(), note: "", platform: "Spotify", context: context)

        let all = pc.fetchAllDailySongs(context: context)
        #expect(all.count == 3)

        // Should be sorted descending (newest first)
        #expect(all[0].songName == "C")
        #expect(all[1].songName == "B")
        #expect(all[2].songName == "A")
    }

    @Test("fetchAllDailySongs returns empty array when no entries exist")
    func testFetchAllDailySongsEmpty() {
        let pc = makePersistence()
        let context = pc.container.viewContext

        let all = pc.fetchAllDailySongs(context: context)
        #expect(all.isEmpty)
    }

    // MARK: - Fetch Monthly

    @Test("fetchDailySongsForMonth returns only songs in the requested month")
    func testFetchDailySongsForMonth() {
        let pc = makePersistence()
        let context = pc.container.viewContext
        let calendar = Calendar.current

        // January entries
        let jan1 = calendar.date(from: DateComponents(year: 2026, month: 1, day: 5))!
        let jan2 = calendar.date(from: DateComponents(year: 2026, month: 1, day: 20))!
        // February entry
        let feb1 = calendar.date(from: DateComponents(year: 2026, month: 2, day: 10))!

        pc.saveDailySong(date: jan1, song: makeSong(name: "Jan A"), mood: makeMood(), note: "", platform: "Spotify", context: context)
        pc.saveDailySong(date: jan2, song: makeSong(name: "Jan B"), mood: makeMood(), note: "", platform: "Spotify", context: context)
        pc.saveDailySong(date: feb1, song: makeSong(name: "Feb A"), mood: makeMood(), note: "", platform: "Spotify", context: context)

        let janSongs = pc.fetchDailySongsForMonth(year: 2026, month: 1, context: context)
        #expect(janSongs.count == 2)

        let febSongs = pc.fetchDailySongsForMonth(year: 2026, month: 2, context: context)
        #expect(febSongs.count == 1)
        #expect(febSongs.first?.songName == "Feb A")
    }

    @Test("fetchDailySongsForMonth returns empty for month with no entries")
    func testFetchMonthEmpty() {
        let pc = makePersistence()
        let context = pc.container.viewContext

        let songs = pc.fetchDailySongsForMonth(year: 2026, month: 6, context: context)
        #expect(songs.isEmpty)
    }

    @Test("fetchDailySongsForMonth is sorted ascending")
    func testFetchMonthlySorted() {
        let pc = makePersistence()
        let context = pc.container.viewContext
        let calendar = Calendar.current

        let d15 = calendar.date(from: DateComponents(year: 2026, month: 3, day: 15))!
        let d5 = calendar.date(from: DateComponents(year: 2026, month: 3, day: 5))!
        let d25 = calendar.date(from: DateComponents(year: 2026, month: 3, day: 25))!

        pc.saveDailySong(date: d15, song: makeSong(name: "Mid"), mood: makeMood(), note: "", platform: "Spotify", context: context)
        pc.saveDailySong(date: d5, song: makeSong(name: "Early"), mood: makeMood(), note: "", platform: "Spotify", context: context)
        pc.saveDailySong(date: d25, song: makeSong(name: "Late"), mood: makeMood(), note: "", platform: "Spotify", context: context)

        let songs = pc.fetchDailySongsForMonth(year: 2026, month: 3, context: context)
        #expect(songs.count == 3)
        #expect(songs[0].songName == "Early")
        #expect(songs[1].songName == "Mid")
        #expect(songs[2].songName == "Late")
    }

    // MARK: - Pattern Analysis

    @Test("analyzeSongPatterns finds repeated songs")
    func testAnalyzeSongPatternsFindsRepeats() {
        let pc = makePersistence()
        let context = pc.container.viewContext
        let calendar = Calendar.current

        // "Strobe" selected 3 times
        for day in [1, 5, 10] {
            let date = calendar.date(from: DateComponents(year: 2026, month: 1, day: day))!
            pc.saveDailySong(date: date, song: makeSong(name: "Strobe", artist: "deadmau5"), mood: makeMood(), note: "", platform: "Spotify", context: context)
        }

        // "Last Last" selected 2 times
        for day in [3, 7] {
            let date = calendar.date(from: DateComponents(year: 2026, month: 1, day: day))!
            pc.saveDailySong(date: date, song: makeSong(name: "Last Last", artist: "Burna Boy"), mood: makeMood(), note: "", platform: "Spotify", context: context)
        }

        // "HUMBLE." selected only 1 time — should NOT appear in patterns
        let date1 = calendar.date(from: DateComponents(year: 2026, month: 1, day: 15))!
        pc.saveDailySong(date: date1, song: makeSong(name: "HUMBLE.", artist: "Kendrick"), mood: makeMood(), note: "", platform: "Spotify", context: context)

        let patterns = pc.analyzeSongPatterns(context: context)

        // Should have 2 patterns (songs with count > 1)
        #expect(patterns.count == 2)

        // Sorted by count descending
        #expect(patterns.first?.songName == "Strobe")
        #expect(patterns.first?.count == 3)
        #expect(patterns.last?.songName == "Last Last")
        #expect(patterns.last?.count == 2)
    }

    @Test("analyzeSongPatterns returns empty when no songs exist")
    func testAnalyzePatternsEmpty() {
        let pc = makePersistence()
        let context = pc.container.viewContext

        let patterns = pc.analyzeSongPatterns(context: context)
        #expect(patterns.isEmpty)
    }

    @Test("analyzeSongPatterns percentage calculation")
    func testAnalyzePatternsPercentage() {
        let pc = makePersistence()
        let context = pc.container.viewContext
        let calendar = Calendar.current

        // 4 total songs, "A" appears 2 times → 50%
        for (day, name) in [(1, "A"), (2, "A"), (3, "B"), (4, "C")] {
            let date = calendar.date(from: DateComponents(year: 2026, month: 4, day: day))!
            pc.saveDailySong(date: date, song: makeSong(name: name, artist: "Artist"), mood: makeMood(), note: "", platform: "Spotify", context: context)
        }

        let patterns = pc.analyzeSongPatterns(context: context)
        #expect(patterns.count == 1) // Only "A" repeats
        #expect(patterns.first?.percentage == 0.5) // 2/4 = 0.5
    }

    @Test("getMostFrequentSong returns the top pattern")
    func testGetMostFrequentSong() {
        let pc = makePersistence()
        let context = pc.container.viewContext
        let calendar = Calendar.current

        for day in [1, 2, 3] {
            let date = calendar.date(from: DateComponents(year: 2026, month: 5, day: day))!
            pc.saveDailySong(date: date, song: makeSong(name: "Number One"), mood: makeMood(), note: "", platform: "Spotify", context: context)
        }

        for day in [4, 5] {
            let date = calendar.date(from: DateComponents(year: 2026, month: 5, day: day))!
            pc.saveDailySong(date: date, song: makeSong(name: "Number Two"), mood: makeMood(), note: "", platform: "Spotify", context: context)
        }

        let top = pc.getMostFrequentSong(context: context)
        #expect(top?.songName == "Number One")
        #expect(top?.count == 3)
    }

    @Test("getMostFrequentSong returns nil when no patterns")
    func testGetMostFrequentSongNil() {
        let pc = makePersistence()
        let context = pc.container.viewContext

        let top = pc.getMostFrequentSong(context: context)
        #expect(top == nil)
    }

    // MARK: - SongPattern dateString

    @Test("SongPattern dateString joins up to 4 dates with Turkish format")
    func testSongPatternDateString() {
        let calendar = Calendar.current
        let dates = [
            calendar.date(from: DateComponents(year: 2026, month: 1, day: 4))!,
            calendar.date(from: DateComponents(year: 2026, month: 1, day: 17))!,
            calendar.date(from: DateComponents(year: 2026, month: 2, day: 2))!,
        ]

        let pattern = PersistenceController.SongPattern(
            songName: "Strobe",
            artistName: "deadmau5",
            count: 3,
            percentage: 0.3,
            color: .blue,
            dates: dates,
            emoji: "🎵"
        )

        let dateString = pattern.dateString
        // Should contain separator dots
        #expect(dateString.contains("·"))
        // Should not have "..." since <= 4
        #expect(!dateString.contains("..."))
    }

    @Test("SongPattern dateString adds ... for more than 4 dates")
    func testSongPatternDateStringTruncated() {
        let calendar = Calendar.current
        let dates = (1...6).map { day in
            calendar.date(from: DateComponents(year: 2026, month: 3, day: day))!
        }

        let pattern = PersistenceController.SongPattern(
            songName: "Test",
            artistName: "Test",
            count: 6,
            percentage: 0.5,
            color: .red,
            dates: dates,
            emoji: nil
        )

        let dateString = pattern.dateString
        #expect(dateString.hasSuffix("..."))
    }

    // MARK: - Circle Sharing

    @Test("saveDailySong does not share without photo")
    func testCircleSharingWithoutPhoto() {
        let pc = makePersistence()
        let context = pc.container.viewContext
        let today = Calendar.current.startOfDay(for: Date())

        pc.saveDailySong(
            date: today,
            song: makeSong(),
            mood: makeMood(),
            note: "",
            platform: "Spotify",
            photo: nil,
            shareWithCircle: true, // Flag is true but no photo
            context: context
        )

        let fetched = pc.fetchDailySong(for: today, context: context)
        // Should NOT be shared because photo is nil
        #expect(fetched?.isSharedWithCircle == false)
    }

    // MARK: - Note Trimming

    @Test("saveDailySong trims whitespace from notes")
    func testNoteTrimming() {
        let pc = makePersistence()
        let context = pc.container.viewContext
        let today = Calendar.current.startOfDay(for: Date())

        pc.saveDailySong(
            date: today,
            song: makeSong(),
            mood: makeMood(),
            note: "  hello world  \n",
            platform: "Spotify",
            context: context
        )

        let fetched = pc.fetchDailySong(for: today, context: context)
        #expect(fetched?.dailyNote == "hello world")
    }

    // MARK: - Color.toHex() Extension

    @Test("Color.toHex returns valid hex string")
    func testColorToHex() {
        let red = Color.red.toHex()
        // Red should be close to #FF0000
        #expect(red.hasPrefix("#"))
        #expect(red.count == 7)
    }

    @Test("Color.toHex round-trip with known hex")
    func testColorToHexRoundTrip() {
        let originalHex = "#5B8DEF"
        let color = Color(hex: originalHex)
        let resultHex = color.toHex()

        // Parse both hexes to compare RGB values with tolerance
        let originalR = Int(originalHex.dropFirst().prefix(2), radix: 16) ?? 0
        let originalG = Int(originalHex.dropFirst(3).prefix(2), radix: 16) ?? 0
        let originalB = Int(originalHex.dropFirst(5).prefix(2), radix: 16) ?? 0

        let resultClean = String(resultHex.dropFirst())
        let resultR = Int(resultClean.prefix(2), radix: 16) ?? 0
        let resultG = Int(resultClean.dropFirst(2).prefix(2), radix: 16) ?? 0
        let resultB = Int(resultClean.dropFirst(4).prefix(2), radix: 16) ?? 0

        #expect(abs(originalR - resultR) <= 1)
        #expect(abs(originalG - resultG) <= 1)
        #expect(abs(originalB - resultB) <= 1)
    }

    // MARK: - Date Normalization

    @Test("saveDailySong normalizes date to start of day")
    func testDateNormalization() {
        let pc = makePersistence()
        let context = pc.container.viewContext

        // Create date at 15:30
        var comps = DateComponents()
        comps.year = 2026
        comps.month = 3
        comps.day = 1
        comps.hour = 15
        comps.minute = 30
        let afternoonDate = Calendar.current.date(from: comps)!

        pc.saveDailySong(
            date: afternoonDate,
            song: makeSong(),
            mood: makeMood(),
            note: "",
            platform: "Spotify",
            context: context
        )

        // Should be fetchable using any time on that day
        let morning = Calendar.current.startOfDay(for: afternoonDate)
        let fetched = pc.fetchDailySong(for: morning, context: context)
        #expect(fetched != nil)

        // The stored date should be start of day
        let storedDate = fetched?.date
        let startOfDay = Calendar.current.startOfDay(for: afternoonDate)
        #expect(storedDate == startOfDay)
    }
}
