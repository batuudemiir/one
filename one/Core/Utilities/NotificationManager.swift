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
    
    // MARK: - Circle Activity (birden çok arkadaş bugün paylaştıysa)

    /// v4: metin `NotificationMessageBuilder`'dan gelir ve istek
    /// `NotificationOrchestrator`'dan geçer — sessiz saatler, tavan ve
    /// telemetri burada da işlesin. Başlık kişi, gövde olay.
    func scheduleCircleActivityNotification(activeCount: Int, firstFriendName: String) {
        guard UserDefaults.standard.oneNotificationsEnabled else { return }
        let center = UNUserNotificationCenter.current()
        let identifier = "circle_activity_\(Self.todayDateKey())"
        // Zaten gönderilmişse tekrarlama
        center.getPendingNotificationRequests { pending in
            if pending.contains(where: { $0.identifier == identifier }) { return }

            let msg = NotificationMessageBuilder.social(
                .circleActivity,
                friendName: firstFriendName,
                friendCount: max(1, activeCount)
            )
            let content = UNMutableNotificationContent()
            content.title = msg.title
            content.body  = msg.body
            content.sound = .default
            content.userInfo = ["type": "circle_activity"]

            _ = NotificationOrchestrator.shared.schedule(
                kind: .circleActivity,
                identifier: identifier,
                trigger: nil,
                content: content,
                variant: msg.variant
            )
        }
    }

    private static func todayDateKey() -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        return fmt.string(from: Date())
    }


    // MARK: - Günlük hatırlatma
    //
    // v4: bu sınıfta ikinci bir günlük hatırlatma motoru vardı — rastgele
    // seçilen 14 mesajlık bir katalog ("ONE seni bekliyor 🎵", "Seri devam
    // ediyor 🔥", "10 saniye sürer"). Katalog da motor da kaldırıldı.
    // Günlük ritüelin tek sahibi `V3ReminderScheduler`, metnin tek kaynağı
    // `NotificationMessageBuilder`. Burada yalnız iptal ucu kaldı.

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


    // MARK: - Haftalık portre (v4'te tek sahibi SundayReflectionScheduler)
    //
    // Burada Pazar 18:00'e kurulu ikinci bir haftalık push vardı
    // ("Bu haftanın özeti hazır 📊 / Ruh halin seni bekliyor"). Aynı olayı
    // iki kez duyuran Cumartesi push'uyla aynı hatanın bir başkasıydı;
    // kaldırıldı. Pending kalmış istekler `NotificationOrchestrator`
    // `purgeRetiredSchedules` içinde temizleniyor.

    // MARK: - Akıllı hatırlatma (v4'te kaldırıldı)
    //
    // Kayıt saatlerinin medyanına bakıp hatırlatma saatini kendi başına
    // kaydıran katman kaldırıldı: ritüelin saatini kullanıcı seçer.

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

    // MARK: - Aylık portre (v4'te tek sahibi MonthlyPortraitScheduler)
    //
    // Ayın son günü 20:00'de "Bu ayın özeti hazır / görmeye hazır mısın?"
    // push'u vardı; ayın 1'i 11:00'deki portre push'uyla aynı şeyi iki kez
    // duyuruyordu. Ayrıca orchestrator'dan geçmiyordu — sessiz saat, tavan
    // ve telemetri dışıydı. Kaldırıldı.

}
