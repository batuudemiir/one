//
//  StreakMilestoneScheduler.swift
//  one
//
//  Streak kutlama bildirimleri. MidnightResetManager gün değişiminde
//  streak değerini hesapladıktan sonra `evaluate(streak:)` çağırır.
//  Her milestone yalnızca bir kez kutlanır (`milestonesCelebrated` set).
//

import Foundation
import UserNotifications

enum StreakMilestoneScheduler {

    static var milestones: [Int] { StreakEngine.milestones }

    private static let key = "milestonesCelebrated"
    private static var defaults: UserDefaults { .standard }

    static func evaluate(streak: Int) {
        guard milestones.contains(streak) else { return }
        var celebrated = Set(defaults.array(forKey: key) as? [Int] ?? [])
        if celebrated.contains(streak) { return }

        let bucket = EngagementTracker.abBucket(userID: nil)
        let msg = NotificationMessageBuilder.build(
            MessageContext(
                kind: .streakMilestone,
                streakDays: streak,
                abBucket: bucket
            ),
            seed: streak
        )

        let content = UNMutableNotificationContent()
        content.title = msg.title
        content.body = msg.body
        content.sound = .default

        // Hemen gönder (1 saniye sonra).
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let decision = NotificationOrchestrator.shared.schedule(
            kind: .streakMilestone,
            identifier: "streak_milestone_\(streak)",
            trigger: trigger,
            content: content,
            variant: msg.variant
        )

        if case .allow = decision {
            celebrated.insert(streak)
            defaults.set(Array(celebrated), forKey: key)
        }
    }
}
