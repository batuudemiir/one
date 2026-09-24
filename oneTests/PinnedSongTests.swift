//
//  PinnedSongTests.swift
//  oneTests
//
//  Unit tests for PinnedSong struct — JSON round-trip, Equatable, nil handling.
//

import Testing
import Foundation
@testable import OneDailyBatuhan

// MARK: - PinnedSong Tests

struct PinnedSongTests {

    // MARK: - JSON Round-trip

    @Test("PinnedSong survives JSON encode → decode round-trip")
    func testJSONRoundTrip() throws {
        let original = PinnedSong(
            songName: "Strobe",
            artistName: "deadmau5",
            artworkURLString: "https://example.com/art.jpg",
            moodColorHex: "#9B7FD4",
            pinnedAt: Date(timeIntervalSince1970: 1_700_000_000)
        )

        let json = original.toJSONString()
        #expect(json != nil)

        let decoded = PinnedSong.fromJSONString(json!)
        #expect(decoded != nil)
        #expect(decoded?.songName == original.songName)
        #expect(decoded?.artistName == original.artistName)
        #expect(decoded?.artworkURLString == original.artworkURLString)
        #expect(decoded?.moodColorHex == original.moodColorHex)
    }

    @Test("PinnedSong round-trip preserves nil artwork")
    func testNilArtworkRoundTrip() throws {
        let song = PinnedSong(
            songName: "Ece",
            artistName: "Teoman",
            artworkURLString: nil,
            moodColorHex: nil,
            pinnedAt: Date(timeIntervalSince1970: 1_700_000_000)
        )

        let json = song.toJSONString()
        let decoded = PinnedSong.fromJSONString(json!)
        #expect(decoded?.artworkURLString == nil)
        #expect(decoded?.moodColorHex == nil)
    }

    // MARK: - fromJSONString edge cases

    @Test("fromJSONString returns nil for empty string")
    func testEmptyStringReturnsNil() {
        #expect(PinnedSong.fromJSONString("") == nil)
    }

    @Test("fromJSONString returns nil for invalid JSON")
    func testInvalidJSONReturnsNil() {
        #expect(PinnedSong.fromJSONString("not-valid-json{}") == nil)
    }

    // MARK: - toJSONString

    @Test("toJSONString produces non-empty string")
    func testToJSONStringNotEmpty() {
        let song = PinnedSong(
            songName: "Test",
            artistName: "Artist",
            artworkURLString: nil,
            moodColorHex: nil,
            pinnedAt: Date()
        )
        let json = song.toJSONString()
        #expect(json != nil)
        #expect(json?.isEmpty == false)
    }

    // MARK: - Equatable

    @Test("PinnedSong Equatable works correctly for equal instances")
    func testEquatableEqual() {
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        let a = PinnedSong(songName: "X", artistName: "Y", artworkURLString: nil, moodColorHex: nil, pinnedAt: date)
        let b = PinnedSong(songName: "X", artistName: "Y", artworkURLString: nil, moodColorHex: nil, pinnedAt: date)
        #expect(a == b)
    }

    @Test("PinnedSong Equatable detects differing song names")
    func testEquatableNotEqual() {
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        let a = PinnedSong(songName: "A", artistName: "Y", artworkURLString: nil, moodColorHex: nil, pinnedAt: date)
        let b = PinnedSong(songName: "B", artistName: "Y", artworkURLString: nil, moodColorHex: nil, pinnedAt: date)
        #expect(a != b)
    }

    // MARK: - Schema version

    @Test("Default schemaVersion is 1")
    func testSchemaVersion() {
        let song = PinnedSong(
            songName: "S", artistName: "A",
            artworkURLString: nil, moodColorHex: nil, pinnedAt: Date()
        )
        #expect(song.schemaVersion == 1)
    }
}

// MARK: - PublicUserProfile PinnedSong Tests

struct PublicUserProfilePinnedSongTests {

    @Test("PublicUserProfile has nil pinnedSong by default when no JSON")
    func testNilPinnedSongFromEmptyRecord() {
        // fromJSONString with empty string returns nil
        let result = PinnedSong.fromJSONString("")
        #expect(result == nil)
    }

    @Test("PinnedSong parsed from valid JSON string")
    func testParsedFromValidJSON() {
        let song = PinnedSong(
            songName: "Acımasız Dünya",
            artistName: "Mor ve Ötesi",
            artworkURLString: nil,
            moodColorHex: "#E63946",
            pinnedAt: Date(timeIntervalSince1970: 1_700_000_000)
        )
        let json = song.toJSONString()!
        let parsed = PinnedSong.fromJSONString(json)
        #expect(parsed?.songName == "Acımasız Dünya")
        #expect(parsed?.artistName == "Mor ve Ötesi")
        #expect(parsed?.moodColorHex == "#E63946")
    }
}
