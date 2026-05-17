//
//  TodayCompletedView.swift
//  One - Günlük Mood
//
//  Enhanced with swift-ios-skills patterns:
//  - Performance: Precomputed values, minimal body recomputation, GPU rendering
//  - Accessibility: Proper labels, hints, traits, Dynamic Type support
//  - Gestures: Modern MagnifyGesture (iOS 17+) with @GestureState
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

    init(entry: DailyEntry,
         onEdit: @escaping () -> Void,
         streakDays: Int = 0,
         isFreezeActive: Bool = false) {
        self.entry = entry
        self.onEdit = onEdit
        self.streakDays = streakDays
        self.isFreezeActive = isFreezeActive
    }

    @ObservedObject private var globalUI = GlobalUIState.shared
    @Environment(\.managedObjectContext) private var viewContext
    @State private var appeared = false
    @State private var displayedStreak: Int = 0
    @State private var streakFlamePulse: CGFloat = 0.85
    @State private var rewardShown = false
    @State private var streakChipPulse: Bool = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showPhotoViewer = false
    @State private var friendShares: [CloudKitManager.FriendCircleData] = []
    @State private var friendsLoading = true
    @State private var friendsFetchFailed = false
    @State private var showShareOptions = false
    @State private var showChangeConfirm = false
    @State private var photoSaved = false
    /// B5 — Widget kurulum nudge'ı kalıcı olarak kapatıldı mı?
    @State private var widgetNudgeDismissed: Bool = UserDefaults.standard.bool(forKey: "widgetNudgeDismissed")
    @State private var pushSoftAskDismissed: Bool = UserDefaults.standard.bool(forKey: "pushSoftAskDismissed")
    @State private var notifStatus: UNAuthorizationStatus = .notDetermined
    @State private var thisWeekEntries: [(date: Date, moodColorHex: String)] = []
    @State private var countUpTask: Task<Void, Never>?

    private var displayedEntry: DailyEntry { entry }

    // MARK: - Dynamic sizing helpers

    /// Photo height: ~23 % of available height, hard-capped at 175 pt.
    private func photoHeight(available: CGFloat) -> CGFloat {
        max(90, min(175, available * 0.23))
    }

    /// Header top padding: scales 10–32 pt.
    private func headerTopPad(available: CGFloat) -> CGFloat {
        max(10, min(32, available * 0.038))
    }

    /// Header bottom padding: scales 8–16 pt.
    private func headerBottomPad(available: CGFloat) -> CGFloat {
        max(8, min(16, available * 0.02))
    }

    /// Hide the subtitle hint on very compact screens to save vertical space.
    private func showSubtitle(available: CGFloat) -> Bool { available > 600 }

    var body: some View {
        GeometryReader { geo in
        let available = geo.size.height
        ZStack {
            // Background
            ONETokens.oneCream.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    // Header
                    VStack(alignment: .leading, spacing: 4) {
                        ZStack(alignment: .trailing) {
                            Text("ONE+")
                                .font(.system(size: 38, weight: .bold, design: .default))
                                .foregroundColor(ONETokens.oneInk)
                            .frame(maxWidth: .infinity)

                            if streakDays >= 1 {
                                let isMilestone = [3, 7, 14, 30, 50, 100, 200, 365].contains(streakDays)
                                Text("🔥 \(displayedStreak)")
                                    .monoSM(tracking: 1)
                                    .foregroundColor(ONETokens.oneInk)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(
                                        Capsule()
                                            .fill(ONETokens.onePaper)
                                            .overlay(Capsule().stroke(isMilestone ? ONETokens.oneBrand.opacity(0.5) : ONETokens.oneSilver, lineWidth: isMilestone ? 1.5 : 1))
                                    )
                                    .scaleEffect((streakChipPulse ? 1.08 : 1.0) * streakFlamePulse)
                                    .animation(
                                        isMilestone && !reduceMotion
                                            ? .easeInOut(duration: 1.4).repeatForever(autoreverses: true)
                                            : .default,
                                        value: streakChipPulse
                                    )
                                    .onAppear {
                                        if isMilestone && !reduceMotion { streakChipPulse = true }
                                    }
                            }
                        }
                        Text(NSLocalizedString("today.completedSubtitle", comment: ""))
                            .padding(.top, 24)
                            .displayLG()
                            .foregroundColor(ONETokens.oneInk)
                            .lineSpacing(2)
                        // Bu hafta
                        if !thisWeekEntries.isEmpty {
                            HStack(spacing: 10) {
                                WeeklyMoodRing(entries: thisWeekEntries, ringSize: 44)
                                Text("bu hafta \(min(thisWeekEntries.count, 7)) gün")
                                    .font(.custom("GeistMono-Regular", size: 10))
                                    .tracking(0.6)
                                    .foregroundColor(ONETokens.oneStone)
                            }
                            .padding(.top, 2)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, ONETokens.spacingXL2)
                    .padding(.top, headerTopPad(available: available))
                    .padding(.bottom, headerBottomPad(available: available))

                    if isFreezeActive {
                        HStack(spacing: 8) {
                            Text("❄️")
                                .font(.system(size: 13))
                            Text("Serin bugün donduruldu")
                                .monoSM(tracking: 0.5)
                                .foregroundColor(Color(hex: "#5B9BD5"))
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(
                            Capsule()
                                .fill(Color(hex: "#5B9BD5").opacity(0.08))
                                .overlay(Capsule().stroke(Color(hex: "#5B9BD5").opacity(0.25), lineWidth: 1))
                        )
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, ONETokens.spacingXL2)
                        .padding(.bottom, 6)
                        .transition(.move(edge: .top).combined(with: .opacity))
                    }

                    // Main Card
                    VStack(spacing: 0) {
                        // Photo or Mood gradient header
                        ZStack(alignment: .bottomLeading) {
                            if let photoURL = displayedEntry.photoURL {
                                // Photo background - tıklanabilir
                                Button(action: {
                                    withAnimation(ONEAnimation.panelSpring) {
                                        showPhotoViewer = true
                                    }
                                }) {
                                    CachedAsyncImagePhase(url: photoURL) { phase in
                                        if let image = phase.image {
                                            image
                                                .resizable()
                                                .aspectRatio(contentMode: .fill)
                                        } else {
                                            ONETokens.onePaper
                                                .overlay(ONEMood(hex: displayedEntry.moodColorHex)?.atmosphereGradient())
                                        }
                                    }
                                    .frame(height: photoHeight(available: available))
                                    .clipped()
                                    .overlay(
                                        // Subtle tap indicator
                                        ZStack {
                                            Color.black.opacity(0.02)
                                            Image(systemName: "arrow.up.left.and.arrow.down.right")
                                                .bodySMMedium()
                                                .foregroundColor(.white.opacity(0.6))
                                        }
                                    )
                                }
                                .buttonStyle(PlainButtonStyle())
                                .accessibilityLabel(String(format: NSLocalizedString("accessibility.today.photoOf", comment: ""), displayedEntry.songName))
                                .accessibilityHint(NSLocalizedString("accessibility.today.photoPreviewHint", comment: "Fotoğrafı tam ekranda görüntülemek için dokunun"))
                                .accessibilityAddTraits(.isButton)
                            } else {
                                // Light Serenity: mood as atmosphere, not host
                                ZStack {
                                    ONETokens.onePaper
                                    if let mood = ONEMood(hex: displayedEntry.moodColorHex) {
                                        mood.atmosphereGradient()
                                    }
                                }
                                .accessibilityHidden(true)
                            }
                            
                            // Time badge
                            HStack(spacing: 6) {
                                Circle()
                                    .fill(Color.white.opacity(0.9))
                                    .frame(width: 6, height: 6)
                                Text(String(format: NSLocalizedString("today.timeSelected", comment: ""), displayedEntry.time))
                                    .monoLabel(tracking: 1.0)
                                    .foregroundColor(.white.opacity(0.85))
                            }
                            .padding(.horizontal, ONETokens.spacingMD)
                            .padding(.vertical, 6)
                            .background(
                                Capsule()
                                    .fill(Color.white.opacity(0.15))
                                    .overlay(
                                        Capsule()
                                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                                    )
                            )
                            .padding(20)
                        }
                        .frame(height: photoHeight(available: available))
                        .frame(maxWidth: .infinity)
                        
                        // Song info section
                        VStack(alignment: .leading, spacing: ONETokens.spacingLG) {
                            // Song name + artist — tappable to change
                            Button(action: {
                                ONEHaptics.feelingSelected()
                                showChangeConfirm = true
                            }) {
                                VStack(alignment: .leading, spacing: ONETokens.spacingLG) {
                                    // Song name
                                    Text(displayedEntry.songName)
                                        .displayMD()
                                        .foregroundColor(ONETokens.oneInk)
                                        .tracking(-0.8)
                                        .lineLimit(2)

                                    // Artist & genre
                                    Text("\(displayedEntry.artistName) · \(displayedEntry.genre)")
                                        .monoBase(tracking: 0.5)
                                        .foregroundColor(ONETokens.oneCharcoal)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .buttonStyle(.plain)

                            // Divider
                            Rectangle()
                                .fill(ONETokens.oneCreamLow)
                                .frame(height: 1)
                                .padding(.vertical, 4)
                                .accessibilityHidden(true)
                            
                            // Mood & Feeling tags
                            HStack(spacing: ONETokens.spacingMD) {
                                // Mood
                                HStack(spacing: 6) {
                                    Circle()
                                        .fill(displayedEntry.moodColor)
                                        .frame(width: 7, height: 7)
                                    Text(displayedEntry.normalizedMoodLabel.uppercased())
                                        .monoLabel(tracking: 1.2)
                                        .foregroundColor(ONETokens.oneCharcoal)
                                }
                                .padding(.horizontal, ONETokens.spacingMD)
                                .padding(.vertical, 6)
                                .background(
                                    Capsule()
                                        .fill((ONEMood(hex: displayedEntry.moodColorHex)?.pastelColor ?? displayedEntry.moodColor).opacity(0.12))
                                )
                                
                                // Feeling
                                HStack(spacing: 6) {
                                    FeelingIconView(type: displayedEntry.feeling)
                                        .frame(width: 20, height: 16)
                                    Text(displayedEntry.feelingLabel.uppercased())
                                        .monoLabel(tracking: 1.2)
                                        .foregroundColor(ONETokens.oneCharcoal)
                                }
                                .padding(.horizontal, ONETokens.spacingMD)
                                .padding(.vertical, 6)
                                .background(
                                    Capsule()
                                        .fill(ONETokens.oneCreamMid)
                                )
                            }
                            
                            // Weather & Share info
                            HStack(spacing: ONETokens.spacingMD) {
                                HStack(spacing: 5) {
                                    Text(displayedEntry.weatherIcon)
                                        .font(.system(size: 11))
                                    Text(displayedEntry.weatherDesc)
                                        .monoLabel()
                                        .foregroundColor(ONETokens.oneCharcoal)
                                }
                                
                                if displayedEntry.shareWithCircle {
                                    HStack(spacing: 5) {
                                        Text("🌍")
                                            .font(.system(size: 11))
                                        Text(NSLocalizedString("today.sharedInCircle", comment: ""))
                                            .monoLabel()
                                            .foregroundColor(ONETokens.oneCharcoal)
                                    }
                                }
                            }
                            .padding(.top, 4)

                            if displayedEntry.shareWithCircle {
                                HStack(spacing: 8) {
                                    Image(systemName: "person.2.fill")
                                        .monoSM()
                                    Text(NSLocalizedString("today.circleCanSee", comment: ""))
                                        .monoSM(tracking: 0.2)
                                }
                                .foregroundColor(ONETokens.oneAsh)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 10)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(ONETokens.oneSilver)
                                )
                            }
                            
                            // Note section (if exists)
                            if let note = displayedEntry.note, !note.isEmpty {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text(NSLocalizedString("today.note", comment: ""))
                                        .monoLabel(tracking: 1.5)
                                        .foregroundColor(ONETokens.oneAsh)

                                    Text(note)
                                        .bodySM()
                                        .foregroundColor(ONETokens.oneInk)
                                        .lineSpacing(2)
                                        .tracking(-0.2)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(ONETokens.spacingLG)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill((ONEMood(hex: displayedEntry.moodColorHex)?.pastelColor ?? displayedEntry.moodColor).opacity(0.08))
                                )
                                .padding(.top, ONETokens.spacingLG)
                            }

                            // Divider
                            Rectangle()
                                .fill(ONETokens.oneCreamLow)
                                .frame(height: 1)
                                .padding(.top, 8)
                                .accessibilityHidden(true)

                            // Action buttons
                            VStack(spacing: 10) {
                                // Primary row — Keşfet (full width, prominent)
                                Button(action: {
                                    ONEHaptics.feelingSelected()
                                    NotificationManager.shared.shouldNavigateToDiscovery = true
                                }) {
                                    HStack(spacing: 6) {
                                        Image(systemName: "sparkles")
                                            .monoBase().fontWeight(.semibold)
                                        Text(NSLocalizedString("notification.openDiscovery", comment: ""))
                                            .bodySMMedium()
                                    }
                                    .foregroundColor(ONETokens.oneCream)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(Capsule().fill(displayedEntry.moodColor))
                                }
                                .accessibilityLabel(NSLocalizedString("notification.openDiscovery", comment: ""))
                                .accessibilityHint(NSLocalizedString("accessibility.discovery.eventHint", comment: "Mood'unuza göre etkinlik ve müzik önerileri"))
                                .accessibilityAddTraits(.isButton)

                                // Secondary row — Kaydet, Paylaş, Ekle
                                HStack(spacing: 8) {
                                    if displayedEntry.photoURL != nil {
                                        Button(action: {
                                            savePhotoToGallery()
                                        }) {
                                            HStack(spacing: 5) {
                                                Image(systemName: photoSaved ? "checkmark" : "arrow.down.to.line")
                                                    .monoSM()
                                                Text(photoSaved ? NSLocalizedString("today.saved", comment: "") : NSLocalizedString("general.save", comment: ""))
                                                    .monoBase(tracking: 0.5)
                                            }
                                            .foregroundColor(photoSaved ? ONETokens.oneGreen : ONETokens.oneInk)
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 10)
                                            .background(
                                                Capsule()
                                                    .fill(photoSaved ? ONETokens.oneGreen.opacity(0.08) : ONETokens.oneCreamMid.opacity(0.5))
                                                    .overlay(Capsule().stroke(photoSaved ? ONETokens.oneGreen.opacity(0.3) : ONETokens.oneSilver, lineWidth: 1))
                                            )
                                        }
                                        .disabled(photoSaved)
                                        .accessibilityLabel(photoSaved ? NSLocalizedString("today.saved", comment: "") : NSLocalizedString("general.save", comment: ""))
                                        .accessibilityHint(NSLocalizedString("accessibility.today.savePhotoHint", comment: "Fotoğrafı galeriye kaydet"))
                                    }

                                    Button(action: {
                                        ONEHaptics.feelingSelected()
                                        showShareOptions = true
                                    }) {
                                        HStack(spacing: 5) {
                                            Image(systemName: "square.and.arrow.up")
                                                .monoSM()
                                            Text(NSLocalizedString("general.share", comment: ""))
                                                .monoBase(tracking: 0.5)
                                        }
                                        .foregroundColor(ONETokens.oneInk)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 10)
                                        .liquidGlass(.regular.interactive(), in: Capsule())
                                    }
                                    .accessibilityLabel(NSLocalizedString("accessibility.today.shareButton", comment: ""))
                                    .accessibilityHint(NSLocalizedString("accessibility.today.shareHint", comment: "Günlük kaydınızı paylaşın"))

                                    // Değiştir — tertiary, küçük metin butonu
                                    Button(action: {
                                        ONEHaptics.feelingSelected()
                                        showChangeConfirm = true
                                    }) {
                                        HStack(spacing: 4) {
                                            Image(systemName: "arrow.counterclockwise")
                                                .monoLabel()
                                            Text(NSLocalizedString("accessibility.today.changeEntry", comment: ""))
                                                .bodySM()
                                        }
                                        .foregroundColor(ONETokens.oneCharcoal.opacity(0.5))
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 5)
                                    }
                                    .buttonStyle(.plain)
                                    .accessibilityLabel(NSLocalizedString("accessibility.today.changeEntry", comment: ""))
                                    .accessibilityHint(NSLocalizedString("accessibility.today.changeHint", comment: "Bugünün kaydını değiştir"))
                                }
                            }
                        }
                        .padding(20)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .liquidGlass(.regular, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .padding(.horizontal, 20)
                    .scaleEffect(appeared ? 1 : 0.94)
                    .opacity(appeared ? 1 : 0)
                    .animation(
                        reduceMotion 
                            ? .easeInOut(duration: 0.2).delay(0.2)
                            : ONEAnimation.panelSpring.delay(0.2), 
                        value: appeared
                    )

                    // Kendi paylaşımıma gelen yorumlar — v3
                    if CommentsFeatureFlag.isEnabled,
                       let myUserID = CloudKitManager.shared.currentUser?["userID"] as? String,
                       displayedEntry.shareWithCircle {
                        CommentEntryButton(
                            shareOwnerID: myUserID,
                            accentColorHex: displayedEntry.moodColorHex,
                            resolveShareRecordName: { completion in
                                CloudKitManager.shared.fetchOwnDailyShareRecordName(date: displayedEntry.date, completion: completion)
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
                        widgetNudgeBanner
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
                        pushSoftAskBanner
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
        } // ZStack
        } // GeometryReader
        .onChange(of: showPhotoViewer) { _, show in
            if show {
                GlobalUIState.shared.todayPhotoURL = displayedEntry.photoURL
            }
        }
        .onChange(of: globalUI.todayPhotoURL) { _, newURL in
            if newURL == nil { showPhotoViewer = false }
        }
        .sheet(isPresented: $showShareOptions) {
            ONEShareSheet(entry: displayedEntry)
        }
        .confirmationDialog(
            NSLocalizedString("today.changeConfirmTitle", comment: ""),
            isPresented: $showChangeConfirm,
            titleVisibility: .visible
        ) {
            Button(NSLocalizedString("today.changeConfirmYes", comment: ""), role: .destructive) {
                onEdit()
            }
            Button(NSLocalizedString("general.cancel", comment: ""), role: .cancel) { }
        } message: {
            Text(NSLocalizedString("today.changeConfirmMessage", comment: ""))
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
                            let nanoseconds = UInt64((0.15 + Double(step - 1) * 0.09) * 1_000_000_000)
                            try? await Task.sleep(nanoseconds: nanoseconds)
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
                        let finalNano = UInt64((0.15 + Double(tickSteps - 1) * 0.09 + 0.12) * 1_000_000_000)
                        try? await Task.sleep(nanoseconds: finalNano)
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
            loadThisWeekEntries()
            UNUserNotificationCenter.current().getNotificationSettings { settings in
                DispatchQueue.main.async {
                    notifStatus = settings.authorizationStatus
                }
            }
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

    // MARK: - Push Soft-Ask Banner

    private var pushSoftAskBanner: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "bell.badge")
                .bodyXL().fontWeight(.light)
                .foregroundColor(ONETokens.oneBrand)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 4) {
                Text("Yarın da hatırlatayım mı?")
                    .bodySMMedium()
                    .foregroundColor(ONETokens.oneInk)
                Text("Günlük kayıtlar mood örüntünü oluşturur.")
                    .bodyXS()
                    .foregroundColor(ONETokens.oneAsh)
                    .lineSpacing(2)

                HStack(spacing: 8) {
                    Button {
                        UserDefaults.standard.set(true, forKey: "pushSoftAskDismissed")
                        pushSoftAskDismissed = true
                        NotificationManager.shared.requestAuthorization { granted in
                            if granted {
                                var comps = DateComponents()
                                comps.hour = 20
                                comps.minute = 0
                                if let date = Calendar.current.date(from: comps) {
                                    NotificationManager.shared.scheduleDailyReminder(at: date)
                                }
                            }
                        }
                    } label: {
                        Text("Evet, hatırlat")
                            .monoLabel(tracking: 0.4)
                            .foregroundColor(ONETokens.oneCream)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(Capsule().fill(ONETokens.oneInk))
                    }

                    Button {
                        UserDefaults.standard.set(true, forKey: "pushSoftAskDismissed")
                        pushSoftAskDismissed = true
                    } label: {
                        Text("Belki sonra")
                            .monoLabel(tracking: 0.4)
                            .foregroundColor(ONETokens.oneAsh)
                    }
                }
                .padding(.top, 4)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(ONETokens.oneCreamMid.opacity(0.55))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(ONETokens.oneSilver, lineWidth: 1))
        )
    }

    // MARK: - This Week Entries

    private func loadThisWeekEntries() {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        guard let weekStart = cal.date(from: cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: today)) else { return }
        let weekEnd = cal.date(byAdding: .day, value: 7, to: weekStart) ?? today
        let req: NSFetchRequest<DailySong> = DailySong.fetchRequest()
        req.predicate = NSPredicate(format: "date >= %@ AND date < %@", weekStart as NSDate, weekEnd as NSDate)
        req.sortDescriptors = [NSSortDescriptor(key: "date", ascending: true)]
        let songs = (try? viewContext.fetch(req)) ?? []
        thisWeekEntries = songs.compactMap { s in
            guard let d = s.date, let hex = s.moodColorHex else { return nil }
            return (date: cal.startOfDay(for: d), moodColorHex: hex)
        }
    }

    // MARK: - B5 — Widget Nudge

    /// Ana ekrana widget eklemeyi öneren küçük banner. Kalıcı olarak
    /// kapatılabilir; bir kez kapatınca tekrar gösterilmez.
    private var widgetNudgeBanner: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "rectangle.stack.badge.plus")
                .bodyXL().fontWeight(.light)
                .foregroundColor(ONETokens.oneBrand)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 4) {
                Text(NSLocalizedString("widget.nudge.title", comment: ""))
                    .bodySMMedium()
                    .foregroundColor(ONETokens.oneInk)
                Text(NSLocalizedString("widget.nudge.body", comment: ""))
                    .bodyXS()
                    .foregroundColor(ONETokens.oneAsh)
                    .lineSpacing(2)
            }

            Spacer(minLength: 8)

            Button {
                widgetNudgeDismissed = true
                UserDefaults.standard.set(true, forKey: "widgetNudgeDismissed")
            } label: {
                Image(systemName: "xmark")
                    .monoSM().fontWeight(.semibold)
                    .foregroundColor(ONETokens.oneStone)
                    .frame(width: 28, height: 28)
            }
            .accessibilityLabel(NSLocalizedString("general.close", comment: ""))
            .accessibilityHint(NSLocalizedString("accessibility.widget.dismissHint", comment: "Widget önerisini kapat"))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(ONETokens.oneCreamMid.opacity(0.55))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(ONETokens.oneSilver, lineWidth: 1)
                )
        )
    }

    // MARK: - Save Photo to Gallery
    private func savePhotoToGallery() {
        guard let photoURL = displayedEntry.photoURL,
              let data = try? Data(contentsOf: photoURL),
              let image = UIImage(data: data) else { return }

        ONEHaptics.feelingSelected()
        ShareManager.shared.saveToPhotoLibrary(image: image) { result in
            if case .success = result {
                withAnimation(ONEAnimation.micro) { photoSaved = true }
            }
        }
    }
}

