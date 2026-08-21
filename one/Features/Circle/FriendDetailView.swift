//
//  FriendDetailView.swift
//  one
//
//  Arkadaşın günlük müzik detayını gösterir.
//  Şarkı seçilmemiş olsa bile açılır; seçilince CloudKit'ten çekerek otomatik güncellenir.
//

import SwiftUI
import CloudKit

struct FriendDetailView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var cloudKitManager = CloudKitManager.shared

    let friendData: CloudKitManager.FriendCircleData
    var onRefresh: (() -> Void)?

    // Live state — başta friendData'dan geliyor, sonra canlı güncellenebilir
    @State private var share: CKRecord?
    @State private var isPolling       = false
    @ObservedObject private var previewer = SongPreviewPlayer.shared
    @State private var stableSong: SongResult? = nil   // UUID'si sabit, playingID karşılaştırması için
    @State private var appeared        = false
    @State private var sentEmoji: String? = nil
    @State private var showPhotoViewer = false
    @State private var showRemoveAlert = false
    @State private var showBlockAlert  = false
    @State private var profilePhotoPressed = false
    @State private var showFriendProfile = false  // v2.6 — public profile sheet
    @State private var friendProfileImageCache: UIImage? = nil
    @State private var cardPhotoCache: UIImage? = nil  // sync I/O'yu pre-load eder; tap anında jank olmaz

    private var displayName: String {
        friendData.user["displayName"] as? String ?? "Arkadaş"
    }
    /// An ekranında yalnız ad görünür — soyad kimlik kartı bilgisi gibi
    /// duruyor ve başlığı gereksiz uzatıyor. Profil ve liste ekranlarında
    /// tam ad durmaya devam ediyor.
    private var firstName: String { displayName.firstNameOnly }
    private var initial: String { String(displayName.prefix(1)).uppercased() }
    private var avatarColorHex: String {
        share?["moodColor"] as? String
            ?? friendData.user["avatarColor"] as? String
            ?? "#888888"
    }

    private var hasSong: Bool {
        guard let s = share else { return false }
        return !((s["songName"] as? String) ?? "").isEmpty
    }

    private func buildSongResult(from s: CKRecord) -> SongResult? {
        guard let name = s["songName"] as? String, !name.isEmpty,
              let artist = s["artistName"] as? String else { return nil }
        return SongResult(
            id: UUID(),
            name: name,
            artist: artist,
            genre: s["genre"] as? String ?? "",
            coverURL: nil,
            spotifyURL: nil,
            artworkURLString: s["albumArtURL"] as? String
        )
    }

    private var friendMusicTasteVisible: Bool {
        let raw = friendData.user["musicTasteVisible"] as? Int64
        return raw.map { $0 != 0 } ?? true
    }

    private var friendMoodHistoryVisible: Bool {
        let raw = friendData.user["moodHistoryVisible"] as? Int64
        return raw.map { $0 != 0 } ?? true
    }

    var body: some View {
        ZStack {
            V3Tokens.paper.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    headerSection
                    if hasSong {
                        if friendMusicTasteVisible {
                            songCard
                        } else {
                            privacyPlaceholder(label: "Müzik Paylaşımı")
                        }
                        if let ownerID = friendData.user["userID"] as? String,
                           let recordName = share?.recordID.recordName, !recordName.isEmpty {
                            ReactionComposer(
                                shareRecordName: recordName,
                                shareOwnerID: ownerID,
                                friendDisplayName: displayName
                            )
                            .padding(.horizontal, 20)
                            .padding(.top, 16)
                            .padding(.bottom, 8)
                        } else if friendMoodHistoryVisible {
                            emojiRow
                        }
                    } else {
                        waitingSection
                    }

                    closeBtn
                }
            }

            if showPhotoViewer, let img = cardPhotoCache {
                PhotoDataViewerSheet(image: img, isPresented: $showPhotoViewer)
                    .transition(.opacity)
                    .zIndex(999)
            }
        }
        .liquidGlassSheetBackground()
        .sheet(isPresented: $showFriendProfile) {
            // v2.6 — Arkadaşın aggregate profili
            PublicProfileView(userID: friendData.user["userID"] as? String ?? "")
        }
        .v3Sheet()
        .overlay {
            if profilePhotoPressed, let img = friendProfileImageCache {
                ZStack {
                    Color.black.opacity(0.72)
                        .ignoresSafeArea()
                        .transition(.opacity)

                    Image(uiImage: img)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 280, height: 280)
                        .clipShape(Circle())
                        .shadow(color: .black.opacity(0.4), radius: 60, x: 0, y: 20)
                        .transition(.scale(scale: 0.45).combined(with: .opacity))
                }
                .allowsHitTesting(false)
            }
        }
        // Uzun basma bir "peek": 280pt fotoğraf 0.45'ten açılıyor. Basma
        // geri bildirimi değil, parmağa bağlı bir açılış — bu yüzden
        // `easingPress` (0.12s) değil `micro`. Aşağıdaki `withAnimation`
        // ile aynı token olmalı, yoksa açılış ve kapanış ayrışır.
        .animation(ONEAnimation.micro, value: profilePhotoPressed)
        .alert(NSLocalizedString("circle.removeFriend", comment: ""), isPresented: $showRemoveAlert) {
            Button(NSLocalizedString("circle.removeAction", comment: ""), role: .destructive) { removeFriend() }
            Button(NSLocalizedString("general.cancel", comment: ""), role: .cancel) { }
        } message: {
            Text(String(format: NSLocalizedString("circle.removeConfirmMessage", comment: ""), displayName))
        }
        .alert(NSLocalizedString("circle.blockUser", comment: ""), isPresented: $showBlockAlert) {
            Button(NSLocalizedString("circle.blockAction", comment: ""), role: .destructive) { blockUser() }
            Button(NSLocalizedString("general.cancel", comment: ""), role: .cancel) { }
        } message: {
            Text(String(format: NSLocalizedString("circle.blockConfirmMessage", comment: ""), displayName))
        }
        .onAppear {
            share = friendData.share
            withAnimation(ONEAnimation.screenTransition) { appeared = true }
            loadSentEmoji()
            markShareAsSeen()
            // Eğer şarkı henüz seçilmemişse polling başlat
            if !hasSong { startPolling() }

            DispatchQueue.global(qos: .userInitiated).async {
                guard let asset = friendData.user["profilePhoto"] as? CKAsset,
                      let url = asset.fileURL,
                      let data = try? Data(contentsOf: url),
                      let img = UIImage(data: data) else { return }
                DispatchQueue.main.async { friendProfileImageCache = img }
            }

            // Kart fotoğrafını background thread'de pre-load et — tap anında sync
            // I/O olmasın (60fps tap-to-open) ve dismiss yumuşak kalsın.
            DispatchQueue.global(qos: .userInitiated).async {
                guard let asset = (share ?? friendData.share)?["photoAsset"] as? CKAsset,
                      let url = asset.fileURL,
                      let data = try? Data(contentsOf: url),
                      let img = UIImage(data: data) else { return }
                DispatchQueue.main.async { cardPhotoCache = img }
            }

            // Auto-play arkadaşın şarkısını (UUID'yi bir kez üretip sakla)
            let record = share ?? friendData.share
            if stableSong == nil, let rec = record, let song = buildSongResult(from: rec) {
                stableSong = song
            }
            if let song = stableSong {
                previewer.toggle(song)
            }
        }
        .onChange(of: share?.recordID.recordName) { _, newName in
            guard newName != nil else { return }
            // Yeni share geldiğinde foto cache'ini yenile
            if let asset = share?["photoAsset"] as? CKAsset {
                DispatchQueue.global(qos: .userInitiated).async {
                    guard let url = asset.fileURL,
                          let data = try? Data(contentsOf: url),
                          let img = UIImage(data: data) else { return }
                    DispatchQueue.main.async { cardPhotoCache = img }
                }
            }
        }
        .onDisappear {
            isPolling = false
            previewer.stop()
        }
        // CircleView'den gelen canlı güncelleme sinyali
        .onReceive(NotificationCenter.default.publisher(for: .init("circleDataNeedsRefresh"))) { _ in
            fetchLatestShare()
        }
    }

    // MARK: - Header

    private var friendStreak: Int {
        friendData.share?["currentStreak"] as? Int ?? 0
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                // Avatar + isim
                HStack(spacing: 12) {
                    ZStack {
                        if let img = friendProfileImageCache {
                            Image(uiImage: img)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 46, height: 46)
                                .clipShape(Circle())
                                .overlay(
                                    Circle()
                                        .stroke(Color(hex: avatarColorHex).opacity(0.4), lineWidth: 1.5)
                                )
                        } else {
                            Circle()
                                .fill(Color(hex: avatarColorHex))
                                .frame(width: 46, height: 46)
                                .overlay(
                                    Text(initial)
                                        .font(ONEBrand.display(22))
                                        .tracking(-0.4)
                                        .foregroundColor(.white.opacity(0.9))
                                )
                        }
                    }
                    .onLongPressGesture(minimumDuration: 0.2, pressing: { isPressing in
                        withAnimation(ONEAnimation.micro) {
                            profilePhotoPressed = isPressing
                        }
                        if isPressing, friendProfileImageCache != nil { ONEHaptics.feelingSelected() }
                    }, perform: {})

                    Text(firstName.uppercased())
                        .monoSM(tracking: 1.6)
                        .foregroundColor(V3Tokens.mutedText)
                }

                Spacer()

                HStack(spacing: 10) {
                    // v3: friend profilinde streak/rozet yasak.
                    // Menü
                    Menu {
                        Button {
                            showFriendProfile = true
                        } label: {
                            Label("Profili gör", systemImage: "person.crop.circle")
                        }
                        Button(role: .destructive) { showRemoveAlert = true } label: {
                            Label(NSLocalizedString("circle.removeAction", comment: ""), systemImage: "person.fill.xmark")
                        }
                        Button(role: .destructive) { showBlockAlert = true } label: {
                            Label(NSLocalizedString("circle.blockAction", comment: ""), systemImage: "nosign")
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(V3Tokens.faintText)
                            .frame(width: 32, height: 32)
                            .contentShape(Rectangle())
                    }
                }
            }

            Text(hasSong
                 ? NSLocalizedString("circle.todayFeeling", comment: "")
                 : NSLocalizedString("circle.notSelectedYet", comment: ""))
                .displayLG()
                .foregroundColor(V3Tokens.ink)
                .lineSpacing(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, V3Tokens.spacingXL2)
        .padding(.top, V3Tokens.spacingXL5)
        .padding(.bottom, 24)
        .opacity(appeared ? 1 : 0)
        .animation(ONEAnimation.panelSpring.delay(0.05), value: appeared)
    }

    // MARK: - Waiting section (no song yet)

    private var waitingSection: some View {
        WaitingView(initial: initial, displayName: displayName, isPolling: isPolling, appeared: appeared)
    }

    private struct WaitingView: View {
        let initial: String
        let displayName: String
        let isPolling: Bool
        let appeared: Bool

        @State private var pulseScale: CGFloat = 1.0
        @State private var pulseOpacity: Double = 0.35

        var body: some View {
            VStack(spacing: 24) {
                // Avatar ile pulse halkaları
                ZStack {
                    // Dış halka 2
                    Circle()
                        .stroke(Color.gray.opacity(0.08 * pulseOpacity * 3), lineWidth: 1)
                        .frame(width: 100 * pulseScale, height: 100 * pulseScale)
                    // Dış halka 1
                    Circle()
                        .stroke(Color.gray.opacity(0.12 * pulseOpacity * 3), lineWidth: 1)
                        .frame(width: 84 * pulseScale, height: 84 * pulseScale)
                    // Ana daire
                    Circle()
                        .stroke(Color.gray.opacity(0.25),
                                style: StrokeStyle(lineWidth: 1.5, dash: [4, 5]))
                        .frame(width: 72, height: 72)
                    Text(initial)
                        .font(ONEBrand.display(22))
                        .tracking(-0.4)
                        .foregroundColor(Color.gray.opacity(0.4))
                }
                .onAppear {
                    withAnimation(.easeInOut(duration: 2.2).repeatForever(autoreverses: true)) {
                        pulseScale   = 1.08
                        pulseOpacity = 0.8
                    }
                }
                .padding(.top, 8)

                VStack(spacing: 8) {
                    Text(NSLocalizedString("circle.waitingPick", comment: ""))
                        .displayMD()
                        .foregroundColor(V3Tokens.mutedText)

                    Text(displayName.firstNameOnly + " " + NSLocalizedString("circle.willAppear", comment: ""))
                    .monoSM(tracking: 0.3)
                    .foregroundColor(V3Tokens.mutedText)
                }
                .multilineTextAlignment(.center)

                if isPolling {
                    HStack(spacing: 6) {
                        ProgressView().scaleEffect(0.65).tint(V3Tokens.mutedText)
                        Text(NSLocalizedString("circle.updating", comment: ""))
                            .monoLabel(tracking: 0.3)
                            .foregroundColor(V3Tokens.mutedText)
                    }
                }
            }
            .padding(.horizontal, 40)
            .padding(.vertical, 36)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.white.opacity(0.5))
                    .overlay(RoundedRectangle(cornerRadius: 20).stroke(V3Tokens.wash, lineWidth: 1))
            )
            .padding(.horizontal, 20)
            .scaleEffect(appeared ? 1 : 0.94)
            .opacity(appeared ? 1 : 0)
            .animation(ONEAnimation.panelSpring.delay(0.15), value: appeared)
        }
    }

    // MARK: - Song card

    @ViewBuilder
    private var songCard: some View {
        if let s = share {
            songCardContent(s)
                .scaleEffect(appeared ? 1 : 0.94)
                .opacity(appeared ? 1 : 0)
                .animation(ONEAnimation.panelSpring.delay(0.15), value: appeared)
        }
    }

    @ViewBuilder
    private func songCardContent(_ s: CKRecord) -> some View {
        let moodHex    = s["moodColor"]  as? String ?? "#5B8DEF"
        let moodColor  = Color(hex: moodHex)
        let songName   = s["songName"]   as? String ?? ""
        let artistName = s["artistName"] as? String ?? ""
        let moodWord   = s["moodWord"]   as? String ?? ""
        let genre      = s["genre"]      as? String ?? ""
        let platform   = s["platform"]   as? String ?? ""
        let dailyNote  = (s["dailyNote"] as? String).flatMap { $0.isEmpty ? nil : $0 }
        let wIcon      = (s["weatherIcon"] as? String) ?? "☀️"
        let wDesc      = s["weatherDesc"] as? String ?? ""
        let photoData: Data? = (s["photoAsset"] as? CKAsset)?.fileURL.flatMap { try? Data(contentsOf: $0) }

        VStack(spacing: 0) {
            // Header — photo or gradient
            ZStack(alignment: .bottomLeading) {
                if let data = photoData, let img = UIImage(data: data) {
                    Button { showPhotoViewer = true } label: {
                        Image(uiImage: img)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(height: 180)
                            .clipped()
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.onePressable)
                } else {
                    LinearGradient(
                        stops: [.init(color: moodColor.opacity(0.65), location: 0),
                                .init(color: moodColor.opacity(0.15), location: 1)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )
                    .frame(height: 180)
                }
                timeBadge(s)

                // Preview indicator — top trailing
                if let song = stableSong {
                    HStack(spacing: 0) {
                        Spacer()
                        Button(action: { previewer.toggle(song) }) {
                            Group {
                                if previewer.playingID == song.id {
                                    AudioWaveform()
                                        .padding(10)
                                        .background(Circle().fill(Color.black.opacity(0.35)))
                                } else if previewer.loadingID == song.id {
                                    ProgressView().scaleEffect(0.7).tint(.white)
                                        .frame(width: 36, height: 36)
                                        .background(Circle().fill(Color.black.opacity(0.35)))
                                } else {
                                    Image(systemName: "play.fill")
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundStyle(.white)
                                        .frame(width: 36, height: 36)
                                        .background(Circle().fill(Color.black.opacity(0.35)))
                                }
                            }
                        }
                        .buttonStyle(.onePressable)
                        .padding(14)
                    }
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .frame(height: 180, alignment: .top)
                }
            }
            .frame(height: 180).frame(maxWidth: .infinity)

            // Info
            VStack(alignment: .leading, spacing: V3Tokens.spacingLG) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(songName)
                            .displayMD()
                            .foregroundColor(V3Tokens.ink).tracking(-0.8).lineLimit(2)
                        Text(artistName)
                            .monoSM(tracking: 0)
                            .foregroundColor(V3Tokens.mutedText)
                    }
                    Spacer()
                    // Platform rozeti
                    if !platform.isEmpty {
                        HStack(spacing: 4) {
                            Image(systemName: platform.lowercased().contains("spotify")
                                  ? "music.note" : "music.note.list")
                                .font(.system(size: 9, weight: .medium))
                            Text(platform.contains("Spotify") ? "Spotify" : "Apple")
                                .font(V3Typography.mono(9, weight: .medium))
                                .tracking(0.3)
                        }
                        .foregroundColor(V3Tokens.mutedText)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(V3Tokens.hairline.opacity(0.8))
                        )
                    }
                }
                if !genre.isEmpty {
                    Text(genre)
                        .monoLabel(tracking: 0.5)
                        .foregroundColor(V3Tokens.mutedText)
                }

                Rectangle().fill(V3Tokens.wash).frame(height: 1).padding(.vertical, 4)

                if !moodWord.isEmpty {
                    HStack(spacing: 6) {
                        Circle().fill(moodColor).frame(width: 7, height: 7)
                        Text(moodWord.uppercased())
                            .monoLabel(tracking: 1.2)
                            .foregroundColor(V3Tokens.mutedText)
                    }
                    .padding(.horizontal, V3Tokens.spacingMD).padding(.vertical, 6)
                    .background(Capsule().fill(moodColor.opacity(0.12)))
                }

                if !wDesc.isEmpty {
                    HStack(spacing: 5) {
                        Text(wIcon).bodyMicro()
                        Text(wDesc).monoSM(tracking: 0).foregroundColor(V3Tokens.mutedText)
                    }
                }

                if let note = dailyNote {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(NSLocalizedString("circle.note", comment: "")).monoSM(tracking: 1.5).foregroundColor(V3Tokens.mutedText)
                        Text(note).bodySM().foregroundColor(V3Tokens.ink).lineSpacing(2)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(V3Tokens.spacingLG)
                    .background(RoundedRectangle(cornerRadius: 12).fill(moodColor.opacity(0.08)))
                    .padding(.top, V3Tokens.spacingLG)
                }
            }
            .padding(20).frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(V3Tokens.surface)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: .black.opacity(0.06), radius: 20, x: 0, y: 8)
        .padding(.horizontal, 20)
    }

    @ViewBuilder
    private func timeBadge(_ s: CKRecord) -> some View {
        if let createdAt = s["createdAt"] as? Date {
            let t = DateFormatter()
            let _ = { t.dateFormat = "HH:mm" }()
            HStack(spacing: 6) {
                Circle().fill(Color.white.opacity(0.9)).frame(width: 6, height: 6)
                Text(String(format: NSLocalizedString("today.timeSelected", comment: ""), t.string(from: createdAt)))
                    .monoSM(tracking: 1)
                    .foregroundColor(.white.opacity(0.85))
            }
            .padding(.horizontal, 12).padding(.vertical, 6)
            .background(Capsule().fill(Color.white.opacity(0.15)))
            .padding(20)
        }
    }

    // MARK: - Emoji row

    private var emojiRow: some View {
        HStack(spacing: V3Tokens.spacingSM) {
            ForEach(["🤍", "🌊", "✨", "🫶", "🔥"], id: \.self) { emoji in
                let moodColor = Color(hex: share?["moodColor"] as? String ?? "#888888")
                Button { sendEmoji(emoji) } label: {
                    Text(emoji).bodyLG()
                        .frame(width: 42, height: 42)
                        .background(
                            Circle().fill(sentEmoji == emoji ? moodColor.opacity(0.15) : V3Tokens.wash)
                                .overlay(Circle().stroke(sentEmoji == emoji ? moodColor.opacity(0.3) : Color.clear, lineWidth: 1))
                        )
                }
                .disabled(sentEmoji != nil && sentEmoji != emoji)
                .scaleEffect(sentEmoji == emoji ? 1.1 : 1.0)
                .animation(ONEAnimation.micro, value: sentEmoji)
            }
            Spacer()
            Text(NSLocalizedString("circle.heard", comment: ""))
                .monoSM(tracking: 1.4)
                .foregroundColor(V3Tokens.faintText)
        }
        .padding(.horizontal, 20).padding(.top, 20)
        .opacity(appeared ? 1 : 0)
        .animation(.easeOut(duration: ONEAnimation.durationMedium).delay(0.3), value: appeared)
    }

    // MARK: - Privacy placeholder

    private func privacyPlaceholder(label: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "lock")
                .font(.system(size: 14, weight: .light))
                .foregroundColor(V3Tokens.mutedText)
            Text(String(format: NSLocalizedString("privacy.hiddenField", comment: ""), label))
                .monoSM(tracking: 0.3)
                .foregroundColor(V3Tokens.mutedText)
                .lineLimit(2)
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 20)
    }

    // MARK: - Close button

    private var closeBtn: some View {
        Button { dismiss() } label: {
            HStack(spacing: 8) {
                Image(systemName: "chevron.down").font(.system(size: 10))
                Text(NSLocalizedString("general.close", comment: "")).monoSM(tracking: 1)
            }
            .foregroundColor(V3Tokens.mutedText)
            .padding(.horizontal, 20).padding(.vertical, V3Tokens.spacingMD)
            .background(Capsule().stroke(V3Tokens.faintText, lineWidth: 1.5))
        }
        .padding(.top, 24).padding(.bottom, 40)
        .opacity(appeared ? 1 : 0)
        .animation(.easeOut(duration: ONEAnimation.durationMedium).delay(0.4), value: appeared)
    }

    // MARK: - Live polling

    private func startPolling() {
        isPolling = true
        scheduleNextPoll()
    }

    private func scheduleNextPoll() {
        guard isPolling else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 15) { [self] in
            guard isPolling else { return }
            fetchLatestShare()
        }
    }

    private func fetchLatestShare() {
        let userID = friendData.user["userID"] as? String ?? ""
        guard !userID.isEmpty else { return }

        cloudKitManager.fetchDailyShare(for: userID, date: Date()) { result in
            DispatchQueue.main.async {
                if case .success(let record) = result {
                    let newSong = record["songName"] as? String ?? ""
                    if !newSong.isEmpty {
                        withAnimation(ONEAnimation.cardSpring) {
                            share = record
                        }
                        isPolling = false
                        markShareAsSeen()
                        onRefresh?()
                        // Yeni şarkı geldi — haptic
                        ONEHaptics.songSaved()
                    } else {
                        scheduleNextPoll()
                    }
                } else {
                    scheduleNextPoll()
                }
            }
        }
    }

    // MARK: - Emoji

    private func sendEmoji(_ emoji: String) {
        guard sentEmoji == nil, let s = share else { return }
        withAnimation(ONEAnimation.micro) { sentEmoji = emoji }
        let key = "emoji_\(s.recordID.recordName)_\(dateKey())"
        UserDefaults.standard.set(emoji, forKey: key)
        ONEHaptics.moodSelected()
        // CloudKit sync removed — legacy emoji path; comment system is the active path.
    }

    private func loadSentEmoji() {
        guard let s = share else { return }
        let key = "emoji_\(s.recordID.recordName)_\(dateKey())"
        if let local = UserDefaults.standard.string(forKey: key) { sentEmoji = local }
        // CloudKit fetch removed — legacy path only reads local cache.
    }

    private func dateKey() -> String {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; return f.string(from: Date())
    }

    // MARK: - Seen Tracking

    private func markShareAsSeen() {
        guard let uid = friendData.user["userID"] as? String,
              let s = share,
              !(s["songName"] as? String ?? "").isEmpty else { return }
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"
        let key = "seenShare_\(uid)_\(f.string(from: Date()))"
        guard !UserDefaults.standard.bool(forKey: key) else { return }
        UserDefaults.standard.set(true, forKey: key)
        NotificationCenter.default.post(name: .init("unseenSharesChanged"), object: nil)
    }

    // MARK: - Actions

    private func removeFriend() {
        let uid = friendData.user["userID"] as? String ?? ""
        guard !uid.isEmpty else { return }
        cloudKitManager.removeFriend(friendUserID: uid) { _ in
            onRefresh?()
            dismiss()
        }
    }

    private func blockUser() {
        let uid = friendData.user["userID"] as? String ?? ""
        guard !uid.isEmpty else { return }
        cloudKitManager.blockUser(userID: uid) { _ in
            onRefresh?()
            dismiss()
        }
    }
}
