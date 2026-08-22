//
//  oneApp.swift
//  one
//
//  Created by Batu Demir on 23.02.2026.
//

import SwiftUI
import UIKit
import CoreData
import CloudKit
import UserNotifications
import MetricKit
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

        // Notification kategorileri artık Tier 3'te kuruluyor (oneApp.body .onAppear).
        // Kategoriler yalnız bildirim teslim anında lazım; launch'ı 7 kategori × 6 aksiyon
        // bekletmiyor.

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
    
    fileprivate func setupNotificationCategories() {
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

        // Arkadaş paylaşımı — Çevre'ye yönlendirir.
        //
        // Eskiden buradaki aksiyon "Keşfet"ti ve Discovery'ye gidiyordu;
        // Keşfet kaldırıldı, üstelik arkadaşın paylaşımının doğal hedefi
        // zaten Çevre.
        let openSharedCircleAction = UNNotificationAction(
            identifier: "OPEN_CIRCLE",
            title: NSLocalizedString("notification.openCircle", comment: ""),
            options: [.foreground]
        )
        let friendSharedCategory = UNNotificationCategory(
            identifier: "FRIEND_SHARED",
            actions: [openSharedCircleAction],
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

        let appUpdateCategory = UNNotificationCategory(
            identifier: "APP_UPDATE",
            actions: [],
            intentIdentifiers: [],
            options: []
        )

        // Yorum sistemi kaldırıldı (efemer karşılığa geçildi) — yorum
        // bildirim kategorisi ve inline yanıt aksiyonu yok.

        UNUserNotificationCenter.current().setNotificationCategories([
            friendRequestCategory,
            weeklySummaryCategory,
            friendSharedCategory,
            moodResonanceCategory,
            appUpdateCategory
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
    @AppStorage("isDarkMode") private var isDarkMode = false
    /// Uygulama kilidi perdesi — Profil'deki anahtar bunu besliyor.
    @StateObject private var appLock = AppLockManager.shared
    @Environment(\.scenePhase) private var scenePhase
    /// Invite code from a deep link that arrived before currentUser was loaded.
    @State private var pendingDeepLinkCode: String? = nil

    init() {
        // 3-tier launch contract: this init is Tier 0. Bütçe: <80ms toplam
        // (main thread'de senkron her şey). Ağır iş için:
        //   • Tier 1 — .onAppear ilk tick (kısa, ana thread OK)
        //   • Tier 2 — Task.detached(.userInitiated) (splash boyunca ok)
        //   • Tier 3 — Task.detached(.background) (retention-critical değil)
        // Yeni iş bunlardan birine gitmeli; ASLA init'e.
        ONELaunchSignpost.begin("appInit")
        let __initT0 = CFAbsoluteTimeGetCurrent()
        defer {
            let elapsed = CFAbsoluteTimeGetCurrent() - __initT0
            ONELaunchSignpost.end("appInit")
            assert(elapsed < 0.08, "oneApp.init > 80ms (\(Int(elapsed * 1000))ms) — moved work back to sync path?")
        }

        // One-time migration: notificationsEnabled was written to UserDefaults.standard
        // but NotificationOrchestrator reads from the App Group container. Sync once.
        //
        // v2 — v1 bu değeri `bool(forKey:)` ile okuyordu: hiç dokunulmamış ayar
        // için `false` dönüyor ve bu `false` app group'a **açıkça** yazılıyordu.
        // Böylece `oneNotificationsEnabled`'ın "yazılmamışsa açık" varsayılanı
        // devreye giremiyor, kullanıcı hiçbir zaman kapatmadığı halde her kind
        // "master off" ile düşüyordu. Yalnız açıkça yazılmış değeri taşı;
        // yoksa app group'taki anahtarı temizle ki varsayılan geçerli olsun.
        let migrationKey = "notificationsEnabled_appGroupMigrated_v2"
        if !UserDefaults.standard.bool(forKey: migrationKey) {
            let appGroup = UserDefaults(suiteName: "group.com.batudemir.ones") ?? .standard
            if let explicit = UserDefaults.standard.object(forKey: "notificationsEnabled") as? Bool {
                appGroup.set(explicit, forKey: "notificationsEnabled")
            } else {
                appGroup.removeObject(forKey: "notificationsEnabled")
            }
            UserDefaults.standard.set(true, forKey: migrationKey)
        }

        // Register background task for midnight reset
        MidnightResetManager.shared.registerBackgroundTask()

        // Observability bootstrap.
        // DEBUG: console logger init'te (ucuz, senkron)
        // RELEASE: PostHog Tier 3'e ertelendi — SDK setup dosya I/O + session
        // bootstrap yapıyor, main thread'i splash boyunca bloke ediyordu.
        #if DEBUG
        AppAnalytics.shared.register(ConsoleAnalyticsService())
        #endif

        Experiment.assign()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(languageManager)
                // Rebuild the entire SwiftUI tree when the language changes
                .id(languageManager.refreshToken)
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
                .preferredColorScheme(isDarkMode ? .dark : .light)
                // Uygulama kilidi — perde her şeyin üstünde, dil değişiminin
                // `.id()` yeniden kurmasından da etkilenmesin diye en dışta.
                .overlay {
                    if appLock.isLocked {
                        AppLockView()
                            .transition(.opacity)
                    }
                }
                .animation(.easeOut(duration: 0.18), value: appLock.isLocked)
                .onChange(of: scenePhase) { _, phase in
                    switch phase {
                    case .active:      appLock.handleDidBecomeActive()
                    case .inactive:    appLock.handleWillResignActive()
                    case .background:  appLock.handleWillResignActive()
                    @unknown default:  break
                    }
                }
                .onAppear {
                    // Cold start: kilit açıksa içerik hiç görünmeden kapansın.
                    appLock.handleLaunch()
                    // Faz 3.5 (2026-04-26) — cold start optimizasyonu:
                    // .onAppear ana thread'i bloke etmemeli. Tüm ağır init işleri
                    // Task'e taşındı; ilk frame splash'ten kullanıcı içeriğine kesintisiz
                    // geçer, retention-kritik işler arka planda akar.

                    // Tier 1 — anında, ucuz, UI'a senkronize
                    if #available(iOS 16.1, *) {
                        Task { await LiveActivityManager.shared.endAllActivities() }
                    }

                    // Tier 2 — bir tick gecikmeli (ilk frame paint olduktan sonra)
                    Task.detached(priority: .userInitiated) {
                        ONELaunchSignpost.begin("tier2")
                        await MainActor.run {
                            cloudKitManager.checkCloudKitAvailability()
                            MidnightResetManager.shared.scheduleMidnightReset()
                            setupPushNotifications()
                        }
                        ONELaunchSignpost.end("tier2")
                    }

                    // Tier 3 — bekleyebilir (engagement, telemetri, network)
                    Task.detached(priority: .background) {
                        ONELaunchSignpost.begin("tier3")
                        // PostHog setup burada — SDK dosya I/O yapıyor, main'e
                        // gerek yok. RELEASE-only.
                        #if !DEBUG
                        #if canImport(PostHog)
                        ONELaunchSignpost.begin("posthogSetup")
                        AppAnalytics.shared.register(
                            PostHogAnalyticsService(apiKey: "phc_ndwqbiAtRrioGLUmaAhBfvYgUQXZtZUSy8PNuJQRFH6H")
                        )
                        ONELaunchSignpost.end("posthogSetup")
                        #endif
                        #endif

                        await MainActor.run {
                            appDelegate.setupNotificationCategories()
                            NotificationOrchestrator.shared.bootOnLaunch()
                            NotificationOrchestrator.shared.onAppOpened()
                            // v3 daily reminder — cold start'ta yeniden planla.
                            // scheduleSmartDailyReminder ile aynı andaydılar; v3
                            // rescheduler eski daily'yi kendisi iptal ediyor.
                            V3ReminderScheduler.reschedule()
                            NotificationManager.shared.scheduleMonthEndNotification()
                            updateChecker.check()
                            // Prod launch histogram telemetry — iOS payload'ı
                            // günde ~1 kez teslim eder; register bir sonraki
                            // teslim penceresini yakalar.
                            MXMetricManager.shared.add(LaunchMetricsCollector.shared)
                        }
                        ONELaunchSignpost.end("tier3")
                    }
                }
                .onOpenURL { url in
                    // Cold-start flicker fix: resolve the URL into a tab
                    // intent BEFORE the shell mounts. `ONEColorPickerView`
                    // reads `LaunchIntent.shared.pendingTab` at first mount
                    // (and observes `.launchIntentUpdated` for mid-splash
                    // deliveries), so the tab is set before the splash fades.
                    // Unknown / malformed URLs fall through silently — user
                    // lands on the default tab.
                    ONELaunchSignpost.begin("deeplink.resolve.url")
                    defer { ONELaunchSignpost.end("deeplink.resolve.url") }

                    // 1. Handle Spotify callback (no tab intent — auth only)
                    if url.scheme == "ones" && url.host == "spotify-callback" {
                        SpotifyManager.shared.handleCallback(url: url)
                    }
                    // 2. Widget / kilit ekranı deep link: ones://today
                    // Ritual entry lives inside the Circle tab (the "+" FAB
                    // presents it), so route to Circle AND fire the picker
                    // notification. Setting the tab first prevents the
                    // shell from briefly rendering the experiment default.
                    else if url.scheme == "ones" && url.host == "today" {
                        ONELogger.info("Received widget deep link: today", category: .general)
                        LaunchIntent.shared.setPendingTab(.circle)
                        LaunchIntent.shared.setPendingMoodPickerRequest()
                    }
                    // 3. Handle Friend Invitation Deep Links
                    // expected format: ones://add-friend?code=ABC123
                    else if url.scheme == "ones" && url.host == "add-friend" {
                        if let components = URLComponents(url: url, resolvingAgainstBaseURL: true),
                           let queryItems = components.queryItems,
                           let codeItem = queryItems.first(where: { $0.name == "code" }),
                           let code = codeItem.value {

                            let uppercased = code.uppercased()
                            guard uppercased.count == 6,
                                  uppercased.allSatisfy({ $0.isASCII && ($0.isLetter || $0.isNumber) }) else {
                                ONELogger.warning("Received invitation deep link with invalid code format", category: .circle)
                                return
                            }

                            ONELogger.info("Received valid invitation deep link", category: .circle)
                            // Land on Circle — the invite acceptance UI is
                            // hosted there. Prevents landing on Archive/Echo
                            // then jumping to Circle when the sheet appears.
                            LaunchIntent.shared.setPendingTab(.circle)
                            handleInviteCode(uppercased)
                        }
                    }
                    // 4. Direct tab deep links: ones://circle · ones://archive
                    // · ones://echo · ones://profile
                    // Added for parity so any external surface (share
                    // extension, notification, widget variant) can route
                    // straight to a tab without a NotificationCenter round-trip.
                    else if url.scheme == "ones", let host = url.host {
                        switch host {
                        case "entry":    LaunchIntent.shared.setPendingTab(.entry)
                        case "circle":   LaunchIntent.shared.setPendingTab(.circle)
                        case "archive":  LaunchIntent.shared.setPendingTab(.archive)
                        // Yankı artık sekme değil — layer route olarak açılıyor.
                        case "echo":     LaunchIntent.shared.setPendingScreen(.echo)
                        case "profile":  LaunchIntent.shared.setPendingTab(.profile)
                        default:
                            ONELogger.warning("Unknown deep link host: \(host)", category: .general)
                        }
                    } else {
                        ONELogger.warning("Unhandled deep link: \(url.absoluteString)", category: .general)
                    }
                }
                .onContinueUserActivity(NSUserActivityTypeBrowsingWeb) { userActivity in
                    guard let url = userActivity.webpageURL else { return }
                    ONELaunchSignpost.begin("deeplink.resolve.activity")
                    defer { ONELaunchSignpost.end("deeplink.resolve.activity") }

                    // In-App Event universal link: https://one.forvibe.app/event/mood
                    // Mood seçim ekranı (ONEColorPickerView) zaten splash sonrası
                    // ana ekran; burada sadece olası modal/sheet'leri kapatıp
                    // kullanıcıyı picker'a getirmek için bildirim yayınlanır.
                    if url.path.hasPrefix("/event/mood") {
                        ONELogger.info("Received in-app event universal link: mood", category: .general)
                        LaunchIntent.shared.setPendingTab(.circle)
                        LaunchIntent.shared.setPendingMoodPickerRequest()
                        return
                    }

                    // Desteklenen domainler: one.forvibe.app ve onedaily.app (eski)
                    // Beklenen format: https://one.forvibe.app/invite?code=ABC123
                    if url.path == "/invite" || url.path.hasPrefix("/invite"),
                       let components = URLComponents(url: url, resolvingAgainstBaseURL: true),
                       let queryItems = components.queryItems,
                       let codeItem = queryItems.first(where: { $0.name == "code" }),
                       let code = codeItem.value {

                        let uppercased = code.uppercased()
                        guard uppercased.count == 6,
                              uppercased.allSatisfy({ $0.isASCII && ($0.isLetter || $0.isNumber) }) else {
                            ONELogger.warning("Received universal link with invalid code format", category: .circle)
                            return
                        }

                        ONELogger.info("Received valid invitation universal link", category: .circle)
                        LaunchIntent.shared.setPendingTab(.circle)
                        handleInviteCode(uppercased)
                    }
                }
                .onChange(of: cloudKitManager.currentUser?.recordID.recordName) { _, newValue in
                    if let userID = newValue {
                        AppAnalytics.shared.identify(
                            userID: userID,
                            properties: Experiment.analyticsProperties
                        )
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

    /// Cold start'ta **izin İSTEMEZ.** Eskiden burada koşulsuz bir
    /// `requestAuthorization` vardı; sistem prompt'u kullanıcı daha Welcome
    /// ekranındayken, uygulamanın ne olduğunu bilmeden çıkıyordu — reddetme
    /// oranının en yüksek olduğu an. Dahası izin `.notDetermined` olmaktan
    /// çıktığı için onboarding'in soft-ask adımı ve `TodayCompletedView`
    /// soft-ask banner'ı ikisi de sessizce ölüyordu.
    ///
    /// İzin isteme yetkisi artık yalnız iki yerde: onboarding `notifSoftAsk`
    /// adımı ve tamamlandı ekranındaki soft-ask banner'ı. Burada sadece
    /// izin gerektirmeyen abonelik kaydı kalır.
    private func setupPushNotifications() {
        // Dönen kullanıcı için immediate kayıt.
        // İlk yüklemede currentUser henüz nil; .onChange(of: currentUser) bu durumu yakalar.
        if cloudKitManager.currentUser != nil {
            cloudKitManager.registerAllSubscriptions()
        }
    }
}
