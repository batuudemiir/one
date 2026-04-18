# Requirements Document

## Introduction

This document specifies requirements for implementing a comprehensive design system with centralized design tokens for the ONE app. The design system will provide a single source of truth for colors, typography, spacing, border radius, animations, and the mood system. This will eliminate hardcoded values throughout the codebase, improve consistency, and enable easier theme updates.

## Glossary

- **Design_Token**: A named constant representing a visual design attribute (color, spacing, font, etc.)
- **Token_File**: A Swift file containing related design token definitions
- **Mood**: One of eight emotional states with associated colors and visual properties
- **Mood_System**: The collection of mood definitions and their visual representations
- **Color_Token**: A named Color constant in the design system
- **Typography_Token**: A named font style definition with size, weight, and family
- **Spacing_Token**: A named CGFloat constant for consistent spacing values
- **Radius_Token**: A named CGFloat constant for border radius values
- **Animation_Token**: A named constant for animation duration or spring configuration
- **View_Modifier**: A SwiftUI modifier that applies design token styles
- **Legacy_Code**: Existing view files with hardcoded design values
- **Hex_Color**: A color defined using hexadecimal notation (e.g., "#FFFFFF")
- **Neutral_Palette**: The set of grayscale color tokens from cream to black
- **Display_Scale**: Typography scale using Fraunces font for headings
- **Mono_Scale**: Typography scale using Geist Mono font for code/labels
- **Gradient_Background**: A view component displaying mood-specific gradient
- **Wave_Height**: A CGFloat value determining mood wave animation amplitude
- **Stagger_Animation**: Sequential animation with delay between list items
- **Button_Press_Style**: Visual feedback configuration for button interactions
- **Round_Trip_Property**: A property where serialization followed by deserialization returns the original value

## Requirements

### Requirement 1: Design Token File Structure

**User Story:** As a developer, I want design tokens organized in separate files by category, so that I can easily find and maintain related tokens.

#### Acceptance Criteria

1. THE Token_File_System SHALL contain exactly seven Token_Files in the DesignSystem folder
2. THE Token_File_System SHALL include ONETokens.swift for colors, spacing, and border radius
3. THE Token_File_System SHALL include ONETypography.swift for font styles and scales
4. THE Token_File_System SHALL include ONEAnimation.swift for animation durations and configurations
5. THE Token_File_System SHALL include ONEMood.swift for mood definitions and properties
6. THE Token_File_System SHALL include Color+ONE.swift for color utilities and hex initialization
7. THE Token_File_System SHALL include View+ONE.swift for view modifiers
8. THE Token_File_System SHALL include ONEToggleStyle.swift for toggle and navigation pip components

### Requirement 2: Neutral Color Palette

**User Story:** As a designer, I want a consistent neutral color palette, so that grayscale colors are used consistently throughout the app.

#### Acceptance Criteria

1. THE Neutral_Palette SHALL define oneCream as the lightest neutral color
2. THE Neutral_Palette SHALL define oneCreamMid as a mid-light neutral color
3. THE Neutral_Palette SHALL define oneCreamLow as a low-light neutral color
4. THE Neutral_Palette SHALL define oneStone as a light-medium neutral color
5. THE Neutral_Palette SHALL define oneAsh as a medium neutral color
6. THE Neutral_Palette SHALL define oneCharcoal as a medium-dark neutral color
7. THE Neutral_Palette SHALL define oneInk as a dark neutral color
8. THE Neutral_Palette SHALL define oneVoid as the darkest neutral color
9. WHEN a developer needs a grayscale color, THE Neutral_Palette SHALL provide the appropriate Color_Token

### Requirement 3: Mood System Definition

**User Story:** As a user, I want my emotional state represented by consistent mood colors, so that the app reflects my feelings accurately.

#### Acceptance Criteria

1. THE Mood_System SHALL define exactly eight Mood values
2. THE Mood_System SHALL include atesli (fiery) with its associated color and properties
3. THE Mood_System SHALL include enerjik (energetic) with its associated color and properties
4. THE Mood_System SHALL include isikli (luminous) with its associated color and properties
5. THE Mood_System SHALL include sakin (calm) with its associated color and properties
6. THE Mood_System SHALL include derin (deep) with its associated color and properties
7. THE Mood_System SHALL include gizemli (mysterious) with its associated color and properties
8. THE Mood_System SHALL include bos (empty) with its associated color and properties
9. THE Mood_System SHALL include temiz (clean) with its associated color and properties
10. FOR EACH Mood, THE Mood_System SHALL provide color, hex value, label, meaning, gradient background configuration, and Wave_Height

