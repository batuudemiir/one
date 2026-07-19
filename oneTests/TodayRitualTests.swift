//
//  TodayRitualTests.swift
//  oneTests
//
//  Tests for the Bugün v2 ritual flow:
//  DraftEntry, RitualStep, TodayCoordinator, ONEMood+RitualExtensions,
//  ProgressDots, MoodIndicatorDots, ContextPill, FlowLayout.
//

import Testing
import SwiftUI
@testable import OneDailyBatuhan

// MARK: - DraftEntry Tests

struct DraftEntryTests {

    @Test("DraftEntry initialises with defaults")
    func testDefaultInit() {
        let draft = DraftEntry()
        #expect(draft.song == nil)
        #expect(draft.photoData == nil)
        #expect(draft.mood == nil)
        #expect(draft.feeling == "")
        // Sosyal katman retention'ı taşıyor (Solo D30 %0) — varsayılan açık.
        #expect(draft.shareToCircle == true)
    }

    @Test("DraftEntry can be mutated")
    func testMutation() {
        var draft = DraftEntry()
        let song = SongResult(
            id: UUID(),
            name: "Test Song",
            artist: "Test Artist",
            genre: "Pop",
            coverURL: nil,
            spotifyURL: nil,
            artworkURLString: nil
        )
        draft.song = song
        draft.mood = .sakin
        draft.feeling = "huzurlu"
        draft.shareToCircle = true

        #expect(draft.song?.name == "Test Song")
        #expect(draft.mood == .sakin)
        #expect(draft.feeling == "huzurlu")
        #expect(draft.shareToCircle == true)
    }
}

// MARK: - RitualStep Tests

struct RitualStepTests {

    @Test("RitualStep has exactly two cases")
    func testCaseCount() {
        #expect(RitualStep.allCases.count == 2)
    }

    @Test("RitualStep rawValues are sequential from 0 — mood first, song last")
    func testRawValues() {
        #expect(RitualStep.mood.rawValue == 0)
        #expect(RitualStep.song.rawValue == 1)
    }

    @Test("RitualStep can be initialised from rawValue")
    func testRawValueInit() {
        #expect(RitualStep(rawValue: 0) == .mood)
        #expect(RitualStep(rawValue: 1) == .song)
        #expect(RitualStep(rawValue: 2) == nil)
    }

    @Test("Son adımın sonrası yok — next() oradan commit()'e düşer")
    func testNextStep() {
        #expect(RitualStep(rawValue: RitualStep.mood.rawValue + 1) == .song)
        #expect(RitualStep(rawValue: RitualStep.song.rawValue + 1) == nil)
    }
}

// MARK: - ONEMood+RitualExtensions Tests

struct ONEMoodRitualExtensionsTests {

    @Test("All moods have non-empty subtitles")
    func testSubtitlesNonEmpty() {
        for mood in ONEMood.allCases {
            #expect(!mood.subtitle.isEmpty, "subtitle empty for \(mood.rawValue)")
        }
    }

    @Test("All moods have exactly 4 suggested feelings")
    func testSuggestedFeelingsCount() {
        for mood in ONEMood.allCases {
            #expect(mood.suggestedFeelings.count == 4, "\(mood.rawValue) does not have 4 suggestions")
        }
    }

    @Test("All moods have non-empty suggested feelings")
    func testSuggestedFeelingsNonEmpty() {
        for mood in ONEMood.allCases {
            for feeling in mood.suggestedFeelings {
                #expect(!feeling.isEmpty, "empty feeling for \(mood.rawValue)")
            }
        }
    }

    @Test("chipTextColor returns a colour for every mood")
    func testChipTextColorNonNil() {
        for mood in ONEMood.allCases {
            // Just accessing the property should not crash — we verify it produces a Color
            let color = mood.chipTextColor
            // Color has no Equatable conformance for generic assertion; check description is non-empty
            let desc = "\(color)"
            #expect(!desc.isEmpty)
        }
    }

    @Test("subtitle for .sakin contains 'sakin'")
    func testSakinSubtitle() {
        #expect(ONEMood.sakin.subtitle.contains("sakin"))
    }

    @Test("suggestedFeelings for .uzgun contains 'üzgün'")
    func testUzgunSuggestions() {
        #expect(ONEMood.uzgun.suggestedFeelings.contains("üzgün"))
    }
}

// MARK: - PillItem Tests

struct PillItemTests {

    @Test("PillItem.song label returns song name")
    func testSongLabel() {
        let song = SongResult(id: UUID(), name: "Darling", artist: "A", genre: "Pop", coverURL: nil, spotifyURL: nil, artworkURLString: nil)
        #expect(PillItem.song(song).label == "Darling")
    }

    @Test("PillItem.mood label returns mood label")
    func testMoodLabel() {
        #expect(PillItem.mood(.sakin).label == ONEMood.sakin.label)
    }

    @Test("PillItem.song has nil swatchColor")
    func testSongSwatchNil() {
        let song = SongResult(id: UUID(), name: "X", artist: "Y", genre: "Z", coverURL: nil, spotifyURL: nil, artworkURLString: nil)
        #expect(PillItem.song(song).swatchColor == nil)
    }

