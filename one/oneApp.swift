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
        let acceptAction = UNNotificationAction(
            identifier: "ACCEPT_FRIEND",
            title: "Kabul Et",
            options: [.foreground]
        )
        
        let declineAction = UNNotificationAction(
            identifier: "DECLINE_FRIEND",
            title: "Reddet",
            options: [.destructive]
        )
        
        let friendRequestCategory = UNNotificationCategory(
            identifier: "FRIEND_REQUEST",
            actions: [acceptAction, declineAction],
            intentIdentifiers: [],
            options: []
        )
        
        UNUserNotificationCenter.current().setNotificationCategories([friendRequestCategory])
    }
}

@main
struct oneApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    let persistenceController = PersistenceController.shared
    @StateObject private var cloudKitManager = CloudKitManager.shared
    
    init() {
        // Register background task for midnight reset
        MidnightResetManager.shared.registerBackgroundTask()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
                .onAppear {
                    // Check CloudKit availability on app launch
                    cloudKitManager.checkCloudKitAvailability()
                    
                    // Schedule midnight reset
                    MidnightResetManager.shared.scheduleMidnightReset()
                    
                    // Request notification permission & register CloudKit subscription
                    setupPushNotifications()
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

                            NotificationCenter.default.post(
                                name: NSNotification.Name("HandleAddFriendDeepLink"),
                                object: nil,
                                userInfo: ["code": uppercased]
                            )
                        }
                    }
                }
                .onContinueUserActivity(NSUserActivityTypeBrowsingWeb) { userActivity in
                    guard let url = userActivity.webpageURL else { return }
                    // expected format: https://onedaily.app/invite?code=ABC123
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

                        NotificationCenter.default.post(
                            name: NSNotification.Name("HandleAddFriendDeepLink"),
                            object: nil,
                            userInfo: ["code": uppercased]
                        )
                    }
                }
                .onChange(of: cloudKitManager.currentUser?.recordID.recordName) { _, newValue in
                    if newValue != nil {
                        cloudKitManager.registerFriendRequestSubscription()
                    }
                }
        }
    }
    
    private func setupPushNotifications() {
        NotificationManager.shared.requestAuthorization { granted in
            if granted {
                ONELogger.success("Notification permission granted", category: .notification)
            }
        }
        
        // Subscription will be registered via onChange(of: cloudKitManager.currentUser)
        if cloudKitManager.currentUser != nil {
            cloudKitManager.registerFriendRequestSubscription()
        }
    }
}