// MARK: - Full Screen Photo Viewer
// Enhanced with modern MagnifyGesture (iOS 17+) and @GestureState for auto-reset
struct PhotoViewerSheet: View {
    let photoURL: URL
    @Binding var isPresented: Bool

    @State private var loadedImage: UIImage? = nil
    @State private var scale: CGFloat = 1.0
    @GestureState private var gestureScale: CGFloat = 1.0
    @State private var dragOffset: CGFloat = 0          // @State → spring-back çalışır
    @State private var isDismissing = false
    @State private var panOffset: CGSize = .zero
    @GestureState private var gesturePanOffset: CGSize = .zero

    private var backgroundOpacity: Double {
        isDismissing ? 0 : Double(max(0.15, 1.0 - dragOffset / 280))
    }

    var body: some View {
        let isZoomed = scale > 1.01
        let combinedScale = scale * gestureScale
        let combinedPanOffset = CGSize(
            width: panOffset.width + gesturePanOffset.width,
            height: panOffset.height + gesturePanOffset.height
        )

        return ZStack {
            Color.black.opacity(backgroundOpacity).ignoresSafeArea()
                .animation(.linear(duration: 0.01), value: dragOffset)

            if let uiImage = loadedImage {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .drawingGroup()
                    .scaleEffect(combinedScale)
                    .offset(
                        x: isZoomed ? combinedPanOffset.width : 0,
                        y: isZoomed ? combinedPanOffset.height : dragOffset
                    )
                    .gesture(
                        SimultaneousGesture(
                            MagnifyGesture(minimumScaleDelta: 0.01)
                                .updating($gestureScale) { value, state, _ in
                                    state = value.magnification
                                }
                                .onEnded { value in
                                    scale = min(max(scale * value.magnification, 1.0), 5.0)
                                    if scale <= 1.0 {
                                        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                                            scale = 1.0
                                            panOffset = .zero
                                        }
                                    }
                                },
                            DragGesture(minimumDistance: 5)
                                .updating($gesturePanOffset) { value, state, _ in
                                    if scale > 1.01 { state = value.translation }
                                }
                                .onChanged { value in
                                    guard scale <= 1.01 else { return }
                                    let dy = value.translation.height
                                    if dy > 0 { dragOffset = dy }
                                }
                                .onEnded { value in
                                    if scale > 1.01 {
                                        panOffset.width  += value.translation.width
                                        panOffset.height += value.translation.height
                                        return
                                    }
                                    let vel = value.velocity.height
                                    let dy  = value.translation.height
                                    let shouldDismiss = dy > 90 || (dy > 20 && vel > 600)
                                    if shouldDismiss {
                                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                        withAnimation(.easeOut(duration: 0.28)) {
                                            dragOffset = UIScreen.main.bounds.height
                                            isDismissing = true
                                        }
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                                            isPresented = false
                                        }
                                    } else {
                                        withAnimation(.spring(response: 0.38, dampingFraction: 0.72)) {
                                            dragOffset = 0
                                        }
                                    }
                                }
                        )
                    )
                    .onTapGesture(count: 2) {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                            if isZoomed {
                                scale = 1.0
                                panOffset = .zero
                            } else {
                                scale = 2.5
                            }
                        }
                    }
                    .accessibilityLabel(NSLocalizedString("accessibility.today.photoViewer", comment: "Fotoğraf görüntüleyici"))
                    .accessibilityHint(NSLocalizedString("accessibility.today.photoViewerHint", comment: "Yakınlaştırmak için çift dokunun, kapatmak için aşağı kaydırın"))
            } else {
                ProgressView()
                    .tint(.white)
                    .accessibilityLabel(NSLocalizedString("accessibility.loading", comment: "Yükleniyor"))
            }

            VStack {
                HStack {
                    Button(action: {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        withAnimation(.easeOut(duration: 0.22)) {
                            dragOffset = UIScreen.main.bounds.height
                            isDismissing = true
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) { isPresented = false }
                    }) {
                        Image(systemName: "xmark")
                            .bodyLG().fontWeight(.semibold)
                            .foregroundColor(.white)
                            .frame(width: 44, height: 44)
                            .background(Circle().fill(Color.black.opacity(0.5))
                                .overlay(Circle().stroke(Color.white.opacity(0.2), lineWidth: 1)))
                    }
                    .padding(20)
                    .accessibilityLabel(NSLocalizedString("general.close", comment: ""))
                    .accessibilityHint(NSLocalizedString("accessibility.today.closeViewer", comment: "Fotoğraf görüntüleyiciyi kapat"))
                    Spacer()
                }
                Spacer()
                Image(systemName: "chevron.compact.down")
                    .displayMD().fontWeight(.light)
                    .foregroundColor(.white.opacity(isZoomed ? 0 : 0.3))
                    .padding(.bottom, 24)
                    .animation(ONEAnimation.micro, value: isZoomed)
                    .accessibilityHidden(true)
            }
            .offset(y: isZoomed ? 0 : dragOffset)
        }
        .ignoresSafeArea()
        .statusBarHidden(true)
        .task {
            if let data = try? Data(contentsOf: photoURL) {
                loadedImage = UIImage(data: data)
            }
        }
    }
}


