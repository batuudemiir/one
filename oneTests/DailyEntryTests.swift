//
//  DailyEntryTests.swift
//  oneTests
//
//  DailyEntry model tests — conversion, equality, hashing, time parsing.
//

import Testing
import SwiftUI
import CoreData
@testable import OneDailyBatuhan

// MARK: - DailyEntry Model Tests

struct DailyEntryTests {

    // MARK: - Helpers

    /// Create a sample DailyEntry with sensible defaults, overridable per-field.
    private func makeSample(
        id: UUID = UUID(),
        date: Date = Date(),
        songName: String = "Strobe",
        artistName: String = "deadmau5",
        genre: String = "Electronic",
        moodColorHex: String = "#5B8DEF",
        moodLabel: String = "Derin",
        feeling: FeelingType = .calm,
        feelingLabel: String = "Sakin",
        time: String = "21:14",
        photoURL: URL? = nil,
        shareWithCircle: Bool = false,
        weatherIcon: String = "⛅",
        weatherDesc: String = "14°C · Parçalı bulutlu",
        spotifyURL: URL? = nil,
        platform: String = "Spotify",
        note: String? = nil
    ) -> DailyEntry {
        DailyEntry(
            id: id,
            date: date,
            songName: songName,
            artistName: artistName,
            genre: genre,
            moodColor: Color(hex: moodColorHex),
            moodColorHex: moodColorHex,
            moodLabel: moodLabel,
            feeling: feeling,
            feelingLabel: feelingLabel,
            time: time,
            photoURL: photoURL,
            shareWithCircle: shareWithCircle,
            weatherIcon: weatherIcon,
            weatherDesc: weatherDesc,
            spotifyURL: spotifyURL,
            platform: platform,
            note: note
        )
    }

    // MARK: - Initialization Tests

    @Test("DailyEntry initializes with all properties correctly")
    func testInitialization() {
        let id = UUID()
        let date = Date()
        let spotifyURL = URL(string: "https://open.spotify.com/track/123")
        
        let entry = makeSample(
            id: id,
            date: date,
            songName: "Last Last",
            artistName: "Burna Boy",
            genre: "Afrobeats",
            moodColorHex: "#E84040",
            moodLabel: "Ateşli",
            feeling: .excited,
            feelingLabel: "Heyecanlı",
            time: "14:30",
            shareWithCircle: true,
            spotifyURL: spotifyURL,
            platform: "Spotify",
            note: "Harika bir gün!"
        )

        #expect(entry.id == id)
        #expect(entry.songName == "Last Last")
        #expect(entry.artistName == "Burna Boy")
        #expect(entry.genre == "Afrobeats")
        #expect(entry.moodColorHex == "#E84040")
        #expect(entry.moodLabel == "Ateşli")
        #expect(entry.feeling == .excited)
        #expect(entry.feelingLabel == "Heyecanlı")
        #expect(entry.time == "14:30")
        #expect(entry.shareWithCircle == true)
        #expect(entry.spotifyURL == spotifyURL)
        #expect(entry.platform == "Spotify")
        #expect(entry.note == "Harika bir gün!")
    }

    @Test("DailyEntry with nil optional fields")
    func testOptionalFields() {
        let entry = makeSample(photoURL: nil, spotifyURL: nil, note: nil)

        #expect(entry.photoURL == nil)
        #expect(entry.spotifyURL == nil)
        #expect(entry.note == nil)
    }

    // MARK: - Equality Tests

    @Test("DailyEntry equality based on id only")
    func testEqualityById() {
        let sharedId = UUID()

        let a = makeSample(id: sharedId, songName: "Song A")
        let b = makeSample(id: sharedId, songName: "Song B")

        // Same id → equal, regardless of different song names
        #expect(a == b)
    }

    @Test("DailyEntry inequality when ids differ")
    func testInequalityById() {
        let a = makeSample(id: UUID(), songName: "Song A")
        let b = makeSample(id: UUID(), songName: "Song A")

        // Different ids → not equal, even with the same song name
        #expect(a != b)
    }

    // MARK: - Hashable Tests

    @Test("DailyEntry hashes to same value for same id")
    func testHashConsistency() {
        let id = UUID()
        let a = makeSample(id: id, songName: "A")
        let b = makeSample(id: id, songName: "B")

        #expect(a.hashValue == b.hashValue)
    }

    @Test("DailyEntry can be stored in a Set")
    func testSetMembership() {
        let id = UUID()
        let a = makeSample(id: id, songName: "A")
        let b = makeSample(id: id, songName: "B")

        var set: Set<DailyEntry> = [a]
        set.insert(b)

        // b should not be inserted because it has the same id
        #expect(set.count == 1)
    }

    @Test("DailyEntry with different ids creates distinct set entries")
    func testSetDistinct() {
        let a = makeSample(id: UUID())
        let b = makeSample(id: UUID())
        let c = makeSample(id: UUID())

        let set: Set<DailyEntry> = [a, b, c]
        #expect(set.count == 3)
    }

    // MARK: - FeelingType Tests

    @Test("FeelingType has all 8 cases")
    func testFeelingTypeCaseCount() {
        #expect(FeelingType.allCases.count == 8)
    }

