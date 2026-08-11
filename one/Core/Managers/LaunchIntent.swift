//
//  LaunchIntent.swift
//  one
//
//  Cold-start deep link route buffer.
//
//  Problem this solves: on cold launch a URL can fire from `onOpenURL`
//  BEFORE the main shell (`ONEColorPickerView`) has mounted. Previously
//  the shell picked `Experiment.defaultLaunchScreen` first, then the
//  deep link handler flipped `NotificationManager.shouldNavigateTo*`,
//  producing a visible flicker (land on default tab → jump to target).
//
//  `LaunchIntent.shared.pendingTab` is set the moment the URL is
//  resolved. `ONEColorPickerView.restoreLastTabIfNeeded()` reads it on
//  first mount — BEFORE the splash dismisses — so when the splash fades
//  the shell is already on the correct tab. Precedence:
//
//      deep-link intent  >  NotificationManager nav flags  >  SceneStorage restore
//
//  If a URL arrives WHILE the splash is still on screen (warm scenario:
//  app was already running in this scene), `ONEColorPickerView` also
//  listens for `.launchIntentUpdated` and routes immediately.
//

import Foundation
import Combine

@MainActor
final class LaunchIntent: ObservableObject {
    static let shared = LaunchIntent()

    /// Target tab requested by a URL received during launch. Consumed by
    /// `ONEColorPickerView` at first-mount (cold) or via
    /// `.launchIntentUpdated` (warm/splash-visible).
    @Published private(set) var pendingTab: PrimaryTab?

    /// Target non-tab screen (e.g. `.discover`) requested by a URL. Used
    /// when the destination is a `ScreenType` case that isn't part of the
    /// dock (`PrimaryTab`) — routed by setting `vm.currentScreen` directly.
    /// Mutually exclusive with `pendingTab` in practice; consumers should
    /// prefer `pendingScreen` if both are set (more specific).
    @Published private(set) var pendingScreen: ScreenType?

    /// Widget / universal-link tapped the mood-picker entry point
    /// (`ones://today`, `/event/mood`). Older code posted `.openMoodPicker`
    /// directly, which was lost on cold-start because the shell hadn't
    /// mounted yet. Buffer it here so first mount consumes.
    @Published private(set) var pendingMoodPickerRequest: Bool = false

    private init() {}

    /// Set the pending tab. Idempotent — last write wins if two URLs
    /// arrive back-to-back (extremely rare but not impossible with
    /// universal links + widget stacking).
    func setPendingTab(_ tab: PrimaryTab) {
        pendingTab = tab
        pendingScreen = nil
        NotificationCenter.default.post(name: .launchIntentUpdated, object: nil)
    }

    /// Set a pending non-tab screen destination. Used for deep links that
    /// resolve to a `ScreenType` outside the dock (e.g. `ones://discover`).
    func setPendingScreen(_ screen: ScreenType) {
        pendingScreen = screen
        pendingTab = nil
        NotificationCenter.default.post(name: .launchIntentUpdated, object: nil)
    }

    /// Cold-start safe replacement for `NotificationCenter.post(.openMoodPicker)`.
    /// The shell reads + clears this on first mount and on `.launchIntentUpdated`.
    func setPendingMoodPickerRequest() {
        pendingMoodPickerRequest = true
        NotificationCenter.default.post(name: .launchIntentUpdated, object: nil)
    }

    /// Called by the shell after routing has been applied. Prevents the
    /// same intent from being re-applied on subsequent tab restorations.
    func consume() {
        pendingTab = nil
        pendingScreen = nil
    }

    func consumeMoodPickerRequest() {
        pendingMoodPickerRequest = false
    }
}

extension Notification.Name {
    /// Fired when `LaunchIntent.pendingTab` mutates. `ONEColorPickerView`
    /// observes this so a URL delivered mid-splash routes immediately
    /// (rather than waiting for `.onAppear`, which already fired).
    static let launchIntentUpdated = Notification.Name("LaunchIntentUpdated")
}
