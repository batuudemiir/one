//
//  V3CircleView.swift
//  one
//
//  Çevre — v3 prototip ekran 10.
//
//  Prototipin bağlayıcı ölçüleri:
//   - Başlık Archivo 38pt, tracking −1.1; altında 16pt mut alt satır.
//   - Aksiyon çipleri: Uyum · Arkadaş ekle — 44pt min yükseklik, radius 999,
//     1px hairline kenar, dolgu yok.
//   - Mono sayaç satırı ("N kişi"), 10pt tracking 1.5 uppercase faint.
//   - **2 kolon kart ızgarası**, gap 12. İlk kart kendi kartın: aynı kart ama
//     içeriden 1.5pt ink çerçeve.
//   - Kart: padding 16, radius 20, surface zemin + hairline kenar, dikey 12
//     boşluklu 4 satır → avatar(46, radius 14) · ad+duygu · 6pt renk şeridi ·
//     mono alt satır ("N an" · son saat / kapsam).
//   - Şerit gün içindeki **tüm** anları eşit dilimlerle gösterir; an yoksa
//     düz wash şerit.
//
//  Üst bardaki istek/bildirim ikonları kabukta (`ONEColorPickerView`) duruyor;
//  buraya `.circleOpenRequests` / `.circleOpenNotifications` ile geliyorlar.
//
//  Eski `CircleView` (bubble cloud + alt-çevre çipleri + comeback) yerini bu
//  ekrana bıraktı; alt ekranlar (arkadaş detayı, istekler, bildirimler, QR,
//  arkadaş ekle) aynı dosyalardan sheet olarak sunuluyor.
//

import SwiftUI
import UIKit
import CloudKit
import CoreData

struct V3CircleView: View {
    @Environment(\.managedObjectContext) private var context
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @StateObject private var cloudKitManager = CloudKitManager.shared
    /// Ekran header'ındaki zil noktası bunu okuyor.
    @StateObject private var circleNotifications = CircleNotificationStore.shared

    /// Bugünün arkadaş verisi — her arkadaş için o günün **tüm** anları.
    @State private var friends: [CloudKitManager.FriendCircleData] = []
    /// Kendi bugünkü anların (Core Data — çevrimdışı da doğru).
    @State private var myMoments: [Moment] = []
    /// userID → çözülmüş profil fotoğrafı. Kart ızgarası bunu okuyor.
    @State private var friendPhotos: [String: UIImage] = [:]
    /// Kendi profil fotoğrafı — cache'lenmiş kopyayı gösteriyoruz ki her render
    /// diskten okunmasın. Profil ekranında güncellenince
    /// `.profilePhotoDidChange` gelir, yeniden yüklenir.
    @State private var selfPhoto: UIImage? = nil

    @State private var isLoading = false
    @State private var hasLoadedOnce = false
    @State private var isFetching = false
    @State private var pendingRequestCount = 0
    @State private var appeared = false

    // Alt ekranlar
    @State private var showAddFriend = false
    @State private var showRequests = false
    @State private var showNotifications = false
    @State private var showResonance = false
    @State private var showQRScanner = false
    @State private var deepLinkInviteCode: String? = nil

    /// Push edilen detay yığını. Arkadaş detayı, kendi paylaşımın ve herkese
    /// açık profil eskiden `.sheet` idi; modal oldukları için kenardan geri
    /// kaydırma ve karttan detaya morph mümkün değildi. Artık gerçek push.
    @State private var path: [CircleRoute] = []

    /// Kart → detay zoom geçişi için ortak namespace (iOS 18+).
    @Namespace private var cardTransitionNS
    /// Kendi bugünkü CloudKit paylaşımın — "kendi paylaşımın" detayı bunu ister.
    @State private var myShare: CKRecord? = nil
    /// Üst çubuğun 0→1 zemin/başlık ilerlemesi. Scroll offset'inden geliyor.
    @State private var topBarProgress: CGFloat = 0

    var onNavigateToToday: (() -> Void)? = nil

    /// Bu sekme şu an görünür mü? Kabuk `vm.currentScreen == .circle` ile
    /// besliyor. `TabView` sekmeyi canlı tuttuğu için `onAppear`/`.task`
    /// artık geri dönüşlerde tetiklenmiyor — tazeleme sinyali bu.
    var isActive: Bool = true

