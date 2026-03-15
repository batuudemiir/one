//
//  ONETokens.swift
//  one
//
//  Design System - Core Tokens
//  Provides centralized color, spacing, and border radius values
//

import SwiftUI

/// Design tokens for the ONE app
/// Provides centralized color, spacing, and border radius values
enum ONETokens {
    
    // MARK: - Neutral Color Palette
    
    /// Lightest neutral - cream background (#F7F6F3)
    /// Purpose: Primary background color for the app, providing a warm, natural base
    /// Usage: Main screen backgrounds, card backgrounds, light surfaces
    static let oneCream = Color(hex: "#F7F6F3")
    
    /// Mid-light neutral - subtle backgrounds (#E5E3DD)
    /// Purpose: Secondary background for subtle elevation and layering
    /// Usage: Card backgrounds, elevated panels, secondary surfaces
    static let oneCreamMid = Color(hex: "#E5E3DD")
    
    /// Low-light neutral - muted backgrounds (#D8D6D0)
    /// Purpose: Tertiary background for additional depth and hierarchy
    /// Usage: Input fields, disabled states, subtle containers
    static let oneCreamLow = Color(hex: "#D8D6D0")
    
    /// Light-medium neutral - borders and dividers (#A8A6A0)
    /// Purpose: Visible borders and dividers
    /// Usage: Card borders, section dividers, input field borders
    static let oneStone = Color(hex: "#A8A6A0")
    
    /// Medium neutral - secondary text (#6B6965)
    /// Purpose: Secondary text that provides hierarchy with good readability
    /// Usage: Metadata, timestamps, secondary labels, helper text
    static let oneAsh = Color(hex: "#6B6965")
    
    /// Medium-dark neutral - tertiary text (#4A4845)
    /// Purpose: Tertiary text for less important information
    /// Usage: Placeholder text, disabled text, subtle labels
    static let oneCharcoal = Color(hex: "#4A4845")
    
    /// Dark neutral - primary text (#1A1A1B)
    /// Purpose: Primary text color for maximum readability and contrast
    /// Usage: Headings, body text, primary labels, important content
    static let oneInk = Color(hex: "#1A1A1B")
    
    /// Darkest neutral - deep backgrounds (#0D0D0E)
    /// Purpose: Deep background for mood gradients and dark surfaces
    /// Usage: Mood gradient base, dark mode backgrounds, deep shadows
    static let oneVoid = Color(hex: "#0D0D0E")
    
    // MARK: - Brand Accent

    /// ONE marka ana rengi (#E63946) — "Hisset, Keşfet, Paylaş"
    /// Purpose: CTA butonları, tab highlight, onboarding, splash, share kartları
    /// Usage: Primary CTA, active tab indicator, hero gradient starts
    static let oneBrand = Color(hex: "#E63946")

    /// Brand gradient light end (#FF6B6B)
    /// Purpose: Hero gradient, splash animasyon, onboarding CTA
    /// Usage: oneBrand → oneBrandLight gradient pair
    static let oneBrandLight = Color(hex: "#FF6B6B")

    // MARK: - Accent Colors

    /// Primary accent - links and interactive elements (#5B8DEF)
    /// Purpose: Primary interactive color for buttons, links, and active states
    /// Usage: Primary buttons, links, selected states, interactive elements
    static let oneBlue = Color(hex: "#5B8DEF")

    /// Success color - positive actions (#4CAF82)
    /// Purpose: Indicates success, completion, and positive actions
    /// Usage: Success messages, confirmation buttons, positive feedback
    static let oneGreen = Color(hex: "#4CAF82")

    /// Error/destructive color (#E84040)
    /// Purpose: Indicates errors, warnings, and destructive actions
    /// Usage: Error messages, delete buttons, warning indicators
    static let oneRed = Color(hex: "#E84040")
    
    // MARK: - Brand Colors
    
    /// Spotify brand green (#1DB954)
    /// Purpose: Spotify-specific UI elements and connection states
    /// Usage: Spotify connect button, authenticated status indicators
    static let spotifyGreen = Color(hex: "#1DB954")
    
