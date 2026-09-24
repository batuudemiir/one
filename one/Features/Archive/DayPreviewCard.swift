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

    /// DayPreviewCard'daki thumb ile morph için ortak namespace.
    @Environment(\.archivePhotoNamespace) private var envPhotoNS
    @Namespace private var localPhotoNS
    private var photoNS: Namespace.ID { envPhotoNS ?? localPhotoNS }

    // Zoom state
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero

    // Sürükleyerek kapatma.
    //
    // `@GestureState` değil `@State`: `@GestureState` parmak kalkınca değerini
    // *anında* sıfırlıyor. Eşiği aşmayan bir sürüklemede fotoğraf yerine
    // yaylanarak değil, tek karede zıplayarak dönüyordu — jestle animasyon
    // arasındaki dikişin en görünür hali. `@State` ile dönüş
    // `dragSnapBack`'e devredilebiliyor ve yoldayken tekrar yakalanabiliyor.
    @State private var dragY: CGFloat = 0
    @State private var appeared = false

    private let minScale: CGFloat = 1.0
    private let maxScale: CGFloat = 5.0
    private let dismissThreshold: CGFloat = 120

    /// Yukarı çekişte `dragY` artık negatif olabiliyor (rubberband). Her iki
    /// hesap da `max(0, ·)` ile taban alıyor: aksi halde yukarı direnç,
    /// perdeyi 1.0'ın üstüne iterek "kararma" gibi ters bir sinyal veriyordu.
    private var backgroundOpacity: Double {
        Double(max(0.15, 1.0 - max(0, dragY) / 320))
    }

    private var chromeOpacity: Double {
        let fade = 1.0 - min(1.0, max(0, dragY) / 80)
        return appeared ? fade : 0
    }

    private var isZoomed: Bool { scale > 1.01 }

    private func dismiss() {
        ONEHaptics.moodSelected()
        withAnimation(ONEAnimation.screenTransition) {
            isPresented = false
        }
        // `dragY` artık `@State`; kapanışta elle sıfırlanmazsa görüntüleyici
        // bir sonraki açılışta kaydırılmış halde beliriyor.
        dragY = 0
    }

    var body: some View {
        ZStack {
            Color.black.opacity(backgroundOpacity)
                .ignoresSafeArea()
                .onTapGesture { if !isZoomed { dismiss() } }

            CachedAsyncImagePhase(url: url) { phase in
                switch phase {
                case .success(let img):
                    img
                        .resizable()
                        .scaledToFit()
                        .drawingGroup()
                        .matchedGeometryEffect(id: "archivePhoto", in: photoNS, isSource: true)
                        .scaleEffect(scale)
                        .offset(x: offset.width, y: offset.height + dragY)
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
                                            withAnimation(ONEAnimation.dragSnapBack) {
                                                scale = minScale
                                                offset = .zero
                                            }
                                            lastScale = minScale
                                            lastOffset = .zero
                                        }
                                    },
                                DragGesture(minimumDistance: 5)
                                    .onChanged { val in
                                        if scale > 1.01 {
                                            offset = CGSize(
                                                width:  lastOffset.width  + val.translation.width,
                                                height: lastOffset.height + val.translation.height
                                            )
                                            // Kapatma sürüklemesi başladıktan *sonra*
                                            // aynı jest içinde yakınlaştırılırsa, bu dal
                                            // devralıyor ve `dragY` asla sıfırlanmıyordu:
                                            // fotoğraf kalıcı olarak kaymış kalıyordu.
                                            if dragY != 0 {
                                                withAnimation(ONEAnimation.dragSnapBack) { dragY = 0 }
                                            }
                                            return
                                        }
                                        let dy = val.translation.height
                                        // Aşağı: 1:1 takip. Yukarı: `if dy > 0`'ın
                                        // sert duvarı yerine ilerledikçe artan direnç —
                                        // "hâlâ canlı, ama bu yönde gidecek yer yok".
                                        dragY = dy > 0
                                            ? dy
                                            : dy.rubberbanded(over: UIScreen.main.bounds.height)
                                    }
                                    .onEnded { val in
                                        if scale > 1.01 {
                                            lastOffset = offset
                                            return
                                        }
                                        // Karar bırakma noktasına değil jestin
                                        // *gittiği* yere veriliyor. Tek başına
                                        // `translation > 120` kısa ama sert bir
                                        // fiskeyi yutuyordu: parmak hızla iniyor,
                                        // 80pt'de kalkıyor, fotoğraf hiçbir şey
                                        // olmamış gibi geri dönüyordu.
                                        let dy = val.translation.height
                                        let projected = val.predictedEndTranslation.height
                                        if dy > dismissThreshold || projected > 260 {
                                            dismiss()
                                        } else {
                                            // interactiveSpring + blendDuration:
                                            // geri dönerken tekrar yakalanırsa
                                            // hareket kesilmeden devralınıyor.
                                            withAnimation(ONEAnimation.dragSnapBack) {
                                                dragY = 0
                                            }
                                        }
                                    }
                            )
                        )
                        .onTapGesture(count: 2) {
                            ONEHaptics.nudge()
                            withAnimation(ONEAnimation.screenTransition) {
                                if scale > 1.01 {
                                    scale = minScale; lastScale = minScale
                                    offset = .zero; lastOffset = .zero
                                } else {
                                    scale = 2.5; lastScale = 2.5
                                }
                            }
                        }

                case .failure:
                    VStack(spacing: V3Tokens.spacingMD) {
                        Image(systemName: "photo")
                            .font(.system(size: 40))
                            .foregroundColor(.white.opacity(0.4))
                        Text(NSLocalizedString("archive.photoLoadFailed", comment: ""))
                            .monoBase()
                            .foregroundColor(.white.opacity(0.4))
                    }

                default:
                    V3Loading(.media)
                }
            }
            .padding(.vertical, V3Tokens.spacingMD)
        }
        .overlay(alignment: .top) {
            HStack {
                Spacer()
                Button(action: dismiss) {
                    Image(systemName: "xmark")
                        .iconMD(weight: .semibold)
                        .foregroundColor(.white)
                        .frame(width: 36, height: 36)
                        .background(
                            Circle()
                                .glassFill(opaque: Color(red: 0.047, green: 0.047, blue: 0.063))
                                .environment(\.colorScheme, .dark)
                        )
                        .overlay(
                            Circle().stroke(Color.white.opacity(0.18), lineWidth: 1)
                        )
                        // Görünen daire 36pt kalıyor; dokunma hedefi HIG'in
                        // 44pt asgarisine genişliyor. Fotoğraf görüntüleyicide
                        // düğme tek çıkış yolu — 36pt'de ıskalanıyordu.
                        .frame(width: V3Tokens.minTouchTarget,
                               height: V3Tokens.minTouchTarget)
                        .contentShape(Circle())
                }
            }
            .padding(.horizontal, V3Tokens.spacingLG)
            .padding(.top, V3Tokens.spacingSM)
            .opacity(chromeOpacity)
        }
        .overlay(alignment: .bottom) {
            Image(systemName: "chevron.compact.down")
                .font(.system(size: 34, weight: .light))
                .foregroundColor(.white.opacity(isZoomed ? 0 : 0.32))
                .padding(.bottom, V3Tokens.spacingSM)
                .opacity(chromeOpacity)
                .accessibilityHidden(true)
        }
        .statusBarHidden(true)
        .task {
            withAnimation(.easeOut(duration: 0.25)) { appeared = true }
        }
    }
}

