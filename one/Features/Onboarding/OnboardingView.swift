//
//  OnboardingView.swift
//  one
//
//  Professional onboarding:
//  1. Welcome — brand reveal with mascot + slogan animation
//  2. Promise — animated mood cycle + value proposition
//  3. Tutorial intro — "let's show you how it works"
//  4. Tutorial / Mood pick — interactive
//  5. Tutorial / Reveal card — magic moment
//  6. Music permission — Apple Music
//  7. Soft notification ask
//

import SwiftUI
import MusicKit
import Combine

// MARK: - Step Index
private enum OnboardingStep: Int, CaseIterable {
    case welcome = 0
    case promise
    case tutorialIntro
    case tutorialMoodPick
    case tutorialReveal
    case music
    case notifSoftAsk

    var analyticsName: String {
        switch self {
        case .welcome:           return "welcome"
        case .promise:           return "promise"
        case .tutorialIntro:     return "tutorial_intro"
        case .tutorialMoodPick:  return "tutorial_mood_pick"
        case .tutorialReveal:    return "tutorial_reveal"
        case .music:             return "permissions"
        case .notifSoftAsk:      return "notif_soft_ask"
        }
    }
}

// MARK: - Onboarding Root
struct OnboardingView: View {
    @Binding var isCompleted: Bool
    @State private var step: OnboardingStep = .welcome
    @State private var rootOpacity: Double = 0
    @State private var selectedMood: ONEMood? = nil
    @State private var notificationsOptIn: Bool = false

    var body: some View {
        ZStack {
            ONETokens.oneCream
                .ignoresSafeArea()

            // Soft background ambience — slow drifting gradient tinted by mood
            BackgroundAmbience(tint: selectedMood?.color)
                .ignoresSafeArea()

            content
                .transition(
                    .asymmetric(
                        insertion: .opacity.combined(with: .move(edge: .trailing)),
                        removal: .opacity.combined(with: .move(edge: .leading))
                    )
                )
                .id(step)

            // Progress dots — hidden on welcome & last permission/notif screens
            if step != .welcome {
                VStack {
                    ProgressDots(current: step.rawValue, total: OnboardingStep.allCases.count)
                        .padding(.top, 14)
                    Spacer()
                }
            }
        }
        .opacity(rootOpacity)
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

    @ViewBuilder
    private var content: some View {
        switch step {
        case .welcome:
            WelcomePage(goToNext: { advance(to: .promise) })
        case .promise:
            PromisePage(
                goBack: { advance(to: .welcome) },
                goToNext: { advance(to: .tutorialIntro) }
            )
        case .tutorialIntro:
            TutorialIntroPage(
                goBack: { advance(to: .promise) },
                goToNext: { advance(to: .tutorialMoodPick) }
            )
        case .tutorialMoodPick:
            TutorialMoodPickPage(
                selectedMood: $selectedMood,
                goBack: { advance(to: .tutorialIntro) },
                goToNext: { advance(to: .tutorialReveal) }
            )
        case .tutorialReveal:
            TutorialRevealPage(
                mood: selectedMood ?? .sakin,
                goToNext: { advance(to: .music) }
            )
        case .music:
            MusicPermissionPage(
                goBack: { advance(to: .tutorialReveal) },
                goToNext: { advance(to: .notifSoftAsk) }
            )
        case .notifSoftAsk:
            NotificationSoftAskPage(
                optIn: $notificationsOptIn,
                complete: completeOnboarding
            )
        }
    }

    private func advance(to next: OnboardingStep) {
        withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) {
            step = next
        }
    }

