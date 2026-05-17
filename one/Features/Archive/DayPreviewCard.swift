//
//  DayPreviewCard.swift
//  One - Günlük Mood
//

import SwiftUI
import MusicKit
import CloudKit

// MARK: - Full Screen Photo Viewer

struct FullScreenPhotoView: View {
    let url: URL
    @Binding var isPresented: Bool

    // Zoom state
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero

    // Swipe-to-dismiss — @GestureState for zero-overhead live tracking
    @GestureState private var dragY: CGFloat = 0
    @State private var isDismissing = false

    private let minScale: CGFloat = 1.0
    private let maxScale: CGFloat = 5.0
    private let dismissThreshold: CGFloat = 120

    private var dismissOffset: CGFloat { isDismissing ? UIScreen.main.bounds.height : dragY }
    private var backgroundOpacity: Double {
        isDismissing ? 0 : Double(max(0.3, 1.0 - dragY / 300))
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.black.opacity(backgroundOpacity).ignoresSafeArea()

            CachedAsyncImagePhase(url: url) { phase in
                switch phase {
                case .success(let img):
                    img
                        .resizable()
                        .scaledToFit()
                        .drawingGroup()
                        .scaleEffect(scale)
                        .offset(x: offset.width, y: offset.height + dismissOffset)
                        .animation(isDismissing ? .easeOut(duration: 0.22) : nil, value: dismissOffset)
                        .gesture(
                            SimultaneousGesture(
                                MagnificationGesture()
                                    .onChanged { val in
                                        let raw = lastScale * val
                                        scale = min(max(raw, minScale), maxScale)
                                    }
                                    .onEnded { _ in
                                        lastScale = scale
                                        if scale < minScale {
                                            withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                                                scale = minScale
                                                offset = .zero
                                            }
                                            lastScale = minScale
                                            lastOffset = .zero
                                        }
                                    },
                                DragGesture()
                                    .updating($dragY) { val, state, _ in
                                        guard scale <= 1.01 else { return }
                                        let dy = val.translation.height
                                        if dy > 0 { state = dy }
                                    }
                                    .onChanged { val in
                                        if scale > 1.01 {
                                            offset = CGSize(
                                                width:  lastOffset.width  + val.translation.width,
                                                height: lastOffset.height + val.translation.height
                                            )
                                        }
                                    }
                                    .onEnded { val in
                                        if scale > 1.01 {
                                            lastOffset = offset
                                        } else if val.translation.height > dismissThreshold {
                                            ONEHaptics.moodSelected()
                                            withAnimation(.easeOut(duration: 0.22)) {
                                                isDismissing = true
                                            }
                                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                                                isPresented = false
                                            }
                                        }
                                        // dragY sıfırlanır otomatik (@GestureState)
                                    }
                            )
                        )
                        .onTapGesture(count: 2) {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                                if scale > 1.01 {
                                    scale = minScale; lastScale = minScale
                                    offset = .zero; lastOffset = .zero
                                } else {
                                    scale = 2.5; lastScale = 2.5
                                }
                            }
                        }

                case .failure:
                    VStack(spacing: 12) {
                        Image(systemName: "photo")
                            .font(.system(size: 40))
                            .foregroundColor(.white.opacity(0.4))
                        Text(NSLocalizedString("archive.photoLoadFailed", comment: ""))
                            .monoBase()
                            .foregroundColor(.white.opacity(0.4))
                    }

                default:
                    ProgressView()
                        .tint(.white)
                }
            }
            .ignoresSafeArea()
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            // Kapat butonu — sağ üst, fotoğrafla birlikte kayar
            Button {
                withAnimation(.easeOut(duration: 0.22)) { isDismissing = true }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) { isPresented = false }
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 40, height: 40)
                    .liquidGlass(in: Circle())
            }
            .padding(.top, 56)
            .padding(.trailing, 20)
            .offset(y: dismissOffset)
        }
        .statusBarHidden(true)
    }
}

// MARK: - Day Preview Card (Wabi-Sabi Minimal)
struct DayPreviewCard: View {
    let entry: DailyEntry
    var onPhotoTap: ((URL) -> Void)? = nil

