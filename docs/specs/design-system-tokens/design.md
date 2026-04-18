# Design Document: Design System Tokens

## Overview

This design document specifies a comprehensive design token system for the ONE app. The system centralizes all visual design attributes (colors, typography, spacing, border radius, animations, and moods) into a single source of truth, eliminating hardcoded values throughout the codebase.

### Goals

- Provide a centralized design token system for all visual attributes
- Enable consistent styling across the entire application
- Facilitate easy theme updates and design iterations
- Improve code maintainability and reduce duplication
- Maintain backward compatibility with zero breaking changes

### Design Principles

1. **Single Source of Truth**: All design values defined in one place
2. **Type Safety**: Leverage Swift's type system for compile-time safety
3. **Discoverability**: Clear naming conventions and organization
4. **Ease of Use**: Convenient view modifiers for common patterns
5. **Wabi-Sabi Aesthetic**: Embrace imperfection, simplicity, and natural beauty

## Architecture

### File Structure

The design system consists of 7 Swift files organized in a `DesignSystem` folder:

```
one/one/DesignSystem/
├── ONETokens.swift          # Colors, spacing, border radius
├── ONETypography.swift      # Font styles and scales
├── ONEAnimation.swift       # Animation durations and configurations
├── ONEMood.swift            # Mood enum and properties
├── Color+ONE.swift          # Color utilities and hex initialization
├── View+ONE.swift           # View modifiers for easy token application
└── ONEToggleStyle.swift     # Toggle and navigation pip components
```

### Import Order and Dependencies

```
Color+ONE.swift (no dependencies)
    ↓
ONETokens.swift (depends on Color+ONE)
    ↓
ONEMood.swift (depends on Color+ONE, ONETokens)
    ↓
ONETypography.swift (no dependencies)
    ↓
ONEAnimation.swift (no dependencies)
    ↓
View+ONE.swift (depends on ONETypography, ONETokens)
    ↓
ONEToggleStyle.swift (depends on ONETokens, ONEAnimation)
```

All files will be imported automatically through the module system. Views only need to import SwiftUI to access design tokens.



## Components and Interfaces

### 1. Color+ONE.swift

Provides hex color initialization utility.

```swift
import SwiftUI

extension Color {
    /// Initialize a Color from a hex string
    /// Supports formats: "#RGB", "#RRGGBB", "#RRGGBBAA"
    /// - Parameter hex: Hex string with or without "#" prefix
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
```

### 2. ONETokens.swift

Defines color palette, spacing scale, and border radius tokens.

```swift
import SwiftUI

/// Design tokens for the ONE app
/// Provides centralized color, spacing, and border radius values
enum ONETokens {
    
    // MARK: - Neutral Color Palette
    
    /// Lightest neutral - cream background (#F7F6F3)
    static let oneCream = Color(hex: "#F7F6F3")
    
    /// Mid-light neutral - subtle backgrounds (#EEECEA)
    static let oneCreamMid = Color(hex: "#EEECEA")
    
    /// Low-light neutral - muted backgrounds (#E8E6E0)
    static let oneCreamLow = Color(hex: "#E8E6E0")
    
    /// Light-medium neutral - borders and dividers (#D8D6D0)
    static let oneStone = Color(hex: "#D8D6D0")
    
    /// Medium neutral - secondary text (#BFBDB5)
    static let oneAsh = Color(hex: "#BFBDB5")
    
    /// Medium-dark neutral - tertiary text (#999591)
    static let oneCharcoal = Color(hex: "#999591")
    
    /// Dark neutral - primary text (#111112)
    static let oneInk = Color(hex: "#111112")
    
    /// Darkest neutral - deep backgrounds (#0D0D0E)
    static let oneVoid = Color(hex: "#0D0D0E")
    
    // MARK: - Accent Colors
    
    /// Primary accent - links and interactive elements (#5B8DEF)
    static let oneBlue = Color(hex: "#5B8DEF")
    
    /// Success color - positive actions (#4CAF82)
    static let oneGreen = Color(hex: "#4CAF82")
    
    /// Error/destructive color (#E84040)
    static let oneRed = Color(hex: "#E84040")
    
    // MARK: - Spacing Scale
    
    /// Extra small spacing - 4pt (tight padding, small gaps)
    static let spacingXS: CGFloat = 4
    
    /// Small spacing - 8pt (compact layouts, list item gaps)
    static let spacingSM: CGFloat = 8
    
    /// Medium spacing - 12pt (default padding, moderate gaps)
    static let spacingMD: CGFloat = 12
    
    /// Large spacing - 16pt (comfortable padding, section gaps)
    static let spacingLG: CGFloat = 16
    
    /// Extra large spacing - 22pt (generous padding)
    static let spacingXL: CGFloat = 22
    
    /// 2XL spacing - 26pt (horizontal screen margins)
    static let spacingXL2: CGFloat = 26
    
    /// 3XL spacing - 36pt (large section spacing)
    static let spacingXL3: CGFloat = 36
    
    /// 4XL spacing - 52pt (major section breaks)
    static let spacingXL4: CGFloat = 52
    
    /// 5XL spacing - 72pt (hero spacing)
    static let spacingXL5: CGFloat = 72
    
    // MARK: - Border Radius Scale
    
    /// Tag radius - 6pt (small pills, tags)
    static let radiusTag: CGFloat = 6
    
    /// Toggle radius - 10pt (toggle switches)
    static let radiusToggle: CGFloat = 10
    
    /// Cover radius - 12pt (album art, small cards)
    static let radiusCover: CGFloat = 12
    
    /// Card radius - 13pt (standard cards, buttons)
    static let radiusCard: CGFloat = 13
    
    /// Large card radius - 16pt (prominent cards)
    static let radiusCardLg: CGFloat = 16
    
    /// Friend card radius - 18pt (circle friend cards)
    static let radiusFriend: CGFloat = 18
    
    /// Sheet radius - 20pt (modal sheets, panels)
    static let radiusSheet: CGFloat = 20
    
    /// Screen radius - 42pt (full screen corners)
    static let radiusScreen: CGFloat = 42
}
```



### 3. ONEMood.swift

Defines the mood system with 8 emotional states.