    private func completeOnboarding() {
        if let mood = selectedMood {
            UserDefaults.standard.set(mood.rawValue, forKey: "onboardingFirstMood")
        }

        let finish: () -> Void = {
            withAnimation(.easeInOut(duration: ONEAnimation.durationMedium)) {
                isCompleted = true
            }
            KeychainHelper.set(true, forKey: "hasCompletedOnboarding")
            let platform = UserDefaults.standard.string(forKey: "selectedMusicPlatform") ?? "unknown"
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
                    }

                    NewUserNurtureScheduler.start()
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

// MARK: - 1. Welcome Page
private struct WelcomePage: View {
    let goToNext: () -> Void

    @State private var mascotScale: CGFloat = 0.7
    @State private var mascotOpacity: Double = 0
    @State private var brandRevealOffset: CGFloat = 30
    @State private var brandOpacity: Double = 0
    @State private var sloganOpacity: Double = 0
    @State private var ctaOpacity: Double = 0
    @State private var pulse: CGFloat = 1.0

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Hero brand reveal
            VStack(spacing: 28) {
                ZStack {
                    Circle()
                        .stroke(ONETokens.oneInk.opacity(0.06), lineWidth: 1)
                        .frame(width: 220, height: 220)
                        .scaleEffect(pulse)
                    Circle()
                        .stroke(ONETokens.oneInk.opacity(0.04), lineWidth: 1)
                        .frame(width: 170, height: 170)
                        .scaleEffect(pulse * 0.95)

                    OneMascotView(pose: .hi, size: 130)
                        .scaleEffect(mascotScale)
                        .opacity(mascotOpacity)
                }

                VStack(spacing: 12) {
                    Text("ONE")
                        .editorialXL()
                        .fontWeight(.bold)
                        .tracking(-2.0)
                        .foregroundColor(ONETokens.oneInk)
                        .offset(y: brandRevealOffset)
                        .opacity(brandOpacity)

                    Text(NSLocalizedString("onboarding.slogan", comment: ""))
                        .monoBase(tracking: 1.4)
                        .foregroundColor(ONETokens.oneAsh)
                        .opacity(sloganOpacity)
                }
            }

            Spacer()

            VStack(spacing: 8) {
                Button(action: goToNext) {
                    Text(NSLocalizedString("onboarding.welcome.cta", comment: ""))
                        .bodySMMedium()
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 17)
                        .background(
                            LinearGradient(
                                colors: [ONETokens.oneBrand, ONETokens.oneBrandLight],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(16)
                }

                Text(NSLocalizedString("onboarding.welcome.subnote", comment: ""))
                    .monoLabel()
                    .foregroundColor(ONETokens.oneStone)
                    .padding(.top, 6)
            }
            .opacity(ctaOpacity)
            .padding(.horizontal, 28)
            .padding(.bottom, 56)
        }
        .onAppear {
            withAnimation(.spring(response: 0.7, dampingFraction: 0.7).delay(0.1)) {
                mascotScale = 1.0
                mascotOpacity = 1
            }
            withAnimation(.easeOut(duration: 0.6).delay(0.45)) {
                brandRevealOffset = 0
                brandOpacity = 1
            }
            withAnimation(.easeOut(duration: 0.5).delay(0.75)) {
                sloganOpacity = 1
            }
            withAnimation(.easeOut(duration: 0.5).delay(1.05)) {
                ctaOpacity = 1
            }
            withAnimation(.easeInOut(duration: 3.5).repeatForever(autoreverses: true)) {
                pulse = 1.06
            }
        }
    }
}

// MARK: - 2. Promise Page (Animated mood cycle)
private struct PromisePage: View {
    let goBack: () -> Void
    let goToNext: () -> Void

    @State private var moodIndex: Int = 0
    @State private var contentOpacity: Double = 0
    @State private var timerCancellable: AnyCancellable?
    private let cycleMoods: [ONEMood] = [.sakin, .isikli, .derin, .nostaljik, .uzgun, .taze, .yorgun, .ozgur, .enerjik, .stresli, .sinirli, .atesli]

    private var currentMood: ONEMood { cycleMoods[moodIndex % cycleMoods.count] }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            BackButton(action: goBack)
                .padding(.top, 56)

            Spacer()

