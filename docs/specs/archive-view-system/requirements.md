# Requirements Document

## Introduction

ONE - Günlük Mood iOS uygulaması için kapsamlı bir arşiv görünümü sistemi. Kullanıcılar geçmiş günlük kayıtlarını ay ve yıl bazında görüntüleyebilir, mood dağılımlarını analiz edebilir ve detaylı gün bilgilerine erişebilir. Sistem, wabi-sabi minimalist estetik ile mood renkleri, fotoğraflar, Spotify şarkıları ve hava durumu bilgilerini entegre eder.

## Glossary

- **Archive_System**: Geçmiş günlük kayıtlarını görüntüleme ve yönetme sistemi
- **Month_Archive_View**: Aylık takvim görünümü bileşeni
- **Year_Archive_View**: Yıllık 12 ay şerit görünümü bileşeni
- **Day_Detail_View**: Tek bir günün detaylı bilgilerini gösteren görünüm
- **Mood_Bar_Strip**: Ayın mood renk dağılımını oransal gösteren görsel bileşen
- **Wave_Strip**: Her günün mood rengini dikey çubuklar olarak gösteren görsel bileşen
- **Calendar_Grid**: 7x6 takvim ızgarası bileşeni
- **Archive_Store**: Arşiv verilerini yöneten veri katmanı
- **Daily_Entry**: Tek bir günlük kaydı veri modeli
- **Month_Summary**: Bir ayın özet bilgilerini içeren veri modeli
- **Filled_Day_Cell**: Veri içeren gün hücresi bileşeni
- **Empty_Day_Cell**: Veri içermeyen gün hücresi bileşeni
- **Feeling_Type**: Kullanıcının hislerini temsil eden enum (calm, happy, sad, anxious, excited, tired, angry, peaceful)
- **Spotify_Manager**: Spotify entegrasyonunu yöneten servis
- **CoreData_Context**: Yerel veri saklama bağlamı

## Requirements

### Requirement 1: Archive View Navigation

**User Story:** As a user, I want to access the archive view from the main interface, so that I can browse my past daily entries.

#### Acceptance Criteria

1. THE Archive_System SHALL provide a navigation entry point from the main interface
2. WHEN the user taps the archive entry point, THE Archive_System SHALL display the Month_Archive_View for the current month
3. THE Archive_System SHALL maintain navigation state when switching between month and year views
4. WHEN the user navigates back, THE Archive_System SHALL return to the previous screen without data loss

### Requirement 2: Month Archive Display

**User Story:** As a user, I want to view my daily entries in a monthly calendar format, so that I can see patterns and navigate to specific days.

#### Acceptance Criteria

1. THE Month_Archive_View SHALL display the month name in Fraunces-Regular 26pt font with -0.5 tracking
2. THE Month_Archive_View SHALL display the year in GeistMono-Regular 10pt font with 2.0 tracking and #BFBDB5 color
3. THE Month_Archive_View SHALL render a 7x6 calendar grid with weekday labels (P, S, Ç, P, C, C, P)
4. WHEN a day contains a Daily_Entry, THE Month_Archive_View SHALL display a Filled_Day_Cell with the mood color
5. WHEN a day has no Daily_Entry, THE Month_Archive_View SHALL display an Empty_Day_Cell with dashed border
6. WHEN the current day is displayed, THE Month_Archive_View SHALL highlight it with a black border (1.5pt stroke)
7. THE Month_Archive_View SHALL use #F7F6F3 as the background color
8. THE Month_Archive_View SHALL calculate calendar grid offset based on the first day's weekday position

### Requirement 3: Mood Bar Strip Visualization

**User Story:** As a user, I want to see a visual summary of my mood distribution for the month, so that I can understand my emotional patterns at a glance.

#### Acceptance Criteria

