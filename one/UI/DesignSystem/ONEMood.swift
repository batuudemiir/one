//
//  ONEMood.swift
//  one
//
//  Design System - Mood System
//  Defines the mood enum with 8 emotional states and their visual properties
//

import SwiftUI

/// Mood represents one of twelve emotional states in the ONE app
/// Each mood has associated visual properties for consistent representation
///
/// The twelve moods cover the full emotional spectrum (color-psychology aligned):
/// - atesli    (Ateşli):    Passionate, intense — red
/// - enerjik   (Coşkulu):   Enthusiastic, excited — orange
/// - isikli    (Mutlu):     Joyful, optimistic — yellow
/// - taze      (Taze):      Fresh, vital, renewed — lime
/// - sakin     (Huzurlu):   Peaceful, balanced — green
/// - ozgur     (Özgür):     Free, open, expansive — teal
/// - derin     (Derin):     Reflective, profound — blue
/// - nostaljik (Nostaljik): Longing, memory — indigo
/// - gizemli   (Gizemli):   Mysterious, dreamy — purple
/// - hassas    (Hassas):    Sensitive, gentle — rose
/// - bos       (Sessiz):    Still, minimal, void — dark
/// - temiz     (Sade):      Simple, natural, clear — ivory
enum ONEMood: String, Codable, CaseIterable, Identifiable {
    case atesli    // Ateşli   - passionate, intense
    case enerjik   // Coşkulu  - enthusiastic, excited
    case isikli    // Mutlu    - joyful, optimistic
    case taze      // Taze     - fresh, vital, renewed
    case sakin     // Huzurlu  - peaceful, balanced
    case ozgur     // Özgür    - free, open, expansive
    case derin     // Derin    - reflective, profound
    case nostaljik // Nostaljik - longing, memory
    case gizemli   // Gizemli  - mysterious, dreamy
    case hassas    // Hassas   - sensitive, gentle
    case bos       // Sessiz   - still, minimal, void
    case temiz     // Sade     - simple, natural, clear
    
    var id: String { rawValue }
    
    /// Primary color for this mood
    /// Purpose: Defines the visual identity and emotional tone of each mood
    /// Usage: Mood selection UI, gradient backgrounds, mood indicators
    var color: Color {
        switch self {
        case .atesli:    return ONETokens.oneRed
        case .enerjik:   return ONETokens.moodOrange
        case .isikli:    return ONETokens.moodYellow
        case .taze:      return ONETokens.moodLime
        case .sakin:     return ONETokens.oneGreen
        case .ozgur:     return ONETokens.moodTeal
        case .derin:     return ONETokens.oneBlue
        case .nostaljik: return ONETokens.moodIndigo
        case .gizemli:   return ONETokens.moodPurple
        case .hassas:    return ONETokens.moodRose
        case .bos:       return ONETokens.moodDark
        case .temiz:     return ONETokens.oneIvory
        }
    }
    
    /// Hex string representation of the mood color
    /// Purpose: Provides hex format for persistence and external integrations
    /// Usage: Data persistence, API communication, color picker displays
    var hex: String {
        switch self {
        case .atesli:    return "#E84040"
        case .enerjik:   return "#FF8C42"
        case .isikli:    return "#F5C842"
        case .taze:      return "#7CC874"
        case .sakin:     return "#4CAF82"
        case .ozgur:     return "#3BBFCF"
        case .derin:     return "#5B8DEF"
        case .nostaljik: return "#5560B8"
        case .gizemli:   return "#9B7FD4"
        case .hassas:    return "#E8829C"
        case .bos:       return "#2C2C2C"
        case .temiz:     return "#E8E6E0"
        }
    }
    
    /// Display label for the mood (Turkish)
    /// Purpose: Provides localized Turkish name for UI display
    /// Usage: Mood selection labels, mood display text, user-facing mood names
    var label: String {
        switch self {
        case .atesli:    return "ateş"
        case .enerjik:   return "enerji"
        case .isikli:    return "ışık"
        case .taze:      return "taze"
        case .sakin:     return "huzur"
        case .ozgur:     return "özgür"
        case .derin:     return "derin"
        case .nostaljik: return "özlem"
        case .gizemli:   return "loş"
        case .hassas:    return "kırılgan"
        case .bos:       return "boşluk"
        case .temiz:     return "sessiz"
        }
    }
    
    /// Semantic meaning of the mood
    /// Purpose: Provides descriptive Turkish text explaining the mood's emotional character
    /// Usage: Mood descriptions, tooltips, help text, emotional context
    var meaning: String {
        switch self {
        case .atesli:    return "içim yanıyor"
        case .enerjik:   return "taşıp duruyor"
        case .isikli:    return "içimden parlıyor"
        case .taze:      return "yeni başlıyor"
        case .sakin:     return "her şey yolunda"
        case .ozgur:     return "hafif, özgür"
        case .derin:     return "içimde kaybolmuş"
        case .nostaljik: return "bir şeyleri özlüyor"
        case .gizemli:   return "gerçek ötesi"
        case .hassas:    return "hassas, savunmasız"
        case .bos:       return "içi boş, sessiz"
        case .temiz:     return "temiz sayfa"
        }
    }
    
