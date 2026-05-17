//
//  SundayReflectionScheduler.swift
//  one
//
//  C2 — Retention planı: her pazar 11:00 push ile haftanın renk paleti
//  ve "Pazar yansıması" davetiyle kullanıcıyı haftalık özete çağırır.
//
//  Her boot'ta gelecek 2 Pazar yeniden zamanlanır (idempotent). Daha
//  uzağa schedule etmek anlamlı değil — kullanıcı 2 hafta açmadıysa
//  win-back zaten devreye girer.
//

import Foundation
import UserNotifications

enum SundayReflectionScheduler {
    static let identifiers = ["sunday_reflection_1", "sunday_reflection_2"]

    /// bootOnLaunch + onSongSaved sonrası çağrılır. Yarın Pazar ise yarın
    /// 11:00, değilse en yakın gelecek Pazar 11:00.
    static func rescheduleAll() {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: identifiers)

        let cal = Calendar.current
        let now = Date()
        // Calendar.weekday: 1=Pazar, 2=Pazartesi ...
        var firstSunday = nextSunday(after: now, calendar: cal)
        firstSunday = setHour(11, on: firstSunday, calendar: cal)

        guard firstSunday > now else {
            // Bugün Pazar ve 11:00 geçmişse bir hafta sonraya kay.
            let next = cal.date(byAdding: .day, value: 7, to: firstSunday) ?? firstSunday
            schedule(date: next, identifier: identifiers[0], occurrence: 1)
            if let secondNext = cal.date(byAdding: .day, value: 14, to: firstSunday) {
                schedule(date: secondNext, identifier: identifiers[1], occurrence: 2)
            }
            return
        }

        schedule(date: firstSunday, identifier: identifiers[0], occurrence: 1)
        if let secondSunday = cal.date(byAdding: .day, value: 7, to: firstSunday) {
            schedule(date: secondSunday, identifier: identifiers[1], occurrence: 2)
        }
    }

    // MARK: - Internal

    private static func nextSunday(after date: Date, calendar: Calendar) -> Date {
        let weekday = calendar.component(.weekday, from: date)  // 1=Pazar
        if weekday == 1 { return calendar.startOfDay(for: date) }
        let daysToAdd = (8 - weekday) % 7
        let candidate = calendar.date(byAdding: .day, value: daysToAdd == 0 ? 7 : daysToAdd, to: date) ?? date
        return calendar.startOfDay(for: candidate)
    }

    private static func setHour(_ hour: Int, on date: Date, calendar: Calendar) -> Date {
        var comps = calendar.dateComponents([.year, .month, .day], from: date)
        comps.hour = hour
        comps.minute = 0
        return calendar.date(from: comps) ?? date
    }

    private static func schedule(date: Date, identifier: String, occurrence: Int) {
        guard date > Date() else { return }

        let bucket = EngagementTracker.abBucket(userID: nil)
        let seed = NotificationMessageBuilder.dailySeed(for: date) + occurrence
        let msg = NotificationMessageBuilder.build(
            MessageContext(
                kind: .weeklySummary,
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
            kind: .weeklySummary,
            identifier: identifier,
            trigger: trigger,
            content: content,
            variant: msg.variant
        )
    }
}
