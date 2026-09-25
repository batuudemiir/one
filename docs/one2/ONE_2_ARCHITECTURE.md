# ONE 2.0 — Architecture Proposal

Date: 25 September 2026 · Status: **Proposal, not approved.** Until Batuhan accepts it, this document overrides nothing in `ADR-001.md`, `02_veri_modeli.md` or `04_arka_plan_motorlari.md`. Where it disagrees with them, the conflict is listed in §1.3 and the decision is listed at the end.

Scope: product architecture, app architecture, navigation, data architecture, feature boundaries. Out of scope: UI, the visual design system, SwiftUI screens.

Two constraints apply to every section:

- **P0. ONE's architecture must be derived from ONE's product thesis; Stoic is a reference for mechanisms and patterns, not the source of ONE's domain model.**
- **Smallest sufficient architecture.** Build the smallest architecture that can express ONE's core differentiated experience. Everything else must be *extensible*, not *present*.

### Evidence rules used in this document

| Tag | Source | Strength |
|---|---|---|
| **[S1]** | `docs/one2/design-system/ref/stoic-home.png` | Observed screenshot |
| **[S2]** | `docs/one2/design-system/ref/stoic-history.png` | Observed screenshot |
| **[S3]** | `docs/one2/design-system/ref/stoic-explore.png` | Observed screenshot |
| **[T]** | `01_stoic_teardown.md`, the "screen list to fill in" section. The list was compiled from Stoic's help center and Appllama screen groups | Second-hand inventory. The screens are listed, not observed |
| **[D]** | Statements about Stoic inside our own docs (`00_faz0_plan.md`, `04` E15) | Claims we have not verified |

The 7-day teardown protocol in `01_stoic_teardown.md` **has not been carried out**. Every checkbox is empty, and the notification log, metrics and screen specs are blank. So the Stoic evidence base is three screenshots plus a feature inventory. When those sources are silent, this document says **"Research does not establish this."** My own inferences are labelled **Assumption** and kept apart from the evidence.

---

## 1. Current ONE architecture assessment

The repo contains two codebases. **v3** is the App Store product and is treated as legacy. **ONE2-so-far** (`one/ONE2/`, about 5.7k lines, built in Faz 1 and in the engine work) is treated as a *candidate*: it is reusable only where it survives the thesis filter in this document.

### 1.1 v3 (legacy)

| Aspect | Finding | Source |
|---|---|---|
| Architecture pattern | MVVM-ish SwiftUI. 24 `ObservableObject` view models, 0 `@Observable`. Heavy use of `.shared` singletons (`CloudKitManager.shared` 57 uses, `PersistenceController.shared` 31, `GlobalUIState.shared` 21) | AUDIT, ADR §4 |
| Navigation | Custom `BottomNavigation` with 4 `PrimaryTab`s (`entry`, `archive`, `circle`, `profile`). Tabs switch through `NotificationCenter` broadcasts (`switchTo*Tab`) and are restored with `@SceneStorage`. Deep links run through `LaunchIntent` | `one/UI/Components/PrimaryTab.swift`, `one/ContentView.swift`, AUDIT R15 |
| State management | Per-screen `ObservableObject`s plus global singletons. `GlobalUIState` holds cross-screen UI state | AUDIT |
| Persistence | Core Data + `NSPersistentCloudKitContainer` (`iCloud.com.batu.ones`, private DB). There is **one entity, `DailySong`**, with 28 fields and no relationships: one mood color (a free hex value is allowed), a note, a song, a photo, and a `passed` flag. It is already deployed to the CloudKit production schema and can never be removed | `one/one.xcdatamodeld`, AUDIT §4 |
| Social persistence | CloudKit **public** DB. 8–9 record types (Circle), 5 query subscriptions, Sign in with Apple, `MidnightResetManager` BG task | AUDIT §4.3, ADR §10 |
| Major feature modules | `Features/Today` (song + color moment), `Archive` (color mosaic), `Circle`, `Comments`, `Echo`, `MonthlySummary`, `Onboarding`, `Profile`, `PublicProfile`, `Share`, `Camera` | `one/Features/` |
| Important dependencies | SPM: PostHog only. Apple: CoreData, CloudKit, MusicKit, WidgetKit, ActivityKit, AppIntents, LocalAuthentication, AuthenticationServices, BackgroundTasks, MetricKit, Contacts, AVFoundation | AUDIT §2 |
| Main architectural problems | (1) Music-first data model: the day is a song plus a color. (2) Everything lives in one flat entity, with no way to hold multiple moments or reflections. (3) Singletons make testing and dependency injection hard. (4) Navigation is event-bus based. (5) The social layer is the largest and riskiest code, about 11.9k lines. (6) The recovery path deletes the store without a backup (fixed in Faz 1). (7) There is no CI and the test plan is broken (fixed in Faz 1) | AUDIT R2–R17 |
| Reusable | `PersistenceController` infrastructure (container, history pruning, remote-change debounce, backup-before-recovery), `KeychainHelper`, `AppLockManager`, `ArchiveExporter` (pattern), `NotificationOrchestrator` + `NotificationPolicy` + `NotificationMessageBuilder`, `WidgetDataWriter` pattern + widget kind `MoodWidget`, `AppAnalytics` protocol + PostHog adapter, `CrashReporter`/`LaunchMetricsCollector`, `Experiment`/`Features`, `LanguageManager` + 9 `.lproj`, state components (`V3Loading`, `ONEErrorView`, `ONEToast*`), `Moment`/`Day` structs (read-only legacy view) | AUDIT §7 |
| Remove or replace | All `Features/*` screens, `CloudKitManager` + social services, `SpotifyManager`, `SongRecommendationEngine`, the v3 reminder, Sunday and monthly schedulers, `MidnightResetManager`, the Live Activity target, `AppleSignInService`, the 102-case `AnalyticsEvent` catalog, `V3Mood`/`ONEMood` as a *mood model*, `MomentDeduplicator` (keep its idea), and NotificationCenter tab switching | AUDIT §7, ADR §2, §10 |

### 1.2 ONE2-so-far (candidate)

