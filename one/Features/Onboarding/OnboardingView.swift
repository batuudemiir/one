//
//  OnboardingView.swift
//  one
//
//  v3 onboarding — design_handoff_onboarding uygulandı.
//  Akış: Niyet → Güven → Apple → Mood → (Şarkı/Ödül ↔ Çevre) → Bildirim → Bugün
//

import SwiftUI
import AuthenticationServices
import UserNotifications
import CoreData

// MARK: - Step

private enum OnboardingV3Step: String, CaseIterable {
    case intent, trust, auth, mood, song, reward, circle, notif, done
}

// MARK: - Root

struct OnboardingView: View {
    @Binding var isCompleted: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.managedObjectContext) private var context

    @StateObject private var appleSignIn = AppleSignInService.shared
    @StateObject private var vm = TodayViewModel(
        context: PersistenceController.shared.container.viewContext
    )

    // MARK: State

    @State private var step: OnboardingV3Step = .intent
    @State private var intentIndex: Int? = nil          // 0..3
    @State private var selectedMood: V3Mood? = nil
    @State private var selectedSong: SongResult? = nil
    @State private var wantsCircle: Bool = false
    @State private var wantsNotifications: Bool = false
    @State private var stepAppearedAt: Date = Date()
    @State private var flowStartedAt: Date = Date()

    // MARK: Ordered flow

    /// intent=2 ("Yakın arkadaşlarımla paylaşmak istiyorum") → Çevre öne çekilir.
    private var orderedSteps: [OnboardingV3Step] {
        if intentIndex == 2 {
            return [.intent, .trust, .auth, .mood, .circle, .song, .reward, .notif]
        }
        return [.intent, .trust, .auth, .mood, .song, .reward, .circle, .notif]
    }

    private var stepIndex: Int {
        orderedSteps.firstIndex(of: step) ?? 0
    }

    var body: some View {
        ZStack {
            V3Tokens.paper.ignoresSafeArea()

            if step == .done {
                DoneView(
                    mood: selectedMood,
                    hasSong: selectedSong != nil,
                    elapsedSeconds: Int(Date().timeIntervalSince(flowStartedAt)),
                    onEnter: exitToApp
                )
                .transition(.opacity)
            } else {
                VStack(spacing: 0) {
                    header
                        .padding(.horizontal, 24)
                        .padding(.top, 26)

                    ProgressDotsRow(
                        current: stepIndex,
                        total: orderedSteps.count,
                        reduceMotion: reduceMotion
                    )
                    .padding(.horizontal, 24)
                    .padding(.top, 16)

                    if step != .intent {
                        BackButton { back() }
                            .padding(.horizontal, 24)
                            .padding(.top, 14)
                    }

                    stepBody
                        .id(step)
                        .transition(rise)
                        .padding(.horizontal, 24)
                        .padding(.bottom, 24)
                }
            }
        }
        .onAppear {
            let now = Date()
            stepAppearedAt = now
            flowStartedAt = now
            AppAnalytics.shared.track(.onboardingStarted)
            AppAnalytics.shared.track(.onboardingStepViewed(step: step.rawValue))
        }
        .onChange(of: step) { _, new in
            stepAppearedAt = Date()
            AppAnalytics.shared.track(.onboardingStepViewed(step: new.rawValue))
        }
        // Apple sign-in başarılı olur olmaz otomatik ilerlet.
        .onChange(of: appleSignIn.status) { _, s in
            if step == .auth, s == .signedIn {
                advance(from: .auth)
            }
        }
    }

    // MARK: Header

    private var header: some View {
        HStack(alignment: .center) {
            Text("\(stepIndex + 1) / \(orderedSteps.count)")
                .v3MicroLabel(1.4)
                .foregroundColor(V3Tokens.faintText)
            Spacer(minLength: 0)
            if step == .song {
                Button {
                    advance(from: .song)
                } label: {
                    Text("Atla")
                        .v3MicroLabel(1.4)
                        .foregroundColor(V3Tokens.faintText)
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: Step body

    @ViewBuilder
    private var stepBody: some View {
        switch step {
        case .intent:
            IntentStep(selected: $intentIndex, onContinue: { advance(from: .intent) })
        case .trust:
            TrustStep(onContinue: { advance(from: .trust) })
        case .auth:
            AuthStep(service: appleSignIn)
        case .mood:
            MoodStep(
                selection: $selectedMood,
                onContinue: {
                    if let mood = selectedMood {
                        AppAnalytics.shared.track(.onboardingMoodPicked(mood: mood.bridgedMood.rawValue))
                    }
                    advance(from: .mood)
                }
            )
        case .song:
            SongStep(
                vm: vm,
                selection: $selectedSong,
                onContinue: { advance(from: .song) }
            )
        case .reward:
            RewardStep(mood: selectedMood, onContinue: { advance(from: .reward) })
        case .circle:
            CircleStep(
                onAccept: { wantsCircle = true; advance(from: .circle) },
                onSkip:   { wantsCircle = false; advance(from: .circle) }
            )
        case .notif:
            NotifStep(
                intentIndex: intentIndex,
                onAllow: {
                    AppAnalytics.shared.track(.onboardingNotifSoftAsk(optIn: true))
                    requestNotificationsAndFinish()
                },
                onSkip: {
                    AppAnalytics.shared.track(.onboardingNotifSoftAsk(optIn: false))
                    finishFlow()
                }
            )
        case .done:
            EmptyView()
        }
    }

    // MARK: Navigation

    private func advance(from current: OnboardingV3Step) {
        // Ekstra guard — sadece current == step iken ilerle.
        guard current == step else { return }

        // Şarkı adımından çıkış — CTA, header "Atla" ve otomatik ilerleme
        // hepsi buradan geçer; müzik bağlanma sinyalini tek noktada yakala.
        if current == .song {
            AppAnalytics.shared.track(.onboardingMusicConnected(granted: selectedSong != nil))
        }

        let steps = orderedSteps
        guard let idx = steps.firstIndex(of: current) else { return }
        let nextIndex = idx + 1
        withAnimation(reduceMotion ? .none : V3Tokens.easing) {
            if nextIndex >= steps.count {
                step = .done
            } else {
                step = steps[nextIndex]
            }
        }
    }

    private func back() {
        let steps = orderedSteps
        guard let idx = steps.firstIndex(of: step), idx > 0 else { return }
        withAnimation(reduceMotion ? .none : V3Tokens.easing) {
            step = steps[idx - 1]
        }
    }

    // MARK: Actions

    private func requestNotificationsAndFinish() {
        wantsNotifications = true
        NotificationManager.shared.requestAuthorization { granted in
            DispatchQueue.main.async {
                let defaults = UserDefaults.standard
                let appGroup = UserDefaults(suiteName: "group.com.batudemir.ones") ?? .standard
                defaults.set(granted, forKey: "notificationsEnabled")
                appGroup.set(granted, forKey: "notificationsEnabled")
                defaults.set(granted, forKey: V3ReminderKeys.enabled)
                if granted {
                    V3ReminderScheduler.reschedule()
                }
                finishFlow()
            }
        }
    }

    private func finishFlow() {
        if wantsCircle {
            UserDefaults.standard.set(true, forKey: "onboardingRequestedCircle")
        }
        withAnimation(reduceMotion ? .none : V3Tokens.easing) {
            step = .done
        }
    }

    private func exitToApp() {
        KeychainHelper.set(true, forKey: "hasCompletedOnboarding")
        WhatsNewManager.shared.markSeen()

        // İlk kaydı tam burada commit et (mood + varsa şarkı). Onboarding
        // boyunca sadece state tutuluyordu; back/forward'da stale kayıt
        // oluşmasın diye storage'a bir tek defa yazıyoruz.
        if let mood = selectedMood {
            UserDefaults.standard.set(true, forKey: TodayViewModel.firstEntryInviteHookKey)
            UserDefaults.standard.set(true, forKey: "onboardingMoodConsumed")
            UserDefaults.standard.set(mood.bridgedMood.rawValue, forKey: "onboardingFirstMood")
            AppAnalytics.shared.track(.onboardingFirstColorPicked(mood: mood.bridgedMood.rawValue))
            vm.saveV3Entry(mood: mood, note: "", photo: nil, song: selectedSong)
        }

        let platform = UserDefaults.standard.string(forKey: "preferredMusicService") ?? "unknown"
        AppAnalytics.shared.track(.onboardingCompleted(musicPlatform: platform))

        withAnimation(.easeInOut(duration: 0.35)) {
            isCompleted = true
        }
    }

    // MARK: Motion

    private var rise: AnyTransition {
        reduceMotion
            ? .opacity
            : .asymmetric(
                insertion: .opacity.combined(with: .offset(y: 10)),
                removal: .opacity
            )
    }
}

// MARK: - Progress dots

private struct ProgressDotsRow: View {
    let current: Int
    let total: Int
    let reduceMotion: Bool

    var body: some View {
        HStack(spacing: 5) {
            ForEach(0..<total, id: \.self) { i in
                Capsule(style: .continuous)
                    .fill(color(for: i))
                    .frame(width: width(for: i), height: 6)
                    .animation(
                        reduceMotion ? .none : .easeOut(duration: 0.2),
                        value: current
                    )
            }
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Adım \(current + 1) / \(total)"))
    }

    private func color(for i: Int) -> Color {
        if i == current { return V3Tokens.ink }
        if i < current  { return Color(hex: "#CFCCC3") }
        return V3Tokens.hairline
    }

    private func width(for i: Int) -> CGFloat {
        i == current ? 22 : 6
    }
}

// MARK: - Back button

private struct BackButton: View {
    let action: () -> Void
    var body: some View {
        HStack {
            Button(action: action) {
                Text("← Geri")
                    .font(V3Typography.sans(14, weight: .medium))
                    .foregroundColor(Color(hex: "#5A5A66"))
                    .padding(.leading, 12)
                    .padding(.trailing, 16)
                    .padding(.vertical, 9)
                    .background(
                        Capsule(style: .continuous)
                            .stroke(V3Tokens.hairline, lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
            Spacer(minLength: 0)
        }
    }
}

// MARK: - Step 1 · Intent

private struct IntentStep: View {
    @Binding var selected: Int?
    let onContinue: () -> Void

    private let options = [
        "Ruh halimi anlamak istiyorum",
        "Günümü müzikle kaydetmek istiyorum",
        "Yakın arkadaşlarımla paylaşmak istiyorum",
        "Sadece bakıyorum"
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Neden\nburadasın?")
                .font(V3Typography.display(46, weight: .black))
                .tracking(-1.4)
                .lineSpacing(-4)
                .foregroundColor(V3Tokens.ink)
                .padding(.top, 44)
                .padding(.bottom, 30)

            VStack(spacing: 10) {
                ForEach(options.indices, id: \.self) { idx in
                    optionRow(idx)
                }
            }

            Spacer(minLength: 24)

            HStack {
                Spacer()
                V3PrimaryButton(
                    title: "Devam",
                    isEnabled: selected != nil,
                    action: onContinue
                )
            }
            .padding(.top, 24)
        }
    }

    @ViewBuilder
    private func optionRow(_ idx: Int) -> some View {
        let isSelected = (selected == idx)
        Button {
            ONEHaptics.feelingSelected()
            selected = idx
        } label: {
            HStack {
                Text(options[idx])
                    .font(V3Typography.sans(16, weight: isSelected ? .semibold : .medium))
                    .foregroundColor(isSelected ? V3Tokens.paper : V3Tokens.ink)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 20)
            .frame(maxWidth: .infinity, minHeight: 60, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(isSelected ? V3Tokens.ink : V3Tokens.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(isSelected ? V3Tokens.ink : V3Tokens.hairline, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

// MARK: - Step 2 · Trust

private struct TrustStep: View {
    let onContinue: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            darkPanel
                .padding(.top, 44)

            Text("Giriş Apple ile.\nVeriler sende kalır.")
                .font(V3Typography.display(40, weight: .black))
                .tracking(-1.2)
                .lineSpacing(-6)
                .foregroundColor(V3Tokens.ink)
                .padding(.top, 34)

            Spacer(minLength: 28)

            V3PrimaryButton(
                title: "Anladım",
                isFullWidth: true,
                verticalPadding: 18,
                fontSize: 17,
                action: onContinue
            )
            .padding(.top, 28)
        }
    }

    private var darkPanel: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Gizlilik")
                .font(V3Typography.mono(11))
                .tracking(1.6)
                .textCase(.uppercase)
                .foregroundColor(V3Tokens.faintText)

            FlowRow(spacing: 8, lineSpacing: 8) {
                chip("Şifre yok")
                chip("E-posta paylaşılmaz")
            }
        }
        .padding(30)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(V3Tokens.ink)
        )
    }

    private func chip(_ label: String) -> some View {
        Text(label)
            .font(V3Typography.mono(10))
            .tracking(1.2)
            .textCase(.uppercase)
            .foregroundColor(Color(hex: "#C8C7C2"))
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.white.opacity(0.08))
            )
    }
}

// MARK: - Step 3 · Apple sign in

private struct AuthStep: View {
    @ObservedObject var service: AppleSignInService
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Apple ile devam et.")
                .font(V3Typography.display(42, weight: .black))
                .tracking(-1.2)
                .foregroundColor(V3Tokens.ink)
                .padding(.top, 44)
                .padding(.bottom, 8)

            Text("Şifre yok. Tek dokunuşla gir.")
                .font(V3Typography.sans(16, weight: .regular))
                .foregroundColor(V3Tokens.mutedText)

            Spacer(minLength: 24)

            SignInWithAppleButton(
                .continue,
                onRequest: { req in service.prepare(request: req) },
                onCompletion: { result in service.handle(result: result) }
            )
            .signInWithAppleButtonStyle(scheme == .dark ? .white : .black)
            .frame(height: 50)
            .clipShape(Capsule(style: .continuous))
            .padding(.top, 24)

            Text("Yalnızca kimlik doğrulama için kullanılır.")
                .font(V3Typography.sans(13))
                .foregroundColor(V3Tokens.faintText)
                .frame(maxWidth: .infinity)
                .padding(.top, 14)
        }
    }
}

// MARK: - Step 4 · Mood

private struct MoodStep: View {
    @Binding var selection: V3Mood?
    let onContinue: () -> Void

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 3)

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Bugün nasıl hissettin?")
                .font(V3Typography.display(44, weight: .black))
                .tracking(-1.3)
                .lineSpacing(-4)
                .foregroundColor(V3Tokens.ink)
                .padding(.top, 40)
                .padding(.bottom, 8)

            Text("Bir renge dokun. Yeter.")
                .font(V3Typography.sans(16))
                .foregroundColor(V3Tokens.mutedText)
                .padding(.bottom, 30)

            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(V3Mood.allCases) { mood in
                    tile(mood)
                }
            }
            .padding(.vertical, 4)

            Spacer(minLength: 20)

            HStack(alignment: .center, spacing: 14) {
                Text(hintText)
                    .font(V3Typography.mono(12))
                    .foregroundColor(V3Tokens.faintText)
                Spacer(minLength: 0)
                V3PrimaryButton(
                    title: "Devam",
                    isEnabled: selection != nil,
                    action: onContinue
                )
            }
            .padding(.top, 20)
        }
    }

    private var hintText: String {
        if let m = selection { return "\(m.label) · kaydedildi" }
        return "Dokuz renkten biri"
    }

    private func tile(_ mood: V3Mood) -> some View {
        let isSelected = (selection == mood)
        return Button {
            ONEHaptics.feelingSelected()
            withAnimation(V3Tokens.easingColor) {
                selection = mood
            }
        } label: {
            VStack(spacing: 8) {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(mood.color)
                    .aspectRatio(1, contentMode: .fit)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(V3Tokens.paper, lineWidth: isSelected ? 3 : 0)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 23, style: .continuous)
                            .stroke(V3Tokens.ink, lineWidth: isSelected ? 3 : 0)
                            .padding(-3)
                    )
                    .shadow(color: Color(red: 20/255, green: 20/255, blue: 26/255).opacity(0.08),
                            radius: 9, x: 0, y: 6)
                    .scaleEffect(isSelected ? 1.02 : 1)

                Text(mood.label)
                    .font(V3Typography.sans(14, weight: .semibold))
                    .foregroundColor(V3Tokens.ink)
                    .opacity(isSelected ? 1 : 0)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(mood.label)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

// MARK: - Step 5 · Song

private struct SongStep: View {
    @ObservedObject var vm: TodayViewModel
    @Binding var selection: SongResult?
    let onContinue: () -> Void

    @State private var query: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Bu hisse bir şarkı ekle")
                .font(V3Typography.display(42, weight: .black))
                .tracking(-1.2)
                .lineSpacing(-4)
                .foregroundColor(V3Tokens.ink)
                .padding(.top, 38)
                .padding(.bottom, 8)

            Text("İstersen sonra da yapabilirsin.")
                .font(V3Typography.sans(16))
                .foregroundColor(V3Tokens.mutedText)
                .padding(.bottom, 22)

            searchField

            HStack(spacing: 8) {
                sourceChip("Apple Music")
                sourceChip("Spotify")
                Spacer(minLength: 0)
            }
            .padding(.top, 12)

            if !vm.searchResults.isEmpty {
                VStack(spacing: 8) {
                    ForEach(vm.searchResults.prefix(3)) { song in
                        row(song)
                    }
                }
                .padding(.top, 20)
            }

            Spacer(minLength: 24)

            ctaButton
                .padding(.top, 24)
        }
    }

    private var searchField: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(V3Tokens.kor)
                .frame(width: 8, height: 8)
            TextField("Şarkı veya sanatçı ara", text: $query)
                .font(V3Typography.sans(16))
                .foregroundColor(V3Tokens.ink)
                .textFieldStyle(.plain)
                .onChange(of: query) { _, q in vm.search(q) }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(V3Tokens.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(V3Tokens.hairline, lineWidth: 1)
        )
    }

    private func sourceChip(_ label: String) -> some View {
        Text(label)
            .font(V3Typography.mono(10))
            .tracking(1.2)
            .textCase(.uppercase)
            .foregroundColor(V3Tokens.faintText)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(V3Tokens.wash)
            )
    }

    private func row(_ song: SongResult) -> some View {
        let isSelected = (selection?.id == song.id)
        return Button {
            ONEHaptics.feelingSelected()
            selection = song
        } label: {
            HStack(spacing: 14) {
                artwork(song)
                VStack(alignment: .leading, spacing: 2) {
                    Text(song.name)
                        .font(V3Typography.sans(15, weight: .semibold))
                        .foregroundColor(V3Tokens.ink)
                        .lineLimit(1)
                    Text(song.artist)
                        .font(V3Typography.sans(13))
                        .foregroundColor(V3Tokens.faintText)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
                Circle()
                    .fill(isSelected ? V3Tokens.ink : Color.clear)
                    .overlay(
                        Circle()
                            .stroke(isSelected ? V3Tokens.ink : Color(hex: "#DDD9CF"),
                                    lineWidth: 1.5)
                    )
                    .frame(width: 18, height: 18)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(isSelected ? V3Tokens.surface : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(isSelected ? V3Tokens.ink : V3Tokens.hairline, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func artwork(_ song: SongResult) -> some View {
        if let s = song.artworkURLString, let url = URL(string: s) {
            AsyncImage(url: url) { img in
                img.resizable().scaledToFill()
            } placeholder: {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(V3Tokens.wash)
            }
            .frame(width: 44, height: 44)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        } else {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(V3Tokens.wash)
                .frame(width: 44, height: 44)
        }
    }

    @ViewBuilder
    private var ctaButton: some View {
        if selection != nil {
            V3PrimaryButton(
                title: "Şarkıyı ekle",
                isFullWidth: true,
                verticalPadding: 18,
                fontSize: 17,
                action: onContinue
            )
        } else {
            Button(action: onContinue) {
                Text("Şimdilik şarkısız devam")
                    .font(V3Typography.sans(17, weight: .semibold))
                    .foregroundColor(Color(hex: "#5A5A66"))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(
                        Capsule(style: .continuous)
                            .stroke(V3Tokens.hairline, lineWidth: 1.5)
                    )
            }
            .buttonStyle(.plain)
        }
    }
}

// MARK: - Step 6 · Reward

private struct RewardStep: View {
    let mood: V3Mood?
    let onContinue: () -> Void

    @State private var popped: Bool = false

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 7)
    private let filledIndex = 12   // handoff: mock "today" konumu
    private let totalCells = 28

    private var monthLabel: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "tr_TR")
        f.dateFormat = "LLLL"
        let m = f.string(from: Date()).capitalized(with: Locale(identifier: "tr_TR"))
        return "Arşiv · \(m)"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(monthLabel)
                .font(V3Typography.mono(11))
                .tracking(1.6)
                .textCase(.uppercase)
                .foregroundColor(V3Tokens.faintText)
                .padding(.top, 38)

            LazyVGrid(columns: columns, spacing: 6) {
                ForEach(0..<totalCells, id: \.self) { i in
                    cell(index: i)
                }
            }
            .padding(.top, 16)

            Text("İşte ilk karen.")
                .font(V3Typography.display(38, weight: .black))
                .tracking(-1.1)
                .foregroundColor(V3Tokens.ink)
                .padding(.top, 36)
                .padding(.bottom, 10)

            Text("Her gün bir tane daha eklenecek. Boş günler de mozaiğin parçası.")
                .font(V3Typography.sans(17))
                .foregroundColor(V3Tokens.mutedText)
                .lineSpacing(4)

            Spacer(minLength: 26)

            V3PrimaryButton(
                title: "Devam",
                isFullWidth: true,
                verticalPadding: 18,
                fontSize: 17,
                action: onContinue
            )
            .padding(.top, 26)
        }
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.62).delay(0.05)) {
                popped = true
            }
        }
    }

    @ViewBuilder
    private func cell(index: Int) -> some View {
        if index == filledIndex, let m = mood {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(m.color)
                .aspectRatio(1, contentMode: .fit)
                .scaleEffect(popped ? 1 : 0.4)
        } else {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .strokeBorder(
                    Color(hex: "#DDD9CF"),
                    style: StrokeStyle(lineWidth: 1.5, dash: [3, 3])
                )
                .aspectRatio(1, contentMode: .fit)
        }
    }
}