```swift
import SwiftUI

/// Mood represents one of eight emotional states in the ONE app
/// Each mood has associated visual properties for consistent representation
enum ONEMood: String, Codable, CaseIterable, Identifiable {
    case atesli    // Fiery - passionate, intense
    case enerjik   // Energetic - vibrant, dynamic
    case isikli    // Luminous - bright, hopeful
    case sakin     // Calm - peaceful, balanced
    case derin     // Deep - thoughtful, profound
    case gizemli   // Mysterious - enigmatic, introspective
    case bos       // Empty - minimal, void
    case temiz     // Clean - pure, simple
    
    var id: String { rawValue }
    
    /// Primary color for this mood
    var color: Color {
        switch self {
        case .atesli:   return Color(hex: "#E84040")
        case .enerjik:  return Color(hex: "#FF8C42")
        case .isikli:   return Color(hex: "#F5C842")
        case .sakin:    return Color(hex: "#4CAF82")
        case .derin:    return Color(hex: "#5B8DEF")
        case .gizemli:  return Color(hex: "#9B7FD4")
        case .bos:      return Color(hex: "#2C2C2C")
        case .temiz:    return Color(hex: "#E8E6E0")
        }
    }
    
    /// Hex string representation of the mood color
    var hex: String {
        switch self {
        case .atesli:   return "#E84040"
        case .enerjik:  return "#FF8C42"
        case .isikli:   return "#F5C842"
        case .sakin:    return "#4CAF82"
        case .derin:    return "#5B8DEF"
        case .gizemli:  return "#9B7FD4"
        case .bos:      return "#2C2C2C"
        case .temiz:    return "#E8E6E0"
        }
    }
    
    /// Display label for the mood (Turkish)
    var label: String {
        switch self {
        case .atesli:   return "Ateşli"
        case .enerjik:  return "Enerjik"
        case .isikli:   return "Işıklı"
        case .sakin:    return "Sakin"
        case .derin:    return "Derin"
        case .gizemli:  return "Gizemli"
        case .bos:      return "Boş"
        case .temiz:    return "Temiz"
        }
    }
    
    /// Semantic meaning of the mood
    var meaning: String {
        switch self {
        case .atesli:   return "Tutkulu, yoğun, canlı"
        case .enerjik:  return "Dinamik, hareketli, coşkulu"
        case .isikli:   return "Aydınlık, umutlu, parlak"
        case .sakin:    return "Huzurlu, dengeli, rahat"
        case .derin:    return "Düşünceli, derin, nostaljik"
        case .gizemli:  return "Gizemli, içsel, hayal"
        case .bos:      return "Minimal, sessiz, boş"
        case .temiz:    return "Saf, temiz, doğal"
        }
    }
    
    /// Whether this mood uses dark text (false) or light text (true)
    var isDark: Bool {
        self != .temiz
    }
    
    /// Wave height for mood visualization (used in WaveStrip)
    var waveHeight: CGFloat {
        switch self {
        case .atesli:   return 28
        case .enerjik:  return 32
        case .isikli:   return 24
        case .sakin:    return 16
        case .derin:    return 20
        case .gizemli:  return 26
        case .bos:      return 8
        case .temiz:    return 12
        }
    }
    
    /// Gradient configuration for background
    /// Returns array of gradient stops: [mood color, blended, dark base]
    var gradientStops: [Color] {
        let darkBase = ONETokens.oneVoid
        return [
            color,                  // Stop 1: Pure mood color
            color.opacity(0.4),     // Stop 2: Mood color at 40% opacity
            darkBase                // Stop 3: Dark base
        ]
    }
    
    /// Gradient start point for background
    var gradientStart: UnitPoint {
        .topLeading
    }
    
    /// Gradient end point for background
    var gradientEnd: UnitPoint {
        .bottomTrailing
    }
}

extension ONEMood {
    /// Initialize from hex string (for legacy compatibility)
    init?(hex: String) {
        let normalized = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted).uppercased()
        switch normalized {
        case "E84040": self = .atesli
        case "FF8C42": self = .enerjik
        case "F5C842": self = .isikli
        case "4CAF82": self = .sakin
        case "5B8DEF": self = .derin
        case "9B7FD4": self = .gizemli
        case "2C2C2C": self = .bos
        case "E8E6E0": self = .temiz
        default: return nil
        }
    }
}
```



### 4. ONETypography.swift

Defines typography scales and font styles.

```swift
import SwiftUI

/// Typography tokens for the ONE app
/// Provides two font scales: Display (Fraunces) and Mono (Geist Mono)
enum ONETypography {
    
    // MARK: - Display Scale (Fraunces)
    // Used for headings, hero text, and emotional content
    
    /// Display XL - 48pt Fraunces Light Italic (splash screen, hero)
    static let displayXL = Font.custom("Fraunces-LightItalic", size: 48)
    
    /// Display LG - 34pt Fraunces Light Italic (main headings)
    static let displayLG = Font.custom("Fraunces-LightItalic", size: 34)
    
    /// Display MD - 26pt Fraunces Light Italic (subheadings)
    static let displayMD = Font.custom("Fraunces-LightItalic", size: 26)
    
    /// Display SM - 22pt Fraunces Light (card titles)
    static let displaySM = Font.custom("Fraunces-Light", size: 22)
    
    /// Display XS - 18pt Fraunces Light Italic (small headings)
    static let displayXS = Font.custom("Fraunces-LightItalic", size: 18)
    
    /// Display Body - 16pt Fraunces Light Italic (body text)
    static let displayBody = Font.custom("Fraunces-LightItalic", size: 16)
    
    // MARK: - Mono Scale (Geist Mono)
    // Used for labels, metadata, and technical information
    
    /// Mono Base - 11pt Geist Mono Regular (buttons, labels)
    static let monoBase = Font.custom("GeistMono-Regular", size: 11)
    
    /// Mono SM - 10pt Geist Mono Regular (metadata, secondary labels)
    static let monoSM = Font.custom("GeistMono-Regular", size: 10)
    
    /// Mono Label - 9pt Geist Mono Regular (small labels, tags)
    static let monoLabel = Font.custom("GeistMono-Regular", size: 9)
    
    /// Mono Micro - 8pt Geist Mono Regular (micro text, captions)
    static let monoMicro = Font.custom("GeistMono-Regular", size: 8)
}

// MARK: - Typography View Modifiers

extension View {
    
    // MARK: Display Scale Modifiers
    
    /// Apply Display XL typography (48pt Fraunces Light Italic)
    func displayXL() -> some View {
        self.font(ONETypography.displayXL)
            .italic()
    }
    
    /// Apply Display LG typography (34pt Fraunces Light Italic)
    func displayLG() -> some View {
        self.font(ONETypography.displayLG)
            .italic()
    }
    
    /// Apply Display MD typography (26pt Fraunces Light Italic)
    func displayMD() -> some View {
        self.font(ONETypography.displayMD)
            .italic()
    }
    
    /// Apply Display SM typography (22pt Fraunces Light)
    func displaySM() -> some View {
        self.font(ONETypography.displaySM)
    }
    
    /// Apply Display XS typography (18pt Fraunces Light Italic)
    func displayXS() -> some View {
        self.font(ONETypography.displayXS)
            .italic()
    }
    
    /// Apply Display Body typography (16pt Fraunces Light Italic)
    func displayBody() -> some View {
        self.font(ONETypography.displayBody)
            .italic()
    }
    
    // MARK: Mono Scale Modifiers
    
    /// Apply Mono Base typography (11pt Geist Mono Regular)
    /// - Parameter tracking: Letter spacing (default: 1.8)
    func monoBase(tracking: CGFloat = 1.8) -> some View {
        self.font(ONETypography.monoBase)
            .tracking(tracking)
    }
    
    /// Apply Mono SM typography (10pt Geist Mono Regular)
    /// - Parameter tracking: Letter spacing (default: 1.2)
    func monoSM(tracking: CGFloat = 1.2) -> some View {
        self.font(ONETypography.monoSM)
            .tracking(tracking)
    }
    
    /// Apply Mono Label typography (9pt Geist Mono Regular)
    /// - Parameter tracking: Letter spacing (default: 1.2)
    func monoLabel(tracking: CGFloat = 1.2) -> some View {
        self.font(ONETypography.monoLabel)
            .tracking(tracking)
    }
    
    /// Apply Mono Micro typography (8pt Geist Mono Regular)
    /// - Parameter tracking: Letter spacing (default: 0.8)
    func monoMicro(tracking: CGFloat = 0.8) -> some View {
        self.font(ONETypography.monoMicro)
            .tracking(tracking)
    }
}
```



