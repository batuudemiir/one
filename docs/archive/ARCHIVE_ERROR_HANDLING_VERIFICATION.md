# Archive View System - Error Handling Verification Guide

## Task 17.2: Verify Error Handling and Edge Cases

This document provides a comprehensive guide for manually verifying error handling and edge cases in the Archive View System.

**Requirements Validated:** 19.1, 19.2, 19.3, 19.4, 19.5, 19.6

---

## Test Suite Overview

A comprehensive test suite has been created at `one/oneTests/ArchiveErrorHandlingTests.swift` with 20+ test cases covering all error handling scenarios. The tests are organized into the following categories:

### 1. Empty Months (Requirement 19.3)

**Test Cases:**
- `testEmptyMonthRendersAllEmptyCells()` - Verifies empty month displays all empty cells
- `testEmptyMonthMoodBarStripIsEmpty()` - Verifies mood distribution is empty

**Manual Verification Steps:**
1. Open the app and navigate to the Archive view
2. Select a month with no entries (e.g., a future month or a month before you started using the app)
3. **Expected Results:**
   - All calendar cells should show dashed borders (empty state)
   - Mood Bar Strip should not be visible or should be empty
   - Wave Strip should show all bars at 4pt height with #EEECEA color
   - Filled days count should show "0 gün"

---

### 2. Missing Photos (Requirement 19.1)

**Test Cases:**
- `testEntryWithMissingPhotoURL()` - Verifies nil photoURL handling
- `testEntryWithEmptyPhotoURLString()` - Verifies empty string photoURL handling

**Manual Verification Steps:**
1. Create a daily entry without adding a photo
2. Navigate to Archive view and tap on that day
3. **Expected Results:**
   - Day Detail View should display a placeholder with:
     - #EEECEA background color
     - "—" symbol in the center
     - 152pt height
     - 16pt corner radius
   - All other information (song, mood, feeling, etc.) should display correctly

---

### 3. Missing Spotify URLs (Requirement 19.2)

**Test Cases:**
- `testEntryWithMissingSpotifyURL()` - Verifies nil spotifyURL handling
- `testEntryWithEmptySpotifyURLString()` - Verifies empty string spotifyURL handling

