import Foundation
import UserNotifications
import Combine
import SwiftUI

class NotificationManager: NSObject, ObservableObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationManager()
    
    @Published var isAuthorized = false
    @Published var shouldNavigateToCircle = false
    
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
    
    func requestAuthorization(completion: @escaping (Bool) -> Void) {
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            DispatchQueue.main.async {
                self.isAuthorized = granted
                completion(granted)
                
                if let error = error {
                    ONELogger.debug("Notification Authorization Error: \(error.localizedDescription)", category: .notification)
                }
            }
        }
    }
    
    // Çeşitli bildirim metinleri — her gün farklı görünsün
    private static let reminderMessages: [(title: String, body: String)] = [
        ("Hisset. Keşfet. Paylaş.", "Bugünün şarkısını seç, mood'unu bırak."),
        ("Çevren senden haber bekliyor.", "Bugünkü şarkını paylaş ve arkadaşlarının mood'unu gör."),
        ("Bugün nasıl hissediyorsun?", "Şarkını seç, etkinlikleri keşfet, çevrene katıl."),
        ("Bugünün ritmi hazır mı?", "Bir şarkı seç ve bugünü görünür yap."),
        ("Mood'unu aç.", "Yakınındaki önerileri görmek için bugünkü seçimini kaydet."),
        ("Bir paylaşım uzaklıkta.", "Bugünün şarkısını seçmeden günü kapatma."),
        ("Bugünü bırakma.", "Şarkın, mood'un ve çevren burada buluşuyor."),
    ]

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
    func cancelTodayReminderIfNeeded() {
        let center = UNUserNotificationCenter.current()
        // Pending listesinde varsa kaldır, delivered'da bırak (zaten görünmüş)
        center.getPendingNotificationRequests { requests in
            let ids = requests
                .filter { $0.identifier == "daily_reminder" }
                .map { $0.identifier }
            if !ids.isEmpty {
                center.removePendingNotificationRequests(withIdentifiers: ids)
                ONELogger.debug("Daily reminder cancelled — today's entry saved.", category: .notification)
                // Bir sonraki gün için yeniden schedule et
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                    let defaults = UserDefaults.standard
                    guard defaults.bool(forKey: "notificationsEnabled") else { return }
                    let hour   = defaults.integer(forKey: "dailyReminderHour")
                    let minute = defaults.integer(forKey: "dailyReminderMinute")
                    var comps  = DateComponents()
                    comps.hour   = hour == 0 ? 20 : hour
                    comps.minute = minute
                    if let date = Calendar.current.date(from: comps) {
                        self.scheduleDailyReminder(at: date)
                    }
                }
            }
        }
    }
    
    func disableDailyReminder() {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: ["daily_reminder"])
        ONELogger.debug("Daily reminder disabled", category: .notification)
    }
    
    // Show notifications as banner even if app is open
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound])
    }
    
    // Handle notification tap / action
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        let userInfo = response.notification.request.content.userInfo
        let actionID = response.actionIdentifier
        
        // Check if it's a friend request notification
        if userInfo["type"] as? String == "friend_request" {
            switch actionID {
            case "ACCEPT_FRIEND":
                // Accept handled via FriendRequestsView (need to open it)
                DispatchQueue.main.async {
                    self.shouldNavigateToCircle = true
                }
            case "DECLINE_FRIEND":
                ONELogger.debug("Friend request declined via notification", category: .notification)
            default:
                // Default tap — navigate to Circle
                DispatchQueue.main.async {
                    self.shouldNavigateToCircle = true
                }
            }
        }
        
        completionHandler()
    }
}
