//
//  ONEColorPickerView.swift
//  one
//
//  Main application view — routes between screens
//

import SwiftUI
import CoreData

// MARK: - Main Application View
struct ONEColorPickerView: View {
    @StateObject private var vm = ColorPickerViewModel()
    @StateObject private var globalUI = GlobalUIState.shared
    @StateObject private var notificationManager = NotificationManager.shared
    /// DEBUG örnek Çevre verisi. Profil › GELİŞTİRİCİ altındaki anahtar ya da
    /// `-v3.debug.sampleFriends YES` launch argument'ı açar.
    @AppStorage("v3.debug.sampleFriends") private var sampleFriendsEnabled = false
    @Environment(\.managedObjectContext) private var viewContext
    @Namespace private var moodCoreNS
    /// Bugün kartındaki fotoğrafın tam ekrana morph'u için ortak namespace.
    /// Kart (source) ve `PhotoViewerSheet` (destination) environment üzerinden
    /// aynı namespace'i okuyor — böylece `matchedGeometryEffect` çalışıyor.
    @Namespace private var todayPhotoNS
    /// Handoff namespace threaded from ContentView. When splash dismisses,
    /// its wordmark morphs into the top-of-shell anchor rendered inside
    /// `mainTabsView`. Optional so previews / isolated use still compile.
    var splashHandoffNS: Namespace.ID? = nil
    /// Last tab the user was on — used to coerce TabView selection when
    /// `vm.currentScreen` becomes a non-tab screen.
    @State private var lastTab: ScreenType = Experiment.defaultLaunchScreen

    /// Per-scene persisted primary tab. Returning users should land where
    /// they left off, not always on `Experiment.defaultLaunchScreen`.
    /// Stored as `rawValue` of `PrimaryTab` so ritual/mid-flow screens
    /// (`.today`) are structurally unrepresentable
    /// as restore targets — only the four dock tabs round-trip.
    @SceneStorage("one.scene.primaryTab") private var restoredPrimaryTabRaw: String = ""

    /// Guard so restoration runs at most once per scene lifetime.
    @State private var didAttemptRestore = false

    /// Yankı bir sekme değil — Profil/Ayarlar veya bildirimden sheet olarak
    /// açılıyor. `.echo` `PrimaryTab.allCases`'da yok; `currentScreen = .echo`
    /// yaparsak tab bar hiçbir sekmeyi seçili göstermezdi.
    @State private var showingEchoSheet = false

    /// True once any code path has observed (and either consumed or
    /// intentionally acknowledged) a launch intent. Prevents the race
    /// where `.onReceive(.launchIntentUpdated)` consumes an intent
    /// BEFORE `.onAppear` runs — leaving `restoreLastTabIfNeeded()` to
    /// find nothing and fall through to SceneStorage, clobbering the
    /// deep link. The invariant: deep link ALWAYS wins over SceneStorage
    /// regardless of arrival order.
    @State private var didConsumeLaunchIntent = false

    /// Reduce Motion açıksa tab crossfade'ini de kısar (jump-cut'a yakın).
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Sekme çubuğu — tek kaynak `PrimaryTab`. Bugün burada yok ama artık
    /// kabuğun İÇİNDE çiziliyor: dock duruyor, ortadaki "+" onu açıyor.
    /// Kökte yalnız confirm/done tam ekran kalıyor.
    private var primaryTabs: [ScreenType] { PrimaryTab.screens }

    // MARK: - Tab selection

    /// Ziyaret edilmiş sekmeler. `TabView` dört sekmeyi de canlı tutuyor —
    /// istediğimiz de bu — ama cold start'ta dördünü birden kurmak açılışı
    /// yavaşlatırdı (Arşiv 12 aylık Core Data fetch'i, Çevre CloudKit).
    /// Bir sekme ilk kez seçildiğinde bu kümeye girer ve bir daha çıkmaz:
    /// ilk ziyaret maliyeti bir kez ödenir, sonrası ücretsizdir.
    @State private var visitedTabs: Set<PrimaryTab> = []