// MARK: - Step 7 · Circle

private struct CircleStep: View {
    let onAccept: () -> Void
    let onSkip: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            avatarStack
                .padding(.top, 40)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text("Yakın arkadaşlarınla paylaşmak ister misin?")
                .font(V3Typography.display(40, weight: .black))
                .tracking(-1.2)
                .lineSpacing(-4)
                .foregroundColor(V3Tokens.ink)
                .padding(.top, 34)
                .padding(.bottom, 12)

            Text("İstersen 3-5 kişilik bir çevre kur. İstemezsen tamamen tek başına kullan.")
                .font(V3Typography.sans(17))
                .foregroundColor(V3Tokens.mutedText)
                .lineSpacing(4)

            Spacer(minLength: 26)

            HStack(spacing: 10) {
                outlineButton("Çevre kur", action: onAccept)
                outlineButton("Şimdi değil", action: onSkip)
            }
            .padding(.top, 26)
        }
    }

    private func outlineButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: {
            ONEHaptics.feelingSelected()
            action()
        }) {
            Text(title)
                .font(V3Typography.sans(16, weight: .semibold))
                .foregroundColor(V3Tokens.ink)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .background(
                    Capsule(style: .continuous)
                        .stroke(V3Tokens.ink, lineWidth: 1.5)
                )
        }
        .buttonStyle(.plain)
    }

    private var avatarStack: some View {
        let sample: [V3Mood] = [.huzurlu, .coskulu, .odakli]
        return HStack(spacing: -14) {
            ForEach(sample.indices, id: \.self) { idx in
                Circle()
                    .fill(sample[idx].color)
                    .frame(width: 52, height: 52)
                    .overlay(Circle().stroke(V3Tokens.paper, lineWidth: 3))
            }
            Circle()
                .fill(V3Tokens.wash)
                .frame(width: 52, height: 52)
                .overlay(
                    Circle()
                        .strokeBorder(
                            Color(hex: "#CFCCC3"),
                            style: StrokeStyle(lineWidth: 1.5, dash: [3, 3])
                        )
                )
                .overlay(
                    Text("+")
                        .font(V3Typography.mono(14))
                        .foregroundColor(V3Tokens.faintText)
                )
        }
    }
}