    @Test("FeelingType raw values match expected strings")
    func testFeelingTypeRawValues() {
        let expected: [FeelingType: String] = [
            .calm: "calm",
            .happy: "happy",
            .sad: "sad",
            .anxious: "anxious",
            .excited: "excited",
            .tired: "tired",
            .angry: "angry",
            .peaceful: "peaceful"
        ]

        for (feeling, raw) in expected {
            #expect(feeling.rawValue == raw, "FeelingType.\(feeling) should have rawValue \"\(raw)\"")
        }
    }

    @Test("FeelingType round-trips via rawValue init")
    func testFeelingTypeRoundTrip() {
        for feeling in FeelingType.allCases {
            let roundTripped = FeelingType(rawValue: feeling.rawValue)
            #expect(roundTripped == feeling)
        }
    }

    @Test("Invalid rawValue returns nil")
    func testFeelingTypeInvalidRawValue() {
        let invalid = FeelingType(rawValue: "depressed")
        #expect(invalid == nil)
    }

    // MARK: - toDailySong Conversion Tests

    @Test("toDailySong correctly maps basic fields")
    func testToDailySongBasicFields() {
        let pc = PersistenceController(inMemory: true)
        let context = pc.container.viewContext

        let entry = makeSample(
            songName: "HUMBLE.",
            artistName: "Kendrick Lamar",
            genre: "Hip-Hop",
            moodColorHex: "#E84040",
            moodLabel: "Ateşli",
            feeling: .excited,
            feelingLabel: "Heyecanlı",
            time: "15:00",
            shareWithCircle: true,
            weatherIcon: "☀️",
            weatherDesc: "28°C · Güneşli",
            platform: "Spotify",
            note: "Test note"
        )

        let dailySong = entry.toDailySong(context: context)

        #expect(dailySong.songName == "HUMBLE.")
        #expect(dailySong.artistName == "Kendrick Lamar")
        #expect(dailySong.genre == "Hip-Hop")
        #expect(dailySong.moodColorHex == "#E84040")
        #expect(dailySong.moodLabel == "Ateşli")
        #expect(dailySong.moodWord == "Ateşli")
        #expect(dailySong.feeling == "excited")
        #expect(dailySong.feelingLabel == "Heyecanlı")
        #expect(dailySong.shareWithCircle == true)
        #expect(dailySong.weatherIcon == "☀️")
        #expect(dailySong.weatherDesc == "28°C · Güneşli")
        #expect(dailySong.platform == "Spotify")
        #expect(dailySong.dailyNote == "Test note")
    }

    @Test("toDailySong sets id correctly")
    func testToDailySongId() {
        let pc = PersistenceController(inMemory: true)
        let context = pc.container.viewContext
        let id = UUID()

        let entry = makeSample(id: id)
        let dailySong = entry.toDailySong(context: context)

        #expect(dailySong.id == id)
    }

    @Test("toDailySong sets date correctly")
    func testToDailySongDate() {
        let pc = PersistenceController(inMemory: true)
        let context = pc.container.viewContext
        let date = Date()

        let entry = makeSample(date: date)
        let dailySong = entry.toDailySong(context: context)

        #expect(dailySong.date == date)
    }

    // MARK: - Time Parsing Tests

    @Test("toDailySong parses valid time string into createdAt")
    func testTimeParsing() {
        let pc = PersistenceController(inMemory: true)
        let context = pc.container.viewContext

        let baseDate = Calendar.current.date(from: DateComponents(year: 2026, month: 3, day: 1))!
        let entry = makeSample(date: baseDate, time: "21:14")
        let dailySong = entry.toDailySong(context: context)

        // createdAt should have the time 21:14 on the base date
        let calendar = Calendar.current
        let components = calendar.dateComponents([.hour, .minute], from: dailySong.createdAt!)
        #expect(components.hour == 21)
        #expect(components.minute == 14)
    }

    @Test("toDailySong falls back to date when time is invalid")
    func testTimeParsingInvalidFallback() {
        let pc = PersistenceController(inMemory: true)
        let context = pc.container.viewContext

        let baseDate = Date()
        let entry = makeSample(date: baseDate, time: "invalid-time")
        let dailySong = entry.toDailySong(context: context)

        // Should fall back to the base date
        #expect(dailySong.createdAt == baseDate)
    }

    @Test("toDailySong parses midnight time 00:00")
    func testTimeParsingMidnight() {
        let pc = PersistenceController(inMemory: true)
        let context = pc.container.viewContext

        let baseDate = Calendar.current.date(from: DateComponents(year: 2026, month: 6, day: 15))!
        let entry = makeSample(date: baseDate, time: "00:00")
        let dailySong = entry.toDailySong(context: context)

        let calendar = Calendar.current
        let components = calendar.dateComponents([.hour, .minute], from: dailySong.createdAt!)
        #expect(components.hour == 0)
        #expect(components.minute == 0)
    }

    @Test("toDailySong parses end-of-day time 23:59")
    func testTimeParsingEndOfDay() {
        let pc = PersistenceController(inMemory: true)
        let context = pc.container.viewContext

        let baseDate = Calendar.current.date(from: DateComponents(year: 2026, month: 1, day: 1))!
        let entry = makeSample(date: baseDate, time: "23:59")
        let dailySong = entry.toDailySong(context: context)

        let calendar = Calendar.current
        let components = calendar.dateComponents([.hour, .minute], from: dailySong.createdAt!)
        #expect(components.hour == 23)
        #expect(components.minute == 59)
    }
}
