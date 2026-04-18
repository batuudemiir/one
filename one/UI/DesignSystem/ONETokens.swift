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
    
    // MARK: - Neutral Color Palette (Adaptive Light/Dark)

    /// Lightest neutral - cream background (Light: #F7F6F3 / Dark: #1A1A1B)
    static let oneCream = Color(UIColor { tc in
        tc.userInterfaceStyle == .dark ? UIColor(hex: "#1A1A1B") : UIColor(hex: "#F7F6F3")
    })

    /// Mid-light neutral - subtle backgrounds (Light: #E5E3DD / Dark: #2C2C2E)
    static let oneCreamMid = Color(UIColor { tc in
        tc.userInterfaceStyle == .dark ? UIColor(hex: "#2C2C2E") : UIColor(hex: "#E5E3DD")
    })

    /// Low-light neutral - muted backgrounds (Light: #D8D6D0 / Dark: #3A3A3C)
    static let oneCreamLow = Color(UIColor { tc in
        tc.userInterfaceStyle == .dark ? UIColor(hex: "#3A3A3C") : UIColor(hex: "#D8D6D0")
    })

    /// Light-medium neutral - borders and dividers (Light: #A8A6A0 / Dark: #6B6965)
    static let oneStone = Color(UIColor { tc in
        tc.userInterfaceStyle == .dark ? UIColor(hex: "#6B6965") : UIColor(hex: "#A8A6A0")
    })

    /// Medium neutral - secondary text (Light: #6B6965 / Dark: #A8A6A0)
    static let oneAsh = Color(UIColor { tc in
        tc.userInterfaceStyle == .dark ? UIColor(hex: "#A8A6A0") : UIColor(hex: "#6B6965")
    })

    /// Medium-dark neutral - tertiary text (Light: #4A4845 / Dark: #BFBDB5)
    static let oneCharcoal = Color(UIColor { tc in
        tc.userInterfaceStyle == .dark ? UIColor(hex: "#BFBDB5") : UIColor(hex: "#4A4845")
    })

    /// Dark neutral - primary text (Light: #1A1A1B / Dark: #F7F6F3)
    static let oneInk = Color(UIColor { tc in
        tc.userInterfaceStyle == .dark ? UIColor(hex: "#F7F6F3") : UIColor(hex: "#1A1A1B")
    })

    /// Darkest neutral - deep backgrounds (Light: #0D0D0E / Dark: #F7F6F3)
    static let oneVoid = Color(UIColor { tc in
        tc.userInterfaceStyle == .dark ? UIColor(hex: "#F7F6F3") : UIColor(hex: "#0D0D0E")
    })
    
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

    // MARK: - Pastel Mood Palette (Gen Z)

    /// Pastel coral — ateş (atesli) #FFB5A7
    static let moodPastelRed      = Color(hex: "#FFB5A7")
    /// Pastel peach — enerji (enerjik) #FFCBA4
    static let moodPastelOrange   = Color(hex: "#FFCBA4")
    /// Pastel yellow — ışık (isikli) #FFF0B3
    static let moodPastelYellow   = Color(hex: "#FFF0B3")
    /// Pastel mint — taze (taze) #B8F0D4
    static let moodPastelMint     = Color(hex: "#B8F0D4")
    /// Pastel sage — huzur (sakin) #A8D5B5
    static let moodPastelGreen    = Color(hex: "#A8D5B5")
    /// Pastel sky — özgür (ozgur) #A8D4F5
    static let moodPastelBlue     = Color(hex: "#A8D4F5")
    /// Pastel periwinkle — derin (derin) #B8C5F0
    static let moodPastelIndigo   = Color(hex: "#B8C5F0")
    /// Pastel lavender — özlem (nostaljik) #C5B8F0
    static let moodPastelLavender = Color(hex: "#C5B8F0")
    /// Pastel violet — büyü (gizemli) #D4B8F0
    static let moodPastelViolet   = Color(hex: "#D4B8F0")
    /// Pastel rose — kırılgan (hassas) #FFB8CC
    static let moodPastelRose     = Color(hex: "#FFB8CC")
    /// Pastel slate — boşluk (bos) #CDD5E8
    static let moodPastelSlate    = Color(hex: "#CDD5E8")
    /// Pastel cream — sessiz (temiz) #F0EDE8
    static let moodPastelCream    = Color(hex: "#F0EDE8")
    
    /// Mood: Bright/Light yellow (#F5C842)
    static let moodYellow = Color(hex: "#F5C842")
    
    /// Mood: Mysterious purple (#9B7FD4)
    static let moodPurple = Color(hex: "#9B7FD4")
    
    /// Mood: Empty/Void dark (#2C2C2C)
    static let moodDark = Color(hex: "#2C2C2C")
    
    /// Mood: Slate/Muted (#607D8B)
    static let moodSlate = Color(hex: "#607D8B")
    
    // MARK: - Extended Neutrals (Adaptive)

    /// Light border/divider (Light: #EEECEA / Dark: #2A2A2C)
    static let oneSilver = Color(UIColor { tc in
        tc.userInterfaceStyle == .dark ? UIColor(hex: "#2A2A2C") : UIColor(hex: "#EEECEA")
    })

    /// Mid-light neutral (Light: #BFBDB5 / Dark: #5A5856)
    static let oneMist = Color(UIColor { tc in
        tc.userInterfaceStyle == .dark ? UIColor(hex: "#5A5856") : UIColor(hex: "#BFBDB5")
    })

    /// Near-black for dark surfaces (Light: #111112 / Dark: #F5F5F3)
    static let oneShadow = Color(UIColor { tc in
        tc.userInterfaceStyle == .dark ? UIColor(hex: "#F5F5F3") : UIColor(hex: "#111112")
    })

    /// Cinematic warm dark — sabit koyu yüzey, mood/dark kartlar için (#1C1714)
    /// Always dark regardless of color scheme — intentional for cinematic card backgrounds
    static let oneCinematicDark = Color(hex: "#1C1714")
    
    // MARK: - Additional Neutrals
    
    /// Paper white background (Light: #FAFAF8 / Dark: #1C1C1E)
    static let onePaper = Color(UIColor { tc in
        tc.userInterfaceStyle == .dark ? UIColor(hex: "#1C1C1E") : UIColor(hex: "#FAFAF8")
    })

    /// Ivory surface (Light: #E8E6E0 / Dark: #2E2E30)
    static let oneIvory = Color(UIColor { tc in
        tc.userInterfaceStyle == .dark ? UIColor(hex: "#2E2E30") : UIColor(hex: "#E8E6E0")
    })

    /// Pebble - warm muted neutral (Light: #CEC9BF / Dark: #48463F)
    static let onePebble = Color(UIColor { tc in
        tc.userInterfaceStyle == .dark ? UIColor(hex: "#48463F") : UIColor(hex: "#CEC9BF")
    })

    /// Graphite - dark gray text (Light: #333333 / Dark: #CCCCCC)
    static let oneGraphite = Color(UIColor { tc in
        tc.userInterfaceStyle == .dark ? UIColor(hex: "#CCCCCC") : UIColor(hex: "#333333")
    })
    
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
    
    // MARK: - Accessibility

    /// Minimum touch target size per Apple HIG (44×44pt)
    static let minTouchTarget: CGFloat = 44

    // MARK: - Location Preference

    /// UserDefaults key for user's preferred city (used by event recommendations)
    static let cityPreferenceKey = "preferredCity"

    /// UserDefaults key for user's preferred in-app language
    static let languagePreferenceKey = "appLanguage"

    // MARK: - App Store & Web

    /// App Store numeric ID (used for review requests and store link)
    static let appStoreID = "6759794739"

    /// Direct App Store link
    static let appStoreURL = "https://apps.apple.com/us/app/one/id6759794739"

    /// Public website
    static let websiteURL = "https://one.forvibe.app"

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