// MARK: - Step 8 · Notification

private struct NotifStep: View {
    let intentIndex: Int?
    let onAllow: () -> Void
    let onSkip: () -> Void

    private var copy: (push: String, time: String, headline: String, body: String) {
        switch intentIndex {
        case 0:  return ("Bu hafta üç gün maviydin", "Pazar 20:00",
                         "Haftalık renk hikayeni kaçırma",
                         "Pazar akşamı haftanın mozaiğini gönderiyoruz. Başka bildirim yok.")
        case 1:  return ("Bugünün şarkısı hâlâ boş", "Her gün 21:00",
                         "Günün şarkısını hatırlatalım mı?",
                         "Akşam tek bir hatırlatma. Kaçırdığın gün ikincisi gelmez.")
        case 2:  return ("Çevrenden iki yeni renk", "Her gün 21:00",
                         "Çevrendeki renkleri kaçırma",
                         "Arkadaşların gününü kaydettiğinde tek bir özet bildirim.")
        default: return ("Bugün nasılsın?", "Her gün 21:00",
                         "Akşam tek bir hatırlatma",
                         "On saniyelik bir soru. İstemezsen kapatabilirsin.")
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            previewCard
                .padding(.top, 40)

            Text(copy.headline)
                .font(V3Typography.display(40, weight: .black))
                .tracking(-1.2)
                .lineSpacing(-4)
                .foregroundColor(V3Tokens.ink)
                .padding(.top, 34)
                .padding(.bottom, 12)

            Text(copy.body)
                .font(V3Typography.sans(17))
                .foregroundColor(V3Tokens.mutedText)
                .lineSpacing(4)

            Spacer(minLength: 26)

            VStack(spacing: 10) {
                V3PrimaryButton(
                    title: "Hatırlat",
                    isFullWidth: true,
                    verticalPadding: 18,
                    fontSize: 17,
                    action: onAllow
                )
                Button(action: onSkip) {
                    Text("Şimdi değil")
                        .font(V3Typography.sans(15, weight: .medium))
                        .foregroundColor(V3Tokens.faintText)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.plain)
            }
            .padding(.top, 26)
        }
    }