            VStack(alignment: .center, spacing: 36) {
                // Big animated mood orb
                ZStack {
                    Circle()
                        .fill(currentMood.color.opacity(0.18))
                        .frame(width: 240, height: 240)
                        .blur(radius: 12)

                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [currentMood.color, currentMood.color.opacity(0.65)],
                                center: .topLeading,
                                startRadius: 20,
                                endRadius: 220
                            )
                        )
                        .frame(width: 180, height: 180)
                        .shadow(color: currentMood.color.opacity(0.45), radius: 30, y: 14)

                    Text(currentMood.label)
                        .editorialMD()
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .contentTransition(.opacity)
                        .id("label-\(moodIndex)")
                }
                .frame(maxWidth: .infinity)
                .animation(.easeInOut(duration: 0.6), value: moodIndex)

                VStack(spacing: 14) {
                    Text(NSLocalizedString("onboarding.promise.title", comment: ""))
                        .displayLG()
                        .multilineTextAlignment(.center)
                        .foregroundColor(ONETokens.oneInk)
                        .lineSpacing(4)
                        .tracking(-0.6)

                    Text(NSLocalizedString("onboarding.promise.sub", comment: ""))
                        .monoBase()
                        .multilineTextAlignment(.center)
                        .foregroundColor(ONETokens.oneAsh)
                        .lineSpacing(6)
                        .padding(.horizontal, 12)
                }
            }
            .frame(maxWidth: .infinity)
            .opacity(contentOpacity)

            Spacer()

            PrimaryButton(title: NSLocalizedString("onboarding.continueShort", comment: ""), action: goToNext)
                .padding(.bottom, 56)
                .opacity(contentOpacity)
        }
        .padding(.horizontal, 28)
        .onAppear {
            withAnimation(.easeOut(duration: 0.6).delay(0.1)) {
                contentOpacity = 1
            }
            timerCancellable = Timer.publish(every: 1.2, on: .main, in: .common)
                .autoconnect()
                .sink { _ in
                    withAnimation(.easeInOut(duration: 0.6)) {
                        moodIndex = (moodIndex + 1) % cycleMoods.count
                    }
                }
        }
        .onDisappear {
            timerCancellable?.cancel()
            timerCancellable = nil
        }
    }
}

// MARK: - 3. Tutorial Intro
private struct TutorialIntroPage: View {
    let goBack: () -> Void
    let goToNext: () -> Void

    @State private var mascotOpacity: Double = 0
    @State private var titleOpacity: Double = 0
    @State private var stepsOpacity: Double = 0
    @State private var ctaOpacity: Double = 0

