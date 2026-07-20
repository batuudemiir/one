//
//  OnboardingView.swift
//  one
//
//  Onboarding — prototipteki 6 sayfa. Simülasyon değil: kullanıcı
//  buradan GERÇEK ilk kaydıyla çıkıyor.
//
//  1. Marka      — bir şarkı. bir renk. bir gün.
//  2. Renk       — 1/3, gerçek kaydın rengi
//  3. Şarkı      — 2/3, gerçek kaydın şarkısı (müzik izni burada)
//  4. Onay       — mühür
//  5. Davet      — son adım, arkadaş
//  6. Hatırlatma — soft-ask (sistem prompt'u en sonda)
//

import SwiftUI
import MusicKit
import Combine
import CoreData   // PersistenceController.container.viewContext
import CloudKit   // CloudKitManager.currentUser["inviteCode"] aboneliği

// MARK: - Step Index
private enum OnboardingStep: Int, CaseIterable {
    case brand = 0      // marka + vaat
    case moodPick       // 1/3 — gerçek ilk kaydın rengi
    case songPick       // 2/3 — gerçek ilk kaydın şarkısı
    case confirm        // 3/3 — mühür
    case invite         // son adım — arkadaş
    case notifSoftAsk   // hatırlatma

    var analyticsName: String {
        switch self {
        case .brand:        return "brand"
        case .moodPick:     return "mood_pick"
        case .songPick:     return "song_pick"
        case .confirm:      return "confirm"
        case .invite:       return "invite"
        case .notifSoftAsk: return "notif_soft_ask"
        }
    }

    /// Alt bardaki birincil butonun metni.
    var primaryTitleKey: String {
        switch self {
        case .brand:        return "onboarding.entry.start"
        case .moodPick:     return "onboarding.entry.next"
        case .songPick:     return "onboarding.entry.save"
        case .confirm:      return "onboarding.entry.next"
        case .invite:       return "onboarding.entry.next"
        case .notifSoftAsk: return "onboarding.entry.finish"
        }
    }
}

// MARK: - Onboarding Root
struct OnboardingView: View {
    @Binding var isCompleted: Bool
    @Environment(\.managedObjectContext) private var context

    @State private var step: OnboardingStep = .brand
    @State private var rootOpacity: Double = 0
    @State private var selectedMood: ONEMood? = nil
    @State private var selectedSong: SongResult? = nil
    @State private var notificationsOptIn: Bool = false
    @State private var isSaving = false
    @State private var showShareSheet = false

    /// Arama ve kayıt için. Onboarding kendi VM'ini kurar — ana ekranınkiyle
    /// paylaşmıyor, çünkü onboarding bitmeden ana ekran hiç kurulmuyor.
    @StateObject private var vm = TodayViewModel(
        context: PersistenceController.shared.container.viewContext
    )

    private var inviteCode: String? {
        let code = CloudKitManager.shared.currentUser?["inviteCode"] as? String
        return (code?.isEmpty == false) ? code : nil
    }

    var body: some View {
        ZStack {
            ONETokens.oneCream.ignoresSafeArea()
            BackgroundAmbience(tint: selectedMood?.color).ignoresSafeArea()

            VStack(spacing: 0) {
                ScrollView(showsIndicators: false) {
                    content
                        .padding(.horizontal, ONETokens.spacingXL)
                        .padding(.top, ONETokens.spacingXL4)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .transition(
                            .asymmetric(
                                insertion: .opacity.combined(with: .move(edge: .trailing)),
                                removal: .opacity.combined(with: .move(edge: .leading))
                            )
                        )
                        .id(step)
                }

                bottomBar
            }
        }
        .opacity(rootOpacity)
        .sheet(isPresented: $showShareSheet) {
            if let code = inviteCode {
                InviteShareSheet(
                    inviteCode: code,
                    userName: CloudKitManager.shared.currentUser?["displayName"] as? String ?? ""
                )
            }
        }
        .onAppear {
            AppAnalytics.shared.track(.onboardingStarted)
            AppAnalytics.shared.track(.onboardingStepViewed(step: step.analyticsName))
            withAnimation(.easeIn(duration: 0.5)) { rootOpacity = 1 }
        }
        .onChange(of: step) { _, new in
            AppAnalytics.shared.track(.onboardingStepViewed(step: new.analyticsName))
        }
        .onChange(of: selectedMood) { _, mood in
            if let mood {
                AppAnalytics.shared.track(.onboardingMoodPicked(mood: mood.rawValue))
            }
        }
    }

