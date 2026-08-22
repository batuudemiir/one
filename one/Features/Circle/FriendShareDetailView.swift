//
//  FriendShareDetailView.swift
//  one
//
//  Detail view for a friend's daily music share in Circle
//  Matches TodayCompletedView card-based light design
//

import SwiftUI
import CloudKit

// MARK: - IdentifiableImage

struct IdentifiableImage: Identifiable {
    let id = UUID()
    let image: UIImage
}

struct FriendShareDetailView: View {
    @Environment(\.dismiss) var dismiss
    let share: CKRecord
    var friendDisplayName: String = ""
    var friendProfilePhoto: UIImage? = nil
    @StateObject private var cloudKitManager = CloudKitManager.shared
    @State private var appeared = false
    @State private var showPhotoViewer = false
    @State private var showRemoveAlert = false
    @State private var showBlockAlert = false
    @State private var isLoading = false
    @State private var loadedPhotoData: Data? = nil
    @State private var loadedPhotoImage: UIImage? = nil  // pre-decoded image — dismiss anında ana thread sync I/O olmasın
    @State private var showFriendProfile = false  // v2.6 — public profile sheet
    @ObservedObject private var previewer = SongPreviewPlayer.shared
    @State private var stableSong: SongResult? = nil

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
            V3Tokens.paper.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    // Header
                    headerSection

                    // Main Card
                    mainCard

                    reactionSection