    /// DEBUG örnek veri — dolu ise CloudKit'e ve Core Data'ya hiç gidilmez.
    /// `V3CircleSampleData` üzerinden preview ve launch-argument yolu besliyor.
    var injectedSample: (friends: [CloudKitManager.FriendCircleData], moments: [Moment])? = nil

    // MARK: - Body

    var body: some View {
        NavigationStack(path: $path) {
            feed
                .navigationBarHidden(true)
                .navigationDestination(for: CircleRoute.self) { route in
                    zoomDestination(route, destination(for: route))
                        .navigationBarHidden(true)
                }
        }
        // Detay push'undayken kabuğun yatay swipe'ı NavigationStack'in
        // kenardan-geri jestiyle çakışıyor — yığın doluyken kilitle.
        .onChange(of: path.isEmpty) { _, _ in syncSwipeLock() }
        .onChange(of: isActive) { _, _ in syncSwipeLock() }
        .onDisappear {
            GlobalUIState.shared.detailStackLocksSwipe = false
        }
    }

    /// Yalnız sekme görünürken etkili — arka planda duran bir detay yığını
    /// başka sekmenin swipe'ını kilitlememeli.
    private func syncSwipeLock() {
        GlobalUIState.shared.detailStackLocksSwipe = isActive && !path.isEmpty
    }

    // MARK: - Feed (yığının kökü)

