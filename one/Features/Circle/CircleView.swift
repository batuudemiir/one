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
    let friendProfilePhoto: UIImage?

    init(_ record: CKRecord, displayName: String = "", profilePhoto: UIImage? = nil) {
        self.id = record.recordID.recordName
        self.record = record
        self.friendDisplayName = displayName
        self.friendProfilePhoto = profilePhoto
    }
}

struct CircleView: View {
    @Environment(\.managedObjectContext) var context
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    @StateObject var cloudKitManager = CloudKitManager.shared
    @State var friendsShares: [CloudKitManager.FriendCircleData] = []
    @State var userShare: CKRecord? = nil  // User's own share
    @State var isLoading = false
    /// Uçuşta bir `performLoadFriendsShares` var mı. `onAppear` ve
    /// `onChange(of: isFetchingUser)` ikisi birden `initializeUser()`
    /// çağırdığı için aynı CloudKit turu iki kez atılıyordu.
    @State var isFetchingShares = false
    @State var showAddFriend = false
    @State var showFriendRequests = false
    /// Prototip 22 — bildirim akışı. Zil artık istekleri değil tüm akışı
    /// açıyor; istekler o akışın içinde bir tür.
    @State var showNotifications = false
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
    /// Faz 3 — başlıktaki haftalık 7 nokta (salt gösterim).
    @State var weekRhythm: [WeekRhythm.Day] = []
    /// Uzun aradan sonra dönüldüyse Frekans üstünde geri dönüş ekranı.
    /// Karar `markOpened` sırasında verilip bayrağa yazılıyor; burada
    /// sadece okunuyor — view'ın kurulma anına bağlı değil.
    @State var showComeback: Bool = EngagementTracker.pendingComebackDays != nil
    @State var comebackDays: Int = EngagementTracker.pendingComebackDays ?? 0
    @State var hasLoadedOnce: Bool = false
    /// Alt-çevreler — başlık altındaki grup çipleri. selectedCircleID nil
    /// iken "Tümü" seçili; dolu iken bubble-cloud o grubun üyelerine
    /// istemci tarafında filtrelenir (yeni sorgu yok).
    @State var subCircles: [SubCircle] = []
    /// SceneStorage-backed persistence: filtre uygulama arka plana atılıp
    /// dönüldüğünde kaybolmasın. Boş string = "Tümü".
    @SceneStorage("one.scene.circleFilter") private var persistedCircleID: String = ""
    @State var selectedCircleID: String? = nil
    @State var showSubCircleManager = false
    @State var receivedReactions: [EmojiReactionItem] = []
    @State var isViewVisible: Bool = false
    @State var unseenShareCount: Int = 0
    @State var selectedPublicProfileUserID: String? = nil
    @State var showSelfDetail = false
    @State var showQuickAdd = false

    // Deep Link support
    @State var deepLinkInviteCode: String? = nil

    /// Scroll-driven header shrink. 0 = başlık tam görünür, 1 = maks küçülmüş.
    /// cloudSection'daki GeometryReader güncelliyor.
    @State var headerShrinkProgress: CGFloat = 0

    var onNavigateToToday: (() -> Void)? = nil
    var onNavigateToDiscover: (() -> Void)? = nil
    
    // Check if current user has shared today
    var userHasSharedToday: Bool {
        (userShare?["songName"] as? String)?.isEmpty == false
    }

    /// Hiç arkadaşı olmayan kullanıcı. `hasLoadedOnce` şart: yükleme bitmeden
    /// boş durum göstermek, verisi olan kullanıcıya bir an "çevren boş" demek olurdu.
    /// Frekans'ın açılma eşiği. Tek arkadaşla "çevre" olmuyor; ürünün
    /// tuttuğu şey karşılıklılık (Solo D30 %0 / Sosyal %20.7). Eşiğe
    /// kadar ekran tek iş yapıyor: davet.
    static let requiredFriends = 3

    var hasNoCircleYet: Bool {
        hasLoadedOnce && friendsShares.count < Self.requiredFriends
    }

    private var totalNotificationCount: Int { CircleNotificationStore.shared.unreadCount }

    /// Başlığın altındaki tek satır. Eskiden iki ayrı yerde aynı bilgi
    /// vardı: üstte "5/7 paylaştı", başlığın altında "5/7 kişi bugün
    /// seçimini paylaştı." Tek satıra indirildi.
    private var counterText: String {
        let sharedCount = friendsShares.filter {
            !($0.share?["songName"] as? String ?? "").isEmpty
        }.count
        let total = friendsShares.count

        guard total > 0 else { return dynamicSubtitle }
        return String(
            format: NSLocalizedString("circle.counterFormat", comment: ""),
            sharedCount, total
        )
    }