### Requirement 4: Mood Gradient Background Component

**User Story:** As a user, I want mood-specific gradient backgrounds, so that the visual atmosphere matches my emotional state.

#### Acceptance Criteria

1. THE Gradient_Background SHALL render a gradient based on the provided Mood
2. WHEN a Mood is provided, THE Gradient_Background SHALL use the mood's gradient configuration
3. THE Gradient_Background SHALL support all eight Mood values
4. THE Gradient_Background SHALL integrate with existing mood display views

### Requirement 5: Typography Scale System

**User Story:** As a developer, I want predefined typography scales, so that text styling is consistent across the app.

#### Acceptance Criteria

1. THE Display_Scale SHALL define XL, LG, MD, SM, XS, and Body styles using Fraunces font
2. THE Mono_Scale SHALL define Base, SM, Label, and Micro styles using Geist Mono font
3. FOR EACH typography style, THE Typography_Token SHALL specify font family, size, and weight
4. THE Typography_Token SHALL provide View_Modifier extensions for easy application
5. WHEN a developer applies a typography View_Modifier, THE view SHALL render with the correct font properties

### Requirement 6: Spacing Token System

**User Story:** As a developer, I want standardized spacing values, so that layout spacing is consistent throughout the app.

#### Acceptance Criteria

1. THE Spacing_Token SHALL define xs as 4 points
2. THE Spacing_Token SHALL define sm as 8 points
3. THE Spacing_Token SHALL define md as 12 points
4. THE Spacing_Token SHALL define lg as 16 points
5. THE Spacing_Token SHALL define xl as 22 points
6. THE Spacing_Token SHALL define xl2 as 26 points
7. THE Spacing_Token SHALL define xl3 as 36 points
8. THE Spacing_Token SHALL define xl4 as 52 points
9. THE Spacing_Token SHALL define xl5 as 72 points

### Requirement 7: Border Radius Token System

**User Story:** As a developer, I want standardized border radius values, so that rounded corners are consistent across components.

#### Acceptance Criteria

1. THE Radius_Token SHALL define tag as 6 points
2. THE Radius_Token SHALL define toggle as 10 points
3. THE Radius_Token SHALL define cover as 12 points
4. THE Radius_Token SHALL define card as 13 points
5. THE Radius_Token SHALL define cardLg as 16 points
6. THE Radius_Token SHALL define friend as 18 points
7. THE Radius_Token SHALL define sheet as 20 points
8. THE Radius_Token SHALL define screen as 42 points

### Requirement 8: Animation Duration Tokens

**User Story:** As a developer, I want standardized animation durations, so that timing is consistent across all animations.

#### Acceptance Criteria

1. THE Animation_Token SHALL define micro duration for very quick animations
2. THE Animation_Token SHALL define short duration for quick animations
3. THE Animation_Token SHALL define medium duration for standard animations
4. THE Animation_Token SHALL define long duration for slow animations
5. THE Animation_Token SHALL define moodBg duration for mood background transitions
6. THE Animation_Token SHALL define pulse duration for pulsing animations
7. THE Animation_Token SHALL define breathe duration for breathing animations

### Requirement 9: Animation Type Configurations

**User Story:** As a developer, I want predefined spring animation configurations, so that animations feel consistent and natural.

#### Acceptance Criteria

1. THE Animation_Token SHALL define micro animation type for subtle interactions
2. THE Animation_Token SHALL define cardSpring animation type for card movements
3. THE Animation_Token SHALL define panelSpring animation type for panel transitions
4. THE Animation_Token SHALL define screenTransition animation type for screen changes
5. THE Animation_Token SHALL define moodTransition animation type for mood changes
6. FOR EACH animation type, THE Animation_Token SHALL specify spring response and damping values

### Requirement 10: Stagger Animation Support

**User Story:** As a developer, I want stagger animation utilities, so that list items can animate in sequence.

#### Acceptance Criteria

