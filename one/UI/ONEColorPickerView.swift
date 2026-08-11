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
    @State private var todayEntryStep: Step = .search
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
    /// `vm.currentScreen` becomes a non-tab screen (e.g. .confirm/.done).
    @State private var lastTab: ScreenType = Experiment.defaultLaunchScreen

    /// Per-scene persisted primary tab. Returning users should land where
    /// they left off, not always on `Experiment.defaultLaunchScreen`.
    /// Stored as `rawValue` of `PrimaryTab` so ritual/mid-flow screens
    /// (`.confirm` / `.done` / `.today`) are structurally unrepresentable
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
    /// (`.confirm` / `.done` / `.search`). `PrimaryTab(containing:)` o
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
            // v3: bone (#FBFAF7) — spec bg. Eski `oneCream` (#F7F6F3) daha bej.
            ONEBrand.bone.ignoresSafeArea()

            // Shared tinted gradient for confirm/done screens
            if vm.currentScreen == .confirm || vm.currentScreen == .done {
                GeometryReader { geometry in
                    RadialGradient(
                        gradient: Gradient(colors: [
                            (vm.selectedMood?.color ?? vm.selectedSong?.grad.first ?? Color.clear).opacity(0.15),
                            Color.clear
                        ]),
                        center: .init(x: 0.5, y: vm.currentScreen == .confirm ? 0.3 : 0.5),
                        startRadius: 0,
                        endRadius: geometry.size.width * 0.8
                    )
                    .ignoresSafeArea()
                    .animation(ONEAnimation.moodTransition, value: vm.selectedMood?.color)
                }
            }

            // Kök yönlendirici:
            // • confirm/done: sekme arayüzünü değiştiren tam ekranlar
            // • diğer her şey: `BottomNavigation`'lı kabuk (Bugün dahil)
            Group {
                switch vm.currentScreen {
                case .confirm:
                    ConfirmScreen(vm: vm, viewContext: viewContext, moodCoreNS: moodCoreNS)
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal:   .move(edge: .leading).combined(with: .opacity)
                        ))
                case .done:
                    DoneScreen(vm: vm, moodCoreNS: moodCoreNS)
                        .transition(.asymmetric(
                            insertion: .scale.combined(with: .opacity),
                            removal:   .opacity
                        ))
                default:
                    mainTabsView
                        .transition(.opacity)
                }
            }
            .animation(ONEAnimation.cardSpring, value: vm.currentScreen)
        }
        .onChange(of: vm.currentScreen) { _, screen in
            if primaryTabs.contains(screen) { lastTab = screen }
            if screen != .today {
                todayEntryStep = .search
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
            // Arşiv/pattern senkron Core Data fetch'leri. Açılış Çevre olduğunda
            // CloudKit `initializeUser()` ile aynı anda main thread'i tutuyorlardı —
            // artık ilk kare çizildikten sonra çalışıyorlar.
            ONELaunchSignpost.event("pickerReady")
            vm.loadArchiveData(context: viewContext)
            vm.loadPatternData(context: viewContext)
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
        .onChange(of: notificationManager.shouldNavigateToDiscovery) { _, shouldNavigate in
            if shouldNavigate {
                withAnimation(ONEAnimation.cardSpring) { vm.currentScreen = .discover }
                notificationManager.shouldNavigateToDiscovery = false
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
            NavigationStack {
                EchoView(context: viewContext)
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) {
                            Button(NSLocalizedString("general.close", comment: "")) {
                                showingEchoSheet = false
                            }
                            .tint(V3Tokens.ink)
                        }
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
                                withAnimation(.spring(response: 0.44, dampingFraction: 0.88)) {
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
                                withAnimation(.spring(response: 0.44, dampingFraction: 0.88)) {
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
                                withAnimation(.spring(response: 0.44, dampingFraction: 0.88)) {
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
            || notificationManager.shouldNavigateToEcho
            || notificationManager.shouldNavigateToDiscovery {
            return
        }
        // If the app opened somewhere other than the experiment default,
        // something else already routed us here — respect it.
        if vm.currentScreen != Experiment.defaultLaunchScreen { return }

        guard let tab = primaryTab(fromRaw: restoredPrimaryTabRaw) else { return }
        // Structurally impossible for `tab.screen` to be .confirm/.done/.today,
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
                .padding(.top, 8)
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


    /// v3 dock: 4 sekme (An · Arşiv · Frekans · Profil), yüzen cam kapsül.
    /// Keşfet ve Echo tabbardan çıktı — Keşfet feature-flag ile kapalı, Echo
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
        // `.safeAreaInset` ile şeffaf bir spacer bırakıyoruz — scroll içeriği
        // buna kadar iner, kalan alan (nav yüksekliği kadar) nav'ın camının
        // arkasına akar. Blur son satırları yumuşatarak Instagram/Music etkisi.
        .safeAreaInset(edge: .bottom, spacing: 0) {
            Color.clear.frame(height: 8)
        }
        .overlay(alignment: .bottom) {
            BottomNavigation(currentScreen: $vm.currentScreen)
        }
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

    /// An sekmesi içeriği — birden fazla case (.today, default, .discover-kapalı)
    /// aynı yere düşüyor.
    private var entryTab: some View {
        TodayView(
            context: viewContext,
            entryStep: $todayEntryStep,
            onClose: {
                // Saved step'teki "Arşive git" bu closure'ı çağırıyor —
                // kabuğu Arşiv sekmesine zıplat.
                NotificationCenter.default.post(name: .init("switchToArchiveTab"), object: nil)
            }
        )
    }

}

// MARK: - Song Row Component
struct SongRow: View {
    let song: Song
    var body: some View {
        HStack(spacing: 12) {
            if let artworkURL = song.artworkURL {
                CachedAsyncImagePhase(url: artworkURL, maxPixelSize: ImageCache.thumbnailMaxPixelSize) { phase in
                    if let image = phase.image {
                        image.resizable().aspectRatio(contentMode: .fill)
                    } else {
                        RoundedRectangle(cornerRadius: 10).fill(V3Tokens.surface)
                    }
                }
                .frame(width: 42, height: 42)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            } else {
                RoundedRectangle(cornerRadius: 10)
                    .fill(LinearGradient(gradient: Gradient(colors: [song.grad[0].opacity(0.6), song.grad[1].opacity(0.3)]), startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 42, height: 42)
                    .overlay(Text(song.emoji).font(V3Typography.sans(20)))
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(song.name)
                    .monoSM(tracking: 0)
                    .foregroundColor(.black)
                    .lineLimit(1)
                Text(song.artist)
                    .monoSM(tracking: 0)
                    .foregroundColor(V3Tokens.faintText)
            }
            Spacer()
            
            Text(song.genre.uppercased())
                .monoLabel()
                .foregroundColor(V3Tokens.faintText)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(V3Tokens.surface)
                .cornerRadius(100)
        }
        .padding(.vertical, 6)
    }
}

// MARK: - Mood Button Component
struct MoodButton: View {
    let mood: ONEMood
    let isSelected: Bool
    let action: () -> Void

    @State private var rippleScale: CGFloat = 0
    @State private var rippleOpacity: Double = 0
    @State private var breatheAmp: CGFloat = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button(action: {
            if !reduceMotion { triggerRipple() }
            action()
        }) {
            VStack(spacing: 8) {
                ZStack {
                    // Watch-style tap ripple
                    Circle()
                        .fill(mood.color.opacity(0.28))
                        .frame(width: 80, height: 80)
                        .scaleEffect(rippleScale)
                        .opacity(rippleOpacity)
                        .allowsHitTesting(false)

                    BreatheBlob(amplitude: breatheAmp)
                        .fill(mood.color)
                        .frame(width: isSelected ? 56 : 48, height: isSelected ? 56 : 48)
                        .overlay(
                            Circle()
                                .strokeBorder(isSelected ? Color.black.opacity(0.18) : Color.clear, lineWidth: 3)
                                .padding(-4)
                        )
                        .shadow(color: isSelected ? mood.color.opacity(0.4) : Color.clear, radius: 10, y: 5)
                        .animation(ONEAnimation.micro, value: isSelected)
                }
                .frame(width: 80, height: 80)

                Text(mood.label.uppercased())
                    .monoSM(tracking: 1.2)
                    .foregroundColor(isSelected ? .black : V3Tokens.mutedText)
                    .opacity(isSelected ? 1.0 : 0.6)
                    .animation(ONEAnimation.micro, value: isSelected)
            }
        }
        .onChange(of: isSelected) { _, selected in
            if selected && !reduceMotion {
                withAnimation(.easeInOut(duration: ONEAnimation.durationBreathe).repeatForever(autoreverses: true)) {
                    breatheAmp = 5
                }
            } else {
                withAnimation(.easeOut(duration: 0.25)) {
                    breatheAmp = 0
                }
            }
        }
        .onAppear {
            if isSelected && !reduceMotion {
                withAnimation(.easeInOut(duration: ONEAnimation.durationBreathe).repeatForever(autoreverses: true)) {
                    breatheAmp = 5
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
        .accessibilityLabel(String(format: NSLocalizedString("accessibility.confirm.moodButton", comment: ""), mood.label))
        .accessibilityHint(mood.meaning)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func triggerRipple() {
        rippleScale = 0.2
        rippleOpacity = 0.7
        withAnimation(.easeOut(duration: 0.45)) {
            rippleScale = 1.4
            rippleOpacity = 0
        }
    }
}

// MARK: - Breathe Blob Shape (Watch Mindfulness morph)

struct BreatheBlob: Shape {
    var amplitude: CGFloat

    var animatableData: CGFloat {
        get { amplitude }
        set { amplitude = newValue }
    }

    func path(in rect: CGRect) -> Path {
        // amplitude ≈ 0 → saf daire, 180 trig hesabından kaçın
        guard amplitude > 0.5 else {
            return Path(ellipseIn: rect)
        }
        let center = CGPoint(x: rect.midX, y: rect.midY)
        // baseR: frame sınırını aşmamak için amplitude kadar içeri al
        let baseR  = min(rect.width, rect.height) / 2 - amplitude
        let bumps  = 6
        var path   = Path()
        let steps  = 180

        for i in 0...steps {
            let angle = CGFloat(i) / CGFloat(steps) * 2 * .pi
            let r     = baseR + amplitude * sin(CGFloat(bumps) * angle)
            let x     = center.x + r * cos(angle - .pi / 2)
            let y     = center.y + r * sin(angle - .pi / 2)
            if i == 0 { path.move(to: CGPoint(x: x, y: y)) }
            else       { path.addLine(to: CGPoint(x: x, y: y)) }
        }
        path.closeSubpath()
        return path
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
