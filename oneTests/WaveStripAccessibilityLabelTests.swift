//
//  WaveStripAccessibilityLabelTests.swift
//  oneTests
//
//  Feature: ui-consistency-and-accessibility-sweep (Task 2.3)
//  Validates the WaveStrip VoiceOver label helper contract.
//

import Testing
import Foundation
@testable import OneDailyBatuhan

/// **Validates: Requirements 12.1, 12.4**
///
/// Unit tests for `WaveStrip.accessibilityLabel(for:mood:)` — the helper that
/// produces the Turkish VoiceOver string for each calendar-day bar in the strip.
///
/// Format contract:
/// - Filled day  → `"<day>. gün — <mood.label>"`
/// - Empty day   → `"<day>. gün — kayıt yok"`
/// - `nil` date  → day component defaults to `0`
struct WaveStripAccessibilityLabelTests {

    // MARK: - Helpers

    /// Builds a deterministic `Date` for March 15, 2026 using the current calendar.
    /// The year is irrelevant for the label (only the day component is read),
    /// but we fix it so the test is fully reproducible.
    private func march15() -> Date {
        var components = DateComponents()
        components.year = 2026
        components.month = 3
        components.day = 15
        // Neutralize time-of-day to avoid any edge-case wrap during component extraction.
        components.hour = 12
        components.minute = 0
        components.second = 0
        guard let date = Calendar.current.date(from: components) else {
            Issue.record("Failed to construct March 15, 2026 date")
            return Date()
        }
        return date
    }

    // MARK: - Tests

    @Test("Filled day returns '<day>. gün — <mood.label>'")
    func test_label_forFilledDay_returnsDayNumberAndMoodLabel() throws {
        let date = march15()
        let label = WaveStrip.accessibilityLabel(for: date, mood: .sakin)

        // Sanity-check: .sakin's user-facing label is the one we expect in Turkish.
        #expect(ONEMood.sakin.label == "huzur",
                "ONEMood.sakin.label changed; update this test if the design copy moved.")

        #expect(label == "15. gün — huzur")
    }

    @Test("Empty day (mood == nil) returns '<day>. gün — kayıt yok'")
    func test_label_forEmptyDay_returnsNoEntryFormat() throws {
        let date = march15()
        let label = WaveStrip.accessibilityLabel(for: date, mood: nil)

        #expect(label == "15. gün — kayıt yok")
    }

    @Test("Nil date falls back to day '0' (default behavior per Req 12.1)")
    func test_label_forNilDate_returnsZeroDay() throws {
        // Empty-slot case: no date, no mood — the strip still needs a stable label.
        let emptyLabel = WaveStrip.accessibilityLabel(for: nil, mood: nil)
        #expect(emptyLabel == "0. gün — kayıt yok")

        // Defensive: even if a mood were somehow supplied without a date,
        // the day component must still default to 0.
        let moodOnlyLabel = WaveStrip.accessibilityLabel(for: nil, mood: .sakin)
        #expect(moodOnlyLabel == "0. gün — huzur")
    }
}
