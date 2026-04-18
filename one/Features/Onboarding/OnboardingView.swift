//
//  OnboardingView.swift
//  one
//
//  Inspired by HTML onboarding flow
//

import SwiftUI
import MusicKit

struct OnboardingView: View {
    @Binding var isCompleted: Bool
    @State private var currentPage = 0
    @State private var opacity: Double = 0
    
    var body: some View {
        ZStack {
            ONETokens.oneCream
                .ignoresSafeArea()
            
            TabView(selection: $currentPage) {
                // Page 1: Hoş Geldin
                MainQuestionPage(goToNext: { currentPage = 1 }, skip: completeOnboarding)
                    .tag(0)

                // Page 2: Özellikler — Müzik + Fotoğraf + Sosyal
                FeaturesOverviewPage(
                    goBack: { currentPage = 0 },
                    goToNext: { currentPage = 2 }
                )
                .tag(1)

                // Page 3: İzinler — Apple Music + Bildirimler
                PermissionsPage(goBack: { currentPage = 1 }, complete: completeOnboarding)
                    .tag(2)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
        }
        .opacity(opacity)
        .onAppear {
            withAnimation(.easeIn(duration: 0.5)) {
                opacity = 1
            }
        }
    }
    
    private func completeOnboarding() {
        // Request notification permission before completing
        NotificationManager.shared.requestAuthorization { granted in
            DispatchQueue.main.async {
                if granted {
                    let defaults = UserDefaults.standard
                    defaults.set(true, forKey: "notificationsEnabled")
                    defaults.set(true, forKey: "streakNotificationsEnabled")
                    defaults.set(true, forKey: "weeklySummaryEnabled")
                    defaults.set(true, forKey: "discoveryNotificationsEnabled")

                    // Varsayılan hatırlatıcı saati 20:00
                    var components = DateComponents()
                    components.hour   = defaults.integer(forKey: "dailyReminderHour") == 0 ? 20 : defaults.integer(forKey: "dailyReminderHour")
                    components.minute = defaults.integer(forKey: "dailyReminderMinute")
                    if components.hour == 0 { components.hour = 20 }

                    if let defaultTime = Calendar.current.date(from: components) {
                        defaults.set(components.hour,   forKey: "dailyReminderHour")
                        defaults.set(components.minute, forKey: "dailyReminderMinute")
                        NotificationManager.shared.scheduleDailyReminder(at: defaultTime)
                        NotificationManager.shared.scheduleWeeklySummary()
                    }
                }
                
                withAnimation(.easeInOut(duration: ONEAnimation.durationMedium)) {
                    isCompleted = true
                }
                KeychainHelper.set(true, forKey: "hasCompletedOnboarding")
            }
        }
    }
}

// MARK: - Main Question Page
struct MainQuestionPage: View {
    let goToNext: () -> Void
    let skip: () -> Void
    
    @State private var logoOpacity: Double = 0
    @State private var questionOpacity: Double = 0
    @State private var subOpacity: Double = 0
    @State private var ctaOpacity: Double = 0
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Mascot
            OneMascotView(pose: .oneQuestions, size: 120)
                .opacity(logoOpacity)
                .padding(.top, 14)
            
            Spacer()
            
            // Hero question
            Text(NSLocalizedString("onboarding.searchPlaceholder", comment: ""))
                .displayLG()
                .foregroundColor(ONETokens.oneInk)
                .lineSpacing(4)
                .tracking(-0.9)
                .opacity(questionOpacity)
            
            // Sub text
            Text(NSLocalizedString("onboarding.slogan", comment: ""))
                .monoBase(tracking: 0.1)
                .foregroundColor(ONETokens.oneAsh)
                .lineSpacing(6)
                .padding(.top, 14)
                .opacity(subOpacity)
            
            Spacer()
            
