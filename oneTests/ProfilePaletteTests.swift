//
//  ProfilePaletteTests.swift
//  oneTests
//
//  Feature: ui-consistency-and-accessibility-sweep (Task 3.1)
//
//  Validates `ProfilePalette` struct parity with the 14 pre-migration
//  dark-mode color helpers that used to live inline inside
//  `ProfileDashboardView`. Each property is asserted in BOTH modes so the
//  future migration (Task 3.2) is visually neutral.
//
//  Strategy:
//  - Light-mode palette values delegate to `ONETokens.*` adaptive tokens
//    (Req 2.5). We resolve both the palette color and the expected token
//    against an explicit `.light` trait collection so comparisons are
//    deterministic regardless of the host simulator's interface style.
//  - Dark-mode palette values are direct `Color.white.opacity(...)` /
//    `Color.black` / `Color.clear` literals (Req 2.3). We resolve both sides
//    against `.unspecified` — their value is trait-independent so either
//    side yields the same RGBA.
//

import Testing
import SwiftUI
import UIKit
@testable import OneDailyBatuhan

/// **Validates: Requirements 2.2, 2.3, 2.4, 2.5**
///
/// Covers the full 13-property × 2-mode matrix (26 assertions) plus the
/// three named canonical cases called out in design.md T1:
/// (The spec header references "14 properties" but the ProfileDashboardView
/// source has exactly 13 dark-mode helpers — `profileColor` is driven by
/// `vm.selectedAvatarColor` and intentionally lives outside the palette.)
/// - `test_screenBG_lightMode_matchesPreMigrationHex`
/// - `test_screenBG_darkMode_matchesBlack`
/// - `test_cardBG_darkMode_appliesCorrectOpacity`
struct ProfilePaletteTests {

    // MARK: - Tolerance

    /// Tolerance per 8-bit RGBA channel (0…255 space).
    /// 1 is enough to absorb sRGB round-trip rounding from `UIColor(Color)`.
    private let tolerance: Int = 1

    // MARK: - RGBA helpers

    /// Resolved RGBA in `0…255` integer space.
    private struct RGBA: Equatable {
        let r: Int
        let g: Int
        let b: Int
        let a: Int
    }

    /// Extract RGBA from a SwiftUI `Color`, resolved against a specific
    /// `UITraitCollection` so that trait-adaptive tokens (ONETokens.*)
    /// produce their light or dark hex variant deterministically.
    private func rgba(_ color: Color, trait: UITraitCollection) -> RGBA {
        let uiColor = UIColor(color).resolvedColor(with: trait)
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        // `.getRed` converts any underlying color space to sRGB extended.
        _ = uiColor.getRed(&r, green: &g, blue: &b, alpha: &a)
        return RGBA(
            r: Int((r * 255).rounded()),
            g: Int((g * 255).rounded()),
            b: Int((b * 255).rounded()),
            a: Int((a * 255).rounded())
        )
    }

    private let lightTrait = UITraitCollection(userInterfaceStyle: .light)