    /// Apple Music brand red (#FA243C)
    /// Purpose: Apple Music-specific UI elements and connection states
    /// Usage: Apple Music connect button, authenticated status indicators
    static let appleMusicRed = Color(hex: "#FA243C")
    
    // MARK: - Mood Palette
    
    /// Mood: Energetic orange (#FF8C42)
    static let moodOrange = Color(hex: "#FF8C42")
    
    /// Mood: Bright/Light yellow (#F5C842)
    static let moodYellow = Color(hex: "#F5C842")
    
    /// Mood: Mysterious purple (#9B7FD4)
    static let moodPurple = Color(hex: "#9B7FD4")
    
    /// Mood: Empty/Void dark (#2C2C2C)
    static let moodDark = Color(hex: "#2C2C2C")
    
    /// Mood: Slate/Muted (#607D8B)
    static let moodSlate = Color(hex: "#607D8B")
    
    // MARK: - Extended Neutrals
    
    /// Light border/divider (#EEECEA)
    /// Purpose: Subtle borders, dividers, card outlines
    /// Usage: Card borders, section dividers, subtle outlines
    static let oneSilver = Color(hex: "#EEECEA")
    
    /// Mid-light neutral (#BFBDB5)
    /// Purpose: Placeholder text, disabled icons, subtle decorations
    /// Usage: Placeholder text, secondary icons, muted labels
    static let oneMist = Color(hex: "#BFBDB5")
    
    /// Near-black for dark surfaces (#111112)
    /// Purpose: Deep dark surfaces, camera backgrounds
    /// Usage: Camera view background, dark overlays, near-black surfaces
    static let oneShadow = Color(hex: "#111112")
    
    // MARK: - Additional Neutrals
    
    /// Paper white background (#FAFAF8)
    /// Purpose: Very light, warm paper-like background for share cards and read-only surfaces
    /// Usage: Story share cards, monthly poster backgrounds, echo detail backgrounds
    static let onePaper = Color(hex: "#FAFAF8")
    
    /// Ivory surface (#E8E6E0)
    /// Purpose: Clean/temiz mood color, soft surface for subtle backgrounds
    /// Usage: Temiz mood, share card fills, soft dividers, empty state backgrounds
    static let oneIvory = Color(hex: "#E8E6E0")
    
    /// Pebble - warm muted neutral (#CEC9BF)
    /// Purpose: Decorative lines, subtle strokes, muted placeholders
    /// Usage: Day cell decorations, faint borders, secondary placeholder elements
    static let onePebble = Color(hex: "#CEC9BF")
    
    /// Graphite - dark gray text (#333333)
    /// Purpose: Dark gray for secondary headings in dark contexts
    /// Usage: Dark text on light backgrounds when oneInk is too strong
    static let oneGraphite = Color(hex: "#333333")
    
    // MARK: - Additional Accent Colors
    
    /// Mood amber fallback (#C97840)
    /// Purpose: Warm amber fallback color for mood when no dominant color exists
    /// Usage: Monthly summary dominant color fallback
    static let moodAmber = Color(hex: "#C97840")

    /// Mood: Fresh lime green (#7CC874) — taze mood
    static let moodLime = Color(hex: "#7CC874")

    /// Mood: Open teal (#3BBFCF) — özgür mood
    static let moodTeal = Color(hex: "#3BBFCF")

    /// Mood: Nostalgic indigo (#5560B8) — nostaljik mood
    static let moodIndigo = Color(hex: "#5560B8")

    /// Mood: Sensitive rose (#E8829C) — hassas mood
    static let moodRose = Color(hex: "#E8829C")
    
    /// Spotify dark green (#0A7A30)
    /// Purpose: Darker green for Spotify gradient endpoints
    /// Usage: Spotify connect button gradient dark end
    static let spotifyDarkGreen = Color(hex: "#0A7A30")
    
    /// Accent orange light (#FF8C5A)
    /// Purpose: Warm orange for CTA gradients - light end
    /// Usage: Spotify connect button gradient, action button gradients
    static let accentOrangeLight = Color(hex: "#FF8C5A")
    
