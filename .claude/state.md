# ONE App — Multi-Agent Analysis State

**Generated:** 2026-05-06  
**Project Root:** `/Users/batudemir/Desktop/one/one`  
**Platform:** iOS / SwiftUI + UIKit hybrid

## Project Overview

| Area | Details |
|------|---------|
| App Name | ONE (OneDailyBatuhan) |
| Architecture | MVVM + Manager pattern |
| Data | Core Data + CloudKit |
| Features | Today, Archive, Echo, Circle, Discovery, MonthlySummary, YearlySummary, Badges, Camera, Share, Comments, Profile, Premium |
| Extensions | MoodWidget, OneActivityExtension (Live Activity) |
| Tests | Unit (oneTests), UI (oneUITests) |
| Swift Files | ~175 source files |

## Agent Reports

---
## PLANNER REPORT

### Finding 1: Pervasive Singleton Coupling With No Abstraction Layer
27+ `static let shared` singleton doğrudan ViewModel ve View'lardan erişiliyor. Yalnızca `AnalyticsService` ve `CrashReporting` protokol soyutlaması var; diğer tüm manager'lar concrete type olarak tüketiliyor. `TodayViewModel` tek başına 9+ singleton'a doğrudan bağımlı. Mock oluşturmak imkansız, unit test yazılamıyor.

### Finding 2: TodayViewModel Is a God Object Orchestrating Too Many Concerns
546 satırlık `TodayViewModel`; CoreData fetch, MusicKit arama, CloudKit sync, streak hesaplama, badge, Live Activity, widget yazma, bildirim planlama ve analytics'i tek sınıfta barındırıyor. `saveEntry` tek metodunda 12 farklı subsystem'a dokunuyor; transaksiyonel garanti yok, bir adım patlarsa zincirleme arıza riski var.

### Finding 3: Dual Data Path Creates Consistency Risks Between CoreData and CloudKit
CoreData (`NSPersistentCloudKitContainer`) ve manuel CloudKit public database olmak üzere iki paralel veri yolu var. Public CloudKit yazımı başarısız olursa outbox/retry kuyruğu bulunmuyor; yerel kayıt var ama sosyal katman görmüyor. Conflict resolution mekanizması eksik.

### Finding 4: NotificationCenter Used as an Event Bus Without Type Safety
17 farklı dosyada ham string isimli (`"HandleAddFriendDeepLink"`, `"todaySongSaved"`) bildirim yayınlanıyor. Payload'lar untyped `userInfo` dict; publisher-subscriber arasında derleme zamanı kontratı yok. Bir Combine subject tabanlı typed event bus veya enum-based koordinatör bu riski ortadan kaldırır.

### Finding 5: App Entry Point Carries Excessive Initialization and Routing Logic
`oneApp.swift` + `ContentView.swift` ~400 satırda push kayıt, CloudKit abonelik, Spotify OAuth, universal link, deep-link doğrulama, analytics init, crash reporter, midnight reset ve Live Activity temizliğini inline yönetiyor. `AppCoordinator` / `Router` / `DeepLinkHandler` soyutlaması yok; her yeni deep-link tipi bu dosyayı büyütecek.
---
## PLANNER REPORT (2026-05-06 — Run 2)

### Finding 1: Pervasive Singleton Coupling Defeats Testability and Modularity
The codebase relies heavily on a `.shared` singleton pattern: `CloudKitManager.shared`, `PremiumManager.shared`, `NotificationManager.shared`, `SpotifyManager.shared`, `LiveActivityManager.shared`, `MidnightResetManager.shared`, `AppAnalytics.shared`, `LanguageManager.shared`, `AppUpdateChecker.shared`, `NotificationOrchestrator.shared`, `CrashReporter.shared`, and `KeychainHelper`. Direct calls to these managers occur across at least 31 files with 66+ occurrences; `oneApp.swift` (367 lines) and `ContentView.swift` (222 lines) each reach into 8+ singletons directly. No `*Tests*.swift` files exist — unit testing is effectively impossible in this shape.
**Recommendation:** Introduce a protocol-typed `AppEnvironment` struct injected at the root via `EnvironmentKey`; start with `PremiumManager` (smallest surface) to prove the pattern before migrating heavier managers.

### Finding 2: God-Object CloudKitManager Concentrates Architectural Risk
`CloudKitManager.swift` is 747 lines + `CloudKitManager+Async.swift` extension, and 24 files call into it directly — view models (`TodayViewModel`, `ProfileViewModel`, `EchoViewModel`), views (`CircleView`, `AddFriendView`, `CommentThreadView`), schedulers (`MidnightResetManager`), and the app entry point. It owns user loading, subscription registration, push routing, throttle state, and friend/comment/circle features simultaneously. Any API change ripples through every feature folder.
**Recommendation:** Split into bounded services — `UserAccountService`, `FriendsService`, `SubscriptionRegistrar`, `CloudKitPushRouter` — each behind a protocol, keeping `CloudKitManager` as a thin facade during migration.