// MARK: - Day Preview Card (Wabi-Sabi Minimal)
struct DayPreviewCard: View {
    let entry: DailyEntry
    var onPhotoTap: ((URL) -> Void)? = nil

    @State private var showShareSheet = false
    @ObservedObject private var cloudKit = CloudKitManager.shared

    /// Fotoğrafın FullScreenPhotoView'e morph'u için ortak namespace.
    @Environment(\.archivePhotoNamespace) private var envPhotoNS
    @Namespace private var localPhotoNS
    private var photoNS: Namespace.ID { envPhotoNS ?? localPhotoNS }
    /// FullScreenPhotoView açıksa thumb'ı gizle (fantom önlemek için).
    @StateObject private var globalUI = GlobalUIState.shared
    private var isViewerActive: Bool { globalUI.archivePhotoURL == entry.photoURL }
    
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
                    .foregroundColor(V3Tokens.mutedText)
            }
            .padding(.horizontal, V3Tokens.spacingXL)
            .padding(.top, V3Tokens.spacingXL)

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
                            RoundedRectangle(cornerRadius: V3Tokens.radiusCard)
                                .fill(V3Tokens.surface)
                                .frame(width: 300, height: 200)
                        }
                    }
                    .id(url)
                    .matchedGeometryEffect(id: "archivePhoto", in: photoNS, isSource: !isViewerActive)
                    .opacity(isViewerActive ? 0 : 1)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        ONEHaptics.moodSelected()
                        withAnimation(ONEAnimation.screenTransition) {
                            onPhotoTap?(url)
                        }
                    }
                } else {
                    // Fotoğraf yoksa mood pattern
                    MoodPatternPreview(moodColorHex: entry.moodColorHex)
                        .frame(width: 300, height: 200)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: V3Tokens.radiusCard))
            .frame(width: 300, height: 200)
            .frame(maxWidth: .infinity)
            .padding(.top, V3Tokens.spacingLG)

            // ── Şarkı Bilgileri (Temiz & Minimal) ──────────
            VStack(alignment: .leading, spacing: 6) {
                Text(entry.songName)
                    .displayXS()
                    .foregroundColor(V3Tokens.ink)
                    .tracking(-0.3)
                    .lineLimit(2)
                
                Text(entry.artistName)
                    .monoBase(tracking: 0.3)
                    .foregroundColor(V3Tokens.mutedText)
                    .lineLimit(1)

                HStack(spacing: V3Tokens.spacingSM) {
                    HStack(spacing: V3Tokens.spacingXS) {
                        Circle()
                            .fill(Color(hex: entry.moodColorHex))
                            .frame(width: 7, height: 7)
                        Text(entry.normalizedMoodLabel.uppercased())
                            .monoMicro(tracking: 0.8)
                            .foregroundColor(V3Tokens.mutedText)
                            .lineLimit(1)
                    }

                }
                .padding(.top, 2)
                
                // Not (varsa)
                if let note = entry.note, !note.isEmpty {
                    Text(note)
                        .bodySM()
                        .foregroundColor(V3Tokens.mutedText.opacity(0.85))
                        .lineLimit(3)
                        .padding(.top, V3Tokens.spacingSM)
                        .padding(.horizontal, V3Tokens.spacingMD)
                        .padding(.vertical, 10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: V3Tokens.radiusInner)
                                .fill(Color(hex: entry.moodColorHex).opacity(0.08))
                        )
                }
            }
            .frame(minHeight: 90)
            .padding(.horizontal, V3Tokens.spacingXL)
            .padding(.top, 18)

            // ── Alt: Saat + Paylaşım (Daha Belirgin) ──────────────────────
            Divider()
                .background(V3Tokens.surface)
                .padding(.horizontal, V3Tokens.spacingXL)
                .padding(.top, 14)

            HStack(spacing: V3Tokens.spacingSM) {
                // Sol: Saat ve Aç butonu
                VStack(alignment: .leading, spacing: 6) {
                    Text(String(format: NSLocalizedString("archive.selectedAt", comment: ""), entry.time))
                        .monoLabel(tracking: 0.5)
                        .foregroundColor(V3Tokens.mutedText)
                    
                    Button(action: openSong) {
                        HStack(spacing: V3Tokens.spacingXS) {
                            Image(systemName: "play.circle.fill")
                                .iconXS()
                            Text(NSLocalizedString("archive.openSong", comment: ""))
                                .monoLabel(tracking: 0.4)
                        }
                        .foregroundColor(V3Tokens.mutedText)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(V3Tokens.surface)
                        )
                    }
                    .buttonStyle(.onePressable)
                }
                
                Spacer()

                // Sağ: Paylaşım butonu
                Button(action: {
                    ONEHaptics.moodSelected()
                    showShareSheet = true
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "square.and.arrow.up")
                            .iconSM(weight: .semibold)
                        Text(NSLocalizedString("general.share", comment: ""))
                            .monoBase(tracking: 0.6)
                    }
                    .foregroundColor(ONEBrand.bone)
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
                .buttonStyle(.onePressable)
            }
            .padding(.horizontal, V3Tokens.spacingXL)
            .padding(.vertical, 14)

            // Efemer karşılıklar yalnız bugüne ait; arşivde (geçmiş) yok.
            // Prototip: geçmiş herkesin kendinde kalır.
        }
        .background(
            RoundedRectangle(cornerRadius: V3Tokens.radiusPanel)
                .fill(V3Tokens.surface)
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
                        .bodyMDSemibold()
                        .foregroundColor(.white)
                        .lineLimit(2)

                    Text(entry.artistName)
                        .monoSM(tracking: 0)
                        .foregroundColor(.white.opacity(0.85))

                    Spacer().frame(height: 5)

                    Text(dayText)
                        .monoMicro(tracking: 0)
                        .foregroundColor(.white.opacity(0.6))

                    Text(NSLocalizedString("share.brandWatermark", comment: ""))
                        .monoMicro(tracking: 0)
                        .foregroundColor(.white.opacity(0.3))
                        .padding(.top, 1)
                }
                .padding(.horizontal, V3Tokens.spacingXL)
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
            .clipShape(RoundedRectangle(cornerRadius: V3Tokens.radiusCard))
            .shadow(color: Color.black.opacity(0.4), radius: 15, x: 0, y: 10)
            .padding(.leading, V3Tokens.spacingXL4)
            
            Spacer()
            
            // Right: Info Display
            VStack(alignment: .leading, spacing: V3Tokens.spacingSM) {
                Spacer()
                
                Rectangle()
                    .fill(Color(hex: entry.moodColorHex))
                    .frame(width: 50, height: 2)
                    .padding(.bottom, V3Tokens.spacingXS)

                Text(entry.songName)
                    .font(V3Typography.sans(24, weight: .bold))
                    .foregroundColor(.white)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                Text(entry.artistName)
                    .font(V3Typography.sans(15, relativeTo: .callout))
                    .foregroundColor(.white.opacity(0.9))
                
                Spacer()

                HStack {
                    VStack(alignment: .leading, spacing: V3Tokens.spacingXS) {
                        Text(dayText.uppercased())
                            .monoLabel()
                            .tracking(1.0)
                            .foregroundColor(.white.opacity(0.8))

                        Text(NSLocalizedString("share.brandWatermarkUpper", comment: ""))
                            .monoMicro()
                            .tracking(1.5)
                            .foregroundColor(.white.opacity(0.6))
                    }
                }
                .padding(.bottom, V3Tokens.spacingXL3)
            }
            .padding(.trailing, V3Tokens.spacingXL4)
            .padding(.vertical, V3Tokens.spacingXL3)
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
                    .init(color: (V3Mood.closest(toHex: moodColorHex)?.pastelColor ?? Color(hex: moodColorHex)).opacity(0.18), location: 0.0),
                    .init(color: (V3Mood.closest(toHex: moodColorHex)?.pastelColor ?? Color(hex: moodColorHex)).opacity(0.08), location: 0.55),
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
                    .init(color: (V3Mood.closest(toHex: moodColorHex)?.pastelColor ?? Color(hex: moodColorHex)).opacity(0.18), location: 0.0),
                    .init(color: (V3Mood.closest(toHex: moodColorHex)?.pastelColor ?? Color(hex: moodColorHex)).opacity(0.08), location: 0.55),
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