    private struct TutorialStep {
        let number: String
        let title: String
        let body: String
    }
    private var steps: [TutorialStep] {
        [
            .init(number: "1", title: NSLocalizedString("onboarding.tutorial.step1.title", comment: ""),
                  body: NSLocalizedString("onboarding.tutorial.step1.body", comment: "")),
            .init(number: "2", title: NSLocalizedString("onboarding.tutorial.step2.title", comment: ""),
                  body: NSLocalizedString("onboarding.tutorial.step2.body", comment: "")),
            .init(number: "3", title: NSLocalizedString("onboarding.tutorial.step3.title", comment: ""),
                  body: NSLocalizedString("onboarding.tutorial.step3.body", comment: "")),
        ]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            BackButton(action: goBack)
                .padding(.top, 56)

            Spacer()

            VStack(alignment: .leading, spacing: 28) {
                OneMascotView(pose: .oneMusic, size: 96)
                    .opacity(mascotOpacity)

                VStack(alignment: .leading, spacing: 10) {
                    Text(NSLocalizedString("onboarding.tutorial.intro.title", comment: ""))
                        .displayLG()
                        .foregroundColor(ONETokens.oneInk)
                        .lineSpacing(4)
                        .tracking(-0.7)

                    Text(NSLocalizedString("onboarding.tutorial.intro.sub", comment: ""))
                        .monoBase()
                        .foregroundColor(ONETokens.oneAsh)
                        .lineSpacing(6)
                }
                .opacity(titleOpacity)

                VStack(alignment: .leading, spacing: 18) {
                    ForEach(Array(steps.enumerated()), id: \.offset) { idx, s in
                        HStack(alignment: .top, spacing: 14) {
                            ZStack {
                                Circle()
                                    .fill(ONETokens.oneInk)
                                    .frame(width: 28, height: 28)
                                Text(s.number)
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(ONETokens.oneCream)
                            }

                            VStack(alignment: .leading, spacing: 2) {
                                Text(s.title)
                                    .bodySMMedium()
                                    .foregroundColor(ONETokens.oneInk)
                                Text(s.body)
                                    .monoSM()
                                    .foregroundColor(ONETokens.oneAsh)
                            }
                            Spacer()
                        }
                        .opacity(stepsOpacity)
                        .offset(y: stepsOpacity == 1 ? 0 : 12)
                        .animation(
                            .easeOut(duration: 0.45).delay(0.05 * Double(idx)),
                            value: stepsOpacity
                        )
                    }
                }
                .padding(.top, 4)
            }

            Spacer()

            PrimaryButton(title: NSLocalizedString("onboarding.tutorial.intro.cta", comment: ""), action: goToNext)
                .padding(.bottom, 56)
                .opacity(ctaOpacity)
        }
        .padding(.horizontal, 28)
        .onAppear {
            withAnimation(.easeOut(duration: 0.5).delay(0.1)) { mascotOpacity = 1 }
            withAnimation(.easeOut(duration: 0.5).delay(0.25)) { titleOpacity = 1 }
            withAnimation(.easeOut(duration: 0.5).delay(0.4)) { stepsOpacity = 1 }
            withAnimation(.easeOut(duration: 0.5).delay(0.85)) { ctaOpacity = 1 }
        }
    }
}

// MARK: - 4. Tutorial: Mood Pick (interactive)
private struct TutorialMoodPickPage: View {
    @Binding var selectedMood: ONEMood?
    let goBack: () -> Void
    let goToNext: () -> Void

    @State private var contentOpacity: Double = 0
    private let columns = [GridItem(.adaptive(minimum: 64, maximum: 80), spacing: 14)]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            BackButton(action: goBack)
                .padding(.top, 56)

            Spacer().frame(height: 8)

            VStack(alignment: .leading, spacing: 14) {
                StepBadge(text: NSLocalizedString("onboarding.tutorial.stepBadge.1", comment: ""))

                Text(NSLocalizedString("onboarding.moodPick.title", comment: ""))
                    .displayLG()
                    .foregroundColor(ONETokens.oneInk)
                    .lineSpacing(4)
                    .tracking(-0.7)

                Text(NSLocalizedString("onboarding.moodPick.sub", comment: ""))
                    .monoBase()
                    .foregroundColor(ONETokens.oneAsh)
                    .lineSpacing(6)
            }

            LazyVGrid(columns: columns, spacing: 14) {
                ForEach(Array(ONEMood.allCases.enumerated()), id: \.element) { idx, mood in
                    MoodSwatch(mood: mood, isSelected: selectedMood == mood) {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                            selectedMood = mood
                        }
                    }
                    .opacity(contentOpacity)
                    .scaleEffect(contentOpacity == 1 ? 1 : 0.85)
                    .animation(
                        .spring(response: 0.5, dampingFraction: 0.75)
                            .delay(0.04 * Double(idx)),
                        value: contentOpacity
                    )
                }
            }
            .padding(.top, 28)

            if let mood = selectedMood {
                HStack(spacing: 8) {
                    Circle().fill(mood.color).frame(width: 10, height: 10)
                    Text(mood.label.capitalized)
                        .bodySMMedium()
                        .foregroundColor(ONETokens.oneInk)
                    Text("·")
                        .foregroundColor(ONETokens.oneAsh)
                    Text(mood.meaning)
                        .monoSM()
                        .foregroundColor(ONETokens.oneAsh)
                }
                .padding(.top, 18)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }

            Spacer()

            PrimaryButton(
                title: NSLocalizedString("onboarding.moodPick.continue", comment: ""),
                action: goToNext,
                disabled: selectedMood == nil
            )
            .padding(.bottom, 56)
            .opacity(contentOpacity)
        }
        .padding(.horizontal, 28)
        .onAppear {
            withAnimation(.easeOut(duration: 0.4)) {
                contentOpacity = 1
            }
        }
    }
}

