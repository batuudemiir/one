//
//  SongModelTests.swift
//  oneTests
//
//  Tests for Song and Mood models.
//

import Testing
import SwiftUI
@testable import OneDailyBatuhan

// MARK: - Song Model Tests

struct SongModelTests {

    // MARK: - Song

    @Test("Song initializes with all properties")
    func testSongInit() {
        let url = URL(string: "https://example.com/artwork.jpg")
        let song = Song(
            name: "Strobe",
            artist: "deadmau5",
            genre: "Electronic",
            emoji: "🌐",
            grad: [.blue, .purple],
            shadow: .blue,
            artworkURL: url
        )

        #expect(song.name == "Strobe")
        #expect(song.artist == "deadmau5")
        #expect(song.genre == "Electronic")
        #expect(song.emoji == "🌐")
        #expect(song.grad.count == 2)
        #expect(song.artworkURL == url)
    }

    @Test("Song has default nil artworkURL")
    func testSongDefaultArtworkURL() {
        let song = Song(
            name: "Test",
            artist: "Test",
            genre: "Test",
            emoji: "🎵",
            grad: [.red],
            shadow: .red
        )

        #expect(song.artworkURL == nil)
    }

    @Test("Song conforms to Identifiable")
    func testSongIdentifiable() {
        let a = Song(name: "A", artist: "A", genre: "A", emoji: "A", grad: [.red], shadow: .red)
        let b = Song(name: "A", artist: "A", genre: "A", emoji: "A", grad: [.red], shadow: .red)

        // Each Song gets a new UUID, so they should have different ids
        #expect(a.id != b.id)
    }

    @Test("Song id is stable within instance")
    func testSongIdStable() {
        let song = Song(name: "X", artist: "X", genre: "X", emoji: "X", grad: [], shadow: .clear)
        let idFirst = song.id
        let idSecond = song.id
        #expect(idFirst == idSecond)
    }

    // MARK: - Mood

    @Test("Mood initializes with all properties")
    func testMoodInit() {
        let mood = Mood(color: .red, word: "Ateşli", isDark: true)

        #expect(mood.word == "Ateşli")
        #expect(mood.isDark == true)
    }

    @Test("Mood conforms to Identifiable")
    func testMoodIdentifiable() {
        let a = Mood(color: .red, word: "A", isDark: true)
        let b = Mood(color: .red, word: "A", isDark: true)

        #expect(a.id != b.id)
    }

    @Test("Mood isDark false")
    func testMoodIsDarkFalse() {
        let mood = Mood(color: .white, word: "Temiz", isDark: false)
        #expect(mood.isDark == false)
    }

    @Test("Mood word can be any string")
    func testMoodWordVariety() {
        let moods = [
            Mood(color: .red, word: "Tutkulu", isDark: true),
            Mood(color: .orange, word: "Enerjik", isDark: true),
            Mood(color: .yellow, word: "Işıklı", isDark: true),
            Mood(color: .green, word: "Sakin", isDark: true),
            Mood(color: .blue, word: "Derin", isDark: true),
            Mood(color: .purple, word: "Gizemli", isDark: true),
            Mood(color: .black, word: "Boş", isDark: true),
            Mood(color: .white, word: "Temiz", isDark: false),
        ]

        #expect(moods.count == 8)
        let words = moods.map { $0.word }
        let uniqueWords = Set(words)
        #expect(words.count == uniqueWords.count, "All mood words should be unique")
    }
}