    @State private var showShareSheet = false
    @ObservedObject private var cloudKit = CloudKitManager.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            
            // ── Top: Mood çizgisi + tarih ──────────────────
            HStack(alignment: .center) {
                Rectangle()
                    .fill(Color(hex: entry.moodColorHex))
                    .frame(width: 32, height: 2.5)
                    .clipShape(Capsule())
                Spacer()
                Text(dayText)
                    .monoMicro(tracking: 0.8)
                    .foregroundColor(ONETokens.oneAsh)
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)

            // ── Fotoğraf veya Mood Pattern (Sabit Boyut) ──────────
            ZStack {
                if let url = entry.photoURL {
                    // Fotoğraf varsa - sabit boyutta, fill mode
                    CachedAsyncImagePhase(url: url) { phase in
                        switch phase {
                        case .success(let img):
                            img
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 300, height: 200)
                                .clipped()
                        default:
                            RoundedRectangle(cornerRadius: 14)
                                .fill(ONETokens.oneCreamMid)
                                .frame(width: 300, height: 200)
                        }
                    }
                    .id(url)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        ONEHaptics.moodSelected()
                        onPhotoTap?(url)
                    }
                } else {
                    // Fotoğraf yoksa mood pattern
                    MoodPatternPreview(moodColorHex: entry.moodColorHex)
                        .frame(width: 300, height: 200)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .frame(width: 300, height: 200)
            .frame(maxWidth: .infinity)
            .padding(.top, 16)

            // ── Şarkı Bilgileri (Temiz & Minimal) ──────────
            VStack(alignment: .leading, spacing: 6) {
                Text(entry.songName)
                    .displayXS()
                    .foregroundColor(ONETokens.oneInk)
                    .tracking(-0.3)
                    .lineLimit(2)
                
                Text(entry.artistName)
                    .monoBase(tracking: 0.3)
                    .foregroundColor(ONETokens.oneAsh)
                    .lineLimit(1)

                HStack(spacing: 8) {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(Color(hex: entry.moodColorHex))
                            .frame(width: 7, height: 7)
                        Text(entry.normalizedMoodLabel.uppercased())
                            .monoMicro(tracking: 0.8)
                            .foregroundColor(ONETokens.oneCharcoal)
                            .lineLimit(1)
                    }

                    if !entry.feelingLabel.isEmpty {
                        Text("·")
                            .monoMicro(tracking: 0.6)
                            .foregroundColor(ONETokens.oneStone)
                        Text(entry.feelingLabel.uppercased())
                            .monoMicro(tracking: 0.8)
                            .foregroundColor(ONETokens.oneAsh)
                    }
                }
                .padding(.top, 2)
                
                // Not (varsa)
                if let note = entry.note, !note.isEmpty {
                    Text(note)
                        .bodySM()
                        .foregroundColor(ONETokens.oneCharcoal.opacity(0.85))
                        .lineLimit(3)
                        .padding(.top, 8)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color(hex: entry.moodColorHex).opacity(0.08))
                        )
                }
            }
            .frame(minHeight: 90)
            .padding(.horizontal, 20)
            .padding(.top, 18)

            // ── Alt: Saat + Paylaşım (Daha Belirgin) ──────────────────────
            Divider()
                .background(ONETokens.oneCreamMid)
                .padding(.horizontal, 20)
                .padding(.top, 14)

            HStack(spacing: 8) {
                // Sol: Saat ve Aç butonu
                VStack(alignment: .leading, spacing: 6) {
                    Text(String(format: NSLocalizedString("archive.selectedAt", comment: ""), entry.time))
                        .monoLabel(tracking: 0.5)
                        .foregroundColor(ONETokens.oneAsh)
                    
                    Button(action: openSong) {
                        HStack(spacing: 4) {
                            Image(systemName: "play.circle.fill")
                                .font(.system(size: 10))
                            Text(NSLocalizedString("archive.openSong", comment: ""))
                                .monoLabel(tracking: 0.4)
                        }
                        .foregroundColor(ONETokens.oneCharcoal)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(ONETokens.oneCreamMid)
                        )
                    }
                }
                
                Spacer()

                // Sağ: Paylaşım butonu
                Button(action: {
                    ONEHaptics.moodSelected()
                    showShareSheet = true
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 12, weight: .semibold))
                        Text(NSLocalizedString("general.share", comment: ""))
                            .monoBase(tracking: 0.6)
                    }
                    .foregroundColor(ONETokens.oneCream)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 10)
                    .background(
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color(hex: entry.moodColorHex),
                                        Color(hex: entry.moodColorHex).opacity(0.85)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .shadow(color: Color(hex: entry.moodColorHex).opacity(0.3), radius: 8, x: 0, y: 4)
                    )
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)

            // Yorum butonu — kendi paylaşımlarındaki yorumlar
            if CommentsFeatureFlag.isEnabled,
               let myUserID = cloudKit.currentUser?["userID"] as? String {
                CommentEntryButton(
                    shareOwnerID: myUserID,
                    accentColorHex: entry.moodColorHex,
                    resolveShareRecordName: { completion in
                        CloudKitManager.shared.fetchOwnDailyShareRecordName(date: entry.date, completion: completion)
                    }
                )
                .padding(.horizontal, 20)
                .padding(.bottom, 16)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(ONETokens.onePaper)
                .shadow(color: Color.black.opacity(0.14), radius: 30, x: 0, y: 14)
        )
        .frame(width: UIScreen.main.bounds.width * 0.88)
        .fixedSize(horizontal: false, vertical: true)
        .sheet(isPresented: $showShareSheet) {
            ONEShareSheet(entry: entry)
        }
    }

    private var dayText: String {
        let f = DateFormatter()
        f.locale = LanguageManager.shared.currentLocale
        f.dateFormat = "d MMMM yyyy"
        return f.string(from: entry.date)
    }

    private func openSong() {
        if let url = entry.spotifyURL, UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
            return
        }

        let rawQuery = "\(entry.songName) \(entry.artistName)"
        let query = rawQuery.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""

        if SpotifyManager.shared.isAuthenticated {
            SpotifyManager.shared.search(query: rawQuery) { result in
                DispatchQueue.main.async {
                    switch result {
                    case .success(let tracks):
                        if let firstTrack = tracks.first {
                            if let customUrl = URL(string: "spotify:track:\(firstTrack.id):play"), UIApplication.shared.canOpenURL(customUrl) {
                                UIApplication.shared.open(customUrl)
                            } else if let trackUrl = URL(string: "https://open.spotify.com/track/\(firstTrack.id)?go=1") {
                                UIApplication.shared.open(trackUrl)
                            } else {
                                fallbackSpotifySearch(query: query)
                            }
                        } else {
                            fallbackSpotifySearch(query: query)
                        }
                    case .failure(_):
                        fallbackSpotifySearch(query: query)
                    }
                }
            }
        } else {
            Task {
                do {
                    var searchRequest = MusicCatalogSearchRequest(term: rawQuery, types: [MusicKit.Song.self])
                    searchRequest.limit = 1
                    let response = try await searchRequest.response()
                    await MainActor.run {
                        if let firstSong = response.songs.first {
                            if let url = URL(string: "music://music.apple.com/album/\(firstSong.albums?.first?.id.rawValue ?? "")?i=\(firstSong.id.rawValue)&play=1"), UIApplication.shared.canOpenURL(url) {
                                UIApplication.shared.open(url)
                            } else {
                                fallbackAppleMusicSearch(query: query)
                            }
                        } else {
                            fallbackAppleMusicSearch(query: query)
                        }
                    }
                } catch {
                    await MainActor.run { fallbackAppleMusicSearch(query: query) }
                }
            }
        }
    }

    private func fallbackSpotifySearch(query: String) {
        if let customUrl = URL(string: "spotify://search/\(query)"), UIApplication.shared.canOpenURL(customUrl) {
            UIApplication.shared.open(customUrl)
        } else if let webUrl = URL(string: "https://open.spotify.com/search/\(query)") {
            UIApplication.shared.open(webUrl)
        }
    }

    private func fallbackAppleMusicSearch(query: String) {
        if let customUrl = URL(string: "music://search?term=\(query)"), UIApplication.shared.canOpenURL(customUrl) {
            UIApplication.shared.open(customUrl)
        } else if let webUrl = URL(string: "https://music.apple.com/search?term=\(query)") {
            UIApplication.shared.open(webUrl)
        }
    }

}

