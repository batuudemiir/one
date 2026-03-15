//
//  TodayModelsTests.swift
//  oneTests
//
//  Tests for TodayModels — TodayState, SongResult, MoodOption, FeelingOption.
//

import Testing
import SwiftUI
@testable import OneDailyBatuhan

// MARK: - Today Models Tests

struct TodayModelsTests {

    // MARK: - TodayState

    @Test("TodayState has empty and completed cases")
    func testTodayStateCases() {
        let empty: TodayState = .empty
        let completed: TodayState = .completed

        // Verify they are distinct enum values
        switch empty {
        case .empty: break
        case .completed: Issue.record("Should be .empty")
        }

        switch completed {
        case .completed: break
        case .empty: Issue.record("Should be .completed")
        }
    }

    // MARK: - SongResult

    @Test("SongResult initializes correctly")
    func testSongResultInit() {
        let id = UUID()
        let url = URL(string: "https://open.spotify.com/track/abc123")
        let artworkURL = URL(string: "https://i.scdn.co/image/abc")

        let result = SongResult(
            id: id,
            name: "Last Last",
            artist: "Burna Boy",
            genre: "Afrobeats",
            coverURL: artworkURL,
            spotifyURL: url,
            artworkURLString: "https://i.scdn.co/image/abc"
        )

        #expect(result.id == id)
        #expect(result.name == "Last Last")
        #expect(result.artist == "Burna Boy")
        #expect(result.genre == "Afrobeats")
        #expect(result.coverURL == artworkURL)
        #expect(result.spotifyURL == url)
        #expect(result.artworkURLString == "https://i.scdn.co/image/abc")
    }

    @Test("SongResult with nil optional fields")
    func testSongResultNilFields() {
        let result = SongResult(
            id: UUID(),
            name: "Test",
            artist: "Test",
            genre: "Test",
            coverURL: nil,
            spotifyURL: nil,
            artworkURLString: nil
        )

        #expect(result.coverURL == nil)
        #expect(result.spotifyURL == nil)
        #expect(result.artworkURLString == nil)
    }

    // MARK: - MoodOption

    @Test("MoodOption.all has exactly 8 moods")
    func testMoodOptionCount() {
        #expect(MoodOption.all.count == 8)
    }

    @Test("MoodOption.all contains all expected keys")
    func testMoodOptionKeys() {
        let expectedKeys = ["tutkulu", "enerjik", "isikli", "sakin", "derin", "gizemli", "bos", "temiz"]
        let actualKeys = MoodOption.all.map { $0.key }

        for key in expectedKeys {
            #expect(actualKeys.contains(key), "MoodOption.all should contain key '\(key)'")
        }
    }

    @Test("MoodOption.all contains all expected labels")
    func testMoodOptionLabels() {
        let expectedLabels = ["Tutkulu", "Enerjik", "Işıklı", "Sakin", "Derin", "Gizemli", "Boş", "Temiz"]
        let actualLabels = MoodOption.all.map { $0.label }

        for label in expectedLabels {
            #expect(actualLabels.contains(label), "MoodOption.all should contain label '\(label)'")
        }
    }

    @Test("MoodOption.all has unique ids")
    func testMoodOptionUniqueIds() {
        let ids = MoodOption.all.map { $0.id }
        let uniqueIds = Set(ids)
        #expect(ids.count == uniqueIds.count, "All MoodOption ids should be unique")
    }

    @Test("MoodOption.all has unique keys")
    func testMoodOptionUniqueKeys() {
        let keys = MoodOption.all.map { $0.key }
        let uniqueKeys = Set(keys)
        #expect(keys.count == uniqueKeys.count, "All MoodOption keys should be unique")
    }

    // MARK: - FeelingOption

    @Test("FeelingOption.all has exactly 8 feelings")
    func testFeelingOptionCount() {
        #expect(FeelingOption.all.count == 8)
    }

    @Test("FeelingOption.all contains all FeelingType values")
    func testFeelingOptionCoversAllTypes() {
        let allTypes = FeelingType.allCases
        let optionTypes = FeelingOption.all.map { $0.type }

        for type in allTypes {
            #expect(optionTypes.contains(type), "FeelingOption.all should contain FeelingType.\(type)")
        }
    }

    @Test("FeelingOption has Turkish labels")
    func testFeelingOptionLabels() {
        let expectedLabels = ["Sakin", "Mutlu", "Hüzünlü", "Kaygılı", "Heyecanlı", "Yorgun", "Öfkeli", "Huzurlu"]
        let actualLabels = FeelingOption.all.map { $0.label }

        for label in expectedLabels {
            #expect(actualLabels.contains(label), "FeelingOption.all should contain label '\(label)'")
        }
    }

    @Test("FeelingOption type-label mapping is correct")
    func testFeelingOptionTypeMapping() {
        let mapping: [FeelingType: String] = [
            .calm: "Sakin",
            .happy: "Mutlu",
            .sad: "Hüzünlü",
            .anxious: "Kaygılı",
            .excited: "Heyecanlı",
            .tired: "Yorgun",
            .angry: "Öfkeli",
            .peaceful: "Huzurlu"
        ]

        for option in FeelingOption.all {
            if let expectedLabel = mapping[option.type] {
                #expect(option.label == expectedLabel,
                       "FeelingType.\(option.type) should map to '\(expectedLabel)', got '\(option.label)'")
            }
        }
    }

    @Test("FeelingOption has unique ids")
    func testFeelingOptionUniqueIds() {
        let ids = FeelingOption.all.map { $0.id }
        let uniqueIds = Set(ids)
        #expect(ids.count == uniqueIds.count, "All FeelingOption ids should be unique")
    }
}
