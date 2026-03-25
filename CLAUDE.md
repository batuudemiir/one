# ONE — Günlük Mood Tracker

## Project Overview

iOS SwiftUI mood tracking and journaling app with Spotify music integration, CloudKit sync, and social features (Circle). Users capture daily moods, attach songs and photos, and share with friends.

## Tech Stack

| Layer | Technology |
|-------|-----------|
| Language | Swift 5.9+ |
| UI Framework | SwiftUI (iOS 15+) |
| Architecture | MVVM |
| Local Persistence | Core Data (`one.xcdatamodeld`) |
| Cloud Sync | CloudKit |
| Music | Spotify iOS SDK |
| Events | Ticketmaster API |
| Fonts | DM Sans (custom) |
| Localization | Turkish (primary), English |

## Project Structure

```
one/
├── Core/
│   ├── Managers/          # 11 service managers (CloudKit, Spotify, Notifications…)
│   ├── Models/            # DailyEntry, Song, MonthSummary, TodayModels
│   └── Utilities/         # ColorUtils, ONELogger, NotificationManager
├── Features/              # 11 feature modules (Today, Archive, Circle, Profile…)
├── UI/
│   ├── DesignSystem/      # ONETokens, ONETypography, ONEMood, Color+ONE
│   └── Components/        # BottomNavigation, DayCell, MoodBarStrip, WaveStrip
├── oneApp.swift           # App entry point
└── ContentView.swift      # Root navigation
```

## Key Entry Points

- `oneApp.swift` — App lifecycle, CloudKit init
- `ContentView.swift` — Root view + navigation state
- `Core/Managers/CloudKitManager.swift` — Primary cloud sync
- `Core/Managers/SpotifyManager.swift` — Spotify auth + playback
- `Features/Today/` — Daily entry creation flow

## Build & Test Commands

```bash
# Build (requires Xcode)
xcodebuild -project ones.xcodeproj -scheme ones -configuration Debug build

# Run tests
xcodebuild test -project ones.xcodeproj -scheme ones -destination 'platform=iOS Simulator,name=iPhone 15'

# SwiftLint (if installed)
swiftlint lint --config .swiftlint.yml
```

## Code Style Conventions

- **Architecture:** MVVM — ViewModels are `@Observable` classes
- **Async:** Swift concurrency (`async/await`, actors) — no DispatchQueue
- **State:** `@Observable` (not `ObservableObject`/`@Published`) for new code
- **DI:** Protocol-based injection with default production implementations
- **Error handling:** `ONELogger` + `ErrorHandler` for all error paths
- **Naming:** `ONE` prefix for design system types (`ONEMood`, `ONETokens`)
- **No force unwrap** (`!`) in production code — use `guard let` / `if let`

## Design System

- Colors: `Color+ONE.swift`, tokens in `ONETokens.swift`
- Typography: `ONETypography.swift` (DM Sans variants)
- Mood: `ONEMood.swift` — mood enum with colors and gradients
- Animations: `ONEAnimation.swift`, `ONEHaptics.swift`

## Testing

- Unit tests: `oneTests/` (11 test files)
- UI tests: `oneUITests/`
- Test guide: `ARCHIVE_USER_FLOW_TEST_GUIDE.md`
- Run with XCTest framework

## CloudKit Setup

- Container: configured in `one.entitlements`
- Services: `CloudKitManager`, `CloudKitFriendshipService`, `CloudKitDailyShareService`, `CloudKitNotificationService`
- Deep links: `ones://spotify-callback`, `ones://add-friend`

## Security Notes

- API keys must live in `Secrets.xcconfig` (see `Secrets.xcconfig.template`)
- Never commit `Secrets.xcconfig` — it is gitignored
- Spotify Client ID: must be in xcconfig, NOT in `Info.plist` directly
- Background modes: remote-notification, background-processing

## Active Skills

- `swift-actor-persistence` — Thread-safe CloudKit/CoreData patterns
- `swiftui-patterns` — Modern SwiftUI state & navigation
- `swift-protocol-di-testing` — Testable manager protocols
- `swift-concurrency-6-2` — Swift 6.2 concurrency safety
- `tdd-workflow` — XCTest TDD workflow
- `security-review` — API key & secrets audit
- `verification-loop` — Pre-PR build/test/security check
- `continuous-learning` — Session pattern extraction