private struct MoodSwatch: View {
    let mood: ONEMood
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Circle()
                    .fill(mood.color)
                    .frame(width: 52, height: 52)
                    .overlay(
                        Circle()
                            .stroke(ONETokens.oneInk, lineWidth: isSelected ? 2.5 : 0)
                            .padding(-3)
                    )
                    .scaleEffect(isSelected ? 1.08 : 1.0)
                    .shadow(color: mood.color.opacity(isSelected ? 0.45 : 0.0), radius: 12, y: 5)

                Text(mood.label)
                    .font(.system(size: 10, weight: isSelected ? .semibold : .regular))
                    .foregroundColor(isSelected ? ONETokens.oneInk : ONETokens.oneAsh)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
        }
        .accessibilityLabel(mood.label)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}

// MARK: - 5. Tutorial: Reveal Card
private struct TutorialRevealPage: View {
    let mood: ONEMood
    let goToNext: () -> Void

    @State private var cardOpacity: Double = 0
    @State private var cardScale: CGFloat = 0.88
    @State private var cardRotation: Double = -3
    @State private var titleOpacity: Double = 0
    @State private var subOpacity: Double = 0
    @State private var ctaOpacity: Double = 0
    @State private var sparkle: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer().frame(height: 56)

            HStack {
                StepBadge(text: NSLocalizedString("onboarding.tutorial.stepBadge.2", comment: ""))
                Spacer()
            }

            Spacer()

            // The "magic" share card
            ZStack {
                // Sparkle decoration
                ForEach(0..<6, id: \.self) { i in
                    Circle()
                        .fill(.white)
                        .frame(width: 4, height: 4)
                        .offset(
                            x: [-90, 100, -120, 110, -70, 130][i],
                            y: [-180, -160, -50, -40, 60, 90][i]
                        )
                        .opacity(sparkle ? 0.85 : 0)
                        .scaleEffect(sparkle ? 1 : 0.4)
                        .animation(
                            .easeOut(duration: 0.7).delay(0.4 + Double(i) * 0.06),
                            value: sparkle
                        )
                }

                MoodPreviewCard(mood: mood)
                    .frame(maxWidth: 280)
                    .scaleEffect(cardScale)
                    .rotationEffect(.degrees(cardRotation))
                    .opacity(cardOpacity)
                    .shadow(color: mood.color.opacity(0.35), radius: 36, y: 18)
            }
            .frame(maxWidth: .infinity)

            Spacer()

            VStack(alignment: .leading, spacing: 12) {
                Text(NSLocalizedString("onboarding.reveal.title", comment: ""))
                    .displayLG()
                    .foregroundColor(ONETokens.oneInk)
                    .lineSpacing(4)
                    .tracking(-0.7)
                    .opacity(titleOpacity)

                Text(NSLocalizedString("onboarding.reveal.sub", comment: ""))
                    .monoBase()
                    .foregroundColor(ONETokens.oneAsh)
                    .lineSpacing(6)
                    .opacity(subOpacity)
            }

            PrimaryButton(title: NSLocalizedString("onboarding.reveal.continue", comment: ""), action: goToNext)
                .padding(.top, 24)
                .padding(.bottom, 56)
                .opacity(ctaOpacity)
        }
        .padding(.horizontal, 28)
        .onAppear {
            withAnimation(.spring(response: 0.7, dampingFraction: 0.72).delay(0.1)) {
                cardOpacity = 1
                cardScale = 1
                cardRotation = 0
            }
            withAnimation(.easeOut(duration: 0.5).delay(0.55)) { titleOpacity = 1 }
            withAnimation(.easeOut(duration: 0.5).delay(0.7))  { subOpacity = 1 }
            withAnimation(.easeOut(duration: 0.5).delay(0.9))  { ctaOpacity = 1 }
            sparkle = true
        }
    }
}

