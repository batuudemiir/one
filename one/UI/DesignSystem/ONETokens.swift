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

    /// Mood: Enerjik vivid orange (#FB6F3B)
    static let moodOrange = Color(hex: "#FB6F3B")

    // MARK: - Pastel Mood Palette

    /// Pastel rose — tutkulu (atesli)
    static let moodPastelRed      = Color(hex: "#FFCDD2")
    /// Pastel peach — enerjik
    static let moodPastelOrange   = Color(hex: "#FFE0B2")
    /// Pastel yellow — mutlu (isikli)
    static let moodPastelYellow   = Color(hex: "#FFF9C4")
    /// Pastel green — doğal (taze)
    static let moodPastelMint     = Color(hex: "#C8E6C9")
    /// Pastel teal — huzurlu (sakin)
    static let moodPastelGreen    = Color(hex: "#B2DFDB")
    /// Pastel blue — sakin (ozgur)
    static let moodPastelBlue     = Color(hex: "#BBDEFB")
    /// Pastel indigo — stabil (derin)
    static let moodPastelIndigo   = Color(hex: "#C5CAE9")
    /// Pastel blue-grey — üzgün (uzgun)
    static let moodPastelLavender = Color(hex: "#CFD8DC")
    /// Pastel violet — (legacy)
    static let moodPastelViolet   = Color(hex: "#D4B8F0")
    /// Pastel pink — heyecanlı (nostaljik)
    static let moodPastelRose     = Color(hex: "#FCE4EC")
    /// Pastel grey — yorgun
    static let moodPastelSlate    = Color(hex: "#ECEFF1")
    /// Pastel cream — (legacy)
    static let moodPastelCream    = Color(hex: "#F0EDE8")

    /// Mood: Mutlu sunny yellow (#FDD835)
    static let moodYellow = Color(hex: "#FDD835")
    
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

    /// Mood: Doğal natural green (#4CAF50) — taze mood
    static let moodLime = Color(hex: "#4CAF50")

    /// Mood: Sakin sky blue (#42A5F5) — ozgur mood
    static let moodTeal = Color(hex: "#42A5F5")

    /// Mood: Üzgün muted blue-grey (#78909C) — uzgun mood
    static let moodIndigo = Color(hex: "#78909C")

    /// Mood: Sensitive rose (#E8829C) — legacy
    static let moodRose = Color(hex: "#E8829C")

    /// Mood: Heyecanlı hot pink (#EC407A) — nostaljik mood
    static let moodExcited = Color(hex: "#EC407A")

    /// Mood: Stresli burning orange (#FF7043) — stresli mood
    static let moodStress = Color(hex: "#FF7043")

    /// Mood: Sinirli dark crimson (#B71C1C) — sinirli mood
    static let moodAngry = Color(hex: "#B71C1C")

    /// Mood: Tutkulu passion red (#E53935) — atesli mood
    static let moodTutkulu = Color(hex: "#E53935")

    /// Mood: Huzurlu peaceful teal (#26A69A) — sakin mood
    static let moodHuzurlu = Color(hex: "#26A69A")

    /// Mood: Stabil deep indigo (#3F51B5) — derin mood
    static let moodStabil = Color(hex: "#3F51B5")

    /// Pastel: Stresli (#FFCCBC) — stresli pastel
    static let moodPastelStress = Color(hex: "#FFCCBC")

    /// Pastel: Sinirli (#EF9A9A) — sinirli pastel
    static let moodPastelAngry = Color(hex: "#EF9A9A")

    /// Activity teal (#2D7C68) — etkinlik/aktivite kategorisi
    /// Purpose: Event category color for activity-type recommendations
    /// Usage: MoodEventsSheet activity category badges
    static let categoryActivity = Color(hex: "#2D7C68")

    /// System-style red (#FC3C44) — Apple-paralel sistem kırmızısı
    /// Purpose: Onboarding accents, alert-toned UI when oneBrand is occupied
    /// Usage: Onboarding info pills, secondary alerts
    static let oneSystemRed = Color(hex: "#FC3C44")
    
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

    // MARK: - Monthly Summary Palette

    /// Summary gradient start (#E65A1A) — MonthlySummary mood map hero LinearGradient başlangıç
    /// Purpose: CoverCard ay hero LinearGradient start
    /// Usage: `summaryGradientStart` → `summaryGradientEnd` gradient pair (MonthlySummary CoverCard)
    static let summaryGradientStart = Color(hex: "#E65A1A")

    /// Summary gradient end (#F29919) — MonthlySummary mood map hero LinearGradient bitişi
    /// Purpose: CoverCard ay hero LinearGradient end
    /// Usage: `summaryGradientStart` → `summaryGradientEnd` gradient pair (MonthlySummary CoverCard)
    static let summaryGradientEnd = Color(hex: "#F29919")

    /// Summary fire spark (#D8401A) — CoverCard arka plan RadialGradient sol-üst kıvılcım
    /// Purpose: MonthlySummary CoverCard background top-left radial accent
    /// Usage: CoverCard RadialGradient top-left stop
    static let summaryFireSpark = Color(hex: "#D8401A")

    /// Summary amber glow (#E69919) — CoverCard orta radial + TopTracks amber vurgusu
    /// Purpose: MonthlySummary CoverCard mid-radial warmth + TopTracks amber accent
    /// Usage: CoverCard RadialGradient mid stop, TopTracks highlight
    static let summaryAmberGlow = Color(hex: "#E69919")

    /// Summary sunshine (#F2CC26) — CoverCard alt radial parlaklık
    /// Purpose: MonthlySummary CoverCard bottom radial highlight
    /// Usage: CoverCard RadialGradient bottom stop
    static let summarySunshine = Color(hex: "#F2CC26")

    /// Summary highlight amber (#F2A626) — CoverCard istatistik kartı vurgusu
    /// Purpose: MonthlySummary stat card accent highlight
    /// Usage: CoverCard stat card highlight color
    static let summaryHighlightAmber = Color(hex: "#F2A626")

    /// Summary fire gradient start (#D85A1A) — MonthlySummary ViewModel mood gradient pair #1 başlangıç
    /// Purpose: MonthlySummary ViewModel mood gradient pair #1 start
    /// Usage: `summaryFireStart` → `summaryFireEnd` gradient pair (MonthlySummaryViewModel)
    static let summaryFireStart = Color(hex: "#D85A1A")

    /// Summary fire gradient end (#E6A61A) — MonthlySummary ViewModel mood gradient pair #1 bitişi
    /// Purpose: MonthlySummary ViewModel mood gradient pair #1 end
    /// Usage: `summaryFireStart` → `summaryFireEnd` gradient pair (MonthlySummaryViewModel)
    static let summaryFireEnd = Color(hex: "#E6A61A")

    /// Summary ember amber (#D8801A) — MonthlySummary ViewModel mood gradient pair #4 bitişi
    /// Purpose: MonthlySummary ViewModel mood gradient pair #4 end
    /// Usage: MonthlySummaryViewModel mood gradient leg #4 end stop
    static let summaryEmberAmber = Color(hex: "#D8801A")

    /// Summary mock red (#C94040) — Mock MonthlySummaryData kırmızı + VM konsolide kırmızı (#C74040)
    /// Purpose: MonthlySummary mock data red + ViewModel consolidated red leg
    /// Usage: MonthlySummaryData.mock red stop, ViewModel mood gradient red leg
    static let summaryMockRed = Color(hex: "#C94040")

    /// Summary mock yellow (#C9A840) — Mock MonthlySummaryData sarı stop
    /// Purpose: MonthlySummary mock data yellow accent
    /// Usage: MonthlySummaryData.mock yellow stop
    static let summaryMockYellow = Color(hex: "#C9A840")

    /// Summary mock teal (#40A89C) — Mock teal + ViewModel gradient leg (konsolide #40A89B)
    /// Purpose: MonthlySummary mock data teal + ViewModel gradient teal leg
    /// Usage: MonthlySummaryData.mock teal stop, ViewModel mood gradient teal leg
    static let summaryMockTeal = Color(hex: "#40A89C")

    /// Summary mock blue (#4070C9) — Mock mavi + ViewModel gradient leg (konsolide #4070CC)
    /// Purpose: MonthlySummary mock data blue + ViewModel gradient blue leg
    /// Usage: MonthlySummaryData.mock blue stop, ViewModel mood gradient blue leg
    static let summaryMockBlue = Color(hex: "#4070C9")

    /// Summary mock purple (#7840C9) — Mock mor + ViewModel gradient leg (konsolide #7840CC)
    /// Purpose: MonthlySummary mock data purple + ViewModel gradient purple leg
    /// Usage: MonthlySummaryData.mock purple stop, ViewModel mood gradient purple leg
    static let summaryMockPurple = Color(hex: "#7840C9")

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
