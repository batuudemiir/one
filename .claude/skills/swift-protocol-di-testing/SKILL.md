# Swift Protocol-Based Dependency Injection & Testing

Pattern for making Swift managers testable through protocol abstraction. Applied to ONE's 11 service managers so ViewModels can be unit-tested without hitting CloudKit or Spotify.

## When to Activate

- Writing or modifying any Manager (`SpotifyManager`, `CloudKitManager`, `NowPlayingManager`, etc.)
- Adding unit tests for ViewModels that depend on managers
- Designing a new feature module that needs an external service
- Refactoring `@EnvironmentObject` injection to protocol-based DI

## Core Pattern — Five Steps

### 1. Define a Focused Protocol

```swift
// Single responsibility — one protocol per concern
protocol DailyEntryStoring: Sendable {
    func save(_ entry: DailyEntry) async throws
    func fetch(for date: Date) async throws -> DailyEntry?
    func fetchAll() async throws -> [DailyEntry]
}

protocol SpotifyPlaying: Sendable {
    func play(trackURI: String) async throws
    func currentTrack() async -> Song?
}
```

### 2. Production Implementation

```swift
extension CloudKitManager: DailyEntryStoring {
    func save(_ entry: DailyEntry) async throws { /* real CloudKit call */ }
    func fetch(for date: Date) async throws -> DailyEntry? { /* real fetch */ }
    func fetchAll() async throws -> [DailyEntry] { /* real fetch */ }
}
```

### 3. Mock Implementation

```swift
final class MockDailyEntryStore: DailyEntryStoring {
    var savedEntries: [DailyEntry] = []
    var fetchResult: DailyEntry? = nil
    var shouldThrow = false

    func save(_ entry: DailyEntry) async throws {
        if shouldThrow { throw ONEError.cloudKitUnavailable }
        savedEntries.append(entry)
    }
    func fetch(for date: Date) async throws -> DailyEntry? { fetchResult }
    func fetchAll() async throws -> [DailyEntry] { savedEntries }
}
```

### 4. ViewModel with Default Production Injection

```swift
@Observable
final class TodayViewModel {
    var entry: DailyEntry?
    private let store: any DailyEntryStoring

    // Default → production; tests can pass a mock
    init(store: any DailyEntryStoring = CloudKitManager.shared) {
        self.store = store
    }

    func saveEntry() async throws {
        guard let entry else { return }
        try await store.save(entry)
    }
}
```

### 5. Tests with Swift Testing

```swift
import Testing

@Suite("TodayViewModel")
struct TodayViewModelTests {
    @Test("saves entry to store")
    func saveEntry() async throws {
        let mock = MockDailyEntryStore()
        let vm = TodayViewModel(store: mock)
        vm.entry = DailyEntry.fixture()

        try await vm.saveEntry()

        #expect(mock.savedEntries.count == 1)
    }

    @Test("handles save error")
    func saveError() async {
        let mock = MockDailyEntryStore()
        mock.shouldThrow = true
        let vm = TodayViewModel(store: mock)
        vm.entry = DailyEntry.fixture()

        await #expect(throws: ONEError.cloudKitUnavailable) {
            try await vm.saveEntry()
        }
    }
}
```

## ONE Manager Protocol Map

| Manager | Protocol to Extract | Benefit |
|---------|--------------------|---------|
| `CloudKitManager` | `DailyEntryStoring` | Test without network |
| `SpotifyManager` | `SpotifyPlaying` | Test without Spotify auth |
| `CloudKitFriendshipService` | `FriendshipManaging` | Test Circle features |
| `NowPlayingManager` | `NowPlayingProviding` | Test song attachment |
| `NotificationManager` | `NotificationScheduling` | Test without entitlements |

## Key Principles

- **Single Responsibility** — one protocol per external concern, not a catch-all
- **Sendable** — all protocols must be `Sendable` when used across actor boundaries
- **Mock only external boundaries** — don't mock internal Swift types
- **Error mocking** — every mock should have a `shouldThrow` property to test failure paths

## Anti-Patterns to Avoid

- Giant protocols with 10+ methods — split into focused protocols
- Mocking internal types (e.g., `DailyEntry`) — only mock external services
- Singletons without protocol abstraction — impossible to test
- Concrete type injection — always inject the protocol type
