//
//  CircleView.swift
//  one
//
//  Çevre (Circle) feature - Friends' daily music sharing with bubble cloud design
//

import SwiftUI
import CloudKit
import CoreData

/// Wrapper to make CKRecord usable with .sheet(item:)
struct IdentifiableCKRecord: Identifiable {
    let id: String
    let record: CKRecord
    let friendDisplayName: String

    init(_ record: CKRecord, displayName: String = "") {
        self.id = record.recordID.recordName
        self.record = record
        self.friendDisplayName = displayName
    }
}

struct CircleView: View {
    @Environment(\.managedObjectContext) var context
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    @StateObject var cloudKitManager = CloudKitManager.shared
    @State var friendsShares: [CloudKitManager.FriendCircleData] = []
    @State var userShare: CKRecord? = nil  // User's own share
    @State var isLoading = false
    @State var showAddFriend = false
    @State var showFriendRequests = false
    @State var selectedShareItem: IdentifiableCKRecord? = nil
    @State var selectedFriendData: CloudKitManager.FriendCircleData? = nil
    @State var bubblesVisible = false
    @State var selfPulseOpacity: Double = 1.0
    @State var pendingRequestCount: Int = 0
    @State var showRemoveConfirmation = false
    @State var friendToRemove: CloudKitManager.FriendCircleData? = nil
    @State var showBlockConfirmation = false
    @State var friendToBlock: CloudKitManager.FriendCircleData? = nil
    @State var localCurrentStreak: Int = 0
    @State var hasLoadedOnce: Bool = false
    @State var receivedReactions: [EmojiReactionItem] = []
    @State var isViewVisible: Bool = false
    @State var unseenShareCount: Int = 0
    @State var selectedPublicProfileUserID: String? = nil
    @State var showSelfDetail = false

    // Deep Link support
    @State var deepLinkInviteCode: String? = nil

    var onNavigateToToday: (() -> Void)? = nil
    
    // Check if current user has shared today
    var userHasSharedToday: Bool {
        (userShare?["songName"] as? String)?.isEmpty == false
    }

    private var totalNotificationCount: Int { CircleNotificationStore.shared.unreadCount }

    private var dynamicSubtitle: String {
        let sharedCount = friendsShares.filter {
            !($0.share?["songName"] as? String ?? "").isEmpty
        }.count
        let total = friendsShares.count
        let hour  = Calendar.current.component(.hour, from: Date())

        if total == 0 {
            return NSLocalizedString("circle.subtitle", comment: "")
        } else if sharedCount == total {
            return total == 1
                ? NSLocalizedString("circle.oneShared", comment: "")
                : NSLocalizedString("circle.allShared", comment: "")
        } else if sharedCount > 0 {
            return String(format: NSLocalizedString("circle.someShared", comment: ""), sharedCount, total)
        } else if hour < 12 {
            return NSLocalizedString("circle.morningPending", comment: "")
        } else {
            return NSLocalizedString("circle.subtitle", comment: "")
        }
    }
    
    @Environment(\.colorScheme) private var colorScheme

    private var removeFriendTitle: String { NSLocalizedString("circle.removeFriend", comment: "") }
    private var blockUserTitle: String { NSLocalizedString("circle.blockUser", comment: "") }
    private var cancelLabel: String { NSLocalizedString("general.cancel", comment: "") }
    private var removeActionLabel: String { NSLocalizedString("circle.removeAction", comment: "") }
    private var blockActionLabel: String { NSLocalizedString("circle.blockAction", comment: "") }
    private var blockMessageFormat: String { NSLocalizedString("circle.blockMessage", comment: "") }

    var body: some View {
        circleContent
            .alert(removeFriendTitle, isPresented: $showRemoveConfirmation) {
                Button(cancelLabel, role: .cancel) { friendToRemove = nil }
                Button(removeActionLabel, role: .destructive) { confirmRemoveFriend() }
            } message: {
                let name = friendToRemove?.user["displayName"] as? String ?? "bu kişi"
                Text(name + " " + removeFriendTitle)
            }
            .alert(blockUserTitle, isPresented: $showBlockConfirmation) {
                Button(cancelLabel, role: .cancel) { friendToBlock = nil }
                Button(blockActionLabel, role: .destructive) { confirmBlockUser() }
            } message: {
                let name = friendToBlock?.user["displayName"] as? String ?? "bu kişi"
                Text(String(format: blockMessageFormat, name))
            }
    }