            // CTA group
            VStack(spacing: 10) {
                Button(action: goToNext) {
                    Text(NSLocalizedString("onboarding.connectMusic", comment: ""))
                        .tracking(-0.3)
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
                
                Button(action: skip) {
                    Text(NSLocalizedString("onboarding.later", comment: ""))
                        .monoSM(tracking: 1.4)
                        .foregroundColor(ONETokens.oneAsh)
                        .padding(.vertical, 12)
                }
                
                Text(NSLocalizedString("onboarding.notificationDesc", comment: ""))
                    .monoLabel()
                    .foregroundColor(ONETokens.oneStone)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .padding(.top, 6)
            }
            .opacity(ctaOpacity)
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 56)
        .onAppear {
            withAnimation(.easeOut(duration: ONEAnimation.durationLong).delay(0.1)) {
                logoOpacity = 1
            }
            withAnimation(.easeOut(duration: ONEAnimation.durationLong).delay(0.2)) {
                questionOpacity = 1
            }
            withAnimation(.easeOut(duration: ONEAnimation.durationLong).delay(0.35)) {
                subOpacity = 1
            }
            withAnimation(.easeOut(duration: ONEAnimation.durationLong).delay(0.5)) {
                ctaOpacity = 1
            }
        }
    }
}

// MARK: - Features Overview Page (Müzik + Fotoğraf + Sosyal)
struct FeaturesOverviewPage: View {
    let goBack: () -> Void
    let goToNext: () -> Void

    @State private var opacity: Double = 0
    @State private var contentOffset: CGFloat = 20

    private var features: [(icon: String, title: String, desc: String)] {
        [
            ("music.note", NSLocalizedString("onboarding.feature.dailySong", comment: ""), NSLocalizedString("onboarding.feature.dailySongDesc", comment: "")),
            ("camera.fill", NSLocalizedString("onboarding.feature.photoMood", comment: ""), NSLocalizedString("onboarding.feature.photoMoodDesc", comment: "")),
            ("person.2.fill", NSLocalizedString("onboarding.feature.circle", comment: ""), NSLocalizedString("onboarding.feature.circleDesc", comment: "")),
            ("sparkles", NSLocalizedString("onboarding.feature.discover", comment: ""), NSLocalizedString("onboarding.feature.discoverDesc", comment: ""))
        ]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: goBack) {
                Text(NSLocalizedString("onboarding.back", comment: ""))
                    .monoSM(tracking: 1.4)
                    .foregroundColor(ONETokens.oneAsh)
                    .padding(.vertical, 4)
            }
            .padding(.top, 14)

            Spacer()

            VStack(alignment: .leading, spacing: 28) {
                OneMascotView(pose: .oneMusic, size: 100)

                Text(NSLocalizedString("onboarding.howItWorks", comment: ""))
                    .displayLG()
                    .foregroundColor(ONETokens.oneInk)
                    .lineSpacing(4)
                    .tracking(-0.75)

                VStack(alignment: .leading, spacing: 16) {
                    ForEach(Array(features.enumerated()), id: \.offset) { index, feature in
                        HStack(spacing: 14) {
                            ZStack {
                                Circle()
                                    .fill(ONETokens.oneCreamMid)
                                    .frame(width: 40, height: 40)
                                Image(systemName: feature.icon)
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(ONETokens.oneInk)
                            }

                            VStack(alignment: .leading, spacing: 2) {
                                Text(feature.title)
                                    .bodySMMedium()
                                    .foregroundColor(ONETokens.oneInk)
                                Text(feature.desc)
                                    .monoSM()
                                    .foregroundColor(ONETokens.oneAsh)
                            }
                        }
                    }
                }
            }
            .offset(y: contentOffset)

            Spacer()

            Button(action: goToNext) {
                Text(NSLocalizedString("onboarding.serviceConnections", comment: ""))
                    .monoSM(tracking: 1.4)
                    .foregroundColor(ONETokens.oneCream)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 17)
                    .background(ONETokens.oneInk)
                    .cornerRadius(16)
            }
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 56)
        .opacity(opacity)
        .onAppear {
            withAnimation(.easeOut(duration: ONEAnimation.durationMedium)) {
                opacity = 1
                contentOffset = 0
            }
        }
    }
}

// MARK: - Permissions Page (Apple Music + Bildirimler)
struct PermissionsPage: View {
    let goBack: () -> Void
    let complete: () -> Void

