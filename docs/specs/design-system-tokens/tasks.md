# Implementation Plan: Design System Tokens

## Overview

This implementation plan creates a comprehensive design token system for the ONE app, centralizing all visual design attributes (colors, typography, spacing, border radius, animations, and moods) into a single source of truth. The migration will eliminate hardcoded values throughout the codebase while maintaining pixel-perfect visual fidelity.

The implementation follows a phased approach: first creating the design system files, then systematically migrating all view files to use the new tokens, and finally verifying correctness through comprehensive testing.

## Tasks

- [x] 1. Create design system file structure
  - Create `one/one/DesignSystem/` folder
  - Set up proper file organization for 7 token files
  - _Requirements: 1.1, 1.2, 1.3, 1.4, 1.5, 1.6, 1.7, 1.8_

- [x] 2. Implement core design token files
  - [x] 2.1 Implement Color+ONE.swift with hex color initialization
    - Create hex string initializer supporting 3, 6, and 8 character formats
    - Handle hex strings with or without "#" prefix
    - Implement proper RGB/RGBA parsing
    - _Requirements: 12.1, 12.2, 12.3, 12.4, 12.5_
  
  - [x] 2.2 Write property test for hex color round-trip
    - **Property 3: Hex Color Round-Trip**
    - **Validates: Requirements 12.2, 12.3, 12.4, 12.5**
  
  - [x] 2.3 Implement ONETokens.swift with color palette, spacing, and radius tokens
    - Define all 8 neutral color tokens (oneCream through oneVoid)
    - Define 3 accent color tokens (oneBlue, oneGreen, oneRed)
    - Define all 9 spacing tokens (spacingXS through spacingXL5)
    - Define all 8 border radius tokens (radiusTag through radiusScreen)
    - _Requirements: 2.1, 2.2, 2.3, 2.4, 2.5, 2.6, 2.7, 2.8, 2.9, 6.1, 6.2, 6.3, 6.4, 6.5, 6.6, 6.7, 6.8, 6.9, 7.1, 7.2, 7.3, 7.4, 7.5, 7.6, 7.7, 7.8_
  
  - [x] 2.4 Implement ONEMood.swift with mood system
    - Define ONEMood enum with 8 cases (atesli, enerjik, isikli, sakin, derin, gizemli, bos, temiz)
    - Implement color, hex, label, meaning, isDark, waveHeight properties for each mood
    - Implement gradientStops, gradientStart, gradientEnd for gradient backgrounds
    - Add Codable conformance for serialization
    - Add hex string initializer for legacy compatibility
    - _Requirements: 3.1, 3.2, 3.3, 3.4, 3.5, 3.6, 3.7, 3.8, 3.9, 3.10, 4.1, 4.2, 4.3, 4.4, 22.1, 22.2, 22.3, 22.4_
  
  - [x] 2.5 Write property test for mood completeness
    - **Property 1: Mood Completeness**
    - **Validates: Requirements 3.10**
  
  - [x] 2.6 Write property test for mood gradient configuration
    - **Property 2: Mood Gradient Configuration**
    - **Validates: Requirements 4.1, 4.2**
  
  - [x] 2.7 Write property test for mood serialization round-trip
    - **Property 4: Mood Serialization Round-Trip**
    - **Validates: Requirements 22.2**
  
  - [x] 2.8 Write property test for hex-to-mood conversion
    - **Property 5: Hex-to-Mood Conversion**
    - **Validates: Requirements 22.4**