### 5. ONEAnimation.swift

Defines animation durations and spring configurations.

```swift
import SwiftUI

/// Animation tokens for the ONE app
/// Provides standardized durations and spring configurations
enum ONEAnimation {
    
    // MARK: - Duration Tokens
    
    /// Micro duration - 0.15s (very quick interactions)
    static let durationMicro: Double = 0.15
    
    /// Short duration - 0.25s (quick animations)
    static let durationShort: Double = 0.25
    
    /// Medium duration - 0.35s (standard animations)
    static let durationMedium: Double = 0.35
    
    /// Long duration - 0.55s (slow, deliberate animations)
    static let durationLong: Double = 0.55
    
    /// Mood background duration - 1.4s (mood gradient transitions)
    static let durationMoodBg: Double = 1.4
    
    /// Pulse duration - 2.0s (pulsing animations)
    static let durationPulse: Double = 2.0
    
    /// Breathe duration - 3.5s (breathing animations)
    static let durationBreathe: Double = 3.5
    
    // MARK: - Animation Type Configurations
    
    /// Micro animation - subtle, quick interactions
    /// Response: 0.3, Damping: 0.7
    static let micro = Animation.spring(response: 0.3, dampingFraction: 0.7)
    
    /// Card spring - smooth card movements
    /// Response: 0.45, Damping: 0.8
    static let cardSpring = Animation.spring(response: 0.45, dampingFraction: 0.8)
    
    /// Panel spring - panel and sheet transitions
    /// Response: 0.5, Damping: 0.85
    static let panelSpring = Animation.spring(response: 0.5, dampingFraction: 0.85)
    
    /// Screen transition - full screen changes
    /// Response: 0.6, Damping: 0.9
    static let screenTransition = Animation.spring(response: 0.6, dampingFraction: 0.9)
    
    /// Mood transition - mood color changes
    /// Response: 0.7, Damping: 0.95
    static let moodTransition = Animation.spring(response: 0.7, dampingFraction: 0.95)
    
    // MARK: - Stagger Animation
    
    /// Calculate stagger delay for list item animations
    /// - Parameters:
    ///   - index: Item index in the list
    ///   - baseDelay: Base delay between items (default: 0.08)
    /// - Returns: Delay in seconds for this item
    static func staggerDelay(index: Int, baseDelay: Double = 0.08) -> Double {
        return Double(index) * baseDelay
    }
    
    // MARK: - Button Press Style
    
    /// Scale for pressed button state
    static let buttonPressScale: CGFloat = 0.96
    
    /// Animation for button press
    static let buttonPressAnimation = Animation.spring(response: 0.25, dampingFraction: 0.6)
    
    /// Animation for button release
    static let buttonReleaseAnimation = Animation.spring(response: 0.35, dampingFraction: 0.7)
}

// MARK: - Animation View Modifiers

extension View {
    
    /// Apply button press animation effect
    /// - Parameter isPressed: Whether button is currently pressed
    func buttonPressEffect(isPressed: Bool) -> some View {
        self.scaleEffect(isPressed ? ONEAnimation.buttonPressScale : 1.0)
            .animation(
                isPressed ? ONEAnimation.buttonPressAnimation : ONEAnimation.buttonReleaseAnimation,
                value: isPressed
            )
    }
}

// MARK: - Breathing Animation Modifier

struct BreathingAnimation: ViewModifier {
    let delay: Double
    @State private var isAnimating = false
    
    func body(content: Content) -> some View {
        content
            .scaleEffect(isAnimating ? 1.05 : 1.0)
            .opacity(isAnimating ? 0.6 : 0.3)
            .animation(
                Animation.easeInOut(duration: ONEAnimation.durationBreathe)
                    .repeatForever(autoreverses: true)
                    .delay(delay),
                value: isAnimating
            )
            .onAppear {
                isAnimating = true
            }
    }
}

extension View {
    /// Apply breathing animation effect
    /// - Parameter delay: Delay before animation starts (default: 0)
    func breathingAnimation(delay: Double = 0) -> some View {
        self.modifier(BreathingAnimation(delay: delay))
    }
}
```



### 6. View+ONE.swift

Provides convenient view modifiers for common styling patterns.

