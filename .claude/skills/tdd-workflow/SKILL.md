# TDD Workflow

Test-driven development for Swift/XCTest. Red → Green → Refactor cycle with 80%+ coverage target. Directly applicable to ONE's existing `oneTests/` suite.

## When to Activate

- Implementing any new feature (Today flow, Circle, Archive, etc.)
- Fixing a bug — write a failing test first that exposes it
- Refactoring a manager or ViewModel — tests guard against regression
- Adding a new manager method

## The Cycle

```
1. Write a failing test (Red)
2. Write minimum code to pass (Green)
3. Refactor without breaking tests (Refactor)
4. Repeat
```

## Step-by-Step for ONE

### 1. User Story → Test Cases

```
As a user, I want to save today's mood so that I can view it in the Archive.

Happy path:   Mood saved → appears in CloudKit
Error path:   CloudKit offline → error shown, local cache preserved
Edge case:    Saving twice on same day → updates, not duplicates
```

### 2. Write the Failing Test First

```swift
import XCTest
@testable import ones

final class TodayViewModelTests: XCTestCase {
    var sut: TodayViewModel!
    var mockStore: MockDailyEntryStore!

    override func setUp() {
        mockStore = MockDailyEntryStore()
        sut = TodayViewModel(store: mockStore)
    }

    // Red — this fails because the method doesn't exist yet
    func test_saveEntry_persistsToStore() async throws {
        sut.mood = .happy
        try await sut.saveEntry()
        XCTAssertEqual(mockStore.savedEntries.count, 1)
        XCTAssertEqual(mockStore.savedEntries.first?.mood, .happy)
    }

    func test_saveEntry_whenOffline_setsError() async {
        mockStore.shouldThrow = true
        sut.mood = .happy
        await sut.saveEntry()   // swallowed — error exposed via property
        XCTAssertNotNil(sut.error)
    }
}
```

### 3. Implement Minimum Code (Green)

```swift
@Observable
final class TodayViewModel {
    var mood: ONEMood = .neutral
    var error: Error?
    private let store: any DailyEntryStoring

    init(store: any DailyEntryStoring = CloudKitManager.shared) {
        self.store = store
    }

    func saveEntry() async {
        do {
            let entry = DailyEntry(mood: mood, date: .now)
            try await store.save(entry)
        } catch {
            ONELogger.error(error)
            self.error = error
        }
    }
}
```

### 4. Refactor & Cover Edge Cases

```swift
func test_saveEntry_twice_sameDayUpdates() async throws {
    sut.mood = .happy
    try await sut.saveEntry()
    sut.mood = .calm
    try await sut.saveEntry()
    // Should update, not duplicate
    XCTAssertEqual(mockStore.savedEntries.count, 1)
    XCTAssertEqual(mockStore.savedEntries.first?.mood, .calm)
}
```

## ONE Test File Map

| Source File | Test File | Coverage Goal |
|------------|-----------|---------------|
| `TodayViewModel` | `TodayViewModelTests` | 90%+ |
| `DailyEntry` | `DailyEntryTests` ✓ | 80%+ |
| `MonthSummary` | `MonthSummaryTests` ✓ | 80%+ |
| `CloudKitManager` | `CloudKitManagerTests` (missing) | 70%+ |
| `SpotifyManager` | `SpotifyManagerTests` (missing) | 70%+ |
| `ONEMood` | `MoodCompletenessTests` ✓ | 100% |

## Run Tests

```bash
xcodebuild test \
  -project ones.xcodeproj \
  -scheme ones \
  -destination 'platform=iOS Simulator,name=iPhone 15' \
  -enableCodeCoverage YES
```

## Coverage Check

```bash
xcrun xccov view --report --json DerivedData/*/Logs/Test/*.xccovreport
```

## Best Practices

- Test **behaviour**, not implementation details
- One assertion concept per test — use separate test methods
- Use `setUp` / `tearDown` for consistent fixture state
- Async tests: use `async throws` — not `expectation`/`waitForExpectations`
- Name tests: `test_<method>_<condition>_<expectedResult>`

## Anti-Patterns to Avoid

- Writing tests after implementation — defeats the purpose
- Testing private methods directly — test via public interface
- Mocking too deeply — only mock external boundaries
- Skipping error path tests — they're often where bugs hide
