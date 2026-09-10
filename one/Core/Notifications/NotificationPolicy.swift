//
//  NotificationPolicy.swift
//  one
//
//  Bildirim karar motorunun primitif tipleri: kind, priority, quiet hours,
//  karar sonuçları. Orchestrator bu tipleri kullanarak her bildirim için
//  allow / defer / drop kararı verir.
//

import Foundation

// MARK: - Priority

enum NotificationPriority: Int, Comparable {
    case low = 1
    case normal = 2
    case high = 3
    case critical = 4

    static func < (lhs: NotificationPriority, rhs: NotificationPriority) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

// MARK: - Time of Day

enum TimeOfDay {
    case morning, noon, evening, night

    static func from(_ date: Date, calendar: Calendar = .current) -> TimeOfDay {
        switch calendar.component(.hour, from: date) {
        case 5..<12:  return .morning
        case 12..<17: return .noon
        case 17..<22: return .evening
        default:      return .night
        }
    }
}

// MARK: - Notification Kind

enum NotificationKind: String, CaseIterable {
    case dailyReminder
    case weeklySummary
    case monthEndSummary
    case circleActivity
    case moodResonance
    case friendShared
    case friendReaction
    case friendRequest
    case friendAccepted
    // Yorum türleri (commentReceived/Reply/Mention/Batch) kaldırıldı: kalıcı
    // yorum sistemi sökülüp yerine efemer karşılık (tepki + yanıt) geldi,
    // dördünü de üreten hiçbir çağrı yeri kalmamıştı. Gelen karşılıklar
    // `friendReaction` ile bildiriliyor.

    var priority: NotificationPriority {
        switch self {
        case .friendRequest, .friendAccepted:
            return .critical
        case .friendShared:
            return .critical
        case .friendReaction, .moodResonance, .circleActivity:
            return .high
        case .dailyReminder, .weeklySummary, .monthEndSummary:
            return .normal
        }
    }

    /// True if scheduled proactively by the app (not reacting to a live event).
    /// Proactive kinds count toward the weekly proactive cap.
    ///
    /// v4: win-back ve nurture serileri kaldırıldı. Uygulamanın kendi
    /// inisiyatifiyle konuştuğu tek üç durum kaldı — günlük ritüel,
    /// haftalık ve aylık portre. Hepsi haftalık proactive cap'e tabi.
    var isProactive: Bool {
        switch self {
        case .dailyReminder, .weeklySummary, .monthEndSummary:
            return true
        default:
            return false
        }
    }

    var categoryIdentifier: String {
        switch self {
        case .weeklySummary:          return "WEEKLY_SUMMARY"
        case .friendShared, .circleActivity: return "FRIEND_SHARED"
        case .friendRequest:          return "FRIEND_REQUEST"
        case .friendReaction, .friendAccepted: return "FRIEND_ACCEPTED"
        case .moodResonance:          return "MOOD_RESONANCE"
        default:                      return ""
        }
    }

}

// MARK: - Quiet Hours

struct QuietHours {
    let start: Int   // hour 0-23 inclusive
    let end: Int     // hour 0-23 exclusive

    static let `default` = QuietHours(start: 22, end: 9)

    func contains(_ date: Date, calendar: Calendar = .current) -> Bool {
        let hour = calendar.component(.hour, from: date)
        if start == end { return false }
        if start < end {
            return hour >= start && hour < end
        } else {
            // Wraps midnight e.g. 23 → 8
            return hour >= start || hour < end
        }
    }

    /// Returns the next Date at or after `fireDate` that falls outside quiet hours.
    func nextActiveWindow(after fireDate: Date, calendar: Calendar = .current) -> Date {
        guard contains(fireDate, calendar: calendar) else { return fireDate }
        var comps = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)
        comps.hour = end
        comps.minute = 0
        var next = calendar.date(from: comps) ?? fireDate
        if next <= fireDate {
            next = calendar.date(byAdding: .day, value: 1, to: next) ?? fireDate
        }
        return next
    }
}

// MARK: - Schedule Decision

enum ScheduleDecision {
    case allow
    case deferTo(Date)
    case drop(reason: String)
}
