//
//  CommentsFeatureFlag.swift
//  one
//
//  v2.5 — Yorum sistemini kademeli rollout için kapı. `UserDefaults`
//  üzerinden override; varsayılan DEBUG'ta açık, RELEASE'te kapalı.
//  İlk açan kullanıcıya tek seferlik intro banner göstermek için
//  `hasSeenIntro` state'i tutulur.
//

import Foundation
import Combine

enum CommentsFeatureFlag {
    private static let overrideKey = "feature.comments.enabled"
    private static let introSeenKey = "feature.comments.introSeen"

    static var isEnabled: Bool {
        if let override = UserDefaults.standard.object(forKey: overrideKey) as? Bool {
            return override
        }
        return true
    }

    static func setEnabled(_ value: Bool) {
        UserDefaults.standard.set(value, forKey: overrideKey)
    }

    static var hasSeenIntro: Bool {
        UserDefaults.standard.bool(forKey: introSeenKey)
    }

    static func markIntroSeen() {
        UserDefaults.standard.set(true, forKey: introSeenKey)
    }
}
