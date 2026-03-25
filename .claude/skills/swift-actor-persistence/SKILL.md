# Swift Actor Persistence

Thread-safe data persistence in Swift using the actor model. Combines in-memory caching with file-backed or CloudKit storage. Directly applicable to ONE's CloudKit + Core Data stack.

## When to Activate

- Writing or modifying `CloudKitManager`, `CloudKitFriendshipService`, `CloudKitDailyShareService`
- Implementing Core Data access from async contexts
- Replacing `DispatchQueue`-based synchronisation with actors
- Building offline-first cache layers

## Core Pattern — LocalRepository Actor

```swift
actor LocalRepository<T: Codable & Identifiable> where T.ID == String {
    private var cache: [String: T] = [:]
    private let storageURL: URL

    init(filename: String) {
        storageURL = FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("\(filename).json")
        // Synchronous load on init — avoids async complexity at call sites
        if let data = try? Data(contentsOf: storageURL),
           let items = try? JSONDecoder().decode([T].self, from: data) {
            cache = Dictionary(uniqueKeysWithValues: items.map { ($0.id, $0) })
        }
    }

    func save(_ item: T) throws {
        cache[item.id] = item
        try persist()
    }

    func delete(id: String) throws {
        cache.removeValue(forKey: id)
        try persist()
    }

    func find(by id: String) -> T? { cache[id] }

    func loadAll() -> [T] { Array(cache.values) }

    private func persist() throws {
        let data = try JSONEncoder().encode(Array(cache.values))
        try data.write(to: storageURL, options: .atomic)   // crash-safe
    }
}
```

## CloudKit-Backed Actor (ONE pattern)

```swift
actor DailyEntryRepository {
    private var cache: [String: DailyEntry] = [:]
    private let cloudKit: CloudKitManager

    init(cloudKit: CloudKitManager = .shared) {
        self.cloudKit = cloudKit
    }

    func save(_ entry: DailyEntry) async throws {
        cache[entry.id] = entry
        try await cloudKit.saveDailyEntry(entry)
    }

    func entries(for month: Date) -> [DailyEntry] {
        cache.values.filter { Calendar.current.isDate($0.date, equalTo: month, toGranularity: .month) }
    }
}
```

## ViewModel Integration

```swift
@Observable
final class ArchiveViewModel {
    var entries: [DailyEntry] = []
    private let repo = DailyEntryRepository()

    func load(month: Date) async {
        entries = await repo.entries(for: month)
        // Actor hop is transparent — just await
    }
}
```

## Design Rationale

| Element | Purpose |
|---------|---------|
| Actor isolation | Compiler-enforced data-race safety |
| In-memory cache | O(1) reads — no repeated disk/network I/O |
| Synchronous init | Simplifies call sites |
| `.atomic` writes | Crash-safe persistence |
| `Sendable` conformance | Safe to pass across actor boundaries |

## Best Practices

- Mark types crossing actor boundaries as `Sendable`
- Keep actor public API minimal — expose only what ViewModels need
- Load data synchronously during `init` to avoid `await` at call sites
- Prefer actors over `@MainActor` classes for persistence — saves main thread

## Pitfalls to Avoid

- Using `DispatchQueue` for synchronisation — use actors instead
- Exposing `cache` as a public property — breaks isolation
- Forgetting `await` on actor method calls — compiler will catch this
- Accessing Core Data `NSManagedObject` outside its context's thread