    private var publicProfileBinding: Binding<IdentifiableString?> {
        Binding(
            get: { selectedPublicProfileUserID.map { IdentifiableString($0) } },
            set: { selectedPublicProfileUserID = $0?.value }
        )
    }

    @ViewBuilder
    private var circleContent: some View {
        ZStack(alignment: .bottom) {
            (colorScheme == .dark ? Color.black : ONETokens.oneCream).ignoresSafeArea()

            if !cloudKitManager.isCloudKitAvailable {
                CircleCloudKitUnavailableState(
                    cloudKitManager: cloudKitManager,
                    onRetry: {
                        cloudKitManager.checkCloudKitAvailability()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                            if cloudKitManager.isCloudKitAvailable {
                                initializeUser()
                            }
                        }
                    },
                    onOpenSettings: openSettings
                )
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    headerSection
                    if isLoading && !hasLoadedOnce {
                        skeletonCards
                    } else {
                        cloudSection
                    }
                }
            }
        }
        .navigationBarHidden(true)
        .sheet(item: $selectedShareItem) { item in
            FriendShareDetailView(share: item.record, friendDisplayName: item.friendDisplayName)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showSelfDetail) {
            if let share = userShare {
                SelfShareDetailView(share: share)
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
            }
        }
        .sheet(item: $selectedFriendData) { data in
            FriendDetailView(friendData: data, onRefresh: { loadFriendsShares() })
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showFriendRequests, onDismiss: {
            loadFriendsShares()
            loadPendingCount()
        }) {
            FriendRequestsView()
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .onAppear {
            AppAnalytics.shared.track(.circleOpened)
            computeLocalStreak()
            if !cloudKitManager.isFetchingUser {
                initializeUser()
            }
            startPulseIfNeeded()
        }
        .onChange(of: reduceMotion) { _, reduced in
            if reduced {
                // Sistem ayarı açıldı — animasyonu anında durdur
                withAnimation(.easeOut(duration: 0.2)) { selfPulseOpacity = 1.0 }
            } else if !userHasSharedToday {
                startPulseIfNeeded()
            }
        }
        .onChange(of: cloudKitManager.isFetchingUser) { _, isFetching in
            if !isFetching {
                initializeUser()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("HandleAddFriendDeepLink"))) { notification in
            guard let targetCode = notification.userInfo?["code"] as? String else { return }
            ONELogger.success("CircleView deep link code: " + targetCode, category: .circle)
            deepLinkInviteCode = targetCode
            if !showAddFriend { showAddFriend = true }
        }
        .onReceive(NotificationCenter.default.publisher(for: .init("todaySongSaved"))) { _ in
            // CloudKit save'in yayılması için kısa bekleme
            computeLocalStreak()
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(1500))
                guard isViewVisible else { return }
                loadFriendsShares()
            }
        }
        // CloudKit subscription pushed a change (friend shared, request arrived, accepted)
        .onReceive(NotificationCenter.default.publisher(for: .init("circleDataNeedsRefresh"))) { _ in
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(800))
                guard isViewVisible else { return }
                cloudKitManager.invalidateCircleCache()
                loadFriendsShares()
                loadPendingCount()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .init("unseenSharesChanged"))) { _ in
            computeUnseenCount()
        }
        // Reload when currentUser becomes available after throttle/error recovery
        .onChange(of: cloudKitManager.currentUser) { _, newUser in
            if newUser != nil && friendsShares.isEmpty && isViewVisible {
                loadFriendsShares()
                loadPendingCount()
            }
        }
        .onAppear {
            isViewVisible = true
            // Clear tab badge as soon as the user opens the Circle screen
            cloudKitManager.unseenFriendShareCount = 0
        }
        .onDisappear { isViewVisible = false }
        .sheet(isPresented: $showAddFriend, onDismiss: {
            loadFriendsShares()
            loadPendingCount()
            deepLinkInviteCode = nil
        }) {
            AddFriendView(prefilledCode: deepLinkInviteCode)
        }
        .sheet(item: publicProfileBinding) { wrap in
            PublicProfileView(userID: wrap.value)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
    }

    // MARK: - Header Action Buttons

    private var addFriendHeaderButton: some View {
        Button(action: { showAddFriend = true }) {
            HStack(spacing: 5) {
                Image(systemName: friendsShares.isEmpty ? "person.badge.plus.fill" : "person.badge.plus")
                    .font(.system(size: 13, weight: .medium))
                if friendsShares.isEmpty {
                    Text(NSLocalizedString("circle.addFriend", comment: ""))
                        .monoSM(tracking: 0.5)
                }
            }
            .foregroundColor(friendsShares.isEmpty ? ONETokens.oneCream : ONETokens.oneAsh)
            .padding(.horizontal, friendsShares.isEmpty ? 14 : 10)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(friendsShares.isEmpty
                          ? ONETokens.oneInk
                          : ONETokens.oneSilver.opacity(0.9))
            )
        }
        .buttonStyle(ScaleButtonStyle())
        .animation(ONEAnimation.micro, value: friendsShares.isEmpty)
        .accessibilityLabel(NSLocalizedString("accessibility.circle.addFriend", comment: ""))
    }

    private var notificationsHeaderButton: some View {
        Button(action: { showFriendRequests = true }) {
            ZStack(alignment: .topTrailing) {
                Image(systemName: totalNotificationCount > 0 ? "bell.badge.fill" : "bell")
                    .font(.system(size: 15, weight: .medium))
                    .symbolRenderingMode(totalNotificationCount > 0 ? .hierarchical : .monochrome)
                    .foregroundColor(totalNotificationCount > 0 ? ONETokens.oneInk : ONETokens.oneAsh)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(
                        Capsule()
                            .fill(totalNotificationCount > 0
                                  ? ONETokens.oneCreamLow
                                  : ONETokens.oneSilver.opacity(0.9))
                    )

                if totalNotificationCount > 0 {
                    ZStack {
                        Circle().fill(Color.red)
                        Text(totalNotificationCount < 10 ? "\(totalNotificationCount)" : "9+")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(.white)
                    }
                    .frame(width: 16, height: 16)
                    .offset(x: 5, y: -4)
                    .transition(.scale.combined(with: .opacity))
                }
            }
        }
        .buttonStyle(ScaleButtonStyle())
        .animation(ONEAnimation.micro, value: totalNotificationCount)
        .accessibilityLabel(
            totalNotificationCount > 0
                ? "\(totalNotificationCount) \(NSLocalizedString("friendRequests.title", comment: ""))"
                : NSLocalizedString("friendRequests.title", comment: "")
        )
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: ONETokens.spacingSM) {
            HStack {
                // Paylaşım sayacı — sadece arkadaş varsa göster
                if !friendsShares.isEmpty {
                    let sharedCount = friendsShares.filter { ($0.share?["songName"] as? String)?.isEmpty == false }.count
                    Text("\(sharedCount)/\(friendsShares.count) paylaştı")
                        .monoSM(tracking: 1.5)
                        .foregroundColor(ONETokens.oneAsh)
                }

                Spacer()

                addFriendHeaderButton
                notificationsHeaderButton
            }

            Text(NSLocalizedString("circle.title", comment: ""))
                .displayLG()
                .foregroundColor(ONETokens.oneInk)

            Text(dynamicSubtitle)
                .bodySM()
                .foregroundColor(ONETokens.oneAsh)
                .animation(ONEAnimation.micro, value: dynamicSubtitle)

            if unseenShareCount > 0 {
                Text("↑ \(unseenShareCount) yeni paylaşım")
                    .monoSM(tracking: 1.0)
                    .foregroundColor(ONETokens.oneBrand)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .padding(.top, ONETokens.spacingXL4)
        .padding(.horizontal, ONETokens.spacingXL2)
        .padding(.bottom, 0)
    }
    
    // MARK: - Cloud Section (structured cards, no overlapping)
    
    private var cloudSection: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 10) {
                // ── ÇEVRE RİTMİ ──────────────────────────────────
                if !rhythmEntries.isEmpty {
                    CircleRhythmStrip(entries: rhythmEntries)
                        .scaleEffect(bubblesVisible ? 1.0 : 0.92)
                        .opacity(bubblesVisible ? 1.0 : 0)
                        .animation(ONEAnimation.cardSpring, value: bubblesVisible)
                }

                // ── SEN ──────────────────────────────────────────
                senCard
                    .scaleEffect(bubblesVisible ? 1.0 : 0.92)
                    .opacity(bubblesVisible ? 1.0 : 0)
                    .animation(ONEAnimation.cardSpring, value: bubblesVisible)

                // ── ARKADAŞLAR ────────────────────────────────────
                ForEach(Array(friendsShares.enumerated()), id: \.element.id) { index, data in
                    friendCard(data: data, index: index)
                        .scaleEffect(bubblesVisible ? 1.0 : 0.92)
                        .opacity(bubblesVisible ? 1.0 : 0)
                        .animation(
                            ONEAnimation.cardSpring
                            .delay(ONEAnimation.staggerDelay(index: index + 1, baseDelay: 0.06)),
                            value: bubblesVisible
                        )
                }

                // ── BEKLEYEN İSTEKLER ─────────────────────────────
                if pendingRequestCount > 0 {
                    pendingRequestsTeaser
                        .scaleEffect(bubblesVisible ? 1.0 : 0.92)
                        .opacity(bubblesVisible ? 1.0 : 0)
                        .animation(
                            ONEAnimation.cardSpring
                            .delay(ONEAnimation.staggerDelay(index: friendsShares.count + 1, baseDelay: 0.06)),
                            value: bubblesVisible
                        )
                        .transition(.move(edge: .top).combined(with: .opacity))
                }

                // ── DAVET SATIRI ──────────────────────────────────
                inviteRow
                    .scaleEffect(bubblesVisible ? 1.0 : 0.92)
                    .opacity(bubblesVisible ? 1.0 : 0)
                    .animation(
                        ONEAnimation.cardSpring
                        .delay(ONEAnimation.staggerDelay(
                            index: friendsShares.count + (pendingRequestCount > 0 ? 2 : 1),
                            baseDelay: 0.06)
                        ),
                        value: bubblesVisible
                    )
            }
            .padding(.horizontal, 20)
            .padding(.top, ONETokens.spacingLG)
            .padding(.bottom, 100)
        }
        .refreshable {
            await refreshData()
        }
        .onAppear {
            withAnimation(ONEAnimation.screenTransition.delay(0.15)) {
                bubblesVisible = true
            }
        }
    }
    
    // MARK: - Pending Requests Teaser
    
    private var pendingRequestsTeaser: some View {
        Button(action: { showFriendRequests = true }) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(ONETokens.oneInk.opacity(0.08))
                        .frame(width: 40, height: 40)
                    Image(systemName: "person.badge.clock")
                        .font(.system(size: 16))
                        .foregroundColor(ONETokens.oneInk)
                }
                .accessibilityHidden(true)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(String(format: NSLocalizedString("circle.pendingRequests", comment: ""), pendingRequestCount))
                        .displaySM()
                        .foregroundColor(ONETokens.oneInk)
                    Text(NSLocalizedString("circle.tapToApprove", comment: ""))
                        .monoSM(tracking: 0)
                        .foregroundColor(ONETokens.oneAsh)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(ONETokens.oneAsh)
                    .accessibilityHidden(true)
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(ONETokens.onePaper.opacity(0.55))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(ONETokens.oneInk.opacity(0.15), lineWidth: 1)
                    )
            )
        }
        .accessibilityLabel(String(format: NSLocalizedString("circle.pendingRequests", comment: ""), pendingRequestCount))
        .accessibilityHint(NSLocalizedString("circle.tapToApprove", comment: ""))
    }
    
    
    // MARK: - Rhythm Strip Data

    /// Kullanıcı dahil çevrenin streak verisi — giriş sırası korunur.
    private var rhythmEntries: [CircleRhythmStrip.Entry] {
        var result: [CircleRhythmStrip.Entry] = []

        // Kendisi
        let selfName = cloudKitManager.currentUser?["displayName"] as? String ?? "Sen"
        let selfColorHex = cloudKitManager.currentUser?["avatarColor"] as? String ?? "#5B8DEF"
        result.append(.init(
            name: selfName,
            streakDays: localCurrentStreak,
            avatarColorHex: selfColorHex,
            isSelf: true
        ))

        // Arkadaşlar
        for data in friendsShares {
            let name = data.user["displayName"] as? String ?? "?"
            let colorHex = data.user["avatarColor"] as? String
                ?? data.share?["moodColor"] as? String
                ?? "#888888"
            // TODO: CloudKit FriendCircleData'ya kalıcı streakDays alanı eklenince burası güncellenmeli.
            let days = data.share?["currentStreak"] as? Int ?? 0
            result.append(.init(
                name: name,
                streakDays: days,
                avatarColorHex: colorHex,
                isSelf: false
            ))
        }

        return result
    }

    // Card builders extracted to CircleView+Cards.swift (Faz 3.1, 2026-04-26).
    // Helpers extracted to CircleView+Helpers.swift (Faz 3.1, 2026-04-26).
    
    // MARK: - Preview
    
    struct CircleView_Previews: PreviewProvider {
        static var previews: some View {
            CircleView()
                .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
        }
    }
}

// CircleShimmerModifier extracted to CircleShimmer.swift (Faz 3.1, 2026-04-26).
