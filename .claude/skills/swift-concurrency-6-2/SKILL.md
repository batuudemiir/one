# Swift 6.2 Concurrency

Swift 6.2 shifts to "single-threaded by default" — async functions stay on the calling actor unless explicitly offloaded. Eliminates the silent background-thread data races common in Swift 6.1.

## When to Activate

- Any file touching `async/await`, `actor`, or `@MainActor`
- Modifying managers that cross concurrency boundaries
- Enabling Swift 6 strict concurrency in the Xcode build settings
- Getting "Sendable" or "actor-isolated" compiler errors

## Core Principles

### 1. Async Functions Stay on Calling Actor

```swift
// Swift 6.1 — could silently hop to background thread
@MainActor
func refresh() async {
    await loadData()   // might run off main actor!
}

// Swift 6.2 — stays on @MainActor unless marked @concurrent
@MainActor
func refresh() async {
    await loadData()   // stays on main actor ✓
}
```

### 2. Isolated Conformances

```swift
// @MainActor-isolated type conforming to non-isolated protocol
@Observable
final class ONERouter: @MainActor Hashable {
    static func == (lhs: ONERouter, rhs: ONERouter) -> Bool { lhs === rhs }
    func hash(into hasher: inout Hasher) { hasher.combine(ObjectIdentifier(self)) }
}
```

### 3. @concurrent for Genuine CPU Work

```swift
// Only use @concurrent when you actually need parallel execution
@concurrent
func processMoodImages(_ images: [UIImage]) async -> [ProcessedImage] {
    // CPU-intensive work — explicitly offloaded
    images.map { processImage($0) }
}

// Called normally — caller decides isolation
let processed = await processMoodImages(rawImages)
```

### 4. @MainActor Inference (Xcode 26+)

In app targets, enable automatic `@MainActor` inference in Build Settings:
```
SWIFT_ENABLE_IMPLICIT_ACTOR_ISOLATION = YES
```

This infers `@MainActor` on types without explicit annotation, reducing boilerplate across ViewModels and Views.

### 5. Protect Mutable Global/Static State

```swift
// Bad — data race risk
var sharedConfig: AppConfig = .default

// Good — compiler-enforced safety
@MainActor var sharedConfig: AppConfig = .default
```

## ONE-Specific Patterns

### Manager Isolation

```swift
// CloudKitManager — runs off main thread, results published to main
actor CloudKitManager {
    func fetchEntries() async throws -> [DailyEntry] { ... }
}

// ViewModel — bridges actor to @MainActor UI
@Observable @MainActor
final class ArchiveViewModel {
    var entries: [DailyEntry] = []
    private let cloudKit = CloudKitManager.shared

    func load() async {
        do {
            entries = try await cloudKit.fetchEntries()  // actor hop automatic
        } catch {
            ONELogger.error(error)
        }
    }
}
```

### Sendable Across Boundaries

```swift
// DailyEntry must be Sendable to pass between actors
struct DailyEntry: Codable, Identifiable, Sendable {
    let id: String
    var mood: ONEMood
    var date: Date
    var song: Song?
}
```

### Task Cancellation

```swift
.task {
    await vm.load()
    // Automatically cancelled when view disappears — no manual cleanup
}
```

## Migration Steps (Incremental)

1. Enable `SWIFT_STRICT_CONCURRENCY = targeted` — fix errors file by file
2. Add `Sendable` to model types (`DailyEntry`, `Song`, `MonthSummary`)
3. Convert `DispatchQueue`-based managers to `actor`
4. Add `@MainActor` to all `@Observable` ViewModels
5. Replace `@concurrent` only where profiling shows benefit

## Pitfalls to Avoid

- Calling `DispatchQueue.main.async` inside `@MainActor` code — redundant
- Non-`Sendable` types passed across actor boundaries — compiler error in strict mode
- `Task.detached` without explicit priority — prefer structured concurrency
- Blocking the main actor with synchronous I/O — use `await` + actor
