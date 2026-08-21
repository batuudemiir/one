import SwiftUI
import Combine
import CloudKit
import CoreData

struct ContentView: View {
    @State private var isActive = false
    @State private var hasCompletedOnboarding = KeychainHelper.completionFlag(forKey: "hasCompletedOnboarding")
    @State private var showProfileSetup = false
    @StateObject private var cloudKitManager = CloudKitManager.shared
    @StateObject private var persistence = PersistenceController.shared
    @StateObject private var appleSignIn = AppleSignInService.shared
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// Shared namespace so the splash wordmark can hand off to a top-of-shell
    /// anchor in a single motion instead of "fade out, then slide in".
    @Namespace private var splashHandoffNS
    /// Number of times we've retried loading the user with no result and no error.
    /// Profile setup is only shown after exhausting all retries.
    @State private var userCheckRetryCount = 0
    private let maxUserCheckRetries = 3
    @State private var showWhatsNew = false
    /// Kicked to true once the launch-critical work overlapping the splash is
    /// done (CloudKit user resolved, or we've decided it's a fresh install).
    /// SplashScreen reads this to dismiss the moment it's safe — it won't
    /// dismiss before its own minimum animation hold.
    @State private var launchReady = false
    /// Guards `ONELaunchSignpost.begin/end("cloudkit.userFetch")` pairing so
    /// end fires exactly once (and only if begin fired) across all callsites.
    @State private var cloudKitFetchSignpostActive = false

    /// Splash yalnız **CoreData** hazır olana kadar duruyor.
    ///
    /// Eskiden `launchReady`'i de bekliyordu, yani CloudKit'ten kullanıcı
    /// kaydı gelene kadar (ya da 1.2s'lik emniyet süresi dolana kadar).
    /// Bu bekleme görsel olarak hiçbir şey kazandırmıyordu: kabuk zaten
    /// `persistence.isReady` ile splash'in altında kurulmuş ve çizilmiş
    /// oluyor. Kullanıcı kor ekrana bakarken beklenen şey ağdı.
    ///
    /// CloudKit kaydı gelmeden kabuğa girmek güvenli, çünkü ona ihtiyaç
    /// duyan tek yüzey Çevre ve orası kendi durumlarını yönetiyor: elde
    /// bugüne ait önbellek varsa anında çiziyor, yoksa skeleton gösteriyor.
    /// Profil kurulum sayfası da zaten `isFetchingUser` üzerinden bağımsız
    /// karar veriyor — splash'i beklemesi hiç gerekmiyordu.
    ///
    /// `launchReady` duruyor: hâlâ set ediliyor ve launch signpost'larını
    /// besliyor, sadece artık splash'i geciktirmiyor.
    ///
    /// Koşul `persistence.isReady` değil `shellDidMount`: ikisi aynı kareye
    /// denk gelirse kabuğun kurulumu ile splash'in sönmesi çakışır ve geçiş
    /// tam da en pahalı işin üstüne biner. Kabuk kendi `onAppear`'ını
    /// bildirdiğinde ilk layout bitmiş oluyor — sahnede yalnızca iki opaklık
    /// kalıyor.
    private var effectiveAppReady: Bool {
        shellDidMount
    }

    /// Kabuk en az bir kez çizildi mi.
    @State private var shellDidMount = false
    