### Finding 3: NotificationCenter as a Hidden Control Plane
String-keyed `NotificationCenter` posts/observers appear across 15 files. `oneApp.swift` alone posts/observes 3 ad-hoc named events (`"OpenMoodPicker"`, `"HandleAddFriendDeepLink"`, `"resetToOnboarding"`), and the deep-link flow (lines 260–335) routes friend invites by storing `pendingDeepLinkCode` and re-firing a post once `currentUser` loads. These untyped names are scattered with no central registry, making the event graph invisible to the compiler.
**Recommendation:** Create a typed `AppEvent` enum + `PassthroughSubject<AppEvent, Never>`; at minimum define all `Notification.Name` constants in one file so the event surface is greppable.

### Finding 4: Bloated Root Views Hold Lifecycle, Migration, and Routing Logic
`oneApp.swift` (367 lines) hosts: AppDelegate push registration, 8 notification category definitions, 3-tier cold-start orchestration with nested `Task.detached`/`MainActor.run`, two deep-link parsers, and analytics/crash/CloudKit initialization. `ContentView.swift` (222 lines) additionally owns onboarding gating, profile-setup retry with manual `userCheckRetryCount`/`maxUserCheckRetries`, and two inline `UserDefaults → Keychain` migrations in `.onAppear`.
**Recommendation:** Extract `AppLaunchCoordinator`, `DeepLinkRouter`, `NotificationCategoryRegistry`, and `LegacyMigrationRunner` so root files shrink to declarative composition only.

### Finding 5: Mixed Persistence Sources of Truth Without an Abstraction
State authority is split across four stores with no unifying repository: Keychain (`hasCompletedOnboarding`, `hasCreatedProfile`), `@AppStorage`/`UserDefaults` (`isDarkMode` + legacy keys), CoreData via raw `NSFetchRequest<DailySong>` inside `TodayViewModel.loadTodayEntry`, and CloudKit via `CloudKitManager`. `TodayViewModel` performs the CoreData fetch and triggers `syncLocalEntryToCloudKitIfNeeded` inline, blending read/write/sync. Retry/migration code in `ContentView` (lines 75–116) shows the cost: profile state reconciled across Keychain + CloudKit + `isFetchingUser` + `userLoadFailed` flags with manual retry counters.
**Recommendation:** Introduce a `MoodEntryRepository` protocol owning CoreData↔CloudKit reconciliation, and an `OnboardingStateStore` hiding the Keychain/UserDefaults split.

---
## UI-AGENT REPORT (2026-05-06)

