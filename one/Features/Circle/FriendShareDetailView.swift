//
//  FriendShareDetailView.swift
//  one
//
//  Detail view for a friend's daily music share in Circle
//  Matches TodayCompletedView card-based light design
//

import SwiftUI
import CloudKit

struct FriendShareDetailView: View {
    @Environment(\.dismiss) var dismiss
    let share: CKRecord
    @StateObject private var cloudKitManager = CloudKitManager.shared
    @State private var sentEmoji: String? = nil
    @State private var appeared = false
    @State private var showPhotoViewer = false
    @State private var showRemoveAlert = false
    @State private var showBlockAlert = false
    @State private var isLoading = false
    
    private var photoData: Data? {
        if let asset = share["photoAsset"] as? CKAsset,
           let fileURL = asset.fileURL {
            return try? Data(contentsOf: fileURL)
        }
        return share["photoData"] as? Data
    }
    
    private var moodColorHex: String {
        share["moodColor"] as? String ?? "#5B8DEF"
    }
    
    private var moodColor: Color {
        Color(hex: moodColorHex)
    }
    
    private var songName: String {
        share["songName"] as? String ?? ""
    }
    
    private var artistName: String {
        share["artistName"] as? String ?? ""
    }
    
    private var moodWord: String {
        share["moodWord"] as? String ?? ""
    }
    
    private var genre: String {
        share["genre"] as? String ?? ""
    }
    
    private var platform: String {
        share["platform"] as? String ?? "Spotify"
    }
    
    private var dailyNote: String? {
        let note = share["dailyNote"] as? String ?? ""
        return note.isEmpty ? nil : note
    }
    
    private var feeling: FeelingType {
        FeelingType(rawValue: share["feeling"] as? String ?? "calm") ?? .calm
    }
    
    private var feelingLabel: String {
        let label = share["feelingLabel"] as? String ?? ""
        return label.isEmpty ? FeelingOption.all.first { $0.type == feeling }?.label ?? "" : label
    }
    
    private var weatherIcon: String {
        let icon = share["weatherIcon"] as? String ?? ""
        return icon.isEmpty ? "☀️" : icon
    }
    
    private var weatherDesc: String {
        share["weatherDesc"] as? String ?? ""
    }
    