    // MARK: Content

    @ViewBuilder
    private var content: some View {
        switch step {
        case .brand:
            OnboardingBrandPage()
        case .moodPick:
            OnboardingMoodPage(selection: $selectedMood)
        case .songPick:
            OnboardingSongPage(vm: vm, selection: $selectedSong)
        case .confirm:
            OnboardingConfirmPage(mood: selectedMood ?? .sakin, song: selectedSong)
        case .invite:
            OnboardingInvitePage(inviteCode: inviteCode) { showShareSheet = true }
        case .notifSoftAsk:
            OnboardingNotifPage(optIn: $notificationsOptIn)
        }
    }

    // MARK: Bottom bar

    /// Prototipteki ortak alt bar. Eskiden her sayfa kendi butonunu çiziyor,
    /// noktalar ise üstte duruyordu — ilerleme ve eylem ekranın iki ucundaydı.
    private var bottomBar: some View {
        VStack(spacing: 9) {
            ProgressDots(current: step.rawValue, total: OnboardingStep.allCases.count)
                .padding(.bottom, 5)

            Button(action: primaryAction) {
                Group {
                    if isSaving {
                        ProgressView().tint(ONETokens.oneCream)
                    } else {
                        Text(NSLocalizedString(step.primaryTitleKey, comment: ""))
                            .bodySMMedium()
                    }
                }
                .foregroundColor(ONETokens.oneCream)
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(Capsule(style: .continuous).fill(ONETokens.oneInk))
            }
            .buttonStyle(.plain)
            .disabled(!canAdvance || isSaving)
            .opacity(canAdvance && !isSaving ? 1 : 0.28)

            // "şimdilik geç" yalnız atlanabilir adımlarda görünür — zorunlu
            // adımlarda gri bir buton göstermek yanlış vaat olurdu.
            Button(action: skipAction) {
                Text(NSLocalizedString("onboarding.entry.skip", comment: ""))
                    .bodySMMedium()
                    .foregroundColor(ONETokens.oneAsh)
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.plain)
            .opacity(canSkip ? 1 : 0)
            .disabled(!canSkip)
        }
        .padding(.horizontal, ONETokens.spacingXL)
        .padding(.bottom, ONETokens.spacingXL3)
    }

    private var canAdvance: Bool {
        switch step {
        case .moodPick: return selectedMood != nil
        case .songPick: return selectedSong != nil
        default:        return true
        }
    }

    private var canSkip: Bool {
        step == .invite || step == .notifSoftAsk
    }

    // MARK: Actions

    private func primaryAction() {
        switch step {
        case .brand:        advance(to: .moodPick)
        case .moodPick:     advance(to: .songPick)
        case .songPick:     saveFirstEntry()
        case .confirm:      advance(to: .invite)
        case .invite:       advance(to: .notifSoftAsk)
        case .notifSoftAsk: completeOnboarding()
        }
    }

    private func skipAction() {
        switch step {
        case .invite:       advance(to: .notifSoftAsk)
        case .notifSoftAsk:
            notificationsOptIn = false
            completeOnboarding()
        default:            break
        }
    }

