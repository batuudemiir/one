//
//  MoodBarStripLabelTests.swift
//  oneTests
//
//  Unit tests for `MoodBarStrip.combinedLabel` computed property.
//  Feature: ui-consistency-and-accessibility-sweep (Task 2.5)
//

import Testing
import Foundation
@testable import OneDailyBatuhan

/// **Validates: Requirements 13.1, 13.2, 13.3, 13.4, 13.5**
///
/// Exercises the VoiceOver `combinedLabel` that `MoodBarStrip` exposes to its
/// container. Verifies:
/// - Empty / all-zero distributions fall back to the localized empty-state label.
/// - A single mood renders a correctly-rounded percentage.
/// - Multiple moods are announced in descending proportion order.
/// - Duplicate hex entries are consolidated into a single percentage.
/// - Percentages round half-up at the 0.5 boundary.
struct MoodBarStripLabelTests {

    // MARK: - Hex constants (source of truth: `ONEMood.init?(hex:)`)

    private let hexAtesli = "#E84040" // label "ateş"
    private let hexSakin  = "#4CAF82" // label "huzur"
    private let hexDerin  = "#5B8DEF" // label "derin"

    // MARK: - Helpers

    /// Resolves the localized empty-state label once so each test compares against
    /// the runtime-resolved string rather than a hard-coded locale string.
    private var emptyLabel: String {
        NSLocalizedString("moodbarstrip.empty", comment: "")
    }

    /// Builds the expected combined label from a pre-formatted parts string
    /// (e.g. `"%100 ateş"`) using the same localized summary format the
    /// production code uses.
    private func expectedLabel(parts: String) -> String {
        String(
            format: NSLocalizedString("moodbarstrip.summary", comment: ""),
            parts
        )
    }

    // MARK: - Tests

    @Test("combinedLabel returns empty-state label when distribution is empty and filledDays is zero")
    func test_combinedLabel_emptyDistribution_returnsEmptyString() throws {
        let strip = MoodBarStrip(moodDistribution: [], filledDays: 0)

        #expect(strip.combinedLabel == emptyLabel,
                "Empty distribution with filledDays=0 should return the localized empty-state label")
    }

    @Test("combinedLabel renders correct percentage for a single mood")
    func test_combinedLabel_singleMood_returnsCorrectPercent() throws {
        // 10 of 10 filled days → 100% atesli ("ateş").
        let strip = MoodBarStrip(
            moodDistribution: [(color: hexAtesli, count: 10)],
            filledDays: 10
        )

        let expected = expectedLabel(parts: "%100 ateş")
        #expect(strip.combinedLabel == expected,
                "Single-mood label should announce the mood at its exact rounded percentage")
    }

    @Test("combinedLabel orders mood segments by descending percentage")
    func test_combinedLabel_multipleMoods_descendingOrder() throws {
        // Input is intentionally unsorted to verify the implementation sorts it.
        // Counts 2/3/5 of 10 filled days → 20% derin, 30% sakin, 50% atesli.
        let strip = MoodBarStrip(
            moodDistribution: [
                (color: hexDerin,  count: 2),
                (color: hexAtesli, count: 5),
                (color: hexSakin,  count: 3)
            ],
            filledDays: 10
        )

        let expected = expectedLabel(parts: "%50 ateş, %30 huzur, %20 derin")
        #expect(strip.combinedLabel == expected,
                "Segments should be announced in descending proportion order")
    }

    @Test("combinedLabel consolidates duplicated mood hexes into a single percentage")
    func test_combinedLabel_duplicatedMoodHexes_consolidatedSinglePercent() throws {
        // Same hex appears twice; consolidation should collapse to a single segment.
        // 3 + 3 of 10 → 30% + 30% → 60% ateş (one segment only).
        let strip = MoodBarStrip(
            moodDistribution: [
                (color: hexAtesli, count: 3),
                (color: hexAtesli, count: 3)
            ],
            filledDays: 10
        )

        let expected = expectedLabel(parts: "%60 ateş")
        #expect(strip.combinedLabel == expected,
                "Duplicated mood hexes should consolidate into one summed percentage")
    }

    @Test("combinedLabel returns empty-state label when every segment rounds to 0%")
    func test_combinedLabel_allZeroPercent_returnsEmptyLabel() throws {
        // Valid hexes but zero counts → every pct rounds to 0 → empty-state fallback.
        let strip = MoodBarStrip(
            moodDistribution: [
                (color: hexAtesli, count: 0),
                (color: hexSakin,  count: 0)
            ],
            filledDays: 10
        )

        #expect(strip.combinedLabel == emptyLabel,
                "If every segment rounds to 0% the label must fall back to the empty-state string")
    }

    @Test("combinedLabel rounds percentages half-up at the 0.5 boundary")
    func test_combinedLabel_rounding_halfUp() throws {
        // 1 / 200 = 0.5% → rounds up to 1%
        // 3 / 200 = 1.5% → rounds up to 2%
        // Descending order: 2% ateş, 1% huzur.
        let strip = MoodBarStrip(
            moodDistribution: [
                (color: hexSakin,  count: 1),
                (color: hexAtesli, count: 3)
            ],
            filledDays: 200
        )

        let expected = expectedLabel(parts: "%2 ateş, %1 huzur")
        #expect(strip.combinedLabel == expected,
                "0.5 and 1.5 percent values should round half-up to 1 and 2")
    }
}