1. THE Mood_Bar_Strip SHALL display horizontally below the month/year toggle
2. THE Mood_Bar_Strip SHALL calculate the proportion of each mood color based on filled days
3. FOR EACH mood color present in the month, THE Mood_Bar_Strip SHALL render a segment with width proportional to its occurrence count
4. THE Mood_Bar_Strip SHALL use 0.7 opacity for mood colors
5. THE Mood_Bar_Strip SHALL use 3pt height and 2pt corner radius for segments
6. THE Mood_Bar_Strip SHALL maintain 2pt spacing between segments
7. WHEN a mood color has less than calculated width, THE Mood_Bar_Strip SHALL enforce a minimum width of 3pt

### Requirement 4: Wave Strip Visualization

**User Story:** As a user, I want to see a wave-like visualization of my daily moods, so that I can identify emotional trends throughout the month.

#### Acceptance Criteria

1. THE Wave_Strip SHALL display all days of the month as vertical bars in chronological order
2. FOR EACH filled day, THE Wave_Strip SHALL render a bar with height mapped to the mood color (#E84040: 22pt, #FF8C42: 20pt, #F5C842: 16pt, #4CAF82: 14pt, #5B8DEF: 18pt, #9B7FD4: 16pt, #607D8B: 10pt, #2C2C2C: 8pt)
3. FOR EACH empty day, THE Wave_Strip SHALL render a 4pt height bar with #EEECEA color at 0.6 opacity
4. THE Wave_Strip SHALL use 2pt corner radius for all bars
5. THE Wave_Strip SHALL maintain 1pt spacing between bars
6. WHEN a bar is selected, THE Wave_Strip SHALL display it at 1.0 opacity
7. WHEN a bar is not selected, THE Wave_Strip SHALL display it at 0.72 opacity
8. WHEN a bar is tapped, THE Wave_Strip SHALL update the selected state and display the song name in the metadata row

### Requirement 5: Wave Strip Metadata Display

**User Story:** As a user, I want to see contextual information about the wave strip, so that I can understand the timeline and selected day details.

#### Acceptance Criteria

1. THE Wave_Strip SHALL display metadata row below the wave visualization
2. THE Wave_Strip SHALL show "1 [MonthAbbrev]" on the left side in GeistMono-Regular 8pt with 1.0 tracking and #D0CEC8 color
3. THE Wave_Strip SHALL show "[TotalDays] [MonthAbbrev]" on the right side in GeistMono-Regular 8pt with 1.0 tracking and #D0CEC8 color
4. WHEN a wave bar is selected, THE Wave_Strip SHALL display the corresponding song name in the center in GeistMono-Regular 8pt with 0.8 tracking and #999999 color
5. WHEN the selected bar changes, THE Wave_Strip SHALL animate the song name transition with 0.2s easeInOut animation

### Requirement 6: Calendar Grid Interaction

**User Story:** As a user, I want to tap on filled days in the calendar to view detailed information, so that I can review my past entries.

#### Acceptance Criteria

1. WHEN a Filled_Day_Cell is tapped, THE Month_Archive_View SHALL navigate to Day_Detail_View for that date
2. WHEN a Filled_Day_Cell is long-pressed, THE Month_Archive_View SHALL scale the cell to 1.12x with spring animation
3. WHEN an Empty_Day_Cell is tapped, THE Month_Archive_View SHALL not trigger any navigation
4. THE Month_Archive_View SHALL maintain scroll position when returning from Day_Detail_View

### Requirement 7: Month/Year View Toggle

**User Story:** As a user, I want to switch between monthly and yearly views, so that I can navigate different time scales of my entries.

#### Acceptance Criteria

1. THE Archive_System SHALL display a toggle with "Ay" and "Yıl" options below the header
2. THE Archive_System SHALL render the active toggle button with #111112 background and #F7F6F3 text
3. THE Archive_System SHALL render the inactive toggle button with transparent background, #BFBDB5 text, and #E0DED9 1pt border
4. THE Archive_System SHALL use GeistMono-Regular 9pt font with 1.6 tracking for toggle labels
5. WHEN "Ay" is active and "Yıl" is tapped, THE Archive_System SHALL transition to Year_Archive_View
6. WHEN "Yıl" is active and "Ay" is tapped, THE Archive_System SHALL transition to Month_Archive_View for the current month

### Requirement 8: Year Archive Display

**User Story:** As a user, I want to view all 12 months of the year in a strip format, so that I can quickly navigate to any month.

#### Acceptance Criteria

1. THE Year_Archive_View SHALL display 12 month rows in chronological order (January to December)
2. FOR EACH month, THE Year_Archive_View SHALL display the month abbreviation (OCA, ŞUB, MAR, NİS, MAY, HAZ, TEM, AĞU, EYL, EKİ, KAS, ARA) in Fraunces-Regular 18pt
3. FOR EACH month, THE Year_Archive_View SHALL display a horizontal strip of all days with mood colors
4. FOR EACH month, THE Year_Archive_View SHALL display the filled day count in GeistMono-Regular 9pt with #BFBDB5 color
5. WHEN a month is the current month, THE Year_Archive_View SHALL display it at 1.0 opacity
6. WHEN a month is not the current month, THE Year_Archive_View SHALL display it at 0.6 opacity
7. WHEN the current month row is tapped, THE Year_Archive_View SHALL navigate to Month_Archive_View for that month
8. WHEN a non-current month row is tapped, THE Year_Archive_View SHALL not trigger any action

### Requirement 9: Day Detail View Display

**User Story:** As a user, I want to view comprehensive details of a specific day, so that I can review my mood, photo, song, and other recorded information.

#### Acceptance Criteria

1. THE Day_Detail_View SHALL display a back button "← arşiv" in GeistMono-Regular 10pt with 1.6 tracking and #BFBDB5 color
2. THE Day_Detail_View SHALL display the relative time text ("Bugün", "Dün", or "X gün önce") in GeistMono-Regular 9pt with 1.4 tracking and #D0CEC8 color
3. WHEN the Daily_Entry has a photo, THE Day_Detail_View SHALL display it at 152pt height with 16pt corner radius
4. WHEN the Daily_Entry has no photo, THE Day_Detail_View SHALL display a placeholder with #EEECEA background and "—" symbol
5. THE Day_Detail_View SHALL display the song card with gradient cover, song name in Fraunces-Regular 20pt, and artist/genre in GeistMono-Regular 10.5pt
6. THE Day_Detail_View SHALL display mood pill with mood color circle (7pt diameter) and mood label in GeistMono-Regular 9pt
7. THE Day_Detail_View SHALL display feeling pill with feeling icon (22x17pt) and feeling label in GeistMono-Regular 9pt
8. THE Day_Detail_View SHALL display weather pill with weather icon and description in GeistMono-Regular 9pt
9. THE Day_Detail_View SHALL display time pill with clock icon and time in GeistMono-Regular 9pt
10. THE Day_Detail_View SHALL use #EEECEA background and capsule shape for all pills

### Requirement 10: Spotify Integration in Day Detail

**User Story:** As a user, I want to open the song in Spotify from the day detail view, so that I can listen to the song associated with that day.

#### Acceptance Criteria

1. THE Day_Detail_View SHALL display a Spotify button with green indicator circle (#1DB954, 8pt diameter) and "Spotify'da dinle" text
2. WHEN the Daily_Entry has a Spotify URL, THE Day_Detail_View SHALL enable the Spotify button at 1.0 opacity
3. WHEN the Daily_Entry has no Spotify URL, THE Day_Detail_View SHALL disable the Spotify button at 0.4 opacity
4. WHEN the enabled Spotify button is tapped, THE Day_Detail_View SHALL open the Spotify URL using UIApplication.shared.open
5. THE Day_Detail_View SHALL display the Spotify button with #E0DED9 1.5pt border and 13pt corner radius

### Requirement 11: Archive Store Data Management

**User Story:** As a developer, I want a centralized store to manage archive data, so that views can access consistent and up-to-date information.

#### Acceptance Criteria

1. THE Archive_Store SHALL initialize with the CoreData_Context from PersistenceController
2. THE Archive_Store SHALL publish currentMonth as MonthSummary for the current calendar month
3. THE Archive_Store SHALL publish yearData as an array of 12 MonthSummary objects
4. WHEN Archive_Store is initialized, THE Archive_Store SHALL load data for the current month and all 12 months of the current year
5. THE Archive_Store SHALL fetch DailySong entities from CoreData filtered by date range
6. THE Archive_Store SHALL transform DailySong entities into Daily_Entry models
7. THE Archive_Store SHALL calculate total days for each month using Calendar.range
8. THE Archive_Store SHALL provide an entry(for:) method that returns the Daily_Entry for a given date

### Requirement 12: Month Summary Calculations

**User Story:** As a developer, I want Month_Summary to provide calculated properties for calendar rendering, so that views can display data correctly.

#### Acceptance Criteria

1. THE Month_Summary SHALL store year, month, entries dictionary, and totalDays
2. THE Month_Summary SHALL provide monthName property returning full month name in Turkish
3. THE Month_Summary SHALL provide monthNameShort property returning 3-letter month abbreviation in Turkish
4. THE Month_Summary SHALL provide filledDays property returning the count of entries
5. THE Month_Summary SHALL provide moodDistribution property returning an array of (color, count) tuples
6. THE Month_Summary SHALL provide orderedDays property returning an array of Date? for all calendar positions
7. WHEN calculating orderedDays, THE Month_Summary SHALL insert nil values at the beginning based on the first day's weekday
8. WHEN calculating orderedDays, THE Month_Summary SHALL use (weekday + 5) % 7 formula for Monday-start offset
9. THE Month_Summary SHALL provide calendarCells property returning orderedDays padded to a multiple of 7

### Requirement 13: Day Cell Components

**User Story:** As a developer, I want reusable day cell components, so that calendar grids can be rendered consistently.

#### Acceptance Criteria

1. THE Filled_Day_Cell SHALL display the day number in GeistMono-Regular 11pt font with #111112 color
2. THE Filled_Day_Cell SHALL use the Daily_Entry mood color as background at 0.85 opacity
3. THE Filled_Day_Cell SHALL use 8pt corner radius
4. THE Filled_Day_Cell SHALL maintain 1:1 aspect ratio
5. WHEN isToday is true, THE Filled_Day_Cell SHALL display a #111112 1.5pt stroke border
6. THE Empty_Day_Cell SHALL display a dashed border using #E8E6E0 color with 1pt stroke
7. THE Empty_Day_Cell SHALL use 8pt corner radius
8. THE Empty_Day_Cell SHALL maintain 1:1 aspect ratio
9. THE Empty_Day_Cell SHALL use transparent background

### Requirement 14: Feeling Icon Visualization

**User Story:** As a user, I want to see visual icons representing my feelings, so that I can quickly identify emotional states.

#### Acceptance Criteria

1. THE Archive_System SHALL support 8 feeling types: calm, happy, sad, anxious, excited, tired, angry, peaceful
2. FOR EACH Feeling_Type, THE Archive_System SHALL provide a unique icon representation
3. THE Archive_System SHALL render feeling icons at 22x17pt size in day detail pills
4. THE Archive_System SHALL use #555555 color for feeling icon strokes
5. THE Archive_System SHALL use consistent stroke width (1.5pt) for all feeling icons

### Requirement 15: Responsive Layout and Scrolling

**User Story:** As a user, I want smooth scrolling and responsive layouts, so that I can navigate the archive comfortably on different screen sizes.

#### Acceptance Criteria

1. THE Month_Archive_View SHALL use ScrollView with showsIndicators: false
2. THE Month_Archive_View SHALL apply 52pt top padding, 22pt horizontal padding, and 80pt bottom padding
3. THE Year_Archive_View SHALL use ScrollView with showsIndicators: false
4. THE Day_Detail_View SHALL use ScrollView with showsIndicators: false
5. THE Day_Detail_View SHALL apply 54pt top padding and 24pt horizontal padding
6. THE Archive_System SHALL maintain scroll position when navigating between views
7. THE Archive_System SHALL use LazyVGrid for calendar grids to optimize performance

### Requirement 16: Animation and Transitions

**User Story:** As a user, I want smooth animations when interacting with the archive, so that the experience feels polished and responsive.

#### Acceptance Criteria

1. WHEN a Filled_Day_Cell is long-pressed, THE Month_Archive_View SHALL animate scale to 1.12x with spring effect
2. WHEN the wave strip selection changes, THE Month_Archive_View SHALL animate the metadata text with 0.2s easeInOut duration
3. WHEN navigating between views, THE Archive_System SHALL use default SwiftUI navigation transitions
4. THE Archive_System SHALL use .opacity transition for conditional wave strip metadata

### Requirement 17: Data Model Integration

**User Story:** As a developer, I want Daily_Entry to integrate with existing CoreData schema, so that archive data is consistent with the rest of the app.

#### Acceptance Criteria

1. THE Daily_Entry SHALL map to DailySong CoreData entity
2. THE Daily_Entry SHALL include id (UUID), date, songName, artistName, genre, moodColor, moodColorHex, moodLabel
3. THE Daily_Entry SHALL include feeling (Feeling_Type), feelingLabel, time (formatted string), photoURL (optional)
4. THE Daily_Entry SHALL include shareWithCircle (Bool), weatherIcon, weatherDesc, spotifyURL (optional)
5. THE Archive_Store SHALL handle missing or nil CoreData attributes with default values
6. THE Archive_Store SHALL format time using "HH:mm" DateFormatter pattern

### Requirement 18: Typography and Color System

**User Story:** As a designer, I want consistent typography and colors throughout the archive system, so that it matches the wabi-sabi aesthetic.

#### Acceptance Criteria

1. THE Archive_System SHALL use Fraunces-Regular font for headers (26pt), month names (18pt), and song names (20pt)
2. THE Archive_System SHALL use GeistMono-Regular font for metadata (8-10.5pt) and labels (9-11pt)
3. THE Archive_System SHALL use #F7F6F3 for background color
4. THE Archive_System SHALL use #111112 for primary text color
5. THE Archive_System SHALL use #BFBDB5, #D0CEC8, #888888, #999999 for secondary text colors
6. THE Archive_System SHALL use #E0DED9, #E8E6E0 for border colors
7. THE Archive_System SHALL use #EEECEA for pill backgrounds
8. THE Archive_System SHALL use #1DB954 for Spotify indicator color
9. THE Archive_System SHALL apply tracking values: 0.4-2.0 for GeistMono, -0.4 to -0.5 for Fraunces

### Requirement 19: Error Handling and Edge Cases

**User Story:** As a user, I want the archive to handle missing data gracefully, so that I can still navigate and view available information.

#### Acceptance Criteria

1. WHEN a Daily_Entry has no photo, THE Day_Detail_View SHALL display a placeholder with "—" symbol
2. WHEN a Daily_Entry has no Spotify URL, THE Day_Detail_View SHALL disable the Spotify button
3. WHEN a month has no entries, THE Month_Archive_View SHALL display all Empty_Day_Cells
4. WHEN CoreData fetch fails, THE Archive_Store SHALL log the error and return empty entries dictionary
5. WHEN date calculations fail, THE Month_Summary SHALL use default totalDays value of 30
6. THE Archive_System SHALL handle nil dates in orderedDays array by rendering transparent cells

### Requirement 20: Performance Optimization

**User Story:** As a user, I want fast loading and smooth scrolling in the archive, so that I can browse my entries without lag.

#### Acceptance Criteria

1. THE Archive_Store SHALL fetch data asynchronously during initialization
2. THE Month_Archive_View SHALL use LazyVGrid to defer cell rendering until visible
3. THE Year_Archive_View SHALL use LazyVStack to defer row rendering until visible
4. THE Archive_System SHALL cache Month_Summary calculations in Archive_Store
5. THE Archive_System SHALL limit CoreData fetch requests to specific date ranges
6. THE Archive_System SHALL use AsyncImage with placeholder for photo loading in Day_Detail_View
