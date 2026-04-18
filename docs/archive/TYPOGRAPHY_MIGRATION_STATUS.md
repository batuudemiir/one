# ONETypography Migration — Accurate Status (Phase 1 audit)

Audited 2026-04-18 during Phase 1 code hygiene pass.

## Design system API

`UI/DesignSystem/ONETypography.swift` exposes:

- **Display (SF Pro)** — `displayXL/LG/MD/SM/XS` via `.displayXL()` … `.displayXS()` modifiers
- **Body (DM Sans)** — `bodyLG/MD/SM/XS` + `bodyMDMedium/bodySMMedium/bodyXSMedium`
- **Mono/Label (DM Sans + tracking)** — `.monoBase(tracking:)`, `.monoSM(tracking:)`, `.monoLabel(tracking:)`, `.monoMicro(tracking:)`

Rule: icon sizing with `.font(.system(size:))` on `Image(systemName:)` stays. Only text uses of `.font(.system(…))` / `Font.custom(…)` should migrate.

## Current state (49 files touched, 304 call sites remaining)

The earlier status file implied many views were "pending" — audit shows a mixed picture:

### Already fully migrated (verified 2026-04-18)
- [RecommendationCardView.swift](../../one/one/Features/Discovery/RecommendationCardView.swift) — all text uses `.bodyXS/.monoSM/.monoMicro/.monoLabel`; remaining `.font(.system(size:))` calls are `Image` sizing only.
- [RecommendationsSection.swift](../../one/one/Features/Discovery/RecommendationsSection.swift) — 1 remaining site is icon sizing (`Image(systemName: "arrow.clockwise")`).
- [DayPreviewCard.swift](../../one/one/Features/Archive/DayPreviewCard.swift) — original Phase 1 completion target.
- Interactive primitives (MoodButton, FeelingButton) in [ONEColorPickerView.swift](../../one/one/UI/ONEColorPickerView.swift) use `.monoSM/.monoLabel`.

### Genuinely pending — text uses remain
Ordered by user-facing weight:

- [ProfileView.swift](../../one/one/Features/Profile/ProfileView.swift) — **24 sites**, many are clearly text (weight `.medium/.bold`).
- [TodayEmptyView.swift](../../one/one/Features/Today/TodayEmptyView.swift) — **10 sites** mixed icon/text.
- [OnboardingView.swift](../../one/one/Features/Onboarding/OnboardingView.swift) — **5 sites** including headline weights.
- [CircleView.swift](../../one/one/Features/Circle/CircleView.swift) — **11 sites** (friend cards, badges).
- [AddFriendView.swift](../../one/one/Features/Circle/AddFriendView.swift) — **21 sites**.
- [CameraView.swift](../../one/one/Features/Camera/CameraView.swift) — **21 sites**.
- Discovery module: [DiscoverView](../../one/one/Features/Discovery/DiscoverView.swift) (8), [WeeklyPlaylistView](../../one/one/Features/Discovery/WeeklyPlaylistView.swift) (31), [FeaturedSongCard](../../one/one/Features/Discovery/FeaturedSongCard.swift) (4), etc.
- MonthlySummary module: [CoverCardView](../../one/one/Features/MonthlySummary/CoverCardView.swift) (13), [TopTracksCardView](../../one/one/Features/MonthlySummary/TopTracksCardView.swift) (11), [MoodMapCardView](../../one/one/Features/MonthlySummary/MoodMapCardView.swift) (9).

Full list: `grep -RnE '\.font\((\.system|Font\.custom)' one/one/` → 304 sites across 49 files.

## Recommended next pass

1. Audit each site: text vs icon. Icon sizing retains `.font(.system(size: …))` — do not touch.
2. Map text sizes to the nearest ONETypography token. Custom tracking is preserved via `.tracking()` or modifier arg.
3. Migrate per feature area: Profile → Today → Circle → Discovery → MonthlySummary → remaining.
4. Visual QA per screen (Dynamic Type XL + dark mode).

Target: 0 text-use `.font(.system(size:))` in Feature views. Icon uses remain as-is.

## Typography API reference

See [ONETypography.swift](../../one/one/UI/DesignSystem/ONETypography.swift) — self-documenting with SwiftUI View modifiers.
