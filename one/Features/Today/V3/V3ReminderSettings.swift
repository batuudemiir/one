import Foundation
import SwiftUI

/// v3 hatırlatma ayarlarının tek kaynak deposu. `UserDefaults`/`@AppStorage`
/// üzerinden okunuyor; NotificationManager bunlara bakarak schedule ediyor.
///
/// Handoff'a göre bu ayarlar tamamen yerel (`Veri sende. Bizde değil.`)
/// — CloudKit sync yok.
enum V3ReminderKeys {
    static let minutes = "v3ReminderMinutes"   // Int, 06:00–23:30 arası 30 dk step
    static let enabled = "v3ReminderEnabled"   // Bool, default true
    static let tone    = "v3ReminderTone"      // String rawValue
    static let days    = "v3ReminderDays"      // String, "1,1,1,1,1,1,1" (Pzt→Paz)
}

enum V3ReminderTone: String, CaseIterable, Identifiable {
    case quiet
    case short
    case curious

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .quiet:   return "Sessiz"
        case .short:   return "Kısa"
        case .curious: return "Merak eden"
        }
    }

    var sampleBody: String {
        switch self {
        case .quiet:   return "Tek kelime, tek renk."
        case .short:   return "On saniye sürer."
        case .curious: return "Dün maviydin. Bugün hangi renk?"
        }
    }

    /// Bildirim metni. `curious` için önceki güne göre body yeniden üretilir;
    /// önceki gün yoksa `short` fallback verilir (handoff kuralı).
    func notification(yesterdayMood: V3Mood?) -> (title: String, body: String) {
        switch self {
        case .quiet:
            return ("Bugün.", "Tek kelime, tek renk.")
        case .short:
            return ("Bugün nasılsın?", "On saniye sürer.")
        case .curious:
            if let y = yesterdayMood {
                return ("Dün \(y.accusativePastTense).", "Bugün hangi renk?")
            }
            return V3ReminderTone.short.notification(yesterdayMood: nil)
        }
    }
}

struct V3ReminderSettings {
    var minutes: Int          // 06:00 = 360, 23:30 = 1410
    var enabled: Bool
    var tone: V3ReminderTone
    var days: [Bool]          // 7 elemanlı, Pazartesi başlangıçlı

    static let defaults = V3ReminderSettings(
        minutes: 21 * 60,
        enabled: true,
        tone: .short,
        days: Array(repeating: true, count: 7)
    )

    static let minMinutes = 6 * 60
    static let maxMinutes = 23 * 60 + 30
    static let step = 30

    var hour: Int { minutes / 60 }
    var minute: Int { minutes % 60 }

    var formattedTime: String {
        String(format: "%02d:%02d", hour, minute)
    }

    static func load(from defaults: UserDefaults = .standard) -> V3ReminderSettings {
        let stored = defaults.object(forKey: V3ReminderKeys.minutes) as? Int
        let minutes = stored.map { clamp($0) } ?? Self.defaults.minutes

        let enabled: Bool
        if defaults.object(forKey: V3ReminderKeys.enabled) == nil {
            enabled = Self.defaults.enabled
        } else {
            enabled = defaults.bool(forKey: V3ReminderKeys.enabled)
        }

        let toneRaw = defaults.string(forKey: V3ReminderKeys.tone) ?? Self.defaults.tone.rawValue
        let tone = V3ReminderTone(rawValue: toneRaw) ?? Self.defaults.tone

        let days: [Bool]
        if let raw = defaults.string(forKey: V3ReminderKeys.days) {
            let parsed = raw.split(separator: ",").map { $0 == "1" }
            days = parsed.count == 7 ? parsed : Self.defaults.days
        } else {
            days = Self.defaults.days
        }

        return V3ReminderSettings(minutes: minutes, enabled: enabled, tone: tone, days: days)
    }

    func save(to defaults: UserDefaults = .standard) {
        defaults.set(minutes, forKey: V3ReminderKeys.minutes)
        defaults.set(enabled, forKey: V3ReminderKeys.enabled)
        defaults.set(tone.rawValue, forKey: V3ReminderKeys.tone)
        let daysString = days.map { $0 ? "1" : "0" }.joined(separator: ",")
        defaults.set(daysString, forKey: V3ReminderKeys.days)
    }

    static func clamp(_ minutes: Int) -> Int {
        min(max(minutes, minMinutes), maxMinutes)
    }
}
