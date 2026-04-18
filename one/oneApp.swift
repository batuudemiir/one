//
//  oneApp.swift
//  one
//
//  Created by Batu Demir on 23.02.2026.
//

import SwiftUI
import CoreData
import CloudKit
import UserNotifications
// MARK: - App Delegate for Push Notifications

class AppDelegate: NSObject, UIApplicationDelegate {
    
    // Lock to portrait only — prevent landscape rotation.
    func application(
        _ application: UIApplication,
        supportedInterfaceOrientationsFor window: UIWindow?
    ) -> UIInterfaceOrientationMask {
        return .portrait
    }

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        // Register for remote notifications (required for CloudKit push)
        application.registerForRemoteNotifications()
        
        // Set up notification categories
        setupNotificationCategories()
        
        return true
    }
    
    func application(_ application: UIApplication,
                     didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        let tokenString = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
        ONELogger.success("Registered for remote notifications: \(tokenString.prefix(8))...", category: .notification)
    }
    
    func application(_ application: UIApplication,
                     didFailToRegisterForRemoteNotificationsWithError error: Error) {
        ONELogger.error("Failed to register for remote notifications", error: error, category: .notification)
    }
    
    // Handle CloudKit silent push notifications
    func application(_ application: UIApplication,
                     didReceiveRemoteNotification userInfo: [AnyHashable: Any],
                     fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        
        // Convert [AnyHashable: Any] to [String: Any]
        let stringKeyedDict = Dictionary(uniqueKeysWithValues: userInfo.map { (String(describing: $0.key), $0.value) })
        
        // Check if it's a CloudKit notification
        if let ck = userInfo["ck"] as? [String: Any] {
            ONELogger.debug("Received CloudKit push: \(ck["qry"] ?? "unknown")", category: .cloudkit)
            
            CloudKitManager.shared.handleCloudKitNotification(stringKeyedDict) {
                completionHandler(.newData)
            }
        } else {
            completionHandler(.noData)
        }
    }
    
    // MARK: - Notification Categories
    
    private func setupNotificationCategories() {
        // Arkadaşlık isteği
        let acceptAction = UNNotificationAction(
            identifier: "ACCEPT_FRIEND",
            title: NSLocalizedString("notification.acceptFriend", comment: ""),
            options: [.foreground]
        )
        let declineAction = UNNotificationAction(
            identifier: "DECLINE_FRIEND",
            title: NSLocalizedString("notification.declineFriend", comment: ""),
            options: [.destructive]
        )
        let friendRequestCategory = UNNotificationCategory(
            identifier: "FRIEND_REQUEST",
            actions: [acceptAction, declineAction],
            intentIdentifiers: [],
            options: []
        )

        // Streak tehlikede
        let openTodayAction = UNNotificationAction(
            identifier: "OPEN_TODAY",
            title: NSLocalizedString("notification.openToday", comment: ""),
            options: [.foreground]
        )
        let streakCategory = UNNotificationCategory(
            identifier: "STREAK_WARNING",
            actions: [openTodayAction],
            intentIdentifiers: [],
            options: []
        )

        // Haftalık özet
        let openEchoAction = UNNotificationAction(
            identifier: "OPEN_ECHO",
            title: NSLocalizedString("notification.openEcho", comment: ""),
            options: [.foreground]
        )
        let weeklySummaryCategory = UNNotificationCategory(
            identifier: "WEEKLY_SUMMARY",
            actions: [openEchoAction],
            intentIdentifiers: [],
            options: []
        )

        // Keşfet hatırlatıcısı
        let openDiscoveryAction = UNNotificationAction(
            identifier: "OPEN_DISCOVERY",
            title: NSLocalizedString("notification.openDiscovery", comment: ""),
            options: [.foreground]
        )
        let discoveryCategory = UNNotificationCategory(
            identifier: "DISCOVERY_REMINDER",
            actions: [openDiscoveryAction],
            intentIdentifiers: [],
            options: []
        )

        // Arkadaş paylaşımı — "Keşfet" aksiyonu ile Discover'a yönlendir
        let openDiscoverAction = UNNotificationAction(
            identifier: "OPEN_DISCOVER",
            title: NSLocalizedString("notification.openDiscovery", comment: ""),
            options: [.foreground]
        )
        let friendSharedCategory = UNNotificationCategory(
            identifier: "FRIEND_SHARED",
            actions: [openDiscoverAction],
            intentIdentifiers: [],
            options: []
        )

        // Çevre Yankısı — mood rezonans bildirimi
        let openCircleAction = UNNotificationAction(
            identifier: "OPEN_CIRCLE",
            title: NSLocalizedString("notification.openCircle", comment: ""),
            options: [.foreground]
        )
        let moodResonanceCategory = UNNotificationCategory(
            identifier: "MOOD_RESONANCE",
            actions: [openCircleAction],
            intentIdentifiers: [],
            options: []
        )

        UNUserNotificationCenter.current().setNotificationCategories([
            friendRequestCategory,
            streakCategory,
            weeklySummaryCategory,
            discoveryCategory,
            friendSharedCategory,
            moodResonanceCategory
        ])
    }
}