// MARK: - Story Card Share Sheet
struct StoryCardShareSheet: View {
    let entry: DailyEntry
    
    @Environment(\.dismiss) private var dismiss
    @State private var isGeneratingCard = false
    @State private var generatedImage: UIImage?
    @State private var errorMessage: String?
    @State private var showError = false
    @State private var breathe = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                ONETokens.oneCream.ignoresSafeArea()
                
                VStack(spacing: 24) {
                    // Preview or loading state
                    if let image = generatedImage {
                        // Show generated image preview
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxHeight: 400)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 4)
                            .padding(.horizontal, 20)
                    } else if isGeneratingCard {
                        // Loading state
                        VStack(spacing: 16) {
                            Circle()
                                .fill(ONETokens.oneInk)
                                .frame(width: 8, height: 8)
                                .scaleEffect(breathe ? 1.4 : 0.8)
                                .opacity(breathe ? 1.0 : 0.4)
                            
                            Text(NSLocalizedString("today.cardLoading", comment: ""))
                                .monoBase(tracking: 0.5)
                                .foregroundColor(ONETokens.oneCharcoal)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        // Initial state
                        VStack(spacing: 16) {
                            Image(systemName: "photo.on.rectangle.angled")
                                .displayXL().fontWeight(.light)
                                .foregroundColor(ONETokens.oneAsh)
                            
                            Text(NSLocalizedString("today.createShareCard", comment: ""))
                                .monoBase(tracking: 0.5)
                                .foregroundColor(ONETokens.oneCharcoal)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                    
                    Spacer()
                    
                    // Action buttons
                    VStack(spacing: 12) {
                        if generatedImage != nil {
                            // Share button
                            Button(action: handleShare) {
                                HStack(spacing: 8) {
                                    Image(systemName: "square.and.arrow.up")
                                        .bodyLG().fontWeight(.light)
                                    Text(NSLocalizedString("general.share", comment: ""))
                                        .monoBase(tracking: 0.5)
                                }
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(
                                    RoundedRectangle(cornerRadius: 2)
                                        .fill(ONETokens.oneInk)
                                )
                            }
                            
                            // Save to library button
                            Button(action: handleSaveToLibrary) {
                                HStack(spacing: 8) {
                                    Image(systemName: "square.and.arrow.down")
                                        .bodySM().fontWeight(.light)
                                    Text(NSLocalizedString("today.saveToPhotos", comment: ""))
                                        .monoBase(tracking: 0.5)
                                }
                                .foregroundColor(ONETokens.oneCharcoal)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(
                                    RoundedRectangle(cornerRadius: 2)
                                        .strokeBorder(ONETokens.oneStone, lineWidth: 1)
                                )
                            }
                        } else {
                            // Generate button
                            Button(action: handleGenerate) {
                                HStack(spacing: 8) {
                                    Image(systemName: "sparkles")
                                        .bodyLG().fontWeight(.light)
                                    Text(NSLocalizedString("today.generateCard", comment: ""))
                                        .monoBase(tracking: 0.5)
                                }
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(
                                    RoundedRectangle(cornerRadius: 2)
                                        .fill(ONETokens.oneInk)
                                )
                            }
                            .disabled(isGeneratingCard)
                            .opacity(isGeneratingCard ? 0.6 : 1.0)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
                }
            }
            .navigationTitle(NSLocalizedString("general.share", comment: ""))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(NSLocalizedString("general.close", comment: "")) {
                        dismiss()
                    }
                    .foregroundColor(ONETokens.oneCharcoal)
                }
            }
            .liquidGlassToolbar()
        }
        .alert(NSLocalizedString("general.error", comment: ""), isPresented: $showError) {
            Button(NSLocalizedString("general.ok", comment: ""), role: .cancel) {}
            if generatedImage == nil {
                Button(NSLocalizedString("general.retry", comment: "")) {
                    handleGenerate()
                }
            }
        } message: {
            Text(errorMessage ?? NSLocalizedString("general.error", comment: ""))
        }
        .onChange(of: isGeneratingCard) { oldValue, newValue in
            if newValue {
                withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                    breathe = true
                }
            } else {
                breathe = false
            }
        }
    }
    
    private func handleGenerate() {
        isGeneratingCard = true
        errorMessage = nil
        
        Task {
            do {
                // Generate card directly from DailyEntry
                let image = try await StoryCardGenerator.shared
                    .generateCardAsync(from: entry)
                
                await MainActor.run {
                    generatedImage = image
                    isGeneratingCard = false
                    ONEHaptics.songSaved()
                }

            } catch {
                await MainActor.run {
                    isGeneratingCard = false
                    errorMessage = error.localizedDescription
                    showError = true
                    ONEHaptics.error()
                }
            }
        }
    }
    
    private func handleShare() {
        guard let image = generatedImage else { return }
        
        let activityVC = UIActivityViewController(
            activityItems: [image],
            applicationActivities: nil
        )
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = windowScene.windows.first?.rootViewController {
            
            // Configure for iPad
            if let popover = activityVC.popoverPresentationController {
                popover.sourceView = rootVC.view
                popover.sourceRect = CGRect(
                    x: rootVC.view.bounds.midX,
                    y: rootVC.view.bounds.midY,
                    width: 0,
                    height: 0
                )
                popover.permittedArrowDirections = []
            }
            
            rootVC.present(activityVC, animated: true)
        }
    }
    
    private func handleSaveToLibrary() {
        guard let image = generatedImage else { return }
        
        ShareManager.shared.saveToPhotoLibrary(image: image) { result in
            switch result {
            case .success:
                ONEHaptics.songSaved()
                dismiss()
            case .failure(let error):
                errorMessage = error.localizedDescription
                showError = true
                ONEHaptics.error()
            }
        }
    }
}