```swift
import SwiftUI

extension View {
    
    // MARK: - Color Combination Modifiers
    
    /// Apply primary text color (oneInk)
    func primaryText() -> some View {
        self.foregroundColor(ONETokens.oneInk)
    }
    
    /// Apply secondary text color (oneAsh)
    func secondaryText() -> some View {
        self.foregroundColor(ONETokens.oneAsh)
    }
    
    /// Apply tertiary text color (oneCharcoal)
    func tertiaryText() -> some View {
        self.foregroundColor(ONETokens.oneCharcoal)
    }
    
    /// Apply muted text color (oneCreamLow)
    func mutedText() -> some View {
        self.foregroundColor(ONETokens.oneCreamLow)
    }
    
    // MARK: - Background Modifiers
    
    /// Apply cream background
    func creamBackground() -> some View {
        self.background(ONETokens.oneCream)
    }
    
    /// Apply card background with standard radius
    func cardBackground() -> some View {
        self.background(
            RoundedRectangle(cornerRadius: ONETokens.radiusCard)
                .fill(ONETokens.oneCreamMid)
        )
    }
    
    // MARK: - Border Modifiers
    
    /// Apply standard card border
    /// - Parameter color: Border color (default: oneStone)
    func cardBorder(color: Color = ONETokens.oneStone) -> some View {
        self.overlay(
            RoundedRectangle(cornerRadius: ONETokens.radiusCard)
                .stroke(color, lineWidth: 1)
        )
    }
    
    // MARK: - Spacing Modifiers
    
    /// Apply standard horizontal padding (XL2 - 26pt)
    func standardHorizontalPadding() -> some View {
        self.padding(.horizontal, ONETokens.spacingXL2)
    }
    
    /// Apply standard vertical padding (LG - 16pt)
    func standardVerticalPadding() -> some View {
        self.padding(.vertical, ONETokens.spacingLG)
    }
}
```

### 7. ONEToggleStyle.swift

Defines custom toggle style and navigation pip components.

```swift
import SwiftUI

/// Custom toggle style using ONE design tokens
struct ONEToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack {
            configuration.label
            Spacer()
            ZStack {
                Capsule()
                    .fill(configuration.isOn ? ONETokens.oneBlue : ONETokens.oneStone)
                    .frame(width: 44, height: 26)
                
                Circle()
                    .fill(Color.white)
                    .frame(width: 22, height: 22)
                    .offset(x: configuration.isOn ? 9 : -9)
            }
            .onTapGesture {
                withAnimation(ONEAnimation.micro) {
                    configuration.isOn.toggle()
                }
            }
        }
    }
}

/// Navigation pip indicator for bottom navigation
struct NavigationPip: View {
    let isActive: Bool
    
    var body: some View {
        Circle()
            .fill(isActive ? ONETokens.oneInk : ONETokens.oneStone)
            .frame(width: 6, height: 6)
            .animation(ONEAnimation.micro, value: isActive)
    }
}

extension ToggleStyle where Self == ONEToggleStyle {
    /// ONE app toggle style
    static var one: ONEToggleStyle { ONEToggleStyle() }
}
```



## Data Models

### Mood Enum

The `ONEMood` enum is the central data model for the mood system:

```swift
enum ONEMood: String, Codable, CaseIterable, Identifiable {
    case atesli, enerjik, isikli, sakin, derin, gizemli, bos, temiz
}
```

**Properties:**
- `color: Color` - Primary mood color
- `hex: String` - Hex representation for persistence
- `label: String` - Display name (Turkish)
- `meaning: String` - Semantic description
- `isDark: Bool` - Whether to use light text on this color
- `waveHeight: CGFloat` - Wave animation amplitude
- `gradientStops: [Color]` - 3-stop gradient configuration
- `gradientStart: UnitPoint` - Gradient start point
- `gradientEnd: UnitPoint` - Gradient end point

**Serialization:**
The enum conforms to `Codable` for Core Data persistence. The `rawValue` (String) is used for encoding/decoding.

**Legacy Compatibility:**
The `init?(hex: String)` initializer allows conversion from hex strings used in existing code.

### Mood Color Mapping

| Mood | Turkish | Hex | Meaning |
|------|---------|-----|---------|
| atesli | Ateşli | #E84040 | Passionate, intense, fiery |
| enerjik | Enerjik | #FF8C42 | Dynamic, vibrant, energetic |
| isikli | Işıklı | #F5C842 | Bright, hopeful, luminous |
| sakin | Sakin | #4CAF82 | Peaceful, balanced, calm |
| derin | Derin | #5B8DEF | Thoughtful, profound, deep |
| gizemli | Gizemli | #9B7FD4 | Enigmatic, introspective, mysterious |
| bos | Boş | #2C2C2C | Minimal, void, empty |
| temiz | Temiz | #E8E6E0 | Pure, simple, clean |

### Gradient Background Component

The mood gradient background uses a 3-stop gradient formula:

```swift
// Stop 1 (0%): Pure mood color
// Stop 2 (50%): Mood color at 40% opacity (creates blend effect)
// Stop 3 (100%): Dark base (#0D0D0E)
```

This creates the Wabi-Sabi aesthetic of mood colors fading into darkness.

**Usage Example:**
```swift
LinearGradient(
    gradient: Gradient(colors: mood.gradientStops),
    startPoint: mood.gradientStart,
    endPoint: mood.gradientEnd
)
```



## Correctness Properties

A property is a characteristic or behavior that should hold true across all valid executions of a system—essentially, a formal statement about what the system should do. Properties serve as the bridge between human-readable specifications and machine-verifiable correctness guarantees.

### Property Reflection

After analyzing all acceptance criteria, I identified the following testable properties:

**Initial candidates:**
- 3.10: Each mood has all required properties
- 4.1: Gradient uses mood colors
- 4.2: Gradient uses mood configuration (redundant with 4.1)
- 12.2: Hex parsing creates correct colors
- 12.3-12.5: Hex format edge cases
- 22.2: Mood serialization round-trip
- 22.4: Hex-to-mood conversion

**After reflection:**
- Properties 4.1 and 4.2 are redundant - they both test that gradients use mood configuration. Combined into Property 2.
- Hex parsing edge cases (12.3-12.5) are covered by the general hex parsing property with appropriate test generators.

### Property 1: Mood Completeness

For any mood in the ONEMood enum, that mood must provide all required properties: color, hex, label, meaning, isDark, waveHeight, gradientStops, gradientStart, and gradientEnd.

**Validates: Requirements 3.10**

### Property 2: Mood Gradient Configuration

For any mood in the ONEMood enum, the gradient stops must be a 3-element array containing: the mood's color, the mood's color at 40% opacity, and the dark base color (oneVoid).

**Validates: Requirements 4.1, 4.2**

### Property 3: Hex Color Round-Trip

For any valid hex string (3, 6, or 8 characters, with or without "#" prefix), initializing a Color with that hex string and then extracting its RGB components should produce values that match the original hex values (within floating-point tolerance).