    private var dynamicSubtitle: String {
        let sharedCount = friendsShares.filter {
            !($0.share?["songName"] as? String ?? "").isEmpty
        }.count
        let total = friendsShares.count
        let hour  = Calendar.current.component(.hour, from: Date())

        if total == 0 {
            // Prototip: arkadaşsız kullanıcıya ürünün ne yaptığını anlatan
            // uzun cümle değil, durumunu söyleyen kısa bir satır. Değer
            // önerisi zaten hemen altındaki önizlemede.
            return NSLocalizedString("circle.empty.status", comment: "")
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
            (colorScheme == .dark ? Color.black : ONEBrand.bone).ignoresSafeArea()

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
                    } else if cloudKitManager.userLoadFailed && friendsShares.isEmpty {
                        // Prototip 34 — bağlantı yok. Hata ekranı çıkmaz sokak
                        // değil: kayıt yerel, sadece paylaşım uzak.
                        CircleOfflineState(
                            onStartRitual: { onNavigateToToday?() },
                            onRetry: {
                                cloudKitManager.loadCurrentUser()
                                loadFriendsShares()
                            }
                        )
                    } else if hasNoCircleYet {
                        // Arkadaşı olmayan kullanıcıya 3 sahte iskelet kartı göstermek
                        // yerine değer önizlemesi + tek net davet. (Solo D30 %0)
                        CircleEmptyState(
                            showAddFriend: $showAddFriend,
                            friendCount: friendsShares.count,
                            requiredFriends: Self.requiredFriends,
                            onStartAlone: onNavigateToToday
                        )
                    } else {
                        if Features.subCirclesEnabled {
                            subCircleChips
                        }
                        cloudSection
                    }
                }
            }
        }
        .navigationBarHidden(true)
        .fullScreenCover(isPresented: Binding(
            get: { showSubCircleManager && Features.subCirclesEnabled },
            set: { showSubCircleManager = $0 }
        ), onDismiss: { loadSubCircles() }) {
            SubCircleManagerView()
        }
        .fullScreenCover(isPresented: $showNotifications) {
            NotificationFeedView(
                onBack: { showNotifications = false },
                onOpenUser: { uid in
                    showNotifications = false
                    selectedPublicProfileUserID = uid
                }
            )
        }
        .sheet(isPresented: $showComeback, onDismiss: { EngagementTracker.consumeComeback() }) {
            ComebackView(
                daysAway: comebackDays,
                friendColors: comebackFriendColors,
                backfillableDays: weekRhythm.filter(\.isBackfillable).map(\.date),
                onBackfill: { _ in
                    // Telafi ritüeli Bugün ekranında; önce oraya götür.
                    showComeback = false
                    onNavigateToToday?()
                },
                onStartToday: {
                    showComeback = false
                    onNavigateToToday?()
                }
            )
            .presentationDetents([.large])
        }
        .sheet(item: $selectedShareItem) { item in
            FriendShareDetailView(
                share: item.record,
                friendDisplayName: item.friendDisplayName,
                friendProfilePhoto: item.friendProfilePhoto
            )
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
            isViewVisible = true
            // Sekme rozetini ekran açılır açılmaz temizle.
            // `onAppear` sekme geçişinin update transaction'ı içinde koşuyor;
            // BottomNavigation aynı pass'te bu @Published'ı okuduğu için
            // doğrudan yazmak "Publishing changes from within view updates"
            // uyarısı üretiyordu. Bir sonraki runloop'a erteliyoruz.
            Task { @MainActor in
                cloudKitManager.unseenFriendShareCount = 0
            }

            AppAnalytics.shared.track(.circleOpened)
            computeLocalStreak()
            loadWeekRhythm()
            if !cloudKitManager.isFetchingUser {
                initializeUser()
            }
            startPulseIfNeeded()

            // Restore persisted filter (SceneStorage). Boş string = Tümü.
            if !persistedCircleID.isEmpty, selectedCircleID == nil {
                selectedCircleID = persistedCircleID
            }
        }
        .onChange(of: selectedCircleID) { _, newValue in
            persistedCircleID = newValue ?? ""
        }
        // Alt-çevre listesi tazelendiğinde stale filtreyi doğrula.
        // SceneStorage'da persist edilen ID, uygulama arka planda iken
        // silinmiş olabilir; onAppear restore bu ölü ID'yi geri getirir
        // ve loadSubCircles callback'i yetişene kadar UI'da "yok grup"
        // seçili görünür. Liste değişimini gözleyip anında sıfırla.
        .onChange(of: subCircles) { _, list in
            if let sel = selectedCircleID,
               !list.contains(where: { $0.id == sel }) {
                selectedCircleID = nil
            }
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
            loadWeekRhythm()
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
        .onReceive(NotificationCenter.default.publisher(for: .init("OpenFriendRequests"))) { _ in
            showFriendRequests = true
        }
        // Reload when currentUser becomes available after throttle/error recovery
        .onChange(of: cloudKitManager.currentUser) { _, newUser in
            if newUser != nil && friendsShares.isEmpty && isViewVisible {
                loadFriendsShares()
                loadPendingCount()
            }
        }
        .onDisappear { isViewVisible = false }
        .sheet(isPresented: $showAddFriend, onDismiss: {
            loadFriendsShares()
            loadPendingCount()
            deepLinkInviteCode = nil
        }) {
            AddFriendScreen(prefilledCode: deepLinkInviteCode)
        }
        .sheet(item: publicProfileBinding) { wrap in
            FriendProfileScreen(
                userID: wrap.value,
                todayShare: friendsShares.first {
                    ($0.user["userID"] as? String) == wrap.value
                }?.share,
                onBack: { selectedPublicProfileUserID = nil }
            )
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showQuickAdd, onDismiss: {
            cloudKitManager.invalidateSuggestionsCache()
            loadFriendsShares()
            loadPendingCount()
        }) {
            QuickAddFriendSheet()
                .presentationDetents([.height(520), .large])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(28)
        }
    }

    // MARK: - Header Action Buttons

    private var addFriendHeaderButton: some View {
        Button(action: { showAddFriend = true }) {
            Image(systemName: "person.badge.plus")
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(V3Tokens.mutedText)
                .frame(width: 34, height: 34)
                .background(Circle().fill(Color.white.opacity(0.6)))
                .overlay(Circle().stroke(V3Tokens.ink.opacity(0.09), lineWidth: 1))
        }
        .buttonStyle(ScaleButtonStyle())
        .accessibilityLabel(NSLocalizedString("accessibility.circle.addFriend", comment: ""))
    }



    private var notificationsHeaderButton: some View {
        Button(action: { showNotifications = true }) {
            ZStack(alignment: .topTrailing) {
                Image(systemName: totalNotificationCount > 0 ? "bell.badge.fill" : "bell")
                    .font(.system(size: 15, weight: .medium))
                    .symbolRenderingMode(totalNotificationCount > 0 ? .hierarchical : .monochrome)
                    .foregroundColor(totalNotificationCount > 0 ? ONETokens.oneInk : V3Tokens.mutedText)
                    .frame(width: 34, height: 34)
                    .background(
                        Circle().fill(totalNotificationCount > 0
                                      ? ONETokens.oneCreamLow
                                      : Color.white.opacity(0.6))
                    )
                    .overlay(Circle().stroke(V3Tokens.ink.opacity(0.09), lineWidth: 1))

                if totalNotificationCount > 0 {
                    ZStack {
                        Circle().fill(Color.red)
                        Text(totalNotificationCount < 10 ? "\(totalNotificationCount)" : "9+")
                            .font(V3Typography.sans(8, weight: .bold))
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
        // Prototip sırası: önce büyük başlık, HEMEN ALTINDA mono sayaç.
        // Kodda tersiydi — sayaç başlıktan önce geliyordu ve ekranın ilk
        // okunan şeyi bir kesir oluyordu.
        VStack(alignment: .leading, spacing: ONETokens.spacingSM) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(NSLocalizedString("circle.title", comment: ""))
                        .displayLG()
                        .foregroundColor(V3Tokens.ink)

                    Text(counterText)
                        .monoLabel(tracking: 0.5)
                        .foregroundColor(V3Tokens.mutedText)
                        .animation(ONEAnimation.micro, value: counterText)
                }

                Spacer()

                // Prototipte iki yuvarlak buton: ekle ve bildirim.
                // Keşfet ve hızlı-ekle başlıktan kalktı — Keşfet'in kendi
                // sekmesi, hızlı-eklenin ortadaki FAB'ı var.
                HStack(spacing: 7) {
                    addFriendHeaderButton
                    if !hasNoCircleYet { notificationsHeaderButton }
                }
            }

            // Faz 3 — kendi haftalık ritmin. Arkadaşların renkleri aşağıda,
            // bu satır "sen neredesin"in sessiz cevabı.
            //
            // Arkadaşsız kullanıcıda gizli: prototipte boş ekranın tek işi
            // davet etmek. Ritim satırı oraya ikinci bir mesaj sokuyor ve
            // "1/4 gün" daha ilk açılışta bir eksiklik gibi okunuyor.
            if !weekRhythm.isEmpty && !hasNoCircleYet {
                WeekRhythmView(days: weekRhythm)
                    .padding(.top, 4)
            }
        }
        .padding(.top, ONETokens.spacingXL4)
        .padding(.horizontal, ONETokens.spacingXL)
        .padding(.bottom, 0)
        // Scroll-driven shrink — sabit header, scroll ilerledikçe küçülür.
        // headerShrinkProgress cloudSection'daki GeometryReader'dan geliyor.
        .scaleEffect(1 - headerShrinkProgress * 0.10, anchor: .topLeading)
        .opacity(1 - headerShrinkProgress * 0.55)
        .animation(.easeOut(duration: 0.14), value: headerShrinkProgress)
    }

    // MARK: - Scroll offset PreferenceKey (header shrink)

    struct CircleScrollOffsetKey: PreferenceKey {
        static var defaultValue: CGFloat = 0
        static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
            value = nextValue()
        }
    }

    /// Ham offset → 0-1 progress. İlk 100pt scroll'da tamamen sıkışıyor.
    static func computeShrinkProgress(offset: CGFloat) -> CGFloat {
        let scroll = max(0, -offset)  // yukarı scroll = pozitif
        return min(1, scroll / 100)
    }

    // MARK: - Alt-çevre filtresi

    /// Seçili gruba göre filtrelenmiş arkadaş paylaşımları. "Tümü" (nil)
    /// veya grup bulunamazsa tüm liste döner.
    var displayedShares: [CloudKitManager.FriendCircleData] {
        guard let id = selectedCircleID,
              let circle = subCircles.first(where: { $0.id == id }) else { return friendsShares }
        let members = Set(circle.memberIDs)
        return friendsShares.filter { data in
            (data.user["userID"] as? String).map(members.contains) ?? false
        }
    }

    /// Başlık altındaki yatay grup çipleri: Tümü + gruplar + "düzenle".
    /// Grup yoksa yalnız keşif için tek bir "Gruplar" çipi görünür.
    @ViewBuilder
    private var subCircleChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 7) {
                if !subCircles.isEmpty {
                    chip(title: NSLocalizedString("subcircle.all", comment: ""),
                         emoji: "", colorHex: nil,
                         selected: selectedCircleID == nil) {
                        selectedCircleID = nil
                    }
                    ForEach(subCircles) { circle in
                        chip(title: circle.name, emoji: circle.emoji, colorHex: circle.colorHex,
                             selected: selectedCircleID == circle.id) {
                            selectedCircleID = (selectedCircleID == circle.id) ? nil : circle.id
                        }
                    }
                }

                Button {
                    ONEHaptics.feelingSelected()
                    showSubCircleManager = true
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: subCircles.isEmpty ? "person.2" : "slider.horizontal.3")
                            .font(.system(size: 11, weight: .semibold))
                        if subCircles.isEmpty {
                            Text(NSLocalizedString("subcircle.title", comment: ""))
                                .font(V3Typography.sans(12.5, weight: .semibold))
                        }
                    }
                    .foregroundColor(V3Tokens.mutedText)
                    .padding(.horizontal, subCircles.isEmpty ? 12 : 10)
                    .padding(.vertical, 7)
                    .background(
                        Capsule().stroke(V3Tokens.ink.opacity(0.14),
                                         style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
                    )
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, ONETokens.spacingXL)
        }
        .padding(.top, ONETokens.spacingMD)
    }

    private func chip(title: String, emoji: String, colorHex: String?,
                      selected: Bool, action: @escaping () -> Void) -> some View {
        Button {
            ONEHaptics.feelingSelected()
            withAnimation(.easeOut(duration: 0.16)) { action() }
        } label: {
            HStack(spacing: 5) {
                if let colorHex {
                    Circle().fill(Color(hex: colorHex)).frame(width: 9, height: 9)
                } else if !emoji.isEmpty {
                    Text(emoji).font(V3Typography.sans(12))
                }
                Text(title)
                    .font(V3Typography.sans(12.5, weight: .semibold))
            }
            .foregroundColor(selected ? ONEBrand.bone : V3Tokens.ink)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(
                Capsule().fill(selected ? ONETokens.oneInk : Color.white.opacity(0.7))
            )
            .overlay(
                Capsule().stroke(V3Tokens.ink.opacity(selected ? 0 : 0.1), lineWidth: 1)
            )
            .frame(minWidth: 44, minHeight: 44)
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Cloud Section (structured cards, no overlapping)

    private var cloudSection: some View {
        // v3 talimat 2-kolon ızgara istiyor ama mevcut friendCard tam-genişlik
        // için tasarlandı — 2-kol'da bilgiler kırpılıyor. Kart-yeniden-tasarımı
        // yapılana kadar tek kolon full-width. (Faz 6 polish TODO.)
        ScrollViewReader { proxy in
        ScrollView(showsIndicators: false) {
            // Scroll offset probe — headerSection buradan progress hesaplıyor.
            GeometryReader { geo in
                Color.clear
                    .preference(
                        key: CircleScrollOffsetKey.self,
                        value: geo.frame(in: .named("circleScroll")).minY
                    )
            }
            .frame(height: 0)

            VStack(spacing: 9) {
                // Sekme re-tap anchor'ı.
                Color.clear.frame(height: 0).id("circleTop")

                // ── SEN ──────────────────────────────────────────
                senCard
                    .scaleEffect(bubblesVisible ? 1.0 : 0.92)
                    .opacity(bubblesVisible ? 1.0 : 0)
                    .animation(ONEAnimation.cardSpring, value: bubblesVisible)

                // ── ARKADAŞLAR ────────────────────────────────────
                ForEach(Array(displayedShares.enumerated()), id: \.element.id) { index, data in
                    friendCard(data: data, index: index)
                        .scaleEffect(bubblesVisible ? 1.0 : 0.92)
                        .opacity(bubblesVisible ? 1.0 : 0)
                        .animation(
                            ONEAnimation.cardSpring
                            .delay(ONEAnimation.staggerDelay(index: index + 1, baseDelay: 0.06)),
                            value: bubblesVisible
                        )
                }

                // Seçili grupta bugün kimse yoksa — davet satırını bastırmadan
                // kısa bir not. Hangi grubun aktif olduğunu da belirt ki
                // kullanıcı "bugün gerçekten kimse paylaşmadı" mı yoksa
                // filtre yüzünden mi boş göründüğünü anlasın.
                if let id = selectedCircleID,
                   let activeName = subCircles.first(where: { $0.id == id })?.name,
                   displayedShares.isEmpty {
                    Text("\(activeName) · \(NSLocalizedString("subcircle.emptyToday", comment: ""))")
                        .bodyXS()
                        .foregroundColor(V3Tokens.mutedText)
                        .frame(maxWidth: .infinity)
                        .multilineTextAlignment(.center)
                        .padding(.vertical, 18)
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
            .padding(.horizontal, ONETokens.spacingXL)
            .padding(.top, ONETokens.spacingLG)
            .padding(.bottom, 100)
        }
        .coordinateSpace(name: "circleScroll")
        .onPreferenceChange(CircleScrollOffsetKey.self) { offset in
            headerShrinkProgress = Self.computeShrinkProgress(offset: offset)
        }
        .refreshable {
            await refreshData()
        }
        .onAppear {
            withAnimation(ONEAnimation.screenTransition.delay(0.15)) {
                bubblesVisible = true
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .circleTabRetapped)) { _ in
            withAnimation(.spring(response: 0.42, dampingFraction: 0.88)) {
                proxy.scrollTo("circleTop", anchor: .top)
            }
            Task { await refreshData() }
        }
        } // end ScrollViewReader
    }
    
    // MARK: - Pending Requests Teaser
    
    private var pendingRequestsTeaser: some View {
        Button(action: { showFriendRequests = true }) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(V3Tokens.ink.opacity(0.08))
                        .frame(width: 40, height: 40)
                    Image(systemName: "person.badge.clock")
                        .font(.system(size: 16))
                        .foregroundColor(V3Tokens.ink)
                }
                .accessibilityHidden(true)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(String(format: NSLocalizedString("circle.pendingRequests", comment: ""), pendingRequestCount))
                        .displaySM()
                        .foregroundColor(V3Tokens.ink)
                    Text(NSLocalizedString("circle.tapToApprove", comment: ""))
                        .monoSM(tracking: 0)
                        .foregroundColor(V3Tokens.mutedText)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(V3Tokens.mutedText)
                    .accessibilityHidden(true)
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(V3Tokens.surface.opacity(0.55))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(V3Tokens.ink.opacity(0.15), lineWidth: 1)
                    )
            )
        }
        .accessibilityLabel(String(format: NSLocalizedString("circle.pendingRequests", comment: ""), pendingRequestCount))
        .accessibilityHint(NSLocalizedString("circle.tapToApprove", comment: ""))
    }
    
    
    // MARK: - Rhythm Strip Data


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