// MARK: - Day Share Card (Story & Post Formats)
// Story: Rendered at 360x640 points with scale 3.0 -> 1080x1920 pixels (Instagram Story resolution)
// Post: Rendered at 600x337.5 points with scale 3.0 -> 1800x1012.5 pixels (Landscape/X resolution)
struct DayShareCard: View {
    let entry: DailyEntry
    let loadedPhoto: UIImage?
    var format: ShareFormat = .story

    var body: some View {
        ZStack {
            if format == .story {
                // Story Background (Full Fill)
                if let photo = loadedPhoto {
                    Image(uiImage: photo)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 360, height: 640)
                        .clipped()
                } else {
                    MoodPatternBackground(moodColorHex: entry.moodColorHex)
                        .frame(width: 360, height: 640)
                        .clipped()
                }
                storyLayout
            } else {
                // Post Background (Blurred if photo, or Mood Pattern)
                if let photo = loadedPhoto {
                    Image(uiImage: photo)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 600, height: 337.5)
                        .blur(radius: 40)
                        .overlay(Color.black.opacity(0.3)) // darken for legibility
                        .clipped()
                } else {
                    MoodPatternBackground(moodColorHex: entry.moodColorHex)
                        .frame(width: 600, height: 337.5)
                        .blur(radius: 30) // Blur the background to make the foreground card pop
                        .overlay(Color.black.opacity(0.25))
                        .clipped()
                }
                postLayout
            }
        }
        .frame(width: format == .story ? 360 : 600, height: format == .story ? 640 : 337.5)
    }

    private var storyLayout: some View {
        VStack {
            Spacer()
            ZStack(alignment: .bottom) {
                LinearGradient(
                    colors: [Color.black.opacity(0.85), Color.black.opacity(0.3), .clear],
                    startPoint: .bottom,
                    endPoint: .top
                )
                .frame(height: 200)

                VStack(alignment: .leading, spacing: 5) {
                    Rectangle()
                        .fill(Color(hex: entry.moodColorHex))
                        .frame(width: 40, height: 1.5)

                    Text(entry.songName)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                        .lineLimit(2)

                    Text(entry.artistName)
                        .font(ONETypography.monoSM)
                        .foregroundColor(.white.opacity(0.85))

                    Spacer().frame(height: 5)

                    Text(dayText)
                        .font(ONETypography.monoMicro)
                        .foregroundColor(.white.opacity(0.6))

                    Text(NSLocalizedString("share.brandWatermark", comment: ""))
                        .font(ONETypography.monoMicro)
                        .foregroundColor(.white.opacity(0.3))
                        .padding(.top, 1)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 80)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var postLayout: some View {
        HStack(spacing: 0) {
            // Left: 9:16 Card Thumbnail
            ZStack {
                if let photo = loadedPhoto {
                    Image(uiImage: photo)
                        .resizable()
                        .scaledToFill()
                } else {
                    MoodPatternBackground(moodColorHex: entry.moodColorHex)
                }
            }
            .frame(width: 155, height: 275) // strictly 9:16 aspect ratio roughly
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: Color.black.opacity(0.4), radius: 15, x: 0, y: 10)
            .padding(.leading, 40)
            
            Spacer()
            
            // Right: Info Display
            VStack(alignment: .leading, spacing: 8) {
                Spacer()
                
                Rectangle()
                    .fill(Color(hex: entry.moodColorHex))
                    .frame(width: 50, height: 2)
                    .padding(.bottom, 4)

                Text(entry.songName)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.white)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                Text(entry.artistName)
                    .font(ONETypography.bodyMD)
                    .foregroundColor(.white.opacity(0.9))
                
                Spacer()

                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(dayText.uppercased())
                            .font(ONETypography.monoLabel)
                            .tracking(1.0)
                            .foregroundColor(.white.opacity(0.8))

                        Text(NSLocalizedString("share.brandWatermarkUpper", comment: ""))
                            .font(ONETypography.monoMicro)
                            .tracking(1.5)
                            .foregroundColor(.white.opacity(0.6))
                    }
                }
                .padding(.bottom, 32)
            }
            .padding(.trailing, 40)
            .padding(.vertical, 32)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var dayText: String {
        let f = DateFormatter()
        f.locale = LanguageManager.shared.currentLocale
        f.dateFormat = "d MMMM yyyy"
        return f.string(from: entry.date)
    }
}