    var body: some View {
        ZStack {
            if !hasCompletedOnboarding {
                // v3 onboarding — 7 adımlı (intent · auth · mood · song ·
                // reward · çevre · notif). Apple sign-in adım 2 olarak
                // akışın içinde.
                V3OnboardingView(isCompleted: $hasCompletedOnboarding)
            } else if appleSignIn.status != .signedIn {
                // Onboarding tamamlanmış ama Apple kimliği artık geçersiz
                // (revoked / notFound). Gate yalnız bu durumda çıkar.
                AppleSignInGateView()
                    .transition(.opacity)
            } else {
                // Kabuk artık CoreData hazır olur olmaz mount ediliyor —
                // `effectiveAppReady`'i (CloudKit dahil) beklemiyor.
                //
                // Eskiden ikisi aynı ana denk geliyordu: splash sönmeye
                // başladığı kare, kabuk ilk kez kuruluyor ve `.task`'ları
                // ateşliyordu. Crossfade'in en pahalı iş ile çakışması
                // "kasarak giriyor" hissinin ana kaynağıydı. Şimdi kurulum
                // splash'in altında, görünmeden oluyor; geçiş anında sahnede
                // yalnızca iki opaklık kalıyor.
                //
                // Splash'in kapanma kararı hâlâ `effectiveAppReady`'de —
                // erken mount, erken kapanma demek değil.
                if persistence.isReady {
                    ONEColorPickerView(splashHandoffNS: splashHandoffNS)
                        .opacity(isActive ? 1 : 0)
                        // Kabuk 0.99'dan açılıyor: splash kalkarken uygulama
                        // "yerine oturuyor" hissi. 0.985 fazla yumuşaktı ve
                        // spring ile birleşince salınım gibi okunuyordu.
                        .scaleEffect(isActive ? 1 : (reduceMotion ? 1 : 0.99))
                        // Splash'in kapanma izni buradan geliyor: ilk layout
                        // bittikten sonra.
                        .onAppear { shellDidMount = true }
                }

                if !isActive {
                    // Splash screen — hands off the wordmark to the main-shell
                    // anchor via `matchedGeometryEffect`. `appReady` gates the
                    // dismiss so CloudKit user fetch overlaps the animation.
                    SplashScreen(
                        isActive: $isActive,
                        appReady: effectiveAppReady,
                        handoffNamespace: splashHandoffNS
                    )
                    .transition(.opacity)
                    .zIndex(1)
                }
            }
        }
        // Geçişin tek sahibi burası. Splash artık kendi outro'sunu yapmıyor —
        // spring yerine v3'ün tek easing eğrisi kullanılıyor; yay sönümü
        // opaklıkta "sünme" yaratıyordu.
        .animation(reduceMotion
                   ? .easeInOut(duration: 0.18)
                   : .timingCurve(0.2, 0.9, 0.25, 1.0, duration: 0.34),
                   value: isActive)
        .overlay {
            if hasCompletedOnboarding && cloudKitManager.userLoadFailed && !cloudKitManager.isFetchingUser && cloudKitManager.currentUser == nil {
                CloudKitRetryOverlay {
                    cloudKitManager.loadCurrentUser()
                }
            }
        }
        .overlay { ONEToastOverlay() }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("resetToOnboarding"))) { _ in
            // Hesap silme / sıfırlama: Apple kimliğini de düş, kullanıcı
            // yeniden Apple ile giriş yaparak sisteme dönsün.
            appleSignIn.signOut()
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
                // Kabuk hemen mount olsun — CloudKit currentUser henüz yoksa da
                // splash aç, kalan iş arka planda tamamlansın.
                if !launchReady { launchReady = true }
                checkProfileStatus()
            }
        }
        // Cold start'ta `.onAppear`'daki checkProfileStatus, isReady=false iken
        // `hasAnyEntry` false döndüğü için sessizce çıkabiliyor. Store hazır
        // olur olmaz yeniden tetikle — aksi halde ilk yavaş cold start'ta
        // profil formu (hasCreatedProfile=false + kayıt var senaryosu) asla
        // açılmaz.
        .onChange(of: persistence.isReady) { _, ready in
            if ready && hasCompletedOnboarding {
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
            if newUser != nil {
                // Fastest release of the splash gate: the user record landed.
                if !launchReady {
                    if cloudKitFetchSignpostActive {
                        ONELaunchSignpost.end("cloudkit.userFetch")
                        cloudKitFetchSignpostActive = false
                    }
                    launchReady = true
                }
                if !KeychainHelper.completionFlag(forKey: "hasCreatedProfile") {
                    ONELogger.success("currentUser appeared, setting hasCreatedProfile flag", category: .general)
                    KeychainHelper.set(true, forKey: "hasCreatedProfile")
                    userCheckRetryCount = 0
                    showProfileSetup = false
                }
            }
        }
        .onChange(of: cloudKitManager.isFetchingUser) { _, isFetching in
            // Definitive outcome — either succeeded, hit an error, or truly no
            // user — is enough to release the splash gate. Don't block launch
            // on retry loops; those can run behind the tab.
            if !isFetching && !launchReady {
                if cloudKitFetchSignpostActive {
                    ONELaunchSignpost.end("cloudkit.userFetch")
                    cloudKitFetchSignpostActive = false
                }
                launchReady = true
            }
            if !isFetching && !KeychainHelper.completionFlag(forKey: "hasCreatedProfile") {
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
            // Apple ID credential state doğrulaması — Keychain'de userID varsa
            // status init'te `.signedIn`, burada async olarak revoked/notFound
            // kontrolü yapıp gerekirse gate'i geri aç.
            appleSignIn.bootstrap()

            // Launch-critical overlap window: kick off CloudKit user resolution
            // DURING the splash instead of after. The splash's `appReady` gate
            // waits on this, so the animation and the fetch race — whichever
            // takes longer wins, and TTI = max(anim, fetch) instead of sum.
            //
            // Skip when onboarding hasn't been completed (no user to fetch yet)
            // or when the flag says we've never created a profile — in those
            // cases we mark ready immediately.
            if hasCompletedOnboarding {
                if KeychainHelper.completionFlag(forKey: "hasCreatedProfile") {
                    ONELaunchSignpost.begin("cloudkit.userFetch")
                    cloudKitFetchSignpostActive = true
                    if cloudKitManager.currentUser != nil {
                        // Already cached from a warm start — nothing to wait on.
                        ONELaunchSignpost.end("cloudkit.userFetch")
                        cloudKitFetchSignpostActive = false
                        launchReady = true
                    } else if !cloudKitManager.isFetchingUser {
                        cloudKitManager.loadCurrentUser()
                    }
                    // Fallback: never let the splash wait more than 1.2s on the
                    // network. Better to show the tab and let it hydrate than
                    // hold a white screen on flaky connectivity.
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                        if !launchReady {
                            ONELaunchSignpost.event("cloudkit.userFetch.timeout")
                            launchReady = true
                        }
                    }
                } else {
                    // Existing user without a profile row (rare) — don't gate.
                    launchReady = true
                }
            }

            // Live Activity — süresi dolmuş activity'leri temizle
            if #available(iOS 16.1, *) {
                Task { await LiveActivityManager.shared.cleanupExpiredActivities() }
            }

            // One-time migration: UserDefaults → Keychain.
            //
            // Yalnız Keychain'de kaydın **kesinlikle olmadığı** durumda taşı.
            // Eskiden `!KeychainHelper.bool(...)` kontrol ediliyordu; kilitli
            // cihazda okuma başarısız olunca bu da `true` oluyor, migration
            // koşuyor, Keychain yazımı da başarısız olabiliyor ve UserDefaults
            // kaydı yine de siliniyordu — bayrak iki depodan da kayboluyordu.
            migrateFlagToKeychain("hasCompletedOnboarding") { hasCompletedOnboarding = true }
            migrateFlagToKeychain("hasCreatedProfile")

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
        // Store yüklenmeden count 0 döner. Guard `hasCreatedProfile || hasAnyEntry`
        // false ile early-return alır — kontrol isActive true olduğunda
        // (effectiveAppReady, isReady'yi bekliyor) yeniden tetikleniyor.
        guard persistence.isReady else { return false }
        let request = DailySong.fetchRequest()
        request.fetchLimit = 1
        let count = (try? PersistenceController.shared.container.viewContext.count(for: request)) ?? 0
        return count > 0
    }

    /// UserDefaults'taki eski bayrağı Keychain'e taşır.
    ///
    /// Taşıma yalnız üç koşul birden sağlanınca yapılır: eski kayıt var,
    /// Keychain'de kayıt **kesinlikle** yok (okunamıyor değil), ve yazma
    /// başarılı. Aksi halde eski kayda dokunulmuyor — bir sonraki açılışta
    /// yeniden denenir.
    private func migrateFlagToKeychain(_ key: String, onMigrated: () -> Void = {}) {
        guard UserDefaults.standard.bool(forKey: key) else { return }
        guard case .notFound = KeychainHelper.read(forKey: key) else { return }

        KeychainHelper.set(true, forKey: key)

        // Yazmanın gerçekten tuttuğunu doğrulamadan eski kaydı silme.
        guard case .found = KeychainHelper.read(forKey: key) else {
            ONELogger.warning("Keychain'e taşınamadı, UserDefaults kaydı korunuyor: '\(key)'", category: .general)
            return
        }

        UserDefaults.standard.removeObject(forKey: key)
        onMigrated()
        ONELogger.info("Migrated \(key) to Keychain", category: .general)
    }

    private func checkProfileStatus() {
        // Keychain is the source of truth — survives app deletion and reinstall
        let hasCreatedProfile = KeychainHelper.completionFlag(forKey: "hasCreatedProfile")

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