1. THE Animation_Token SHALL provide a stagger delay calculation function
2. WHEN given an index and base delay, THE stagger function SHALL return the appropriate delay for that item
3. THE stagger function SHALL support configurable base delay values
4. THE stagger function SHALL enable sequential animation of list items

### Requirement 11: Button Press Style Configuration

**User Story:** As a developer, I want standardized button press feedback, so that all buttons respond consistently to user interaction.

#### Acceptance Criteria

1. THE Button_Press_Style SHALL define scale limits for button press animations
2. THE Button_Press_Style SHALL define animation parameters for press and release
3. WHEN a button is pressed, THE Button_Press_Style SHALL apply the defined scale transformation
4. WHEN a button is released, THE Button_Press_Style SHALL return to normal scale

### Requirement 12: Color Hex Initialization Utility

**User Story:** As a developer, I want to initialize colors from hex strings, so that I can define Color_Tokens from hex values.

#### Acceptance Criteria

1. THE Color+ONE SHALL provide a hex string initializer for Color
2. WHEN given a valid hex string, THE hex initializer SHALL create the corresponding Color
3. THE hex initializer SHALL support 6-character hex strings (RGB)
4. THE hex initializer SHALL support 8-character hex strings (RGBA)
5. THE hex initializer SHALL handle hex strings with or without the "#" prefix

### Requirement 13: Legacy Code Migration - Color Replacement

**User Story:** As a developer, I want all hardcoded colors replaced with tokens, so that color changes can be made centrally.

#### Acceptance Criteria

1. WHEN Legacy_Code contains Color(hex: "#..."), THE code SHALL be updated to use the appropriate Color_Token
2. THE migration SHALL replace all Hex_Color instances in view files
3. THE migration SHALL maintain existing visual appearance
4. THE migration SHALL update TodayCompletedView.swift to use Color_Tokens
5. THE migration SHALL update DayDetailView.swift to use Color_Tokens
6. THE migration SHALL update CircleView.swift to use Color_Tokens
7. THE migration SHALL update ArchiveView.swift to use Color_Tokens
8. THE migration SHALL update MonthArchiveView.swift to use Color_Tokens
9. THE migration SHALL update YearArchiveView.swift to use Color_Tokens
10. THE migration SHALL update PersonDetailBackground.swift to use Color_Tokens
11. THE migration SHALL update ONEColorPickerView.swift to use Color_Tokens
12. THE migration SHALL update all other view files containing Hex_Colors

### Requirement 14: Legacy Code Migration - Typography Replacement

**User Story:** As a developer, I want all hardcoded fonts replaced with typography tokens, so that font changes can be made centrally.

#### Acceptance Criteria

1. WHEN Legacy_Code contains hardcoded font names, THE code SHALL be updated to use Typography_Tokens
2. WHEN Legacy_Code contains hardcoded font sizes, THE code SHALL be updated to use Typography_Tokens
3. THE migration SHALL replace all hardcoded Fraunces font references
4. THE migration SHALL replace all hardcoded Geist Mono font references
5. THE migration SHALL maintain existing text appearance
6. THE migration SHALL update all view files containing hardcoded fonts

### Requirement 15: Legacy Code Migration - Spacing and Radius Replacement

**User Story:** As a developer, I want all hardcoded spacing and radius values replaced with tokens, so that layout can be adjusted centrally.

#### Acceptance Criteria

1. WHEN Legacy_Code contains hardcoded spacing values matching Spacing_Tokens, THE code SHALL use the appropriate Spacing_Token
2. WHEN Legacy_Code contains hardcoded corner radius values matching Radius_Tokens, THE code SHALL use the appropriate Radius_Token
3. THE migration SHALL maintain existing layout appearance
4. THE migration SHALL update all view files with hardcoded spacing values
5. THE migration SHALL update all view files with hardcoded corner radius values

### Requirement 16: Legacy Code Migration - Animation Replacement

**User Story:** As a developer, I want all hardcoded animations replaced with animation tokens, so that animation timing is consistent.

#### Acceptance Criteria

1. WHEN Legacy_Code contains hardcoded animation durations, THE code SHALL use Animation_Tokens
2. WHEN Legacy_Code contains hardcoded spring configurations, THE code SHALL use Animation_Tokens
3. THE migration SHALL maintain existing animation feel
4. THE migration SHALL update all view files with hardcoded animation values

