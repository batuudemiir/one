import SwiftUI
import Combine
import CloudKit
import CoreData

struct ContentView: View {
    @State private var isActive = false
    @State private var hasCompletedOnboarding = KeychainHelper.bool(forKey: "hasCompletedOnboarding")
    @State private var showProfileSetup = false
    @StateObject private var cloudKitManager = CloudKitManager.shared
    /// Number of times we've retried loading the user with no result and no error.
    /// Profile setup is only shown after exhausting all retries.
    @State private var userCheckRetryCount = 0
    private let maxUserCheckRetries = 3
    @State private var showWhatsNew = false
    
    var body: some View {
        ZStack {
            if !hasCompletedOnboarding {
                // First time user - show onboarding
                OnboardingView(isCompleted: $hasCompletedOnboarding)
            } else if isActive {
                // Main app — aşağıdan yukarı gelir, splash'in üzerine oturur
                ONEColorPickerView()
                    .transition(.asymmetric(
                        insertion: .move(edge: .bottom).combined(with: .opacity),
                        removal: .opacity
                    ))
            } else {
                // Splash screen — kapanırken scale küçülür ve solar
                SplashScreen(isActive: $isActive)
                    .transition(.asymmetric(
                        insertion: .opacity,
                        removal: .scale(scale: 0.94).combined(with: .opacity)
                    ))
            }
        }
        .animation(ONEAnimation.screenTransition, value: isActive)
        .overlay {
            if hasCompletedOnboarding && cloudKitManager.userLoadFailed && !cloudKitManager.isFetchingUser && cloudKitManager.currentUser == nil {
                CloudKitRetryOverlay {
                    cloudKitManager.loadCurrentUser()
                }
            }
        }
        .overlay { ONEToastOverlay() }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("resetToOnboarding"))) { _ in
            withAnimation(ONEAnimation.screenTransition) {
                isActive = false
                hasCompletedOnboarding = false
            }
        }
        .sheet(isPresented: $showProfileSetup) {
            ProfileView()
                .interactiveDismissDisabled(true) // Prevent dismissing without saving
        }
        .onChange(of: hasCompletedOnboarding) { _, completed in
            if completed {
                ONELogger.debug("Onboarding completed, checking profile status", category: .general)
                checkProfileStatus()
            }
        }
        // İlk kayıttan sonra profil formunu aç. `checkProfileStatus` kendi
        // içinde "kayıt var mı" kontrolü yaptığı için mevcut kullanıcılarda
        // bu bildirim zararsız bir tekrar kontrolünden ibaret.
        .onReceive(NotificationCenter.default.publisher(for: .init("todaySongSaved"))) { _ in
            checkProfileStatus()
        }
        .onChange(of: isActive) { _, active in
            if active {
                ONELogger.debug("App became active, checking profile status", category: .general)
                checkProfileStatus()
                // Onboarding tamamlanmadan asla — savunma katmanı.
                // `isActive` yalnız onboarding'den sonra true olabiliyor
                // ama bu koşul o varsayımı koda bağlıyor.
                if hasCompletedOnboarding && WhatsNewManager.shared.shouldShow {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                        showWhatsNew = true
                    }
                }
            }
        }
        .sheet(isPresented: $showWhatsNew) {
            WhatsNewView {
                showWhatsNew = false
                WhatsNewManager.shared.markSeen()
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.hidden)
        }
        .onChange(of: cloudKitManager.currentUser) { _, newUser in
            if newUser != nil && !KeychainHelper.bool(forKey: "hasCreatedProfile") {
                ONELogger.success("currentUser appeared, setting hasCreatedProfile flag", category: .general)
                KeychainHelper.set(true, forKey: "hasCreatedProfile")
                userCheckRetryCount = 0
                showProfileSetup = false
            }
        }
        .onChange(of: cloudKitManager.isFetchingUser) { _, isFetching in
            if !isFetching && !KeychainHelper.bool(forKey: "hasCreatedProfile") {
                if cloudKitManager.userLoadFailed {
                    ONELogger.warning("finished fetching with error, not showing profile setup", category: .general)
                } else if let user = cloudKitManager.currentUser {
                    ONELogger.success("finished fetching, found user \(user["userID"] as? String ?? ""), setting flag", category: .general)
                    KeychainHelper.set(true, forKey: "hasCreatedProfile")
                    userCheckRetryCount = 0
                } else {
                    // No user found — retry a few times before concluding this is a new user
                    userCheckRetryCount += 1
                    if userCheckRetryCount < maxUserCheckRetries {
                        ONELogger.warning("no user found (attempt \(userCheckRetryCount)/\(maxUserCheckRetries)), retrying...", category: .general)
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                            cloudKitManager.loadCurrentUser()
                        }
                    } else {
                        ONELogger.warning("no user found after \(maxUserCheckRetries) attempts, showing profile setup", category: .general)
                        showProfileSetup = true
                    }
                }
            }
        }
        .onAppear {
            // Live Activity — süresi dolmuş activity'leri temizle
            if #available(iOS 16.1, *) {
                Task { await LiveActivityManager.shared.cleanupExpiredActivities() }
            }

            // One-time migration: move hasCompletedOnboarding from UserDefaults → Keychain
            if UserDefaults.standard.bool(forKey: "hasCompletedOnboarding") && !KeychainHelper.bool(forKey: "hasCompletedOnboarding") {
                KeychainHelper.set(true, forKey: "hasCompletedOnboarding")
                UserDefaults.standard.removeObject(forKey: "hasCompletedOnboarding")
                hasCompletedOnboarding = true
                ONELogger.info("Migrated hasCompletedOnboarding to Keychain", category: .general)
            }
            // One-time migration: move hasCreatedProfile from UserDefaults → Keychain
            if UserDefaults.standard.bool(forKey: "hasCreatedProfile") && !KeychainHelper.bool(forKey: "hasCreatedProfile") {
                KeychainHelper.set(true, forKey: "hasCreatedProfile")
                UserDefaults.standard.removeObject(forKey: "hasCreatedProfile")
                ONELogger.info("Migrated hasCreatedProfile to Keychain", category: .general)
            }

            ONELogger.debug("ContentView appeared", category: .general)
            ONELogger.debug("hasCompletedOnboarding: \(hasCompletedOnboarding)", category: .general)
            ONELogger.debug("hasCreatedProfile: \(KeychainHelper.bool(forKey: "hasCreatedProfile"))", category: .general)
            ONELogger.debug("currentUser exists: \(cloudKitManager.currentUser != nil)", category: .general)
            ONELogger.debug("isFetchingUser: \(cloudKitManager.isFetchingUser)", category: .general)
            
            if hasCompletedOnboarding {
                checkProfileStatus()
            }
        }
    }
    
    /// Kullanıcı hiç kayıt yapmadan profil formu göstermeyi engeller.
    ///
    /// Faz 4: form eskiden onboarding biter bitmez, `interactiveDismissDisabled`
    /// ile çıkıyordu — ilk 60 saniyedeki en büyük friction ve kullanıcı henüz
    /// uygulamanın ne işe yaradığını görmemişken. Form silinemez (CloudKit
    /// profili olmadan Çevre çalışmaz), ama ilk kayda kadar bekleyebilir.
    private var hasAnyEntry: Bool {
        let request = DailySong.fetchRequest()
        request.fetchLimit = 1
        let count = (try? PersistenceController.shared.container.viewContext.count(for: request)) ?? 0
        return count > 0
    }

    private func checkProfileStatus() {
        // Keychain is the source of truth — survives app deletion and reinstall
        let hasCreatedProfile = KeychainHelper.bool(forKey: "hasCreatedProfile")

        // Değeri gördükten sonra sor. `todaySongSaved` bildirimi ilk kayıttan
        // sonra bu kontrolü yeniden tetikliyor.
        guard hasCreatedProfile || hasAnyEntry else {
            ONELogger.debug("Henüz kayıt yok — profil formu erteleniyor", category: .general)
            return
        }

        ONELogger.debug("Checking profile status:", category: .general)
        ONELogger.debug("hasCreatedProfile flag: \(hasCreatedProfile)", category: .general)
        ONELogger.debug("currentUser exists: \(cloudKitManager.currentUser != nil)", category: .general)

        if hasCreatedProfile {
            // Profile already created, no need to show setup
            ONELogger.success("Profile already created (flag is set)", category: .general)

            // If flag is set but currentUser is nil, try to load it
            if cloudKitManager.currentUser == nil && !cloudKitManager.isFetchingUser {
                ONELogger.warning("Flag is set but currentUser is nil, loading from CloudKit...", category: .general)
                cloudKitManager.loadCurrentUser()
            }
            return
        }

        // No profile flag, check if user exists in CloudKit
        ONELogger.warning("No profile flag, checking CloudKit...", category: .general)

        if cloudKitManager.currentUser != nil {
            // User exists in CloudKit but flag not set - fix the flag
            ONELogger.success("Found user in CloudKit, setting flag", category: .general)
            KeychainHelper.set(true, forKey: "hasCreatedProfile")
        } else {
            // Wait for CloudKit to finish fetching, then check again
            if cloudKitManager.isFetchingUser {
                ONELogger.debug("CloudKit is currently fetching user, waiting...", category: .general)
                // We will handle the result when isFetchingUser changes via the onChange below
            } else if cloudKitManager.userLoadFailed {
                // Load errored (throttle/network) — do not show profile setup
                ONELogger.warning("CloudKit load failed, not showing profile setup", category: .general)
            } else {
                // Not fetching, no error, no user — trigger a load; count tracked in onChange(of: isFetchingUser)
                if userCheckRetryCount < maxUserCheckRetries {
                    ONELogger.warning("no user found, triggering CloudKit load...", category: .general)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                        cloudKitManager.loadCurrentUser()
                    }
                } else {
                    ONELogger.warning("no user found after \(maxUserCheckRetries) attempts, showing profile setup", category: .general)
                    self.showProfileSetup = true
                }
            }
        }
    }
}

private struct CloudKitRetryOverlay: View {
    let onRetry: () -> Void
    @ObservedObject private var cloudKit = CloudKitManager.shared
    @State private var now = Date()
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var secondsLeft: Int {
        guard let retryAfter = cloudKit.throttleRetryAfter else { return 0 }
        return max(0, Int(retryAfter.timeIntervalSince(now)))
    }

    private var message: String {
        if secondsLeft > 0 {
            let mins = secondsLeft / 60
            let secs = secondsLeft % 60
            return String(format: NSLocalizedString("cloudkit.throttleWait", comment: ""), mins, secs)
        }
        return NSLocalizedString("cloudkit.connectionError", comment: "")
    }

    var body: some View {
        ZStack {
            Color(UIColor.systemBackground).ignoresSafeArea()
            ONEErrorView(
                message: message,
                onRetry: secondsLeft == 0 ? onRetry : nil
            )
        }
        .onReceive(timer) { t in
            now = t
            // Auto-retry once throttle window expires
            if secondsLeft == 0 && cloudKit.userLoadFailed {
                onRetry()
            }
        }
    }
}

#Preview {
    ContentView()
}