    private var previewCard: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(V3Tokens.kor)
                    .frame(width: 38, height: 38)
                Text("ONE")
                    .font(V3Typography.display(17, weight: .black))
                    .tracking(-0.7)
                    .foregroundColor(V3Tokens.paper)
                    .fixedSize()
                    .clipped()
            }
            .frame(width: 38, height: 38)

            VStack(alignment: .leading, spacing: 2) {
                Text(copy.push)
                    .font(V3Typography.sans(14, weight: .semibold))
                    .foregroundColor(V3Tokens.ink)
                Text(copy.time)
                    .font(V3Typography.sans(13))
                    .foregroundColor(V3Tokens.faintText)
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(V3Tokens.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(V3Tokens.hairline, lineWidth: 1)
        )
        .shadow(color: Color(red: 20/255, green: 20/255, blue: 26/255).opacity(0.06),
                radius: 12, x: 0, y: 8)
    }
}

// MARK: - Done

private struct DoneView: View {
    let mood: V3Mood?
    let hasSong: Bool
    let elapsedSeconds: Int
    let onEnter: () -> Void

    private var moodColor: Color   { mood?.color ?? V3Tokens.kor }
    private var moodInk: Color     { mood?.ink ?? V3Tokens.paper }
    private var moodName: String   { mood?.label ?? "Ateşli" }