    /// `TabView(selection:)` `Hashable` bir seçim istiyor ama
    /// `vm.currentScreen` sekme olmayan değerler de alabiliyor
    /// (`.echo` gibi). `PrimaryTab(containing:)` o
    /// eşlemeyi yapıyor; yazma yönünde sekmenin kendi ekranına dönüyoruz.
    ///
    /// Bu köprü sayesinde deep-link ve SceneStorage restorasyonu
    /// (`restoreLastTabIfNeeded` / `applyLaunchIntentIfNeeded`) hâlâ
    /// `vm.currentScreen` üzerinden çalışıyor — hiçbiri değişmedi.
    private var selectedTab: Binding<PrimaryTab> {
        Binding(
            get: { PrimaryTab(containing: vm.currentScreen) },
            set: { tab in
                guard vm.currentScreen != tab.screen else { return }
                vm.currentScreen = tab.screen
            }
        )
    }

    var body: some View {
        ZStack {
            V3Tokens.paper.ignoresSafeArea()

            // Kök yönlendirici. v3'te tek dal var: dört sekmeli kabuk.
            //
            // Eskiden burada `.confirm` / `.done` için iki tam ekran dalı ve
            // onlara özel bir radyal gradyan vardı. `currentScreen` hiçbir
            // yerde `.confirm`'e atanmadığı için o dallar ulaşılamazdı —
            // ekranların kendisiyle birlikte kalktılar.
            mainTabsView
                .transition(.opacity)
            .animation(ONEAnimation.cardSpring, value: vm.currentScreen)
        }
        .onChange(of: vm.currentScreen) { _, screen in
            if primaryTabs.contains(screen) { lastTab = screen }
            if screen != .today {
                // An akışı bir sekmede canlı kalıyor (TabView sekmeleri yok
                // etmiyor), yani `V3EntryContainer.onDisappear`'ın tetiklendiğine
                // güvenemeyiz. Kilit takılı kalırsa kullanıcı hiçbir sekmede
                // swipe yapamaz — sıfırlamayı kabuk garanti ediyor.
                globalUI.tabBarMinimized     = false
                globalUI.entryFlowLocksSwipe = false
            }
            // Persist only safe restore targets (the four dock tabs). Ritual
            // screens (confirm/done/today) intentionally never round-trip —
            // waking up mid-ritual would be disorienting.
            if let tab = PrimaryTab.allCases.first(where: { $0.screen == screen }) {
                // `rawValue` (not `String(describing:)`) — a case rename
                // would silently break restoration; the raw string is the
                // persisted contract, guarded by explicit `= "circle"` etc.
                restoredPrimaryTabRaw = tab.rawValue
            }
        }
        .onAppear {
            if primaryTabs.contains(vm.currentScreen) { lastTab = vm.currentScreen }
            restoreLastTabIfNeeded()
        }
        // Warm case: a URL arrived AFTER `.onAppear` fired (e.g. splash
        // still on screen but the shell already mounted). Route now so the
        // user doesn't watch the default tab render then jump.
        .onReceive(NotificationCenter.default.publisher(for: .launchIntentUpdated)) { _ in
            applyLaunchIntentIfNeeded()
        }
        .task {
            // Arşiv/pattern fetch'leri buradaydı; sonuçlarını hiçbir view
            // okumadığı için kaldırıldılar. Arşiv kendi verisini
            // `ArchiveStore` üzerinden çekiyor.
            ONELaunchSignpost.event("pickerReady")
        }
        .onChange(of: notificationManager.shouldNavigateToCircle) { _, shouldNavigate in
            if shouldNavigate {
                withAnimation(ONEAnimation.cardSpring) { vm.currentScreen = .circle }
                notificationManager.shouldNavigateToCircle = false
            }
        }
        .onChange(of: notificationManager.shouldNavigateToToday) { _, shouldNavigate in
            if shouldNavigate {
                withAnimation(ONEAnimation.cardSpring) { vm.currentScreen = .today }
                notificationManager.shouldNavigateToToday = false
            }
        }
        .onChange(of: notificationManager.shouldNavigateToEcho) { _, shouldNavigate in
            if shouldNavigate {
                showingEchoSheet = true
                notificationManager.shouldNavigateToEcho = false
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .init("switchToTodayTab"))) { _ in
            withAnimation(ONEAnimation.cardSpring) { vm.currentScreen = .today }
        }
        .onReceive(NotificationCenter.default.publisher(for: .init("switchToArchiveTab"))) { _ in
            withAnimation(ONEAnimation.cardSpring) { vm.currentScreen = .archive }
        }
        .onReceive(NotificationCenter.default.publisher(for: .init("switchToCircleTab"))) { _ in
            withAnimation(ONEAnimation.cardSpring) { vm.currentScreen = .circle }
        }
        .onReceive(NotificationCenter.default.publisher(for: .init("switchToEchoTab"))) { _ in
            showingEchoSheet = true
        }
        .sheet(isPresented: $showingEchoSheet) {
            // Kabuk `EchoView`'ün kendisinde: `onDismiss` verildiğinde ekran
            // kendi `V3TopBar(leading: .close)`'unu çiziyor. Buradaki
            // `NavigationStack` + sistem toolbar'ı yalnız bir kapat düğmesi
            // için duruyordu ve o düğme uygulamanın geri kalanındaki dairesel
            // xmark'a benzemiyordu.
            EchoView(context: viewContext, onDismiss: { showingEchoSheet = false })
        }
        .v3Sheet()
        .onChange(of: showingEchoSheet) { _, isShown in
            // Sheet açık iken alt çubuk arkada da olsa küçük dursun — kapanış
            // animasyonu daha temiz oluyor ve varsayılan (.large değil) detent
            // seçilirse arkadan görünen çubuk odağı bölmüyor.
            withAnimation(ONEAnimation.easingColor) {
                if isShown {
                    GlobalUIState.shared.addMinimizeSource("profile.echo")
                } else {
                    GlobalUIState.shared.removeMinimizeSource("profile.echo")
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .init("openCitySettings"))) { _ in
            withAnimation(ONEAnimation.cardSpring) { vm.currentScreen = .profile }
        }
        .overlay {
            if let url = globalUI.archivePhotoURL {
                FullScreenPhotoView(
                    url: url,
                    isPresented: Binding(
                        get: { globalUI.archivePhotoURL != nil },
                        set: { newValue in
                            if !newValue {
                                withAnimation(ONEAnimation.screenTransition) {
                                    globalUI.archivePhotoURL = nil
                                }
                            }
                        }
                    )
                )
                .transition(.opacity.animation(.easeOut(duration: 0.22)))
                .zIndex(100)
            } else if let img = globalUI.archiveMomentImage {
                PhotoDataViewerSheet(
                    image: img,
                    isPresented: Binding(
                        get: { globalUI.archiveMomentImage != nil },
                        set: { newValue in
                            if !newValue {
                                withAnimation(ONEAnimation.screenTransition) {
                                    globalUI.archiveMomentImage = nil
                                }
                            }
                        }
                    )
                )
                .transition(.opacity.animation(.easeOut(duration: 0.22)))
                .zIndex(100)
            } else if let img = globalUI.circlePhotoImage {
                PhotoDataViewerSheet(
                    image: img,
                    isPresented: Binding(
                        get: { globalUI.circlePhotoImage != nil },
                        set: { if !$0 { globalUI.circlePhotoImage = nil } }
                    )
                )
                .transition(.opacity)
                .zIndex(100)
            } else if let url = globalUI.todayPhotoURL {
                PhotoViewerSheet(
                    photoURL: url,
                    isPresented: Binding(
                        get: { globalUI.todayPhotoURL != nil },
                        set: { newValue in
                            if !newValue {
                                withAnimation(ONEAnimation.screenTransition) {
                                    globalUI.todayPhotoURL = nil
                                }
                            }
                        }
                    )
                )
                .transition(.opacity.animation(.easeOut(duration: 0.22)))
                .zIndex(100)
            }
        }
        .environment(\.todayPhotoNamespace, todayPhotoNS)
    }

    // MARK: - State restoration

    /// Bring returning users back to the tab they last saw. Runs once per
    /// scene. Precedence (highest first):
    ///   1. `LaunchIntent.pendingTab` — a URL routed here during cold
    ///      launch, resolved before the splash faded.
    ///   2. `NotificationManager.shouldNavigateTo*` — notification / prior
    ///      widget-nav flags set during app lifetime.
    ///   3. `SceneStorage` last-tab restoration.
    /// If any deep-link signal is present, we skip SceneStorage restore.
    private func restoreLastTabIfNeeded() {
        guard !didAttemptRestore else { return }
        didAttemptRestore = true

        // 1. Highest precedence: cold-launch deep link intent.
        if applyLaunchIntentIfNeeded() { return }

        // If `.onReceive(.launchIntentUpdated)` already consumed an intent
        // before this ran, SceneStorage must NOT clobber it. The intent
        // has already routed; we're done.
        if didConsumeLaunchIntent { return }

        // 2. Notification / in-session nav flags win over SceneStorage.
        //    Note: NotificationManager flags and LaunchIntent are dual
        //    signals by design — the former survives across scene
        //    reloads, the latter is one-shot for cold-launch URLs.
        if notificationManager.shouldNavigateToCircle
            || notificationManager.shouldNavigateToToday
            || notificationManager.shouldNavigateToEcho {
            return
        }
        // If the app opened somewhere other than the experiment default,
        // something else already routed us here — respect it.
        if vm.currentScreen != Experiment.defaultLaunchScreen { return }

        guard let tab = primaryTab(fromRaw: restoredPrimaryTabRaw) else { return }
        // Structurally impossible for `tab.screen` to be .today,
        // but guarding here documents the invariant for future changes.
        guard primaryTabs.contains(tab.screen) else { return }
        // Skip when restoring to the same tab the experiment already chose.
        guard tab.screen != vm.currentScreen else { return }

        vm.currentScreen = tab.screen
        lastTab = tab.screen
    }

    /// Apply `LaunchIntent.pendingTab` / `pendingScreen` if present.
    /// Returns `true` when an intent was consumed — restore logic uses
    /// that to short-circuit. Safe to call multiple times: consumption
    /// clears both fields so re-entry is a no-op.
    ///
    /// Sets `didConsumeLaunchIntent = true` on any consumption so that
    /// a late `.onAppear` doesn't fall through to SceneStorage and
    /// clobber a deep link that arrived first. The deep link always
    /// wins over SceneStorage regardless of arrival order.
    @discardableResult
    private func applyLaunchIntentIfNeeded() -> Bool {
        var applied = false

        // `pendingScreen` is more specific than `pendingTab` — prefer it.
        if let screen = LaunchIntent.shared.pendingScreen {
            LaunchIntent.shared.consume()
            didConsumeLaunchIntent = true
            vm.currentScreen = screen
            if primaryTabs.contains(screen) { lastTab = screen }
            applied = true
        } else if let tab = LaunchIntent.shared.pendingTab {
            LaunchIntent.shared.consume()
            didConsumeLaunchIntent = true
            vm.currentScreen = tab.screen
            lastTab = tab.screen
            applied = true
        }

        // Widget / universal-link mood-picker request. Applied AFTER any tab
        // switch above so the picker lands on top of the intended tab
        // (typically .circle). Older code posted `.openMoodPicker` — that
        // race is documented at LaunchIntent.setPendingMoodPickerRequest().
        if LaunchIntent.shared.pendingMoodPickerRequest {
            LaunchIntent.shared.consumeMoodPickerRequest()
            didConsumeLaunchIntent = true
            withAnimation(ONEAnimation.cardSpring) { vm.currentScreen = .today }
            applied = true
        }

        return applied
    }

    private func primaryTab(fromRaw raw: String) -> PrimaryTab? {
        // Raw-string round trip. Empty rawValue (fresh install, never
        // saved) returns nil naturally — no allCases scan needed.
        PrimaryTab(rawValue: raw)
    }

    // MARK: - Primary tabs view (Liquid Glass on iOS 26, legacy fallback below)

    @ViewBuilder
    /// Sekme yüzeyi — tüm iOS sürümlerinde prototipin dock'u.
    ///
    /// Eskiden burada `if #available(iOS 26.0, *)` ile ikiye ayrılan bir
    /// yol vardı: iOS 26+ Apple'ın native `TabView`'ını (SF Symbols'lı
    /// Liquid Glass çubuk), altı `BottomNavigation`'ı kullanıyordu. Sonuç:
    /// iOS 26/27 cihazlarda prototipin dock'u (◎ ▦ ◠ ◍ glifleri, ortadaki
    /// FAB, krem gradyan) HİÇ görünmüyordu — native çubuk onu eziyordu.
    /// Prototip artık varsayılan: tek yol, `BottomNavigation`.
    private var mainTabsView: some View {
        customDockTabView
            .overlay(alignment: .top) { splashHandoffAnchor }
    }

    /// Invisible destination for the splash wordmark's `matchedGeometryEffect`.
    /// Sized small and pinned to the top-safe-area so the "ONE" morphs from
    /// the splash's center to a subtle header position in one motion. The
    /// anchor never draws anything — it's a geometry receiver only. Attached
    /// once at the shell root so the handoff target exists on every tab.
    @ViewBuilder
    private var splashHandoffAnchor: some View {
        if let ns = splashHandoffNS {
            Color.clear
                .frame(width: 40, height: 14)
                .padding(.top, V3Tokens.spacingSM)
                .matchedGeometryEffect(
                    id: SplashHandoff.wordmarkID,
                    in: ns,
                    properties: .frame,
                    anchor: .center,
                    isSource: false
                )
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
    }


    /// v3 dock: 4 sekme (An · Arşiv · Çevre · Profil), yüzen cam kapsül.
    /// Echo tabbardan çıktı —
    /// Profil altında layer route (Phase 4/6'ta bağlanacak).
    ///
    /// **Neden `TabView(.page)` ve neden `switch` değil?**
    /// Eskiden burada `Group { switch vm.currentScreen { ... } }` vardı. SwiftUI
    /// bunu "eski dalı yok et, yenisini kur" diye okuyor: Arşiv'e her dönüşte
    /// `ArchiveStore` sıfırdan kuruluyor ve 12 ay yeniden yükleniyordu (skeleton
    /// flash), Çevre'ye her dönüşte CloudKit'e yeniden gidiliyor, her sekmede
    /// scroll pozisyonu başa dönüyordu. `TabView` sekmeleri canlı tutuyor.
    ///
    /// `.page` stili seçildi çünkü kendi sekme çubuğunu **çizmiyor** — dosyanın
    /// üstündeki `mainTabsView` yorumunda anlatılan iOS 26 çakışması (native
    /// çubuğun `BottomNavigation`'ı ezmesi) böylece tekrarlanmıyor. Yan kazanç:
    /// parmak takipli yatay swipe ücretsiz geliyor.
    private var customDockTabView: some View {
        TabView(selection: selectedTab) {
            ForEach(PrimaryTab.allCases, id: \.self) { tab in
                tabContent(for: tab)
                    .tag(tab)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        // Akış ortasındayken (An adım 2+) yanlışlıkla sekme kaydırmayı engelle.
        // `including: .gesture` drag'i burada yutar, `.subviews` normal davranış.
        .gesture(DragGesture(), including: globalUI.tabSwipeLocked ? .gesture : .subviews)
        .onChange(of: PrimaryTab(containing: vm.currentScreen)) { old, new in
            visitedTabs.insert(new)
            // Dokunarak geçişte haptiği `BottomNavigation` veriyor; swipe ile
            // geçişte kimse vermiyordu. Sekmenin gerçekten değiştiği tek yer
            // burası, dolayısıyla haptik de buraya ait — ama çift tetiklememek
            // için dokunma yolundakini kaldırdık.
            if old != new { ONEHaptics.tabSwitch() }
        }
        .onAppear { visitedTabs.insert(PrimaryTab(containing: vm.currentScreen)) }
        // Reduce Motion: sayfa kaydırma animasyonunu kes, geçiş anlık olsun.
        .transaction { if reduceMotion { $0.animation = nil } }
        .safeAreaInset(edge: .top, spacing: 0) {
            // Üst bar (wordmark + bağlam etiketi) kaldırıldı — sekme adları
            // zaten alt dock'ta. Yalnız offline şerit üstte kalır; kendi
            // görünürlüğünü `isVisible` ile yönetiyor.
            V3OfflineBanner(isVisible: !NetworkMonitor.shared.isOnline)
        }
        // Nav Instagram tarzı: yüzen pill içerik AKIŞININ ÜSTÜNE biner.
        // `.safeAreaInset` scroll içeriğine nav yüksekliği kadar dinlenme payı
        // bırakıyor — scroll bittiğinde son satır nav altında kalmıyor.
        // Ama içerik nav altından **geçebilir** (scroll SIRASINDA blur efekti);
        // spacer sadece "at-rest" pozisyonu belirliyor.
        // 64pt ≈ nav gövdesi (52pt tab + 5×2 iç pad) + hafif nefes payı.
        .safeAreaInset(edge: .bottom, spacing: 0) {
            Color.clear.frame(height: 64)
        }
        .overlay(alignment: .bottom) {
            BottomNavigation(currentScreen: $vm.currentScreen)
        }
        // Sekme-içi scroll modifier'larının kimin aktif olduğunu bilmesi için.
        .environment(\.currentPrimaryTab, PrimaryTab(containing: vm.currentScreen))
    }

    /// Tek bir sekmenin gövdesi.
    ///
    /// Henüz ziyaret edilmemiş sekmeler boş kâğıt olarak dururlar — `TabView`
    /// komşu sayfaları önceden kurmaya çalıştığında Arşiv'in Core Data
    /// fetch'ini ya da Çevre'nin CloudKit isteğini kullanıcı oraya gitmeden
    /// tetiklemesin diye. Bir kez ziyaret edilince `visitedTabs`'tan çıkmıyor,
    /// yani gerçek gövde kalıcı oluyor.
    @ViewBuilder
    private func tabContent(for tab: PrimaryTab) -> some View {
        // Seçili sekme her zaman gerçek gövdeyi çizer. `visitedTabs`'a ekleme
        // `.onAppear`/`.onChange` ile oluyor, yani ilk kare için geç kalıyor —
        // o karede kullanıcı boş kâğıt görürdü.
        if visitedTabs.contains(tab) || PrimaryTab(containing: vm.currentScreen) == tab {
            switch tab {
            case .entry:
                entryTab
            case .archive:
                ArchiveContainerView(context: viewContext)
            case .circle:
                // v3: prototip 10 — 2 kolon kart ızgarası. Eski bubble-cloud
                // `CircleView` dosyada duruyor ama kabuktan çıktı.
                V3CircleView(
                    onNavigateToToday: { vm.currentScreen = .today },
                    isActive: vm.currentScreen == .circle,
                    injectedSample: circleSampleData
                )
                // Örnek veri anahtarı değişince view sıfırdan kurulsun —
                // `injectedSample` yalnız `.task`'ta okunuyor.
                .id(sampleFriendsEnabled)
            case .profile:
                // v3: kompakt profil — avatar + stats + renk dağılımı + ayarlar.
                // Eski BeReal-style hero (ProfileView/ProfileDashboardView) yerine.
                V3ProfileView()
            }
        } else {
            V3Tokens.paper
        }
    }

    /// DEBUG: `-v3.debug.sampleFriends YES` launch argument'ı ile Çevre sekmesi
    /// örnek arkadaşlarla dolar. Release'te her zaman `nil`.
    private var circleSampleData: (friends: [CloudKitManager.FriendCircleData], moments: [Moment])? {
        #if DEBUG
        guard sampleFriendsEnabled else { return nil }
        return (V3CircleSampleData.friends(), V3CircleSampleData.myMoments())
        #else
        return nil
        #endif
    }

    /// An sekmesi içeriği — `.today` ve tanımsız ekranlar buraya düşüyor.
    private var entryTab: some View {
        TodayView(
            context: viewContext,
            onClose: {
                // Saved step'teki "Arşive git" bu closure'ı çağırıyor —
                // kabuğu Arşiv sekmesine zıplat.
                NotificationCenter.default.post(name: .init("switchToArchiveTab"), object: nil)
            }
        )
    }

}


// MARK: - Animations
// BreathingAnimation now provided by DesignSystem/ONEAnimation.swift

// MARK: - Preview
struct ONEColorPickerView_Previews: PreviewProvider {
    static var previews: some View {
        ONEColorPickerView()
    }
}