**Manual Verification Steps:**
1. Create a daily entry without selecting a Spotify song (or with a song that doesn't have a Spotify URL)
2. Navigate to Archive view and tap on that day
3. **Expected Results:**
   - Spotify button should be visible but disabled
   - Button opacity should be 0.4 (dimmed)
   - Tapping the button should have no effect
   - Green indicator circle should still be visible but dimmed

---

### 4. Invalid Feeling Types (Requirement 19.4)

**Test Cases:**
- `testEntryWithInvalidFeelingType()` - Verifies invalid feeling defaults to .calm
- `testEntryWithNilFeelingType()` - Verifies nil feeling defaults to .calm

**Manual Verification Steps:**
1. This is primarily a data integrity test that runs automatically
2. If you encounter corrupted data, the app should:
   - Default to "calm" feeling type
   - Display the calm icon in the feeling pill
   - Not crash or show errors

---

### 5. Missing CoreData Attributes (Requirement 19.4)

**Test Case:**
- `testEntryWithMissingAttributes()` - Verifies default values for missing attributes

**Expected Default Values:**
- Missing ID → Generated UUID
- Missing song name → "Bilinmeyen Şarkı"
- Missing artist → "Bilinmeyen Sanatçı"
- Missing genre → "Bilinmeyen"
- Missing mood color → "#607D8B" (gray-blue)
- Missing feeling → .calm
- Missing weather icon → "☀️"
- Missing weather description → "—"

**Manual Verification:**
- Check older entries or corrupted data
- Verify default values appear correctly
- App should not crash with missing data

---

### 6. Date Calculation Failures (Requirement 19.5)

**Test Case:**
- `testMonthSummaryWithInvalidDateComponents()` - Verifies fallback to 30 days

**Manual Verification:**
- System should handle edge cases gracefully
- If date calculations fail, default to 30 days per month
- Calendar should still render correctly

---

### 7. Nil Dates in Calendar Cells (Requirement 19.6)

**Test Case:**
- `testCalendarCellsWithNilDates()` - Verifies transparent cells for nil dates

**Manual Verification Steps:**
1. Open any month in Archive view
2. Observe the calendar grid
3. **Expected Results:**
   - Cells before the 1st of the month should be transparent (Color.clear)
   - Cells after the last day should be transparent (padding to multiple of 7)
   - All visible date cells should be in chronological order
   - Grid should always have rows that are multiples of 7 (7, 14, 21, 28, 35, 42)

---

### 8. Time Formatting (Requirement 17.5)

**Test Case:**
- `testTimeFormatting()` - Verifies "HH:mm" format

**Manual Verification Steps:**
1. Create entries at different times of day
2. View them in Day Detail View
3. **Expected Results:**
   - Time should be formatted as "HH:mm" (24-hour format)
   - Examples: "09:30", "14:45", "23:15"
   - Leading zeros should be present

---

### 9. Multiple Entries Edge Cases

**Test Cases:**
- `testMultipleEntriesInSameMonth()` - Verifies multiple entries load correctly
- `testMoodDistributionWithMultipleMoods()` - Verifies mood distribution calculation

**Manual Verification Steps:**
1. Create multiple entries in the same month with different moods
2. Navigate to Archive view for that month
3. **Expected Results:**
   - All entries should appear in the calendar
   - Mood Bar Strip should show proportional segments for each mood
   - Wave Strip should show all days with correct heights
   - Filled days count should be accurate

---

### 10. Year Data Loading

**Test Case:**
- `testYearDataLoadsAll12Months()` - Verifies all 12 months load

**Manual Verification Steps:**
1. Switch to Year view in Archive
2. **Expected Results:**
   - All 12 months should be visible (OCA through ARA)
   - Each month should show correct filled day count
   - Current month should be at 1.0 opacity
   - Other months should be at 0.6 opacity

---

### 11. Turkish Month Names (Requirements 12.2, 12.3)

**Test Case:**
- `testTurkishMonthNames()` - Verifies correct Turkish month names

**Expected Month Names:**
- Full: Ocak, Şubat, Mart, Nisan, Mayıs, Haziran, Temmuz, Ağustos, Eylül, Ekim, Kasım, Aralık
- Short: OCA, ŞUB, MAR, NİS, MAY, HAZ, TEM, AĞU, EYL, EKİ, KAS, ARA

**Manual Verification:**
- Check both Month and Year views
- Verify all month names are in Turkish
- Verify abbreviations are correct

---

### 12. Calendar Grid Offset Calculation (Requirements 2.8, 12.7, 12.8)

**Test Case:**
- `testCalendarGridOffsetCalculation()` - Verifies (weekday + 5) % 7 formula

**Manual Verification Steps:**
1. Check multiple months with different starting weekdays
2. **Expected Results:**
   - First day of month should align with correct weekday column
   - Offset formula: (weekday + 5) % 7 (Monday-start calendar)
   - Empty cells before first day should be transparent

---

### 13. Leap Year Handling

**Test Cases:**
- `testFebruaryLeapYear()` - Verifies 29 days in leap year February
- `testFebruaryNonLeapYear()` - Verifies 28 days in non-leap year February

**Manual Verification:**
- February 2024: Should have 29 days (leap year)
- February 2025: Should have 28 days (non-leap year)
- February 2026: Should have 28 days (non-leap year)

---

### 14. Month Day Counts

**Test Cases:**
- `testMonthWith31Days()` - Verifies 31-day months
- `testMonthWith30Days()` - Verifies 30-day months

**Expected Day Counts:**
- 31 days: January, March, May, July, August, October, December
- 30 days: April, June, September, November
- 28/29 days: February (depends on leap year)

---

## Running the Automated Tests

### Option 1: Xcode GUI
1. Open `One - Günlük Mood.xcodeproj` in Xcode
2. Select the test navigator (⌘5)
3. Find `ArchiveErrorHandlingTests`
4. Click the play button next to the test class or individual tests
5. View results in the test navigator

### Option 2: Command Line
```bash
cd one
xcodebuild test -scheme "One - Günlük Mood" \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:oneTests/ArchiveErrorHandlingTests
```

---

## Test Coverage Summary

| Requirement | Test Cases | Status |
|-------------|------------|--------|
| 19.1 - Missing Photos | 2 | ✅ Implemented |
| 19.2 - Missing Spotify URLs | 2 | ✅ Implemented |
| 19.3 - Empty Months | 2 | ✅ Implemented |
| 19.4 - Invalid Feeling Types | 2 | ✅ Implemented |
| 19.4 - Missing Attributes | 1 | ✅ Implemented |
| 19.5 - Date Calculation Failures | 1 | ✅ Implemented |
| 19.6 - Nil Dates in Calendar | 1 | ✅ Implemented |
| 17.5 - Time Formatting | 1 | ✅ Implemented |
| Additional Edge Cases | 10+ | ✅ Implemented |

**Total Test Cases: 20+**

---

## Implementation Notes

### Error Handling Strategy

The Archive View System implements graceful degradation:

1. **Missing Data**: Uses sensible defaults (e.g., "Bilinmeyen Şarkı" for missing song names)
2. **Invalid Data**: Falls back to safe values (e.g., .calm for invalid feelings)
3. **Failed Calculations**: Uses default values (e.g., 30 days if month calculation fails)
4. **CoreData Errors**: Logs errors and returns empty data structures
5. **UI Rendering**: Shows placeholders for missing content (e.g., "—" for missing photos)

### Key Files

- **Test Suite**: `one/oneTests/ArchiveErrorHandlingTests.swift`
- **Archive Store**: `one/one/ArchiveStore.swift` (CoreData integration & error handling)
- **Month Summary**: `one/one/MonthSummary.swift` (Date calculations)
- **Day Detail View**: `one/one/DayDetailView.swift` (Missing photo/Spotify handling)

---

## Conclusion

The Archive View System has comprehensive error handling for all edge cases specified in Requirements 19.1-19.6. The test suite provides automated verification, and this guide enables manual verification of the user-facing behavior.

All error scenarios are handled gracefully without crashes, and the UI provides appropriate feedback for missing or invalid data.
