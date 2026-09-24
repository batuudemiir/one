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
        case .quiet:   return NSLocalizedString("reminder.tone.quiet", comment: "")
        case .short:   return NSLocalizedString("reminder.tone.short", comment: "")
        case .curious: return NSLocalizedString("reminder.tone.recall", comment: "")
        }
    }

    /// Ayar ekranındaki örnek satır. **Gönderilen metnin kendisidir** —
    /// örnek ile gerçek metin ayrı yazıldığında ikisi ayrı sese kayıyordu.
    ///
    /// Dün bağlamlı tonun farkı ancak gerçek bir dünkü kayıtla görünür; o
    /// yüzden örnekte kullanıcının **kendi** son moodu kullanılıyor. Kayıt
    /// yoksa ton `Kısa` metnine düşüyor — ekranda da öyle görünmesi doğru.
    var sampleBody: String {
        let tone: NotificationMessageBuilder.DailyTone = {
            switch self {
            case .quiet:   return .quiet
            case .short:   return .plain
            case .curious: return .recall
            }
        }()
        return NotificationMessageBuilder.dailyReminder(
            tone: tone,
            yesterdayMoodLabel: EngagementTracker.lastMoodLabel,
            now: Self.sampleDate
        ).body
    }

    /// Örnek satır için sabit bir gün/saat: ayar ekranı her açılışta farklı
    /// varyant göstermesin.
    private static let sampleDate: Date = {
        var comps = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        comps.hour = 21
        comps.minute = 0
        return Calendar.current.date(from: comps) ?? Date()
    }()

    /// v4 marka sesi: metin `NotificationMessageBuilder`'dan gelir. Ton
    /// yalnızca ne kadar bağlam taşındığını seçer — üçü de bir olguyu
    /// bildirir, hiçbiri bir şey istemez, süre vaat etmez, duygu yorumlamaz.
    ///
    /// `curious` için önceki günün moodu **olgu olarak** anılır; önceki gün
    /// yoksa `short` metnine düşer.
    func notification(yesterdayMood: V3Mood?, now: Date = Date()) -> (title: String, body: String) {
        let tone: NotificationMessageBuilder.DailyTone = {
            switch self {
            case .quiet:   return .quiet
            case .short:   return .plain
            case .curious: return .recall
            }
        }()
        let msg = NotificationMessageBuilder.dailyReminder(
            tone: tone,
            yesterdayMoodLabel: yesterdayMood?.label.localizedLowercase,
            now: now
        )
        return (msg.title, msg.body)
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
