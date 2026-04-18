//
//  TodayCompletedView.swift
//  One - Günlük Mood
//

import SwiftUI

struct TodayCompletedView: View {
    let entry: DailyEntry
    let onEdit: () -> Void

    @State private var appeared = false
    @State private var showPhotoViewer = false
    @State private var showShareOptions = false
    @State private var showChangeConfirm = false
    @State private var photoSaved = false

    private var displayedEntry: DailyEntry { entry }

    // MARK: - Dynamic sizing helpers

    /// Photo height: ~23 % of available height, hard-capped at 175 pt.
    private func photoHeight(available: CGFloat) -> CGFloat {
        max(90, min(175, available * 0.23))
    }

    /// Header top padding: scales 10–32 pt.
    private func headerTopPad(available: CGFloat) -> CGFloat {
        max(10, min(32, available * 0.038))
    }

    /// Header bottom padding: scales 8–16 pt.
    private func headerBottomPad(available: CGFloat) -> CGFloat {
        max(8, min(16, available * 0.02))
    }

    /// Hide the subtitle hint on very compact screens to save vertical space.
    private func showSubtitle(available: CGFloat) -> Bool { available > 600 }

    var body: some View {
        GeometryReader { geo in
        let available = geo.size.height
        ZStack {
            // Background
            ONETokens.oneCream.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    // Header
                    VStack(alignment: .leading, spacing: 5) {
                        Text(NSLocalizedString("splash.slogan", comment: ""))
                            .font(ONETypography.monoSM)
                            .tracking(1.6)
                            .foregroundColor(ONETokens.oneBrand.opacity(0.8))

                        Text(NSLocalizedString("today.completedSubtitle", comment: ""))
                            .displayLG()
                            .foregroundColor(ONETokens.oneInk)
                            .lineSpacing(2)

                        if showSubtitle(available: available) {
                            Text(NSLocalizedString("today.shareHint", comment: ""))
                                .bodySM()
                                .foregroundColor(ONETokens.oneAsh)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, ONETokens.spacingXL2)
                    .padding(.top, headerTopPad(available: available))
                    .padding(.bottom, headerBottomPad(available: available))
                    
                    // Main Card
                    VStack(spacing: 0) {
                        // Photo or Mood gradient header
                        ZStack(alignment: .bottomLeading) {
                            if let photoURL = displayedEntry.photoURL {
                                // Photo background - tıklanabilir
                                Button(action: {
                                    withAnimation(ONEAnimation.panelSpring) {
                                        showPhotoViewer = true
                                    }
                                }) {
                                    AsyncImage(url: photoURL) { image in
                                        image
                                            .resizable()
                                            .aspectRatio(contentMode: .fill)
                                    } placeholder: {
                                        // Gradient fallback while loading
                                        LinearGradient(
                                            stops: [
                                                .init(color: displayedEntry.moodColor.opacity(0.65), location: 0.0),
                                                .init(color: displayedEntry.moodColor.opacity(0.35), location: 0.5),
                                                .init(color: displayedEntry.moodColor.opacity(0.15), location: 1.0)
                                            ],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    }
                                    .frame(height: photoHeight(available: available))
                                    .clipped()
                                    .overlay(
                                        // Subtle tap indicator
                                        ZStack {
                                            Color.black.opacity(0.02)
                                            Image(systemName: "arrow.up.left.and.arrow.down.right")
                                                .font(.system(size: 14, weight: .medium))
                                                .foregroundColor(.white.opacity(0.6))
                                        }
                                    )
                                }
                                .buttonStyle(PlainButtonStyle())
                                .accessibilityLabel(String(format: NSLocalizedString("accessibility.today.photoOf", comment: ""), displayedEntry.songName))
                            } else {
                                // Gradient background with wabi-sabi design
                                ZStack {
                                    // Base gradient
                                    LinearGradient(
                                        stops: [
                                            .init(color: displayedEntry.moodColor.opacity(0.65), location: 0.0),
                                            .init(color: displayedEntry.moodColor.opacity(0.35), location: 0.5),
                                            .init(color: displayedEntry.moodColor.opacity(0.15), location: 1.0)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                    
                                    // Abstract circles (only when no photo)
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
                                        colors: [displayedEntry.moodColor.opacity(0.15), .clear],
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
                            HStack(spacing: 6) {
                                Circle()
                                    .fill(Color.white.opacity(0.9))
                                    .frame(width: 6, height: 6)
                                Text(String(format: NSLocalizedString("today.timeSelected", comment: ""), displayedEntry.time))
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
                        .frame(height: photoHeight(available: available))
                        .frame(maxWidth: .infinity)
                        
                        // Song info section
                        VStack(alignment: .leading, spacing: ONETokens.spacingLG) {
                            // Song name
                            Text(displayedEntry.songName)
                                .displayMD()
                                .foregroundColor(ONETokens.oneInk)
                                .tracking(-0.8)
                                .lineLimit(2)
                            
                            // Artist & genre
                            Text("\(displayedEntry.artistName) · \(displayedEntry.genre)")
                                .monoBase(tracking: 0.5)
                                .foregroundColor(ONETokens.oneCharcoal)
                            
                            // Divider
                            Rectangle()
                                .fill(ONETokens.oneCreamLow)
                                .frame(height: 1)
                                .padding(.vertical, 4)
                            
                            // Mood & Feeling tags
                            HStack(spacing: ONETokens.spacingMD) {
                                // Mood
                                HStack(spacing: 6) {
                                    Circle()
                                        .fill(displayedEntry.moodColor)
                                        .frame(width: 7, height: 7)
                                    Text(displayedEntry.moodLabel.uppercased())
                                        .monoLabel(tracking: 1.2)
                                        .foregroundColor(ONETokens.oneCharcoal)
                                }
                                .padding(.horizontal, ONETokens.spacingMD)
                                .padding(.vertical, 6)
                                .background(
                                    Capsule()
                                        .fill(displayedEntry.moodColor.opacity(0.12))
                                )
                                
                                // Feeling
                                HStack(spacing: 6) {
                                    FeelingIconView(type: displayedEntry.feeling)
                                        .frame(width: 20, height: 16)
                                    Text(displayedEntry.feelingLabel.uppercased())
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
                            
                            // Weather & Share info
                            HStack(spacing: ONETokens.spacingMD) {
                                HStack(spacing: 5) {
                                    Text(displayedEntry.weatherIcon)
                                        .font(.system(size: 11))
                                    Text(displayedEntry.weatherDesc)
                                        .monoLabel()
                                        .foregroundColor(ONETokens.oneCharcoal)
                                }
                                
                                if displayedEntry.shareWithCircle {
                                    HStack(spacing: 5) {
                                        Text("🌍")
                                            .font(.system(size: 11))
                                        Text(NSLocalizedString("today.sharedInCircle", comment: ""))
                                            .monoLabel()
                                            .foregroundColor(ONETokens.oneCharcoal)
                                    }
                                }
                            }
                            .padding(.top, 4)

                            if displayedEntry.shareWithCircle {
                                HStack(spacing: 8) {
                                    Image(systemName: "person.2.fill")
                                        .font(.system(size: 11, weight: .medium))
                                    Text(NSLocalizedString("today.circleCanSee", comment: ""))
                                        .monoSM(tracking: 0.2)
                                }
                                .foregroundColor(ONETokens.oneAsh)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 10)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(ONETokens.oneSilver)
                                )
                            }
                            
                            // Note section (if exists)
                            if let note = displayedEntry.note, !note.isEmpty {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text(NSLocalizedString("today.note", comment: ""))
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
                                        .fill(displayedEntry.moodColor.opacity(0.08))
                                )
                                .padding(.top, ONETokens.spacingLG)
                            }

                            // Divider
                            Rectangle()
                                .fill(ONETokens.oneCreamLow)
                                .frame(height: 1)
                                .padding(.top, 8)

                            // Action buttons
                            VStack(spacing: 10) {
                                // Primary row — Keşfet (full width, prominent)
                                Button(action: {
                                    ONEHaptics.feelingSelected()
                                    NotificationManager.shared.shouldNavigateToDiscovery = true
                                }) {
                                    HStack(spacing: 6) {
                                        Image(systemName: "sparkles")
                                            .font(.system(size: 12, weight: .semibold))
                                        Text(NSLocalizedString("notification.openDiscovery", comment: ""))
                                            .bodySMMedium()
                                    }
                                    .foregroundColor(ONETokens.oneCream)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(Capsule().fill(displayedEntry.moodColor))
                                }
                                .accessibilityLabel(NSLocalizedString("notification.openDiscovery", comment: ""))
                                .accessibilityHint(NSLocalizedString("accessibility.discovery.eventHint", comment: ""))

                                // Secondary row — Kaydet, Paylaş, Ekle
                                HStack(spacing: 8) {
                                    if displayedEntry.photoURL != nil {
                                        Button(action: {
                                            savePhotoToGallery()
                                        }) {
                                            HStack(spacing: 5) {
                                                Image(systemName: photoSaved ? "checkmark" : "arrow.down.to.line")
                                                    .font(.system(size: 11, weight: .medium))
                                                Text(photoSaved ? NSLocalizedString("today.saved", comment: "") : NSLocalizedString("general.save", comment: ""))
                                                    .monoBase(tracking: 0.5)
                                            }
                                            .foregroundColor(photoSaved ? ONETokens.oneGreen : ONETokens.oneInk)
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 10)
                                            .background(
                                                Capsule()
                                                    .fill(photoSaved ? ONETokens.oneGreen.opacity(0.08) : ONETokens.oneCreamMid.opacity(0.5))
                                                    .overlay(Capsule().stroke(photoSaved ? ONETokens.oneGreen.opacity(0.3) : ONETokens.oneSilver, lineWidth: 1))
                                            )
                                        }
                                        .disabled(photoSaved)
                                    }

                                    Button(action: {
                                        ONEHaptics.feelingSelected()
                                        showShareOptions = true
                                    }) {
                                        HStack(spacing: 5) {
                                            Image(systemName: "square.and.arrow.up")
                                                .font(.system(size: 11, weight: .medium))
                                            Text(NSLocalizedString("general.share", comment: ""))
                                                .monoBase(tracking: 0.5)
                                        }
                                        .foregroundColor(ONETokens.oneInk)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 10)
                                        .background(
                                            Capsule()
                                                .fill(ONETokens.oneCreamMid.opacity(0.5))
                                                .overlay(Capsule().stroke(ONETokens.oneSilver, lineWidth: 1))
                                        )
                                    }
                                    .accessibilityLabel(NSLocalizedString("accessibility.today.shareButton", comment: ""))
                                }
                            }
                        }
                        .padding(20)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .background(ONETokens.onePaper)
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .shadow(color: Color.black.opacity(0.06), radius: 20, x: 0, y: 8)
                    .padding(.horizontal, 20)
                    .scaleEffect(appeared ? 1 : 0.94)
                    .opacity(appeared ? 1 : 0)
                    .animation(ONEAnimation.panelSpring.delay(0.2), value: appeared)

                }
            }
        } // ZStack
        } // GeometryReader
        .fullScreenCover(isPresented: $showPhotoViewer) {
            if let photoURL = displayedEntry.photoURL {
                PhotoViewerSheet(photoURL: photoURL, isPresented: $showPhotoViewer)
            }
        }
        .sheet(isPresented: $showShareOptions) {
            ONEShareSheet(entry: displayedEntry)
        }
        .confirmationDialog(
            NSLocalizedString("today.changeConfirmTitle", comment: ""),
            isPresented: $showChangeConfirm,
            titleVisibility: .visible
        ) {
            Button(NSLocalizedString("today.changeConfirmYes", comment: ""), role: .destructive) {
                onEdit()
            }
            Button(NSLocalizedString("general.cancel", comment: ""), role: .cancel) { }
        } message: {
            Text(NSLocalizedString("today.changeConfirmMessage", comment: ""))
        }
        .onAppear {
            withAnimation(ONEAnimation.screenTransition) { appeared = true }
        }
    }

    // MARK: - Save Photo to Gallery
    private func savePhotoToGallery() {
        guard let photoURL = displayedEntry.photoURL,
              let data = try? Data(contentsOf: photoURL),
              let image = UIImage(data: data) else { return }

        ONEHaptics.feelingSelected()
        UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
        withAnimation(ONEAnimation.micro) { photoSaved = true }
    }
}

// MARK: - Full Screen Photo Viewer
struct PhotoViewerSheet: View {
    let photoURL: URL
    @Binding var isPresented: Bool

    @State private var loadedImage: UIImage? = nil
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var dismissOffset: CGFloat = 0
    @State private var backgroundOpacity: Double = 1.0
    @State private var panOffset: CGSize = .zero
    @State private var lastPanOffset: CGSize = .zero

    private let dismissThreshold: CGFloat = 120

    var body: some View {
        let isZoomed = scale > 1.01
        return ZStack {
            Color.black.opacity(backgroundOpacity).ignoresSafeArea()

            if let uiImage = loadedImage {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .scaleEffect(scale)
                    .offset(
                        x: isZoomed ? panOffset.width  : 0,
                        y: isZoomed ? panOffset.height : dismissOffset
                    )
                    .gesture(
                        SimultaneousGesture(
                            MagnificationGesture()
                                .onChanged { value in
                                    scale = min(max(lastScale * value, 1.0), 5.0)
                                }
                                .onEnded { _ in
                                    lastScale = scale
                                    if scale <= 1.0 {
                                        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                                            scale = 1.0
                                            lastScale = 1.0
                                            panOffset = .zero
                                            lastPanOffset = .zero
                                        }
                                    }
                                },
                            DragGesture()
                                .onChanged { val in
                                    if scale > 1.01 {
                                        panOffset = CGSize(
                                            width:  lastPanOffset.width  + val.translation.width,
                                            height: lastPanOffset.height + val.translation.height
                                        )
                                    } else {
                                        let dy = val.translation.height
                                        if dy > 0 {
                                            dismissOffset = dy
                                            backgroundOpacity = Double(max(0.3, 1.0 - dy / 300))
                                        }
                                    }
                                }
                                .onEnded { val in
                                    if scale > 1.01 {
                                        lastPanOffset = panOffset
                                    } else {
                                        let velocity = val.predictedEndTranslation.height - val.translation.height
                                        let shouldDismiss = val.translation.height > dismissThreshold
                                            || (val.translation.height > 30 && velocity > 250)
                                        if shouldDismiss {
                                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                            withAnimation(.easeOut(duration: 0.18)) {
                                                dismissOffset = UIScreen.main.bounds.height
                                                backgroundOpacity = 0
                                            }
                                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [self] in
                                                guard isPresented else { return }
                                                var t = Transaction()
                                                t.disablesAnimations = true
                                                withTransaction(t) { isPresented = false }
                                            }
                                        } else {
                                            withAnimation(.spring(response: 0.32, dampingFraction: 0.76)) {
                                                dismissOffset = 0
                                                backgroundOpacity = 1.0
                                            }
                                        }
                                    }
                                }
                        )
                    )
                    .onTapGesture(count: 2) {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                            if isZoomed {
                                scale = 1.0
                                lastScale = 1.0
                                panOffset = .zero
                                lastPanOffset = .zero
                            } else {
                                scale = 2.5
                                lastScale = 2.5
                            }
                        }
                    }
            } else {
                ProgressView().tint(.white)
            }

            // Kapat butonu — zoom'dayken sabit, değilse fotoğrafla kayar
            VStack {
                HStack {
                    Button(action: {
                        isPresented = false
                        dismissOffset = 0
                        scale = 1.0
                        lastScale = 1.0
                        panOffset = .zero
                        lastPanOffset = .zero
                    }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 44, height: 44)
                            .background(Circle().fill(Color.black.opacity(0.5))
                                .overlay(Circle().stroke(Color.white.opacity(0.2), lineWidth: 1)))
                    }
                    .padding(20)
                    Spacer()
                }
                Spacer()
                // Aşağı kaydır ipucu — zoom modunda gizle
                Image(systemName: "chevron.compact.down")
                    .font(.system(size: 24, weight: .light))
                    .foregroundColor(.white.opacity(isZoomed ? 0 : 0.3))
                    .padding(.bottom, 24)
                    .animation(ONEAnimation.micro, value: isZoomed)
            }
            .offset(y: isZoomed ? 0 : dismissOffset)
        }
        .statusBar(hidden: true)
        .task {
            // Pre-load image once to avoid AsyncImage re-fetches during gesture
            if let data = try? Data(contentsOf: photoURL) {
                loadedImage = UIImage(data: data)
            }
        }
    }
}


