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
        defaults.set(true, forKey: "widget_isPremium")

        // Tell WidgetKit to reload all timelines immediately
        WidgetCenter.shared.reloadAllTimelines()
        ONELogger.debug("WidgetDataWriter: widget data updated for '\(songName)'", category: .general)
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

        // Clear today's keys
        ["widget_songName", "widget_artistName", "widget_moodLabel",
         "widget_moodColorHex", "widget_savedAt", "widget_note",
         "widget_entryCount"].forEach { defaults.removeObject(forKey: $0) }

        WidgetCenter.shared.reloadAllTimelines()
    }
}
