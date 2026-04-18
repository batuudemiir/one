# CLAUDE.md — ONE Project

## Project Overview

**ONE** is a personal mood tracking and social iOS app (SwiftUI). Users select one song per day, assign a mood/color, and discover activity recommendations based on their mood. Social sharing with close friends is core to the experience.

**Slogan:** *Hisset. Keşfet. Paylaş.*

- **Bundle ID**: `com.batudemir.ones`
- **Minimum iOS**: 17.0+
- **Language**: Swift / SwiftUI
- **Xcode project**: `one/ones.xcodeproj`

---

## App Direction

- **Mood tracking** — daily song + mood/color as emotional snapshot
- **Discovery** — activity suggestions tailored to the user's current mood
- **Social** — share daily mood+song with close friends (Circle/Çevre)
- Gamification and streaks are permitted if they serve engagement

---

## Directory Structure

```
Desktop/one/                  ← root workspace
  one/                        ← git repo
    one/                      ← Xcode project folder
      one/                    ← app source
        oneApp.swift
        ContentView.swift
        Core/
          Managers/           ← CloudKitManager, SpotifyManager, CalendarManager, etc.
          Models/             ← DailyEntry, Song, AppError, etc.
          Extensions/
          Utilities/
        Features/
          Today/              ← TodayView, TodayViewModel, TodayEmptyView, TodayCompletedView
          Archive/
          Echo/               ← Pattern/repeat analysis
          Circle/             ← Social/friend sharing (CloudKit)
          Discovery/          ← Mood-based activity recommendations
          Onboarding/
          Profile/
          MonthlySummary/
          Share/
          Camera/
        UI/
          DesignSystem/       ← ONETokens, ONEAnimation, ONETypography, ONEMood, Color+ONE
          Components/
          Layout/
          ConfirmScreen.swift
          DoneScreen.swift
          ONEColorPickerView.swift
          SearchScreen.swift
      oneTests/
      oneUITests/
    ones.xcodeproj/
```

---

## Architecture

- **Pattern**: MVVM (`@StateObject` / `@ObservableObject`)
- **Persistence**: Core Data (`one.xcdatamodeld`) via `PersistenceController.shared`
- **Cloud**: CloudKit (public + private DB) via `CloudKitManager.shared`
- **Push**: APNs + CloudKit silent push via `AppDelegate`
- **Deep links**: `ones://` — Spotify callback (`ones://spotify-callback`), friend invites (`ones://add-friend?code=XXXXXX`)

---

## Key Managers

| Manager | Purpose |
|---|---|
| `CloudKitManager` | iCloud/CloudKit read/write, friend system |
| `CloudKitFriendshipService` | Friend requests, acceptance, subscriptions |
| `CloudKitDailyShareService` | Sharing daily songs with Circle friends |
| `CloudKitNotificationService` | Push notification subscriptions |
| `SpotifyManager` | Spotify Web API + OAuth token management |
| `CalendarManager` | EventKit — sync daily song to iOS Calendar |
| `MidnightResetManager` | Background task for daily reset |
| `ShareManager` | Instagram story cards, share sheets |
| `Persistence` | Core Data stack |
| `ErrorHandler` | Centralized `AppError` handling |

---

## Design System

All tokens in `UI/DesignSystem/`. **Always use tokens — never hardcode colors, fonts, spacing, or animations.**

- **`ONETokens`** — colors, spacing, corner radii
- **`ONETypography`** — font styles
- **`ONEAnimation`** — animation durations/curves
- **`ONEMood`** — mood color definitions
- **`Color+ONE`** — SwiftUI `Color` extensions

---

## Music Platforms

- **Apple Music** — MusicKit, permission on first launch
- **Spotify** — OAuth 2.0, client ID in `SpotifyManager.swift`, redirect: `ones://spotify-callback`

---

## Core Data Model

Primary entity: `DailyEntry`

Fields: `songTitle`, `artistName`, `albumName`, `artworkURL`, `moodWord`, `moodColorHex`, `moodIsDark`, `dailyNote`, `platform`, `createdAt`

- One entry per calendar day (enforced in `TodayViewModel`)
- Entries are immutable once saved

---

## Circle (Social) Feature

- Invite via code or QR
- Push-notified friend requests via APNs
- Deep link: `ones://add-friend?code=XXXXXX`
- Notification categories: `FRIEND_REQUEST` → `ACCEPT_FRIEND` / `DECLINE_FRIEND`
- See `CEVRE_FEATURE.md`, `CLOUDKIT_SETUP.md`

---

## Discovery Feature (Mood-Based Activities)

- Suggests activities (music, film, places, exercises) based on the user's selected mood
- Lives in `Features/Discovery/`
- Mood input: current `moodWord` + `moodColorHex` from today's entry

---

## Logging

```swift
ONELogger.debug("message", category: .cloudkit)
ONELogger.info("message", category: .circle)
ONELogger.success("message", category: .notification)
ONELogger.error("message", error: err, category: .general)
```

---

## Build & Test

```bash
xcodebuild -project ones.xcodeproj -scheme one -destination 'platform=iOS Simulator,name=iPhone 16'
xcodebuild test -project ones.xcodeproj -scheme one -destination 'platform=iOS Simulator,name=iPhone 16'
```

---

## Conventions

- **No hardcoded strings** — use `en.lproj` / `tr.lproj`
- **One song per day** — enforced in `TodayViewModel`, do not bypass
- **No force unwraps** — use `guard let` / `if let`
- **iOS 16 target** — guard iOS 17+ APIs with version checks
- **SwiftUI previews** — keep up to date when modifying views

---

## Active Development (2026-03)

- Circle/Çevre — CloudKit subscriptions, friend song sharing
- Discovery — mood-based activity recommendations (new feature)
- Typography migration — see `TYPOGRAPHY_MIGRATION_STATUS.md`
- CloudKit production schema — see `CLOUDKIT_PRODUCTION_DEPLOYMENT.md`
- Spotify production approval pending

---

## Key Docs

| File | Topic |
|---|---|
| `README.md` | Feature overview |
| `CLOUDKIT_SETUP.md` | CloudKit setup |
| `CLOUDKIT_PRODUCTION_DEPLOYMENT.md` | Production schema |
| `SPOTIFY_SETUP.md` | Spotify OAuth |
| `CEVRE_FEATURE.md` | Circle feature spec |
| `TYPOGRAPHY_MIGRATION_STATUS.md` | Typography migration |
| `BUNDLE_ID_DEGISIKLIK_REHBERI.md` | Bundle ID change guide |