- [ ] 3. Implement typography and animation systems
  - [x] 3.1 Implement ONETypography.swift with font scales
    - Define Display scale (displayXL, displayLG, displayMD, displaySM, displayXS, displayBody)
    - Define Mono scale (monoBase, monoSM, monoLabel, monoMicro)
    - Create view modifiers for each typography style
    - _Requirements: 5.1, 5.2, 5.3, 5.4, 5.5, 24.1, 24.2_
  
  - [x] 3.2 Implement ONEAnimation.swift with animation tokens
    - Define duration tokens (durationMicro through durationBreathe)
    - Define animation type configurations (micro, cardSpring, panelSpring, screenTransition, moodTransition)
    - Implement stagger delay calculation function
    - Define button press style configuration
    - Create breathing animation modifier
    - _Requirements: 8.1, 8.2, 8.3, 8.4, 8.5, 8.6, 8.7, 9.1, 9.2, 9.3, 9.4, 9.5, 9.6, 10.1, 10.2, 10.3, 10.4, 11.1, 11.2, 11.3, 11.4_
  
  - [x] 3.3 Implement View+ONE.swift with convenience modifiers
    - Create color combination modifiers (primaryText, secondaryText, tertiaryText, mutedText)
    - Create background modifiers (creamBackground, cardBackground)
    - Create border modifiers (cardBorder)
    - Create spacing modifiers (standardHorizontalPadding, standardVerticalPadding)
    - _Requirements: 24.3, 24.4_
  
  - [x] 3.4 Implement ONEToggleStyle.swift with toggle and navigation components
    - Create ONEToggleStyle using design tokens
    - Create NavigationPip component
    - Add toggle style extension for easy access
    - _Requirements: 25.1, 25.2, 25.3, 25.4_

- [x] 4. Checkpoint - Verify design system compilation
  - Ensure all design system files compile without errors
  - Verify files are properly added to Xcode project
  - Run build to confirm no syntax errors
  - _Requirements: 18.1, 18.2, 18.3, 19.1_

- [ ] 5. Migrate colors in high-priority view files
  - [x] 5.1 Migrate colors in TodayCompletedView.swift
    - Replace all Color(hex: "...") with appropriate ONETokens color constants
    - Verify visual appearance remains identical
    - _Requirements: 13.1, 13.2, 13.3, 13.4, 20.1_
  
  - [x] 5.2 Migrate colors in DayDetailView.swift
    - Replace all Color(hex: "...") with appropriate ONETokens color constants
    - Verify visual appearance remains identical
    - _Requirements: 13.1, 13.2, 13.3, 13.5, 20.1_
  
  - [x] 5.3 Migrate colors in CircleView.swift
    - Replace all Color(hex: "...") with appropriate ONETokens color constants
    - Verify visual appearance remains identical
    - _Requirements: 13.1, 13.2, 13.3, 13.6, 20.1_
  
  - [x] 5.4 Migrate colors in ArchiveView.swift
    - Replace all Color(hex: "...") with appropriate ONETokens color constants
    - Verify visual appearance remains identical
    - _Requirements: 13.1, 13.2, 13.3, 13.7, 20.1_
  
  - [x] 5.5 Migrate colors in MonthArchiveView.swift
    - Replace all Color(hex: "...") with appropriate ONETokens color constants
    - Verify visual appearance remains identical
    - _Requirements: 13.1, 13.2, 13.3, 13.8, 20.1_
  
  - [x] 5.6 Migrate colors in YearArchiveView.swift
    - Replace all Color(hex: "...") with appropriate ONETokens color constants
    - Verify visual appearance remains identical
    - _Requirements: 13.1, 13.2, 13.3, 13.9, 20.1_

