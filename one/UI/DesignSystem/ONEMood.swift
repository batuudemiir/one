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
        case .atesli:    return "Ateşli"
        case .enerjik:   return "Coşkulu"
        case .isikli:    return "Mutlu"
        case .taze:      return "Doğal"
        case .sakin:     return "Huzurlu"
        case .ozgur:     return "Özgür"
        case .derin:     return "Derin"
        case .nostaljik: return "Nostaljik"
        case .gizemli:   return "Gizemli"
        case .hassas:    return "Hassas"
        case .bos:       return "Sessiz"
        case .temiz:     return "Nötr"
        }
    }
    
    /// Semantic meaning of the mood
    /// Purpose: Provides descriptive Turkish text explaining the mood's emotional character
    /// Usage: Mood descriptions, tooltips, help text, emotional context
    var meaning: String {
        switch self {
        case .atesli:    return "Tutkulu, yoğun, alev alev"
        case .enerjik:   return "Coşkulu, heyecanlı, canlı"
        case .isikli:    return "Neşeli, umutlu, aydınlık"
        case .taze:      return "Doğal, toprakla bağlantılı, dingin"
        case .sakin:     return "Huzurlu, dengeli, dingin"
        case .ozgur:     return "Özgür, ferah, engin"
        case .derin:     return "İçsel, düşünceli, derin"
        case .nostaljik: return "Özlem, hatıra, geçmiş"
        case .gizemli:   return "Gizemli, büyülü, hayal"
        case .hassas:    return "Nazik, hassas, yumuşak"
        case .bos:       return "Sessiz, durgun, minimal"
        case .temiz:     return "Nötr, yalın, belirsiz"
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
        // Legacy labels that no longer match new system
        case "607D8B": self = .derin   // old moodSlate → derin
        case "C97840": self = .enerjik // old moodAmber → enerjik
        default: return nil
        }
    }
}