    private var feed: some View {
        ScrollViewReader { proxy in
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    // Anchor + scroll-driven tab-bar minimize sensörü.
                    Color.clear.frame(height: 0)
                        .id("circleTop")
                        .scrollOffsetSensor(spaceName: "one.scroll.circle")

                    if injectedSample != nil {
                        mainContent
                    } else if !cloudKitManager.isCloudKitAvailable {
                        CircleCloudKitUnavailableState(
                            cloudKitManager: cloudKitManager,
                            onRetry: {
                                cloudKitManager.checkCloudKitAvailability()
                                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                                    if cloudKitManager.isCloudKitAvailable { loadFriends(force: true) }
                                }
                            },
                            onOpenSettings: {
                                if let url = URL(string: UIApplication.openSettingsURLString) {
                                    UIApplication.shared.open(url)
                                }
                            }
                        )
                        .padding(.top, V3Tokens.spacingXL2)
                    } else if isLoading && !hasLoadedOnce {
                        skeleton
                    } else if hasLoadedOnce && friends.isEmpty {
                        emptyState
                    } else {
                        mainContent
                    }
                }
                .padding(.horizontal, V3Tokens.channel)
                // Dinlenme pozisyonunun tek sahibi kabuk: `safeAreaInset`
                // nav yüksekliği kadar pay bırakıyor. Buradaki fazladan 24pt
                // o payın üstüne biniyordu — son satır çubuğun 16pt üstünde
                // duruyor, çubuk boş kağıdın üzerinde asılı kalıyordu. Cam
                // ancak arkasından bir şey geçerse cam gibi okunur.
            }
            .background(V3Tokens.paper)
            .hidesTabBarOnScroll(tab: .circle, spaceName: "one.scroll.circle")
            .topBarProgress($topBarProgress, spaceName: "one.scroll.circle")
            .safeAreaInset(edge: .top, spacing: 0) {
                // İstek ve bildirim düğmeleri burada. Eskiden scroll
                // içeriğinin ilk satırıydılar — aşağı kaydırınca kayboluyor,
                // "yeni istek var mı" sorusu ekranın dışına çıkıyordu.
                //
                // Ekranın adı da artık burada ve gövdeden kalktı: çubuk
                // "Çevre" derken gövde 40pt aşağıda aynı kelimeyi 38pt
                // Archivo ile tekrar yazıyordu.
                V3TopBar(
                    style: .root,
                    title: PrimaryTab.circle.screenTitle,
                    progress: topBarProgress
                ) {
                    headerActions
                }
            }
            .refreshable { await refresh() }
            .onReceive(NotificationCenter.default.publisher(for: .circleTabRetapped)) { _ in
                withAnimation(ONEAnimation.easing) { proxy.scrollTo("circleTop", anchor: .top) }
                loadFriends(force: true)
            }
        }
        .task {
            if let sample = injectedSample {
                friends = sample.friends
                myMoments = sample.moments
                hasLoadedOnce = true
                appeared = true
                return
            }
            loadMyMoments()
            // Bugüne ait bir şey elimizde varsa onu hemen çiz — skeleton
            // yalnız gerçekten boş başlangıçta görünsün. `loadFriends`
            // arkada tazeliyor ve `isLoading = friends.isEmpty` olduğu için
            // seed edilmiş halde yükleme durumuna hiç girmiyor.
            if let cached = cloudKitManager.circleCacheForDisplay {
                friends = cached
                decodeFriendPhotos(cached)
                hasLoadedOnce = true
            }
            loadFriends()
            loadPendingCount()
        }
        // Sekme artık `TabView` içinde canlı kalıyor: `.task` bir kez çalışır.
        // Kullanıcı Çevre'ye geri döndüğünde veriyi tazelemek için sekmenin
        // görünür olduğu anı dinliyoruz. `loadFriends` cache TTL'ine saygılı,
        // yani hızlı sekme gezinmesi ağa yeni istek açmıyor.
        .onChange(of: isActive) { _, active in
            if active, injectedSample == nil {
                loadMyMoments()
                loadFriends()
                loadPendingCount()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .init("todaySongSaved"))) { _ in
            loadMyMoments()
            loadFriends(force: true)
        }
        // Uzaktan inen an değişikliği.
        //
        // Bu ekran uzun süre **yalnız** `todaySongSaved` dinliyordu, yani
        // başka bir cihazdan gelen an Çevre'ye hiç düşmüyordu — `Archive`,
        // `Profil` ve `Echo` bu bildirimi zaten dinliyordu, Çevre atlanmıştı.
        //
        // `loadFriends(force: true)` **çağrılmıyor**: uzak bir *an*
        // değişikliği arkadaş listesini zorla tazelemeyi gerektirmiyor ve
        // `force` cache TTL'ini atlayıp her senkronda bir CloudKit sorgusu
        // koşturuyor. Tazelenmesi gereken kendi anlarım.
        .onReceive(NotificationCenter.default.publisher(for: .momentsDidChangeRemotely)) { _ in
            loadMyMoments()
        }
        .onReceive(NotificationCenter.default.publisher(for: .init("circleDataNeedsRefresh"))) { _ in
            loadFriends(force: true)
        }
        .onReceive(NotificationCenter.default.publisher(for: .profilePhotoDidChange)) { _ in
            loadSelfPhoto()
        }
        .onReceive(NotificationCenter.default.publisher(for: .circleOpenRequests)) { _ in
            showRequests = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .init("OpenFriendRequests"))) { _ in
            showRequests = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .circleOpenNotifications)) { _ in
            showNotifications = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .init("HandleAddFriendDeepLink"))) { note in
            deepLinkInviteCode = note.object as? String
            showAddFriend = true
        }
        .sheet(isPresented: $showAddFriend, onDismiss: { deepLinkInviteCode = nil; loadFriends(force: true) }) {
            AddFriendScreen(prefilledCode: deepLinkInviteCode)
        }
        .sheet(isPresented: $showRequests, onDismiss: { loadPendingCount(); loadFriends(force: true) }) {
            FriendRequestsView()
        }
        .fullScreenCover(isPresented: $showNotifications) {
            NotificationFeedView(
                onBack: { showNotifications = false },
                onOpenUser: { uid in
                    showNotifications = false
                    path.append(.publicProfile(userID: uid))
                }
            )
        }
        .sheet(isPresented: $showResonance) {
            V3ResonanceView(friends: friends, myMoments: myMoments)
        }
        .v3Sheet()
        .sheet(isPresented: $showQRScanner) {
            QRScannerView { code in
                showQRScanner = false
                deepLinkInviteCode = code
                showAddFriend = true
            }
        }
        .v3Sheet()
    }

    // MARK: - Routes

    /// Push edilebilir detaylar.
    ///
    /// Rota **kimlik** taşıyor, veri değil: `FriendCircleData` bir `CKRecord`
    /// sarmalıyor ve `Hashable` değil, ayrıca tazeleme sonrası kopyası bayat
    /// kalırdı. Kimlikten çözünce açık duran detay, arkada gelen tazelemeyi
    /// otomatik görüyor.
    enum CircleRoute: Hashable {
        case friend(id: String)
        case selfDetail
        case publicProfile(userID: String)
    }

    @ViewBuilder
    private func destination(for route: CircleRoute) -> some View {
        switch route {
        case .friend(let id):
            if let data = friends.first(where: { $0.id == id }) {
                FriendDetailView(friendData: data, onRefresh: { loadFriends(force: true) })
            }
        case .selfDetail:
            if let mine = myShare {
                SelfShareDetailView(share: mine)
            }
        case .publicProfile(let userID):
            FriendProfileScreen(userID: userID, todayShare: nil, onBack: {
                if !path.isEmpty { path.removeLast() }
            })
        }
    }

    /// Karttan detaya zoom geçişinin **kaynağı** (kart tarafı) — iOS 18+.
    /// Altında ve Reduce Motion açıkken düz push'a düşer.
    @ViewBuilder
    private func zoomSource<V: View>(_ id: CircleRoute, _ content: V) -> some View {
        if #available(iOS 18.0, *), !reduceMotion {
            content.matchedTransitionSource(id: id, in: cardTransitionNS)
        } else {
            content
        }
    }

    /// Aynı geçişin **hedefi** (detay tarafı).
    @ViewBuilder
    private func zoomDestination<V: View>(_ id: CircleRoute, _ content: V) -> some View {
        if #available(iOS 18.0, *), !reduceMotion {
            content.navigationTransition(.zoom(sourceID: id, in: cardTransitionNS))
        } else {
            content
        }
    }

    // MARK: - Header actions

    /// İki eylem düğmesi: arkadaş istekleri + bildirimler. `V3TopBar`'ın sağ
    /// yuvasında duruyorlar — çubuk sabit olduğu için scroll'la kaybolmuyorlar.
    ///
    /// Buradaki düğmeler bir dönem bu ekrana özgü 44pt sayaç kapsülleriydi.
    /// Artık çubuğun kendi 36pt dairesi (`V3TopBarIconButton`) + kor rozet:
    /// aynı satırda An'ın hatırlatma, Arşiv'in Yankı düğmesiyle aynı ailede
    /// okunuyorlar. Sayı kayb olmuyor, rozete taşındı.
    private var headerActions: some View {
        HStack(spacing: V3Tokens.spacingXS) {
            V3TopBarIconButton(
                systemName: "person.badge.plus",
                label: NSLocalizedString("circle.requests", comment: ""),
                count: pendingRequestCount
            ) {
                showRequests = true
            }
            V3TopBarIconButton(
                systemName: "bell",
                label: NSLocalizedString("circle.notifications", comment: ""),
                count: circleNotifications.unreadCount
            ) {
                showNotifications = true
            }
        }
    }

    // MARK: - Main content

    private var mainContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Gövde başlığı kalktı — ekranın adı artık üst çubukta ve
            // kaydırmadan da orada. 38pt "Çevre" çubuğun 40pt altında aynı
            // kelimeyi tekrar ediyordu.
            //
            // Alt satır ("Bugün kimin nasıl olduğunu gör.") da kalktı: bir
            // işlev anlatmıyordu, ızgaranın kendisi zaten onu gösteriyor.
            // Kopya kuralı — açıklama metni yalnız o an gerekli işlevsel
            // bilgiyi verir, yoksa hiç yazılmaz.
            HStack(spacing: V3Tokens.spacingSM) {
                actionChip(NSLocalizedString("circle.resonance", comment: "")) {
                        showResonance = true
                }
                actionChip(NSLocalizedString("circle.addFriend", comment: "")) {
                        showAddFriend = true
                }
            }
            .padding(.top, V3Tokens.spacingXL)

            Text(String(format: NSLocalizedString("circle.peopleCount", comment: ""), friends.count))
                .monoLabel(weight: .regular)
                .tracking(1.5)
                .textCase(.uppercase)
                .foregroundColor(V3Tokens.ghostText)
                .padding(.top, V3Tokens.spacingXL2)

            LazyVGrid(
                columns: [GridItem(.flexible(), spacing: V3Tokens.spacingMD), GridItem(.flexible(), spacing: V3Tokens.spacingMD)],
                spacing: V3Tokens.spacingMD
            ) {
                ownCard
                ForEach(friends) { data in
                    friendCard(data)
                }
            }
            .padding(.top, 18)

            if pendingRequestCount > 0 {
                requestsTeaser.padding(.top, V3Tokens.spacingLG)
            }
        }
        .opacity(appeared || reduceMotion ? 1 : 0)
        .offset(y: appeared || reduceMotion ? 0 : 9)
        .animation(reduceMotion ? nil : ONEAnimation.easing, value: appeared)
        .onAppear {
            appeared = true
            loadSelfPhoto()
        }
    }

    // MARK: - Own card

    private var ownCard: some View {
        let hexes = myMoments.map(\.moodColorHex).filter { !$0.isEmpty }
        let mood = hexes.first.flatMap { V3Mood.fromHex($0) }
        let scopeLabel = myMoments.contains(where: { $0.scope == .friends })
            ? NSLocalizedString("circle.scopeShared", comment: "")
            : NSLocalizedString("circle.scopePrivate", comment: "")

        return zoomSource(.selfDetail, Button {
            ONEHaptics.feelingSelected()
            // Paylaşım kaydı elde yoksa (hiç an yok ya da CloudKit kaydı
            // gelmedi) detay yerine An akışına götür.
            if myShare != nil, !myMoments.isEmpty {
                path.append(.selfDetail)
            } else {
                onNavigateToToday?()
            }
        } label: {
            cardBody(
                initial: initial(of: myDisplayName),
                mood: mood,
                title: NSLocalizedString("circle.youCard", comment: ""),
                subtitle: mood?.label ?? NSLocalizedString("circle.youNotShared", comment: ""),
                stripHexes: hexes,
                leftMeta: momentCountLabel(hexes.count),
                rightMeta: myMoments.isEmpty ? "—" : scopeLabel,
                photo: selfPhoto
            )
            .overlay(
                RoundedRectangle(cornerRadius: V3Tokens.radiusPanel, style: .continuous)
                    .strokeBorder(V3Tokens.ink, lineWidth: 1.5)
            )
        }
        .buttonStyle(.onePressable)
        .accessibilityLabel(
            "\(NSLocalizedString("circle.youCard", comment: "")), \(mood?.label ?? NSLocalizedString("circle.youNotShared", comment: "")), \(momentCountLabel(hexes.count))"
        ))
    }

    // MARK: - Friend card

    private func friendCard(_ data: CloudKitManager.FriendCircleData) -> some View {
        // `.private` anlar servisten hiç gelmiyor; burada ek filtre yok —
        // veri katmanı zaten paylaşılmışları döndürüyor.
        let shares = data.shares.filter { !(($0["moodColor"] as? String) ?? "").isEmpty }
        let hexes = shares.compactMap { $0["moodColor"] as? String }
        let mood = hexes.first.flatMap { V3Mood.fromHex($0) }
        let name = data.user["displayName"] as? String ?? "?"
        let moodWord = (shares.first?["moodWord"] as? String).flatMap { $0.isEmpty ? nil : $0 }
        let lastTime = timeString(shares.last?["createdAt"] as? Date)

        let state = mood?.label ?? moodWord?.capitalized
            ?? NSLocalizedString("circle.notSharedToday", comment: "")

        return zoomSource(.friend(id: data.id), Button {
            ONEHaptics.feelingSelected()
            path.append(.friend(id: data.id))
        } label: {
            cardBody(
                initial: initial(of: name),
                mood: mood,
                title: name,
                subtitle: state,
                stripHexes: hexes,
                leftMeta: momentCountLabel(hexes.count),
                rightMeta: lastTime.isEmpty ? "—" : lastTime,
                photo: friendPhotos[data.id]
            )
        }
        .buttonStyle(.onePressable)
        // Kart görsel olarak dört satır: ad, duygu, renk şeridi, mono meta.
        // Şerit ve meta satırı VoiceOver'da hiç okunmuyordu — an sayısı ve
        // son paylaşım saati kartın bilgisinin yarısı. Hepsi tek cümlede.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            [name, state, momentCountLabel(hexes.count), lastTime]
                .filter { !$0.isEmpty && $0 != "—" }
                .joined(separator: ", ")
        )
        .accessibilityAddTraits(.isButton))
    }

    // MARK: - Shared card body

    /// Prototip 46pt diyor; büyük metin ayarlarında içindeki harf kutuyu
    /// taşırdığı için birlikte ölçekleniyor.
    @ScaledMetric(relativeTo: .title3) private var avatarSize: CGFloat = 46

    private func cardBody(
        initial: String,
        mood: V3Mood?,
        title: String,
        subtitle: String,
        stripHexes: [String],
        leftMeta: String,
        rightMeta: String,
        photo: UIImage? = nil
    ) -> some View {
        VStack(alignment: .leading, spacing: V3Tokens.spacingMD) {
            // Avatar — 46pt, radius 46×0.3 ≈ 14.
            // Fotoğraf varsa o, yoksa kişinin bugünkü renginde baş harf.
            // (Kart eskiden fotoğrafı hiç okumuyordu; kullanıcının yüklediği
            // fotoğraf yalnız arkadaş detayında görünüyordu.)
            Group {
                if let photo {
                    Image(uiImage: photo)
                        .resizable()
                        .scaledToFill()
                        .frame(width: avatarSize, height: avatarSize)
                        .clipShape(RoundedRectangle(cornerRadius: avatarSize * 0.3, style: .continuous))
                        // Renk bilgisi kaybolmasın: fotoğrafın kenarı o günün rengi.
                        .overlay(
                            RoundedRectangle(cornerRadius: avatarSize * 0.3, style: .continuous)
                                .strokeBorder(mood?.color ?? V3Tokens.hairline, lineWidth: mood == nil ? 1 : 2)
                        )
                } else {
                    Text(initial)
                        .font(ONEBrand.display(18))
                        .tracking(-0.5)
                        .foregroundColor(mood?.ink ?? V3Tokens.ghostText)
                        .frame(width: avatarSize, height: avatarSize)
                        .background(
                            RoundedRectangle(cornerRadius: avatarSize * 0.3, style: .continuous)
                                .fill(mood?.color ?? V3Tokens.wash)
                        )
                }
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .bodyLGSemibold()
                    .foregroundColor(V3Tokens.ink)
                    // Uzun adlar ve büyük metin ayarları tek satıra sığmıyor.
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
                Text(subtitle)
                    .bodyXS()
                    .foregroundColor(V3Tokens.mutedText)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
                    .truncationMode(.tail)
            }
            .fixedSize(horizontal: false, vertical: true)

            // 6pt şerit — günün anları eşit dilimlerle.
            Group {
                if stripHexes.isEmpty {
                    Capsule().fill(V3Tokens.wash)
                } else {
                    HStack(spacing: 3) {
                        ForEach(Array(stripHexes.enumerated()), id: \.offset) { _, hex in
                            Rectangle()
                                .fill(Color(hex: hex))
                                // 6pt'lik şerit gün içindeki anları yalnız
                                // renkle ayırıyordu — desen ikinci kanal.
                                .moodPattern(V3Mood.fromHex(hex), lineWidth: 0.7)
                        }
                    }
                    .clipShape(Capsule())
                }
            }
            .frame(height: 6)

            HStack {
                Text(leftMeta)
                Spacer(minLength: 6)
                Text(rightMeta)
            }
            .monoLabel(weight: .regular)
            .tracking(1)
            .textCase(.uppercase)
            .foregroundColor(V3Tokens.ghostText)
            .lineLimit(1)
            // İki kolonlu ızgarada mono meta satırı en dar eleman; büyük
            // metin ayarlarında "3 AN" / "21:14" yerine "…" görünmesin.
            .minimumScaleFactor(0.7)
        }
        .padding(V3Tokens.spacingLG)
        .frame(maxWidth: .infinity, alignment: .leading)
        .oneCardBackground(radius: V3Tokens.radiusPanel)
        .contentShape(RoundedRectangle(cornerRadius: V3Tokens.radiusPanel, style: .continuous))
    }

    // MARK: - Empty state (prototip 11)

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(NSLocalizedString("circle.v3EmptyTitle", comment: ""))
                .font(ONEBrand.display(38))
                .tracking(-1.1)
                .foregroundColor(V3Tokens.ink)
                .padding(.top, 30)

            Text(NSLocalizedString("circle.v3EmptyBody", comment: ""))
                .bodyLG()
                .foregroundColor(V3Tokens.mutedText)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, V3Tokens.spacingMD)

            LazyVGrid(
                columns: [GridItem(.flexible(), spacing: V3Tokens.spacingMD), GridItem(.flexible(), spacing: V3Tokens.spacingMD)],
                spacing: V3Tokens.spacingMD
            ) {
                ForEach(0..<4, id: \.self) { i in
                    RoundedRectangle(cornerRadius: V3Tokens.radiusPanel, style: .continuous)
                        .strokeBorder(
                            i == 0 ? ONEBrand.kor : V3Tokens.hairline,
                            style: StrokeStyle(lineWidth: 1.5, dash: [6, 5])
                        )
                        .aspectRatio(1, contentMode: .fit)
                }
            }
            .padding(.top, 30)

            VStack(spacing: 10) {
                Button {
                    showAddFriend = true
                } label: {
                    Text(NSLocalizedString("circle.addFriend", comment: ""))
                        .bodyLGSemibold()
                        .foregroundColor(V3Tokens.paper)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 17)
                        .background(Capsule().fill(V3Tokens.ink))
                }
                .buttonStyle(.onePressable)

                Button {
                    showQRScanner = true
                } label: {
                    Text(NSLocalizedString("circle.scanQR", comment: ""))
                        .bodyLGSemibold()
                        .foregroundColor(V3Tokens.ink)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 17)
                        .background(Capsule().strokeBorder(V3Tokens.hairline, lineWidth: 1.5))
                }
                .buttonStyle(.onePressable)
            }
            .padding(.top, 28)
        }
    }

    // MARK: - Skeleton

    private var skeleton: some View {
        VStack(alignment: .leading, spacing: 18) {
            RoundedRectangle(cornerRadius: V3Tokens.radiusChip).fill(V3Tokens.wash)
                .frame(width: 160, height: 34)
            LazyVGrid(
                columns: [GridItem(.flexible(), spacing: V3Tokens.spacingMD), GridItem(.flexible(), spacing: V3Tokens.spacingMD)],
                spacing: V3Tokens.spacingMD
            ) {
                ForEach(0..<4, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: V3Tokens.radiusPanel, style: .continuous)
                        .fill(V3Tokens.wash)
                        .frame(height: 150)
                }
            }
        }
        .padding(.top, V3Tokens.spacingXL2)
        .shimmeringCircle()
    }

    // MARK: - Bits

    private func actionChip(_ label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .bodySMMedium()
                .foregroundColor(V3Tokens.ink)
                .padding(.horizontal, 15)
                .frame(minHeight: 44)
                .background(Capsule().strokeBorder(V3Tokens.hairline, lineWidth: 1))
        }
        .buttonStyle(.onePressable)
    }

    private var requestsTeaser: some View {
        Button {
            showRequests = true
        } label: {
            HStack(spacing: V3Tokens.spacingMD) {
                Text(String(format: NSLocalizedString("circle.pendingRequests", comment: ""), pendingRequestCount))
                    .bodyMDMedium()
                    .foregroundColor(V3Tokens.ink)
                Spacer()
                Image(systemName: "chevron.right")
                    .iconSM(weight: .semibold)
                    .foregroundColor(V3Tokens.ghostText)
            }
            .padding(V3Tokens.spacingLG)
            .oneCardBackground(radius: V3Tokens.radiusPanel)
        }
        .buttonStyle(.onePressable)
    }

    // MARK: - Derived

    private var myDisplayName: String {
        cloudKitManager.currentUser?["displayName"] as? String ?? "?"
    }

    private func initial(of name: String) -> String {
        String(name.prefix(1)).uppercased()
    }

    private func momentCountLabel(_ n: Int) -> String {
        n == 0 ? "—" : String(format: NSLocalizedString("circle.momentCount", comment: ""), n)
    }

    private func timeString(_ date: Date?) -> String {
        guard let date else { return "" }
        return ONEFormatters.time.string(from: date)
    }

    // MARK: - Data

    private func loadMyMoments() {
        let req: NSFetchRequest<DailySong> = DailySong.fetchRequest()
        let start = Calendar.current.startOfDay(for: Date())
        let end = Calendar.current.date(byAdding: .day, value: 1, to: start) ?? start
        req.predicate = NSPredicate(format: "date >= %@ AND date < %@", start as NSDate, end as NSDate)
        req.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: true)]
        let rows = (try? context.fetch(req)) ?? []
        myMoments = rows.compactMap { Moment(from: $0) }.sorted { $0.time < $1.time }
    }

    private func loadFriends(force: Bool = false) {
        guard !isFetching else { return }
        guard cloudKitManager.isCloudKitAvailable else {
            hasLoadedOnce = true
            return
        }
        isFetching = true
        isLoading = friends.isEmpty
        if force { cloudKitManager.cachedCircleData = nil; cloudKitManager.circleDataLastFetched = nil }

        cloudKitManager.fetchUserDailyShare(for: Date()) { result in
            DispatchQueue.main.async {
                myShare = (try? result.get())
            }
        }

        cloudKitManager.fetchFriendsDailyShares(for: Date()) { result in
            DispatchQueue.main.async {
                isFetching = false
                isLoading = false
                hasLoadedOnce = true
                if case .success(let list) = result {
                    friends = list
                    cloudKitManager.friendsSharedTodayCount = list.filter { $0.share != nil }.count
                    writeFriendSharesToWidget(list)
                    computeUnseenCount(list)
                    decodeFriendPhotos(list)
                }
            }
        }
    }

    /// Kendi profil fotoğrafını off-main thread'de diskten oku, main'de commit et.
    private func loadSelfPhoto() {
        DispatchQueue.global(qos: .userInitiated).async {
            let img = ProfileViewModel.loadProfilePhotoFromDisk()
            DispatchQueue.main.async {
                self.selfPhoto = img
            }
        }
    }

    /// Arkadaşların profil fotoğrafları. `CKAsset.fileURL` diskten okunuyor;
    /// bu iş main thread'de yapılırsa ızgara kaydırırken takılır.
    ///
    /// Not: asset URL'i `CKRecord` yaşadığı sürece geçerli — bu yüzden veri
    /// gelir gelmez `UIImage`'a çözülüp saklanıyor, URL saklanmıyor.
    private func decodeFriendPhotos(_ list: [CloudKitManager.FriendCircleData]) {
        let pending = list.compactMap { data -> (String, URL)? in
            guard friendPhotos[data.id] == nil,
                  let asset = data.user["profilePhoto"] as? CKAsset,
                  let url = asset.fileURL else { return nil }
            return (data.id, url)
        }
        guard !pending.isEmpty else { return }

        DispatchQueue.global(qos: .userInitiated).async {
            var decoded: [String: UIImage] = [:]
            for (id, url) in pending {
                if let data = try? Data(contentsOf: url), let image = UIImage(data: data) {
                    decoded[id] = image
                }
            }
            guard !decoded.isEmpty else { return }
            DispatchQueue.main.async {
                friendPhotos.merge(decoded) { _, new in new }
            }
        }
    }

    /// Sekme çubuğundaki kor nokta — bugün görülmemiş paylaşım sayısı.
    /// İşaretleyiciyi `FriendDetailView` yazıyor (`seenShare_<uid>_<gün>`).
    private func computeUnseenCount(_ list: [CloudKitManager.FriendCircleData]) {
        let f = ONEFormatters.dayKey
        let today = f.string(from: Date())
        let count = list.filter { data in
            guard data.share != nil, let uid = data.user["userID"] as? String else { return false }
            return !UserDefaults.standard.bool(forKey: "seenShare_\(uid)_\(today)")
        }.count
        cloudKitManager.unseenFriendShareCount = count
    }

    /// Çevre widget'ı (4×2) dört arkadaşın bugünkü rengini buradan okuyor.
    private func writeFriendSharesToWidget(_ shares: [CloudKitManager.FriendCircleData]) {
        let dicts = shares.compactMap { data -> [String: String]? in
            guard let name = data.user["displayName"] as? String ?? data.user["userID"] as? String else { return nil }
            let share = data.share
            return [
                "name": name,
                "songName": share?["songName"] as? String ?? "",
                "artistName": share?["artistName"] as? String ?? "",
                "moodColorHex": share?["moodColor"] as? String ?? "#5B8DEF",
                "moodWord": share?["moodWord"] as? String ?? ""
            ]
        }
        WidgetDataWriter.writeFriendShares(dicts)
    }

    private func loadPendingCount() {
        cloudKitManager.fetchPendingRequestCount { count in
            DispatchQueue.main.async { pendingRequestCount = count }
        }
    }

    private func refresh() async {
        await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
            loadMyMoments()
            loadPendingCount()
            cloudKitManager.cachedCircleData = nil
            cloudKitManager.circleDataLastFetched = nil
            cloudKitManager.fetchFriendsDailyShares(for: Date()) { result in
                DispatchQueue.main.async {
                    if case .success(let list) = result { friends = list }
                    hasLoadedOnce = true
                    cont.resume()
                }
            }
        }
    }
}

// MARK: - Press style


#if DEBUG
// MARK: - Previews

#Preview("Çevre · dolu") {
    let sample = (V3CircleSampleData.friends(), V3CircleSampleData.myMoments())
    return ZStack {
        V3Tokens.paper.ignoresSafeArea()
        V3CircleView(injectedSample: sample)
    }
}

#Preview("Çevre · dolu · koyu") {
    let sample = (V3CircleSampleData.friends(), V3CircleSampleData.myMoments())
    return ZStack {
        V3Tokens.paper.ignoresSafeArea()
        V3CircleView(injectedSample: sample)
    }
    .preferredColorScheme(.dark)
}

#Preview("Çevre · boş") {
    ZStack {
        V3Tokens.paper.ignoresSafeArea()
        V3CircleView(injectedSample: ([], []))
    }
}
#endif
