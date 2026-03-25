# SwiftUI Patterns

Modern SwiftUI patterns for building declarative, performant user interfaces on Apple platforms. Covers the Observation framework, view composition, type-safe navigation, and performance optimization.

## When to Activate

- Building SwiftUI views and managing state (@State, @Observable, @Binding)
- Designing navigation flows with NavigationStack
- Structuring view models and data flow
- Optimizing rendering performance for lists and complex layouts
- Working with environment values and dependency injection in SwiftUI

## State Management

### Property Wrapper Selection

| Wrapper | Use Case |
|---------|----------|
| `@State` | View-local value types (toggles, form fields, sheet presentation) |
| `@Binding` | Two-way reference to parent's @State |
| `@Observable` class + `@State` | Owned model with multiple properties |
| `@Observable` class (no wrapper) | Read-only reference passed from parent |
| `@Bindable` | Two-way binding to an @Observable property |
| `@Environment` | Shared dependencies injected via `.environment()` |

### @Observable ViewModel (ONE pattern)

```swift
@Observable
final class TodayViewModel {
    var mood: ONEMood = .neutral
    var selectedSong: Song?
    var isLoading = false
    var error: Error?

    private let cloudKit: CloudKitManager

    init(cloudKit: CloudKitManager = .shared) {
        self.cloudKit = cloudKit
    }

    func saveEntry(_ entry: DailyEntry) async {
        isLoading = true
        defer { isLoading = false }
        do {
            try await cloudKit.save(entry)
        } catch {
            ONELogger.error(error)
            self.error = error
        }
    }
}
```

### View Consuming the ViewModel

```swift
struct TodayView: View {
    @State private var vm = TodayViewModel()

    var body: some View {
        MoodPickerView(mood: $vm.mood)
            .task { await vm.loadTodayEntry() }
    }
}
```

### Environment Injection (replace @EnvironmentObject)

```swift
// Inject
.environment(cloudKitManager)

// Consume
@Environment(CloudKitManager.self) private var cloudKit
```

## View Composition

### Extract Subviews to Limit Invalidation

```swift
// Good — only MoodBarStrip re-renders when moods change
struct ArchiveView: View {
    var moods: [ONEMood]
    var body: some View {
        VStack {
            HeaderView()          // never re-renders
            MoodBarStrip(moods: moods)  // re-renders on mood change
        }
    }
}
```

### ViewModifier for Reusable Styling

```swift
struct ONECardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(ONETokens.spacing16)
            .background(Color.oneCardBackground)
            .clipShape(RoundedRectangle(cornerRadius: ONETokens.radius12))
    }
}

extension View {
    func oneCard() -> some View { modifier(ONECardModifier()) }
}
```

## Navigation

### Type-Safe NavigationStack

```swift
enum ONEDestination: Hashable {
    case archive
    case circle
    case profile
    case monthSummary(Date)
}

@Observable
final class ONERouter {
    var path = NavigationPath()

    func navigate(to dest: ONEDestination) { path.append(dest) }
    func popToRoot() { path.removeLast(path.count) }
}

struct ContentView: View {
    @State private var router = ONERouter()

    var body: some View {
        NavigationStack(path: $router.path) {
            TodayView()
                .navigationDestination(for: ONEDestination.self) { dest in
                    switch dest {
                    case .archive: ArchiveView()
                    case .circle: CircleView()
                    case .profile: ProfileView()
                    case .monthSummary(let date): MonthlySummaryView(date: date)
                    }
                }
        }
        .environment(router)
    }
}
```

## Performance

### Lazy Containers for Large Collections

```swift
// Archive calendar — use LazyVGrid
LazyVGrid(columns: columns, spacing: ONETokens.spacing8) {
    ForEach(entries) { entry in
        DayCell(entry: entry)
    }
}
```

### Stable Identifiers

```swift
// Good
ForEach(entries, id: \.id) { DayCell(entry: $0) }

// Bad — never use array index
ForEach(0..<entries.count, id: \.self) { i in ... }
```

### Avoid Expensive Work in body

```swift
// Good
.task { await vm.load() }   // cancels on disappear

// Bad
var body: some View {
    let processed = entries.sorted().filter { ... }  // runs every render
    ...
}
```

## Anti-Patterns to Avoid

- Using `ObservableObject` / `@Published` / `@StateObject` / `@EnvironmentObject` in new code — migrate to `@Observable`
- Putting async work directly in `body` or `init` — use `.task {}`
- Using `AnyView` type erasure — prefer `@ViewBuilder` or `Group`
- Ignoring `Sendable` requirements when passing data across actor boundaries
- Force unwrapping optionals (`!`) — use `guard let` / `if let`

## References

- See skill: `swift-actor-persistence` for actor-based CloudKit/CoreData patterns
- See skill: `swift-protocol-di-testing` for testable manager protocols
- See skill: `swift-concurrency-6-2` for Swift 6.2 concurrency safety