    @Test("PillItem.mood has non-nil swatchColor")
    func testMoodSwatchNonNil() {
        #expect(PillItem.mood(.atesli).swatchColor != nil)
    }

    @Test("PillItem targetStep maps correctly")
    func testTargetStep() {
        let song = SongResult(id: UUID(), name: "S", artist: "A", genre: "G", coverURL: nil, spotifyURL: nil, artworkURLString: nil)
        #expect(PillItem.song(song).targetStep    == .song)
        #expect(PillItem.mood(.derin).targetStep  == .mood)
    }
}

// MARK: - TodayCoordinator Tests

@MainActor
struct TodayCoordinatorTests {

    @Test("Coordinator starts at .mood step")
    func testInitialStep() {
        let coordinator = TodayCoordinator()
        #expect(coordinator.step == .mood)
    }

    @Test("back() from first step is a no-op")
    func testBackFromFirst() {
        let coordinator = TodayCoordinator()
        coordinator.back()
        #expect(coordinator.step == .mood)
    }

    @Test("jumpTo changes step")
    func testJumpTo() {
        let coordinator = TodayCoordinator()
        coordinator.jumpTo(.song)
        #expect(coordinator.step == .song)
    }

    @Test("draft defaults — shareToCircle varsayılan olarak AÇIK")
    func testDraftDefaults() {
        let coordinator = TodayCoordinator()
        #expect(coordinator.draft.song == nil)
        #expect(coordinator.draft.mood == nil)
        #expect(coordinator.draft.photoData == nil)
        #expect(coordinator.draft.feeling == "")
        // Sosyal katman retention'ı taşıyor — opt-in'e bağlı bırakılamaz.
        #expect(coordinator.draft.shareToCircle == true)
    }

    @Test("next() from .mood moves to .song (raw arithmetic)")
    func testNextFromMood() {
        let coordinator = TodayCoordinator()
        let nextRaw = RitualStep(rawValue: coordinator.step.rawValue + 1)
        #expect(nextRaw == .song)
    }

    @Test("back() from .song moves to .mood (raw)")
    func testBackFromSong() {
        let prevRaw = RitualStep(rawValue: RitualStep.song.rawValue - 1)
        #expect(prevRaw == .mood)
    }

    @Test("commit() vm olmadan çökmemeli")
    func testCommitWithoutVM() {
        let coordinator = TodayCoordinator()
        coordinator.commit()   // guard let vm else { return }
        #expect(coordinator.step == .mood)
    }
}

// MARK: - Backfill Mode Tests (Faz 3.5)

/// Telafi (geri tarihli) modun state makinesi. Buradaki asıl mesele bir
/// veri kaybı bug'ıydı: `cancelBackfill` state'i temizliyordu ama sunum
/// katmanına haber vermiyordu — sheet açık kalıp normal "bugün" ritüeline
/// dönüyor, akış tamamlanınca bugünün kaydını eziyordu.
struct BackfillModeTests {

    private var yesterday: Date {
        Calendar.current.date(byAdding: .day, value: -1, to: Date())!
    }

    @Test("Varsayılan mod telafi değil")
    func testDefaultIsNotBackfill() {
        let coordinator = TodayCoordinator()
        #expect(coordinator.backfillDate == nil)
        #expect(coordinator.isBackfill == false)
    }

    @Test("startBackfill modu açar ve draft'ı sıfırlar")
    func testStartBackfill() {
        let coordinator = TodayCoordinator()
        coordinator.draft.feeling = "eski"
        coordinator.step = .song

        coordinator.startBackfill(for: yesterday)

        #expect(coordinator.isBackfill == true)
        #expect(coordinator.backfillDate == yesterday)
        #expect(coordinator.draft.feeling == "")
        #expect(coordinator.step == .mood)
    }

    @Test("cancelBackfill onFinish'i tetikler — sheet'in kapanma sinyali")
    func testCancelFiresOnFinish() {
        let coordinator = TodayCoordinator()
        var finishCount = 0
        coordinator.onFinish = { finishCount += 1 }

        coordinator.startBackfill(for: yesterday)
        #expect(finishCount == 0)

        coordinator.cancelBackfill()
        #expect(finishCount == 1)
    }

    @Test("cancelBackfill telafi modunu tamamen temizler")
    func testCancelClearsMode() {
        let coordinator = TodayCoordinator()
        coordinator.startBackfill(for: yesterday)
        coordinator.draft.feeling = "yarım"

        coordinator.cancelBackfill()

        // Kritik: backfillDate nil olduğu için sonraki commit() normal
        // "bugün" dalına düşer. Sunum katmanı onFinish ile kapanmazsa
        // kullanıcı bugünün kaydını ezebilir — bu yüzden ikisi bir arada.
        #expect(coordinator.backfillDate == nil)
        #expect(coordinator.isBackfill == false)
        #expect(coordinator.draft.feeling == "")
        #expect(coordinator.step == .mood)
    }

    @Test("onFinish bağlı değilse cancelBackfill çökmemeli")
    func testCancelWithoutObserver() {
        let coordinator = TodayCoordinator()
        coordinator.startBackfill(for: yesterday)
        coordinator.cancelBackfill()
        #expect(coordinator.backfillDate == nil)
    }
}