    private func advance(to next: OnboardingStep) {
        withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) { step = next }
    }

    // MARK: Gerçek ilk kayıt

    /// Prototipin sözü: "bu senin gerçek ilk kaydın — deneme değil."
    ///
    /// İki idempotency anahtarı `saveEntry`'den ÖNCE yazılıyor:
    /// - `firstEntryInviteHookConsumed`: `saveEntry` içindeki hook `total == 1`
    ///   koşulunu tam olarak sağlar ve 1.6 s sonra davet sheet'ini açardı;
    ///   onboarding kendi davet adımını gösterdiği için ikinci kez çıkmamalı.
    /// - `onboardingMoodConsumed`: eski pre-fill yolu artık gereksiz; yazılmazsa
    ///   `ColorPickerViewModel.init` aynı mood'u bir daha doldurur.
    private func saveFirstEntry() {
        guard let mood = selectedMood, let song = selectedSong else { return }

        isSaving = true

        let defaults = UserDefaults.standard
        defaults.set(true, forKey: TodayViewModel.firstEntryInviteHookKey)
        defaults.set(true, forKey: "onboardingMoodConsumed")
        defaults.set(mood.rawValue, forKey: "onboardingFirstMood")
        AppAnalytics.shared.track(.onboardingFirstColorPicked(mood: mood.rawValue))

        let option = MoodOption.all.first { $0.key == mood.rawValue } ?? MoodOption.all[4]
        vm.saveEntry(song: song, mood: option, photo: nil, sharePhoto: true)

        // Kayıt senkron; kısa bir nefes payı mührün ani düşmesini engelliyor.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            isSaving = false
            advance(to: .confirm)
        }
    }

    // MARK: Bitiş

    private func completeOnboarding() {
        let finish: () -> Void = {
            withAnimation(.easeInOut(duration: ONEAnimation.durationMedium)) {
                isCompleted = true
            }
            KeychainHelper.set(true, forKey: "hasCompletedOnboarding")
            // Anahtar uyuşmazlığı düzeltildi: yazan taraf `preferredMusicService`
            // kullanıyordu, burası `selectedMusicPlatform` okuyordu — event
            // platformu hep "unknown" gidiyordu.
            let platform = UserDefaults.standard.string(forKey: "preferredMusicService") ?? "unknown"
            AppAnalytics.shared.track(.onboardingCompleted(musicPlatform: platform))
        }

        guard notificationsOptIn else {
            let appGroup = UserDefaults(suiteName: "group.com.batudemir.ones") ?? .standard
            UserDefaults.standard.set(false, forKey: "notificationsEnabled")
            appGroup.set(false, forKey: "notificationsEnabled")
            DispatchQueue.main.async { finish() }
            return
        }

        NotificationManager.shared.requestAuthorization { granted in
            DispatchQueue.main.async {
                if granted {
                    let defaults = UserDefaults.standard
                    let appGroup = UserDefaults(suiteName: "group.com.batudemir.ones") ?? .standard
                    defaults.set(true, forKey: "notificationsEnabled")
                    appGroup.set(true, forKey: "notificationsEnabled")
                    defaults.set(true, forKey: "streakNotificationsEnabled")
                    defaults.set(true, forKey: "weeklySummaryEnabled")
                    defaults.set(true, forKey: "discoveryNotificationsEnabled")

                    var components = DateComponents()
                    let storedHour = defaults.integer(forKey: "dailyReminderHour")
                    components.hour = storedHour == 0 ? 21 : storedHour
                    components.minute = defaults.integer(forKey: "dailyReminderMinute")

                    if let defaultTime = Calendar.current.date(from: components) {
                        defaults.set(components.hour, forKey: "dailyReminderHour")
                        defaults.set(components.minute, forKey: "dailyReminderMinute")
                        NotificationManager.shared.scheduleDailyReminder(at: defaultTime)
                        NotificationManager.shared.scheduleWeeklySummary()
                        NewUserNurtureScheduler.start()
                    }
                }
                finish()
            }
        }
    }
}


// MARK: - Background Ambience (subtle drifting blob)
private struct BackgroundAmbience: View {
    let tint: Color?
    @State private var drift: CGFloat = 0

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [(tint ?? ONETokens.oneBrandLight).opacity(0.18), .clear],
                            center: .center,
                            startRadius: 10,
                            endRadius: geo.size.width * 0.7
                        )
                    )
                    .frame(width: geo.size.width * 1.2, height: geo.size.width * 1.2)
                    .offset(x: drift * 30 - 60, y: -geo.size.height * 0.2 + drift * 20)
                    .blur(radius: 30)
                    .animation(.easeInOut(duration: 1.4), value: tint)

                Circle()
                    .fill(
                        RadialGradient(
                            colors: [(tint ?? ONETokens.oneBrand).opacity(0.10), .clear],
                            center: .center,
                            startRadius: 10,
                            endRadius: geo.size.width * 0.6
                        )
                    )
                    .frame(width: geo.size.width, height: geo.size.width)
                    .offset(x: -drift * 30 + 50, y: geo.size.height * 0.3 - drift * 30)
                    .blur(radius: 40)
                    .animation(.easeInOut(duration: 1.4), value: tint)
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 8).repeatForever(autoreverses: true)) {
                drift = 1
            }
        }
    }
}

// MARK: - Progress Dots
private struct ProgressDots: View {
    let current: Int
    let total: Int

    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<total, id: \.self) { index in
                Capsule()
                    .fill(index == current ? ONETokens.oneInk : ONETokens.oneAsh.opacity(0.25))
                    .frame(width: index == current ? 22 : 6, height: 6)
                    .animation(.spring(response: 0.45, dampingFraction: 0.8), value: current)
            }
        }
    }
}


#Preview {
    OnboardingView(isCompleted: .constant(false))
}
