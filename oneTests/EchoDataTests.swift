//
//  EchoDataTests.swift
//  oneTests
//
//  Tests for EchoData and RepeatedSong models.
//
//  `StreakInfo` ve `EchoData.longestStreak` testleri kaldırıldı: seri
//  (streak) sayacı üründen çıktı — CLAUDE.md "Yapılmayacaklar" listesinde.
//  Testler tipin kendisinden sonra da duruyordu, yani derlenmiyorlardı.
//

import Testing
import SwiftUI
@testable import OneDailyBatuhan

// MARK: - EchoData Tests

struct EchoDataTests {

    // MARK: - EchoData.empty

    @Test("EchoData.empty has 7 nil weekColors")
    func testEmptyWeekColors() {
        let data = EchoData.empty
        #expect(data.weekColors.count == 7)
        for color in data.weekColors {
            #expect(color == nil)
        }
    }

    @Test("EchoData.empty has nil dominantFeeling")
    func testEmptyDominantFeeling() {
        let data = EchoData.empty
        #expect(data.dominantFeeling == nil)
    }

    @Test("EchoData.empty has empty repeatedSongs")
    func testEmptyRepeatedSongs() {
        let data = EchoData.empty
        #expect(data.repeatedSongs.isEmpty)
    }

    @Test("EchoData.empty has zero silentDays")
    func testEmptySilentDays() {
        let data = EchoData.empty
        #expect(data.silentDays == 0)
        #expect(data.silentDates.isEmpty)
    }

    @Test("EchoData.empty has empty hourDistribution")
    func testEmptyHourDistribution() {
        let data = EchoData.empty
        #expect(data.hourDistribution.isEmpty)
    }

    @Test("EchoData.empty has zero syncCount")
    func testEmptySyncCount() {
        let data = EchoData.empty
        #expect(data.syncCount == 0)
    }

    @Test("EchoData.empty has 30 nil last30DaysColors")
    func testEmptyLast30DaysColors() {
        let data = EchoData.empty
        #expect(data.last30DaysColors.count == 30)
        for color in data.last30DaysColors {
            #expect(color == nil)
        }
    }

    // MARK: - EchoData.mock()

    @Test("EchoData.mock has 7 weekColors")
    func testMockWeekColors() {
        let data = EchoData.mock()
        #expect(data.weekColors.count == 7)
    }

    @Test("EchoData.mock has some nil weekColors (rest days)")
    func testMockWeekColorsContainsNil() {
        let data = EchoData.mock()
        let nilCount = data.weekColors.filter { $0 == nil }.count
        #expect(nilCount > 0, "Mock should have some rest days")
    }

    @Test("EchoData.mock has dominantFeeling")
    func testMockDominantFeeling() {
        let data = EchoData.mock()
        #expect(data.dominantFeeling == .calm)
    }

    @Test("EchoData.mock has repeated songs")
    func testMockRepeatedSongs() {
        let data = EchoData.mock()
        #expect(data.repeatedSongs.count == 2)
        #expect(data.repeatedSongs[0].songName == "Strobe")
        #expect(data.repeatedSongs[1].songName == "Last Last")
    }

    @Test("EchoData.mock has silentDays > 0")
    func testMockSilentDays() {
        let data = EchoData.mock()
        #expect(data.silentDays == 12)
        #expect(data.silentDates.count == 12)
    }

    @Test("EchoData.mock has hourDistribution data")
    func testMockHourDistribution() {
        let data = EchoData.mock()
        #expect(!data.hourDistribution.isEmpty)
        // Peak hour should be 20 with count 12
        #expect(data.hourDistribution[20] == 12)
    }

    @Test("EchoData.mock has syncCount")
    func testMockSyncCount() {
        let data = EchoData.mock()
        #expect(data.syncCount == 7)
    }

    @Test("EchoData.mock has 30 last30DaysColors")
    func testMockLast30DaysColors() {
        let data = EchoData.mock()
        #expect(data.last30DaysColors.count == 30)
    }

    // MARK: - RepeatedSong

    @Test("RepeatedSong initializes correctly")
    func testRepeatedSongInit() {
        let id = UUID()
        let song = RepeatedSong(
            id: id,
            songName: "Strobe",
            artistName: "deadmau5",
            moodColorHex: "#5B8DEF",
            dates: ["Oca", "Mar", "Haz"],
            count: 3
        )

        #expect(song.id == id)
        #expect(song.songName == "Strobe")
        #expect(song.artistName == "deadmau5")
        #expect(song.moodColorHex == "#5B8DEF")
        #expect(song.dates.count == 3)
        #expect(song.count == 3)
    }

    @Test("RepeatedSong is Identifiable")
    func testRepeatedSongIdentifiable() {
        let a = RepeatedSong(id: UUID(), songName: "A", artistName: "A", moodColorHex: "#000", dates: [], count: 1)
        let b = RepeatedSong(id: UUID(), songName: "B", artistName: "B", moodColorHex: "#111", dates: [], count: 1)

        // They should have different ids
        #expect(a.id != b.id)
    }
}
