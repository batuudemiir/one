//
//  ActivityAttributes.swift
//
//  Bu dosya hem `one` hem `OneActivityExtensionExtension` target'larına eklenmeli.
//  Xcode → File Inspector → Target Membership: her ikisini de işaretle.
//

import ActivityKit
import Foundation

// MARK: - Günlük Şarkı (kaydetme anı — 30 sn)

struct DailySongActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var songName: String
        var artistName: String
        var moodLabel: String
        var moodColorHex: String
        var moodIsDark: Bool
        var moodSFSymbol: String
        var streakCount: Int
        /// true → kutlama fazı (ilk 5 sn), false → normal compact
        var isCelebrating: Bool
        /// "energetic" | "calm" | "deep" — symbolEffect seçimi için
        var moodAnimationStyle: String
    }
    var savedAt: Date
}

// MARK: - Arkadaş Paylaşımı (bildirim — 2 dk)

struct FriendShareActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var friendName: String
        var songName: String
        var artistName: String
        var moodLabel: String
        var moodColorHex: String
        var moodSFSymbol: String
    }
    var receivedAt: Date
}