    /// Assert two Colors are equal channel-wise within `tolerance` when
    /// resolved against the same trait collection.
    private func expectEqualColor(
        _ actual: Color,
        _ expected: Color,
        trait: UITraitCollection,
        label: String,
        sourceLocation: SourceLocation = #_sourceLocation
    ) {
        let got = rgba(actual, trait: trait)
        let want = rgba(expected, trait: trait)
        #expect(
            abs(got.r - want.r) <= tolerance,
            "[\(label)] red mismatch: got \(got.r) want \(want.r)",
            sourceLocation: sourceLocation
        )
        #expect(
            abs(got.g - want.g) <= tolerance,
            "[\(label)] green mismatch: got \(got.g) want \(want.g)",
            sourceLocation: sourceLocation
        )
        #expect(
            abs(got.b - want.b) <= tolerance,
            "[\(label)] blue mismatch: got \(got.b) want \(want.b)",
            sourceLocation: sourceLocation
        )
        #expect(
            abs(got.a - want.a) <= tolerance,
            "[\(label)] alpha mismatch: got \(got.a) want \(want.a)",
            sourceLocation: sourceLocation
        )
    }

    // MARK: - Named canonical tests (design.md T1)

    @Test("screenBG in light mode matches the pre-migration oneCream hex (#F7F6F3)")
    func test_screenBG_lightMode_matchesPreMigrationHex() throws {
        let palette = ProfilePalette(isDarkMode: false)
        // Pre-migration literal: `vm.isDarkMode ? .black : ONETokens.oneCream`.
        expectEqualColor(
            palette.screenBG,
            ONETokens.oneCream,
            trait: lightTrait,
            label: "screenBG.light"
        )
        // And the resolved hex in light mode is #F7F6F3.
        let resolved = rgba(palette.screenBG, trait: lightTrait)
        #expect(resolved.r == 0xF7)
        #expect(resolved.g == 0xF6)
        #expect(resolved.b == 0xF3)
        #expect(resolved.a == 0xFF)
    }

    @Test("screenBG in dark mode equals Color.black")
    func test_screenBG_darkMode_matchesBlack() throws {
        let palette = ProfilePalette(isDarkMode: true)
        expectEqualColor(
            palette.screenBG,
            Color.black,
            trait: lightTrait,
            label: "screenBG.dark"
        )
    }

    @Test("cardBG in dark mode applies white.opacity(0.07)")
    func test_cardBG_darkMode_appliesCorrectOpacity() throws {
        let palette = ProfilePalette(isDarkMode: true)
        expectEqualColor(
            palette.cardBG,
            Color.white.opacity(0.07),
            trait: lightTrait,
            label: "cardBG.dark"
        )
        // And verify the alpha channel literal resolves to ~18 in 0…255 space
        // (0.07 * 255 ≈ 17.85 → 18 with half-up rounding).
        let resolved = rgba(palette.cardBG, trait: lightTrait)
        #expect(abs(resolved.a - 18) <= tolerance, "cardBG dark alpha ≈ 18, got \(resolved.a)")
        #expect(resolved.r >= 254)
        #expect(resolved.g >= 254)
        #expect(resolved.b >= 254)
    }

    // MARK: - Full 14 × 2 parity matrix

    @Test("13 palette properties — light mode parity with ONETokens references")
    func test_allProperties_lightMode_matchPreMigrationHelpers() throws {
        let palette = ProfilePalette(isDarkMode: false)

        // Each case mirrors the pre-migration helper from ProfileDashboardView.swift
        // lines 72–84 (the light branch of the `vm.isDarkMode ? … : …` ternary).
        let cases: [(name: String, actual: Color, expected: Color)] = [
            ("screenBG",      palette.screenBG,      ONETokens.oneCream),
            ("cardBG",        palette.cardBG,        ONETokens.onePaper.opacity(0.55)),
            ("cardBorder",    palette.cardBorder,    ONETokens.oneSilver),
            ("statRowBG",     palette.statRowBG,     ONETokens.onePaper.opacity(0.75)),
            ("statDivider",   palette.statDivider,   ONETokens.oneIvory),
            ("primaryText",   palette.primaryText,   ONETokens.oneInk),
            ("secondaryText", palette.secondaryText, ONETokens.oneAsh),
            ("tertiaryText",  palette.tertiaryText,  ONETokens.oneStone),
            ("sectionHeader", palette.sectionHeader, ONETokens.oneCharcoal),
            ("dividerColor",  palette.dividerColor,  ONETokens.oneSilver),
            ("actionBubble",  palette.actionBubble,  ONETokens.onePaper.opacity(0.8)),
            ("actionIcon",    palette.actionIcon,    ONETokens.oneAsh),
            ("rowIcon",       palette.rowIcon,       ONETokens.oneInk)
        ]
        #expect(cases.count == 13, "Expected 13 delegated light-mode properties")

        for item in cases {
            expectEqualColor(
                item.actual,
                item.expected,
                trait: lightTrait,
                label: "\(item.name).light"
            )
        }
    }

    @Test("13 palette properties — dark mode parity with pre-migration literals")
    func test_allProperties_darkMode_matchPreMigrationHelpers() throws {
        let palette = ProfilePalette(isDarkMode: true)

        // Each case mirrors the dark branch of the pre-migration helpers
        // (ProfileDashboardView.swift lines 72–84).
        let cases: [(name: String, actual: Color, expected: Color)] = [
            ("screenBG",      palette.screenBG,      Color.black),
            ("cardBG",        palette.cardBG,        Color.white.opacity(0.07)),
            ("cardBorder",   palette.cardBorder,    Color.clear),
            ("statRowBG",     palette.statRowBG,     Color.white.opacity(0.07)),
            ("statDivider",   palette.statDivider,   Color.white.opacity(0.12)),
            ("primaryText",   palette.primaryText,   Color.white),
            ("secondaryText", palette.secondaryText, Color.white.opacity(0.45)),
            ("tertiaryText",  palette.tertiaryText,  Color.white.opacity(0.25)),
            ("sectionHeader", palette.sectionHeader, Color.white.opacity(0.35)),
            ("dividerColor",  palette.dividerColor,  Color.white.opacity(0.08)),
            ("actionBubble",  palette.actionBubble,  Color.white.opacity(0.10)),
            ("actionIcon",    palette.actionIcon,    Color.white.opacity(0.65)),
            ("rowIcon",       palette.rowIcon,       Color.white.opacity(0.75))
        ]
        #expect(cases.count == 13, "Expected 13 dark-mode literal properties")

        for item in cases {
            expectEqualColor(
                item.actual,
                item.expected,
                trait: lightTrait,
                label: "\(item.name).dark"
            )
        }
    }

    // MARK: - EnvironmentKey default

    @Test("Environment default resolves to the light-mode palette")
    func test_environmentDefaultValue_isLightModePalette() throws {
        // The SwiftUI `@Environment(\.profilePalette)` default must be the
        // light-mode palette so an unconfigured host renders in the
        // pre-migration light palette (Req 2.4).
        let defaultPalette = EnvironmentValues().profilePalette
        expectEqualColor(
            defaultPalette.screenBG,
            ONETokens.oneCream,
            trait: lightTrait,
            label: "environmentDefault.screenBG"
        )
        expectEqualColor(
            defaultPalette.primaryText,
            ONETokens.oneInk,
            trait: lightTrait,
            label: "environmentDefault.primaryText"
        )
    }
}
