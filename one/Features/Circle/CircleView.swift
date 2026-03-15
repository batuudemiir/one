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
    @State private var receivedEmojis: [String] = []

    // Deep Link support
    @State private var deepLinkInviteCode: String? = nil

    var onNavigateToToday: (() -> Void)? = nil
    
    // Check if current user has shared today
    private var userHasSharedToday: Bool {
        (userShare?["songName"] as? String)?.isEmpty == false
    }
    
    var body: some View {
        ZStack(alignment: .bottom) {
            ONETokens.oneCream.ignoresSafeArea()
            
            if !cloudKitManager.isCloudKitAvailable {
                cloudKitUnavailableView
            } else if hasLoadedOnce && friendsShares.isEmpty && !isLoading && userShare == nil && pendingRequestCount == 0 {
                emptyStateView
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    headerSection
                    cloudSection
                }
            }
            
            if isLoading {
                ProgressView()
                    .scaleEffect(1.5)
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
        .alert("Arkadaşlıktan Çıkar", isPresented: $showRemoveConfirmation) {
            Button("İptal", role: .cancel) { friendToRemove = nil }
            Button("Çıkar", role: .destructive) { confirmRemoveFriend() }
        } message: {
            let name = friendToRemove?.user["displayName"] as? String ?? "bu kişi"
            Text("\(name) arkadaşlıktan çıkarılsın mı?")
        }
        .alert("Kullanıcıyı Engelle", isPresented: $showBlockConfirmation) {
            Button("Vazgeç", role: .cancel) { friendToBlock = nil }
            Button("Engelle", role: .destructive) { confirmBlockUser() }
        } message: {
            let name = friendToBlock?.user["displayName"] as? String ?? "bu kişi"
            Text("\(name) adlı kullanıcıyı engellemek istediğine emin misin? Bu işlemi geri alamazsın.")
        }
        .onAppear {
            computeLocalStreak()
            if !cloudKitManager.isFetchingUser {
                initializeUser()
            }

            // Start pulse animation for empty self bubble
            if !userHasSharedToday {
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
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                loadFriendsShares()
            }
            computeLocalStreak()
        }
        // CloudKit subscription pushed a change (friend shared, request arrived, accepted)
        .onReceive(NotificationCenter.default.publisher(for: .init("circleDataNeedsRefresh"))) { _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                loadFriendsShares()
                loadPendingCount()
            }
        }
        .sheet(isPresented: $showAddFriend, onDismiss: {
            loadFriendsShares()
            loadPendingCount()
            deepLinkInviteCode = nil
        }) {
            AddFriendView(prefilledCode: deepLinkInviteCode)
        }
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: ONETokens.spacingSM) {
            HStack {
                Text("Çevre · \(friendsShares.filter { ($0.share?["songName"] as? String)?.isEmpty == false }.count)/\(friendsShares.count) paylaştı")
                    .monoSM(tracking: 2.0)
                    .foregroundColor(ONETokens.oneAsh)
                
                Spacer()
                
                // Bildirimler butonu
                Button(action: { showFriendRequests = true }) {
                    HStack(spacing: 5) {
                        Image(systemName: pendingRequestCount > 0 ? "bell.badge" : "bell")
                            .font(.system(size: 15))
                        if pendingRequestCount > 0 {
                            Text("\(pendingRequestCount)")
                                .monoSM(tracking: 0)
                        }
                    }
                    .foregroundColor(pendingRequestCount > 0 ? ONETokens.oneInk : ONETokens.oneAsh)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(pendingRequestCount > 0 ? ONETokens.oneCreamLow : Color.clear)
                            .overlay(
                                Capsule()
                                    .stroke(ONETokens.oneAsh.opacity(0.25), lineWidth: 1)
                            )
                    )
                }
            }
            
            Text("çevre")
                .displayLG()
                .foregroundColor(ONETokens.oneInk)

            Text("Arkadaşlarının bugünkü mood'unu gör, kendi seçimini bırak, paylaşımı büyüt.")
                .bodySM()
                .foregroundColor(ONETokens.oneAsh)

            if !userHasSharedToday {
                Text("Bugün senden bir paylaşım bekleniyor.")
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

                // ── DAVET SATIRI ──────────────────────────────────
                inviteRow
                    .scaleEffect(bubblesVisible ? 1.0 : 0.92)
                    .opacity(bubblesVisible ? 1.0 : 0)
                    .animation(
                        ONEAnimation.cardSpring
                        .delay(ONEAnimation.staggerDelay(index: friendsShares.count + 1, baseDelay: 0.06)),
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
                    Text("\(pendingRequestCount) gelen istek")
                        .displaySM()
                        .foregroundColor(ONETokens.oneInk)
                    Text("Onaylamak için dokun")
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
                    .fill(Color.white.opacity(0.55))
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
            // Avatar
            ZStack {
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
            
            // Info
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text("SEN")
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
                    if !receivedEmojis.isEmpty {
                        HStack(spacing: 4) {
                            ForEach(Array(Set(receivedEmojis)), id: \.self) { emoji in
                                Text(emoji)
                                    .font(.system(size: 13))
                                    .padding(5)
                                    .background(Circle().fill(Color(hex: moodColorHex).opacity(0.1)))
                            }
                            Text("\(receivedEmojis.count)")
                                .monoMicro(tracking: 0)
                                .foregroundColor(ONETokens.oneAsh)
                        }
                        .padding(.top, 2)
                    }
                } else {
                    Text("Bugünü paylaş ve çevrende görün")
                        .bodySM()
                        .foregroundColor(ONETokens.oneAsh)
                        .padding(.top, 2)
                }
            }
        }
        .padding(ONETokens.spacingLG)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.7))
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
        let time = getTimeString(from: data.share?["createdAt"] as? Date)
        let friendStreak = data.share?["currentStreak"] as? Int ?? 0
        let photoAsset = data.share?["photoAsset"] as? CKAsset
        let photoFileURL = photoAsset?.fileURL

        return HStack(spacing: ONETokens.spacingLG) {
            // Avatar: show today's photo if available, else mood color circle
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
                    Text("Bugün henüz paylaşmadı")
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
                .fill(Color.white.opacity(hasSong ? 0.55 : 0.3))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(ONETokens.oneCreamLow.opacity(0.7), lineWidth: 1)
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
                Label("Arkadaşlıktan Çıkar", systemImage: "person.badge.minus")
            }
            Button(role: .destructive) {
                friendToBlock = data
                showBlockConfirmation = true
            } label: {
                Label("Engelle", systemImage: "nosign")
            }
        }
    }
    
    // MARK: - Invite Row (inside scroll list)

    private var inviteRow: some View {
        Button(action: { showAddFriend = true }) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .strokeBorder(
                            ONETokens.oneStone,
                            style: StrokeStyle(lineWidth: 1.5, dash: [2, 3])
                        )
                        .frame(width: 44, height: 44)
                    Image(systemName: "plus")
                        .font(.system(size: 16, weight: .light))
                        .foregroundColor(ONETokens.oneAsh)
                }
                Text("Bir arkadaşını çevrene çağır")
                    .bodySM()
                    .foregroundColor(ONETokens.oneAsh)
                Spacer()
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.white.opacity(0.2))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(ONETokens.oneCreamLow.opacity(0.8), lineWidth: 1)
                    )
            )
        }
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
                        Text("Çevreni kur")
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
                    Text("iCloud erişimi gerekli")
                        .displayMD()
                        .foregroundColor(ONETokens.oneInk)
                    
                    Text("Çevre özelliği için iCloud\nhesabınızla giriş yapmalısınız.")
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
                    Text("Tekrar Dene")
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
                    Text("Ayarlar'a Git")
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
            cloudKitManager.registerAllSubscriptions()
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
                // Register CloudKit subscriptions for real-time push notifications
                self.cloudKitManager.registerAllSubscriptions()
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
        isLoading = true

        // Load user's own share first
        cloudKitManager.fetchUserDailyShare(for: Date()) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let share):
                    self.userShare = share
                    ONELogger.success("Loaded user's own share", category: .circle)
                    // Load emoji reactions others sent to this share
                    self.cloudKitManager.fetchReceivedEmojiReactions(shareRecordName: share.recordID.recordName) { emojis in
                        withAnimation(ONEAnimation.micro) {
                            self.receivedEmojis = emojis
                        }
                    }
                case .failure(let error):
                    ONELogger.info("User hasn't shared today: \(error)", category: .circle)
                    self.userShare = nil
                    self.receivedEmojis = []
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
                    self.bubblesVisible = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        self.bubblesVisible = true
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