// MARK: - Story Card Share Sheet
struct StoryCardShareSheet: View {
    let entry: DailyEntry
    
    @Environment(\.dismiss) private var dismiss
    @State private var isGeneratingCard = false
    @State private var generatedImage: UIImage?
    @State private var errorMessage: String?
    @State private var showError = false
    @State private var breathe = false
    
    var body: some View {
        NavigationView {
            ZStack {
                ONETokens.oneCream.ignoresSafeArea()
                
                VStack(spacing: 24) {
                    // Preview or loading state
                    if let image = generatedImage {
                        // Show generated image preview
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxHeight: 400)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 4)
                            .padding(.horizontal, 20)
                    } else if isGeneratingCard {
                        // Loading state
                        VStack(spacing: 16) {
                            Circle()
                                .fill(ONETokens.oneInk)
                                .frame(width: 8, height: 8)
                                .scaleEffect(breathe ? 1.4 : 0.8)
                                .opacity(breathe ? 1.0 : 0.4)
                            
                            Text(NSLocalizedString("today.cardLoading", comment: ""))
                                .monoBase(tracking: 0.5)
                                .foregroundColor(ONETokens.oneCharcoal)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        // Initial state
                        VStack(spacing: 16) {
                            Image(systemName: "photo.on.rectangle.angled")
                                .font(.system(size: 48, weight: .light))
                                .foregroundColor(ONETokens.oneAsh)
                            
                            Text(NSLocalizedString("today.createShareCard", comment: ""))
                                .monoBase(tracking: 0.5)
                                .foregroundColor(ONETokens.oneCharcoal)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                    
                    Spacer()
                    
                    // Action buttons
                    VStack(spacing: 12) {
                        if generatedImage != nil {
                            // Share button
                            Button(action: handleShare) {
                                HStack(spacing: 8) {
                                    Image(systemName: "square.and.arrow.up")
                                        .font(.system(size: 16, weight: .light))
                                    Text(NSLocalizedString("general.share", comment: ""))
                                        .monoBase(tracking: 0.5)
                                }
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(
                                    RoundedRectangle(cornerRadius: 2)
                                        .fill(ONETokens.oneInk)
                                )
                            }
                            
                            // Save to library button
                            Button(action: handleSaveToLibrary) {
                                HStack(spacing: 8) {
                                    Image(systemName: "square.and.arrow.down")
                                        .font(.system(size: 14, weight: .light))
                                    Text(NSLocalizedString("today.saveToPhotos", comment: ""))
                                        .monoBase(tracking: 0.5)
                                }
                                .foregroundColor(ONETokens.oneCharcoal)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(
                                    RoundedRectangle(cornerRadius: 2)
                                        .strokeBorder(ONETokens.oneStone, lineWidth: 1)
                                )
                            }
                        } else {
                            // Generate button
                            Button(action: handleGenerate) {
                                HStack(spacing: 8) {
                                    Image(systemName: "sparkles")
                                        .font(.system(size: 16, weight: .light))
                                    Text(NSLocalizedString("today.generateCard", comment: ""))
                                        .monoBase(tracking: 0.5)
                                }
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(
                                    RoundedRectangle(cornerRadius: 2)
                                        .fill(ONETokens.oneInk)
                                )
                            }
                            .disabled(isGeneratingCard)
                            .opacity(isGeneratingCard ? 0.6 : 1.0)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
                }
            }
            .navigationTitle(NSLocalizedString("general.share", comment: ""))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(NSLocalizedString("general.close", comment: "")) {
                        dismiss()
                    }
                    .foregroundColor(ONETokens.oneCharcoal)
                }
            }
        }
        .alert(NSLocalizedString("general.error", comment: ""), isPresented: $showError) {
            Button(NSLocalizedString("general.ok", comment: ""), role: .cancel) {}
            if generatedImage == nil {
                Button(NSLocalizedString("general.retry", comment: "")) {
                    handleGenerate()
                }
            }
        } message: {
            Text(errorMessage ?? NSLocalizedString("general.error", comment: ""))
        }
        .onChange(of: isGeneratingCard) { oldValue, newValue in
            if newValue {
                withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                    breathe = true
                }
            } else {
                breathe = false
            }
        }
    }
    