private struct MoodPreviewCard: View {
    let mood: ONEMood

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 28)
                .fill(
                    LinearGradient(
                        colors: [mood.color.opacity(0.95), mood.color.opacity(0.55)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .aspectRatio(0.72, contentMode: .fit)

            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("ONE")
                        .monoSM(tracking: 1.6)
                        .foregroundColor(.white.opacity(0.85))
                    Spacer()
                    Text(currentDateString())
                        .monoLabel()
                        .foregroundColor(.white.opacity(0.7))
                }
                Spacer()
                Text(mood.label)
                    .editorialLG()
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                Text(mood.meaning)
                    .monoBase(tracking: 0.1)
                    .foregroundColor(.white.opacity(0.85))
            }
            .padding(24)
        }
    }

    private func currentDateString() -> String {
        let f = DateFormatter()
        f.dateFormat = "d MMM"
        f.locale = Locale.current
        return f.string(from: Date()).uppercased()
    }
}

// MARK: - 6. Music Permission
private struct MusicPermissionPage: View {
    let goBack: () -> Void
    let goToNext: () -> Void

    @State private var contentOpacity: Double = 0
    @State private var isConnecting = false
    @State private var musicConnected = false
    @State private var showDeniedAlert = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            BackButton(action: goBack)
                .padding(.top, 56)

            Spacer().frame(height: 8)

            VStack(alignment: .leading, spacing: 14) {
                Text(NSLocalizedString("onboarding.music.title", comment: ""))
                    .displayLG()
                    .foregroundColor(ONETokens.oneInk)
                    .lineSpacing(4)
                    .tracking(-0.7)

                Text(NSLocalizedString("onboarding.music.sub", comment: ""))
                    .monoBase()
                    .foregroundColor(ONETokens.oneAsh)
                    .lineSpacing(6)
            }

            ServiceButton(
                icon: "♪",
                iconBg: "#FC3C44",
                name: "Apple Music",
                desc: musicConnected ? NSLocalizedString("onboarding.connected", comment: "") : NSLocalizedString("onboarding.noSubscriptionHint", comment: ""),
                action: connectAppleMusic,
                isConnected: musicConnected
            )
            .padding(.top, 28)

            VStack(alignment: .leading, spacing: 10) {
                InfoPill(icon: "checkmark.circle.fill", color: ONETokens.oneSystemRed,
                         text: NSLocalizedString("onboarding.noSubscriptionRequired", comment: ""))
                InfoPill(icon: "lock.fill", color: ONETokens.oneAsh,
                         text: NSLocalizedString("onboarding.noDataSelling", comment: ""))
                InfoPill(icon: "music.note", color: ONETokens.oneStone,
                         text: NSLocalizedString("onboarding.spotifyAlsoWorks", comment: ""))
            }
            .padding(.top, 20)

            Spacer()

