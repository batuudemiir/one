# Observability Setup — Sentry + PostHog

Phase 2 scaffolding is in place. This doc covers the one-time Xcode work
to plug real backends into the `AppAnalytics` + `CrashReporter`
abstractions. Until these SDKs are registered, the app logs events
through `ConsoleAnalyticsService` in DEBUG and is a no-op in Release.

## Architecture

```
Call sites
    │
    ▼
AppAnalytics.shared.track(.entrySaved(...))   ← typed enum
    │
    ▼
[registered services]            CrashReporter.shared.capture(error: ...)
    │                                    │
    ├─ ConsoleAnalyticsService (DEBUG)   ├─ (no-op default)
    ├─ PostHogAnalyticsService ←add      ├─ SentryCrashReporter ←add
    └─ MixpanelAnalyticsService ←add
```

Event enum: [AnalyticsEvent.swift](../one/one/Core/Utilities/Analytics/AnalyticsEvent.swift) — 19 events covering onboarding, Today, Circle, Discover, Share funnels.

## Sentry (crash + non-fatal error reporting)

**1. Add SPM package**
- In Xcode → File → Add Packages…
- URL: `https://github.com/getsentry/sentry-cocoa`
- Version: 8.x (up to next major)
- Add `Sentry` to target `one`.

**2. Create Sentry backend adapter**

Create `one/Core/Utilities/Analytics/SentryCrashReporter.swift`:

```swift
import Foundation
import Sentry

final class SentryCrashReporter: CrashReporting {
    init(dsn: String, environment: String) {
        SentrySDK.start { options in
            options.dsn = dsn
            options.environment = environment
            options.tracesSampleRate = 0.2
            options.enableAutoPerformanceTracing = true
            options.attachStacktrace = true
        }
    }

    func capture(error: Error, context: [String: Any]) {
        SentrySDK.capture(error: error) { scope in
            context.forEach { scope.setExtra(value: $0.value, key: $0.key) }
        }
    }

    func capture(message: String, level: CrashLevel) {
        let sentryLevel: SentryLevel = {
            switch level {
            case .info: return .info
            case .warning: return .warning
            case .error: return .error
            case .fatal: return .fatal
            }
        }()
        SentrySDK.capture(message: message) { $0.setLevel(sentryLevel) }
    }

    func setUser(id: String?) {
        if let id {
            let user = User(userId: id)
            SentrySDK.setUser(user)
        } else {
            SentrySDK.setUser(nil)
        }
    }

    func addBreadcrumb(_ message: String, category: String) {
        let crumb = Breadcrumb(level: .info, category: category)
        crumb.message = message
        SentrySDK.addBreadcrumb(crumb)
    }
}
```

**3. Register in `oneApp.init()`**

```swift
init() {
    MidnightResetManager.shared.registerBackgroundTask()

    // Crash reporting — production DSN
    let sentry = SentryCrashReporter(
        dsn: "<YOUR_SENTRY_DSN>",
        environment: {
            #if DEBUG
            return "debug"
            #else
            return "production"
            #endif
        }()
    )
    CrashReporter.shared.register(sentry)

    // Analytics
    #if DEBUG
    AppAnalytics.shared.register(ConsoleAnalyticsService())
    #endif
    // AppAnalytics.shared.register(PostHogAnalyticsService(apiKey: ...))
}
```

**4. dSYM upload (App Store Connect builds)**

Add a Run Script phase in Xcode → Build Phases (after "Copy Bundle Resources"):

```bash
if [[ "$(uname -m)" == arm64 ]]; then export PATH="/opt/homebrew/bin:$PATH"; fi
SENTRY_ORG=<org-slug> \
SENTRY_PROJECT=<project-slug> \
SENTRY_AUTH_TOKEN=<token> \
sentry-cli debug-files upload --include-sources "$DWARF_DSYM_FOLDER_PATH"
```

Store the auth token in a file outside the repo (never commit). Reference
pattern: keep it in `~/.sentryclirc` and only pipe secrets at build time.

## PostHog (product analytics)

**1. Add SPM package**
- URL: `https://github.com/PostHog/posthog-ios`
- Version: 3.x
- Add `PostHog` to target `one`.

**2. Backend adapter**

Create `one/Core/Utilities/Analytics/PostHogAnalyticsService.swift`:

```swift
import Foundation
import PostHog

final class PostHogAnalyticsService: AnalyticsService {
    init(apiKey: String) {
        let config = PostHogConfig(apiKey: apiKey, host: "https://eu.posthog.com")
        config.captureApplicationLifecycleEvents = true
        config.captureScreenViews = false // we route screens via events
        PostHogSDK.shared.setup(config)
    }

    func track(event: AnalyticsEvent) {
        PostHogSDK.shared.capture(event.name, properties: event.properties)
    }

    func identify(userID: String, properties: [String: Any]) {
        PostHogSDK.shared.identify(userID, userProperties: properties)
    }

    func reset() {
        PostHogSDK.shared.reset()
    }
}
```

**3. Register in `oneApp.init()`** (see Sentry example — same pattern).

## Privacy manifest

Add `one/Resources/PrivacyInfo.xcprivacy` with the standard data-collection
declarations for:

- **Crash data** (Sentry): `NSPrivacyCollectedDataTypeCrashData`,
  purpose `NSPrivacyCollectedDataTypePurposeAppFunctionality`, not linked.
- **Product Interaction** (PostHog): `NSPrivacyCollectedDataTypeProductInteraction`,
  purpose `NSPrivacyCollectedDataTypePurposeAnalytics`, not linked.
- **User ID** (identify): `NSPrivacyCollectedDataTypeUserID`,
  purpose analytics, not linked.

Both SDKs ship their own bundled privacy manifests — they merge at build.

## Verification checklist

After SDK wiring:

- [ ] App launches with no console SDK errors.
- [ ] Force a test crash in DEBUG (`SentrySDK.crash()`) — event lands in Sentry within 1 min.
- [ ] Onboarding completion fires `onboarding_completed` → visible in PostHog live events.
- [ ] Save a daily entry → `entry_saved` event with `has_photo`, `has_note` props.
- [ ] Send a friend request → `friend_request_sent`.
- [ ] User identity is set (`distinctId` matches CloudKit userID prefix in PostHog).

## Instrumented call sites (as of Phase 2)

| Event | Location |
|---|---|
| `entry_saved` | [TodayViewModel.saveEntry](../one/one/Features/Today/TodayViewModel.swift) |
| `onboarding_completed` | [OnboardingView.completeOnboarding](../one/one/Features/Onboarding/OnboardingView.swift) |
| `friend_request_sent` | [CloudKitFriendshipService.sendFriendRequest](../one/one/Core/Managers/CloudKitFriendshipService.swift) |
| `friend_request_accepted` | [CloudKitFriendshipService.acceptFriendRequest](../one/one/Core/Managers/CloudKitFriendshipService.swift) |
| `identify` | [oneApp.swift](../one/one/oneApp.swift) on `currentUser` load |

Remaining events (defined in `AnalyticsEvent` but not yet wired):
`song_searched`, `song_selected`, `mood_selected`, `photo_added`,
`note_added`, `circle_opened`, `discover_opened`, `recommendation_tapped`,
`event_tapped`, `playlist_opened`, `story_card_shared`,
`monthly_poster_shared`, `friend_invite_sent`, `friend_share_viewed`,
`onboarding_started`, `platform_selected`.

Add one call site per event as you touch those features.