    /// Accent orange dark (#FF6B3D)
    /// Purpose: Warm orange for CTA gradients - dark end
    /// Usage: Spotify connect button gradient, action button gradients
    static let accentOrangeDark = Color(hex: "#FF6B3D")
    
    // MARK: - Spacing Scale
    
    /// Extra small spacing - 4pt (tight padding, small gaps)
    /// Typical use cases: Icon padding, tight list gaps, minimal spacing between related elements
    static let spacingXS: CGFloat = 4
    
    /// Small spacing - 8pt (compact layouts, list item gaps)
    /// Typical use cases: List item vertical spacing, compact card padding, small element gaps
    static let spacingSM: CGFloat = 8
    
    /// Medium spacing - 12pt (default padding, moderate gaps)
    /// Typical use cases: Default padding for most elements, moderate gaps between sections
    static let spacingMD: CGFloat = 12
    
    /// Large spacing - 16pt (comfortable padding, section gaps)
    /// Typical use cases: Comfortable padding for cards, section spacing, standard margins
    static let spacingLG: CGFloat = 16
    
    /// Extra large spacing - 22pt (generous padding)
    /// Typical use cases: Generous padding for important elements, comfortable breathing room
    static let spacingXL: CGFloat = 22
    
    /// 2XL spacing - 26pt (horizontal screen margins)
    /// Typical use cases: Standard horizontal screen margins, main content padding
    static let spacingXL2: CGFloat = 26
    
    /// 3XL spacing - 36pt (large section spacing)
    /// Typical use cases: Major section breaks, large gaps between content groups
    static let spacingXL3: CGFloat = 36
    
    /// 4XL spacing - 52pt (major section breaks)
    /// Typical use cases: Hero section spacing, major visual breaks, top/bottom screen padding
    static let spacingXL4: CGFloat = 52
    
    /// 5XL spacing - 72pt (hero spacing)
    /// Typical use cases: Hero section padding, splash screen spacing, dramatic visual breaks
    static let spacingXL5: CGFloat = 72
    
    // MARK: - Location Preference

    /// UserDefaults key for user's preferred city (used by event recommendations)
    static let cityPreferenceKey = "preferredCity"

    /// Default city shown before user sets a preference
    static let defaultCity = "İstanbul"

    /// Available cities for event recommendations
    static let availableCities = [
        "İstanbul", "Ankara", "İzmir", "Bursa", "Antalya",
        "Adana", "Gaziantep", "Konya", "Mersin", "Eskişehir",
        "Kayseri", "Samsun", "Diyarbakır", "Trabzon", "Kocaeli", "Sakarya"
    ]

    // MARK: - Border Radius Scale
    
    /// Tag radius - 6pt (small pills, tags)
    /// Used by: Tag components, small pills, compact badges
    static let radiusTag: CGFloat = 6
    
    /// Toggle radius - 10pt (toggle switches)
    /// Used by: ONEToggleStyle, switch components, small interactive elements
    static let radiusToggle: CGFloat = 10
    
    /// Cover radius - 12pt (album art, small cards)
    /// Used by: Album art, small media cards, compact content cards
    static let radiusCover: CGFloat = 12
    
    /// Card radius - 13pt (standard cards, buttons)
    /// Used by: Standard cards, buttons, most UI components, default rounded corners
    static let radiusCard: CGFloat = 13
    
    /// Large card radius - 16pt (prominent cards)
    /// Used by: Prominent cards, featured content, larger UI elements
    static let radiusCardLg: CGFloat = 16
    
    /// Friend card radius - 18pt (circle friend cards)
    /// Used by: Friend cards in CircleView, social feature cards, profile cards
    static let radiusFriend: CGFloat = 18
    
    /// Sheet radius - 20pt (modal sheets, panels)
    /// Used by: Modal sheets, bottom sheets, slide-up panels, overlays
    static let radiusSheet: CGFloat = 20
    
    /// Screen radius - 42pt (full screen corners)
    /// Used by: Full screen views, main content areas, large rounded containers
    static let radiusScreen: CGFloat = 42
}
