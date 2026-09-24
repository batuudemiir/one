# Implementation Plan: Archive View System

## Overview

This implementation plan covers the complete Archive View System for the ONE app, including data models, CoreData integration, view components, visualizations, navigation, and comprehensive testing. The system enables users to browse historical mood entries in monthly and yearly formats with rich visualizations and detailed day views.

Implementation follows a bottom-up approach: data layer first, then view components, then integration and testing. Each task references specific requirements for traceability.

## Tasks

- [x] 1. Implement core data models and enums
  - [x] 1.1 Create FeelingType enum with 8 cases
    - Define enum with cases: calm, happy, sad, anxious, excited, tired, angry, peaceful
    - Make it conform to String, CaseIterable
    - _Requirements: 14.1, 17.3_
  
  - [x] 1.2 Create DailyEntry struct
    - Define all properties: id, date, songName, artistName, genre, moodColor, moodColorHex, moodLabel, feeling, feelingLabel, time, photoURL, shareWithCircle, weatherIcon, weatherDesc, spotifyURL
    - Make it conform to Identifiable
    - _Requirements: 17.2, 17.3, 17.4_
  
  - [x] 1.3 Create MonthSummary struct with computed properties
    - Define stored properties: year, month, entries dictionary, totalDays
    - Implement monthName and monthNameShort computed properties with Turkish month names
    - Implement filledDays, moodDistribution, orderedDays, and calendarCells computed properties
    - _Requirements: 12.1, 12.2, 12.3, 12.4, 12.5, 12.6, 12.7, 12.8, 12.9_

- [ ] 2. Implement ArchiveStore with CoreData integration
  - [x] 2.1 Create ArchiveStore class as ObservableObject
    - Define @Published properties: currentMonth and yearData
    - Implement init with NSManagedObjectContext parameter
    - Implement loadData() method to populate currentMonth and yearData
    - _Requirements: 11.1, 11.2, 11.3, 11.4_
  
  - [x] 2.2 Implement CoreData fetch and transformation logic
    - Implement loadMonth(year:month:) private method with NSFetchRequest and date range predicate
    - Transform DailySong entities to DailyEntry models with nil coalescing for default values
    - Implement entry(for:) method to lookup entries by date
    - Implement formatTime() method using "HH:mm" DateFormatter pattern
    - _Requirements: 11.5, 11.6, 11.7, 11.8, 17.5, 17.6_
  
  - [x] 2.3 Add error handling for CoreData fetch failures
    - Wrap fetch requests in do-catch blocks
    - Log errors and return empty MonthSummary on failure
    - Handle date calculation failures with default totalDays of 30
    - _Requirements: 19.4, 19.5_

- [ ] 3. Implement day cell components
  - [x] 3.1 Create FilledDayCell view
    - Display day number in GeistMono-Regular 11pt
    - Apply mood color background at 0.85 opacity with 8pt corner radius
    - Add 1:1 aspect ratio modifier
    - Add conditional #111112 1.5pt stroke border when isToday is true
    - _Requirements: 13.1, 13.2, 13.3, 13.4, 13.5_
  
  - [x] 3.2 Create EmptyDayCell view
    - Display dashed border using #E8E6E0 color with 1pt stroke
    - Apply 8pt corner radius and transparent background
    - Add 1:1 aspect ratio modifier
    - _Requirements: 13.6, 13.7, 13.8, 13.9_
  
  - [x] 3.3 Write property tests for day cell components
    - **Property 2: Day Cell Type Selection**
    - **Property 28: Filled Day Cell Mood Color**
    - **Property 29: Day Cell Aspect Ratio**
    - **Property 30: Current Day Border Highlight**
    - **Validates: Requirements 2.4, 2.5, 13.2, 13.4, 13.5, 13.8**

- [ ] 4. Implement FeelingIconView component
  - [x] 4.1 Create FeelingIconView with custom icon paths
    - Implement switch statement for 8 feeling types
    - Render custom Path shapes at 22x17pt size
    - Apply #555555 stroke color with 1.5pt stroke width
    - _Requirements: 14.1, 14.2, 14.3, 14.4, 14.5_
  
  - [x] 4.2 Write property test for feeling icon rendering
    - **Property 31: Feeling Icon Rendering**
    - **Validates: Requirements 14.2, 14.3, 14.4, 14.5**

- [ ] 5. Implement Mood Bar Strip visualization
  - [x] 5.1 Create MoodBarStrip view component
    - Use GeometryReader to calculate available width
    - Calculate proportional widths for each mood color segment
    - Enforce minimum width of 3pt per segment
    - Render segments with 3pt height, 2pt corner radius, 0.7 opacity, and 2pt spacing
    - _Requirements: 3.1, 3.2, 3.3, 3.4, 3.5, 3.6, 3.7_
  
  - [x] 5.2 Write property test for mood bar proportional width
    - **Property 3: Mood Bar Proportional Width**
    - **Validates: Requirements 3.2, 3.3, 3.7**

