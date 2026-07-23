//
//  TodayCompletedView.swift
//  One - Günlük Mood
//
//  Kaydedildi ekranının orkestrasyonu. Parçalar ayrı dosyalarda:
//  • CompletedHeroHeader  — streak chip + "senin rengin: X" + freeze + ritim
//  • CompletedEntryCard   — foto/mood başlığı + şarkı bilgisi + eylemler
//  • Push/Widget banner + PassedDayView — TodayCompletedNudges.swift
//  • PhotoViewerSheet     — tam ekran fotoğraf görüntüleyici
//
//  Bu dosya yalnızca sırayı, streak count-up animasyonunu ve arkadaş
//  akışı / bildirim durumu gibi ekran düzeyi state'i tutar.
//

import SwiftUI
import CloudKit
import CoreData
import UserNotifications

struct TodayCompletedView: View {
    let entry: DailyEntry

    let onEdit: () -> Void
    let streakDays: Int
    let isFreezeActive: Bool
    /// Kayıt sonrası opsiyonel ekler. `onEdit`'ten farklı: o yıkıcı (clearToday),
    /// bunlar mevcut entry'yi bozmadan alan ekler.
    let onAddPhoto: (() -> Void)?
    let onAddNote: (() -> Void)?
    /// Faz 3 — haftalık ritim. Boşsa satır hiç çizilmez.
    let weekRhythm: [WeekRhythm.Day]
    /// Telafi edilebilir bir güne dokunulduğunda ritüeli o gün için açar.
    let onBackfill: ((Date) -> Void)?
    /// Prototipteki "frekansa dön". nil ise buton hiç çizilmez.
    let onReturnToCircle: (() -> Void)?

    init(entry: DailyEntry,
         onEdit: @escaping () -> Void,
         streakDays: Int = 0,
         isFreezeActive: Bool = false,
         onAddPhoto: (() -> Void)? = nil,
         onAddNote: (() -> Void)? = nil,
         weekRhythm: [WeekRhythm.Day] = [],
         onBackfill: ((Date) -> Void)? = nil,
         onReturnToCircle: (() -> Void)? = nil) {
        self.entry = entry
        self.onEdit = onEdit
        self.streakDays = streakDays
        self.isFreezeActive = isFreezeActive
        self.onAddPhoto = onAddPhoto
        self.onAddNote = onAddNote
        self.weekRhythm = weekRhythm
        self.onBackfill = onBackfill
        self.onReturnToCircle = onReturnToCircle
    }

    @ObservedObject private var globalUI = GlobalUIState.shared
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false
    @State private var displayedStreak: Int = 0
    @State private var streakFlamePulse: CGFloat = 0.85
    @State private var showPhotoViewer = false
    @State private var friendShares: [CloudKitManager.FriendCircleData] = []
    @State private var friendsLoading = true
    @State private var friendsFetchFailed = false
    /// B5 — nudge'lar kalıcı olarak kapatıldı mı?
    @State private var widgetNudgeDismissed: Bool = UserDefaults.standard.bool(forKey: "widgetNudgeDismissed")
    @State private var pushSoftAskDismissed: Bool = UserDefaults.standard.bool(forKey: "pushSoftAskDismissed")
    @State private var notifStatus: UNAuthorizationStatus = .notDetermined
    @State private var countUpTask: Task<Void, Never>?

    var body: some View {
        // #10 — Pas günü: minimal tamamlandı ekranı
        if entry.passed {
            PassedDayView(onEdit: onEdit)
        } else {
            mainCompletedBody
        }
    }