// MARK: - Mood Pattern Background
// Scaled for 360×640 point canvas (rendered at 3× for 1080×1920 pixel output)
struct MoodPatternBackground: View {
    let moodColorHex: String

    var body: some View {
        ZStack {
            // Base gradient
            LinearGradient(
                stops: [
                    .init(color: (ONEMood(hex: moodColorHex)?.pastelColor ?? Color(hex: moodColorHex)).opacity(0.18), location: 0.0),
                    .init(color: (ONEMood(hex: moodColorHex)?.pastelColor ?? Color(hex: moodColorHex)).opacity(0.08), location: 0.55),
                    .init(color: .clear, location: 1.0)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            // Organic shapes pattern
            GeometryReader { geometry in
                ZStack {
                    // Large background circles
                    Circle()
                        .fill(Color.white.opacity(0.08))
                        .frame(width: 200, height: 200)
                        .offset(x: geometry.size.width * 0.7, y: -33)
                        .blur(radius: 13)

                    Circle()
                        .fill(Color.white.opacity(0.06))
                        .frame(width: 150, height: 150)
                        .offset(x: -50, y: geometry.size.height * 0.3)
                        .blur(radius: 12)

                    Circle()
                        .fill(Color.black.opacity(0.04))
                        .frame(width: 117, height: 117)
                        .offset(x: geometry.size.width * 0.5, y: geometry.size.height * 0.6)
                        .blur(radius: 10)

                    // Medium accent circles
                    Circle()
                        .fill(Color.white.opacity(0.12))
                        .frame(width: 93, height: 93)
                        .offset(x: geometry.size.width * 0.2, y: geometry.size.height * 0.15)
                        .blur(radius: 8)

                    Circle()
                        .fill(Color.black.opacity(0.06))
                        .frame(width: 73, height: 73)
                        .offset(x: geometry.size.width * 0.8, y: geometry.size.height * 0.75)
                        .blur(radius: 7)

                    // Small detail circles
                    Circle()
                        .fill(Color.white.opacity(0.15))
                        .frame(width: 50, height: 50)
                        .offset(x: geometry.size.width * 0.15, y: geometry.size.height * 0.7)
                        .blur(radius: 5)

                    Circle()
                        .fill(Color.white.opacity(0.1))
                        .frame(width: 40, height: 40)
                        .offset(x: geometry.size.width * 0.65, y: geometry.size.height * 0.35)
                        .blur(radius: 4)
                }
            }

            // Subtle noise texture overlay
            Rectangle()
                .fill(Color.white.opacity(0.02))
        }
    }
}

// MARK: - Mood Pattern Preview (Archive Card Size)
struct MoodPatternPreview: View {
    let moodColorHex: String

    var body: some View {
        ZStack {
            // Base gradient
            LinearGradient(
                stops: [
                    .init(color: (ONEMood(hex: moodColorHex)?.pastelColor ?? Color(hex: moodColorHex)).opacity(0.18), location: 0.0),
                    .init(color: (ONEMood(hex: moodColorHex)?.pastelColor ?? Color(hex: moodColorHex)).opacity(0.08), location: 0.55),
                    .init(color: .clear, location: 1.0)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            // Organic shapes
            GeometryReader { geometry in
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.15))
                        .frame(width: 120, height: 120)
                        .offset(x: geometry.size.width * 0.7, y: -20)
                        .blur(radius: 15)
                    
                    Circle()
                        .fill(Color.white.opacity(0.1))
                        .frame(width: 90, height: 90)
                        .offset(x: -20, y: geometry.size.height * 0.6)
                        .blur(radius: 12)
                    
                    Circle()
                        .fill(Color.black.opacity(0.06))
                        .frame(width: 70, height: 70)
                        .offset(x: geometry.size.width * 0.5, y: geometry.size.height * 0.3)
                        .blur(radius: 10)
                }
            }
            
            // Subtle texture
            Rectangle()
                .fill(Color.white.opacity(0.03))
        }
    }
}
