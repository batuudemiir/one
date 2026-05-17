//
//  WinBackScheduler.swift
//  one
//
//  İnaktif kullanıcıyı geri çekme dalgası. Her uygulama açılışında pending
//  win-back bildirimleri iptal edilip `lastOpenedDate`'e göre yeniden
//  schedule edilir (3g, 7g, 14g, 30g). Kullanıcı açılış yaptıkça bu bildirimler
//  otomatik olarak doğru zamana kayar.
//

import Foundation
import UserNotifications

enum WinBackScheduler {

    static let identifiers = [
        "winback_3d", "winback_7d", "winback_14d", "winback_30d"
    ]

    /// bootOnLaunch / onAppOpened sonrasında çağrılır.
    static func rescheduleAll() {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: identifiers)

        let lastOpen = EngagementTracker.lastOpenedDate ?? Date()
        schedule(kind: .winBack3,  identifier: "winback_3d",  daysFromLastOpen: 3,  lastOpen: lastOpen)
        schedule(kind: .winBack7,  identifier: "winback_7d",  daysFromLastOpen: 7,  lastOpen: lastOpen)
        schedule(kind: .winBack14, identifier: "winback_14d", daysFromLastOpen: 14, lastOpen: lastOpen)
        schedule(kind: .winBack30, identifier: "winback_30d", daysFromLastOpen: 30, lastOpen: lastOpen)
    }

    private static func schedule(
        kind: NotificationKind,
        identifier: String,
        daysFromLastOpen: Int,
        lastOpen: Date
    ) {
        let cal = Calendar.current
        guard var fireDate = cal.date(byAdding: .day, value: daysFromLastOpen, to: lastOpen) else { return }

        // Saatini 19:00'a sabitle (akşam aktif pencere).
        var comps = cal.dateComponents([.year, .month, .day], from: fireDate)
        comps.hour = 19
        comps.minute = 0
        fireDate = cal.date(from: comps) ?? fireDate

        // Geçmişte kaldıysa planlama anlamsız.
        guard fireDate > Date() else { return }

        let bucket = EngagementTracker.abBucket(userID: nil)
        let seed = NotificationMessageBuilder.dailySeed(for: fireDate) + daysFromLastOpen
        let msg = NotificationMessageBuilder.build(
            MessageContext(
                kind: kind,
                now: fireDate,
                lastMoodLabel: EngagementTracker.lastMoodLabel,
                abBucket: bucket
            ),
            seed: seed
        )

        let content = UNMutableNotificationContent()
        content.title = msg.title
        content.body = msg.body
        content.sound = .default

        let triggerComps = cal.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: triggerComps, repeats: false)

        _ = NotificationOrchestrator.shared.schedule(
            kind: kind,
            identifier: identifier,
            trigger: trigger,
            content: content,
            variant: msg.variant
        )
    }
}
