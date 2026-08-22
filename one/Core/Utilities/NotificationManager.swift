import Foundation
import UserNotifications
import Combine
import SwiftUI
import CoreData
import CloudKit

class NotificationManager: NSObject, ObservableObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationManager()

    @Published var isAuthorized = false
    @Published var shouldNavigateToCircle   = false
    @Published var shouldNavigateToToday    = false
    @Published var shouldNavigateToEcho     = false
    
    override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
        checkAuthorization()
    }
    
    func checkAuthorization() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                self.isAuthorized = (settings.authorizationStatus == .authorized)
            }
        }
    }
    
    /// Sistem izin prompt'unu gösterir — **yalnızca daha önce sorulmamışsa.**
    ///
    /// `.notDetermined` guard'ı savunma katmanı: prompt kullanıcıya hayatında
    /// bir kez gösterilir, o yüzden hangi an'da gösterildiği geri alınamaz bir
    /// karar. Bu guard olmadan herhangi bir çağrı yeri (cold start, günlük
    /// hatırlatıcı planlama) prompt'u yanlış ana çekebiliyordu ve soft-ask
    /// katmanları sessizce ölüyordu.
    ///
    /// Zaten karar verilmişse mevcut durumla döner, prompt göstermez.
    func requestAuthorization(completion: @escaping (Bool) -> Void) {
        let center = UNUserNotificationCenter.current()
        center.getNotificationSettings { settings in
            guard settings.authorizationStatus == .notDetermined else {
                let alreadyAuthorized = settings.authorizationStatus == .authorized
                DispatchQueue.main.async {
                    self.isAuthorized = alreadyAuthorized
                    completion(alreadyAuthorized)
                }
                return
            }

            AppAnalytics.shared.track(.notifPermissionPrompted)
            center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
                DispatchQueue.main.async {
                    self.isAuthorized = granted
                    AppAnalytics.shared.track(.notifPermissionResult(granted: granted))
                    completion(granted)

                    if let error = error {
                        ONELogger.debug("Notification Authorization Error: \(error.localizedDescription)", category: .notification)
                    }
                }
            }
        }
    }
    
    // Çeşitli bildirim metinleri — her gün farklı, Duolingo tarzı
    private static let reminderMessages: [(title: String, body: String)] = [
        ("Bugünün rengi seni bekliyor.", "Bir an bırak."),
        ("Çevren senden haber bekliyor.", "Bugünkü şarkını paylaş ve arkadaşlarının mood'unu gör."),
        ("Bugün nasıl hissediyorsun?", "Bir renk seç, çevrene katıl."),
        ("Bugünün ritmi hazır mı?", "Bir şarkı seç ve bugünü görünür yap."),
        ("Mood'unu aç.", "Bugünkü seçimini kaydet, günü görünür yap."),
        ("Bir paylaşım uzaklıkta.", "Bugünün şarkısını seçmeden günü kapatma."),
        ("Bugünü bırakma.", "Şarkın, mood'un ve çevren burada buluşuyor."),
        // Duolingo-style kişisel mesajlar
        ("Bugün hangi renktesin? 🎨", "Bir şarkı seç, mood'unu kaydet."),
        ("Günün kaldı.", "Şarkıyla işaretle, geride bırakma."),
        ("ONE seni bekliyor 🎵", "Bugünkü seçimini yapmak 10 saniye sürer."),
        ("Arkadaşların çoktan seçti.", "Sen de bugünkü mood'unu paylaş!"),
        ("Seri devam ediyor 🔥", "Bugün de seçimini yap, ritmi bozmama!"),
        ("Şarkısız geçmesin.", "Bugünü müzikle işaretle."),
        ("Yarın geç olmadan.", "Bugünkü hissini kaydet, yeniden bulursun."),
    ]

    // MARK: - Circle Activity Reminder (arkadaş paylaşımı yaptıysa)

    /// Belirtilen sayıda arkadaş bugün paylaşım yaptıysa kullanıcıyı haberdar eder.
    func scheduleCircleActivityNotification(activeCount: Int, firstFriendName: String) {
        guard UserDefaults.standard.oneNotificationsEnabled else { return }
        let center = UNUserNotificationCenter.current()
        let identifier = "circle_activity_\(Self.todayDateKey())"
        // Zaten gönderilmişse tekrarlama
        center.getPendingNotificationRequests { pending in
            if pending.contains(where: { $0.identifier == identifier }) { return }
            let content = UNMutableNotificationContent()
            if activeCount == 1 {
                content.title = "\(firstFriendName) bugünkü seçimini yaptı 🎵"
                content.body  = "Çevrende neler oluyor bir bak!"
            } else {
                content.title = "Çevrende \(activeCount) kişi seçim yaptı 🎵"
                content.body  = "\(firstFriendName) ve diğerleri bugünkü mood'larını paylaştı."
            }
            content.sound = .default
            content.categoryIdentifier = "FRIEND_SHARED"
            content.userInfo = ["type": "circle_activity"]
            let request = UNNotificationRequest(identifier: identifier, content: content, trigger: nil)
            center.add(request) { _ in }
        }
    }

    private static func todayDateKey() -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        return fmt.string(from: Date())
    }


    func scheduleDailyReminder(at time: Date, completion: ((Bool) -> Void)? = nil) {
        let center = UNUserNotificationCenter.current()

        // Mevcut hatırlatıcıları temizle
        center.removePendingNotificationRequests(withIdentifiers: ["daily_reminder"])

        requestAuthorization { granted in
            guard granted else {
                ONELogger.debug("Cannot schedule notification: Permission denied", category: .notification)
                completion?(false)
                return
            }

            let content = UNMutableNotificationContent()

            // Rastgele mesaj seç
            let msg = Self.reminderMessages.randomElement()!
            content.title = msg.title
            content.body  = msg.body
            content.sound = .default
            content.userInfo = ["type": "daily_reminder"]

            // Seçilen saate göre tekrarlayan trigger
            let calendar   = Calendar.current
            let components = calendar.dateComponents([.hour, .minute], from: time)
            let trigger    = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
            let request    = UNNotificationRequest(
                identifier: "daily_reminder",
                content: content,
                trigger: trigger
            )

            center.add(request) { error in
                if let error = error {
                    ONELogger.debug("Error scheduling notification: \(error.localizedDescription)", category: .notification)
                    completion?(false)
                } else {
                    ONELogger.success(
                        "Daily reminder scheduled for \(components.hour ?? 0):\(String(format: "%02d", components.minute ?? 0))",
                        category: .notification
                    )
                    completion?(true)
                }
            }
        }
    }

    /// Bugün zaten şarkı seçilmişse bildirimi iptal eder.
    /// TodayViewModel tarafından kayıt sonrası çağrılır.
    /// Race fix: önceki sürümde 1sn `asyncAfter` içinde yeniden schedule
    /// ediliyordu; Orchestrator bunu `onSongSaved` içinde deterministik
    /// seed ile tek adımda yapar.
    func cancelTodayReminderIfNeeded() {
        NotificationOrchestrator.shared.onSongSaved(
            moodLabel: EngagementTracker.lastMoodLabel,
            moodColorHex: EngagementTracker.lastMoodColorHex
        )
    }
    
    func disableDailyReminder() {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: ["daily_reminder"])
        ONELogger.debug("Daily reminder disabled", category: .notification)
    }


    // MARK: - Weekly Summary (her Pazar 18:00)

    func scheduleWeeklySummary() {
        guard UserDefaults.standard.bool(forKey: "weeklySummaryEnabled") else { return }
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: ["weekly_summary"])

        let content = UNMutableNotificationContent()
        content.title = "Bu haftanın özeti hazır 📊"
        content.body  = "Bu hafta nasıl geçti? Ruh halin seni bekliyor."
        content.sound = .default
        content.categoryIdentifier = "WEEKLY_SUMMARY"
        content.userInfo = ["type": "weekly_summary"]

        var dateComponents = DateComponents()
        dateComponents.weekday = 1  // Pazar
        dateComponents.hour    = 18
        dateComponents.minute  = 0
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(identifier: "weekly_summary", content: content, trigger: trigger)

        center.add(request) { error in
            if let error {
                ONELogger.error("Failed to schedule weekly summary", error: error, category: .notification)
            } else {
                ONELogger.success("Weekly summary notification scheduled", category: .notification)
            }
        }
    }

    func disableWeeklySummary() {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: ["weekly_summary"])
    }

    // MARK: - Akıllı Hatırlatma (Pattern Bazlı)

    /// Son 30 günün kayıt saatlerine bakarak hatırlatıcıyı kullanıcının en aktif olduğu
    /// saate göre ayarlar. En az 5 kayıt gerekir; aksi hâlde değişiklik yapılmaz.
    func scheduleSmartDailyReminder(context: NSManagedObjectContext) {
        guard UserDefaults.standard.oneNotificationsEnabled else { return }

        let fetchRequest: NSFetchRequest<DailySong> = DailySong.fetchRequest()
        guard let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: Date()) else { return }
        fetchRequest.predicate = NSPredicate(format: "createdAt >= %@", thirtyDaysAgo as NSDate)

        guard let songs = try? context.fetch(fetchRequest), songs.count >= 3 else { return }

        var hourCounts = [Int: Int]()
        for song in songs {
            guard let created = song.createdAt else { continue }
            let hour = Calendar.current.component(.hour, from: created)
            hourCounts[hour, default: 0] += 1
        }

        // Peak saati 9-22 aralığında ara
        guard let peakHour = hourCounts
            .filter({ $0.key >= 9 && $0.key <= 22 })
            .max(by: { $0.value < $1.value })?
            .key else { return }

        let currentHour = UserDefaults.standard.integer(forKey: "dailyReminderHour")
        let currentEffectiveHour = currentHour == 0 ? 20 : currentHour

        // En az 1 saat fark varsa güncelle
        guard abs(peakHour - currentEffectiveHour) >= 1 else { return }

        UserDefaults.standard.set(peakHour, forKey: "dailyReminderHour")
        UserDefaults.standard.set(0, forKey: "dailyReminderMinute")

        var comps = DateComponents()
        comps.hour = peakHour
        comps.minute = 0
        if let date = Calendar.current.date(from: comps) {
            scheduleDailyReminder(at: date)
            ONELogger.info("Akıllı hatırlatma: \(peakHour):00 olarak güncellendi (önceki: \(currentEffectiveHour):00)", category: .notification)
        }
    }

    // Show notifications as banner even if app is open
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        NotificationOrchestrator.shared.recordDelivered(notification)
        completionHandler([.banner, .sound])
    }

    // Handle notification tap / action
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        NotificationOrchestrator.shared.recordOpened(response)
        let userInfo   = response.notification.request.content.userInfo
        let actionID   = response.actionIdentifier
        let categoryID = response.notification.request.content.categoryIdentifier
        let type       = userInfo["type"] as? String ?? ""

        DispatchQueue.main.async {
            switch categoryID {

            case "FRIEND_REQUEST":
                switch actionID {
                case "ACCEPT_FRIEND":
                    self.shouldNavigateToCircle = true
                case "DECLINE_FRIEND":
                    ONELogger.debug("Friend request declined via notification", category: .notification)
                default:
                    self.shouldNavigateToCircle = true
                }

            case "FRIEND_SHARED":
                // Arkadaş paylaşımının tek hedefi Çevre. Kategorinin aksiyonu
                // da (`OPEN_CIRCLE`) buraya düşüyor — düğme ve gövde dokunuşu
                // aynı yere gidiyor.
                self.shouldNavigateToCircle = true

            case "FRIEND_ACCEPTED", "EMOJI_REACTION":
                self.shouldNavigateToCircle = true

            case "STREAK_WARNING":
                self.shouldNavigateToToday = true

            case "WEEKLY_SUMMARY":
                self.shouldNavigateToEcho = true

            case "APP_UPDATE":
                AppUpdateChecker.shared.openAppStore()

            default:
                // Eski "type" tabanlı yönlendirme (geriye uyumluluk)
                switch type {
                case "friend_request", "friend_shared", "friend_accepted", "emoji_reaction":
                    self.shouldNavigateToCircle = true
                case "daily_reminder":
                    self.shouldNavigateToToday = true
                case "app_update":
                    AppUpdateChecker.shared.openAppStore()
                default:
                    break
                }
            }
        }

        completionHandler()
    }

    // MARK: - App Update Notification

    /// Yeni sürüm tespit edildiğinde bildirim gönderir.
    /// Bildirime tıklandığında App Store açılır.
    /// Aynı sürüm için yalnızca bir kez gönderilir.
    func scheduleAppUpdateNotification(newVersion: String) {
        let alreadyNotifiedKey = "appUpdateNotified_\(newVersion)"
        guard !UserDefaults.standard.bool(forKey: alreadyNotifiedKey) else { return }

        let center = UNUserNotificationCenter.current()
        let content = UNMutableNotificationContent()
        content.title = NSLocalizedString("notification.appUpdate.title", comment: "")
        content.body  = String(format: NSLocalizedString("notification.appUpdate.body", comment: ""), newVersion)
        content.sound = .default
        content.categoryIdentifier = "APP_UPDATE"
        content.userInfo = ["type": "app_update"]

        let request = UNNotificationRequest(
            identifier: "app_update_available",
            content: content,
            trigger: nil  // anlık gönderim
        )
        center.add(request) { error in
            if let error {
                ONELogger.error("Failed to schedule app update notification", error: error, category: .notification)
            } else {
                UserDefaults.standard.set(true, forKey: alreadyNotifiedKey)
                ONELogger.success("App update notification sent for v\(newVersion)", category: .notification)
            }
        }
    }

    // MARK: - Month-End Summary Notification

    /// Ayın son günü saat 20:00'de aylık özet hazır bildirimi gönderir.
    func scheduleMonthEndNotification() {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: ["monthEndSummary"])

        let content = UNMutableNotificationContent()
        content.title = NSLocalizedString("notification.monthEnd.title", comment: "")
        content.body  = NSLocalizedString("notification.monthEnd.body",  comment: "")
        content.sound = .default
        content.userInfo = ["type": "monthly_summary"]

        // Ayın son günü saat 20:00
        let cal = Calendar.current
        let now = Date()
        guard
            let firstOfMonth = cal.date(from: cal.dateComponents([.year, .month], from: now)),
            let firstOfNextMonth = cal.date(byAdding: .month, value: 1, to: firstOfMonth),
            let lastDay = cal.date(byAdding: .day, value: -1, to: firstOfNextMonth)
        else { return }

        var comps = cal.dateComponents([.year, .month, .day], from: lastDay)
        comps.hour = 20
        comps.minute = 0

        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
        let request = UNNotificationRequest(identifier: "monthEndSummary", content: content, trigger: trigger)
        center.add(request) { error in
            if let error {
                ONELogger.error("Failed to schedule month-end notification", error: error, category: .notification)
            } else {
                ONELogger.success("Month-end summary notification scheduled", category: .notification)
            }
        }
    }
}