@main
struct oneApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    let persistenceController = PersistenceController.shared
    @StateObject private var cloudKitManager = CloudKitManager.shared
    @StateObject private var languageManager = LanguageManager.shared
    @StateObject private var updateChecker = AppUpdateChecker.shared
    @StateObject private var premiumManager = PremiumManager.shared
    @AppStorage("isDarkMode") private var isDarkMode = false
    /// Invite code from a deep link that arrived before currentUser was loaded.
    @State private var pendingDeepLinkCode: String? = nil

    init() {
        // Register background task for midnight reset
        MidnightResetManager.shared.registerBackgroundTask()

        // Observability bootstrap — real SDK registration lives in
        // docs/OBSERVABILITY_SETUP.md (Sentry + PostHog). Default stack
        // is console-only so DEBUG builds still see event flow.
        #if DEBUG
        AppAnalytics.shared.register(ConsoleAnalyticsService())
        #endif
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(languageManager)
                .environmentObject(premiumManager)
                .badgeUnlockToast()
                // Rebuild the entire SwiftUI tree when the language changes
                .id(languageManager.refreshToken)
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
                .preferredColorScheme(isDarkMode ? .dark : .light)
                .onAppear {
                    // Check CloudKit availability on app launch
                    cloudKitManager.checkCloudKitAvailability()

                    // Uygulama açılışında kalmış eski Live Activity'leri temizle
                    if #available(iOS 16.1, *) {
                        Task {
                            await LiveActivityManager.shared.endAllActivities()
                        }
                    }
                    
                    // Schedule midnight reset
                    MidnightResetManager.shared.scheduleMidnightReset()
                    
                    // Request notification permission & register CloudKit subscription
                    setupPushNotifications()

                    // Akıllı hatırlatma: geçmiş kayıt saatlerine göre optimize et
                    NotificationManager.shared.scheduleSmartDailyReminder(
                        context: persistenceController.container.viewContext
                    )

                    // Ay-sonu özet bildirimi planla
                    NotificationManager.shared.scheduleMonthEndNotification()

                    // App Store güncelleme kontrolü
                    updateChecker.check()
                }
                .sheet(isPresented: $updateChecker.updateAvailable) {
                    AppUpdateSheet(
                        currentVersion: updateChecker.currentVersion,
                        newVersion: updateChecker.appStoreVersion,
                        onUpdate: { updateChecker.openAppStore() },
                        onDismiss: { updateChecker.updateAvailable = false }
                    )
                    .presentationDetents([.height(340)])
                    .presentationDragIndicator(.visible)
                }
                .onOpenURL { url in
                    // 1. Handle Spotify callback
                    if url.scheme == "ones" && url.host == "spotify-callback" {
                        SpotifyManager.shared.handleCallback(url: url)
                    }
                    // 2. Handle Friend Invitation Deep Links
                    // expected format: ones://add-friend?code=ABC123
                    else if url.scheme == "ones" && url.host == "add-friend" {
                        if let components = URLComponents(url: url, resolvingAgainstBaseURL: true),
                           let queryItems = components.queryItems,
                           let codeItem = queryItems.first(where: { $0.name == "code" }),
                           let code = codeItem.value {

                            let uppercased = code.uppercased()
                            guard uppercased.count == 6,
                                  uppercased.allSatisfy({ $0.isLetter || $0.isNumber }) else {
                                ONELogger.warning("Received invitation deep link with invalid code format", category: .circle)
                                return
                            }

                            ONELogger.info("Received valid invitation deep link", category: .circle)
                            handleInviteCode(uppercased)
                        }
                    }
                }
                .onContinueUserActivity(NSUserActivityTypeBrowsingWeb) { userActivity in
                    guard let url = userActivity.webpageURL else { return }
                    // Desteklenen domainler: one.forvibe.app ve onedaily.app (eski)
                    // Beklenen format: https://one.forvibe.app/invite?code=ABC123
                    if url.path == "/invite" || url.path.hasPrefix("/invite"),
                       let components = URLComponents(url: url, resolvingAgainstBaseURL: true),
                       let queryItems = components.queryItems,
                       let codeItem = queryItems.first(where: { $0.name == "code" }),
                       let code = codeItem.value {

                        let uppercased = code.uppercased()
                        guard uppercased.count == 6,
                              uppercased.allSatisfy({ $0.isLetter || $0.isNumber }) else {
                            ONELogger.warning("Received universal link with invalid code format", category: .circle)
                            return
                        }

                        ONELogger.info("Received valid invitation universal link", category: .circle)
                        handleInviteCode(uppercased)
                    }
                }
                .onChange(of: cloudKitManager.currentUser?.recordID.recordName) { _, newValue in
                    if let userID = newValue {
                        AppAnalytics.shared.identify(userID: userID)
                        CrashReporter.shared.setUser(id: userID)
                        cloudKitManager.registerAllSubscriptions()
                        // Fire any deep link that arrived before currentUser was ready
                        if let code = pendingDeepLinkCode {
                            pendingDeepLinkCode = nil
                            ONELogger.info("Firing pending deep link code after user loaded", category: .circle)
                            NotificationCenter.default.post(
                                name: NSNotification.Name("HandleAddFriendDeepLink"),
                                object: nil,
                                userInfo: ["code": code]
                            )
                        }
                    }
                }
        }
    }
    
    private func handleInviteCode(_ code: String) {
        if cloudKitManager.currentUser != nil {
            NotificationCenter.default.post(
                name: NSNotification.Name("HandleAddFriendDeepLink"),
                object: nil,
                userInfo: ["code": code]
            )
        } else {
            // currentUser not ready yet — store and fire once it loads
            ONELogger.warning("currentUser nil, storing pending deep link code", category: .circle)
            pendingDeepLinkCode = code
        }
    }

    private func setupPushNotifications() {
        NotificationManager.shared.requestAuthorization { granted in
            if granted {
                ONELogger.success("Notification permission granted", category: .notification)
            }
        }

        // Dönen kullanıcı için immediate kayıt.
        // İlk yüklemede currentUser henüz nil; .onChange(of: currentUser) bu durumu yakalar.
        if cloudKitManager.currentUser != nil {
            cloudKitManager.registerAllSubscriptions()
        }
    }
}
