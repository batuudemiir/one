//
//  NotificationAnalytics.swift
//  one
//
//  Her bildirim için local event log. Ring buffer 200 entry. Orchestrator,
//  UNUserNotificationCenterDelegate callback'leri ve Debug ekranı bu log'u
//  kullanır. Privacy: cihazda kalır, CloudKit'e sync edilmez.
//

import Foundation

enum NotificationAnalyticsEventType: String, Codable {
    case scheduled
    case delivered
    case opened
    case dismissed
    case dropped
    case deferred
}

struct NotificationAnalyticsEvent: Codable {
    let timestamp: Date
    let kind: String
    let identifier: String
    let type: NotificationAnalyticsEventType
    let variant: Int?
    let reason: String?
}

enum NotificationAnalytics {
    private static let capacity = 200
    private static let key = "notificationAnalyticsLog"
    private static let suiteName = "group.com.batudemir.ones"
    private static var defaults: UserDefaults {
        UserDefaults(suiteName: suiteName) ?? .standard
    }

    static func record(
        kind: NotificationKind,
        identifier: String,
        type: NotificationAnalyticsEventType,
        variant: Int? = nil,
        reason: String? = nil
    ) {
        let event = NotificationAnalyticsEvent(
            timestamp: Date(),
            kind: kind.rawValue,
            identifier: identifier,
            type: type,
            variant: variant,
            reason: reason
        )
        var events = loadAll()
        events.append(event)
        if events.count > capacity { events.removeFirst(events.count - capacity) }
        save(events)
    }

    static func loadAll() -> [NotificationAnalyticsEvent] {
        guard let data = defaults.data(forKey: key) else { return [] }
        return (try? JSONDecoder().decode([NotificationAnalyticsEvent].self, from: data)) ?? []
    }

    static func clear() {
        defaults.removeObject(forKey: key)
    }

    /// Returns (opened, delivered) counts per kind over the last `days`.
    static func openRateByKind(days: Int = 7) -> [String: (opened: Int, delivered: Int)] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? .distantPast
        let events = loadAll().filter { $0.timestamp >= cutoff }
        var result: [String: (opened: Int, delivered: Int)] = [:]
        for e in events {
            var entry = result[e.kind] ?? (0, 0)
            switch e.type {
            case .opened:    entry.opened += 1
            case .delivered: entry.delivered += 1
            default: break
            }
            result[e.kind] = entry
        }
        return result
    }

    private static func save(_ events: [NotificationAnalyticsEvent]) {
        guard let data = try? JSONEncoder().encode(events) else { return }
        defaults.set(data, forKey: key)
    }
}