| Aspect | Finding | Source |
|---|---|---|
| Pattern | `@Observable` + `Router` (`ONE2Tab`, `Route`, `SheetRoute`, a stack per tab) + `AppEnvironment` passed through `@Environment(\.one2)`. No new singletons | `one/ONE2/App/` |
| Navigation | System `TabView` with 4 tabs: `today`, `journey`, `explore`, `profile`. `DeepLink` is a pure function that returns a `Destination` | `Router.swift`, `ONE2RootView.swift`, `DeepLink.swift` |
| Persistence | Core Data model `one 3` with 13 entities (`DailySong` + 12 new). **Deployed to development only, not production** (ADR Faz 1 #10, MIGRATION §5). The stores (`JournalStore`, `MoodStore`, `DayStore`, `LibraryStore`, `ExposureStore`, `ProfileStore`, `LegacyMomentStore`) run synchronously on `viewContext` and return `Sendable` value types | `one/ONE2/Data/` |
| Domain values | `JournalEntry`, `EntryAnswer`, `MoodCheckIn`, `JournalTag`, `EarnedBadge`, `PracticeItem`, `DayCompletion`, `StreakState`, `DayKey` | `Data/JournalValues.swift`, `Core/` |
| Engines | 10 pure-core engines: Quote, Prompt, Echo, Recommendation, ThemeCalendar, Badges, Insights, Search, Widget (bridge + snapshot), NotificationPlanner. All deterministic through `AppClock` + `SeededRandom` | `one/ONE2/Engines/`, `04` |
| Tests | Swift Testing covers stores, `DayKey`, `Streak`, engines, deep links, legacy reads and the model version. CI exists (`.github/workflows/ci.yml`) | `oneTests/` |
| Debt / risks | (1) `AppEnvironment` owns 19 dependencies **and hides write side effects**: `journal.didSave` → day completion → badges → widget → notifications. That flow sits in a closure in the initializer. (2) **No object represents "the day"**: every surface would have to put it together from 4–5 stores. (3) `DayRecord` stores *derivable* facts (`dailyCompletedAt`, `morningCompletedAt`, `eveningCompletedAt`, `backfilledAt`, `completedBy`) even though CLAUDE.md says derived data is not stored. (4) Streak is a domain-level primitive (`Core/Streak.swift`, `DayStore.streakState`). (5) The engines' content machinery (800+ quotes, 150 echoes, 20 badges) was sized for a quote-and-writing product before this thesis existed. (6) The schema carries 7 entities that no current flow needs (§5.1) and is heading for an irreversible production deploy | code, `04` |

### 1.3 Conflicts with existing docs (raised as CLAUDE.md requires, not fixed)

| # | Conflict | Where |
|---|---|---|
| K1 | The design-system README positions ONE 2.0 as "a **writing and self-improvement** app", while the thesis here is "Your day, in one feeling" as a personal record | `docs/one2/design-system/README.md` |
| K2 | The README defines 5 tabs (Today, Quotes, Explore, Journey, Trends). `Router` has 4 tabs (Today, Journey, Explore, Profile). This document recommends 2 (§7) | README, `Router.swift` |
| K3 | A streak pill in the Today top bar and E8 treat streak as core. This document moves streak below the domain layer (§5.4) | README, `ScreenBugun.md`, `04` E8 |
| K4 | `DayRecord` persists derivable completion fields, against the CLAUDE.md rule "Türetilen veri (seri, istatistik) saklanmaz" (derived data such as streaks and statistics is not stored) | `02` v0.2, `one 3` |
| K5 | The quote content target (800 → 1,500 items) and a Quotes tab were decided before the thesis. This document treats quotes as optional content | `04` E2 + decision 5 |
| K6 | ADR §7 says "V3Tokens TAŞI" (keep V3Tokens). `05_ux_promptlari.md` says that is invalid for ONE 2.0 and introduces `ONE2Tokens`. This is not in scope here, only noted | ADR §7, `05` |

---

## 2. Stoic product architecture analysis

### A. Entry / onboarding

| Question | Finding |
|---|---|
| What does Stoic establish about the user? | [T] lists "Onboarding quiz steps (each one separate)", a notification permission step ("at which step?"), an optional account / Sign in with Apple ("does it exist, at which step?"), a first paywall, "all plans", and a premium welcome with Face ID activation. The *content* of the quiz questions: **Research does not establish this.** |
| What does onboarding configure? | [T] lists a "Personalize" screen, a mode choice (Daily Check-In vs morning + evening), reminder settings, "Track Mood on Launch" and "Show Memories" toggles, and Quotes path selection. Which of these onboarding sets, and which are set later: **Research does not establish this.** |
| Minimum before the daily experience starts | **Research does not establish this.** (`01` asked us to measure the number of onboarding steps and the time to first check-in; both are blank.) |

### B. Daily experience: the underlying loop

Observed Today anatomy [S1], top to bottom:

1. A streak pill ("2").
2. A time-of-day greeting.
3. A **week strip** (Mo–Su) with ✓ on completed days and today boxed.
4. A card holding a single **echo sentence** and a **mood pill** ("Neutral Mood").
5. "Your Practices" (one pinned practice, plus an edit control).
6. "Weekly Theme" with "See All".
7. A floating **+** button.
8. A 5-tab dock: Home, Quotes, Explore, History, Trends.

The loop, as far as the evidence supports it:

```
User opens app
↓  Launch mood check-in ("Track Mood on Launch" [T]; "multiple moods a day, at every open, like Stoic" [D])
↓  Today [S1]: the date anchors the day (week strip). Today's mood + one echo sentence
↓  Optional depth: a practice, the weekly theme prompt, + (blank page, suggestion, templates, guided) [T][S1]
↓  Mode rituals: morning prep (focus) / evening reflection (habit tracker) [T]
↓  Saved as typed records inside the day (Mood Check-In 11:39, a photo, Daily Check-In 01:53) [S2]
↓  Completion screen + tag [T]; ✓ on the week strip; streak count [S1]
↓  Return: the week strip gap, streak, reminders [T], the weekly theme cadence [S1][T]
```

- Why the user returns tomorrow, beyond these mechanisms: **Research does not establish this.** There is no retention data and no notification log.
- Which record the Home mood pill reflects: **Research does not establish this.** [S1] shows "Neutral Mood" on Home. [S2] shows "Excellent Mood" at 11:39 for the same day, and a Daily Check-In at 01:53 whose mood is not visible.

**Underlying loop (my reading):** *anchor the day → capture state cheaply → offer optional depth → accumulate typed records in the day → visibly mark the day → come back.* The structure is the day. Everything else hangs off it.

### C. Reflection / journal architecture

| Concept | Evidence |
|---|---|
| Typed records per day | [S2]: "Mood Check-In", a photo card, "Daily Check-In", each with a time. They are heterogeneous records in one day-grouped stream |
| Prompts + answers | [T]: weekly theme daily prompt, journaling suggestions, guided journals (multi-step), custom templates (prompt + 1–5 scale + yes/no) |
| Free-form | [T]: a blank page editor with formatting, media, audio recording and drawing |
| Emotions | [T]: an "Emotions Check-In" with a count and categories still to be measured. Mood as a named level ("Neutral", "Excellent") [S1][S2] |
| Tags | [T]: a tag on the completion screen; filters in Journey |
| Attachments | [S2] photo; [T] audio, drawing |
| Generated insights | [T]: an Insights card, Trends (mood, emotion, activity, health, exercise calendar); AI "Go Deeper" dialogue with mentors (premium) |
| Structured vs free-form | Both exist [T]. How they are stored: **Research does not establish this.** |

### D. Content / practice architecture

- Stoic visibly separates **user records** (History [S2]) from **content** (Explore [S3]: a featured item with a date range and CTA, category cards "Journaling" and "Breathing", lock / NEW / FEATURED badges).
- It also has **Quotes** as a separate tab [S1], and **practices** pinned to Today [S1].
- Content kinds [T]: weekly themes, guided journals, library categories, breathing, meditation, quotes with "paths".
- A practice seems to be *content the user pins*. The "Moment of Gratitude Journal" tile in [S1] is **Assumption** on this point.
- How content links to the records it produces: **Research does not establish this.**

### E. History / insights

- Daily data → History: the day-grouped stream [S2] with period modes Days, Weeks, Months, Years and Smart [T], plus filters and search [S2].
- History → patterns: Trends [T] (mood, emotions, activity, health).
- Patterns → insights: the Insights card [T].
- "Show Memories" [T] suggests resurfacing past records. How it works: **Research does not establish this.**
- Whether insights are stored or computed: **Research does not establish this.**

The distinction ONE needs anyway:

- **Raw data** is what the user entered.
- **Derived data** is computed from raw data: aggregates, series, continuity.
- **User-facing insight** is a derived observation plus wording, shown only when enough data exists.

### F. Progress / retention

| Mechanism | Evidence | Structural or engagement? |
|---|---|---|
| The day as the unit (week strip, day headers) | [S1][S2] | **Structural.** Without it the history has no spine |
| Unified history | [S2] | **Structural.** It is where accumulation becomes visible |
| Recurring rituals (morning/evening, daily check-in) | [T] | **Structural** as record types. The *schedule* is engagement |
| Weekly theme | [S1][T] | Mixed. It structures content; its cadence drives return |
| Streak count | [S1] | **Engagement.** It re-expresses completed days |
| Badges | [T] | **Engagement** |
| Notifications | [T] | **Engagement** |
| Unfinished activities / backfill / streak repair | [T] (listed to observe) | Engagement around a structural fact (the missing day). How they behave: **Research does not establish this.** |
| Personalization (mode, paths, practices) | [T] | Configuration of structure |
| Premium placement | [T], [D]: "Stoic makes streak, sync and lock premium" | Monetization. [D] is unverified |

---

## 3. Architectural principles

Each principle is tagged with where it comes from: **[Stoic]** means evidenced as a Stoic mechanism, **[Thesis]** means derived from ONE's thesis or rules.

| # | Principle | Source |
|---|---|---|
| **P0** | **ONE's architecture must be derived from ONE's product thesis; Stoic is a reference for mechanisms and patterns, not the source of ONE's domain model.** | Batuhan |
| P1 | **The local day is the unit.** Every record carries `dayKey`, and every surface reads by day | [Stoic] [S1][S2] + existing rule |
| P2 | **One stream of heterogeneous records.** Different record kinds live in one day-grouped history instead of separate silos | [Stoic] [S2] |
| P3 | **Content and user data are separate domains.** Content is referenced by ID + snapshot and is never owned or mutated by the user | [Stoic] [S3] vs [S2] + `02` |
| P4 | **Derived is computed, not stored.** A persisted derived value is allowed only as a declared, rebuildable cache | [Thesis] / CLAUDE.md |
| P5 | **The past must not change when the algorithm changes.** Anything that *represents* a past day to the user as "what that day was" is user-authored and persisted. It is not re-derived by the current code | [Thesis] ("a record") |
| P6 | **The user names the feeling.** The app may suggest. It never assigns a day's feeling on its own | [Thesis] / CLAUDE.md copy rule "duyguyu kullanıcı adlandırır" (the user names the emotion) |
| P7 | **Entry costs seconds; depth is optional.** The minimum daily act must be complete by itself | [Stoic] launch check-in [T] + [Thesis] |
| P8 | **History is a first-class surface**, not a settings-level archive | [Stoic] [S2] |
| P9 | **Retention mechanics sit on top of structure, never inside it.** Streaks, badges and reminders read domain facts. No domain rule depends on them | [Stoic] analysis F + Batuhan R3 |
| P10 | **Smallest sufficient architecture.** Anything not needed by the differentiated core stays extensible, not present | Batuhan |

---

## 4. Stoic → ONE translation

| Stoic mechanism (evidence) | What ONE takes | What ONE does *not* take |
|---|---|---|
| The day as an anchor, with a week strip [S1] | P1: the day is the unit | The Stoic week-strip semantics, where ✓ means "ritual done" |
| A cheap launch check-in [T] | P7: a moment capture that takes seconds | Launch-time forcing (**Assumption**: forcing it contradicts "calm") |
| Typed records in one day stream [S2] | P2 | Stoic's record types: breathing, meditation, habit tracker |
| Content vs records [S3] vs [S2] | P3 | Mentors, the quote curation, content categories, visuals |
| Rituals (morning/evening) [T] | Possibly as *record kinds* later | Rituals as the definition of "a completed day" |
| Streak and badges [S1][T] | At most a *representation* of continuity (§5.4) | Streak as a domain primitive |
| Trends / insights [T] | Derived views over records (P4) | Health and exercise trends |
| Quotes tab [S1] | Nothing required. Quotes are optional content | A Quotes tab (decision D6) |

**What the thesis adds that Stoic does not evidence.** "Your day, in one feeling" + "a day can leave something behind" + "a personal record". Stoic evidences a day as a *container of activities*. It does not evidence a single, user-named, day-level feeling, or a single thing that remains from the day. **Research does not establish** whether Stoic has anything like that (the Home mood pill could be the last check-in [S1]).

**Candidate differentiators** (listed, not chosen; see Decision D1):

- (a) naming the day's one feeling
- (b) keeping one thing the day leaves behind (a line, a photo, a song)
- (c) the accumulated record of days, "a year in feelings"
- (d) moments across the day distilled into one

The architecture in §5–§6 is judged on whether it makes **each** of these *structurally* possible, as data and flow, and not just as naming or visuals.

---

## 5. ONE domain model

§5 stays neutral about the day-level object. That question is resolved in §6, and §5.3 shows the result.

### 5.1 MVP entity filter

Each entity must answer three questions: (1) which concrete ONE 2.0 flow needs it; (2) why it must be persisted; (3) what breaks if it is removed. Adding an entity or field later is cheap: a lightweight migration plus a schema deploy. **Removing one after a production deploy is impossible.** When in doubt, leave it out.

| Entity (`one 3`) | (1) Flow | (2) Why persisted | (3) If removed | Verdict |
|---|---|---|---|---|
| `Entry` | Reflection: prompt or free writing attached to a day | User-authored text is the primary record | No reflection at all | **MVP** |
| `EntryAnswer` | Multi-question flows only (guided, templates, morning/evening scripts) | Each answer to a structured step | A single prompt + text still works (`Entry.contentSnapshot` + `body`) | **Post-MVP** unless the MVP ships multi-step flows (D8) |
| `MoodLog` | Moments: "how am I now", several times a day | A user statement at a point in time | No moments. The day's feeling has nothing to be suggested from | **MVP** |
| `DayRecord` | Depends on §6 | Depends on §6 | — | **Resolved in §6** |
| `Media` | "Something remains": a photo or song as the day's keepsake, or a photo in an entry | User binary data (CKAsset) | No photo or music memory | **MVP if D4 = yes**, as one entity for `photo` + `song` |
| `Tag` | User-defined labels on entries | User vocabulary | MVP "what influenced it" is covered by the `causeIDs` catalog on `MoodLog` | **Post-MVP** |
| `Template`, `TemplateItem` | Custom templates (premium) | User-designed structures | Nothing in the core | **Post-MVP** |
| `MetricDefinition` | Custom metrics (1–5, yes/no) | User-defined | Nothing in the core | **Post-MVP** |
| `BadgeAward` | Badges | The award date is the only non-derivable part | Engagement only (P9) | **Post-MVP** |
| `Practice` | Pinned content on Today | User's list order | If pinning ships, a small ordered ID list in synced settings (KVS) is enough. No record type needed | **Not an entity**; post-MVP |
| `ContentExposure` | Non-repeating quotes and prompts across devices, favorites | Cross-device "seen" history | Quotes and prompts may repeat. Acceptable for a small MVP prompt set | **Post-MVP** unless Quotes stays a core surface (D6) |

| Content type | Nature | MVP? |
|---|---|---|
| Prompt | Content (bundled JSON, ID + snapshot in `Entry`) | **Yes, small set.** Reflection needs a question |
| Theme (weekly) | Content + calendar rule (`ThemeCalendar`) | Optional. It is a cadence mechanism, not core (D7) |
| Quote | Content | Optional (D6) |
| Guided | Content (multi-step) | Post-MVP (depends on `EntryAnswer`) |
| Catalogs (emotions, causes) | Content | **Yes.** The feeling vocabulary |

Content is never persisted as user data (P3). A record that used content stores `contentRef` + a snapshot, so the record stays readable even if the content disappears.

### 5.2 Entities independent of the day-object question

| Entity | Responsibility | Key properties (existing `one 3` names) | Relationships | Persisted / derived | Lifecycle |
|---|---|---|---|---|---|
| **Moment** (`MoodLog`) | A point-in-time feeling statement | `id`, `dayKey`, `timeZoneID`, `timestamp`, `emotionIDsJSON`, `score` (0 = none), `causeIDsJSON`, `note`, `source` | Optional → `Entry` (inverse) | Persisted | Created on check-in. Editable, deletable. Never merged |
| **Reflection** (`Entry`) | User writing, free or prompted | `id`, `dayKey`, `timeZoneID`, `createdAt`, `updatedAt`, `kind`, `title`, `body`, `contentRef`, `contentSnapshot`, `isBackfilled`, `wordCount`*, `searchText`* | → `MoodLog?`, →> `Media` | Persisted (*declared caches) | Draft (device-local) → saved → edited → deleted |
| **Media** | Photo or song | `id`, `type`, `data`/`thumbnail` (external), `song*` fields, `order` | → `Entry?` | Persisted | Created with its owner, cascades with it |
| **Day** (concept) | *Everything recorded on one local day* | `dayKey` → its moments, reflections, media | Query by `dayKey`, not a relationship (existing rule, so CloudKit merges cannot break links) | **Derived** (a query) in every option | Exists as soon as any record has that `dayKey` |
| **Continuity** | Days kept, calendar fill, gaps, accumulation | Computed from records | — | **Derived** | Recomputed on change |
| **Insight** | Observation over a period | See `InsightsEngine` | — | **Derived** | Recomputed. Shown only past a data threshold |
| **Profile/Settings** | Name, reminder times, preferences | `ProfileStore` keys | — | KVS + App Group (not Core Data) | Onboarding → settings |

### 5.3 Relationship diagram

This diagram is drawn for the §6 recommendation. The alternatives appear in §6.4 as diffs.

```text
Content (bundled/remote JSON, read-only)          User data (Core Data, CloudKit private DB)
  Prompt ─┐                                        
  Emotion/Cause catalog ─┐                          ┌──────────── dayKey (yyyy-MM-dd, local) ────────────┐
                         │ referenced by ID +      │                                                      │
                         └── snapshot ───────────► Moment (MoodLog)*        Reflection (Entry)*          ONE (§6)
                                                   │  0..1 ◄──────────────► 0..1 │                        0..1 per dayKey
                                                   │                             └──►> Media*            │ keepsakeRef → one of
                                                   │                                                     │ {Entry, MoodLog, Media}
                                                   └──────────── Day = all records with the same dayKey ─┘ (by ID, not relationship)

Derived (never stored): Day view · Continuity · (optional) streak representation · Insights · Search results
Legacy (read-only): DailySong → LegacyMomentStore → shown as "ONE 1" days
```

### 5.4 Streak: below the domain layer

```text
Domain fact          Derived (Application)                        Representation (Presentation / Engagement)
DayCompletion  ───►  Continuity                          ───►     optional: streak count, streak reminder, badges
(per day: does       • days recorded (total, this month/year)
 the day have a      • week/month fill (which days have a ONE / any record)
 ONE? any record?)   • gaps, days since last record
                     • longest run (computed, not stored)
```

- **The primary product truth is the accumulated days and records.** A streak is one way to *display* runs within Continuity.
- The existing `Core/Streak.swift` and `DayStore.streakState` would move to the representation layer as a function over Continuity, keeping their tests. `DayCompletion` stops being stored (K4) and is computed from records.
- **Should streak be in the MVP?** The thesis favours "accumulation without pressure". A streak counter frames a missed day as a *loss*, and a personal record should treat it as a *gap*. Recommendation: **the MVP shows continuity (week and month fill, days recorded) but no streak counter.** The streak function stays available behind a representation flag, so it can be switched on later without schema work. This is a product call (D5), and it conflicts with K3.

---

## 6. The ONE daily object

### 6.1 Definitions

- **Day**: the complete collection of what happened or was recorded on a local day (`dayKey`): moments, reflections, media. It always exists implicitly, and in every option it is a derived aggregate (§5.2).
- **ONE**: the product's *distilled representation* of that day. Its candidate contents: the day's one feeling, and optionally one line and one thing the day leaves behind. The rest of this section asks whether the ONE deserves its own persisted form, and in what shape.

### 6.2 Structural options

| # | Option | What is persisted at day level |
|---|---|---|
| **S1** | Same entity (Model A: `DayRecord` = ONE) | One per-day row holding both day bookkeeping (completion fields, focus) and the distillation (feeling, line, keepsake) |
| **S2** | Separate entities (Model B: `DayRecord` = day container + a `One` artifact) | A day row (container/bookkeeping) **and** a separate ONE row per day |
| **S3** | One source model + derived ONE read model | No day-level row. The ONE is computed from the day's records every time |
| **S3′** | One source model + a *minimal persisted distillation* | The day container is derived (as in S3). Only the **user-authored** parts of the ONE (chosen feeling, optional line, optional keepsake reference) are persisted in one small per-day row. Everything else about the ONE (suggestion, counts, completeness) is derived |

S3′ is listed separately because P4 (derived is not stored) and P5/P6 (past days are user-authored and must not be re-derived) pull in opposite directions. S3′ is the shape that satisfies both.

### 6.3 Completion options

| # | Completion model | Meaning |
|---|---|---|
| **C1** | Explicit completion / sealing | The user performs a closing act, and the day is "sealed" |
| **C2** | Automatic daily completion | A rule, or midnight, completes the day |
| **C3** | No completion state | Days just have records. A ONE may be set or changed at any time. "Complete" is not a concept |
| **C4** | Derived ONE from accumulated data | The app computes the day's feeling (last, dominant or average) |

### 6.4 Evaluation

Scale: ● strong, ◐ partial, ○ weak or conflicting.

**Structural options × capabilities**

| Capability / criterion | S1 (A) | S2 (B) | S3 derived | S3′ minimal persisted |
|---|---|---|---|---|
| Thesis: "your day, in one feeling" | ● a per-day feeling field | ● a ONE row | ◐ the feeling is computed, so it is the app's reading (P6) | ● a user-named feeling |
| Multiple moments in a day | ● | ● | ● | ● |
| Reflection | ● | ● | ● | ● |
| Photos | ● | ● | ◐ no way to pick *the* photo | ● keepsake ref |
| Music memories | ● | ● | ◐ same | ● keepsake ref |
| History (one card per day) | ● one fetch | ● one fetch | ◐ a compute per day | ● one fetch + derived body |
| Insights (one point per day) | ● | ● | ◐ the series shifts if the algorithm changes (P5) | ● |
| Yearly reflection ("a year in feelings") | ● | ● | ○ unstable across app versions | ● |
| Future AI | ◐ no provenance unless added | ● room for provenance | ◐ AI output would *be* the ONE (P6 risk) | ● AI may *suggest*; the user's choice is stored with provenance |
| "Something remains from the day" | ● | ● | ○ nothing is chosen, so nothing *remains* | ● |
| P4 derived-not-stored | ○ keeps derivable completion fields (K4) | ○ the container row duplicates the query | ● | ● only user-authored facts are stored |
| Schema cost (irreversible) | Low: fields on one entity | Higher: 2 day-level record types | None | Low: 1 small record type (reshape the undeployed `DayRecord`, or add a new one) |
| Sync / conflicts | Per-day dedupe (exists) plus field merge rules | Two per-day dedupes | None | One per-day dedupe (the existing `DayStore.reconcileDuplicates` pattern) + last-writer by `updatedAt` |
| Editable / backfill | ● | ● | ● (automatic) | ● |
| Empty or incomplete day | Row with nil fields | Container without a ONE | Nothing to show | "Open day": derived Day, no persisted ONE |
| Legacy `DailySong` display | ● a v3 day already *is* one color + note + song + photo, so it maps to a ONE-shaped card | ● | ◐ | ● |
| Smallest sufficient (P10) | ◐ | ○ | ● | ● |

**Completion options × thesis**

| Criterion | C1 explicit seal | C2 automatic | C3 no completion | C4 derived ONE |
|---|---|---|---|---|
| User names the feeling (P6) | ● | ○ the app closes the day for the user | ● if the ONE is set by the user | ○ |
| Friction | ◐ an extra closing act; unsealed days pile up | ● none | ● none | ● none |
| Closure as a ritual | ● | ○ | ◐ available as a moment, not required | ○ |
| Pressure / guilt | ◐ "unsealed" can read as unfinished | ● | ● | ● |
| Stable past (P5) | ● | ◐ | ● | ○ |
| Structural need for a "sealed" state and timestamp | Yes | Yes (rule engine) | No | No |
| Fits "something remains" | ● | ◐ | ● | ○ |

Notes on the tables:

- C4 is not viable as the *ONE*, because it conflicts with P5 and P6. It **is** useful as a *suggestion* inside C1 or C3 (for example, pre-selecting the most recent moment's emotion).
- C2 is really a streak or completion rule. Under §5.4 it belongs in Continuity, not in the ONE.
- The difference between C1 and C3 is mostly *ceremony*. C1 needs a persisted `sealedAt` and makes "unsealed" a visible state. C3 needs neither. The distilled feeling can be set whenever the user is ready, and a day without one is simply an *open day*.

### 6.5 Recommendation (hypothesis, requires D2)

**S3′ + C3, with an optional closing moment:**

- **Day** = derived (all records by `dayKey`). No day container is persisted.
- **ONE** = one small per-day row holding only what the user authored:
  - `dayKey`
  - `emotionID` (the one feeling, named by the user from the catalog)
  - `line` (optional: the sentence the day leaves)
  - `keepsakeKind` + `keepsakeID` (optional: a pointer to one existing Entry, Moment or Media of that day)
  - `origin` (`user` / `suggestionAccepted`: provenance for future AI)
  - `createdAt`, `updatedAt`
- Whether the row is called `DayRecord` (reshaped before its first production deploy) or gets a new name is a technical choice. Reusing `DayRecord` keeps the existing dedupe code, and "the record a day leaves" fits the thesis. **Assumption:** reusing it is preferable. This is a *candidate* change to the undeployed `one 3`, and nothing is edited by this document.
- **No sealing state.** A closing moment (for example, an evening "your day in one feeling") is a *flow* that writes the same row. It is not a separate state. If D1 decides that closure *is* the irreplaceable action, C1 can be added later as one `sealedAt` field (an additive change).
- **Why not S1:** it keeps derived completion fields and mixes bookkeeping with the artifact (K4). **Why not S2:** it creates two per-day record types to express one user act. **Why not S3:** a derived ONE violates P5 and P6, and it makes "something remains" impossible.

Differentiator check (§4). Under S3′ + C3:

- (a) naming the feeling is a first-class write.
- (b) keeping something is `keepsakeRef` + `line`.
- (c) the year in feelings is a stable per-day series.
- (d) moments distilled into one works as suggestion + choice.

All four are structurally possible, and none of them requires the others.

### 6.6 The ONE, under the recommendation

| Question | Answer (S3′ + C3) | If S1 / C1 were chosen instead |
|---|---|---|
| What makes a ONE? | A user-named feeling for a `dayKey`. Line and keepsake are optional | S1: a feeling field on the day row. C1: plus a seal |
| When is it created? | When the user first names the day's feeling (from a moment, from the evening prompt, or from the day view) | S1: the row exists from the first record of the day |
| When is it complete? | There is no "complete" state. A day has a ONE or is open | C1: when sealed |
| Editable? | Yes, any time. `updatedAt` resolves sync conflicts | C1: edit after seal is a product rule (D2) |
| Multiple reflections? | The Day holds any number. The ONE may *point to* one of them as its keepsake | Same |
| Music / media? | Yes, as a keepsake pointer to `Media` (D4) | Same |
| Without a mood? | A day can exist without a ONE (open day). A ONE by definition has a feeling | S1: a row without a feeling can exist |
| Incomplete? | "Open day" is a legitimate, non-penalized state | C1: "unsealed" state |
| In history | One card per day. A day with a ONE shows the feeling (+ line / keepsake). An open day shows its records. Legacy `DailySong` days render as read-only "ONE 1" days | Same shape |
| In insights | Primary series: the ONE feelings over days (stable). Secondary: moments within days. Writing volume. "On this day" | Same |
| Backfill | Allowed within the existing 7-day window (`04` decision 1) | Same |

---

## 7. Information architecture

The navigation is derived from §6. The product's objects are: *today's day* (in progress), *the record of days* (history of ONEs), *understanding* (patterns over that record) and *content* (prompts and practices).

| User job | Frequency (**Assumption**, no data) | Object |
|---|---|---|
| Capture how I am now; name today's feeling | Daily, several times | Today |
| Write about today | Daily or weekly | Today → editor |
| See a past day / what remained | Weekly | Days |
| See what my days add up to | Monthly or yearly | Days (patterns lens) |
| Find a prompt or practice | Occasional | Content |
| Settings, lock, export | Rare | Profile |

### 7.1 Candidate models

| Criterion | (i) Today · Journey · Explore | (ii) Today · Days | (iii) Stoic-like 5 tabs (Today · Quotes · Explore · Journey · Trends), per the README |
|---|---|---|---|
| Maps to user jobs | ● | ● content reached from Today (prompt of the day, + sheet) | ◐ two tabs serve occasional jobs |
| Daily ritual | ● | ● the whole ritual is one surface | ● |
| Product differentiation | ◐ reads as a journaling app with a library | ● "today" and "all my days" *is* the thesis | ○ structurally indistinguishable from Stoic (P0) |
| Frequency fit | ◐ Explore is occasional but primary | ● both tabs are frequent | ○ Quotes and Trends are occasional |
| Information hierarchy | ◐ insights hidden in Journey | ● Days has a zoom: day → week → month → year, and patterns are the zoomed-out view of the same record | ◐ patterns split from the record they describe |
| Cognitive simplicity | ◐ 3 | ● 2 | ○ 5 |
| Cost to extend | Add a tab | Add Explore as a 3rd tab when content volume justifies it | — |

### 7.2 Recommendation (hypothesis, D3)

**(ii) Today · Days.** Profile opens from the top bar. Content opens from Today and has no tab. This follows from §6: the product is *a day* and *the record of days*. Patterns ("what my days add up to") are the zoomed-out lens of Days, not a separate place.

| Destination | Why it exists | User job | Data it owns (reads) | Actions | Primary? |
|---|---|---|---|---|---|
| **Today** | The day being lived | Capture moments; name the day's feeling; write; see today's prompt | Today's derived Day; today's ONE; prompt of the day | Add a moment, set or change the ONE, open the editor, open a prompt | **Yes**, the daily surface |
| **Days** | The accumulated record | Revisit days; see continuity; see patterns | All ONEs, derived Days, Continuity, Insights, search | Open a day, zoom period, search, filter, backfill (≤ 7 days) | **Yes**, the long-term surface |
| Day detail | One day in full | Read or edit what a day contains | One derived Day + its ONE | Edit or delete records, change the ONE / keepsake | No (a push from Today or Days) |
| Editor | Writing | Reflect | Draft (device-local) → `Entry` | Save, attach a photo or song | No (sheet) |
| Moment capture | Check-in | "How am I now" | → `MoodLog` | Save; optionally "make this the day's feeling" | No (sheet) |
| Profile / Settings | Configuration | Reminders, lock, export, legacy switch | Profile settings | Toggle and export | No (top bar) |
| Content (prompts; later a library) | Depth | A question to write to | Content catalog | Start a reflection | No, until content volume grows (then (i)) |

This conflicts with K2 (the README's 5 tabs and Router's 4). The `Route.insights` already in Router becomes a Days lens.

---

## 8. Core user flows

The flows assume the recommendations in §6.5 and §7.2. "Persist" names the store write.

### First launch

| Step | Screen | Transition | State change | Data mutation | Persistence point |
|---|---|---|---|---|---|
| 1 | Welcome (thesis in one line) | → | `AppModel.phase = .onboarding(step)` | — | — |
| 2 | Name (optional) + reminder time (optional, can skip) | → | onboarding draft | — | — |
| 3 | Notification permission (only if a reminder was chosen) | system prompt | permission status | — | — |
| 4 | **First moment**: "how are you now" | sheet-like step | moment draft | `MoodLog` insert | `MoodStore.log` via `RecordWriter` |
| 5 | "Is this today's feeling?" (suggestion = the moment's emotion) | → | ONE draft | ONE insert (`origin: suggestionAccepted`) | ONE store via `RecordWriter` |
| 6 | Today (shows the first ONE) | replace root | `phase = .main`, `onboardingDone` | Profile settings | `ProfileStore` (KVS + App Group) |

The minimum before the daily experience is **nothing required**: every step except 1 and 6 can be skipped. Whether Stoic requires more: **Research does not establish this.** A paywall in onboarding is decision D9.

### Daily return

Open the app. `AppModel` checks for a `dayKey` rollover. Today loads through `DayComposer.day(today)`:

- If there is no record yet, Today shows an empty-day state.
- If there are moments, they are shown with the ONE suggestion.
- If a ONE exists, the feeling + line + keepsake are shown.

Then:

1. Add a moment (sheet) → `RecordWriter.saveMoment` → `DataRevision` bump → Today reloads.
2. Optionally name the day's feeling → `RecordWriter.setOne`.
3. Optionally write → Editor → `RecordWriter.saveEntry`.

There is no completion screen requirement.

### Evening closing moment (optional flow, not a state)

The reminder (if set) deep-links `ones://today?close=1`. Today opens the ONE sheet, prefilled with suggestions from the day's moments. The user picks a feeling, and optionally a line and a keepsake from today's records. `RecordWriter.setOne` persists the ONE row.

### History

Days tab → period lens (days / weeks / months / year) → a day card → push Day detail (`Route.day(dayKey)`) → its moments, reflections and media, plus the ONE. Editing happens in the sheets, and each save is a `RecordWriter` call.

- Legacy days (before ONE 2.0) come from `LegacyMomentStore`, are merged by date in `DayComposer`, and are read-only.
- Backfill: tapping a gap inside the 7-day window opens Moment capture or the ONE sheet with a past `dayKey` (`isBackfilled`).

### Reflection

Prompt (Today's prompt, or a prompt list) → Editor (draft autosaved to device-local storage) → Save → `Entry` with `contentRef` + `contentSnapshot` + `dayKey` → attached to its Day by `dayKey`. Optionally: "keep this as what remains from today" → ONE `keepsakeRef`.

### Insight

Days → zoom out (month or year) → `InsightsEngine` computes from the ONEs + moments + entries for the period. When the data is below threshold, the engine returns `.insufficient(needed:)` and the screen shows an empty state. Tapping an insight drills to the related days, filtered in Days.

### Search

Days → search → `SearchIndex` over `Entry.searchText` + ONE `line` → results grouped by day → Day detail. It is justified because the record grows without bound (P8). For the MVP it can be deferred (D10) until volume makes scrolling insufficient.

---

## 9. State architecture

Keep what exists (`@Observable`, `Router`, `AppEnvironment` DI, value types out of stores). Add only the pieces that have a concrete reason.

| State | Owner | Lifetime | Notes |
|---|---|---|---|
| App state | `AppModel` (`@Observable`, new, small) | Process | `phase: launching / onboarding / locked / main`. Lock integration via the existing `AppLockManager` |
| Navigation | `Router` (exists) | Process (+ scene restore; unknown restored value falls back to Today, R15) | Tabs follow D3 |
| Session / clock | `AppClock` (exists) + a `today: DayKey` published by `AppModel` | Process | Rollover on `significantTimeChange` / foreground |
| Onboarding | `OnboardingModel` (feature) | Flow | Writes the profile on finish. `onboardingDone` in the profile |
| Today | `TodayModel` (feature) | Screen | `Phase<TodayViewData>` from `DayComposer` |
| Moment / ONE / Editor | One feature model each | Sheet | The editor draft is persisted device-locally |
| Days / Day detail / Patterns | One feature model each | Screen | Paged by period |
| Loading / empty / error | Every feature model exposes `enum Phase<V> { loading, empty, loaded(V), failed(ONEError) }` | — | Rendered with the existing `V3Loading` / `ONEErrorView` (CLAUDE.md: every screen defines all three) |
| Freshness | `DataRevision` (`@Observable`, a counter) | Process | Bumped by `RecordWriter` and on remote change. Models reload when it changes. **Reason:** cross-feature freshness without Feature→Feature coupling or NotificationCenter |

Two new application-layer pieces:

- **`RecordWriter`**: the single write path for moments, entries, media and the ONE. Order: store write → `DataRevision` bump → widget snapshot → notification window → analytics domain event. **Reason:** these side effects are currently hidden in `AppEnvironment`'s `journal.didSave` closure, so they are untestable and incomplete (moments do not trigger them). v3's `MomentWriter` already proved the pattern (AUDIT §7).
- **`DayComposer`**: the read model that builds the Day view (records + ONE + legacy) for one `dayKey` or a range. **Reason:** Today, Days, Day detail, the widget and the evening flow would otherwise each assemble the day from 4–5 stores.

Concurrency: keep default MainActor isolation and synchronous `viewContext` stores for small writes (ADR note). Move `Media` writes to a background context (already planned). async/await is used where there is real I/O: content download, media, export.

Not added:

- a separate use-case class per action (`RecordWriter` methods are the use cases)
- a repository protocol per store (stores are already the repository; tests use an in-memory store)
- a Redux-style global store

---

## 10. Persistence architecture

**Technology: Core Data + the existing `NSPersistentCloudKitContainer`, model version `one 3` (ADR §1, locked).** This is the right choice for these reasons:

- The container and CloudKit mirroring are already in production with v3 data.
- `DailySong` must stay readable (MIGRATION B′).
- SwiftData would need either a second store or a shared store with unclear CloudKit behaviour.

Local JSON is used only for content. UserDefaults and KVS hold settings. Keychain holds only secrets.

| Class | Data | Where | Rule |
|---|---|---|---|
| **Primary** | Moments (`MoodLog`), reflections (`Entry`), media (`Media`), ONE (per §6.5) | Core Data → CloudKit private DB | CloudKit rules: optional/defaulted fields, no unique constraints, optional inverse relationships, no ordered relationships, external binary storage |
| Primary (settings) | Name, reminder times, preferences, `onboardingDone` | `NSUbiquitousKeyValueStore` + App Group UserDefaults (`ProfileStore`) | No flag that nothing reads |
| Legacy primary (read-only) | `DailySong` | Same store | Never written (`LegacyWriteGuard`) |
| **Derived** | Day view, Continuity, streak representation, insights, search results, ONE suggestions | Memory (recomputed; per-period cache invalidated by `DataRevision`) | Never persisted |
| Declared caches (derived but stored) | `Entry.wordCount`, `Entry.searchText`, widget snapshot (`w2_*` keys) | Core Data / App Group | Must be rebuildable from primary data. Rebuild on schema or algorithm change |
| Content | Prompts, catalogs (later: themes, quotes, guided) | Bundled JSON + `Application Support/Content` cache (ADR §5) | Referenced by ID + snapshot |
| **Temporary UI state** | Editor draft, sheet state, selected period, scroll position | Draft: device-local file / UserDefaults (not synced; drafts are unfinished and should not sync). The rest: memory / `@SceneStorage` | Not in Core Data |
| Secrets | Lock settings if sensitive; legacy Spotify token (delete) | Keychain | — |

Production schema discipline: before the first production deploy of `one 3`, the model should contain only the entities that pass §5.1 plus the §6.5 ONE shape. Every excluded entity can be added later as an additive version. The production deploy follows MIGRATION §5.

---

## 11. Feature / module architecture

Same target, same folder (ADR §2, no SPM packages). The changes to `one/ONE2/` are `Domain/` (extracted from `Data/`), `Application/` (new) and the feature list:

```text
one/ONE2/
├── App/            ONE2RootView, AppModel, AppEnvironment, Router, DeepLink, ONE2Flag
├── Core/           DayKey, AppClock, SeededRandom, ONE2Cleanup            (pure, no Core Data)
├── Domain/         Value types: Moment(MoodCheckIn), Reflection(JournalEntry), OneValue,
│                   DayCompletion, Continuity types, ONEError                (moved out of Data/JournalValues.swift)
├── Application/    RecordWriter, DayComposer, ContinuityCalculator, DataRevision
├── Data/           MoodStore, JournalStore, OneStore(DayStore reshaped), MediaStore (later),
│                   ProfileStore, LegacyMomentStore, ManagedObjectMapping, LegacyWriteGuard
├── Content/        ContentRepository, ContentSchema, Bundled/                (prompts + catalogs for MVP)
├── Engines/        Prompts, Insights, Search, Widget        (MVP-wired)
│                   Quotes, Echo, Recommendations, ThemeCalendar, Badges  (kept, tested, NOT wired until decided)
├── Infrastructure/ Notifications (ONE2NotificationScheduler, NotificationPlanner), WidgetBridge,
│                   Analytics adapter (one2_ events)                         (moved from Notifications/, Engines/Widget)
├── DesignSystem/   (UX session owns; later stage)
└── Features/
    ├── Onboarding/   ├── Today/        ├── Moment/       ├── One/
    ├── Editor/       ├── Days/         ├── DayDetail/    ├── Patterns/ (lens inside Days)
    └── Settings/     (Paywall/ when D9 is decided)
```

Moving `Domain/` out of `Data/` has a concrete reason: engines and features should depend on value types, not on the store folder, so the dependency rule in §12 can be checked with grep. The engines that are not wired stay because they are tested and cost nothing at runtime. They are not referenced from Features until their decisions (D5–D7) land.

---

## 12. Dependency rules

```text
UI (SwiftUI views, Features/*)
 ↓ owns
Feature models (@Observable, Features/*)
 ↓ writes via                 ↓ reads via
Application (RecordWriter, DayComposer, Continuity)   Engines (pure) ← Content
 ↓                                                     ↓
Data (stores) ─────────────────────────────────────────┘ (engines get data as value types, passed in)
 ↓
Core Data / CloudKit ; KVS ; App Group ; Keychain
Infrastructure (notifications, widget, analytics) ← called only by Application (+ UI-event analytics from feature models)
Domain + Core (value types, DayKey, AppClock) ← importable by every layer
```

| Rule | Allowed | Forbidden |
|---|---|---|
| Views | Their own feature model; DesignSystem; Domain values | Stores, `NSManagedObject`, `NSManagedObjectContext`, engines directly |
| Feature models | Application, Engines, Router, Domain | Another `Features/X` (communicate through `Route` or `DataRevision`); Infrastructure for domain side effects |
| Application | Data, Engines, Infrastructure, Domain | UI |
| Engines | Domain, Core, Content types | Core Data, network, UI, stores (inputs are passed in) |
| Data (stores) | Core Data, Domain | Notifications, widget, analytics, engines |
| All ONE2 code | v3 `UI/DesignSystem`, `UI/Components`, `Core/Utilities`, `NotificationOrchestrator`/`Policy`, `Moment`/`Day` (via `LegacyMomentStore` only) | v3 `Features/*`, `CloudKitManager` (ADR §2, `ui_guard` `one2_imports_v3=0`) |

| Concern | Where it lives |
|---|---|
| Business logic | Pure rules in `Core/` + `Engines/` + `Application/ContinuityCalculator`. Orchestration in `Application/` |
| Persistence logic | `Data/` stores only (mapping, dedupe, fetch) |
| Analytics | Domain events (`one2_moment_saved`, `one2_one_set`, `one2_entry_saved`) in `RecordWriter`. UI events (`screen_viewed`, `paywall_shown`) in feature models. No user text is ever sent (`04` E17) |
| Notifications | `Infrastructure/Notifications`. Rebuilt by `RecordWriter` after writes and by `AppModel` on launch. Retired IDs go through `NotificationOrchestrator` |
| Widget | `Infrastructure/WidgetBridge`, fed by `DayComposer`, triggered by `RecordWriter` |

---

## 13. Future extensibility

| Feature | Supported cleanly? | How / what it needs |
|---|---|---|
| AI-generated reflections | Yes | A `ReflectionAssistant` protocol in Application with a no-op default. Output is only ever a *suggestion* (ONE `origin = suggestionAccepted`, or a prompt). The core never depends on it (P6) |
| Deeper insights | Yes | New pure functions in `InsightsEngine` over the same primary data |
| Music memories | Yes | `Media(type: song)` + ONE keepsake. The MusicKit search service is extracted from v3 `TodayViewModel` (AUDIT §7) |
| Photos | Yes | `Media(type: photo)`. Background-context writes |
| Widgets | Yes | `DayComposer` → `w2_*` snapshot. Kind `MoodWidget` is preserved |
| Apple Health | Yes | `MoodLog.healthKitSampleID` exists. An Infrastructure adapter writes State of Mind. Catalog alignment is an open question (`02`) |
| Apple Intelligence | Yes | Same `ReflectionAssistant` seam, on-device. `Media.onDeviceDescription` exists |
| Social / close friends | Possible, not planned | Removed by ADR §10. A future layer would read ONEs through `DayComposer`, never the stores. The private-first model is unchanged |
| Yearly reflection | Yes, *because of* S3′ | A stable per-day ONE series (P5) |
| Export | Yes | Export v2 (`04` E16) over primary data + ONEs + legacy |
| Subscription | Yes | `EntitlementStore` + a `PremiumFeature` gate in feature models. The core record is never gated (`04` E15 principle) |
| Localization | Yes | 9-language UI strings (rule). Content TR first, EN fallback (ADR §5) |
| Rituals (morning/evening) | Yes | New `Entry.kind` values (already in the enum) + `EntryAnswer` when added. They are *record kinds*, not day completion |
| Streak / badges | Yes | Representations over Continuity (§5.4). `BadgeAward` is added when decided |
| Quotes / weekly theme / Explore tab | Yes | Wire the existing engines. Add `ContentExposure` for cross-device non-repetition. Add a 3rd tab (§7.1 (i)) |

---

## 14. Legacy concepts to remove

Explicit list. Each item says whether it goes from v3, from the ONE2-so-far candidate, or from both.

| Concept | Source | Why |
|---|---|---|
| Mood as a **free color** (`moodColorHex`, color picker) and `V3Mood`/`ONEMood` as the mood model | v3 | Not nameable. Violates P6. Kept only to render legacy days (ADR decision) |
| **Music-first** day (song as the primary record, `SongRecommendationEngine`, charts, `SpotifyManager`) | v3 | A song is at most a keepsake (§6.5), not the day |
| `DailySong` as a write target | v3 | Read-only forever (B′) |
| Circle / public DB social, `AppleSignInService`, `MidnightResetManager`, Contacts, QR, CloudKit subscriptions | v3 | ADR §10 decision |
| Live Activity target | v3 | Off by flag. No thesis role |
| Singletons in new code; NotificationCenter tab switching; `GlobalUIState` | v3 | Replaced by DI + Router |
| v3 Echo / MonthlySummary / Archive mosaic screens | v3 | Replaced by Days + Patterns |
| 102-case `AnalyticsEvent` | v3 | Replaced by a small `one2_` catalog |
| Hidden side effects in `AppEnvironment.init` (`didSave` closure) | ONE2 | Replaced by `RecordWriter` |
| **Stored derived completion** (`DayRecord.*CompletedAt`, `completedBy`, `backfilledAt`) | ONE2 | P4 / K4. Computed by Continuity |
| **Streak as a domain primitive** and the streak pill as the Today headline | ONE2 + README | P9 / §5.4 |
| Quotes as a primary tab; the 800–1,500 quote target as an MVP requirement | ONE2 docs | P10. Optional content (D6) |
| Badges (20) in the MVP | ONE2 docs | Engagement, not structure |
| `Template`, `TemplateItem`, `MetricDefinition`, `Practice`, `Tag`, `BadgeAward`, `ContentExposure`, `EntryAnswer` in the **first production schema** | ONE2 schema | §5.1 filter. Additive later |
| A 5-tab IA | README | §7 |
| Morning/evening ritual as the definition of "a completed day" | ONE2 (`RitualMode`, E8) | Completion is not a ONE concept (§6.5). Rituals may return as record kinds |
| Duplicated state: completion held in both `DayRecord` and entries | ONE2 | One source (records) |
| New SPM dependencies | — | None needed |

---

## 15. Final architecture diagram

```text
┌──────────────────────────────────────────── PRODUCT LAYER ────────────────────────────────────────────┐
│  Today (the day being lived)                         Days (the record of days; zoom → patterns)         │
│  · capture a moment · name the day's ONE feeling      · day cards (ONE or open) · Day detail · search    │
│  · write · what remains (line / keepsake)             · continuity (fill, days kept) · insights lens     │
│  Profile/Settings (top bar) · Onboarding · [later: Explore, Paywall, rituals, streak/badges]            │
└──────────────────────────────────────────────────────────────────────────────────────────────────────────┘
┌──────────────────────────────────────────── UI LAYER (SwiftUI) ───────────────────────────────────────┐
│  Features/{Onboarding, Today, Moment, One, Editor, Days, DayDetail, Patterns, Settings}                │
│  views ─owns─► @Observable feature models (Phase: loading/empty/loaded/failed) · Router · AppModel      │
└──────────────────────────────────────────────────────────────────────────────────────────────────────────┘
┌──────────────────────────────────────────── APPLICATION LAYER ────────────────────────────────────────┐
│  RecordWriter (single write path + side effects)   DayComposer (Day view / ONE read model, legacy merge)│
│  ContinuityCalculator (DayCompletion → Continuity)  DataRevision   [seam: ReflectionAssistant (no-op)]  │
│  Presentation-only representations: streak (optional), badges (later)                                  │
└──────────────────────────────────────────────────────────────────────────────────────────────────────────┘
┌──────────────────────────────────────────── DOMAIN LAYER ─────────────────────────────────────────────┐
│  Moment · Reflection · Media · ONE (user-named feeling, line?, keepsakeRef?, origin) · Day (derived)     │
│  DayKey · AppClock · DayCompletion (fact) · rules: P4 derived-not-stored, P5 stable past, P6 user names │
│  Pure engines: Prompts · Insights · Search   (parked: Quotes · Echo · Recommendations · Theme · Badges) │
└──────────────────────────────────────────────────────────────────────────────────────────────────────────┘
┌──────────────────────────────────────────── DATA LAYER ───────────────────────────────────────────────┐
│  MoodStore · JournalStore · OneStore · (MediaStore) · ProfileStore · LegacyMomentStore · ContentRepo    │
│  Core Data `one 3` (MVP entities only) ⇄ NSPersistentCloudKitContainer (iCloud.com.batu.ones, private)  │
│  KVS + App Group (settings, w2_* widget) · bundled/remote content JSON · Keychain                       │
└──────────────────────────────────────────────────────────────────────────────────────────────────────────┘
┌──────────────────────────────────────────── INFRASTRUCTURE LAYER ─────────────────────────────────────┐
│  NotificationOrchestrator + ONE2 scheduler · WidgetBridge (kind MoodWidget) · AppAnalytics/PostHog      │
│  AppLockManager · CrashReporter/MetricKit · App Intents (SaveMomentIntent kept) · DeepLink (ones://)    │
│  [later: HealthKit, MusicKit search, StoreKit 2 EntitlementStore, on-device AI]                         │
└──────────────────────────────────────────────────────────────────────────────────────────────────────────┘
```

Streak is outside the Domain layer by design.

---

## 16. Implementation roadmap (after approval; nothing here is started)

Every phase:

- is one branch step with its own commit(s)
- has Swift Testing tests in `oneTests/`
- is type-checked with the CLAUDE.md `swiftc -typecheck` command
- passes CI and `tooling/ui_guard.sh` / `voice_guard.py`

UI phases wait for the Product Specification → Visual Direction → Design System stages.

| Phase | Goal | Files / modules | Depends on | Tests | Acceptance |
|---|---|---|---|---|---|
| **P0 Decisions & doc reconciliation** | Record D1–D10 answers. Update `02_veri_modeli.md` (v0.3), add an ADR-001 amendment (or ADR-002), trim `04` scope, update the design-system README IA note | `docs/one2/*` | Batuhan's decisions | — | Docs agree with each other. K1–K6 are closed or explicitly kept |
| **P1 Domain extraction** | Move value types from `Data/JournalValues.swift` to `Domain/`. Add `OneValue`, `Phase`, `ONEError`. No behaviour change | `ONE2/Domain/`, `ONE2/Data/` | P0 | Existing tests pass unchanged | Typecheck green. Grep shows engines import no `Data/` types |
| **P2 Schema candidate (pre-production)** | Reshape `one 3` per P0: add the ONE per §6.5, remove derived `DayRecord` fields, drop the entities §5.1 excludes. Stays development-only | `one/one.xcdatamodeld/one 3.xcdatamodel`, `ManagedObjectMapping.swift`, `ModelVersionTests` | P0, P1 | Lightweight migration `one 2 → one 3` with `DailySong` intact; ONE dedupe (two devices, same `dayKey`, latest `updatedAt` wins); `LegacyWriteGuard` | `DailySong` untouched (diff). T1–T9 from MIGRATION pass. Dev schema regenerated (`initializeCloudKitSchema`) |
| **P3 Continuity** | `DayCompletion` computed from records. `ContinuityCalculator`. `Streak` becomes a representation over Continuity | `Application/`, `Core/Streak.swift` → representation | P2 | Midnight, DST, time-zone change, 7-day backfill, open days, legacy days excluded | No stored completion fields are read anywhere |
| **P4 RecordWriter + DataRevision** | Single write path. Remove the `didSave` closure | `Application/RecordWriter.swift`, `App/AppEnvironment.swift` | P2 | With fake widget, notifications and analytics: each write triggers each side effect once, in order; a failure in a side effect does not roll back the record | `AppEnvironment.init` has no side-effect closures |
| **P5 DayComposer** | Day view and range reads, including the legacy merge and ONE suggestions | `Application/DayComposer.swift` | P3, P4 | Empty / open / ONE day; range with legacy days; a suggestion never auto-persists | Today, Days and the widget can all be fed from one API |
| **P6 AppModel + onboarding state** | App phases, rollover, onboarding completion, trimmed `ProfileStore` keys (drop keys nothing reads) | `App/AppModel.swift`, `Data/ProfileStore.swift` | P1 | Phase transitions, rollover at midnight, relaunch mid-onboarding | No settings key without a reader |
| **P7 Router / IA** | Tabs per D3; routes `day(DayKey)`, `one`, `moment`, `editor(prompt?)`; deep links incl. `ones://today?close=1` | `App/Router.swift`, `DeepLink.swift` | P0 | DeepLink → Destination table incl. legacy links and unknown restore values | All existing deep-link tests plus new ones pass |
| **P8 Feature models: Today, Moment, One, Editor** | Logic and view data only, no views | `Features/*/…Model.swift` | P5, P7 | Fakes; `Phase` states; draft persistence | Every model has loading / empty / error states tested |
| **P9 Feature models: Days, DayDetail, Patterns, Search** | Same | `Features/…` | P5 | Paging, period zoom, insight thresholds, backfill window | Same |
| **P10 Infrastructure wiring** | Widget snapshot from `DayComposer`; a minimal notification set (optional evening moment); `one2_` analytics catalog | `Infrastructure/*` | P4, P5 | Notification budget and IDs; no user text in analytics | Retired IDs are cleaned up; widget kind unchanged |
| **P11 UI** (blocked) | Screens per the spec and design system | `Features/*/…View.swift`, `DesignSystem/` | Spec, visual direction, design system | Snapshot/preview matrix (light, dark, AX3) | Per spec |
| **P12 Schema freeze + production deploy** | The MIGRATION §5 checklist | Dashboard, TestFlight | P2 stable | Two-device sync test | Production schema = the MVP entities only |
| **P13 Entitlements** (if D9) | StoreKit 2 `EntitlementStore`, `PremiumFeature` | `Infrastructure/`, `Features/Paywall` | D9 | `SKTestSession` | The core record is never gated |
| **P14 Post-relaunch legacy deletion** | ADR §2 deletion list | v3 `Features/`, flags, Live Activity | Relaunch + 2 weeks | Build + tests | `DailySong`, `Moment`, `Day`, `LegacyMomentStore` remain |

---

## 17. Open questions

| # | Question | Why it matters | Who |
|---|---|---|---|
| Q1 | Is `score` (1–5) kept on moments, or does valence come from the emotion catalog? | Insights need an ordinal series. The thesis is about *named* feelings | Product (D11) |
| Q2 | Is the emotion catalog aligned with Apple State of Mind labels? | HealthKit writing later | Product + tech (`02` open question) |
| Q3 | The ONE edit window: can a day's feeling be changed after the day ends (beyond the 7-day backfill)? | "Stable past" vs honesty | Product |
| Q4 | Is `Entry.body` encrypted beyond the UI lock? | Privacy of a personal record | Product + tech (`02`) |
| Q5 | Teardown: will the 7-day Stoic protocol still be run? Many cells above read "Research does not establish this." | Evidence quality for the Product Specification | Batuhan |
| Q6 | Does `DayRecord` get reused for the ONE, or renamed before the production deploy? | CloudKit record type names are permanent | Tech (my recommendation: reuse) |

---

## Decisions I Need From Batuhan

Only product-judgement calls. Technical details are handled in the sections above.

| # | Decision | Options | My recommendation |
|---|---|---|---|
| **D1** | **What is the single irreplaceable action or artifact that makes ONE different from a generic journaling / reflection app?** | — | *Not answered here, on purpose.* §6 makes all four candidates in §4 structurally possible. Your answer decides whether the closing moment becomes a sealed state (C1) and what Today leads with |
| D2 | The day-level model and completion | S1 / S2 / S3 / **S3′** × C1 / C2 / **C3** | S3′ + C3 (§6.5) |
| D3 | Primary navigation | (i) 3 tabs / **(ii) Today · Days** / (iii) 5 tabs | (ii) (§7.2) |
| D4 | Is "what remains" (keepsake: photo / song / line) in the MVP, and are photos and music in the MVP at all? | Line only / line + photo / line + photo + song | Line + photo in the MVP; song as a fast follow (MusicKit extraction) |
| D5 | Streak in the MVP | Counter on Today / counter in Profile only / **none (continuity fill only)** | None in the MVP (§5.4). Conflicts with K3 |
| D6 | Quotes: tab, content, or later | Tab / **content inside Today** / post-MVP. The 800-item target stands or is deferred | Post-MVP, or light content in Today. Defer the 800 target |
| D7 | Weekly theme in the MVP | Yes / later | Later (a cadence mechanism, not core) |
| D8 | Multi-step flows (morning/evening rituals, guided) in the MVP | Yes (keep `EntryAnswer`) / later | Later |
| D9 | Premium at launch, and whether a paywall appears in onboarding | — | The core record (moments, ONE, history, export, lock) is never paid (consistent with `04` E15) |
| D10 | Search in the MVP | Yes / later | Later, unless D4 brings many photos |
| D11 | Moment measurement: named emotion only, or emotion + 1–5 score | — | Emotion + optional score (Q1) |
| D12 | Resolve positioning K1: "writing and self-improvement app" (README) vs "your day, in one feeling" (this brief) | — | Follows from D1 |
