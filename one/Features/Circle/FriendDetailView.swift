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
    @State private var appeared        = false
    @State private var sentEmoji: String? = nil
    @State private var showPhotoViewer = false
    @State private var showRemoveAlert = false
    @State private var showBlockAlert  = false
    @State private var showProfileZoom = false
    @State private var profilePhotoPressed = false

    private var displayName: String {
        friendData.user["displayName"] as? String ?? "Arkadaş"
    }
    private var initial: String { String(displayName.prefix(1)).uppercased() }
    private var avatarColorHex: String {
        share?["moodColor"] as? String
            ?? friendData.user["avatarColor"] as? String
            ?? "#888888"
    }

    /// Friend's profile photo loaded from their CKAsset, if available.
    private var friendProfileImage: UIImage? {
        guard let asset = friendData.user["profilePhoto"] as? CKAsset,
              let url = asset.fileURL,
              let data = try? Data(contentsOf: url) else { return nil }
        return UIImage(data: data)
    }
    private var hasSong: Bool {
        guard let s = share else { return false }
        return !((s["songName"] as? String) ?? "").isEmpty
    }

    var body: some View {
        ZStack {
            ONETokens.oneCream.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    headerSection
                    if hasSong {
                        songCard
                        emojiRow
                    } else {
                        waitingSection
                    }

                    closeBtn
                }
            }
        }
        .fullScreenCover(isPresented: $showPhotoViewer) {
            if let asset = share?["photoAsset"] as? CKAsset,
               let url   = asset.fileURL,
               let data  = try? Data(contentsOf: url),
               let img   = UIImage(data: data) {
                PhotoDataViewerSheet(image: img, isPresented: $showPhotoViewer)
            }
        }
        .overlay {
            if profilePhotoPressed, let img = friendProfileImage {
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
        .animation(.spring(response: 0.28, dampingFraction: 0.72), value: profilePhotoPressed)
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
        }
        .onDisappear { isPolling = false }
        // CircleView'den gelen canlı güncelleme sinyali
        .onReceive(NotificationCenter.default.publisher(for: .init("circleDataNeedsRefresh"))) { _ in
            fetchLatestShare()
        }
    }

    // MARK: - Header

    private var friendUsername: String? {
        friendData.user["username"] as? String
    }
    private var friendStreak: Int {
        friendData.share?["currentStreak"] as? Int ?? 0
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                // Avatar + isim
                HStack(spacing: 12) {
                    ZStack {
                        if let img = friendProfileImage {
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
                                        .font(.system(size: 18, weight: .regular, design: .serif))
                                        .italic()
                                        .foregroundColor(.white.opacity(0.9))
                                )
                        }
                    }
                    .onLongPressGesture(minimumDuration: 0.2, pressing: { isPressing in
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.72)) {
                            profilePhotoPressed = isPressing
                        }
                        if isPressing, friendProfileImage != nil { ONEHaptics.feelingSelected() }
                    }, perform: {})

                    Text(displayName.uppercased())
                        .monoSM(tracking: 1.6)
                        .foregroundColor(ONETokens.oneCharcoal)
                }

                Spacer()

                HStack(spacing: 10) {
                    // Streak rozeti
                    if friendStreak >= 2 {
                        HStack(spacing: 4) {
                            Text("🔥")
                                .font(.system(size: 11))
                            Text("\(friendStreak)")
                                .monoSM(tracking: 0.5)
                                .foregroundColor(Color(hex: avatarColorHex))
                        }
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .background(
                            Capsule()
                                .fill(Color(hex: avatarColorHex).opacity(0.1))
                                .overlay(Capsule().stroke(Color(hex: avatarColorHex).opacity(0.2), lineWidth: 1))
                        )
                    }

                    // Menü
                    Menu {
                        Button(role: .destructive) { showRemoveAlert = true } label: {
                            Label(NSLocalizedString("circle.removeAction", comment: ""), systemImage: "person.fill.xmark")
                        }
                        Button(role: .destructive) { showBlockAlert = true } label: {
                            Label(NSLocalizedString("circle.blockAction", comment: ""), systemImage: "nosign")
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(ONETokens.oneStone)
                            .frame(width: 32, height: 32)
                            .contentShape(Rectangle())
                    }
                }
            }

            Text(hasSong
                 ? NSLocalizedString("circle.todayFeeling", comment: "")
                 : NSLocalizedString("circle.notSelectedYet", comment: ""))
                .displayLG()
                .foregroundColor(ONETokens.oneInk)
                .lineSpacing(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, ONETokens.spacingXL2)
        .padding(.top, ONETokens.spacingXL4)
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
                        .font(.system(size: 26, weight: .regular, design: .serif))
                        .italic()
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
                        .foregroundColor(ONETokens.oneAsh)

                    Text(
                        (displayName.components(separatedBy: " ").first ?? displayName)
                        + " "
                        + NSLocalizedString("circle.willAppear", comment: "")
                    )
                    .monoSM(tracking: 0.3)
                    .foregroundColor(ONETokens.oneMist)
                }
                .multilineTextAlignment(.center)

                if isPolling {
                    HStack(spacing: 6) {
                        ProgressView().scaleEffect(0.65).tint(ONETokens.oneMist)
                        Text(NSLocalizedString("circle.updating", comment: ""))
                            .monoLabel(tracking: 0.3)
                            .foregroundColor(ONETokens.oneMist)
                    }
                }
            }
            .padding(.horizontal, 40)
            .padding(.vertical, 36)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.white.opacity(0.5))
                    .overlay(RoundedRectangle(cornerRadius: 20).stroke(ONETokens.oneCreamLow, lineWidth: 1))
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
                    .buttonStyle(.plain)
                } else {
                    LinearGradient(
                        stops: [.init(color: moodColor.opacity(0.65), location: 0),
                                .init(color: moodColor.opacity(0.15), location: 1)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )
                    .frame(height: 180)
                }
                timeBadge(s)
            }
            .frame(height: 180).frame(maxWidth: .infinity)

            // Info
            VStack(alignment: .leading, spacing: ONETokens.spacingLG) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(songName)
                            .displayMD()
                            .foregroundColor(ONETokens.oneInk).tracking(-0.8).lineLimit(2)
                        Text(artistName)
                            .monoSM(tracking: 0)
                            .foregroundColor(ONETokens.oneCharcoal)
                    }
                    Spacer()
                    // Platform rozeti
                    if !platform.isEmpty {
                        HStack(spacing: 4) {
                            Image(systemName: platform.lowercased().contains("spotify")
                                  ? "music.note" : "music.note.list")
                                .font(.system(size: 9, weight: .medium))
                            Text(platform.contains("Spotify") ? "Spotify" : "Apple")
                                .font(.system(size: 9, weight: .medium, design: .monospaced))
                                .tracking(0.3)
                        }
                        .foregroundColor(ONETokens.oneAsh)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(ONETokens.oneSilver.opacity(0.8))
                        )
                    }
                }
                if !genre.isEmpty {
                    Text(genre)
                        .monoLabel(tracking: 0.5)
                        .foregroundColor(ONETokens.oneMist)
                }

                Rectangle().fill(ONETokens.oneCreamLow).frame(height: 1).padding(.vertical, 4)

                if !moodWord.isEmpty {
                    HStack(spacing: 6) {
                        Circle().fill(moodColor).frame(width: 7, height: 7)
                        Text(moodWord.uppercased())
                            .monoLabel(tracking: 1.2)
                            .foregroundColor(ONETokens.oneCharcoal)
                    }
                    .padding(.horizontal, ONETokens.spacingMD).padding(.vertical, 6)
                    .background(Capsule().fill(moodColor.opacity(0.12)))
                }

                if !wDesc.isEmpty {
                    HStack(spacing: 5) {
                        Text(wIcon).font(.system(size: 11))
                        Text(wDesc).monoSM(tracking: 0).foregroundColor(ONETokens.oneCharcoal)
                    }
                }

                if let note = dailyNote {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(NSLocalizedString("circle.note", comment: "")).monoSM(tracking: 1.5).foregroundColor(ONETokens.oneAsh)
                        Text(note).bodySM().foregroundColor(ONETokens.oneInk).lineSpacing(2)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(ONETokens.spacingLG)
                    .background(RoundedRectangle(cornerRadius: 12).fill(moodColor.opacity(0.08)))
                    .padding(.top, ONETokens.spacingLG)
                }
            }
            .padding(20).frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(ONETokens.onePaper)
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
        HStack(spacing: ONETokens.spacingSM) {
            ForEach(["🤍", "🌊", "✨", "🫶", "🔥"], id: \.self) { emoji in
                let moodColor = Color(hex: share?["moodColor"] as? String ?? "#888888")
                Button { sendEmoji(emoji) } label: {
                    Text(emoji).font(.system(size: 16))
                        .frame(width: 42, height: 42)
                        .background(
                            Circle().fill(sentEmoji == emoji ? moodColor.opacity(0.15) : ONETokens.oneCreamLow)
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
                .foregroundColor(ONETokens.oneStone)
        }
        .padding(.horizontal, 20).padding(.top, 20)
        .opacity(appeared ? 1 : 0)
        .animation(.easeOut(duration: ONEAnimation.durationMedium).delay(0.3), value: appeared)
    }

    // MARK: - Close button

    private var closeBtn: some View {
        Button { dismiss() } label: {
            HStack(spacing: 8) {
                Image(systemName: "chevron.down").font(.system(size: 10))
                Text(NSLocalizedString("general.close", comment: "")).monoSM(tracking: 1)
            }
            .foregroundColor(ONETokens.oneCharcoal)
            .padding(.horizontal, 20).padding(.vertical, ONETokens.spacingMD)
            .background(Capsule().stroke(ONETokens.oneStone, lineWidth: 1.5))
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
                        UINotificationFeedbackGenerator().notificationOccurred(.success)
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
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        cloudKitManager.sendEmojiReaction(shareRecordName: s.recordID.recordName, emoji: emoji) { _ in }
    }

    private func loadSentEmoji() {
        guard let s = share else { return }
        let key = "emoji_\(s.recordID.recordName)_\(dateKey())"
        if let local = UserDefaults.standard.string(forKey: key) { sentEmoji = local; return }
        cloudKitManager.fetchEmojiReaction(shareRecordName: s.recordID.recordName) { e in
            guard let e else { return }
            sentEmoji = e
            UserDefaults.standard.set(e, forKey: key)
        }
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