- [ ] 6. Implement Wave Strip visualization
  - [x] 6.1 Create WaveStrip view component
    - Use GeometryReader to calculate bar widths
    - Render bars for all totalDays in chronological order
    - Map mood colors to heights: #E84040→22pt, #FF8C42→20pt, #F5C842→16pt, #4CAF82→14pt, #5B8DEF→18pt, #9B7FD4→16pt, #607D8B→10pt, #2C2C2C→8pt
    - Render empty days as 4pt height bars with #EEECEA color at 0.6 opacity
    - Apply 2pt corner radius and 1pt spacing between bars
    - _Requirements: 4.1, 4.2, 4.3, 4.4, 4.5_
  
  - [x] 6.2 Add wave strip selection state and interaction
    - Add @State for selectedWaveIdx
    - Apply 1.0 opacity to selected bar, 0.72 opacity to others
    - Add tap gesture to update selectedWaveIdx
    - _Requirements: 4.6, 4.7, 4.8_
  
  - [x] 6.3 Create wave strip metadata row
    - Display "1 [MonthAbbrev]" on left in GeistMono-Regular 8pt with #D0CEC8 color
    - Display "[TotalDays] [MonthAbbrev]" on right in GeistMono-Regular 8pt with #D0CEC8 color
    - Display selected song name in center when selectedWaveIdx is set
    - Add 0.2s easeInOut animation for song name transition
    - _Requirements: 5.1, 5.2, 5.3, 5.4, 5.5_
  
  - [x] 6.4 Write property tests for wave strip
    - **Property 4: Wave Strip Day Count**
    - **Property 5: Wave Strip Height Mapping**
    - **Property 6: Wave Strip Empty Day Rendering**
    - **Property 7: Wave Strip Selection State**
    - **Property 8: Wave Strip Tap Interaction**
    - **Validates: Requirements 4.1, 4.2, 4.3, 4.6, 4.7, 4.8, 5.4**

- [ ] 7. Implement MonthArchiveView
  - [x] 7.1 Create MonthArchiveView with header and toggle
    - Display month name in Fraunces-Regular 26pt with -0.5 tracking
    - Display year in GeistMono-Regular 10pt with 2.0 tracking and #BFBDB5 color
    - Create toggle with "Ay" and "Yıl" buttons in GeistMono-Regular 9pt with 1.6 tracking
    - Style active toggle with #111112 background and #F7F6F3 text
    - Style inactive toggle with transparent background, #BFBDB5 text, and #E0DED9 1pt border
    - _Requirements: 2.1, 2.2, 7.1, 7.2, 7.3, 7.4_
  
  - [x] 7.2 Add Mood Bar Strip and Wave Strip to MonthArchiveView
    - Integrate MoodBarStrip component below toggle
    - Integrate WaveStrip component below Mood Bar Strip
    - _Requirements: 3.1, 4.1_
  
  - [x] 7.3 Create calendar grid with LazyVGrid
    - Display weekday labels (P, S, Ç, P, C, C, P) in GeistMono-Regular 8pt
    - Create LazyVGrid with 7 columns and 3pt spacing
    - Render FilledDayCell for dates with entries
    - Render EmptyDayCell for dates without entries
    - Render Color.clear for nil dates in calendarCells array
    - Apply #F7F6F3 background color
    - _Requirements: 2.3, 2.4, 2.5, 2.7, 19.6_
  
  - [x] 7.4 Add calendar grid interactions and animations
    - Add tap gesture to FilledDayCell for navigation to DayDetailView
    - Add long press gesture to FilledDayCell with 1.12x scale spring animation
    - Ensure EmptyDayCell has no tap action
    - _Requirements: 6.1, 6.2, 6.3, 16.1_
  
  - [x] 7.5 Apply layout and scrolling configuration
    - Wrap content in ScrollView with showsIndicators: false
    - Apply 52pt top padding, 22pt horizontal padding, 80pt bottom padding
    - _Requirements: 15.1, 15.2, 15.7_
  
  - [x] 7.6 Write property tests for MonthArchiveView
    - **Property 1: Calendar Grid Offset Calculation**
    - **Property 9: Filled Day Cell Navigation**
    - **Property 10: Empty Day Cell No-Op**
    - **Property 11: Scroll Position Preservation**
    - **Property 32: Long Press Scale Animation**
    - **Property 37: Nil Date Transparent Cell**
    - **Validates: Requirements 2.8, 6.1, 6.3, 6.4, 12.7, 12.8, 16.1, 19.6**

