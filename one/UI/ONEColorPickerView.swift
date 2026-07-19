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
    @StateObject private var cloudKit = CloudKitManager.shared
    @Environment(\.managedObjectContext) private var viewContext
    @State private var todayEntryStep: Step = .search
    @Namespace private var moodCoreNS
    /// Last tab the user was on — used to coerce TabView selection when
    /// `vm.currentScreen` becomes a non-tab screen (e.g. .confirm/.done).
    @State private var lastTab: ScreenType = Experiment.defaultLaunchScreen

    /// Sekme çubuğu — tek kaynak `PrimaryTab`. Bugün/confirm/done/search burada
    /// yok; kökte tam ekran yönlendiriliyorlar. Ritüel bir yer değil, ortadaki
    /// "+" butonuyla açılan bir eylem.
    private var primaryTabs: [ScreenType] { PrimaryTab.screens }

    var body: some View {
        ZStack {
            // Background
            ONETokens.oneCream.ignoresSafeArea()

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

            // Root router:
            // • confirm/done: full-screen overlays that replace the tab UI
            // • everything else: the 5-tab interface (native Liquid Glass on
            //   iOS 26+, legacy BottomNavigation fallback below)
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
                case .today:
                    // Ritüel artık sekme değil — "+" ile açılan tam ekran eylem.
                    TodayView(
                        context: viewContext,
                        entryStep: $todayEntryStep,
                        onClose: {
                            withAnimation(ONEAnimation.cardSpring) { vm.currentScreen = .circle }
                        }
                    )
                        .overlay(alignment: .topLeading) { ritualDismissButton }
                        .transition(.asymmetric(
                            insertion: .move(edge: .bottom).combined(with: .opacity),
                            removal:   .move(edge: .bottom).combined(with: .opacity)
                        ))
                default:
                    mainTabsView
                        .transition(.opacity)
                }
            }
            .animation(ONEAnimation.cardSpring, value: vm.currentScreen)
        }
        // Remember the last primary tab whenever the user actually lands on one.
        // Widget / kilit ekranı / universal link → giriş ritüeli.
        // Bildirimi `oneApp` hem `ones://today` hem `/event/mood` için yayınlıyor;
        // dinleyicisi olmadığı için ikisi de bugüne kadar ölüydü.
        .onReceive(NotificationCenter.default.publisher(for: .openMoodPicker)) { _ in
            withAnimation(ONEAnimation.cardSpring) { vm.currentScreen = .today }
        }
        .onChange(of: vm.currentScreen) { _, screen in
            if primaryTabs.contains(screen) { lastTab = screen }
            if screen != .today { todayEntryStep = .search }
        }
        .onAppear {
            if primaryTabs.contains(vm.currentScreen) { lastTab = vm.currentScreen }
        }
        .task {
            // Arşiv/pattern senkron Core Data fetch'leri. Açılış Çevre olduğunda
            // CloudKit `initializeUser()` ile aynı anda main thread'i tutuyorlardı —
            // artık ilk kare çizildikten sonra çalışıyorlar.
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
                // Yankı artık kendi sekmesi
                withAnimation(ONEAnimation.cardSpring) { vm.currentScreen = .echo }
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
        .onReceive(NotificationCenter.default.publisher(for: .init("switchToEchoTab"))) { _ in
            withAnimation(ONEAnimation.cardSpring) { vm.currentScreen = .echo }
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
                        set: { if !$0 { globalUI.archivePhotoURL = nil } }
                    )
                )
                .transition(.opacity)
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
                        set: { if !$0 { globalUI.todayPhotoURL = nil } }
                    )
                )
                .transition(.opacity)
                .zIndex(100)
            }
        }
    }

    // MARK: - Primary tabs view (Liquid Glass on iOS 26, legacy fallback below)

    @ViewBuilder
    private var mainTabsView: some View {
        if #available(iOS 26.0, *) {
            liquidGlassTabView
        } else {
            legacyTabView
        }
    }

    /// Native iOS 26 TabView — Apple's built-in Liquid Glass effect and
    /// drag-to-select come for free. Each tab is declared with `Tab(...)`.
    @available(iOS 26.0, *)
    private var liquidGlassTabView: some View {
        TabView(selection: tabBinding) {
            Tab(value: PrimaryTab.circle.screen) {
                CircleView(
                    onNavigateToToday: { vm.currentScreen = .today },
                    onNavigateToDiscover: { vm.currentScreen = .discover }
                )
                    .badge(cloudKit.unseenFriendShareCount)
            } label: {
                Label(PrimaryTab.circle.title, systemImage: PrimaryTab.circle.icon)
            }
            Tab(PrimaryTab.archive.title, systemImage: PrimaryTab.archive.icon,
                value: PrimaryTab.archive.screen) {
                ArchiveContainerView(context: viewContext)
            }
            Tab(PrimaryTab.echo.title, systemImage: PrimaryTab.echo.icon,
                value: PrimaryTab.echo.screen) {
                EchoView(context: viewContext)
            }
            Tab(PrimaryTab.profile.title, systemImage: PrimaryTab.profile.icon,
                value: PrimaryTab.profile.screen) {
                ProfileView(isFromTab: true)
            }
        }
        .tint(ONETokens.oneRed)
        // Native TabView'ın çubuğuna ortadan buton eklenemiyor. `safeAreaInset`
        // kullanıyoruz: sabit padding'in aksine çubuğun gerçek yüksekliğine göre
        // yer ayırır, böylece FAB ne çubuğu örter ne de içeriğin üstüne biner.
        .safeAreaInset(edge: .bottom) {
            ritualFAB.padding(.bottom, ONETokens.spacingSM)
        }
    }

    /// Kalıcı birincil eylem: bugünkü rengini bırak.
    /// Her sekmeden erişilebilir — brief'in 4. kırmızı çizgisi.
    private var ritualFAB: some View {
        Button {
            ONEHaptics.tabSwitch()
            withAnimation(ONEAnimation.cardSpring) { vm.currentScreen = .today }
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 22, weight: .medium))
                .foregroundColor(ONETokens.oneCream)
                .frame(width: 58, height: 58)
                .background(Circle().fill(ONETokens.oneInk))
                .shadow(color: ONETokens.oneInk.opacity(0.32), radius: 12, x: 0, y: 6)
        }
        .buttonStyle(PlainButtonStyle())
        .accessibilityLabel(NSLocalizedString("nav.todayHint", comment: ""))
    }

    /// Ritüel tam ekran açıldığı için kendi kapatma yolu gerekiyor.
    private var ritualDismissButton: some View {
        Button {
            withAnimation(ONEAnimation.cardSpring) { vm.currentScreen = lastTab }
        } label: {
            Image(systemName: "xmark")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(ONETokens.oneAsh)
                .frame(width: 44, height: 44)
        }
        .buttonStyle(PlainButtonStyle())
        .padding(.leading, 8)
        .padding(.top, 4)
        .accessibilityLabel(NSLocalizedString("general.close", comment: ""))
    }

    /// iOS < 26: fall back to the custom floating bar we've had.
    private var legacyTabView: some View {
        ZStack {
            Group {
                switch vm.currentScreen {
                case .discover:
                    DiscoverView(context: viewContext)
                case .archive:
                    ArchiveContainerView(context: viewContext)
                case .circle:
                    CircleView(
                    onNavigateToToday: { vm.currentScreen = .today },
                    onNavigateToDiscover: { vm.currentScreen = .discover }
                )
                case .profile:
                    ProfileView(isFromTab: true)
                case .echo:
                    EchoView(context: viewContext)
                default:
                    // Bugün artık kökte tam ekran yönlendiriliyor; buraya
                    // beklenmedik bir durum düşerse açılış ekranına dön.
                    CircleView(
                    onNavigateToToday: { vm.currentScreen = .today },
                    onNavigateToDiscover: { vm.currentScreen = .discover }
                )
                }
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            BottomNavigation(
                currentScreen: $vm.currentScreen,
                todayMoodColorHex: vm.todayMoodColorHex
            )
        }
    }

    /// Bridges the native TabView selection to `vm.currentScreen` without
    /// introducing a second source of truth.
    ///
    /// • get: if the VM's screen is one of the 5 tabs, use it. Otherwise
    ///   (confirm/done/echo/search) coerce to the last known tab so TabView
    ///   doesn't silently snap to its first tab.
    /// • set: write straight into the VM (no mirror @State, no onChange hop).
    ///
    /// This avoids the AttributeGraph cycle caused by onChange writing back
    /// into a separate @State that feeds the binding.
    private var tabBinding: Binding<ScreenType> {
        Binding<ScreenType>(
            get: {
                primaryTabs.contains(vm.currentScreen) ? vm.currentScreen : lastTab
            },
            set: { newValue in
                guard vm.currentScreen != newValue else { return }
                vm.currentScreen = newValue
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
                CachedAsyncImagePhase(url: artworkURL) { phase in
                    if let image = phase.image {
                        image.resizable().aspectRatio(contentMode: .fill)
                    } else {
                        RoundedRectangle(cornerRadius: 10).fill(ONETokens.oneCreamMid)
                    }
                }
                .frame(width: 42, height: 42)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            } else {
                RoundedRectangle(cornerRadius: 10)
                    .fill(LinearGradient(gradient: Gradient(colors: [song.grad[0].opacity(0.6), song.grad[1].opacity(0.3)]), startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 42, height: 42)
                    .overlay(Text(song.emoji).font(.system(size: 20)))
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(song.name)
                    .monoSM(tracking: 0)
                    .foregroundColor(.black)
                    .lineLimit(1)
                Text(song.artist)
                    .monoSM(tracking: 0)
                    .foregroundColor(ONETokens.oneMist)
            }
            Spacer()
            
            Text(song.genre.uppercased())
                .monoLabel()
                .foregroundColor(ONETokens.oneStone)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(ONETokens.oneCreamMid)
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
                    .foregroundColor(isSelected ? .black : ONETokens.oneAsh)
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

// MARK: - Feeling Button Component
struct FeelingButton: View {
    let feeling: FeelingOption
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                // Icon
                FeelingIconView(type: feeling.type)
                    .frame(width: isSelected ? 44 : 40, height: isSelected ? 36 : 32)
                    .opacity(isSelected ? 1.0 : 0.6)
                    .animation(ONEAnimation.micro, value: isSelected)

                // Label
                Text(feeling.label.uppercased())
                    .monoLabel(tracking: 0.8)
                    .foregroundColor(isSelected ? ONETokens.oneInk : ONETokens.oneAsh)
                    .opacity(isSelected ? 1.0 : 0.7)
                    .animation(ONEAnimation.micro, value: isSelected)
            }
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? ONETokens.oneCreamMid : Color.clear)
                    .animation(ONEAnimation.micro, value: isSelected)
            )
        }
        .buttonStyle(PlainButtonStyle())
        .accessibilityLabel(String(format: NSLocalizedString("accessibility.confirm.feelingButton", comment: ""), feeling.label))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

// MARK: - Legacy Pattern Screen (kept for backward compatibility)
struct PatternScreen: View {
    @ObservedObject var vm: ColorPickerViewModel
    @Environment(\.managedObjectContext) private var viewContext
    @State private var animateBars = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(NSLocalizedString("colorPicker.echoes", comment: ""))
                .monoBase(tracking: 2)
                .foregroundColor(ONETokens.oneAsh)
                .padding(.top, 24)

            Text(NSLocalizedString("colorPicker.echoesDesc", comment: ""))
                .displayLG()
                .foregroundColor(ONETokens.oneInk)
                .tracking(-0.02)
                .padding(.top, 14)
                .lineSpacing(4)
            
            if vm.songPatterns.isEmpty {
                // Empty state
                VStack(spacing: 16) {
                    Text("🎵")
                        .font(.system(size: 60))
                        .padding(.top, 60)
                    
                    Text(NSLocalizedString("colorPicker.noEchoes", comment: ""))
                        .displaySM()
                        .foregroundColor(ONETokens.oneInk)

                    Text(NSLocalizedString("colorPicker.echoesHint", comment: ""))
                        .monoSM(tracking: 0)
                        .foregroundColor(ONETokens.oneAsh)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                        .padding(.horizontal, 40)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 40)
                
                Spacer()
            } else {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 22) {
                        ForEach(vm.songPatterns) { pattern in
                            VStack(alignment: .leading, spacing: 5) {
                                HStack {
                                    Text(pattern.songName)
                                        .displaySM()
                                        .foregroundColor(ONETokens.oneInk)
                                        .tracking(-0.01)
                                        .lineLimit(1)
                                    Spacer()
                                    Text(String(format: NSLocalizedString("colorPicker.times", comment: ""), pattern.count))
                                        .monoSM(tracking: 0.06)
                                        .foregroundColor(ONETokens.oneAsh)
                                }
                                
                                Text(pattern.artistName)
                                    .monoSM(tracking: 0)
                                    .foregroundColor(ONETokens.oneAsh)
                                    .lineLimit(1)
                                
                                // Bar
                                GeometryReader { geo in
                                    ZStack(alignment: .leading) {
                                        RoundedRectangle(cornerRadius: 1)
                                            .fill(ONETokens.oneCreamLow)
                                            .frame(height: 2)
                                        
                                        RoundedRectangle(cornerRadius: 1)
                                            .fill(pattern.color)
                                            .frame(width: animateBars ? geo.size.width * CGFloat(pattern.percentage) : 0, height: 2)
                                    }
                                }
                                .frame(height: 2)
                                .padding(.vertical, 8)
                                
                                Text(pattern.dateString)
                                    .monoBase()
                                    .foregroundColor(ONETokens.oneAsh)
                            }
                        }
                        
                        // Insight Card
                        if let topSong = vm.mostFrequentSong {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    if let emoji = topSong.emoji {
                                        Text(emoji)
                                            .font(.system(size: 32))
                                    }
                                    Spacer()
                                }
                                
                                Text(String(format: NSLocalizedString("colorPicker.insightText", comment: ""), topSong.songName, topSong.count))
                                    .displayXS()
                                    .foregroundColor(ONETokens.oneCream)
                                    .lineSpacing(4)
                            }
                            .padding(.horizontal, 24)
                            .padding(.vertical, 28)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(ONETokens.oneInk)
                            .cornerRadius(20)
                            .padding(.top, 20)
                        }
                    }
                    .padding(.top, 32)
                    .padding(.bottom, 100)
                }
            }
        }
        .padding(.horizontal, 26)
        .onAppear {
            vm.loadPatternData(context: viewContext)
            withAnimation(.easeOut(duration: ONEAnimation.durationLong).delay(0.2)) {
                animateBars = true
            }
        }
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