### Requirement 17: Legacy Code Migration - Mood System Integration

**User Story:** As a developer, I want all mood-related code to use the Mood enum, so that mood handling is centralized.

#### Acceptance Criteria

1. WHEN Legacy_Code references mood colors directly, THE code SHALL use the Mood_System
2. WHEN Legacy_Code handles mood selection, THE code SHALL use the Mood enum
3. THE migration SHALL replace hardcoded mood color mappings with Mood_System lookups
4. THE migration SHALL maintain existing mood functionality

### Requirement 18: iOS Compatibility

**User Story:** As a developer, I want the design system to support iOS 15+, so that the app runs on supported devices.

#### Acceptance Criteria

1. THE Design_Token SHALL be compatible with iOS 15 and later versions
2. THE Design_Token SHALL use only SwiftUI APIs available in iOS 15+
3. WHEN compiled for iOS 15, THE Design_Token SHALL compile without errors

### Requirement 19: Build Verification

**User Story:** As a developer, I want the app to compile after migration, so that I know the changes are syntactically correct.

#### Acceptance Criteria

1. WHEN all migrations are complete, THE app SHALL compile without errors
2. WHEN all migrations are complete, THE app SHALL compile without warnings related to design tokens
3. THE Design_Token SHALL maintain type safety throughout the codebase

### Requirement 20: Visual Regression Prevention

**User Story:** As a user, I want the app to look the same after migration, so that my experience is not disrupted.

#### Acceptance Criteria

1. WHEN the migration is complete, THE app SHALL maintain identical visual appearance
2. WHEN the migration is complete, THE app SHALL maintain identical animation behavior
3. WHEN the migration is complete, THE app SHALL maintain identical spacing and layout
4. THE migration SHALL introduce zero breaking changes to UI/UX

### Requirement 21: Design Token Documentation

**User Story:** As a developer, I want design tokens to be self-documenting, so that I understand their purpose and usage.

#### Acceptance Criteria

1. FOR EACH Color_Token, THE code SHALL include a comment describing its purpose
2. FOR EACH Typography_Token, THE code SHALL include a comment describing its usage
3. FOR EACH Spacing_Token, THE code SHALL include a comment describing typical use cases
4. FOR EACH Radius_Token, THE code SHALL include a comment describing which components use it
5. FOR EACH Animation_Token, THE code SHALL include a comment describing its intended effect

### Requirement 22: Mood System Serialization

**User Story:** As a developer, I want mood values to serialize correctly, so that mood data persists properly.

#### Acceptance Criteria

1. THE Mood enum SHALL conform to Codable protocol
2. WHEN a Mood is encoded then decoded, THE result SHALL equal the original Mood (Round_Trip_Property)
3. THE Mood enum SHALL provide string representations for persistence
4. WHEN a Mood string is parsed, THE Mood_System SHALL return the corresponding Mood value or handle invalid input

### Requirement 23: Color Token Accessibility

**User Story:** As a user with visual impairments, I want sufficient color contrast, so that I can read text clearly.

#### Acceptance Criteria

1. WHEN Color_Tokens are used for text on backgrounds, THE combination SHALL maintain existing contrast ratios
2. THE migration SHALL preserve all existing accessibility properties
3. THE Color_Token definitions SHALL include comments noting contrast relationships

### Requirement 24: View Modifier Convenience

**User Story:** As a developer, I want convenient view modifiers for common styles, so that I can apply design tokens easily.

#### Acceptance Criteria

1. THE View+ONE SHALL provide view modifiers for each Display_Scale typography style
2. THE View+ONE SHALL provide view modifiers for each Mono_Scale typography style
3. THE View+ONE SHALL provide view modifiers for common color combinations
4. WHEN a view modifier is applied, THE view SHALL render with the correct design token values

### Requirement 25: Toggle and Navigation Component Styles

**User Story:** As a developer, I want standardized toggle and navigation pip styles, so that these components are consistent.

#### Acceptance Criteria

1. THE ONEToggleStyle SHALL define a custom toggle style using design tokens
2. THE ONEToggleStyle SHALL define navigation pip components using design tokens
3. WHEN a toggle uses ONEToggleStyle, THE toggle SHALL render with design token colors and spacing
4. THE ONEToggleStyle SHALL use Radius_Tokens for corner radius values