                    // Close button
                    closeButton
                }
            }
            .scrollDismissesKeyboard(.interactively)

            if showPhotoViewer, let img = loadedPhotoImage {
                PhotoDataViewerSheet(image: img, isPresented: $showPhotoViewer)
                    .transition(.opacity)
                    .zIndex(999)
            }
        }
        .liquidGlassSheetBackground()
        .sheet(isPresented: $showFriendProfile) {
            // v2.6 — Arkadaşın aggregate profili
            PublicProfileView(userID: targetUserID())
        }
        .v3Sheet()
        .alert(NSLocalizedString("circle.removeFriend", comment: ""), isPresented: $showRemoveAlert) {
            Button(NSLocalizedString("circle.removeAction", comment: ""), role: .destructive) { removeFriend() }
            Button(NSLocalizedString("general.cancel", comment: ""), role: .cancel) { }
        } message: {
            Text(String(format: NSLocalizedString("circle.removeConfirmMessage", comment: ""), getUserDisplayName()))
        }
        .alert(NSLocalizedString("circle.blockUser", comment: ""), isPresented: $showBlockAlert) {
            Button(NSLocalizedString("circle.blockAction", comment: ""), role: .destructive) { blockUser() }
            Button(NSLocalizedString("general.cancel", comment: ""), role: .cancel) { }
        } message: {
            Text(String(format: NSLocalizedString("circle.blockConfirmMessage", comment: ""), getUserDisplayName()))
        }
        .overlay {
            if isLoading {
                ZStack {
                    V3Tokens.paper.opacity(0.7).ignoresSafeArea()
                    V3Loading(.inline)
                        .padding(V3Tokens.spacingLG)
                        .background(
                            RoundedRectangle(cornerRadius: V3Tokens.radiusCard, style: .continuous)
                                .fill(V3Tokens.surface)
                                .shadow(color: .black.opacity(0.06), radius: 12, y: 4)
                        )
                }
                .transition(.opacity)
            }
        }
        .onAppear {
            withAnimation(ONEAnimation.screenTransition) { appeared = true }
            if stableSong == nil, !songName.isEmpty {
                stableSong = SongResult(
                    id: UUID(),
                    name: songName,
                    artist: artistName,
                    genre: genre,
                    coverURL: nil,
                    spotifyURL: nil,
                    artworkURLString: share["albumArtURL"] as? String
                )
            }
            if let song = stableSong { previewer.toggle(song) }
        }
        .onDisappear { previewer.stop() }
        .task {
            guard loadedPhotoData == nil else { return }
            await Task.detached(priority: .userInitiated) {
                if let asset = share["photoAsset"] as? CKAsset,
                   let url = asset.fileURL,
                   let data = try? Data(contentsOf: url) {
                    let decoded = UIImage(data: data)
                    await MainActor.run {
                        loadedPhotoData = data
                        loadedPhotoImage = decoded
                    }
                } else if let data = share["photoData"] as? Data {
                    let decoded = UIImage(data: data)
                    await MainActor.run {
                        loadedPhotoData = data
                        loadedPhotoImage = decoded
                    }
                }
            }.value
        }
    }
    
    // MARK: - Header
    
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: V3Tokens.spacingSM) {
            HStack {
                // Friend info — v2.6: tap → public profile
                Button {
                    if !targetUserID().isEmpty { showFriendProfile = true }
                } label: {
                    HStack(spacing: 10) {
                        ZStack {
                            if let img = friendProfilePhoto {
                                Image(uiImage: img)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 32, height: 32)
                                    .clipShape(Circle())
                                    .overlay(
                                        Circle()
                                            .stroke(moodColor.opacity(0.35), lineWidth: 1.5)
                                    )
                            } else {
                                Circle()
                                    .fill(moodColor)
                                    .frame(width: 32, height: 32)
                                    .overlay(
                                        Text(getInitial())
                                            .monoSM(tracking: 0)
                                            .foregroundColor(.white.opacity(0.9))
                                    )
                            }
                        }

                        Text(getUserDisplayName().uppercased())
                            .monoSM(tracking: 1.6)
                            .foregroundColor(V3Tokens.mutedText)
                    }
                }
                .buttonStyle(.onePressable)
                
                Spacer()
                
                // Relative time & Menu
                HStack(spacing: V3Tokens.spacingMD) {
                    Text(getRelativeTime())
                        .monoLabel(tracking: 0.6)
                        .foregroundColor(V3Tokens.faintText)
                    
                    Menu {
                        Button(role: .destructive, action: { showRemoveAlert = true }) {
                            Label(NSLocalizedString("circle.removeAction", comment: ""), systemImage: "person.fill.xmark")
                        }
                        Button(role: .destructive, action: { showBlockAlert = true }) {
                            Label(NSLocalizedString("circle.blockAction", comment: ""), systemImage: "nosign")
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .bodySM()
                            .fontWeight(.semibold)
                            .foregroundColor(V3Tokens.faintText)
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                }
            }
            
            Text(NSLocalizedString("circle.todayFeeling", comment: ""))
                .displayLG()
                .foregroundColor(V3Tokens.ink)
                .lineSpacing(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, V3Tokens.channel)
        .padding(.top, V3Tokens.spacingXL5)
        .padding(.bottom, V3Tokens.spacingXL2)
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : -10)
        .animation(ONEAnimation.screenTransition.delay(0.1), value: appeared)
    }
    
    // MARK: - Main Card
    
    private var mainCard: some View {
        VStack(spacing: 0) {
            // Photo or Mood gradient header
            ZStack(alignment: .bottomLeading) {
                if let uiImage = loadedPhotoImage {
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
                                        .bodySM()
                                        .fontWeight(.medium)
                                        .foregroundColor(.white.opacity(0.6))
                                }
                            )
                    }
                    .contentShape(Rectangle())
                    .buttonStyle(.onePressable)
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
                        Text(String(format: NSLocalizedString("today.timeSelected", comment: ""), timeString))
                            .monoLabel(tracking: 1.0)
                            .foregroundColor(.white.opacity(0.85))
                    }
                    .padding(.horizontal, V3Tokens.spacingMD)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(Color.white.opacity(0.15))
                            .overlay(
                                Capsule()
                                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
                            )
                    )
                    .padding(V3Tokens.spacingXL)
                }

                // Play / pause button — top trailing
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
                                    V3Loading(.media)
                                        .frame(width: 36, height: 36)
                                        .background(Circle().fill(Color.black.opacity(0.35)))
                                } else {
                                    Image(systemName: "play.fill")
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundStyle(V3Tokens.darkText)
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
            .frame(height: 180)
            .frame(maxWidth: .infinity)
            
            // Song info section
            VStack(alignment: .leading, spacing: V3Tokens.spacingLG) {
                // Song name
                Text(songName)
                    .displayMD()
                    .foregroundColor(V3Tokens.ink)
                    .tracking(-0.8)
                    .lineLimit(2)
                
                // Artist & platform
                Text("\(artistName) · \(genre.isEmpty ? platform : genre)")
                    .monoBase(tracking: 0.5)
                    .foregroundColor(V3Tokens.mutedText)
                
                // Divider
                Rectangle()
                    .fill(V3Tokens.wash)
                    .frame(height: 1)
                    .padding(.vertical, V3Tokens.spacingXS)
                
                // Mood & Feeling tags (matching TodayCompletedView)
                HStack(spacing: V3Tokens.spacingMD) {
                    // Mood
                    if !moodWord.isEmpty {
                        HStack(spacing: 6) {
                            Circle()
                                .fill(moodColor)
                                .frame(width: 7, height: 7)
                            Text(moodWord.uppercased())
                                .monoLabel(tracking: 1.2)
                                .foregroundColor(V3Tokens.mutedText)
                        }
                        .padding(.horizontal, V3Tokens.spacingMD)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(moodColor.opacity(0.12))
                        )
                    }
                    
                }
                
                // Weather & Platform info (matching TodayCompletedView)
                HStack(spacing: V3Tokens.spacingMD) {
                    if !weatherDesc.isEmpty {
                        HStack(spacing: 5) {
                            Text(weatherIcon)
                                .bodyMicro()
                            Text(weatherDesc)
                                .monoLabel()
                                .foregroundColor(V3Tokens.mutedText)
                        }
                    }
                    
                    HStack(spacing: 5) {
                        Image(systemName: "music.note")
                            .font(.system(size: 10))
                            .foregroundColor(V3Tokens.mutedText)
                        Text(platform)
                            .monoLabel()
                            .foregroundColor(V3Tokens.mutedText)
                    }
                }
                .padding(.top, V3Tokens.spacingXS)
                
                // Note section (if exists)
                if let note = dailyNote {
                    VStack(alignment: .leading, spacing: V3Tokens.spacingSM) {
                        Text(NSLocalizedString("circle.note", comment: ""))
                            .monoLabel(tracking: 1.5)
                            .foregroundColor(V3Tokens.mutedText)
                        
                        Text(note)
                            .bodySM()
                            .foregroundColor(V3Tokens.ink)
                            .lineSpacing(2)
                            .tracking(-0.2)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(V3Tokens.spacingLG)
                    .background(
                        RoundedRectangle(cornerRadius: V3Tokens.radiusInner)
                            .fill(moodColor.opacity(0.08))
                    )
                    .padding(.top, V3Tokens.spacingLG)
                }
            }
            .padding(V3Tokens.spacingXL)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(V3Tokens.surface)
        .clipShape(RoundedRectangle(cornerRadius: V3Tokens.radiusPanel))
        .shadow(color: Color.black.opacity(0.06), radius: 20, x: 0, y: 8)
        .padding(.horizontal, V3Tokens.spacingXL)
        .scaleEffect(appeared ? 1 : 0.94)
        .opacity(appeared ? 1 : 0)
        .animation(ONEAnimation.panelSpring.delay(0.2), value: appeared)
    }
    
    // MARK: - Karşılık ver (prototip: sessiz cevaplaşma)

    private var reactionSection: some View {
        ReactionComposer(
            shareRecordName: share.recordID.recordName,
            shareOwnerID: targetUserID(),
            friendDisplayName: getUserDisplayName()
        )
        .padding(.horizontal, V3Tokens.spacingXL)
        .padding(.top, V3Tokens.spacingXL)
        .padding(.bottom, V3Tokens.spacingSM)
        .opacity(appeared ? 1 : 0)
        .animation(.easeOut(duration: 0.3).delay(0.3), value: appeared)
    }

    // MARK: - Close Button
    
    private var closeButton: some View {
        Button(action: { dismiss() }) {
            HStack(spacing: V3Tokens.spacingSM) {
                Image(systemName: "chevron.down")
                    .monoMicro()
                Text(NSLocalizedString("general.close", comment: ""))
                    .monoBase(tracking: 1.0)
            }
            .foregroundColor(V3Tokens.mutedText)
            .padding(.horizontal, V3Tokens.spacingXL)
            .padding(.vertical, V3Tokens.spacingMD)
            .background(
                Capsule()
                    .stroke(V3Tokens.faintText, lineWidth: 1.5)
            )
        }
        .padding(.top, V3Tokens.spacingXL2)
        .padding(.bottom, V3Tokens.spacingXL4)
        .opacity(appeared ? 1 : 0)
        .animation(.easeOut(duration: ONEAnimation.durationLong).delay(0.4), value: appeared)
    }
    
    // MARK: - Helper Functions
    
    private func getInitial() -> String {
        let name = getUserDisplayName()
        return String(name.prefix(1)).uppercased()
    }
    
    private func getUserDisplayName() -> String {
        if !friendDisplayName.isEmpty { return friendDisplayName }
        if let displayName = share["displayName"] as? String, !displayName.isEmpty { return displayName }
        return "Arkadaş"
    }
    
    private func getRelativeTime() -> String {
        guard let createdAt = share["createdAt"] as? Date else { return "" }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        formatter.locale = LanguageManager.shared.currentLocale
        return formatter.localizedString(for: createdAt, relativeTo: Date())
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
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
    @State private var dragOffset: CGFloat = 0          // @State → spring-back çalışır
    @State private var isDismissing = false

    private var backgroundOpacity: Double {
        isDismissing ? 0 : Double(max(0.15, 1.0 - dragOffset / 280))
    }

    var body: some View {
        ZStack {
            Color.black.opacity(backgroundOpacity).ignoresSafeArea()
                .animation(.linear(duration: 0.01), value: dragOffset)

            ZStack {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .drawingGroup()
                    .scaleEffect(scale)
                    .offset(y: dragOffset)
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
                            DragGesture(minimumDistance: 5)
                                .onChanged { value in
                                    guard scale <= 1.01 else { return }
                                    let dy = value.translation.height
                                    // Aşağı: 1:1 takip. Yukarı: sert duvar yerine
                                    // ilerledikçe artan direnç.
                                    dragOffset = dy > 0
                                        ? dy
                                        : dy.rubberbanded(over: UIScreen.main.bounds.height)
                                }
                                .onEnded { value in
                                    guard scale <= 1.01 else { return }
                                    // Bırakma noktasına değil, jestin gittiği yere bak.
                                    let dy = value.translation.height
                                    let projected = value.predictedEndTranslation.height
                                    if dy > 90 || projected > 220 {
                                        ONEHaptics.nudge()
                                        // Sabit süreli animasyon + zamanlayıcı yerine
                                        // kesintiye uğratılabilir spring; kapanış
                                        // animasyonun gerçek bitişine bağlı.
                                        withAnimation(ONEAnimation.dragDismiss) {
                                            dragOffset = UIScreen.main.bounds.height
                                            isDismissing = true
                                        } completion: {
                                            isPresented = false
                                        }
                                    } else {
                                        withAnimation(ONEAnimation.dragSnapBack) {
                                            dragOffset = 0
                                        }
                                    }
                                }
                        )
                    )

                VStack {
                    HStack {
                        Spacer()
                        Button(action: {
                            ONEHaptics.nudge()
                            withAnimation(.easeOut(duration: 0.22)) {
                                dragOffset = UIScreen.main.bounds.height
                                isDismissing = true
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) { isPresented = false }
                        }) {
                            Image(systemName: "xmark")
                                .bodyLG()
                                .fontWeight(.semibold)
                                .foregroundColor(V3Tokens.darkText)
                                .frame(width: 44, height: 44)
                                .background(
                                    Circle()
                                        .fill(Color.black.opacity(0.5))
                                        .overlay(Circle().stroke(Color.white.opacity(0.2), lineWidth: 1))
                                )
                        }
                        .padding(V3Tokens.spacingXL)
                    }
                    Spacer()
                    Image(systemName: "chevron.compact.down")
                        .displayMD()
                        .fontWeight(.light)
                        .foregroundColor(.white.opacity(0.3))
                        .padding(.bottom, V3Tokens.spacingXL2)
                        .opacity(dragOffset < 5 ? 1 : 0)
                }
            }
        }
        .ignoresSafeArea()
        .statusBarHidden(true)
    }
}