**Validates: Requirements 12.2, 12.3, 12.4, 12.5**

### Property 4: Mood Serialization Round-Trip

For any mood in the ONEMood enum, encoding that mood to JSON and then decoding it should produce a mood equal to the original.

**Validates: Requirements 22.2**

### Property 5: Hex-to-Mood Conversion

For any mood in the ONEMood enum, converting the mood's hex string to a mood using ONEMood(hex:) should return the original mood.

**Validates: Requirements 22.4**



## Error Handling

### Color Hex Parsing

The `Color(hex:)` initializer handles invalid input gracefully:

```swift
default:
    (a, r, g, b) = (255, 0, 0, 0)  // Returns black for invalid input
```

**Error Cases:**
- Invalid hex characters → Returns black (#000000)
- Wrong length (not 3, 6, or 8) → Returns black (#000000)
- Empty string → Returns black (#000000)

**Design Decision:** We return black rather than crashing because color parsing often happens with user-provided or external data. A visible black color is better than a crash for debugging.

### Mood Hex Conversion

The `ONEMood.init?(hex:)` initializer returns `nil` for invalid hex strings:

```swift
init?(hex: String) {
    // ... mapping ...
    default: return nil
}
```

**Error Cases:**
- Unrecognized hex value → Returns nil
- Empty string → Returns nil
- Invalid format → Returns nil

**Design Decision:** Returning nil allows calling code to handle unknown moods gracefully, such as falling back to a default mood or showing an error message.

### Font Loading

Custom fonts (Fraunces, Geist Mono) must be properly registered in the app bundle. If a font fails to load:

```swift
// SwiftUI falls back to system font
.font(.custom("Fraunces-LightItalic", size: 34))  // Falls back to system italic
```

**Mitigation:**
- Include font files in app bundle
- Add fonts to Info.plist under "Fonts provided by application"
- Test font loading in unit tests

### Animation Edge Cases

**Zero or negative durations:** All duration constants are positive values. If custom durations are needed, validation should occur at the call site.

**Infinite animations:** The `breathingAnimation` modifier uses `.repeatForever()`. Views using this modifier should be properly cleaned up when removed from the hierarchy to prevent memory leaks.



## Testing Strategy

### Dual Testing Approach

This feature requires both unit tests and property-based tests for comprehensive coverage:

**Unit Tests** focus on:
- Specific examples of color conversions
- Edge cases (empty strings, invalid formats)
- Integration between components
- Font loading verification
- View modifier application

**Property-Based Tests** focus on:
- Universal properties across all moods
- Round-trip serialization
- Hex parsing for all valid formats
- Gradient configuration consistency

### Property-Based Testing Configuration

**Library:** Swift-Check (or similar PBT library for Swift)

**Configuration:**
- Minimum 100 iterations per property test
- Each test tagged with feature name and property number
- Tag format: `// Feature: design-system-tokens, Property {N}: {description}`

**Example Test Structure:**

```swift
import XCTest
import SwiftCheck

class DesignTokensPropertyTests: XCTestCase {
    
    // Feature: design-system-tokens, Property 1: Mood Completeness
    func testMoodCompleteness() {
        property("All moods have complete properties") <- forAll { (mood: ONEMood) in
            return !mood.label.isEmpty &&
                   !mood.hex.isEmpty &&
                   !mood.meaning.isEmpty &&
                   mood.waveHeight > 0 &&
                   mood.gradientStops.count == 3
        }
    }
    
    // Feature: design-system-tokens, Property 4: Mood Serialization Round-Trip
    func testMoodSerializationRoundTrip() {
        property("Encoding then decoding a mood returns the original") <- forAll { (mood: ONEMood) in
            let encoder = JSONEncoder()
            let decoder = JSONDecoder()
            
            guard let encoded = try? encoder.encode(mood),
                  let decoded = try? decoder.decode(ONEMood.self, from: encoded) else {
                return false
            }
            
            return decoded == mood
        }
    }
}
```

### Unit Test Examples

```swift
class DesignTokensUnitTests: XCTestCase {
    
    func testHexColorParsing() {
        // Test 6-character hex
        let color1 = Color(hex: "#FF0000")
        // Verify red channel is 1.0
        
        // Test 3-character hex
        let color2 = Color(hex: "#F00")
        // Verify equivalent to #FF0000
        
        // Test without # prefix
        let color3 = Color(hex: "00FF00")
        // Verify green channel is 1.0
    }
    
    func testMoodProperties() {
        let atesli = ONEMood.atesli
        XCTAssertEqual(atesli.hex, "#E84040")
        XCTAssertEqual(atesli.label, "Ateşli")
        XCTAssertTrue(atesli.isDark)
        XCTAssertEqual(atesli.waveHeight, 28)
    }
    
    func testSpacingTokens() {
        XCTAssertEqual(ONETokens.spacingXS, 4)
        XCTAssertEqual(ONETokens.spacingSM, 8)
        XCTAssertEqual(ONETokens.spacingMD, 12)
        // ... etc
    }
    
    func testRadiusTokens() {
        XCTAssertEqual(ONETokens.radiusTag, 6)
        XCTAssertEqual(ONETokens.radiusCard, 13)
        XCTAssertEqual(ONETokens.radiusScreen, 42)
    }
}
```

### Integration Tests

```swift
class DesignTokensIntegrationTests: XCTestCase {
    
    func testMoodGradientIntegration() {
        let mood = ONEMood.derin
        let gradient = LinearGradient(
            gradient: Gradient(colors: mood.gradientStops),
            startPoint: mood.gradientStart,
            endPoint: mood.gradientEnd
        )
        
        // Verify gradient has 3 stops
        XCTAssertEqual(mood.gradientStops.count, 3)
        
        // Verify first stop is mood color
        // Verify last stop is dark base
    }
    
    func testTypographyModifiers() {
        let text = Text("Test")
        let styled = text.displayLG()
        
        // Verify font is applied (requires view inspection)
    }
}
```

### Visual Regression Testing

While not automated, visual regression testing is critical for this feature:

1. **Before Migration:** Take screenshots of all major screens
2. **After Migration:** Take screenshots of the same screens
3. **Compare:** Use image diff tools to verify pixel-perfect match
4. **Document:** Any intentional visual changes should be documented

**Key Screens to Test:**
- Today view (main screen)
- Confirm screen (with mood selection)
- Archive view (month and year views)
- Circle view (friend cards)
- Settings view



## Migration Strategy

### Overview

The migration replaces hardcoded design values with design tokens across the entire codebase. This is a large-scale refactoring that must maintain visual fidelity and avoid breaking changes.

### Migration Phases

#### Phase 1: Create Design System Files

1. Create `one/one/DesignSystem/` folder
2. Implement all 7 design token files in order:
   - `Color+ONE.swift`
   - `ONETokens.swift`
   - `ONEMood.swift`
   - `ONETypography.swift`
   - `ONEAnimation.swift`
   - `View+ONE.swift`
   - `ONEToggleStyle.swift`
3. Add files to Xcode project
4. Verify compilation

#### Phase 2: Color Migration

**Strategy:** Replace all `Color(hex: "...")` with appropriate token references.

**Priority Order:**
1. Neutral colors (most common)
2. Mood colors
3. Accent colors (blue, green, red)

**Example Transformations:**

```swift
// Before
Color(hex: "#F7F6F3")

// After
ONETokens.oneCream

// Before
Color(hex: "#111112")

// After
ONETokens.oneInk

// Before
Color(hex: "#BFBDB5")

// After
ONETokens.oneAsh
```

**Files to Migrate (in order):**
1. `TodayCompletedView.swift`
2. `DayDetailView.swift`
3. `CircleView.swift`
4. `ArchiveView.swift`
5. `MonthArchiveView.swift`
6. `YearArchiveView.swift`
7. `PersonDetailBackground.swift`
8. `ONEColorPickerView.swift`
9. All remaining view files

**Verification:** After each file, compile and run app to verify no visual changes.

#### Phase 3: Typography Migration

**Strategy:** Replace hardcoded font references with typography tokens.

**Example Transformations:**

```swift
// Before
.font(.custom("Fraunces-LightItalic", size: 34))
.italic()

// After
.displayLG()

// Before
.font(.custom("GeistMono-Regular", size: 11))
.tracking(1.8)

// After
.monoBase()

// Before
.font(.custom("Fraunces-Light", size: 22))

// After
.displaySM()
```

**Pattern Matching:**
- `Fraunces-LightItalic` + size → Display scale
- `Fraunces-Light` + size → Display scale (without italic)
- `GeistMono-Regular` + size → Mono scale

**Verification:** Check that all text renders with correct fonts and sizes.

#### Phase 4: Spacing Migration

**Strategy:** Replace hardcoded spacing values with spacing tokens.

**Example Transformations:**

```swift
// Before
.padding(.horizontal, 26)

// After
.padding(.horizontal, ONETokens.spacingXL2)
// Or use convenience modifier:
.standardHorizontalPadding()

// Before
.padding(.vertical, 16)

// After
.padding(.vertical, ONETokens.spacingLG)

// Before
.padding(12)

// After
.padding(ONETokens.spacingMD)
```

**Matching Strategy:**
- 4pt → `spacingXS`
- 8pt → `spacingSM`
- 12pt → `spacingMD`
- 16pt → `spacingLG`
- 22pt → `spacingXL`
- 26pt → `spacingXL2`
- 36pt → `spacingXL3`
- 52pt → `spacingXL4`
- 72pt → `spacingXL5`

**Note:** Not all spacing values will match tokens. Only replace values that exactly match the token scale.

#### Phase 5: Border Radius Migration

**Strategy:** Replace hardcoded corner radius values with radius tokens.

**Example Transformations:**

```swift
// Before
.cornerRadius(13)

// After
.cornerRadius(ONETokens.radiusCard)

// Before
RoundedRectangle(cornerRadius: 12)

// After
RoundedRectangle(cornerRadius: ONETokens.radiusCover)

// Before
.clipShape(RoundedRectangle(cornerRadius: 16))

// After
.clipShape(RoundedRectangle(cornerRadius: ONETokens.radiusCardLg))
```

**Matching Strategy:**
- 6pt → `radiusTag`
- 10pt → `radiusToggle`
- 12pt → `radiusCover`
- 13pt → `radiusCard`
- 16pt → `radiusCardLg`
- 18pt → `radiusFriend`
- 20pt → `radiusSheet`
- 42pt → `radiusScreen`

#### Phase 6: Animation Migration

**Strategy:** Replace hardcoded animation values with animation tokens.

**Example Transformations:**

```swift
// Before
.animation(.spring(response: 0.45, dampingFraction: 0.8), value: someValue)

// After
.animation(ONEAnimation.cardSpring, value: someValue)

// Before
.animation(.easeInOut(duration: 1.4), value: mood)

// After
.animation(.easeInOut(duration: ONEAnimation.durationMoodBg), value: mood)

// Before
Animation.spring(response: 0.3, dampingFraction: 0.7)

// After
ONEAnimation.micro
```

**Matching Strategy:**
- Spring(0.45, 0.8) → `cardSpring`
- Spring(0.5, 0.85) → `panelSpring`
- Spring(0.6, 0.9) → `screenTransition`
- Duration 1.4s → `durationMoodBg`
- Duration 3.5s → `durationBreathe`

#### Phase 7: Mood System Integration

**Strategy:** Replace mood color lookups with ONEMood enum.

**Current Pattern:**
```swift
let mockMoods: [Mood] = [
    Mood(color: Color(hex: "#E84040"), word: "Tutkulu", isDark: true),
    // ...
]
```

**New Pattern:**
```swift
// Use ONEMood enum directly
let mood = ONEMood.atesli
let color = mood.color
let label = mood.label
```

**Migration Steps:**
1. Update `ONEColorPickerView.swift` to use `ONEMood` enum
2. Replace `mockMoods` array with `ONEMood.allCases`
3. Update mood selection logic
4. Update Core Data to store mood raw value (String)
5. Update mood display components

**Backward Compatibility:**
- Existing Core Data entries store hex strings
- Use `ONEMood(hex:)` initializer to convert legacy data
- Gradually migrate stored data to use mood raw values

### Migration Checklist

- [ ] Phase 1: Create all 7 design system files
- [ ] Phase 1: Verify compilation
- [ ] Phase 2: Migrate colors in TodayCompletedView
- [ ] Phase 2: Migrate colors in DayDetailView
- [ ] Phase 2: Migrate colors in CircleView
- [ ] Phase 2: Migrate colors in ArchiveView
- [ ] Phase 2: Migrate colors in MonthArchiveView
- [ ] Phase 2: Migrate colors in YearArchiveView
- [ ] Phase 2: Migrate colors in PersonDetailBackground
- [ ] Phase 2: Migrate colors in ONEColorPickerView
- [ ] Phase 2: Migrate colors in all remaining files
- [ ] Phase 3: Migrate typography in all files
- [ ] Phase 4: Migrate spacing in all files
- [ ] Phase 5: Migrate border radius in all files
- [ ] Phase 6: Migrate animations in all files
- [ ] Phase 7: Integrate ONEMood enum
- [ ] Verify: App compiles without errors
- [ ] Verify: All screens render identically
- [ ] Verify: No animation regressions
- [ ] Verify: Mood system works correctly
- [ ] Test: Run unit tests
- [ ] Test: Run property-based tests
- [ ] Test: Manual visual regression testing

### Rollback Strategy

If issues are discovered during migration:

1. **Git Branching:** Perform migration in a feature branch
2. **Incremental Commits:** Commit after each phase
3. **Testing Between Phases:** Verify app works after each phase
4. **Rollback Point:** Can revert to any phase if needed

### Risk Mitigation

**Risk:** Visual regressions
**Mitigation:** Screenshot comparison, manual testing, incremental migration

**Risk:** Performance impact
**Mitigation:** Profile app before and after, ensure no performance degradation

**Risk:** Breaking existing features
**Mitigation:** Comprehensive testing, feature flags for gradual rollout

**Risk:** Merge conflicts
**Mitigation:** Coordinate with team, migrate in short timeframe



## Backward Compatibility

### Zero Breaking Changes Guarantee

This migration maintains 100% backward compatibility:

1. **Visual Appearance:** All colors, fonts, spacing, and animations remain pixel-perfect identical
2. **API Surface:** No public APIs are removed or changed
3. **Data Persistence:** Existing Core Data entries continue to work
4. **User Experience:** No user-facing changes or disruptions

### Legacy Data Handling

#### Mood Hex Strings

**Problem:** Existing Core Data entries store mood colors as hex strings (e.g., "#E84040")

**Solution:** The `ONEMood.init?(hex:)` initializer converts legacy hex strings to mood enum values:

```swift
// Legacy data
let hexString = "#E84040"

// Convert to new enum
if let mood = ONEMood(hex: hexString) {
    // Use mood enum
    let color = mood.color
    let label = mood.label
}
```

**Migration Path:**
1. Read legacy hex string from Core Data
2. Convert to ONEMood using `init?(hex:)`
3. Use mood enum for display
4. Optionally: Update Core Data to store mood.rawValue for future reads

#### Color Utilities

**Problem:** Existing code uses `Color.moodToGradient(hex:)` utility

**Solution:** Maintain the utility for backward compatibility, but deprecate in favor of `ONEMood.gradientStops`:

```swift
extension Color {
    /// Converts mood color to dark gradient stops
    /// - Deprecated: Use ONEMood.gradientStops instead
    @available(*, deprecated, message: "Use ONEMood.gradientStops instead")
    static func moodToGradient(hex: String) -> [Color] {
        // Keep existing implementation for compatibility
        let moodColor = Color(hex: hex.isEmpty ? "#5B8DEF" : hex)
        let darkBase = ONETokens.oneVoid
        return [
            moodColor,
            moodColor.opacity(0.4),
            darkBase
        ]
    }
}
```

### Gradual Adoption

The design system can be adopted gradually:

**Phase 1:** New code uses design tokens
- All new views use `ONETokens`, `ONETypography`, etc.
- Existing views remain unchanged

**Phase 2:** Migrate high-traffic views
- Update main screens (Today, Circle, Archive)
- Verify no regressions

**Phase 3:** Migrate remaining views
- Update all other views
- Remove deprecated utilities

**Phase 4:** Cleanup
- Remove legacy color utilities
- Update documentation
- Remove deprecation warnings

### iOS Version Compatibility

**Minimum iOS Version:** iOS 15.0

All design tokens use APIs available in iOS 15+:
- `Color` initializers
- `Font.custom()`
- SwiftUI view modifiers
- `Animation.spring()`
- `Codable` protocol

**No iOS 16+ APIs used:** The design system works on iOS 15 devices.

### Xcode Compatibility

**Minimum Xcode Version:** Xcode 13.0

The design system uses Swift 5.5 features:
- Enums with computed properties
- Protocol conformance
- View modifiers
- Property wrappers

**No Swift 5.7+ features used:** Compatible with Xcode 13+.



## Implementation Examples

### Example 1: Migrating a Simple View

**Before:**
```swift
struct SimpleCard: View {
    var body: some View {
        VStack(spacing: 12) {
            Text("Hello")
                .font(.custom("Fraunces-LightItalic", size: 34))
                .italic()
                .foregroundColor(Color(hex: "#111112"))
            
            Text("World")
                .font(.custom("GeistMono-Regular", size: 11))
                .tracking(1.8)
                .foregroundColor(Color(hex: "#BFBDB5"))
        }
        .padding(16)
        .background(Color(hex: "#F7F6F3"))
        .cornerRadius(13)
    }
}
```

**After:**
```swift
struct SimpleCard: View {
    var body: some View {
        VStack(spacing: ONETokens.spacingMD) {
            Text("Hello")
                .displayLG()
                .primaryText()
            
            Text("World")
                .monoBase()
                .secondaryText()
        }
        .padding(ONETokens.spacingLG)
        .background(ONETokens.oneCream)
        .cornerRadius(ONETokens.radiusCard)
    }
}
```

### Example 2: Mood-Based Gradient Background

**Before:**
```swift
struct MoodBackground: View {
    let moodHex: String
    
    var body: some View {
        let colors = Color.moodToGradient(hex: moodHex)
        
        LinearGradient(
            gradient: Gradient(colors: colors),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}
```

**After:**
```swift
struct MoodBackground: View {
    let mood: ONEMood
    
    var body: some View {
        LinearGradient(
            gradient: Gradient(colors: mood.gradientStops),
            startPoint: mood.gradientStart,
            endPoint: mood.gradientEnd
        )
    }
}
```

### Example 3: Animated Button

**Before:**
```swift
struct AnimatedButton: View {
    @State private var isPressed = false
    
    var body: some View {
        Text("Press Me")
            .font(.custom("GeistMono-Regular", size: 11))
            .tracking(1.8)
            .foregroundColor(Color(hex: "#F7F6F3"))
            .padding(.vertical, 14)
            .padding(.horizontal, 26)
            .background(Color(hex: "#111112"))
            .cornerRadius(13)
            .scaleEffect(isPressed ? 0.96 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.6), value: isPressed)
    }
}
```

**After:**
```swift
struct AnimatedButton: View {
    @State private var isPressed = false
    
    var body: some View {
        Text("Press Me")
            .monoBase()
            .foregroundColor(ONETokens.oneCream)
            .padding(.vertical, 14)
            .standardHorizontalPadding()
            .background(ONETokens.oneInk)
            .cornerRadius(ONETokens.radiusCard)
            .buttonPressEffect(isPressed: isPressed)
    }
}
```

### Example 4: Mood Picker

**Before:**
```swift
struct MoodPicker: View {
    @Binding var selectedMood: Mood?
    
    let moods = [
        Mood(color: Color(hex: "#E84040"), word: "Ateşli", isDark: true),
        Mood(color: Color(hex: "#FF8C42"), word: "Enerjik", isDark: true),
        // ... more moods
    ]
    
    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 12) {
                ForEach(moods) { mood in
                    Circle()
                        .fill(mood.color)
                        .frame(width: 44, height: 44)
                        .overlay(
                            Text(mood.word)
                                .font(.custom("GeistMono-Regular", size: 9))
                        )
                }
            }
        }
    }
}
```

**After:**
```swift
struct MoodPicker: View {
    @Binding var selectedMood: ONEMood?
    
    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: ONETokens.spacingMD) {
                ForEach(ONEMood.allCases) { mood in
                    Circle()
                        .fill(mood.color)
                        .frame(width: 44, height: 44)
                        .overlay(
                            Text(mood.label)
                                .monoLabel()
                        )
                }
            }
        }
    }
}
```

### Example 5: Staggered List Animation

**Before:**
```swift
struct StaggeredList: View {
    let items: [String]
    @State private var isVisible = false
    
    var body: some View {
        VStack(spacing: 8) {
            ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                Text(item)
                    .opacity(isVisible ? 1 : 0)
                    .animation(
                        .easeOut.delay(Double(index) * 0.08),
                        value: isVisible
                    )
            }
        }
        .onAppear { isVisible = true }
    }
}
```

**After:**
```swift
struct StaggeredList: View {
    let items: [String]
    @State private var isVisible = false
    
    var body: some View {
        VStack(spacing: ONETokens.spacingSM) {
            ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                Text(item)
                    .opacity(isVisible ? 1 : 0)
                    .animation(
                        .easeOut.delay(ONEAnimation.staggerDelay(index: index)),
                        value: isVisible
                    )
            }
        }
        .onAppear { isVisible = true }
    }
}
```

### Example 6: Custom Toggle

**Before:**
```swift
struct CustomToggle: View {
    @Binding var isOn: Bool
    
    var body: some View {
        HStack {
            Text("Setting")
            Spacer()
            ZStack {
                Capsule()
                    .fill(isOn ? Color(hex: "#5B8DEF") : Color(hex: "#D8D6D0"))
                    .frame(width: 44, height: 26)
                
                Circle()
                    .fill(Color.white)
                    .frame(width: 22, height: 22)
                    .offset(x: isOn ? 9 : -9)
            }
            .onTapGesture {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    isOn.toggle()
                }
            }
        }
    }
}
```

**After:**
```swift
struct CustomToggle: View {
    @Binding var isOn: Bool
    
    var body: some View {
        Toggle("Setting", isOn: $isOn)
            .toggleStyle(.one)
    }
}
```

## Design Decisions and Rationale

### Why Enums Instead of Structs?

**Decision:** Use enums for `ONETokens`, `ONETypography`, and `ONEAnimation`

**Rationale:**
- Enums with static properties prevent instantiation
- Clear namespace for related constants
- Type-safe access to tokens
- No memory overhead (no instances created)

### Why Separate Files?

**Decision:** Split design system into 7 files instead of one large file

**Rationale:**
- Easier to navigate and maintain
- Clear separation of concerns
- Faster compilation (smaller files)
- Better Git diff readability
- Allows importing only needed components

### Why View Modifiers?

**Decision:** Provide view modifiers for typography and common patterns

**Rationale:**
- More concise than direct token access
- Encapsulates common patterns (e.g., italic + font)
- Easier to update globally
- Better discoverability through autocomplete
- Follows SwiftUI conventions

### Why Keep Hex Strings in Mood Enum?

**Decision:** Store both `Color` and `hex: String` in `ONEMood`

**Rationale:**
- Backward compatibility with Core Data
- Easier debugging (hex strings are readable)
- Interop with external systems
- No conversion overhead (pre-computed)

### Why 3-Stop Gradients?

**Decision:** Use 3-stop gradients (mood color → 40% opacity → dark base)

**Rationale:**
- Matches existing Wabi-Sabi aesthetic
- Creates smooth color transitions
- Maintains visual consistency
- Tested and approved design

### Why Separate Mono and Display Scales?

**Decision:** Two typography scales instead of one unified scale

**Rationale:**
- Different use cases (emotional vs. technical)
- Different font families (Fraunces vs. Geist Mono)
- Clear semantic meaning
- Prevents misuse (e.g., using mono for headings)

### Why Include Wave Height in Mood?

**Decision:** Store `waveHeight` as a mood property

**Rationale:**
- Each mood has unique wave animation
- Centralizes mood-related properties
- Easier to adjust per-mood
- Maintains consistency across views

## Future Enhancements

### Dark Mode Support

Currently, the design system uses light mode colors. Future enhancement:

```swift
extension ONETokens {
    static var oneCream: Color {
        Color(light: "#F7F6F3", dark: "#1A1A1B")
    }
}
```

### Theme System

Support for multiple themes (Wabi-Sabi, Minimalist, Vibrant):

```swift
enum ONETheme {
    case wabiSabi
    case minimalist
    case vibrant
}

extension ONETokens {
    static func color(for theme: ONETheme) -> Color {
        // Return theme-specific colors
    }
}
```

### Accessibility Tokens

Add tokens for accessibility features:

```swift
extension ONETokens {
    static let minimumTouchTarget: CGFloat = 44
    static let highContrastRatio: CGFloat = 7.0
}
```

### Responsive Spacing

Add spacing that adapts to screen size:

```swift
extension ONETokens {
    static func spacing(_ size: SpacingSize, for screenSize: CGSize) -> CGFloat {
        // Return responsive spacing
    }
}
```

## Conclusion

This design system provides a comprehensive, type-safe foundation for the ONE app's visual design. By centralizing all design tokens, we enable:

- Consistent visual language across the app
- Easy theme updates and design iterations
- Improved code maintainability
- Better developer experience
- Zero breaking changes during migration

The migration strategy ensures a smooth transition from hardcoded values to design tokens, with comprehensive testing and backward compatibility guarantees.