    private var body1: String {
        hasSong
            ? "İlk karen ve şarkın arşivde. Yarın bir tane daha."
            : "İlk karen arşivde. Yarın bir tane daha."
    }

    private var elapsedLabel: String {
        let m = elapsedSeconds / 60
        let s = elapsedSeconds % 60
        return String(format: "%d:%02d’DE HAZIR OLDU", m, s)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Bugünün rengi")
                    .font(V3Typography.mono(11))
                    .tracking(1.4)
                    .textCase(.uppercase)
                    .foregroundColor(moodInk.opacity(0.7))

                Text(moodName)
                    .font(V3Typography.display(42, weight: .black))
                    .tracking(-1.2)
                    .foregroundColor(moodInk)
            }
            .padding(30)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .fill(moodColor)
            )
            .padding(.top, 8)

            Text("Hazırsın.")
                .font(V3Typography.display(44, weight: .black))
                .tracking(-1.3)
                .foregroundColor(V3Tokens.ink)
                .padding(.top, 36)
                .padding(.bottom, 12)

            Text(body1)
                .font(V3Typography.sans(17))
                .foregroundColor(V3Tokens.mutedText)
                .lineSpacing(4)

            Spacer(minLength: 0)

            VStack(spacing: 10) {
                V3PrimaryButton(
                    title: "Bugün’e git",
                    isFullWidth: true,
                    verticalPadding: 18,
                    fontSize: 17,
                    action: onEnter
                )
                Text(elapsedLabel)
                    .font(V3Typography.mono(11))
                    .tracking(1.2)
                    .textCase(.uppercase)
                    .foregroundColor(V3Tokens.ghostText)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 26)
        .padding(.bottom, 24)
    }
}

// MARK: - FlowRow (chip wrapper)

private struct FlowRow<Content: View>: View {
    let spacing: CGFloat
    let lineSpacing: CGFloat
    @ViewBuilder let content: () -> Content

    var body: some View {
        // Küçük chip seti — 3 eleman tek satıra sığar; sığmazsa doğal HStack
        // taşması yerine `Layout` istemeden basit wrap benzetimi.
        HStack(spacing: spacing) {
            content()
        }
    }
}

#Preview {
    OnboardingView(isCompleted: .constant(false))
}
