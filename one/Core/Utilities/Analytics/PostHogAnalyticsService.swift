//
//  PostHogAnalyticsService.swift
//  one
//
//  PostHog product analytics backend.
//  Registers itself from oneApp.init() in RELEASE builds.
//
//  Setup:
//  1. Xcode → File → Add Package Dependencies
//     URL: https://github.com/PostHog/posthog-ios  (v3.x)
//     Target: ones
//  2. PostHog dashboard → Project Settings → API Key
//  3. oneApp.init() içindeki #if !DEBUG bloğuna API key gir.
//
//  See docs/OBSERVABILITY_SETUP.md
//

import Foundation

#if canImport(PostHog)
import PostHog

final class PostHogAnalyticsService: AnalyticsService {

    init(apiKey: String) {
        let config = PostHogConfig(
            projectToken: apiKey,
            host: "https://us.posthog.com"   // US server (hesap US bölgesinde)
        )
        config.captureApplicationLifecycleEvents = false  // manuel kontrol
        config.flushAt = 20
        config.flushIntervalSeconds = 30
        PostHogSDK.shared.setup(config)
    }

    func track(event: AnalyticsEvent) {
        // Aktivasyon penceresi ("ilk 3 gün") her event'te kesilebilmeli —
        // tek tek event'lere eklemek yerine burada bir kez ekleniyor.
        var properties = event.properties
        if let days = EngagementTracker.daysSinceInstall {
            properties["days_since_install"] = days
        }

        PostHogSDK.shared.capture(
            event.name,
            properties: properties.isEmpty ? nil : properties
        )
    }

    func identify(userID: String, properties: [String: Any]) {
        PostHogSDK.shared.identify(userID, userProperties: properties.isEmpty ? nil : properties)
    }

    func reset() {
        PostHogSDK.shared.reset()
    }
}
#endif