### Finding 1: Saturated Mood Colors Drive Primary UI While Pastel Palette Sits Unused
`ONEMood.swift` defines both saturated (`oneRed` #E84040) and pastel (`moodPastelRed` #FFB5A7) variants, but `ONEMood.color` returns saturated everywhere: `MoodExplorerView` chips, `SplashScreen` squares, `DoneScreen` wave, `BottomNavigation` glow, and `DayCell` pattern backgrounds all render full saturation. The pastel set exists only as a fallback in persistence code. This contradicts the "Light Serenity" visual direction.
**Recommendation:** Add `pastelColor: Color` to `ONEMood` and use it for all ambient/background surfaces; reserve `.color` (saturated) for active CTA states and export share cards only.

### Finding 2: Monthly Summary Cards Are Fully Disconnected from the Design System
`MoodMapCardView.swift` and `TopTracksCardView.swift` use raw `.font(.system(size: 56, weight: .black))`, `.font(.system(size: 9, weight: .regular, design: .monospaced))`, and hardcoded `Color(red:green:blue:)` literals. Comments reference BebasNeue/SyneMono but neither is registered (no `UIAppFonts` entry). Zero `ONETypography` or `ONETokens` usage. The monthly summary is visually orphaned from every other screen.
**Recommendation:** Map each raw size to the nearest `ONETypography` scale, replace `Color(red:green:blue:)` literals with `ONETokens.moodAmber` etc., and switch background to `oneCinematicDark` which already exists for this purpose.

### Finding 3: PaywallView Is a 26-Line Stub That Destroys Trust at the Highest-Intent Moment
`PaywallView.swift` shows only a system-font "ONE+" title and "Yakında geliyor." text — no `ONETokens`, no `ONETypography`, no dismiss animation, no accessibility labels. `PremiumManager` and `PremiumModels` are production-complete. Every premium gate leads here, directly contradicting the app's quality positioning to Gen Z.
**Recommendation:** Implement a minimal but complete Light Serenity paywall: `oneCream` background, `displayHero` wordmark, `bodyLG` value props, `oneBrand` CTA button, ghost dismiss with `oneAsh` stroke, and accessibility labels on all interactive elements.

### Finding 4: DayCell Uses Unregistered GeistMono — Silent Font Fallback in Archive Grid
`DayCell.swift` uses `Font.custom("GeistMono-Regular", size: 9)` for day numbers. GeistMono has no `UIAppFonts` entry and is absent from `ONETypography.swift`. SwiftUI silently falls back to system font on load failure — meaning the Archive calendar grid (highest emotional investment screen) currently renders with wrong rhythm and weight.
**Recommendation:** Either formally register GeistMono in `Info.plist` + `ONETypography` as `monoGrid`, or replace it with the existing `ONETypography.monoMicro` (DM Sans Medium 9pt, `relativeTo: .caption2`) which is identically sized and already in the token system.

### Finding 5: Empty-State Components Have Two Visual Languages in One File
`CircleEmptyState.swift` uses `OneMascotView` with hardcoded Turkish strings, raw spacing literals (`24`, `12`, `40`, `32`), and a `oneBrand → oneBrandLight` gradient button — none of which follow `StandardStateViews.swift` patterns. `CircleCloudKitUnavailableState` in the same file correctly uses `ONETokens`. `OneMascotView` receives no `.accessibilityLabel` or `.accessibilityHint`, making the mascot container inaccessible.
**Recommendation:** Extend `EmptyState` in `StandardStateViews.swift` with an optional `mascotPose` param and `ctaStyle` enum; replace all hardcoded spacing with `ONETokens.spacingLG/XL/XL2`; add accessibility labels to mascot container and CTA.

---
## BUILDER REPORT (2026-05-06)

### Finding 1: CoreData Save Errors Silently Discarded Across the Codebase
`TodayViewModel.saveEntry` (line 215), `clearToday` (line 333), and `clearEntry` (line 345) all call `try? context.save()`, swallowing every CoreData error without logging or surfacing it. UI state is updated immediately after the attempted save — so a constraint violation or migration mismatch leaves the user seeing "saved" while data is never persisted. The same pattern appears in `ArchiveStore`.
**Fix:** Replace all `try? context.save()` with `do/catch` that calls `ErrorHandler.shared.handle(_:)` on failure, and halt in-memory state updates unless the save succeeds.

### Finding 2: `@MainActor` ViewModel Performs Synchronous CoreData Fetches on the Main Thread
`TodayViewModel` is `@MainActor` (line 14) yet `loadTodayEntry`, `loadRecentArtists`, `loadLastYearEntry`, `loadLastWeekEntry`, and `computeCurrentStreak` all call `context.fetch(...)` synchronously on the main actor. `EchoViewModel.fetchAllSongs` fetches unbounded CoreData rows with no `fetchLimit`. `ArchiveStore.loadData` iterates all 12 months synchronously at init time with no background dispatch.
**Fix:** Move all fetches to `newBackgroundContext()` and bridge results with `await MainActor.run { ... }`. Add `fetchLimit` to any unbounded query.

### Finding 3: Temp Files Leak in the Photo-to-CKAsset Pipeline
`CloudKitDailyShareService.swift` (lines 122–133) writes photo data to a temp file for `CKAsset` creation but only cleans it up on success; background/failure paths leave the file indefinitely in `tmp/`. The same write-to-temp pattern in `TodayViewModel.dailyEntryFrom` (line 465) re-writes the same JPEG on every `loadTodayEntry()` call — multiple writes per session for identical data.
**Fix:** Delete temp files in a `defer` block regardless of success/failure. Cache the written URL by entry UUID in `dailyEntryFrom` to avoid redundant writes.

### Finding 4: `ensureCurrentUser` Busy-Poll Loop Has Data Race Risk
`ensureCurrentUser()` in `CloudKitManager.swift` (lines 184–216) is non-isolated `async` yet reads `@Published` properties (`currentUser`, `isThrottled`, `userLoadFailed`, `isFetchingUser`) that are mutated on `DispatchQueue.main` throughout the codebase — no actor isolation guarantee. `syncLocalEntryToCloudKitIfNeeded` in `TodayViewModel` adds a redundant `DispatchQueue.main.async` hop inside a `CloudKitManager` callback, despite `TodayViewModel` already being `@MainActor`.
**Fix:** Mark `CloudKitManager` `@MainActor`, or annotate all `@Published` reads in `ensureCurrentUser` with `await MainActor.run { ... }`. Remove the redundant hop.

### Finding 5: Zero Test Coverage for All Critical User-Facing Paths
14 test files cover only model structs and pure utilities. `TodayViewModel`, `ArchiveStore`, `EchoViewModel`, `CloudKitManager`, and all CloudKit service extensions (`CloudKitDailyShareService`, `CloudKitCommentService`, `CloudKitFriendshipService`) have no tests. The core flow — `saveEntry` → CoreData write → CloudKit share → streak computation → widget update — is entirely uncovered. Project target is 80% coverage; current effective coverage of the ~60-file source tree is near 0%.
**Fix:** Add `XCTestCase` for `TodayViewModel` using the in-memory `PersistenceController` already in `DailyEntryTests`, covering `saveEntry`, `clearToday`, and `computeCurrentStreak` with date fixtures. Abstract `CloudKitManager` behind a protocol to enable hermetic mocks.

---
## REVIEWER REPORT (2026-05-06)

### Finding 1: Spotify Client ID Hardcoded in Info.plist — CRITICAL
`Info.plist` line 46 stores the Spotify OAuth `client_id` (`f2afa405bc0e44bf8ed6c171adc0fa79`) as plaintext. Any `.ipa` user running `strings` recovers it instantly. A leaked client ID enables rogue OAuth impersonation and API quota exhaustion. The Ticketmaster key in the same file correctly uses `$(TICKETMASTER_API_KEY)` xcconfig substitution — Spotify must follow the same pattern.
**Fix:** Add `SPOTIFY_CLIENT_ID` to `Secrets.xcconfig`, update `Info.plist` to `$(SPOTIFY_CLIENT_ID)`, read via `Bundle.main.object(forInfoDictionaryKey:)` as `SpotifyManager.swift` already expects.

### Finding 2: Secrets.xcconfig Contains Live API Key and Lives Inside the Project Tree — CRITICAL
`Secrets.xcconfig` contains the live Ticketmaster key (`ogfADZPwtx0APF42s1G7LjoiA6WZJWeO`) in plaintext, co-located with source. A zip/share/accidental git push exposes it immediately. The file's own comment says it must never be committed, yet it exists inside the project directory.
**Fix:** Move `Secrets.xcconfig` outside the Xcode project directory (e.g. `~/secrets/one/`). Rotate the Ticketmaster key immediately if this directory has ever been shared externally. Verify `.gitignore` covers it before any version control initialization.

### Finding 3: Spotify Keychain Load Query Missing `kSecAttrSynchronizable` — HIGH
`SpotifyManager.swift` saves the access token with `kSecAttrSynchronizable: false` but `loadTokenFromKeychain` omits that attribute from the `SecItemCopyMatching` query. Without the explicit match, the lookup may ambiguously match across synchronizable/non-synchronizable classes by iOS version, causing spurious lookup failures that force full re-authentication. The refresh token pair is consistent; the access token pair is not.
**Fix:** Add `kSecAttrSynchronizable as String: false` to the `loadTokenFromKeychain` query dictionary to mirror the save query exactly.

### Finding 4: User Free-Text (`dailyNote`) Written to CloudKit Public Database Without Validation — HIGH
`CloudKitDailyShareService.swift` line 110 writes raw `dailyNote` and `userName` (both user-controlled) directly to the public CloudKit database with `isPublic = 1`. No length cap, no content sanitization, no moderation before the record lands in other users' Circle feeds. Arbitrarily large payloads can exhaust client bandwidth on fetch; malicious content can exploit `Text` rendering.
**Fix:** Cap at `dailyNote?.prefix(500)` and trim whitespace before the CloudKit save. Apply the same limit to `userName`. Consider a moderation queue consistent with the existing `CloudKitReportService`.

### Finding 5: Spotify Token Exchange Error Path Re-Issues Consumed Code and Logs Raw Response — MEDIUM
`SpotifyManager.swift` lines 192–196: the `catch` block of `exchangeCodeForToken` fires a second `URLSession` call with the same request body — including the one-time PKCE `code` already consumed by the first attempt. Spotify always returns `400 invalid_grant`. Worse, the raw error response body is logged via `ONELogger.error("Error response: \(errorString)")`, which can echo back submitted parameters and risks leaking credentials if Spotify's response format changes.
**Fix:** Remove the retry call from the `catch` block entirely (it's a decode error, not a network error). Log only a fixed-string message; gate any verbose logging behind `#if DEBUG`.
