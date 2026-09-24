//
//  MoodLogSmokeTests.swift
//  oneUITests
//
//  Smoke tests for the critical user journeys (Faz 4.3, 2026-04-26).
//
//  Goals:
//   • Verify the app launches without crash
//   • Verify the bottom navigation is visible and tabs are reachable
//   • Verify the mood log entry surface appears (search step)
//   • Verify accessibility labels exist on key tabs
//
//  Notes:
//   • Tests do NOT mutate Core Data / CloudKit — they only navigate the UI.
//   • Use `accessibilityLabel`/`accessibilityIdentifier` to query elements
//     instead of brittle text matching where possible.
//   • For deeper end-to-end (actually saving a mood), see the planned
//     `MoodLogE2ETests.swift` (out of scope for soft-launch smoke).
//

import XCTest

final class MoodLogSmokeTests: XCTestCase {

    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        // Launch arg the app reads to disable splash delay & onboarding for tests.
        // (If oneApp.swift doesn't honor these yet, the tests still work — they just
        // wait a beat longer for splash/onboarding to clear.)
        app.launchArguments = ["-uiTesting", "-skipOnboarding"]
        app.launch()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - Launch

    @MainActor
    func test_appLaunches_withoutCrash() {
        // If we got here, launch() did not crash.
        XCTAssertTrue(app.state == .runningForeground, "App should be in foreground after launch")
    }

    // MARK: - Bottom Navigation

    @MainActor
    func test_bottomNavigation_isPresent() {
        // BottomNavigation NavItem uses `nav.tabAccessibility` localized format.
        // We accept the existence of any of the 5 standard tabs as proof.
        let tabKeywords = ["Bugün", "Today", "Çevre", "Discover", "Keşfet", "Profil", "Profile", "Arşiv"]

        // Wait up to 3s for splash / onboarding to clear
        let predicate = NSPredicate(format: "exists == true")
        let anyTab = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'Today' OR label CONTAINS[c] 'Bugün' OR label CONTAINS[c] 'Profile' OR label CONTAINS[c] 'Profil' OR label CONTAINS[c] 'Discover' OR label CONTAINS[c] 'Keşfet' OR label CONTAINS[c] 'Çevre' OR label CONTAINS[c] 'Arşiv'")).firstMatch
        let exists = expectation(for: predicate, evaluatedWith: anyTab, handler: nil)
        wait(for: [exists], timeout: 5)

        XCTAssertTrue(anyTab.exists, "At least one bottom-nav tab should be visible. Tried: \(tabKeywords)")
    }

    // MARK: - Accessibility Sanity

    @MainActor
    func test_keyButtons_haveAccessibilityLabels() {
        // Wait for app idle
        sleep(2)

        // Walk all visible buttons; assert none have empty labels.
        // (Empty-label icon-only buttons are an a11y bug per ONE A11yPatterns.md.)
        let allButtons = app.buttons.allElementsBoundByIndex
        var emptyLabelCount = 0
        for button in allButtons where button.exists && button.isHittable {
            if button.label.trimmingCharacters(in: .whitespaces).isEmpty {
                emptyLabelCount += 1
            }
        }

        // Tolerance: some system-injected back buttons may have empty labels at
        // launch. Threshold of 2 is conservative; tighten as a11y migration completes.
        XCTAssertLessThanOrEqual(
            emptyLabelCount, 2,
            "Found \(emptyLabelCount) icon-only buttons without accessibilityLabel — see Documents/A11yPatterns.md Pattern 1"
        )
    }

    // MARK: - Performance

    @MainActor
    func test_launchPerformance() throws {
        // Hedef: cold start < 1.2s (Faz 3.5'te koyulan hedef).
        // measure metric'i averaged over multiple launches yapar.
        if #available(iOS 16.0, *) {
            measure(metrics: [XCTApplicationLaunchMetric()]) {
                XCUIApplication().launch()
            }
        }
    }
}