- [ ] 6. Migrate colors in remaining view files
  - [x] 6.1 Migrate colors in PersonDetailBackground.swift
    - Replace all Color(hex: "...") with appropriate ONETokens color constants
    - Verify visual appearance remains identical
    - _Requirements: 13.1, 13.2, 13.3, 13.10, 20.1_
  
  - [x] 6.2 Migrate colors in ONEColorPickerView.swift
    - Replace all Color(hex: "...") with appropriate ONETokens color constants
    - Update to use ONEMood enum instead of mock mood array
    - Verify visual appearance remains identical
    - _Requirements: 13.1, 13.2, 13.3, 13.11, 17.1, 17.2, 17.3, 17.4, 20.1_
  
  - [x] 6.3 Migrate colors in ContentView.swift
    - Replace all Color(hex: "...") with appropriate ONETokens color constants
    - Verify visual appearance remains identical
    - _Requirements: 13.1, 13.2, 13.3, 13.12, 20.1_
  
  - [x] 6.4 Migrate colors in OnboardingView.swift
    - Replace all Color(hex: "...") with appropriate ONETokens color constants
    - Verify visual appearance remains identical
    - _Requirements: 13.1, 13.2, 13.3, 13.12, 20.1_
  
  - [x] 6.5 Migrate colors in SplashScreen.swift
    - Replace all Color(hex: "...") with appropriate ONETokens color constants
    - Verify visual appearance remains identical
    - _Requirements: 13.1, 13.2, 13.3, 13.12, 20.1_
  
  - [x] 6.6 Migrate colors in AddFriendView.swift
    - Replace all Color(hex: "...") with appropriate ONETokens color constants
    - Verify visual appearance remains identical
    - _Requirements: 13.1, 13.2, 13.3, 13.12, 20.1_
  
  - [x] 6.7 Migrate colors in WaveStrip.swift
    - Replace all Color(hex: "...") with appropriate ONETokens color constants
    - Update to use ONEMood.waveHeight property
    - Verify visual appearance remains identical
    - _Requirements: 13.1, 13.2, 13.3, 13.12, 17.1, 17.2, 20.1_
  
  - [x] 6.8 Migrate colors in FeelingIconView.swift
    - Replace all Color(hex: "...") with appropriate ONETokens color constants
    - Verify visual appearance remains identical
    - _Requirements: 13.1, 13.2, 13.3, 13.12, 20.1_
  
  - [x] 6.9 Migrate colors in CircleShareToggle.swift
    - Replace all Color(hex: "...") with appropriate ONETokens color constants
    - Verify visual appearance remains identical
    - _Requirements: 13.1, 13.2, 13.3, 13.12, 20.1_
  
  - [x] 6.10 Migrate colors in PhotoPickerView.swift
    - Replace all Color(hex: "...") with appropriate ONETokens color constants
    - Verify visual appearance remains identical
    - _Requirements: 13.1, 13.2, 13.3, 13.12, 20.1_
  
  - [x] 6.11 Migrate colors in StoryCardView.swift and related story card files
    - Replace all Color(hex: "...") with appropriate ONETokens color constants
    - Update StoryCardShareView.swift, StoryCardGenerator.swift, StoryCardViewModel.swift
    - Verify visual appearance remains identical
    - _Requirements: 13.1, 13.2, 13.3, 13.12, 20.1_

- [x] 7. Checkpoint - Verify color migration
  - Build and run app to verify all colors render correctly
  - Manually test all major screens for visual consistency
  - Ensure no color-related compilation errors
  - _Requirements: 19.1, 19.2, 20.1, 20.3_

- [x] 8. Migrate typography in all view files
  - [x] 8.1 Migrate typography in main view files
    - Replace hardcoded Fraunces fonts with Display scale modifiers
    - Replace hardcoded Geist Mono fonts with Mono scale modifiers
    - Update TodayCompletedView, DayDetailView, CircleView, ArchiveView
    - Verify text renders with correct fonts and sizes
    - _Requirements: 14.1, 14.2, 14.3, 14.4, 14.5, 14.6, 20.1_
  
  - [x] 8.2 Migrate typography in archive view files
    - Replace hardcoded fonts with typography tokens
    - Update MonthArchiveView, YearArchiveView
    - Verify text renders with correct fonts and sizes
    - _Requirements: 14.1, 14.2, 14.3, 14.4, 14.5, 14.6, 20.1_
  
  - [x] 8.3 Migrate typography in UI component files
    - Replace hardcoded fonts with typography tokens
    - Update ONEColorPickerView, WaveStrip, FeelingIconView, CircleShareToggle
    - Verify text renders with correct fonts and sizes
    - _Requirements: 14.1, 14.2, 14.3, 14.4, 14.5, 14.6, 20.1_
  
  - [x] 8.4 Migrate typography in onboarding and splash screens
    - Replace hardcoded fonts with typography tokens
    - Update OnboardingView, SplashScreen, ContentView
    - Verify text renders with correct fonts and sizes
    - _Requirements: 14.1, 14.2, 14.3, 14.4, 14.5, 14.6, 20.1_
  
  - [x] 8.5 Migrate typography in story card files
    - Replace hardcoded fonts with typography tokens
    - Update StoryCardView, StoryCardShareView, StoryCardGenerator
    - Verify text renders with correct fonts and sizes
    - _Requirements: 14.1, 14.2, 14.3, 14.4, 14.5, 14.6, 20.1_

