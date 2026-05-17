//
//  AnalyticsEvent.swift
//  one
//
//  Typed product analytics events. All user-facing funnels and key
//  interactions go through this enum so call sites stay discoverable.
//
//  Event names are stable (snake_case) — changing one breaks existing
//  dashboards. Add new cases rather than renaming old ones.
//

import Foundation

enum AnalyticsEvent {
    // ── Onboarding ─────────────────────────────────────────────────
    case onboardingStarted
    case onboardingCompleted(musicPlatform: String)
    case platformSelected(platform: String)          // "apple" | "spotify"
    case onboardingStepViewed(step: String)          // "welcome" | "mood_pick" | "reveal" | "permissions" | "notif_soft_ask"
    case onboardingMoodPicked(mood: String)
    case onboardingMusicConnected(granted: Bool)
    case onboardingNotifSoftAsk(optIn: Bool)

    // ── Today / daily entry ────────────────────────────────────────
    case songSearched(query: String, source: String) // source: "apple" | "spotify"
    case songSelected(source: String)
    case moodSelected(mood: String)
    case photoAdded(method: String)                  // "camera" | "library"
    case noteAdded(length: Int)
    case entrySaved(hasPhoto: Bool, hasNote: Bool)
    case streakFreezeConsumed                        // B1 — soft streak freeze devreye girdi

    // ── Circle (social) ────────────────────────────────────────────
    case circleOpened
    case friendInviteSent(method: String)            // "code" | "link" | "contact"
    case friendRequestSent
    case friendRequestAccepted
    case friendShareViewed
    case firstEntryInviteHookShown                                // A4 — first-entry invite kancası gösterildi
    case firstEntryInviteHookAction(action: String)               // "invite" | "skip"
    // ── Comments (v2.5) ────────────────────────────────────────────
    case commentCreated
    case commentEdited
    case commentDeleted
    case commentReported
    case commentAuthorProfileOpened
    case userBlocked
    case userUnblocked

    // ── Discovery ──────────────────────────────────────────────────
    case discoverOpened
    case recommendationTapped(source: String)        // "apple" | "spotify"
    case eventTapped(category: String)
    case playlistOpened

    // ── Share ──────────────────────────────────────────────────────
    case storyCardShared(surface: String)            // "ig_story" | "system_sheet" | "save"
    case monthlyPosterShared

    // ── Badges ─────────────────────────────────────────────────────
    case badgeUnlocked(id: String)

    // ── Name + properties for dispatch ─────────────────────────────

    /// Stable event name emitted to analytics backends.
    var name: String {
        switch self {
        case .onboardingStarted:         return "onboarding_started"
        case .onboardingCompleted:       return "onboarding_completed"
        case .platformSelected:          return "platform_selected"
        case .onboardingStepViewed:      return "onboarding_step_viewed"
        case .onboardingMoodPicked:      return "onboarding_mood_picked"
        case .onboardingMusicConnected:  return "onboarding_music_connected"
        case .onboardingNotifSoftAsk:    return "onboarding_notif_soft_ask"
        case .songSearched:              return "song_searched"
        case .songSelected:              return "song_selected"
        case .moodSelected:              return "mood_selected"
        case .photoAdded:                return "photo_added"
        case .noteAdded:                 return "note_added"
        case .entrySaved:                return "entry_saved"
        case .streakFreezeConsumed:      return "streak_freeze_consumed"
        case .circleOpened:              return "circle_opened"
        case .friendInviteSent:          return "friend_invite_sent"
        case .friendRequestSent:         return "friend_request_sent"
        case .friendRequestAccepted:     return "friend_request_accepted"
        case .friendShareViewed:         return "friend_share_viewed"
        case .firstEntryInviteHookShown: return "first_entry_invite_hook_shown"
        case .firstEntryInviteHookAction:return "first_entry_invite_hook_action"
        case .commentCreated:            return "comment_created"
        case .commentEdited:             return "comment_edited"
        case .commentDeleted:            return "comment_deleted"
        case .commentReported:           return "comment_reported"
        case .commentAuthorProfileOpened:return "comment_author_profile_opened"
        case .userBlocked:               return "user_blocked"
        case .userUnblocked:             return "user_unblocked"
        case .discoverOpened:            return "discover_opened"
        case .recommendationTapped:      return "recommendation_tapped"
        case .eventTapped:               return "event_tapped"
        case .playlistOpened:            return "playlist_opened"
        case .storyCardShared:           return "story_card_shared"
        case .monthlyPosterShared:       return "monthly_poster_shared"
        case .badgeUnlocked:             return "badge_unlocked"
        }
    }

    /// Structured properties. No PII — stick to short enum-like strings,
    /// counts, and booleans. User identity flows through `AppAnalytics.identify`.
    var properties: [String: Any] {
        switch self {
        case .onboardingStarted, .circleOpened, .discoverOpened,
             .friendRequestSent, .friendRequestAccepted, .friendShareViewed,
             .playlistOpened, .monthlyPosterShared, .songSelected,
             .commentCreated, .commentEdited, .commentDeleted, .commentReported,
             .commentAuthorProfileOpened, .userBlocked, .userUnblocked,
             .firstEntryInviteHookShown,
             .streakFreezeConsumed:
            return [:]
        case .firstEntryInviteHookAction(let action):
            return ["action": action]
        case .onboardingCompleted(let musicPlatform):
            return ["music_platform": musicPlatform]
        case .platformSelected(let platform):
            return ["platform": platform]
        case .onboardingStepViewed(let step):
            return ["step": step]
        case .onboardingMoodPicked(let mood):
            return ["mood": mood]
        case .onboardingMusicConnected(let granted):
            return ["granted": granted]
        case .onboardingNotifSoftAsk(let optIn):
            return ["opt_in": optIn]
        case .songSearched(let query, let source):
            return ["query_length": query.count, "source": source]
        case .moodSelected(let mood):
            return ["mood": mood]
        case .photoAdded(let method):
            return ["method": method]
        case .noteAdded(let length):
            return ["length": length]
        case .entrySaved(let hasPhoto, let hasNote):
            return ["has_photo": hasPhoto, "has_note": hasNote]
        case .friendInviteSent(let method):
            return ["method": method]
        case .recommendationTapped(let source):
            return ["source": source]
        case .eventTapped(let category):
            return ["category": category]
        case .storyCardShared(let surface):
            return ["surface": surface]
        case .badgeUnlocked(let id):
            return ["badge_id": id]
        }
    }
}
