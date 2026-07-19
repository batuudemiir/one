//
//  WidgetDataWriter.swift
//  one
//
//  Writes today's mood + song data to the shared App Group UserDefaults so that
//  the MoodWidget extension can display it on the Lock Screen.
//
//  App Group: group.com.batudemir.ones
//  (Enable this capability on both the "one" target and the "MoodWidget" extension target
//   in Xcode → Signing & Capabilities → + Capability → App Groups)
//

import Foundation
import WidgetKit

enum WidgetDataWriter {

    static let appGroupID = "group.com.batudemir.ones"

    private static var sharedDefaults: UserDefaults? {
        UserDefaults(suiteName: appGroupID)
    }

    // MARK: - Write

    /// Call this immediately after saving a DailyEntry so the widget reflects the latest mood.
    static func writeTodayEntry(songName: String, artistName: String,
                                moodLabel: String, moodColorHex: String,
                                note: String? = nil, entryCount: Int = 1) {
        guard let defaults = sharedDefaults else {
            ONELogger.error("WidgetDataWriter: App Group UserDefaults unavailable — check entitlements", category: .general)
            return
        }

        defaults.set(songName,     forKey: "widget_songName")
        defaults.set(artistName,   forKey: "widget_artistName")
        defaults.set(moodLabel,    forKey: "widget_moodLabel")
        defaults.set(moodColorHex, forKey: "widget_moodColorHex")
        defaults.set(Date(),       forKey: "widget_savedAt")
        defaults.set(note ?? "",   forKey: "widget_note")
        defaults.set(entryCount,   forKey: "widget_entryCount")

        WidgetCenter.shared.reloadAllTimelines()
        ONELogger.debug("WidgetDataWriter: widget data updated for '\(songName)'", category: .general)
    }

    // MARK: - Friend Shares

    /// Write friends' daily share data so the CircleWidget can display them.
    /// Each item is a lightweight dictionary: [name, songName, artistName, moodColorHex, moodWord]
    static func writeFriendShares(_ friends: [[String: String]]) {
        guard let defaults = sharedDefaults else { return }

        // Cap at 8 friends to keep UserDefaults payload small
        let capped = Array(friends.prefix(8))
        do {
            let data = try JSONSerialization.data(withJSONObject: capped)
            defaults.set(data, forKey: "widget_friendShares")
            defaults.set(Date(), forKey: "widget_friendSharesUpdatedAt")
        } catch {
            ONELogger.error("WidgetDataWriter: Failed to serialize friend shares: \(error)", category: .general)
        }

        WidgetCenter.shared.reloadAllTimelines()
        ONELogger.debug("WidgetDataWriter: \(capped.count) friend shares written", category: .general)
    }

    // MARK: - Streak

    /// Write current streak count so widgets can display it.
    static func writeStreak(_ streak: Int) {
        guard let defaults = sharedDefaults else { return }
        defaults.set(streak, forKey: "widget_streak")
        WidgetCenter.shared.reloadAllTimelines()
    }

    // MARK: - Clear (call on midnight reset or sign-out)

    static func clear() {
        guard let defaults = sharedDefaults else { return }

        // Archive today's data as "yesterday" before clearing,
        // so the widget can show a fallback until a new song is logged.
        let archiveKeys = ["songName", "artistName", "moodLabel", "moodColorHex", "savedAt", "note"]
        for key in archiveKeys {
            let todayKey = "widget_\(key)"
            let prevKey  = "widget_prev_\(key)"
            if let value = defaults.object(forKey: todayKey) {
                defaults.set(value, forKey: prevKey)
            }
        }

        // Clear today's keys (streak persists — it survives midnight resets)
        ["widget_songName", "widget_artistName", "widget_moodLabel",
         "widget_moodColorHex", "widget_savedAt", "widget_note",
         "widget_entryCount", "widget_friendShares",
         "widget_friendSharesUpdatedAt"
        ].forEach { defaults.removeObject(forKey: $0) }

        WidgetCenter.shared.reloadAllTimelines()
    }
}