    @State private var opacity: Double = 0
    @State private var contentOffset: CGFloat = 20
    @State private var isConnectingMusic = false
    @State private var musicConnected = false
    @State private var showDeniedAlert = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: goBack) {
                Text(NSLocalizedString("onboarding.back", comment: ""))
                    .monoSM(tracking: 1.4)
                    .foregroundColor(ONETokens.oneAsh)
                    .padding(.vertical, 4)
            }
            .padding(.top, 14)

            Spacer()

            VStack(alignment: .leading, spacing: 0) {
                Text(NSLocalizedString("onboarding.lastStep", comment: ""))
                    .displayLG()
                    .foregroundColor(ONETokens.oneInk)
                    .lineSpacing(4)
                    .tracking(-0.75)

                Text(NSLocalizedString("onboarding.connectDesc", comment: ""))
                    .monoBase()
                    .foregroundColor(ONETokens.oneAsh)
                    .lineSpacing(6)
                    .padding(.top, 12)

                // Apple Music
                VStack(alignment: .leading, spacing: 16) {
                    ServiceButton(
                        icon: "♪",
                        iconBg: "#FC3C44",
                        name: "Apple Music",
                        desc: musicConnected ? NSLocalizedString("onboarding.connected", comment: "") : NSLocalizedString("onboarding.noSubscriptionHint", comment: ""),
                        action: connectAppleMusic,
                        isConnected: musicConnected
                    )
                }
                .padding(.top, 28)

                // Info pills
                VStack(alignment: .leading, spacing: 10) {
                    InfoPill(icon: "checkmark.circle.fill", color: Color(hex: "#FC3C44"),
                             text: NSLocalizedString("onboarding.noSubscriptionRequired", comment: ""))
                    InfoPill(icon: "lock.fill", color: ONETokens.oneAsh,
                             text: NSLocalizedString("onboarding.noDataSelling", comment: ""))
                }
                .padding(.top, 20)
            }
            .offset(y: contentOffset)

            Spacer()

            VStack(spacing: 10) {
                Button(action: complete) {
                    Text(musicConnected ? NSLocalizedString("onboarding.startConnected", comment: "") : NSLocalizedString("onboarding.start", comment: ""))
                        .monoSM(tracking: 1.4)
                        .foregroundColor(ONETokens.oneCream)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 17)
                        .background(
                            musicConnected
                                ? Color(hex: "#FC3C44")
                                : ONETokens.oneInk
                        )
                        .cornerRadius(16)
                }

                if !musicConnected {
                    Text(NSLocalizedString("onboarding.spotifySettings", comment: ""))
                        .monoLabel()
                        .foregroundColor(ONETokens.oneStone)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 4)
                }
            }
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 56)
        .opacity(opacity)
        .onAppear {
            withAnimation(.easeOut(duration: ONEAnimation.durationMedium)) {
                opacity = 1
                contentOffset = 0
            }
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
        isConnectingMusic = true
        Task {
            let status = await MusicAuthorization.request()
            await MainActor.run {
                isConnectingMusic = false
                if status == .authorized {
                    UserDefaults.standard.set("AppleMusic", forKey: "preferredMusicService")
                    withAnimation(.easeOut(duration: ONEAnimation.durationShort)) {
                        musicConnected = true
                    }
                } else {
                    showDeniedAlert = true
                }
            }
        }
    }
}

// MARK: - Info Pill
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

// MARK: - Service Button
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
                // Icon
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color(hex: iconBg))
                        .frame(width: 36, height: 36)
                    
                    Text(icon)
                        .font(.system(size: 18))
                }
                
                // Info
                VStack(alignment: .leading, spacing: 2) {
                    Text(name)
                        .monoBase(tracking: -0.1)
                        .foregroundColor(ONETokens.oneInk)
                    
                    Text(desc)
                        .monoSM()
                        .foregroundColor(isConnected ? ONETokens.spotifyGreen : ONETokens.oneAsh)
                }
                
                Spacer()
                
                // Arrow or Checkmark
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
    }
}

#Preview {
    OnboardingView(isCompleted: .constant(false))
}