            VStack(spacing: 10) {
                // P1.1 — Müzik bağlama opsiyonel. Connected state'te primary "Başla";
                // değilse primary "Bağla ve Başla" + secondary "Şimdilik geç" — kullanıcı
                // bilinçli karar versin, friction permission ekranındakine düşmesin.
                PrimaryButton(
                    title: musicConnected
                        ? NSLocalizedString("onboarding.startConnected", comment: "")
                        : NSLocalizedString("onboarding.music.connectAndStart", comment: ""),
                    action: musicConnected ? goToNext : connectAppleMusic,
                    fillColor: musicConnected ? ONETokens.oneSystemRed : ONETokens.oneInk
                )

                if !musicConnected {
                    Button(action: {
                        AppAnalytics.shared.track(.onboardingMusicConnected(granted: false))
                        goToNext()
                    }) {
                        Text(NSLocalizedString("onboarding.music.skipForNow", comment: ""))
                            .monoSM(tracking: 0.6)
                            .foregroundColor(ONETokens.oneAsh)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                    }
                    .accessibilityLabel(NSLocalizedString("onboarding.music.skipForNow", comment: ""))
                }
            }
            .padding(.bottom, 56)
        }
        .padding(.horizontal, 28)
        .opacity(contentOpacity)
        .onAppear {
            withAnimation(.easeOut(duration: 0.45)) { contentOpacity = 1 }
            if UserDefaults.standard.string(forKey: "preferredMusicService") == "AppleMusic" {
                musicConnected = true
            }
        }
        .alert("Apple Music", isPresented: $showDeniedAlert) {
            Button(NSLocalizedString("general.ok", comment: ""), role: .cancel) { }
        } message: {
            Text(NSLocalizedString("onboarding.appleMusicDenied", comment: ""))
        }
    }

    private func connectAppleMusic() {
        isConnecting = true
        Task {
            let status = await MusicAuthorization.request()
            await MainActor.run {
                isConnecting = false
                if status == .authorized {
                    UserDefaults.standard.set("AppleMusic", forKey: "preferredMusicService")
                    AppAnalytics.shared.track(.onboardingMusicConnected(granted: true))
                    withAnimation(.easeOut(duration: ONEAnimation.durationShort)) {
                        musicConnected = true
                    }
                } else {
                    AppAnalytics.shared.track(.onboardingMusicConnected(granted: false))
                    showDeniedAlert = true
                }
            }
        }
    }
}

// MARK: - 7. Notification Soft Ask
private struct NotificationSoftAskPage: View {
    @Binding var optIn: Bool
    let complete: () -> Void

    @State private var contentOpacity: Double = 0
    @State private var reminderTime: Date = {
        let storedHour = UserDefaults.standard.integer(forKey: "dailyReminderHour")
        var comps = DateComponents()
        comps.hour = storedHour == 0 ? 21 : storedHour
        comps.minute = UserDefaults.standard.integer(forKey: "dailyReminderMinute")
        return Calendar.current.date(from: comps) ?? Date()
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer().frame(height: 56)

            Spacer()

            VStack(alignment: .leading, spacing: 16) {
                OneMascotView(pose: .sitHi, size: 96)

                Text(NSLocalizedString("onboarding.notif.title", comment: ""))
                    .displayLG()
                    .foregroundColor(ONETokens.oneInk)
                    .lineSpacing(4)
                    .tracking(-0.7)

                Text(NSLocalizedString("onboarding.notif.sub", comment: ""))
                    .monoBase()
                    .foregroundColor(ONETokens.oneAsh)
                    .lineSpacing(6)

                // P1.6 — Streak freeze açıklaması. Kullanıcı bir gün
                // kaçırdığında serisi sıfırlanmaz; haftada bir freeze hediye.
                // Kayıp korkusu yumuşar → dönüş cesareti artar.
                HStack(spacing: 8) {
                    Image(systemName: "snowflake")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(ONETokens.oneBrand)
                    Text(NSLocalizedString("onboarding.notif.freezeHint", comment: ""))
                        .monoSM(tracking: 0.4)
                        .foregroundColor(ONETokens.oneStone)
                        .lineSpacing(3)
                }
                .padding(.top, 4)

                HStack {
                    Text(NSLocalizedString("onboarding.notif.reminderTime", comment: ""))
                        .monoSM(tracking: 0.4)
                        .foregroundColor(ONETokens.oneStone)
                    Spacer()
                    DatePicker("", selection: $reminderTime, displayedComponents: .hourAndMinute)
                        .labelsHidden()
                        .colorScheme(.light)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(ONETokens.onePaper)
                )
                .padding(.top, 4)
            }

            Spacer()

            VStack(spacing: 10) {
                Button(action: {
                    let cal = Calendar.current
                    let hour = cal.component(.hour, from: reminderTime)
                    let minute = cal.component(.minute, from: reminderTime)
                    UserDefaults.standard.set(hour, forKey: "dailyReminderHour")
                    UserDefaults.standard.set(minute, forKey: "dailyReminderMinute")
                    optIn = true
                    AppAnalytics.shared.track(.onboardingNotifSoftAsk(optIn: true))
                    complete()
                }) {
                    Text(NSLocalizedString("onboarding.notif.yes", comment: ""))
                        .bodySMMedium()
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 17)
                        .background(
                            LinearGradient(
                                colors: [ONETokens.oneBrand, ONETokens.oneBrandLight],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(16)
                }

                Button(action: {
                    optIn = false
                    AppAnalytics.shared.track(.onboardingNotifSoftAsk(optIn: false))
                    complete()
                }) {
                    Text(NSLocalizedString("onboarding.notif.no", comment: ""))
                        .monoSM(tracking: 1.4)
                        .foregroundColor(ONETokens.oneAsh)
                        .padding(.vertical, 12)
                }
            }
            .padding(.bottom, 56)
        }
        .padding(.horizontal, 28)
        .opacity(contentOpacity)
        .onAppear {
            withAnimation(.easeOut(duration: 0.45)) { contentOpacity = 1 }
        }
    }
}