    var body: some View {
        ZStack {
            // Background
            ONETokens.oneCream.ignoresSafeArea()
            
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    // Header
                    headerSection
                    
                    // Main Card
                    mainCard
                    
                    // Emoji reaction row
                    emojiSection
                    
                    // Close button
                    closeButton
                }
            }
        }
        .fullScreenCover(isPresented: $showPhotoViewer) {
            if let data = photoData, let uiImage = UIImage(data: data) {
                PhotoDataViewerSheet(image: uiImage, isPresented: $showPhotoViewer)
            }
        }
        .alert("Arkadaşlıktan Çıkar", isPresented: $showRemoveAlert) {
            Button("Çıkar", role: .destructive) { removeFriend() }
            Button("Vazgeç", role: .cancel) { }
        } message: {
            Text("\(getUserDisplayName()) adlı kullanıcıyı çevrenden çıkarmak istediğine emin misin?")
        }
        .alert("Kullanıcıyı Engelle", isPresented: $showBlockAlert) {
            Button("Engelle", role: .destructive) { blockUser() }
            Button("Vazgeç", role: .cancel) { }
        } message: {
            Text("\(getUserDisplayName()) adlı kullanıcıyı engellemek istediğine emin misin? Bu işlemi geri alamazsın.")
        }
        .overlay(
            Group {
                if isLoading {
                    Color.black.opacity(0.3).ignoresSafeArea()
                    ProgressView()
                        .padding()
                        .background(Color.white)
                        .cornerRadius(10)
                }
            }
        )
        .onAppear {
            loadSentEmoji()
            withAnimation(ONEAnimation.screenTransition) { appeared = true }
        }
    }
    
    // MARK: - Header
    
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                // Friend info
                HStack(spacing: 10) {
                    Circle()
                        .fill(moodColor)
                        .frame(width: 28, height: 28)
                        .overlay(
                            Text(getInitial())
                                .monoSM(tracking: 0)
                                .foregroundColor(.white.opacity(0.9))
                        )
                    
                    Text(getUserDisplayName().uppercased())
                        .monoSM(tracking: 1.6)
                        .foregroundColor(ONETokens.oneAsh)
                }
                
                Spacer()
                
                // Relative time & Menu
                HStack(spacing: 12) {
                    Text(getRelativeTime())
                        .monoLabel(tracking: 0.6)
                        .foregroundColor(ONETokens.oneStone)
                    
                    Menu {
                        Button(role: .destructive, action: { showRemoveAlert = true }) {
                            Label("Çıkar", systemImage: "person.fill.xmark")
                        }
                        Button(role: .destructive, action: { showBlockAlert = true }) {
                            Label("Engelle", systemImage: "nosign")
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
            
            Text("Bugün ne\nhissediyor?")
                .displayLG()
                .foregroundColor(ONETokens.oneInk)
                .lineSpacing(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, ONETokens.spacingXL2)
        .padding(.top, ONETokens.spacingXL4)
        .padding(.bottom, 24)
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : -10)
        .animation(ONEAnimation.screenTransition.delay(0.1), value: appeared)
    }
    
    // MARK: - Main Card
    
    private var mainCard: some View {
        VStack(spacing: 0) {
            // Photo or Mood gradient header
            ZStack(alignment: .bottomLeading) {
                if let photoData = photoData, !photoData.isEmpty,
                   let uiImage = UIImage(data: photoData) {
                    // Photo background — tappable
                    Button(action: {
                        withAnimation(ONEAnimation.panelSpring) {
                            showPhotoViewer = true
                        }
                    }) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(height: 180)
                            .clipped()
                            .overlay(
                                ZStack {
                                    Color.black.opacity(0.02)
                                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(.white.opacity(0.6))
                                }
                            )
                    }
                    .buttonStyle(PlainButtonStyle())
                } else {
                    // Gradient background with wabi-sabi design
                    ZStack {
                        // Base gradient
                        LinearGradient(
                            stops: [
                                .init(color: moodColor.opacity(0.65), location: 0.0),
                                .init(color: moodColor.opacity(0.35), location: 0.5),
                                .init(color: moodColor.opacity(0.15), location: 1.0)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        
                        // Abstract circles
                        GeometryReader { geo in
                            ZStack {
                                Circle()
                                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
                                    .background(Circle().fill(Color.white.opacity(0.04)))
                                    .frame(width: 120, height: 120)
                                    .offset(x: geo.size.width * 0.7, y: -20)
                                
                                Circle()
                                    .stroke(Color.white.opacity(0.06), lineWidth: 1)
                                    .background(Circle().fill(Color.white.opacity(0.03)))
                                    .frame(width: 80, height: 80)
                                    .offset(x: geo.size.width * 0.2, y: geo.size.height * 0.3)
                                
                                Circle()
                                    .stroke(Color.white.opacity(0.05), lineWidth: 1)
                                    .background(Circle().fill(Color.white.opacity(0.02)))
                                    .frame(width: 60, height: 60)
                                    .offset(x: geo.size.width * 0.85, y: geo.size.height * 0.7)
                            }
                        }
                        
                        // Diagonal lines
                        Canvas { ctx, size in
                            ctx.opacity = 0.04
                            for i in -2..<6 {
                                var path = Path()
                                let startX = size.width * (Double(i) * 0.2 - 0.1)
                                path.move(to: CGPoint(x: startX, y: size.height))
                                path.addLine(to: CGPoint(x: startX + size.width * 0.5, y: 0))
                                ctx.stroke(path, with: .color(.white), lineWidth: 0.8)
                            }
                        }
                        
                        // Radial glow
                        RadialGradient(
                            colors: [moodColor.opacity(0.15), .clear],
                            center: UnitPoint(x: 0.7, y: 0.2),
                            startRadius: 0,
                            endRadius: 120
                        )
                        
                        // Grain texture overlay
                        Rectangle()
                            .fill(
                                LinearGradient(
                                    gradient: Gradient(colors: [
                                        Color.white.opacity(0.02),
                                        Color.clear,
                                        Color.white.opacity(0.02)
                                    ]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .blendMode(.overlay)
                    }
                    .drawingGroup()
                }
                
                // Time badge
                if let createdAt = share["createdAt"] as? Date {
                    let timeString = formatTime(createdAt)
                    HStack(spacing: 6) {
                        Circle()
                            .fill(Color.white.opacity(0.9))
                            .frame(width: 6, height: 6)
                        Text("\(timeString)'te")
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
            }
            .frame(height: 180)
            .frame(maxWidth: .infinity)
            
            // Song info section
            VStack(alignment: .leading, spacing: ONETokens.spacingLG) {
                // Song name
                Text(songName)
                    .displayMD()
                    .foregroundColor(ONETokens.oneInk)
                    .tracking(-0.8)
                    .lineLimit(2)
                
                // Artist & platform
                Text("\(artistName) · \(genre.isEmpty ? platform : genre)")
                    .monoBase(tracking: 0.5)
                    .foregroundColor(ONETokens.oneCharcoal)
                
                // Divider
                Rectangle()
                    .fill(ONETokens.oneCreamLow)
                    .frame(height: 1)
                    .padding(.vertical, 4)
                
                // Mood & Feeling tags (matching TodayCompletedView)
                HStack(spacing: ONETokens.spacingMD) {
                    // Mood
                    if !moodWord.isEmpty {
                        HStack(spacing: 6) {
                            Circle()
                                .fill(moodColor)
                                .frame(width: 7, height: 7)
                            Text(moodWord.uppercased())
                                .monoLabel(tracking: 1.2)
                                .foregroundColor(ONETokens.oneCharcoal)
                        }
                        .padding(.horizontal, ONETokens.spacingMD)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(moodColor.opacity(0.12))
                        )
                    }
                    
                    // Feeling
                    if !feelingLabel.isEmpty {
                        HStack(spacing: 6) {
                            FeelingIconView(type: feeling)
                                .frame(width: 20, height: 16)
                            Text(feelingLabel.uppercased())
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
                }
                
                // Weather & Platform info (matching TodayCompletedView)
                HStack(spacing: ONETokens.spacingMD) {
                    if !weatherDesc.isEmpty {
                        HStack(spacing: 5) {
                            Text(weatherIcon)
                                .font(.system(size: 11))
                            Text(weatherDesc)
                                .monoLabel()
                                .foregroundColor(ONETokens.oneCharcoal)
                        }
                    }
                    
                    HStack(spacing: 5) {
                        Text("🎵")
                            .font(.system(size: 11))
                        Text(platform)
                            .monoLabel()
                            .foregroundColor(ONETokens.oneCharcoal)
                    }
                }
                .padding(.top, 4)
                
                // Note section (if exists)
                if let note = dailyNote {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("NOT")
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
                            .fill(moodColor.opacity(0.08))
                    )
                    .padding(.top, ONETokens.spacingLG)
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: Color.black.opacity(0.06), radius: 20, x: 0, y: 8)
        .padding(.horizontal, 20)
        .scaleEffect(appeared ? 1 : 0.94)
        .opacity(appeared ? 1 : 0)
        .animation(ONEAnimation.panelSpring.delay(0.2), value: appeared)
    }
    
    // MARK: - Emoji Section
    
    private let emojis = ["🤍", "🌊", "✨", "🫶", "🔥"]
    
    private var emojiSection: some View {
        HStack(spacing: ONETokens.spacingSM) {
            ForEach(emojis, id: \.self) { emoji in
                Button(action: { sendEmoji(emoji) }) {
                    Text(emoji)
                        .font(.system(size: 16))
                        .frame(width: 42, height: 42)
                        .background(
                            Circle()
                                .fill(sentEmoji == emoji ? moodColor.opacity(0.15) : ONETokens.oneCreamLow)
                                .overlay(
                                    Circle()
                                        .stroke(sentEmoji == emoji ? moodColor.opacity(0.3) : Color.clear, lineWidth: 1)
                                )
                        )
                }
                .disabled(sentEmoji != nil && sentEmoji != emoji)
                .scaleEffect(sentEmoji == emoji ? 1.1 : 1.0)
                .animation(ONEAnimation.micro, value: sentEmoji)
            }
            
            Spacer()
            
            Text("duydum")
                .monoMicro(tracking: 1.4)
                .foregroundColor(ONETokens.oneStone)
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
        .opacity(appeared ? 1 : 0)
        .animation(.easeOut(duration: ONEAnimation.durationLong).delay(0.35), value: appeared)
    }
    
    // MARK: - Close Button
    
    private var closeButton: some View {
        Button(action: { dismiss() }) {
            HStack(spacing: 8) {
                Image(systemName: "chevron.down")
                    .font(.system(size: 10))
                Text("Kapat")
                    .monoBase(tracking: 1.0)
            }
            .foregroundColor(ONETokens.oneCharcoal)
            .padding(.horizontal, 20)
            .padding(.vertical, ONETokens.spacingMD)
            .background(
                Capsule()
                    .stroke(ONETokens.oneStone, lineWidth: 1.5)
            )
        }
        .padding(.top, 24)
        .padding(.bottom, 40)
        .opacity(appeared ? 1 : 0)
        .animation(.easeOut(duration: ONEAnimation.durationLong).delay(0.4), value: appeared)
    }
    
    // MARK: - Helper Functions
    
    private func getInitial() -> String {
        let name = getUserDisplayName()
        return String(name.prefix(1)).uppercased()
    }
    
    private func getUserDisplayName() -> String {
        // Try displayName field first, fall back to userID
        if let displayName = share["displayName"] as? String, !displayName.isEmpty {
            return displayName
        }
        return share["userID"] as? String ?? "Friend"
    }
    
    private func getRelativeTime() -> String {
        guard let createdAt = share["createdAt"] as? Date else { return "" }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        formatter.locale = Locale(identifier: "tr_TR")
        return formatter.localizedString(for: createdAt, relativeTo: Date())
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
    
    private func sendEmoji(_ emoji: String) {
        guard sentEmoji == nil else { return }

        withAnimation(ONEAnimation.micro) {
            sentEmoji = emoji
        }

        // Anında yerel kayıt — hızlı feedback için
        let key = "emoji_sent_\(share.recordID.recordName)_\(dateKey())"
        UserDefaults.standard.set(emoji, forKey: key)

        UIImpactFeedbackGenerator(style: .light).impactOccurred()

        // CloudKit'e kalıcı olarak kaydet
        cloudKitManager.sendEmojiReaction(shareRecordName: share.recordID.recordName, emoji: emoji) { result in
            if case .failure(let error) = result {
                ONELogger.error("Emoji CloudKit'e kaydedilemedi: \(error)", category: .circle)
            }
        }
    }

    private func loadSentEmoji() {
        // Önce yerel cache'e bak (anlık yükleme)
        let key = "emoji_sent_\(share.recordID.recordName)_\(dateKey())"
        if let local = UserDefaults.standard.string(forKey: key) {
            sentEmoji = local
            return
        }

        // Yerel cache yoksa CloudKit'ten yükle
        cloudKitManager.fetchEmojiReaction(shareRecordName: share.recordID.recordName) { emoji in
            guard let emoji else { return }
            sentEmoji = emoji
            UserDefaults.standard.set(emoji, forKey: key)
        }
    }
    
    private func dateKey() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }
    
    // MARK: - Connections Management
    
    private func targetUserID() -> String {
        return share["userID"] as? String ?? ""
    }
    
    private func removeFriend() {
        let userID = targetUserID()
        guard !userID.isEmpty else { return }
        isLoading = true
        cloudKitManager.removeFriend(friendUserID: userID) { _ in
            isLoading = false
            dismiss()
        }
    }
    
    private func blockUser() {
        let userID = targetUserID()
        guard !userID.isEmpty else { return }
        isLoading = true
        cloudKitManager.blockUser(userID: userID) { _ in
            isLoading = false
            dismiss()
        }
    }
}

// MARK: - Photo Data Viewer (for Data-based images)

struct PhotoDataViewerSheet: View {
    let image: UIImage
    @Binding var isPresented: Bool

    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var dismissOffset: CGFloat = 0
    @State private var backgroundOpacity: Double = 1.0

    private let dismissThreshold: CGFloat = 120

    var body: some View {
        ZStack {
            // Arka plan — sadece opacity ile solar, offset almaz
            Color.black.opacity(backgroundOpacity).ignoresSafeArea()

            // Fotoğraf + buton aynı anda kayar
            ZStack {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .scaleEffect(scale)
                    .gesture(
                        SimultaneousGesture(
                            MagnificationGesture()
                                .onChanged { value in
                                    scale = max(1.0, lastScale * value)
                                }
                                .onEnded { _ in
                                    lastScale = scale
                                    if scale < 1.0 {
                                        withAnimation(ONEAnimation.micro) {
                                            scale = 1.0
                                            lastScale = 1.0
                                        }
                                    }
                                },
                            DragGesture()
                                .onChanged { val in
                                    guard scale <= 1.01 else { return }
                                    let dy = val.translation.height
                                    if dy > 0 {
                                        dismissOffset = dy
                                        backgroundOpacity = Double(max(0.3, 1.0 - dy / 300))
                                    }
                                }
                                .onEnded { val in
                                    guard scale <= 1.01 else { return }
                                    if val.translation.height > dismissThreshold {
                                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                        withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                                            dismissOffset = 800
                                            backgroundOpacity = 0
                                        }
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                                            var t = Transaction()
                                            t.disablesAnimations = true
                                            withTransaction(t) { isPresented = false }
                                        }
                                    } else {
                                        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                                            dismissOffset = 0
                                            backgroundOpacity = 1.0
                                        }
                                    }
                                }
                        )
                    )

                // Kapat butonu — fotoğrafla aynı container'da, birlikte kayar
                VStack {
                    HStack {
                        Spacer()
                        Button(action: { isPresented = false }) {
                            Image(systemName: "xmark")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(width: 44, height: 44)
                                .background(
                                    Circle()
                                        .fill(Color.black.opacity(0.5))
                                        .overlay(Circle().stroke(Color.white.opacity(0.2), lineWidth: 1))
                                )
                        }
                        .padding(20)
                    }
                    Spacer()
                }

                // Aşağı kaydır ipucu
                VStack {
                    Spacer()
                    Image(systemName: "chevron.compact.down")
                        .font(.system(size: 24, weight: .light))
                        .foregroundColor(.white.opacity(0.3))
                        .padding(.bottom, 24)
                        .opacity(dismissOffset == 0 ? 1 : 0)
                }
            }
            .offset(y: dismissOffset)
        }
        .statusBar(hidden: true)
    }
}
