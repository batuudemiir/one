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

    init(_ record: CKRecord) {
        self.id = record.recordID.recordName
        self.record = record
    }
}

struct CircleView: View {
    @Environment(\.managedObjectContext) private var context
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @StateObject private var cloudKitManager = CloudKitManager.shared
    @State private var friendsShares: [CloudKitManager.FriendCircleData] = []
    @State private var userShare: CKRecord? = nil  // User's own share
    @State private var isLoading = false
    @State private var showAddFriend = false
    @State private var showFriendRequests = false
    @State private var selectedShareItem: IdentifiableCKRecord? = nil
    @State private var selectedFriendData: CloudKitManager.FriendCircleData? = nil
    @State private var bubblesVisible = false
    @State private var selfPulseOpacity: Double = 1.0
    @State private var pendingRequestCount: Int = 0
    @State private var showRemoveConfirmation = false
    @State private var friendToRemove: CloudKitManager.FriendCircleData? = nil
    @State private var showBlockConfirmation = false
    @State private var friendToBlock: CloudKitManager.FriendCircleData? = nil
    @State private var localCurrentStreak: Int = 0
    @State private var hasLoadedOnce: Bool = false
    @State private var receivedReactions: [EmojiReactionItem] = []
    @State private var isViewVisible: Bool = false
    @State private var unseenShareCount: Int = 0

    // Deep Link support
    @State private var deepLinkInviteCode: String? = nil

    var onNavigateToToday: (() -> Void)? = nil
    
    // Check if current user has shared today
    private var userHasSharedToday: Bool {
        (userShare?["songName"] as? String)?.isEmpty == false
    }

    private var totalNotificationCount: Int { pendingRequestCount + CircleNotificationStore.shared.unreadCount }

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
    
