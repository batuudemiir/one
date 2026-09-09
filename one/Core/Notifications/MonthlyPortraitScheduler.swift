//
//  MonthlyPortraitScheduler.swift
//  one
//
//  Her ayın 1'inde 11:00: geçen ayın portresi hazır olduğunu bildirir.
//  v4 — bir olgu bildirimi, bir davet değil. Metin
//  `NotificationMessageBuilder`'dan gelir ("Ağustos / Ayın portresi hazır.").
//  Aylık portrenin **tek** planlayıcısı burasıdır.
//
//  Boot başına gelecek 2 ayın 1'i kuyruğa alınır (idempotent). Ay sonu
//  hesaplama yerine "ayın ilk günü 11:00" sabitlenir — geçen ay tamamlanmış
//  olur, MonthlySummary anlamlı olur.
//

import Foundation
import UserNotifications

enum MonthlyPortraitScheduler {
    static let identifiers = ["monthly_portrait_1", "monthly_portrait_2"]

    /// boot + onSongSaved sonrası çağrılır. Önümüzdeki 2 ayın 1'inde 11:00.
    static func rescheduleAll() {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: identifiers)

        let cal = Calendar.current
        let now = Date()

        guard let nextFirst = nextMonthFirstAt(hour: 11, after: now, calendar: cal) else { return }
        schedule(date: nextFirst, identifier: identifiers[0], occurrence: 1)

        if let monthAfter = cal.date(byAdding: .month, value: 1, to: nextFirst) {
            schedule(date: monthAfter, identifier: identifiers[1], occurrence: 2)
        }
    }

    private static func nextMonthFirstAt(hour: Int, after date: Date, calendar: Calendar) -> Date? {
        var comps = calendar.dateComponents([.year, .month], from: date)
        comps.day = 1
        comps.hour = hour
        comps.minute = 0
        guard var candidate = calendar.date(from: comps) else { return nil }
        if candidate <= date {
            candidate = calendar.date(byAdding: .month, value: 1, to: candidate) ?? candidate
        }
        return candidate
    }

    private static func schedule(date: Date, identifier: String, occurrence: Int) {
        guard date > Date() else { return }

        let bucket = EngagementTracker.abBucket(userID: nil)
        let seed = NotificationMessageBuilder.dailySeed(for: date) + occurrence
        let msg = NotificationMessageBuilder.build(
            MessageContext(
                kind: .monthEndSummary,
                now: date,
                lastMoodLabel: EngagementTracker.lastMoodLabel,
                friendCount: EngagementTracker.lastKnownFriendCount,
                abBucket: bucket
            ),
            seed: seed
        )

        let content = UNMutableNotificationContent()
        content.title = msg.title
        content.body = msg.body
        content.sound = .default

        let cal = Calendar.current
        let triggerComps = cal.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        let trigger = UNCalendarNotificationTrigger(dateMatching: triggerComps, repeats: false)

        _ = NotificationOrchestrator.shared.schedule(
            kind: .monthEndSummary,
            identifier: identifier,
            trigger: trigger,
            content: content,
            variant: msg.variant
        )
    }
}
