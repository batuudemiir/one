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

    /// Sekme çubuğu — tek kaynak `PrimaryTab`. Bugün burada yok ama artık
    /// kabuğun İÇİNDE çiziliyor: dock duruyor, ortadaki "+" onu açıyor.
    /// Kökte yalnız confirm/done tam ekran kalıyor.
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
        .onReceive(NotificationCenter.default.publisher(for: .init("switchToCircleTab"))) { _ in
            withAnimation(ONEAnimation.cardSpring) { vm.currentScreen = .circle }
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
    }


    /// Prototipin dock'u: içerik + `BottomNavigation` (glifler + FAB).
    private var customDockTabView: some View {
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
                case .today:
                    // Bugün tam ekran DEĞİL: dock'un içinde, diğer sekmelerle
                    // aynı kabukta. Kökte ayrı bir dal olarak dururken tüm
                    // kabuğu değiştiriyordu — sekme çubuğu kayboluyor, ritüel
                    // "yeni bir yere gittin" hissi veriyordu. Prototipte
                    // ritüel yerinde beliren bir görünüm, ayrı bir yer değil.
                    TodayView(
                        context: viewContext,
                        entryStep: $todayEntryStep,
                        onClose: {
                            withAnimation(ONEAnimation.cardSpring) { vm.currentScreen = .circle }
                        }
                    )
                default:
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

// MARK: - Animations
// BreathingAnimation now provided by DesignSystem/ONEAnimation.swift

// MARK: - Preview
struct ONEColorPickerView_Previews: PreviewProvider {
    static var previews: some View {
        ONEColorPickerView()
    }
}
