//
//  NewUserNurtureScheduler.swift
//  one
//
//  Onboarding + bildirim izni verilen ilk 72 saatte +1g/+2g/+3g günlerinde
//  21:00'de alışkanlık kurucu bildirimler planlar. Kullanıcı o gün içinde
//  kayıt yaptıysa o günün nurture bildirimi iptal edilir.
//

import Foundation
import UserNotifications

enum NewUserNurtureScheduler {

    static let identifiers = ["nurture_d1", "nurture_d2", "nurture_d3", "nurture_d4_circle"]

    /// Onboarding tamamlanınca çağrılır.
    static func start() {
        EngagementTracker.startNurtureIfNeeded()
        rescheduleAll()
    }

    /// Her boot'ta rescheduled. Kullanıcı o güne ait kayıt yapmışsa o günün
    /// nurture bildirimi iptal kalır.
    static func rescheduleAll() {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: identifiers)

        guard let start = EngagementTracker.nurtureStartedAt else { return }
        let cal = Calendar.current
        let daysSinceStart = cal.dateComponents([.day], from: start, to: Date()).day ?? 0
        if daysSinceStart > 4 { return } // sekans bitti

        // B4 — Day-4 circle invite ekleniyor. Kullanıcının arkadaşı varsa
        // bu push iptal edilir (proven friend signal: lastKnownFriendCount).
        let hasFriends = EngagementTracker.lastKnownFriendCount > 0
        var kinds: [(Int, NotificationKind, String)] = [
            (1, .nurtureDay1, "nurture_d1"),
            (2, .nurtureDay2, "nurture_d2"),
            (3, .nurtureDay3, "nurture_d3"),
        ]
        if !hasFriends {
            kinds.append((4, .circleInviteWave, "nurture_d4_circle"))
        }

        for (offset, kind, id) in kinds {
            guard var fire = cal.date(byAdding: .day, value: offset, to: start) else { continue }
            var comps = cal.dateComponents([.year, .month, .day], from: fire)
            // P1.3 — TR Gen Z evening sweet spot. 21:00'de inbox doluyor;
            // 20:30 hâlâ "akşam ritüeli" niyetinde ama az kalabalık. A/B
            // sonrası optimize edilebilir.
            comps.hour = 20
            comps.minute = 30
            fire = cal.date(from: comps) ?? fire
            guard fire > Date() else { continue }

            let msg = NotificationMessageBuilder.build(
                MessageContext(
                    kind: kind,
                    now: fire,
                    abBucket: EngagementTracker.abBucket(userID: nil)
                ),
                seed: offset
            )
            let content = UNMutableNotificationContent()
            content.title = msg.title
            content.body = msg.body
            content.sound = .default

            let triggerComps = cal.dateComponents([.year, .month, .day, .hour, .minute], from: fire)
            let trigger = UNCalendarNotificationTrigger(dateMatching: triggerComps, repeats: false)

            _ = NotificationOrchestrator.shared.schedule(
                kind: kind,
                identifier: id,
                trigger: trigger,
                content: content,
                variant: msg.variant
            )
        }
    }
}
