//
//  ONEShareSheet.swift
//  one
//
//  Unified share bottom sheet for Today and Archive.
//  Uses the existing InstagramStoryShareCard template (defined in DayPreviewCard.swift).
//  - Instagram Story  → instagram-stories:// URL scheme (direct to Stories)
//  - Diğer Uygulamalar → UIActivityViewController with image + platform link
//  - Fotoğraflara Kaydet → PHPhotoLibrary
//

import SwiftUI
import UIKit

struct ONEShareSheet: View {
    let entry: DailyEntry

    @Environment(\.dismiss) private var dismiss

    @State private var storyImage: UIImage?
    @State private var xImage: UIImage?
    @State private var isGenerating = true
    @State private var errorMessage: String?
    @State private var showError = false
    @State private var isSaved = false
    @State private var isRawPhotoSaved = false
    @State private var breathe = false

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            dragHandle

            titleRow

            // Card preview or loading indicator
            Group {
                if isGenerating {
                    loadingView
                } else if let image = storyImage {
                    cardPreview(image)
                }
            }
            .frame(height: 280)
            
            Spacer(minLength: 24)

            actionButtons
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
        }
        .background(ONETokens.oneCream.ignoresSafeArea())
        .presentationDetents([.height(640), .large])
        .presentationDragIndicator(.hidden)
        .task { await generateCard() }
        .alert(NSLocalizedString("general.error", comment: ""), isPresented: $showError) {
            Button(NSLocalizedString("general.ok", comment: ""), role: .cancel) {}
            Button(NSLocalizedString("general.retry", comment: "")) { Task { await generateCard() } }
        } message: {
            Text(errorMessage ?? NSLocalizedString("general.error", comment: ""))
        }
    }

    // MARK: - Subviews

    private var dragHandle: some View {
        RoundedRectangle(cornerRadius: 3)
            .fill(ONETokens.oneStone)
            .frame(width: 36, height: 4)
            .padding(.top, 12)
            .padding(.bottom, 14)
    }

    private var titleRow: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(NSLocalizedString("share.title", comment: ""))
                    .monoLabel(tracking: 2.0)
                    .foregroundColor(ONETokens.oneAsh)
                Text(entry.songName)
                    .displaySM()
                    .foregroundColor(ONETokens.oneInk)
                    .lineLimit(1)
            }
            Spacer()
            Button(action: { dismiss() }) {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(ONETokens.oneAsh)
                    .frame(width: 32, height: 32)
                    .background(Circle().fill(ONETokens.oneSilver))
            }
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 16)
    }

    private var loadingView: some View {
        VStack(spacing: 12) {
            Circle()
                .fill(ONETokens.oneInk)
                .frame(width: 8, height: 8)
                .scaleEffect(breathe ? 1.4 : 0.8)
                .opacity(breathe ? 1.0 : 0.4)
                .onAppear {
                    withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
                        breathe = true
                    }
                }
            Text(NSLocalizedString("share.preparing", comment: ""))
                .monoSM(tracking: 0.5)
                .foregroundColor(ONETokens.oneAsh)
        }
        .frame(maxWidth: .infinity)
    }

    private func cardPreview(_ image: UIImage) -> some View {
        Image(uiImage: image)
            .resizable()
            .aspectRatio(9 / 16, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(color: Color.black.opacity(0.14), radius: 14, x: 0, y: 6)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 80)
            .transition(.opacity.combined(with: .scale(scale: 0.96)))
    }

    private var actionButtons: some View {
        VStack(spacing: 24) {
            // Social Sharing Grid
            HStack(spacing: 16) {
                let instaInstalled = ShareManager.shared.isInstagramInstalled()
                
                ShareAppButton(
                    title: "Instagram",
                    icon: "camera.viewfinder",
                    gradient: [Color(hex: "#F58529"), Color(hex: "#DD2A7B"), Color(hex: "#8134AF")],
                    isEnabled: storyImage != nil && instaInstalled,
                    action: shareToInstagramStory
                )
                
                ShareAppButton(
                    title: "TikTok",
                    icon: "music.note",
                    gradient: [Color.black, Color(white: 0.15)],
                    isEnabled: storyImage != nil,
                    action: shareToTikTok
                )
                
                ShareAppButton(
                    title: NSLocalizedString("share.otherApps", comment: ""),
                    icon: "ellipsis",
                    gradient: [ONETokens.oneAsh, ONETokens.oneStone],
                    isEnabled: storyImage != nil && xImage != nil,
                    action: shareViaSystem
                )
            }
            .padding(.top, 8)
            
            // Other Actions
            VStack(spacing: 10) {
                if isSaved {
                    ActionRow(
                        icon: "checkmark.circle.fill",
                        label: NSLocalizedString("share.cardSaved", comment: ""),
                        sublabel: "",
                        style: .ghost,
                        isEnabled: false,
                        iconColorOverride: ONETokens.oneGreen,
                        action: {}
                    )
                } else {
                    ActionRow(
                        icon: "square.and.arrow.down",
                        label: NSLocalizedString("share.saveCard", comment: ""),
                        sublabel: NSLocalizedString("share.saveCardHint", comment: ""),
                        style: .ghost,
                        isEnabled: storyImage != nil,
                        iconColorOverride: nil,
                        action: saveToPhotos
                    )
                }

                if entry.photoURL != nil {
                    if isRawPhotoSaved {
                        ActionRow(
                            icon: "checkmark.circle.fill",
                            label: NSLocalizedString("share.photoSaved", comment: ""),
                            sublabel: "",
                            style: .ghost,
                            isEnabled: false,
                            iconColorOverride: ONETokens.oneGreen,
                            action: {}
                        )
                    } else {
                        ActionRow(
                            icon: "photo.on.rectangle",
                            label: NSLocalizedString("share.savePhoto", comment: ""),
                            sublabel: NSLocalizedString("share.savePhotoHint", comment: ""),
                            style: .ghost,
                            isEnabled: true,
                            iconColorOverride: nil,
                            action: saveRawPhotoToGallery
                        )
                    }
                }
            }
        }
        .animation(.easeInOut(duration: 0.2), value: isSaved)
        .animation(.easeInOut(duration: 0.2), value: isRawPhotoSaved)
    }

    // MARK: - Helpers


    private var platformURL: URL? {
        if let url = entry.spotifyURL { return url }
        let query = "\(entry.songName) \(entry.artistName)"
            .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        if entry.platform.lowercased().contains("spotify") {
            return URL(string: "https://open.spotify.com/search/\(query)")
        } else {
            return URL(string: "https://music.apple.com/search?term=\(query)")
        }
    }

    // MARK: - Actions

    /// Renders the DayShareCards into UIImages.
    @MainActor
    private func generateCard() async {
        isGenerating = true
        errorMessage = nil

        // Load photo data from disk (local file URL) if available
        var photoImage: UIImage? = nil
        if let url = entry.photoURL,
           let data = try? Data(contentsOf: url),
           let img = UIImage(data: data) {
            photoImage = img
        }

        // Story format
        let storyCard = DayShareCard(entry: entry, loadedPhoto: photoImage, format: .story)
        let storyRenderer = ImageRenderer(content: storyCard)
        storyRenderer.scale = 3.0
        let sImage = storyRenderer.uiImage

        // Post (X) format
        let xCard = DayShareCard(entry: entry, loadedPhoto: photoImage, format: .post)
        let xRenderer = ImageRenderer(content: xCard)
        xRenderer.scale = 3.0
        let pImage = xRenderer.uiImage

        if let s = sImage, let x = pImage {
            ONELogger.success("Share cards generated", category: .general)
            withAnimation {
                storyImage = s
                xImage = x
            }
        } else {
            ONELogger.error("ImageRenderer returned nil — share card generation failed", category: .general)
            errorMessage = NSLocalizedString("share.cardFailed", comment: "")
            showError = true
        }
        isGenerating = false
    }

    private func shareToInstagramStory() {
        guard let image = storyImage else { return }
        ONEHaptics.feelingSelected()

        // 1. Dismiss the sheet FIRST so there is no SwiftUI presentation layering
        //    when Instagram becomes the active app.
        dismiss()

        // 2. Write pasteboard + open Instagram after a single runloop tick —
        //    enough time for the sheet dismissal animation to begin,
        //    but the pasteboard data is written before Instagram reads it.
        DispatchQueue.main.async {
            // v2.6 — Attribution sticker: Story'nin üstünde "Uygulamada aç" linki çıkar.
            // Ana sayfa URL'i; uygulama yüklüyse Universal Link akışına düşer.
            let attributionURL = URL(string: "https://one.forvibe.app")
            ShareManager.shared.shareToInstagramStories(image: image, contentURL: attributionURL) { result in
                if case .failure(let err) = result {
                    ONELogger.error("Instagram story share failed: \(err.localizedDescription)", category: .share)
                }
            }
        }
    }

    private func shareToTikTok() {
        guard let story = storyImage else { return }
        ONEHaptics.moodSelected()
        
        ShareManager.shared.shareToTikTok(image: story) { result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    // TikTok açıldı
                    break
                case .failure:
                    // Eğer TikTok açılamazsa fallback olarak standart iOS Share Sheet göster
                    ShareManager.shared.shareViaActivityController(items: [story])
                }
            }
        }
    }

    private func shareViaSystem() {
        guard let story = storyImage, let xPost = xImage else { return }
        ONEHaptics.moodSelected()
        
        let mood = entry.normalizedMoodLabel.uppercased()
        let template = NSLocalizedString("share.xTemplate", comment: "ONE uygulamasından günün ruh hali: %@\\n\\n#OneApp")
        let xText = String(format: template, mood)
        
        ShareManager.shared.shareViaActivityControllerAdaptive(
            storyImage: story,
            xPostImage: xPost,
            xText: xText,
            platformURL: platformURL
        )
    }

    private func saveToPhotos() {
        guard let image = storyImage else { return }
        ONEHaptics.moodSelected()
        ShareManager.shared.saveToPhotoLibrary(image: image) { result in
            switch result {
            case .success:
                ONEHaptics.songSaved()
                withAnimation { isSaved = true }
            case .failure(let err):
                errorMessage = err.localizedDescription
                showError = true
            }
        }
    }

    private func saveRawPhotoToGallery() {
        guard let photoURL = entry.photoURL,
              let data = try? Data(contentsOf: photoURL),
              let image = UIImage(data: data) else {
            errorMessage = "Fotoğraf yüklenemedi"
            showError = true
            return
        }
        ONEHaptics.moodSelected()
        ShareManager.shared.saveToPhotoLibrary(image: image) { result in
            switch result {
            case .success:
                ONEHaptics.songSaved()
                withAnimation { isRawPhotoSaved = true }
            case .failure(let err):
                errorMessage = err.localizedDescription
                showError = true
            }
        }
    }
}