    private func handleGenerate() {
        isGeneratingCard = true
        errorMessage = nil
        
        Task {
            do {
                // Generate card directly from DailyEntry
                let image = try await StoryCardGenerator.shared
                    .generateCardAsync(from: entry)
                
                await MainActor.run {
                    generatedImage = image
                    isGeneratingCard = false
                    ONEHaptics.songSaved()
                }

            } catch {
                await MainActor.run {
                    isGeneratingCard = false
                    errorMessage = error.localizedDescription
                    showError = true
                    ONEHaptics.error()
                }
            }
        }
    }
    
    private func handleShare() {
        guard let image = generatedImage else { return }
        
        let activityVC = UIActivityViewController(
            activityItems: [image],
            applicationActivities: nil
        )
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = windowScene.windows.first?.rootViewController {
            
            // Configure for iPad
            if let popover = activityVC.popoverPresentationController {
                popover.sourceView = rootVC.view
                popover.sourceRect = CGRect(
                    x: rootVC.view.bounds.midX,
                    y: rootVC.view.bounds.midY,
                    width: 0,
                    height: 0
                )
                popover.permittedArrowDirections = []
            }
            
            rootVC.present(activityVC, animated: true)
        }
    }
    
    private func handleSaveToLibrary() {
        guard let image = generatedImage else { return }
        
        ShareManager.shared.saveToPhotoLibrary(image: image) { result in
            switch result {
            case .success:
                ONEHaptics.songSaved()
                dismiss()
            case .failure(let error):
                errorMessage = error.localizedDescription
                showError = true
                ONEHaptics.error()
            }
        }
    }
}