- [x] 9. Migrate spacing and border radius values
  - [x] 9.1 Migrate spacing in main view files
    - Replace hardcoded padding/spacing values with spacing tokens
    - Update TodayCompletedView, DayDetailView, CircleView, ArchiveView
    - Only replace values that exactly match token scale
    - Verify layout remains identical
    - _Requirements: 15.1, 15.2, 15.3, 15.4, 20.1, 20.3_
  
  - [x] 9.2 Migrate border radius in main view files
    - Replace hardcoded cornerRadius values with radius tokens
    - Update TodayCompletedView, DayDetailView, CircleView, ArchiveView
    - Only replace values that exactly match token scale
    - Verify visual appearance remains identical
    - _Requirements: 15.1, 15.2, 15.3, 15.5, 20.1, 20.3_
  
  - [x] 9.3 Migrate spacing and radius in archive views
    - Replace hardcoded spacing and radius values with tokens
    - Update MonthArchiveView, YearArchiveView
    - Verify layout and appearance remain identical
    - _Requirements: 15.1, 15.2, 15.3, 15.4, 15.5, 20.1, 20.3_
  
  - [x] 9.4 Migrate spacing and radius in UI components
    - Replace hardcoded spacing and radius values with tokens
    - Update ONEColorPickerView, WaveStrip, FeelingIconView, CircleShareToggle, PhotoPickerView
    - Verify layout and appearance remain identical
    - _Requirements: 15.1, 15.2, 15.3, 15.4, 15.5, 20.1, 20.3_
  
  - [x] 9.5 Migrate spacing and radius in remaining files
    - Replace hardcoded spacing and radius values with tokens
    - Update OnboardingView, SplashScreen, ContentView, AddFriendView, story card files
    - Verify layout and appearance remain identical
    - _Requirements: 15.1, 15.2, 15.3, 15.4, 15.5, 20.1, 20.3_

- [x] 10. Migrate animation values
  - [x] 10.1 Migrate animations in main view files
    - Replace hardcoded animation durations with duration tokens
    - Replace hardcoded spring configurations with animation type tokens
    - Update TodayCompletedView, DayDetailView, CircleView, ArchiveView
    - Verify animations feel identical
    - _Requirements: 16.1, 16.2, 16.3, 16.4, 20.1, 20.2_
  
  - [x] 10.2 Migrate animations in mood-related files
    - Replace mood background transition animations with ONEAnimation.durationMoodBg
    - Update ONEColorPickerView, WaveStrip, PersonDetailBackground
    - Verify mood transitions feel identical
    - _Requirements: 16.1, 16.2, 16.3, 16.4, 20.1, 20.2_
  
  - [x] 10.3 Migrate animations in UI components
    - Replace hardcoded animations with animation tokens
    - Update CircleShareToggle, FeelingIconView, PhotoPickerView
    - Verify animations feel identical
    - _Requirements: 16.1, 16.2, 16.3, 16.4, 20.1, 20.2_
  
  - [x] 10.4 Migrate stagger animations in list views
    - Replace hardcoded stagger delays with ONEAnimation.staggerDelay()
    - Update archive views and any list animations
    - Verify stagger timing feels identical
    - _Requirements: 16.1, 16.2, 16.3, 16.4, 20.1, 20.2_

- [x] 11. Checkpoint - Verify complete migration
  - Build and run app to verify all migrations are complete
  - Test all major screens and interactions
  - Verify no hardcoded design values remain in migrated files
  - Ensure app compiles without errors or warnings
  - _Requirements: 19.1, 19.2, 19.3, 20.1, 20.2, 20.3, 20.4_