// MARK: - ActionRow

private enum ActionRowStyle {
    case filled(Color)
    case bordered
    case ghost
}

private struct ActionRow: View {
    let icon: String
    let label: String
    let sublabel: String
    let style: ActionRowStyle
    let isEnabled: Bool
    var iconColorOverride: Color? = nil
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(iconColor)
                    .frame(width: 22)

                VStack(alignment: .leading, spacing: 2) {
                    Text(label)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(labelColor)
                    Text(sublabel)
                        .monoSM(tracking: 0.3)
                        .foregroundColor(labelColor.opacity(0.55))
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(labelColor.opacity(0.35))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 13)
            .background(background)
        }
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1.0 : 0.38)
    }

    // MARK: Style helpers

    private var labelColor: Color {
        switch style {
        case .filled: return .white
        case .bordered, .ghost: return ONETokens.oneInk
        }
    }

    private var iconColor: Color { iconColorOverride ?? labelColor }

    @ViewBuilder
    private var background: some View {
        switch style {
        case .filled(let color):
            RoundedRectangle(cornerRadius: 14).fill(color)
        case .bordered:
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.white)
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(ONETokens.oneStone, lineWidth: 1))
        case .ghost:
            RoundedRectangle(cornerRadius: 14)
                .fill(ONETokens.oneSilver.opacity(0.6))
        }
    }
}

// MARK: - ShareAppButton

private struct ShareAppButton: View {
    let title: String
    let icon: String
    let gradient: [Color]
    let isEnabled: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 10) {
                ZStack {
                    LinearGradient(
                        colors: gradient,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .frame(width: 62, height: 62)
                    .clipShape(Circle())
                    .shadow(color: gradient.first?.opacity(0.3) ?? .clear, radius: 8, x: 0, y: 4)
                    
                    Image(systemName: icon)
                        .font(.system(size: 26, weight: .medium))
                        .foregroundColor(.white)
                }
                
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(ONETokens.oneInk)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
        }
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1.0 : 0.4)
    }
}
