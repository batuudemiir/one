//
//  ProfilePalette.swift
//  one
//
//  Feature: ui-consistency-and-accessibility-sweep (Task 3.1)
//
//  Centralizes the 14 adaptive color helpers that previously lived inline
//  inside `ProfileDashboardView` as view-local computed properties.
//
//  Design reference:
//  - design.md Component 1 (ProfilePalette struct + EnvironmentKey)
//  - requirements.md Requirement 2 (consolidation + exact hex parity)
//
//  Light variants delegate to `ONETokens.*` members wherever exact hex
//  equality is preserved (Req 2.5). Dark variants mirror the pre-migration
//  `Color.white.opacity(…)` / `Color.black` / `Color.clear` literals 1:1
//  (Req 2.3) so the palette swap is visually neutral.
//

import SwiftUI

/// Adaptive color palette consumed by `ProfileDashboardView` and the future
/// decomposed section views (Phase 3). Each property returns a concrete
/// `Color` based on the `isDarkMode` input so that the adaptive resolution
/// is driven by `ProfileViewModel.isDarkMode` (the app's in-app dark-mode
/// toggle) rather than the iOS trait collection.
///
/// - Note: Light-variant `ONETokens.*` members are themselves adaptive
///   `UITraitCollection`-driven colors. When `isDarkMode == false` the
///   palette returns the token as-is, letting the system's light/dark
///   mapping remain intact. When `isDarkMode == true` the palette returns
///   the pre-migration dark-mode literal (e.g. `Color.black`,
///   `Color.white.opacity(...)`).
struct ProfilePalette {
    /// Mirrors `ProfileViewModel.isDarkMode`. Injected by the root view.
    let isDarkMode: Bool

    // MARK: - Neutrals

    /// Screen background — dark: `.black`, light: `ONETokens.oneCream`.
    var screenBG: Color {
        isDarkMode ? Color.black : ONETokens.oneCream
    }

    /// Card fill — dark: `white @ 7%`, light: `onePaper @ 55%`.
    var cardBG: Color {
        isDarkMode ? Color.white.opacity(0.07) : V3Tokens.surface.opacity(0.55)
    }

    /// Card border — dark: `.clear`, light: `ONETokens.oneSilver`.
    var cardBorder: Color {
        isDarkMode ? Color.clear : ONETokens.oneSilver
    }

    /// Stat row fill — dark: `white @ 7%`, light: `onePaper @ 75%`.
    var statRowBG: Color {
        isDarkMode ? Color.white.opacity(0.07) : V3Tokens.surface.opacity(0.75)
    }

    /// Stat row divider — dark: `white @ 12%`, light: `ONETokens.oneIvory`.
    var statDivider: Color {
        isDarkMode ? Color.white.opacity(0.12) : ONETokens.oneIvory
    }

    // MARK: - Text

    /// Primary text — dark: `.white`, light: `ONETokens.oneInk`.
    var primaryText: Color {
        isDarkMode ? Color.white : ONETokens.oneInk
    }

    /// Secondary text — dark: `white @ 45%`, light: `ONETokens.oneAsh`.
    var secondaryText: Color {
        isDarkMode ? Color.white.opacity(0.45) : ONETokens.oneAsh
    }

    /// Tertiary text — dark: `white @ 25%`, light: `ONETokens.oneStone`.
    var tertiaryText: Color {
        isDarkMode ? Color.white.opacity(0.25) : ONETokens.oneStone
    }

    /// Section header text — dark: `white @ 35%`, light: `ONETokens.oneCharcoal`.
    var sectionHeader: Color {
        isDarkMode ? Color.white.opacity(0.35) : ONETokens.oneCharcoal
    }

    /// Generic divider — dark: `white @ 8%`, light: `ONETokens.oneSilver`.
    var dividerColor: Color {
        isDarkMode ? Color.white.opacity(0.08) : ONETokens.oneSilver
    }

    // MARK: - Action

    /// Action bubble fill — dark: `white @ 10%`, light: `onePaper @ 80%`.
    var actionBubble: Color {
        isDarkMode ? Color.white.opacity(0.10) : V3Tokens.surface.opacity(0.8)
    }

    /// Action icon tint — dark: `white @ 65%`, light: `ONETokens.oneAsh`.
    var actionIcon: Color {
        isDarkMode ? Color.white.opacity(0.65) : ONETokens.oneAsh
    }

    /// Row icon tint — dark: `white @ 75%`, light: `ONETokens.oneInk`.
    var rowIcon: Color {
        isDarkMode ? Color.white.opacity(0.75) : ONETokens.oneInk
    }
}

// MARK: - Environment wiring

/// Internal key so consumers read the palette through the SwiftUI environment
/// chain: `@Environment(\.profilePalette) var palette`.
private struct ProfilePaletteKey: EnvironmentKey {
    static let defaultValue = ProfilePalette(isDarkMode: false)
}

extension EnvironmentValues {
    /// Palette injected by `ProfileDashboardView` at the root of its view tree.
    /// Default (unconfigured) value is the light-mode palette.
    var profilePalette: ProfilePalette {
        get { self[ProfilePaletteKey.self] }
        set { self[ProfilePaletteKey.self] = newValue }
    }
}
