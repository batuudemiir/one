import Foundation
import UserNotifications
import CoreData

/// Günlük ritüelin **tek** planlayıcısı. Kurallar:
/// - Günde tek local notification.
/// - Bugün kayıt zaten varsa iptal.
/// - Kaçırılan gün için follow-up yok.
/// - Master kapalıysa tüm pending istekleri iptal.
///
/// v4: metin `NotificationMessageBuilder`'dan gelir (bkz. `V3ReminderTone`).
/// Saati, günlerini ve tonunu kullanıcı seçtiği için bu bildirim haftalık
/// proaktif bütçeye girmez — uygulamanın kendi inisiyatifi değil, kullanıcının
/// kendisiyle kurduğu randevudur.
enum V3ReminderScheduler {

    /// Bekleyen tüm v3 istekleri için ID prefix'i.
    static let idPrefix = "v3_daily_reminder_"

    /// Ayarları oku, izin varsa 7 güne kadar tek tek planla.
    /// - Parameter yesterdayMood: `curious` tonu için — nil'sa `short`'a düşer.
    static func reschedule(yesterdayMood: V3Mood? = nil,
                           defaults: UserDefaults = .standard) {
        let settings = V3ReminderSettings.load(from: defaults)
        let center = UNUserNotificationCenter.current()

        // v3 tek günlük bildirime geçtiği için mevcut `daily_reminder` iptal.
        // Aynı saatte iki bildirim (eski Duolingo-tonlu + v3 yalın) atmasın.
        NotificationManager.shared.disableDailyReminder()

        // Önce mevcut tüm v3 pending isteklerini temizle.
        center.getPendingNotificationRequests { requests in
            let ids = requests.map(\.identifier).filter { $0.hasPrefix(idPrefix) }
            if !ids.isEmpty {
                center.removePendingNotificationRequests(withIdentifiers: ids)
            }

            guard settings.enabled else { return }

            // Bugün için zaten kayıt varsa bugünün fire'ı planlanmaz (aşağıda
            // seçili tarih için ayrıca kontrol edilir).
            NotificationManager.shared.requestAuthorization { granted in
                guard granted else { return }
                scheduleUpcoming(settings: settings, yesterdayMood: yesterdayMood)
            }
        }
    }

    /// Master kapatıldığında ya da uygulama kaldırıldığında çağır.
    static func cancelAll() {
        let center = UNUserNotificationCenter.current()
        center.getPendingNotificationRequests { requests in
            let ids = requests.map(\.identifier).filter { $0.hasPrefix(idPrefix) }
            center.removePendingNotificationRequests(withIdentifiers: ids)
        }
    }

    // MARK: - Private

    private static func scheduleUpcoming(settings: V3ReminderSettings,
                                         yesterdayMood: V3Mood?) {
        let calendar = Calendar.current
        let now = Date()
        let hasEntryToday = existsEntryForToday()

        // Sonraki 7 günü planla — her gün için yalnızca 1 istek.
        for offset in 0..<7 {
            guard let day = calendar.date(byAdding: .day, value: offset, to: now) else { continue }

            // Handoff: Pzt=0 → Sunday=6 (Türkiye takvimi)
            let weekdayIndex = weekdayIndexMondayFirst(from: day, calendar: calendar)
            guard settings.days[weekdayIndex] else { continue }

            var comps = calendar.dateComponents([.year, .month, .day], from: day)
            comps.hour = settings.hour
            comps.minute = settings.minute
            guard let fireDate = calendar.date(from: comps) else { continue }

            // Geçmiş saat: bugün ise ve saat geçtiyse atla.
            if offset == 0, fireDate <= now { continue }

            // Bugün için kayıt zaten yapıldıysa bugünün fire'ı planlanmaz.
            if offset == 0, hasEntryToday { continue }

            // curious tonu için body — yalnızca bugünkü fire'a bakalım; sonraki
            // günlerde `short` fallback (yarının "dünü" bugün henüz belirsiz).
            let mood: V3Mood? = (offset == 0) ? yesterdayMood : nil
            let content = makeContent(tone: settings.tone, yesterdayMood: mood, fireDate: fireDate)

            let trigger = UNCalendarNotificationTrigger(
                dateMatching: calendar.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate),
                repeats: false
            )
            let id = "\(idPrefix)\(comps.year ?? 0)-\(comps.month ?? 0)-\(comps.day ?? 0)"
            let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
            UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
        }
    }

    /// `fireDate` metne giriyor: başlık gün adını taşıyor ("Salı akşamı") ve
    /// bu döngü 7 gün ileriyi planlıyor. Bugünün gününü yedi isteğe birden
    /// yazmak, kullanıcıya cuma günü "Salı" diyen bir bildirim gönderirdi.
    private static func makeContent(tone: V3ReminderTone,
                                    yesterdayMood: V3Mood?,
                                    fireDate: Date) -> UNNotificationContent {
        let text = tone.notification(yesterdayMood: yesterdayMood, now: fireDate)
        let content = UNMutableNotificationContent()
        content.title = text.title
        content.body = text.body
        content.sound = .default
        content.userInfo = ["type": "v3_daily_reminder", "tone": tone.rawValue]
        return content
    }

    /// Bugün için `DailySong` var mı? — Handoff kuralı: kayıtlıysa bugünün
    /// bildirimini planlama.
    private static func existsEntryForToday() -> Bool {
        let context = PersistenceController.shared.container.viewContext
        let today = Calendar.current.startOfDay(for: Date())
        let req: NSFetchRequest<DailySong> = DailySong.fetchRequest()
        req.predicate = NSPredicate(format: "date == %@", today as NSDate)
        req.fetchLimit = 1
        return ((try? context.count(for: req)) ?? 0) > 0
    }

    /// Pazartesi = 0, ..., Pazar = 6.
    private static func weekdayIndexMondayFirst(from date: Date, calendar: Calendar) -> Int {
        let weekday = calendar.component(.weekday, from: date)  // Pazar=1..Cmt=7
        return (weekday + 5) % 7
    }
}