// MARK: - Shared Buttons / Components

private struct PrimaryButton: View {
    let title: String
    let action: () -> Void
    var disabled: Bool = false
    var fillColor: Color = ONETokens.oneInk

    var body: some View {
        Button(action: action) {
            Text(title)
                .monoSM(tracking: 1.4)
                .foregroundColor(ONETokens.oneCream)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 17)
                .background(disabled ? ONETokens.oneAsh.opacity(0.4) : fillColor)
                .cornerRadius(16)
        }
        .disabled(disabled)
    }
}

private struct BackButton: View {
    let action: () -> Void

    var body: some View {
        HStack {
            Button(action: action) {
                Text(NSLocalizedString("onboarding.back", comment: ""))
                    .monoSM(tracking: 1.4)
                    .foregroundColor(ONETokens.oneAsh)
                    .padding(.vertical, 4)
            }
            Spacer()
        }
    }
}

private struct StepBadge: View {
    let text: String
    var body: some View {
        Text(text)
            .monoLabel()
            .tracking(1.4)
            .foregroundColor(ONETokens.oneAsh)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                Capsule().fill(ONETokens.oneCreamMid)
            )
    }
}

private struct InfoPill: View {
    let icon: String
    let color: Color
    let text: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(color)
                .frame(width: 20)
            Text(text)
                .monoSM()
                .foregroundColor(ONETokens.oneAsh)
        }
    }
}

struct ServiceButton: View {
    let icon: String
    let iconBg: String
    let name: String
    let desc: String
    let action: () -> Void
    let isConnected: Bool

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color(hex: iconBg))
                        .frame(width: 36, height: 36)

                    Text(icon)
                        .font(.system(size: 18))
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(name)
                        .monoBase(tracking: -0.1)
                        .foregroundColor(ONETokens.oneInk)
                    Text(desc)
                        .monoSM()
                        .foregroundColor(isConnected ? ONETokens.spotifyGreen : ONETokens.oneAsh)
                }

                Spacer()

                if isConnected {
                    Text("✓")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(ONETokens.spotifyGreen)
                } else {
                    Text("›")
                        .font(.system(size: 20))
                        .foregroundColor(ONETokens.oneAsh)
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
            .background(isConnected ? ONETokens.oneCreamMid.opacity(0.5) : ONETokens.oneCreamMid)
            .cornerRadius(14)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(isConnected ? ONETokens.spotifyGreen.opacity(0.3) : Color.clear, lineWidth: 2)
            )
        }
        .disabled(isConnected)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(name). \(desc)")
        .accessibilityAddTraits(isConnected ? [.isSelected] : [])
    }
}

#Preview {
    OnboardingView(isCompleted: .constant(false))
}