    /// SF Symbol icon representing this mood — used for accessibility labels and color-blind support
    /// Purpose: VoiceOver announces mood name + icon context; icon is NOT rendered visually by default
    /// Usage: .accessibilityLabel("\(label) — \(meaning)"), future icon overlay feature
    var icon: String {
        switch self {
        case .atesli:    return "flame.fill"
        case .enerjik:   return "bolt.fill"
        case .isikli:    return "sun.max.fill"
        case .taze:      return "leaf.fill"
        case .sakin:     return "water.waves"
        case .ozgur:     return "wind"
        case .derin:     return "moon.fill"
        case .nostaljik: return "clock.fill"
        case .gizemli:   return "sparkles"
        case .hassas:    return "heart.fill"
        case .bos:       return "circle.dotted"
        case .temiz:     return "snowflake"
        }
    }

    /// Whether this mood uses dark text (false) or light text (true)
    /// Purpose: Determines text color for optimal contrast on mood backgrounds
    /// Usage: Text color selection, accessibility, contrast calculations
    var isDark: Bool {
        // Light-background moods need dark text for contrast
        switch self {
        case .isikli, .taze, .temiz: return false
        default: return true
        }
    }
    
    /// Wave height for mood visualization (used in WaveStrip)
    /// Purpose: Defines the amplitude of wave animations to match mood energy
    /// Usage: WaveStrip component, mood-based animations, visual intensity
    /// Higher values = more energetic moods, lower values = calmer moods
    var waveHeight: CGFloat {
        switch self {
        case .atesli:    return 28  // yüksek enerji
        case .enerjik:   return 32  // en enerjik
        case .isikli:    return 24  // neşeli, orta-yüksek
        case .taze:      return 20  // canlı ama sakin
        case .sakin:     return 16  // düşük, huzurlu
        case .ozgur:     return 22  // akan, açık
        case .derin:     return 20  // orta, içsel
        case .nostaljik: return 18  // hafif dalgalı, derin
        case .gizemli:   return 26  // dalgalı, gizemli
        case .hassas:    return 14  // nazik, yumuşak
        case .bos:       return 8   // minimal
        case .temiz:     return 12  // sade, hafif
        }
    }
    
    /// Gradient configuration for background
    /// Purpose: Creates mood-specific gradient backgrounds with Wabi-Sabi aesthetic
    /// Usage: Background gradients, mood atmosphere, visual depth
    /// Returns array of gradient stops: [mood color, blended, dark base]
    /// Formula: Pure mood color → 40% opacity blend → deep dark base
    var gradientStops: [Color] {
        let darkBase = ONETokens.oneVoid
        return [
            color,                  // Stop 1: Pure mood color
            color.opacity(0.4),     // Stop 2: Mood color at 40% opacity
            darkBase                // Stop 3: Dark base
        ]
    }
    
    /// Gradient start point for background
    /// Purpose: Defines where the mood gradient begins (top-leading corner)
    /// Usage: LinearGradient startPoint parameter
    var gradientStart: UnitPoint {
        .topLeading
    }
    
    /// Gradient end point for background
    /// Purpose: Defines where the mood gradient ends (bottom-trailing corner)
    /// Usage: LinearGradient endPoint parameter
    var gradientEnd: UnitPoint {
        .bottomTrailing
    }
}

extension ONEMood {
    /// Initialize from hex string (for persistence and legacy compatibility)
    init?(hex: String) {
        let normalized = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted).uppercased()
        switch normalized {
        // Pastel hex values (new entries)
        case "FFB5A7": self = .atesli
        case "FFCBA4": self = .enerjik
        case "FFF0B3": self = .isikli
        case "B8F0D4": self = .taze
        case "A8D5B5": self = .sakin
        case "A8D4F5": self = .ozgur
        case "B8C5F0": self = .derin
        case "C5B8F0": self = .nostaljik
        case "D4B8F0": self = .gizemli
        case "FFB8CC": self = .hassas
        case "CDD5E8": self = .bos
        case "F0EDE8": self = .temiz
        // Legacy saturated hex values (kept for existing saved entries)
        case "E84040": self = .atesli
        case "FF8C42": self = .enerjik
        case "F5C842": self = .isikli
        case "7CC874": self = .taze
        case "4CAF82": self = .sakin
        case "3BBFCF": self = .ozgur
        case "5B8DEF": self = .derin
        case "5560B8": self = .nostaljik
        case "9B7FD4": self = .gizemli
        case "E8829C": self = .hassas
        case "2C2C2C": self = .bos
        case "E8E6E0": self = .temiz
        case "607D8B": self = .derin   // old moodSlate → derin
        case "C97840": self = .enerjik // old moodAmber → enerjik
        default: return nil
        }
    }
}