    @ViewBuilder
    private var mainCompletedBody: some View {
        GeometryReader { geo in
            let available = geo.size.height
            ZStack {
                ONETokens.oneCream.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        CompletedHeroHeader(
                            entry: entry,
                            streakDays: streakDays,
                            displayedStreak: displayedStreak,
                            streakFlamePulse: streakFlamePulse,
                            isFreezeActive: isFreezeActive,
                            weekRhythm: weekRhythm,
                            onBackfill: onBackfill,
                            available: available
                        )

                        CompletedEntryCard(
                            entry: entry,
                            available: available,
                            onEdit: onEdit,
                            onAddPhoto: onAddPhoto,
                            onAddNote: onAddNote,
                            showPhotoViewer: $showPhotoViewer
                        )
                        .padding(.horizontal, 20)
                        .scaleEffect(appeared ? 1 : 0.94)
                        .opacity(appeared ? 1 : 0)
                        .animation(
                            reduceMotion
                                ? .easeInOut(duration: 0.2).delay(0.2)
                                : ONEAnimation.panelSpring.delay(0.2),
                            value: appeared
                        )

                        // Prototipteki kapanış: ayraç + "frekansa dön".
                        // Bu ekranda hiç çıkış kontrolü yoktu — kullanıcı ancak
                        // sekme çubuğundan kaçabiliyordu.
                        if let onReturnToCircle {
                            Rectangle()
                                .fill(ONETokens.oneInk.opacity(0.09))
                                .frame(height: 1)
                                .padding(.horizontal, ONETokens.spacingXL2)
                                .padding(.top, ONETokens.spacingXL)

                            Button(action: onReturnToCircle) {
                                Text(NSLocalizedString("today.backToFrequency", comment: ""))
                                    .bodySMMedium()
                                    .foregroundColor(ONETokens.oneInk)
                                    .frame(maxWidth: .infinity, minHeight: 44)
                                    .background(
                                        Capsule(style: .continuous)
                                            .stroke(ONETokens.oneInk.opacity(0.14), lineWidth: 1.5)
                                    )
                            }
                            .buttonStyle(.plain)
                            .padding(.horizontal, ONETokens.spacingXL2)
                            .padding(.top, ONETokens.spacingXL)
                        }

                        // Buradan aşağısı prototipte yok: gerçek özellikler,
                        // ama prototipin kapanışından SONRA. Ekran yukarıdan
                        // aşağı prototip gibi okunsun, hiçbir şey kaybolmasın.

                        // Kendi paylaşımıma gelen yorumlar — v3
                        if CommentsFeatureFlag.isEnabled,
                           let myUserID = CloudKitManager.shared.currentUser?["userID"] as? String,
                           entry.shareWithCircle {
                            CommentEntryButton(
                                shareOwnerID: myUserID,
                                accentColorHex: entry.moodColorHex,
                                resolveShareRecordName: { completion in
                                    CloudKitManager.shared.fetchOwnDailyShareRecordName(date: entry.date, completion: completion)
                                }
                            )
                            .padding(.top, 14)
                            .padding(.horizontal, 20)
                            .opacity(appeared ? 1 : 0)
                            .animation(
                                reduceMotion
                                    ? .easeInOut(duration: 0.2).delay(0.28)
                                    : ONEAnimation.panelSpring.delay(0.28),
                                value: appeared
                            )
                        }

                        // Çevrende Bugün — friend mini feed (hidden while loading and on fetch failure)
                        if !friendsLoading && !friendsFetchFailed {
                            TodayFriendsFeedSection(
                                friendShares: friendShares,
                                onSeeAll: {
                                    NotificationManager.shared.shouldNavigateToCircle = true
                                },
                                onFriendTap: { _ in
                                    NotificationManager.shared.shouldNavigateToCircle = true
                                }
                            )
                            .padding(.top, 18)
                            .padding(.horizontal, 20)
                            .opacity(appeared ? 1 : 0)
                            .animation(
                                reduceMotion
                                    ? .easeInOut(duration: 0.2).delay(0.42)
                                    : ONEAnimation.panelSpring.delay(0.42),
                                value: appeared
                            )
                        }

                        // B5 — Widget kurulum nudge'ı (ilk birkaç gün için, dismissable)
                        if !widgetNudgeDismissed {
                            WidgetNudgeBanner(dismissed: $widgetNudgeDismissed)
                                .padding(.top, 14)
                                .padding(.horizontal, 20)
                                .opacity(appeared ? 1 : 0)
                                .animation(
                                    reduceMotion
                                        ? .easeInOut(duration: 0.2).delay(0.42)
                                        : ONEAnimation.panelSpring.delay(0.42),
                                    value: appeared
                                )
                        }

                        // Push bildirim soft-ask — yalnızca izin verilmemiş ve henüz reddedilmemişse
                        if !pushSoftAskDismissed && notifStatus == .notDetermined {
                            PushSoftAskBanner(dismissed: $pushSoftAskDismissed)
                                .padding(.top, 10)
                                .padding(.horizontal, 20)
                                .opacity(appeared ? 1 : 0)
                                .animation(
                                    reduceMotion
                                        ? .easeInOut(duration: 0.2).delay(0.5)
                                        : ONEAnimation.panelSpring.delay(0.5),
                                    value: appeared
                                )
                        }

                        Spacer().frame(height: 24)
                    }
                }
            }
        }
        .onChange(of: showPhotoViewer) { _, show in
            if show {
                GlobalUIState.shared.todayPhotoURL = entry.photoURL
            }
        }
        .onChange(of: globalUI.todayPhotoURL) { _, newURL in
            if newURL == nil { showPhotoViewer = false }
        }
        .onAppear {
            // Streak reveal (one-shot)
            let todayKey = ISO8601DateFormatter().string(from: Calendar.current.startOfDay(for: Date()))
            let shownKey = "rewardShownDate"
            let alreadyShown = UserDefaults.standard.string(forKey: shownKey) == todayKey

            if !alreadyShown && !reduceMotion {
                // Watch-tarzı adım adım count-up: birden fazla günse geriden başla
                let tickStart   = streakDays > 3 ? max(0, streakDays - 5) : 0
                let tickSteps   = streakDays - tickStart
                let isMilestone = [1, 3, 7, 14, 30, 50, 100, 200, 365].contains(streakDays)
                displayedStreak = tickStart

                // tickSteps == 0 koruması: streak 0'ken yanlış state'e düşmeyi önler
                if tickSteps > 0 {
                    countUpTask = Task { @MainActor in
                        for step in 1...tickSteps {
                            // Açık Double ara değişken: karışık Int/Double literal
                            // aritmetiğini tek UInt64 init'ine gömmek tip
                            // denetleyicisini saniyelerce oyalıyordu.
                            let seconds: Double = 0.15 + Double(step - 1) * 0.09
                            try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                            guard !Task.isCancelled else { return }
                            displayedStreak = tickStart + step
                            withAnimation(.spring(response: 0.18, dampingFraction: 0.52)) {
                                streakFlamePulse = 1.14
                            }
                            withAnimation(.spring(response: 0.22, dampingFraction: 0.78).delay(0.09)) {
                                streakFlamePulse = 1.0
                            }
                            if step < tickSteps {
                                UIImpactFeedbackGenerator(style: .light).impactOccurred(intensity: 0.4)
                            }
                        }
                        // Son adım: kutlama haptic + büyük bounce
                        let finalSeconds: Double = 0.15 + Double(tickSteps - 1) * 0.09 + 0.12
                        try? await Task.sleep(nanoseconds: UInt64(finalSeconds * 1_000_000_000))
                        guard !Task.isCancelled else { return }
                        withAnimation(.spring(response: 0.30, dampingFraction: 0.48)) {
                            streakFlamePulse = 1.28
                        }
                        withAnimation(.spring(response: 0.30, dampingFraction: 0.72).delay(0.20)) {
                            streakFlamePulse = 1.0
                        }
                        ONEHaptics.streakRevealed(isMilestone: isMilestone)
                    }
                } else {
                    // Tek adım (streak == 1 veya tickStart == streakDays)
                    displayedStreak = streakDays
                    ONEHaptics.streakRevealed(isMilestone: isMilestone)
                }

                UserDefaults.standard.set(todayKey, forKey: shownKey)
            } else {
                displayedStreak = streakDays
                streakFlamePulse = 1.0
            }

            withAnimation(ONEAnimation.screenTransition) { appeared = true }
        }
        .task {
            let settings = await UNUserNotificationCenter.current().notificationSettings()
            notifStatus = settings.authorizationStatus
            CloudKitManager.shared.fetchFriendsDailyShares(for: Date()) { result in
                DispatchQueue.main.async {
                    friendsLoading = false
                    switch result {
                    case .success(let shares):
                        friendShares = shares.filter { $0.share != nil }
                    case .failure:
                        friendsFetchFailed = true
                    }
                }
            }
        }
        .onDisappear {
            countUpTask?.cancel()
            countUpTask = nil
        }
    }
}