- [x] 12. Write unit tests for design tokens
  - [x] 12.1 Write unit tests for color tokens
    - Test neutral color palette values
    - Test accent color values
    - Test hex color parsing edge cases
    - _Requirements: 2.1, 2.2, 2.3, 2.4, 2.5, 2.6, 2.7, 2.8, 2.9, 12.1, 12.2_
  
  - [x] 12.2 Write unit tests for mood properties
    - Test each mood has correct color, hex, label, meaning
    - Test isDark property for each mood
    - Test waveHeight values
    - Test gradient configuration
    - _Requirements: 3.1, 3.2, 3.3, 3.4, 3.5, 3.6, 3.7, 3.8, 3.9, 3.10_
  
  - [x] 12.3 Write unit tests for spacing and radius tokens
    - Test all spacing token values
    - Test all radius token values
    - _Requirements: 6.1, 6.2, 6.3, 6.4, 6.5, 6.6, 6.7, 6.8, 6.9, 7.1, 7.2, 7.3, 7.4, 7.5, 7.6, 7.7, 7.8_
  
  - [x] 12.4 Write unit tests for typography tokens
    - Test Display scale font definitions
    - Test Mono scale font definitions
    - Verify font sizes and families
    - _Requirements: 5.1, 5.2, 5.3_
  
  - [x] 12.5 Write unit tests for animation tokens
    - Test duration token values
    - Test spring configuration values
    - Test stagger delay calculation
    - Test button press style values
    - _Requirements: 8.1, 8.2, 8.3, 8.4, 8.5, 8.6, 8.7, 9.1, 9.2, 9.3, 9.4, 9.5, 9.6, 10.1, 10.2, 10.3, 10.4, 11.1, 11.2, 11.3, 11.4_

- [x] 13. Perform visual regression testing
  - [x] 13.1 Test main screens for visual consistency
    - Compare before/after screenshots of Today view
    - Compare before/after screenshots of Confirm screen with mood selection
    - Verify pixel-perfect match or document intentional changes
    - _Requirements: 20.1, 20.3_
  
  - [x] 13.2 Test archive views for visual consistency
    - Compare before/after screenshots of Archive view
    - Compare before/after screenshots of Month archive
    - Compare before/after screenshots of Year archive
    - Verify pixel-perfect match
    - _Requirements: 20.1, 20.3_
  
  - [x] 13.3 Test Circle and social features for visual consistency
    - Compare before/after screenshots of Circle view
    - Compare before/after screenshots of friend cards
    - Compare before/after screenshots of story cards
    - Verify pixel-perfect match
    - _Requirements: 20.1, 20.3_
  
  - [x] 13.4 Test animations and transitions
    - Verify mood transitions feel identical
    - Verify button press animations feel identical
    - Verify list stagger animations feel identical
    - Verify wave animations feel identical
    - _Requirements: 20.2_

- [x] 14. Update documentation with design token usage
  - [x] 14.1 Add inline documentation to design token files
    - Add comments describing purpose of each color token
    - Add comments describing usage of each typography token
    - Add comments describing typical use cases for spacing tokens
    - Add comments describing which components use each radius token
    - Add comments describing intended effect of each animation token
    - _Requirements: 21.1, 21.2, 21.3, 21.4, 21.5_
  
  - [x] 14.2 Document accessibility considerations
    - Add comments noting contrast relationships for color tokens
    - Document that migration preserves existing accessibility properties
    - _Requirements: 23.1, 23.2, 23.3_

- [x] 15. Final verification and cleanup
  - Run full test suite to ensure all tests pass
  - Verify app builds without errors or warnings
  - Perform final manual testing of all features
  - Ensure all requirements are met
  - _Requirements: 19.1, 19.2, 19.3, 20.1, 20.2, 20.3, 20.4_

## Notes

- Tasks marked with `*` are optional and can be skipped for faster MVP
- Each task references specific requirements for traceability
- Checkpoints ensure incremental validation at key milestones
- Property tests validate universal correctness properties
- Unit tests validate specific examples and edge cases
- Visual regression testing ensures zero breaking changes to UI/UX
- Migration is performed incrementally to minimize risk
- All design token files use Swift and are compatible with iOS 15+