- [ ] 8. Implement YearArchiveView
  - [x] 8.1 Create YearArchiveView with 12 month rows
    - Use LazyVStack with 16pt spacing
    - For each month, display month abbreviation in Fraunces-Regular 18pt
    - For each month, display horizontal day strip with mood colors
    - For each month, display filled day count in GeistMono-Regular 9pt with #BFBDB5 color
    - Apply 1.0 opacity to current month, 0.6 opacity to other months
    - _Requirements: 8.1, 8.2, 8.3, 8.4, 8.5, 8.6_
  
  - [x] 8.2 Add year view navigation interaction
    - Add tap gesture to current month row to navigate to MonthArchiveView
    - Ensure non-current month rows have no tap action
    - _Requirements: 8.7, 8.8_
  
  - [x] 8.3 Apply scrolling configuration
    - Wrap content in ScrollView with showsIndicators: false
    - _Requirements: 15.3_
  
  - [x] 8.4 Write property tests for YearArchiveView
    - **Property 12: Year View Month Count Display**
    - **Property 13: Year View Non-Current Month Interaction**
    - **Validates: Requirements 8.4, 8.8**

- [ ] 9. Implement DayDetailView
  - [x] 9.1 Create DayDetailView header and navigation
    - Display back button "← arşiv" in GeistMono-Regular 10pt with 1.6 tracking and #BFBDB5 color
    - Display relative time text ("Bugün", "Dün", "X gün önce") in GeistMono-Regular 9pt with 1.4 tracking and #D0CEC8 color
    - Implement relative time calculation logic
    - _Requirements: 9.1, 9.2_
  
  - [x] 9.2 Create photo section with conditional rendering
    - Display AsyncImage at 152pt height with 16pt corner radius when photoURL exists
    - Display placeholder with #EEECEA background and "—" symbol when photoURL is nil
    - _Requirements: 9.3, 9.4, 19.1_
  
  - [x] 9.3 Create song card section
    - Display gradient cover at 50x50pt with 12pt corner radius
    - Display song name in Fraunces-Regular 20pt
    - Display artist and genre in GeistMono-Regular 10.5pt
    - _Requirements: 9.5_
  
  - [x] 9.4 Create pill components for mood, feeling, weather, and time
    - Create mood pill with 7pt diameter mood color circle and mood label in GeistMono-Regular 9pt
    - Create feeling pill with FeelingIconView and feeling label in GeistMono-Regular 9pt
    - Create weather pill with weather icon and description in GeistMono-Regular 9pt
    - Create time pill with clock icon and time in GeistMono-Regular 9pt
    - Apply #EEECEA background and capsule shape to all pills
    - _Requirements: 9.6, 9.7, 9.8, 9.9, 9.10_
  
  - [x] 9.5 Create Spotify and apple music button with conditional state
    - Display button with green indicator circle (#1DB954, 8pt diameter) and "Spotify'da dinle" text
    - Enable button at 1.0 opacity when spotifyURL exists
    - Disable button at 0.4 opacity when spotifyURL is nil
    - Add tap action to open spotifyURL using UIApplication.shared.open
    - Apply #E0DED9 1.5pt border and 13pt corner radius
    - _Requirements: 10.1, 10.2, 10.3, 10.4, 10.5, 19.2_
  
  - [x] 9.6 Apply layout and scrolling configuration
    - Wrap content in ScrollView with showsIndicators: false
    - Apply 54pt top padding and 24pt horizontal padding
    - Apply #F7F6F3 background color
    - _Requirements: 15.4, 15.5_
  
  - [x] 9.7 Write property tests for DayDetailView
    - **Property 14: Relative Time Calculation**
    - **Property 15: Photo Display Conditional**
    - **Property 16: Day Detail Pill Structure**
    - **Property 17: Spotify Button State**
    - **Property 18: Spotify Button Action**
    - **Validates: Requirements 9.2, 9.3, 9.4, 9.6, 9.7, 9.8, 9.9, 9.10, 10.2, 10.3, 10.4, 19.1, 19.2**

- [ ] 10. Implement navigation and state management
  - [x] 10.1 Create ArchiveContainerView with navigation state
    - Use NavigationStack for view hierarchy
    - Manage toggle state for Month/Year view switching
    - Pass ArchiveStore as environment object
    - _Requirements: 1.1, 1.3, 7.5, 7.6_
  
  - [x] 10.2 Wire navigation between views
    - Add NavigationLink from MonthArchiveView to DayDetailView
    - Add navigation action from YearArchiveView to MonthArchiveView
    - Ensure back navigation returns to previous screen
    - _Requirements: 1.2, 1.4, 6.1, 8.7_
  
  - [x] 10.3 Write property test for scroll position preservation
    - **Property 11: Scroll Position Preservation**
    - **Validates: Requirements 6.4, 15.6**

- [x] 11. Checkpoint - Ensure all tests pass
  - Ensure all tests pass, ask the user if questions arise.

- [ ] 12. Implement MonthSummary computed property tests
  - [x] 12.1 Write property tests for MonthSummary calculations
    - **Property 19: CoreData Date Range Filtering**
    - **Property 20: DailySong to DailyEntry Transformation**
    - **Property 21: Month Total Days Calculation**
    - **Property 22: Entry Lookup by Date**
    - **Property 23: Turkish Month Name Mapping**
    - **Property 24: Filled Days Count**
    - **Property 25: Mood Distribution Calculation**
    - **Property 26: Ordered Days Array Structure**
    - **Property 27: Calendar Cells Padding**
    - **Validates: Requirements 11.5, 11.6, 11.7, 11.8, 12.2, 12.3, 12.4, 12.5, 12.6, 12.9, 17.4, 19.5, 20.5**

- [ ] 13. Implement animation property tests
  - [x] 13.1 Write property test for wave strip selection animation
    - **Property 33: Wave Strip Selection Animation**
    - **Validates: Requirements 16.2**

- [ ] 14. Implement time formatting and error handling tests
  - [x] 14.1 Write property tests for time formatting and error handling
    - **Property 34: Time Formatting**
    - **Property 35: Empty Month Rendering**
    - **Property 36: CoreData Fetch Error Handling**
    - **Validates: Requirements 17.5, 19.3, 19.4**

- [ ] 15. Implement performance optimization tests
  - [ ] 15.1 Write property test for month summary caching
    - **Property 38: Month Summary Caching**
    - **Validates: Requirements 20.4**

- [ ] 16. Apply typography and color system
  - [x] 16.1 Verify typography implementation across all views
    - Ensure Fraunces-Regular is used for headers (26pt), month names (18pt), and song names (20pt)
    - Ensure GeistMono-Regular is used for metadata (8-10.5pt) and labels (9-11pt)
    - Apply correct tracking values: 0.4-2.0 for GeistMono, -0.4 to -0.5 for Fraunces
    - _Requirements: 18.1, 18.2, 18.9_
  
  - [x] 16.2 Verify color system implementation across all views
    - Ensure #F7F6F3 is used for background color
    - Ensure #111112 is used for primary text color
    - Ensure #BFBDB5, #D0CEC8, #888888, #999999 are used for secondary text colors
    - Ensure #E0DED9, #E8E6E0 are used for border colors
    - Ensure #edac6aff is used for pill backgrounds
    - Ensure #1DB954 is used for Spotify indicator color
    - _Requirements: 18.3, 18.4, 18.5, 18.6, 18.7, 18.8_

- [ ] 17. Final integration and polish
  - [x] 17.1 Test complete user flows
    - Test navigation from main interface to archive
    - Test switching between Month and Year views
    - Test tapping filled days to view details
    - Test wave strip interaction and metadata display
    - Test Spotify button functionality
    - _Requirements: 1.1, 1.2, 6.1, 7.5, 7.6, 8.7, 10.4_
  
  - [x] 17.2 Verify error handling and edge cases
    - Test with empty months (no entries)
    - Test with missing photos
    - Test with missing Spotify URLs
    - Test with invalid feeling types
    - Test CoreData fetch failures
    - _Requirements: 19.1, 19.2, 19.3, 19.4, 19.5, 19.6_
  
  - [x] 17.3 Verify performance optimizations
    - Verify LazyVGrid and LazyVStack are used correctly
    - Verify AsyncImage is used for photo loading
    - Verify CoreData fetch requests use date range predicates
    - Verify MonthSummary caching in ArchiveStore
    - _Requirements: 20.1, 20.2, 20.3, 20.4, 20.5, 20.6_

- [x] 18. Final checkpoint - Ensure all tests pass
  - Ensure all tests pass, ask the user if questions arise.

## Notes

- Tasks marked with `*` are optional and can be skipped for faster MVP
- Each task references specific requirements for traceability
- Property tests validate universal correctness properties across all inputs
- Unit tests validate specific examples and edge cases
- Checkpoints ensure incremental validation
- Implementation follows bottom-up approach: data models → components → views → integration
- All 38 correctness properties from the design document are covered in property test tasks
- Typography and color system verification ensures wabi-sabi aesthetic consistency