    var body: some View {
        ZStack(alignment: .bottom) {
            ONETokens.oneCream.ignoresSafeArea()
            
            if !cloudKitManager.isCloudKitAvailable {
                cloudKitUnavailableView
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
            FriendShareDetailView(share: item.record)
        }
        .sheet(item: $selectedFriendData) { data in
            FriendDetailView(friendData: data, onRefresh: { loadFriendsShares() })
        }
        .sheet(isPresented: $showFriendRequests, onDismiss: {
            loadFriendsShares()
            loadPendingCount()
        }) {
            FriendRequestsView()
        }
        .alert(NSLocalizedString("circle.removeFriend", comment: ""), isPresented: $showRemoveConfirmation) {
            Button(NSLocalizedString("general.cancel", comment: ""), role: .cancel) { friendToRemove = nil }
            Button(NSLocalizedString("circle.removeAction", comment: ""), role: .destructive) { confirmRemoveFriend() }
        } message: {
            let name = friendToRemove?.user["displayName"] as? String ?? "bu kişi"
            Text("\(name) \(NSLocalizedString("circle.removeFriend", comment: ""))")
        }
        .alert(NSLocalizedString("circle.blockUser", comment: ""), isPresented: $showBlockConfirmation) {
            Button(NSLocalizedString("general.cancel", comment: ""), role: .cancel) { friendToBlock = nil }
            Button(NSLocalizedString("circle.blockAction", comment: ""), role: .destructive) { confirmBlockUser() }
        } message: {
            let name = friendToBlock?.user["displayName"] as? String ?? "bu kişi"
            Text(String(format: NSLocalizedString("circle.blockMessage", comment: ""), name))
        }
        .onAppear {
            computeLocalStreak()
            if !cloudKitManager.isFetchingUser {
                initializeUser()
            }

            // Start pulse animation for empty self bubble
            // Reduce Motion: tekrar eden animasyon atlanır
            if !userHasSharedToday && !reduceMotion {
                withAnimation(
                    .easeInOut(duration: 2.8)
                    .repeatForever(autoreverses: true)
                ) {
                    selfPulseOpacity = 0.35
                }
            }
        }
        .onChange(of: cloudKitManager.isFetchingUser) { _, isFetching in
            if !isFetching {
                initializeUser()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("HandleAddFriendDeepLink"))) { notification in
            if let targetCode = notification.userInfo?["code"] as? String {
                ONELogger.success("CircleView triggered by Deep Link. Code: \(targetCode)", category: .circle)
                deepLinkInviteCode = targetCode
                if !showAddFriend { showAddFriend = true }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .init("todaySongSaved"))) { _ in
            // Small delay to allow CloudKit save to propagate
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [self] in
                guard isViewVisible else { return }
                loadFriendsShares()
            }
            computeLocalStreak()
        }
        // CloudKit subscription pushed a change (friend shared, request arrived, accepted)
        .onReceive(NotificationCenter.default.publisher(for: .init("circleDataNeedsRefresh"))) { _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [self] in
                guard isViewVisible else { return }
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
                Text(String(format: NSLocalizedString("circle.headerCount", comment: ""), friendsShares.filter { ($0.share?["songName"] as? String)?.isEmpty == false }.count, friendsShares.count))
                    .monoSM(tracking: 2.0)
                    .foregroundColor(ONETokens.oneAsh)
                
                Spacer()

                // Arkadaş ekle butonu
                addFriendHeaderButton

                // Bildirimler butonu
                notificationsHeaderButton
            }
            
            Text(NSLocalizedString("circle.title", comment: ""))
                .displayLG()
                .foregroundColor(ONETokens.oneInk)

            Text(dynamicSubtitle)
                .bodySM()
                .foregroundColor(ONETokens.oneAsh)
                .animation(ONEAnimation.micro, value: dynamicSubtitle)

            if !userHasSharedToday {
                Text(NSLocalizedString("circle.awaitingShare", comment: ""))
                    .bodyMD()
                    .foregroundColor(ONETokens.oneAsh)
                    .padding(.top, 2)
                    .onTapGesture {
                        onNavigateToToday?()
                    }
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
    }
    
    
    // MARK: - Sen Card
    
    @ViewBuilder
    private var senCard: some View {
        let hasSong = userHasSharedToday
        let moodColorHex = userShare?["moodColor"] as? String ?? "#5B8DEF"
        let songName = userShare?["songName"] as? String ?? ""
        let artistName = userShare?["artistName"] as? String ?? ""
        let moodWord = (userShare?["moodWord"] as? String ?? "").uppercased()
        let time: String = {
            if let d = userShare?["createdAt"] as? Date {
                let f = DateFormatter(); f.dateFormat = "HH:mm"; return f.string(from: d)
            }
            return ""
        }()
        let displayName = cloudKitManager.currentUser?["displayName"] as? String ?? "S"
        let initial = String(displayName.prefix(1)).uppercased()
        
        HStack(spacing: ONETokens.spacingLG) {
            // Avatar — profil fotoğrafı > mood rengi > initial
            ZStack {
                if let profilePhoto = ProfileView.loadProfilePhotoFromDisk() {
                    Image(uiImage: profilePhoto)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 52, height: 52)
                        .clipShape(Circle())
                        .overlay(
                            Circle()
                                .stroke(
                                    hasSong ? Color(hex: moodColorHex).opacity(0.5) : ONETokens.oneCreamLow,
                                    lineWidth: hasSong ? 2 : 1
                                )
                        )
                    if !hasSong {
                        Circle()
                            .stroke(ONETokens.oneAsh,
                                    style: StrokeStyle(lineWidth: 1.5, dash: [4, 4]))
                            .frame(width: 52, height: 52)
                            .opacity(selfPulseOpacity)
                    }
                } else {
                    Circle()
                        .fill(hasSong ? Color(hex: moodColorHex) : ONETokens.oneCreamLow)
                        .frame(width: 52, height: 52)
                    if hasSong {
                        Text(initial)
                            .displaySM()
                            .foregroundColor(.white.opacity(0.9))
                    } else {
                        Circle()
                            .stroke(ONETokens.oneAsh,
                                    style: StrokeStyle(lineWidth: 1.5, dash: [4, 4]))
                            .frame(width: 52, height: 52)
                            .opacity(selfPulseOpacity)
                        Text(initial)
                            .displayXS()
                            .foregroundColor(ONETokens.oneAsh)
                    }
                }
            }
            
            // Info
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(NSLocalizedString("circle.you", comment: ""))
                        .monoSM(tracking: 1.6)
                        .foregroundColor(ONETokens.oneCharcoal)
                    if hasSong && !moodWord.isEmpty {
                        Circle()
                            .fill(Color(hex: moodColorHex))
                            .frame(width: 6, height: 6)
                        Text(moodWord)
                            .monoSM(tracking: 1.2)
                            .foregroundColor(Color(hex: moodColorHex))
                    }
                    Spacer()
                    streakBadge(days: localCurrentStreak, colorHex: moodColorHex)
                    if !time.isEmpty {
                        Text(time)
                            .monoLabel(tracking: 0.5)
                            .foregroundColor(ONETokens.oneAsh)
                    }
                }
                if hasSong {
                    Text(songName)
                        .bodySM()
                        .foregroundColor(ONETokens.oneInk)
                        .lineLimit(1)
                    Text(artistName)
                        .monoBase()
                        .foregroundColor(ONETokens.oneAsh)
                        .lineLimit(1)
                    if !receivedReactions.isEmpty {
                        HStack(spacing: 6) {
                            ForEach(Array(receivedReactions.prefix(3))) { reaction in
                                HStack(spacing: 3) {
                                    Text(reaction.emoji)
                                        .font(.system(size: 12))
                                    Text(reaction.senderName.components(separatedBy: " ").first ?? reaction.senderName)
                                        .monoMicro(tracking: 0)
                                        .foregroundColor(ONETokens.oneAsh)
                                        .lineLimit(1)
                                }
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .background(Capsule().fill(Color(hex: moodColorHex).opacity(0.09)))
                            }
                            if receivedReactions.count > 3 {
                                Text("+\(receivedReactions.count - 3)")
                                    .monoMicro(tracking: 0)
                                    .foregroundColor(ONETokens.oneAsh)
                            }
                        }
                        .padding(.top, 2)
                    }
                } else {
                    Text(NSLocalizedString("circle.shareToday", comment: ""))
                        .bodySM()
                        .foregroundColor(ONETokens.oneAsh)
                        .padding(.top, 2)
                }
            }
        }
        .padding(ONETokens.spacingLG)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(ONETokens.onePaper.opacity(0.7))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(
                            hasSong ? Color(hex: moodColorHex).opacity(0.3) : ONETokens.oneCreamLow,
                            lineWidth: 1
                        )
                )
        )
        .contentShape(Rectangle())
        .onTapGesture {
            if !hasSong { onNavigateToToday?() }
        }
    }
    
    // MARK: - Friend Card

    private func friendCard(data: CloudKitManager.FriendCircleData, index: Int) -> some View {
        let hasSong = data.share != nil && !(data.share!["songName"] as? String ?? "").isEmpty
        let moodColorHex = data.share?["moodColor"] as? String ?? data.user["avatarColor"] as? String ?? "#888888"
        let songName = data.share?["songName"] as? String ?? ""
        let artistName = data.share?["artistName"] as? String ?? ""
        let moodWord = (data.share?["moodWord"] as? String ?? "").uppercased()
        let name = data.user["displayName"] as? String ?? "?"
        let initial = String(name.prefix(1)).uppercased()

        // Çevre Yankısı — kullanıcının bugünkü rengiyle karşılaştır
        let myMoodColorHex = userShare?["moodColor"] as? String ?? ""
        let isResonant = hasSong && !myMoodColorHex.isEmpty
            && Color.hsbHueDifference(hex1: myMoodColorHex, hex2: moodColorHex) <= 20.0
        let time = getTimeString(from: data.share?["createdAt"] as? Date)
        let friendStreak = data.share?["currentStreak"] as? Int ?? 0
        let photoAsset = data.share?["photoAsset"] as? CKAsset
        let photoFileURL = photoAsset?.fileURL
        let profilePhotoAsset = data.user["profilePhoto"] as? CKAsset
        let profilePhotoURL = profilePhotoAsset?.fileURL

        let isUnseen = isUnseenShare(data)
        let friendIsPremium = data.user["isPremium"] as? Int64 == 1

        return HStack(spacing: ONETokens.spacingLG) {
            // Avatar: daily photo > profile photo > mood color circle
            Group {
                if let photoURL = photoFileURL,
                   let uiImg = UIImage(contentsOfFile: photoURL.path) {
                    Image(uiImage: uiImg)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 44, height: 44)
                        .clipShape(Circle())
                        .overlay(
                            Circle()
                                .stroke(Color(hex: moodColorHex).opacity(0.5), lineWidth: 1.5)
                        )
                } else if let profileURL = profilePhotoURL,
                          let uiImg = UIImage(contentsOfFile: profileURL.path) {
                    Image(uiImage: uiImg)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 44, height: 44)
                        .clipShape(Circle())
                        .overlay(
                            Circle()
                                .stroke(Color(hex: moodColorHex).opacity(0.3), lineWidth: 1)
                        )
                } else {
                    Circle()
                        .fill(hasSong ? Color(hex: moodColorHex) : ONETokens.oneStone)
                        .frame(width: 44, height: 44)
                        .overlay(
                            Text(initial)
                                .displayXS()
                                .foregroundColor(.white.opacity(hasSong ? 0.9 : 0.5))
                        )
                }
            }
            .overlay(alignment: .topTrailing) {
                if isUnseen {
                    Circle()
                        .fill(Color(hex: moodColorHex))
                        .frame(width: 11, height: 11)
                        .overlay(Circle().stroke(ONETokens.oneCream, lineWidth: 2))
                        .offset(x: 2, y: -2)
                } else if friendIsPremium {
                    // ONE+ premium crown badge
                    Image(systemName: "crown.fill")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(3)
                        .background(
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [ONETokens.oneBrand, ONETokens.oneBrandLight],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                        )
                        .overlay(Circle().stroke(ONETokens.oneCream, lineWidth: 1.5))
                        .offset(x: 3, y: -3)
                }
            }

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(name.uppercased())
                        .monoSM(tracking: 1.4)
                        .foregroundColor(ONETokens.oneCharcoal)
                    if hasSong && !moodWord.isEmpty {
                        Circle()
                            .fill(Color(hex: moodColorHex))
                            .frame(width: 5, height: 5)
                        Text(moodWord)
                            .monoSM(tracking: 1.0)
                            .foregroundColor(Color(hex: moodColorHex).opacity(0.85))
                    }
                    // Çevre Yankısı rozeti
                    if isResonant {
                        resonancePill(myHex: myMoodColorHex, friendHex: moodColorHex)
                    }
                    Spacer()
                    if hasSong { streakBadge(days: friendStreak, colorHex: moodColorHex) }
                    if !time.isEmpty {
                        Text(time)
                            .monoLabel(tracking: 0.5)
                            .foregroundColor(ONETokens.oneAsh)
                    }
                }
                if hasSong {
                    Text(songName)
                        .bodyMD()
                        .foregroundColor(ONETokens.oneInk)
                        .lineLimit(1)
                    Text(artistName)
                        .monoSM()
                        .foregroundColor(ONETokens.oneAsh)
                        .lineLimit(1)
                } else {
                    Text(NSLocalizedString("circle.notSharedYet", comment: ""))
                        .bodySM()
                        .foregroundColor(ONETokens.oneAsh)
                        .padding(.top, 1)
                }
            }
        }
        .padding(14)
        .opacity(hasSong ? 1.0 : 0.55)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(ONETokens.onePaper.opacity(hasSong ? 0.55 : 0.3))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(
                            isResonant
                                ? LinearGradient(
                                    colors: [
                                        Color(hex: myMoodColorHex).opacity(0.55),
                                        Color(hex: moodColorHex).opacity(0.55)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                                : LinearGradient(
                                    colors: [ONETokens.oneCreamLow.opacity(0.7)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                            lineWidth: isResonant ? 1.5 : 1
                        )
                )
        )
        .contentShape(Rectangle())
        .onTapGesture {
            ONEHaptics.feelingSelected()
            selectedFriendData = data
        }
        .contextMenu {
            Button(role: .destructive) {
                friendToRemove = data
                showRemoveConfirmation = true
            } label: {
                Label(NSLocalizedString("circle.removeAction", comment: ""), systemImage: "person.badge.minus")
            }
            Button(role: .destructive) {
                friendToBlock = data
                showBlockConfirmation = true
            } label: {
                Label(NSLocalizedString("circle.blockAction", comment: ""), systemImage: "nosign")
            }
        }
    }
    
    // MARK: - Invite Row (inside scroll list)

    // MARK: - Skeleton Loading Cards
    private var skeletonCards: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 10) {
                ForEach(0..<4, id: \.self) { index in
                    skeletonCard(widths: skeletonWidths[index])
                        .transition(.opacity.combined(with: .scale(scale: 0.95)))
                        .animation(
                            ONEAnimation.cardSpring.delay(Double(index) * 0.08),
                            value: isLoading
                        )
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, ONETokens.spacingLG)
            .padding(.bottom, 100)
        }
    }

    private let skeletonWidths: [(name: CGFloat, sub: CGFloat)] = [
        (140, 90), (120, 110), (160, 70), (130, 100)
    ]

    private func skeletonCard(widths: (name: CGFloat, sub: CGFloat)) -> some View {
        HStack(spacing: 12) {
            Circle()
                .fill(ONETokens.oneCreamMid)
                .frame(width: 44, height: 44)

            VStack(alignment: .leading, spacing: 6) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(ONETokens.oneCreamMid)
                    .frame(width: widths.name, height: 12)
                RoundedRectangle(cornerRadius: 4)
                    .fill(ONETokens.oneSilver)
                    .frame(width: widths.sub, height: 10)
            }

            Spacer()

            RoundedRectangle(cornerRadius: 6)
                .fill(ONETokens.oneSilver)
                .frame(width: 48, height: 48)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: ONETokens.radiusFriend)
                .fill(ONETokens.onePaper)
        )
        .shimmeringCircle()
    }

    private var inviteRow: some View {
        Button(action: { showAddFriend = true }) {
            HStack(spacing: 14) {
                // İkon
                ZStack {
                    Circle()
                        .fill(friendsShares.isEmpty ? ONETokens.oneInk.opacity(0.06) : Color.clear)
                        .frame(width: 44, height: 44)
                    Circle()
                        .strokeBorder(
                            friendsShares.isEmpty ? ONETokens.oneInk.opacity(0.18) : ONETokens.oneStone,
                            style: StrokeStyle(lineWidth: 1.5, dash: [2, 3])
                        )
                        .frame(width: 44, height: 44)
                    Image(systemName: friendsShares.isEmpty ? "person.badge.plus.fill" : "plus")
                        .font(.system(size: friendsShares.isEmpty ? 15 : 16, weight: .light))
                        .foregroundColor(friendsShares.isEmpty ? ONETokens.oneInk : ONETokens.oneAsh)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(NSLocalizedString("circle.addFriend", comment: ""))
                        .bodySM()
                        .foregroundColor(friendsShares.isEmpty ? ONETokens.oneInk : ONETokens.oneAsh)
                    if friendsShares.isEmpty {
                        Text(NSLocalizedString("circle.inviteHint", comment: ""))
                            .monoLabel(tracking: 0.3)
                            .foregroundColor(ONETokens.oneMist)
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(ONETokens.oneMist)
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(friendsShares.isEmpty
                          ? ONETokens.onePaper.opacity(0.7)
                          : ONETokens.onePaper.opacity(0.4))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(
                                friendsShares.isEmpty
                                    ? ONETokens.oneInk.opacity(0.1)
                                    : ONETokens.oneCreamLow.opacity(0.8),
                                lineWidth: friendsShares.isEmpty ? 1.5 : 1
                            )
                    )
            )
        }
        .buttonStyle(ScaleButtonStyle())
        .accessibilityLabel(NSLocalizedString("accessibility.circle.addFriend", comment: ""))
        .accessibilityHint(NSLocalizedString("accessibility.circle.addFriendHint", comment: ""))
    }
    
    // MARK: - Empty State
    
    private var emptyStateView: some View {
        VStack(spacing: 0) {
            Spacer()
            
            VStack(spacing: 24) {
                // Mascot
                OneMascotView(
                    pose: .noState,
                    size: 140,
                    message: "Henüz çevren yok.\nArkadaşlarını ekle, bugünkü mood'larını\ngör ve paylaşımı başlat."
                )
                
                // Buttons
                VStack(spacing: 12) {
                    // Davet et
                    Button(action: { showAddFriend = true }) {
                        Text(NSLocalizedString("circle.setupCTA", comment: ""))
                            .bodySMMedium()
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(
                                LinearGradient(
                                    colors: [ONETokens.oneBrand, ONETokens.oneBrandLight],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .accessibilityLabel(NSLocalizedString("accessibility.circle.setupCircle", comment: ""))
                    .padding(.horizontal, 40)
                }
            }
            .padding(.horizontal, 32)
            
            Spacer()
            Spacer() // double spacer → content biraz yukarda durur (nav bar'dan uzak)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - CloudKit Unavailable
    
    private var cloudKitUnavailableView: some View {
        VStack(spacing: ONETokens.spacingXL) {
            Spacer()
            
            VStack(spacing: ONETokens.spacingLG) {
                Image(systemName: "icloud.slash")
                    .font(.system(size: 56, weight: .ultraLight))
                    .foregroundColor(ONETokens.oneAsh)
                
                VStack(spacing: ONETokens.spacingSM) {
                    Text(NSLocalizedString("circle.iCloudRequired", comment: ""))
                        .displayMD()
                        .foregroundColor(ONETokens.oneInk)

                    Text(NSLocalizedString("circle.iCloudMessage", comment: ""))
                        .monoSM(tracking: 0)
                        .multilineTextAlignment(.center)
                        .foregroundColor(ONETokens.oneCharcoal)
                        .padding(.horizontal, 40)
                    
#if DEBUG
                    Text("Debug: CloudKit durumu kontrol ediliyor...")
                        .monoMicro(tracking: 0)
                        .foregroundColor(ONETokens.oneStone)
                        .padding(.top, ONETokens.spacingSM)
#endif
                }
            }
            
            Spacer()
            
            VStack(spacing: ONETokens.spacingMD) {
                Button(action: {
                    cloudKitManager.checkCloudKitAvailability()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        if cloudKitManager.isCloudKitAvailable {
                            initializeUser()
                        }
                    }
                }) {
                    Text(NSLocalizedString("circle.tryAgain", comment: ""))
                        .monoBase(tracking: 1.0)
                        .foregroundColor(ONETokens.oneInk)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, ONETokens.spacingMD)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(ONETokens.oneAsh, lineWidth: 1)
                        )
                }
                
                Button(action: openSettings) {
                    Text(NSLocalizedString("circle.goToSettings", comment: ""))
                        .monoBase(tracking: 1.0)
                        .foregroundColor(ONETokens.oneCream)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, ONETokens.spacingMD)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(ONETokens.oneInk)
                        )
                }
            }
            .padding(.horizontal, ONETokens.spacingXL)
            .padding(.bottom, ONETokens.spacingXL4)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Resonance Pill

    @ViewBuilder
    private func resonancePill(myHex: String, friendHex: String) -> some View {
        HStack(spacing: 3) {
            Circle().fill(Color(hex: myHex)).frame(width: 5, height: 5)
            Circle().fill(Color(hex: friendHex)).frame(width: 5, height: 5)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(
            Capsule()
                .fill(
                    LinearGradient(
                        colors: [
                            Color(hex: myHex).opacity(0.12),
                            Color(hex: friendHex).opacity(0.12)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .overlay(
                    Capsule()
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color(hex: myHex).opacity(0.3),
                                    Color(hex: friendHex).opacity(0.3)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            ),
                            lineWidth: 0.75
                        )
                )
        )
    }

    // MARK: - Streak Badge

    @ViewBuilder
    private func streakBadge(days: Int, colorHex: String) -> some View {
        if days >= 2 {
            HStack(spacing: 3) {
                Text("🔥")
                    .font(.system(size: 9))
                Text("\(days)")
                    .monoMicro(tracking: 0.4)
                    .foregroundColor(Color(hex: colorHex))
            }
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(
                Capsule()
                    .fill(Color(hex: colorHex).opacity(0.12))
                    .overlay(
                        Capsule()
                            .stroke(Color(hex: colorHex).opacity(0.3), lineWidth: 0.75)
                    )
            )
        }
    }

    // MARK: - Unseen Share Tracking

    private func unseenShareKey(for userID: String) -> String {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"
        return "seenShare_\(userID)_\(f.string(from: Date()))"
    }

    private func isUnseenShare(_ data: CloudKitManager.FriendCircleData) -> Bool {
        guard let share = data.share,
              !(share["songName"] as? String ?? "").isEmpty,
              let uid = data.user["userID"] as? String else { return false }
        return !UserDefaults.standard.bool(forKey: unseenShareKey(for: uid))
    }

    private func computeUnseenCount() {
        unseenShareCount = friendsShares.filter { isUnseenShare($0) }.count
        cloudKitManager.unseenFriendShareCount = unseenShareCount
    }

    // MARK: - Helper Functions

    private func computeLocalStreak() {
        let fetchRequest: NSFetchRequest<DailySong> = DailySong.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "date", ascending: false)]
        guard let songs = try? context.fetch(fetchRequest) else { return }

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today) ?? today

        let filledDates = Set(songs.compactMap { s -> Date? in
            guard let d = s.date else { return nil }
            return calendar.startOfDay(for: d)
        })

        guard filledDates.contains(today) || filledDates.contains(yesterday) else {
            localCurrentStreak = 0
            return
        }

        let anchor = filledDates.contains(today) ? today : yesterday
        var streak = 0
        var checkDay = anchor
        while filledDates.contains(checkDay) {
            streak += 1
            guard let prev = calendar.date(byAdding: .day, value: -1, to: checkDay) else { break }
            checkDay = prev
        }
        localCurrentStreak = streak
    }

    private func getTimeString(from date: Date?) -> String {
        guard let date = date else { return "" }
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
    
    private func initializeUser() {
        if cloudKitManager.currentUser != nil {
            loadFriendsShares()
            loadPendingCount()
            // Subscription kaydı oneApp.swift'teki .onChange(of: currentUser) tarafından yapılır.
            return
        }

        if cloudKitManager.isFetchingUser {
            ONELogger.debug("Still fetching user, deferring initialization...", category: .circle)
            return
        }

        cloudKitManager.createOrFetchUser(displayName: "ONE User") { result in
            switch result {
            case .success:
                ONELogger.debug("User initialized successfully", category: .circle)
                self.loadFriendsShares()
                self.loadPendingCount()
                // Subscription kaydı oneApp.swift'teki .onChange(of: currentUser) üstlenir;
                // burada tekrar çağırmak race condition yaratırdı.
            case .failure(let error):
                ONELogger.debug("Error initializing user: \(error)", category: .circle)
                DispatchQueue.main.async {
                    self.isLoading = false
                }
            }
        }
    }
    
    private func loadFriendsShares() {
        if cloudKitManager.currentUser == nil {
            ONELogger.warning("loadFriendsShares: currentUser is nil, waiting...", category: .circle)
            Task {
                let loaded = await cloudKitManager.ensureCurrentUser()
                guard loaded else {
                    ONELogger.error("loadFriendsShares: currentUser still nil after wait", category: .circle)
                    return
                }
                await MainActor.run {
                    performLoadFriendsShares()
                }
            }
            return
        }
        performLoadFriendsShares()
    }

    private func performLoadFriendsShares() {
        // ── Serve cache instantly ────────────────────────────────────────
        if cloudKitManager.isCircleCacheValid, let cached = cloudKitManager.cachedCircleData {
            self.friendsShares = cached
            if !self.bubblesVisible {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    withAnimation(ONEAnimation.cardSpring) { self.bubblesVisible = true }
                }
            }
            // Still refresh in background (cache will be updated silently)
        }

        isLoading = self.friendsShares.isEmpty

        // Load user's own share first
        cloudKitManager.fetchUserDailyShare(for: Date()) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let share):
                    self.userShare = share
                    ONELogger.success("Loaded user's own share", category: .circle)
                    // Load emoji reactions others sent to this share
                    self.cloudKitManager.fetchReceivedEmojiReactions(shareRecordName: share.recordID.recordName) { reactions in
                        withAnimation(ONEAnimation.micro) {
                            self.receivedReactions = reactions
                        }
                    }
                case .failure(let error):
                    ONELogger.info("User hasn't shared today: \(error)", category: .circle)
                    self.userShare = nil
                    self.receivedReactions = []
                }
            }
        }

        // Load friends' shares
        cloudKitManager.fetchFriendsDailyShares(for: Date()) { result in
            DispatchQueue.main.async {
                self.isLoading = false
                self.hasLoadedOnce = true
                switch result {
                case .success(let shares):
                    self.friendsShares = shares
                    self.computeUnseenCount()
                    self.cloudKitManager.friendsSharedTodayCount = shares.filter { $0.share != nil }.count
                    if !self.bubblesVisible {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                            withAnimation(ONEAnimation.cardSpring) {
                                self.bubblesVisible = true
                            }
                        }
                    }
                case .failure(let error):
                    ONELogger.debug("Error loading shares: \(error)", category: .circle)
                }
            }
        }
    }
    
    private func loadPendingCount() {
        cloudKitManager.fetchPendingRequestCount { count in
            withAnimation(ONEAnimation.micro) {
                self.pendingRequestCount = count
            }
        }
    }
    
    private func confirmRemoveFriend() {
        guard let friend = friendToRemove else { return }
        let friendUserID = friend.user["userID"] as? String ?? friend.user.recordID.recordName

        cloudKitManager.removeFriend(friendUserID: friendUserID) { result in
            switch result {
            case .success:
                withAnimation(ONEAnimation.micro) {
                    friendsShares.removeAll { $0.id == friend.id }
                }
                ErrorHandler.shared.showSuccess("Arkadaşlıktan çıkarıldı")
            case .failure(let error):
                ErrorHandler.shared.handle(error, context: "remove friend")
            }
            friendToRemove = nil
        }
    }

    private func confirmBlockUser() {
        guard let friend = friendToBlock else { return }
        let friendUserID = friend.user["userID"] as? String ?? friend.user.recordID.recordName

        cloudKitManager.blockUser(userID: friendUserID) { result in
            switch result {
            case .success:
                withAnimation(ONEAnimation.micro) {
                    friendsShares.removeAll { $0.id == friend.id }
                }
                ErrorHandler.shared.showSuccess("Kullanıcı engellendi")
            case .failure(let error):
                ErrorHandler.shared.handle(error, context: "block user")
            }
            friendToBlock = nil
        }
    }
    
    @MainActor
    private func refreshData() async {
        computeLocalStreak()
        loadFriendsShares()
        loadPendingCount()
        // Give CloudKit calls time to complete
        try? await Task.sleep(nanoseconds: 1_500_000_000)
    }
    
    private func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }
    
    // MARK: - Preview
    
    struct CircleView_Previews: PreviewProvider {
        static var previews: some View {
            CircleView()
                .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
        }
    }
}

// MARK: - Circle Shimmer
private struct CircleShimmerModifier: ViewModifier {
    @State private var phase: CGFloat = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .overlay(
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color.clear,
                        ONETokens.oneCreamMid.opacity(0.4),
                        Color.clear
                    ]),
                    startPoint: .init(x: phase - 0.5, y: 0.5),
                    endPoint: .init(x: phase + 0.5, y: 0.5)
                )
                .clipShape(RoundedRectangle(cornerRadius: ONETokens.radiusFriend))
            )
            .onAppear {
                // Reduce Motion: shimmer atlanır
                guard !reduceMotion else { return }
                withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                    phase = 1.5
                }
            }
    }
}

extension View {
    func shimmeringCircle() -> some View {
        modifier(CircleShimmerModifier())
    }
}
