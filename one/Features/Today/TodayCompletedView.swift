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
    @State private var showEvents = false

    var body: some View {
        ZStack {
            // Background
            ONETokens.oneCream.ignoresSafeArea()
            
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    // Header
                    VStack(alignment: .leading, spacing: 8) {
                        Text("hisset · keşfet · paylaş")
                            .font(ONETypography.monoSM)
                            .tracking(1.6)
                            .foregroundColor(ONETokens.oneBrand.opacity(0.8))

                        Text("Bugünün seçimi\nhazır")
                            .displayLG()
                            .foregroundColor(ONETokens.oneInk)
                            .lineSpacing(2)

                        Text("Şimdi etkinlikleri açabilir ya da çevrene gönderebilirsin.")
                            .bodySM()
                            .foregroundColor(ONETokens.oneAsh)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, ONETokens.spacingXL2)
                    .padding(.top, ONETokens.spacingXL4)
                    .padding(.bottom, 24)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : -10)
                    .animation(ONEAnimation.screenTransition.delay(0.1), value: appeared)
                    
                    // Main Card
                    VStack(spacing: 0) {
                        // Photo or Mood gradient header
                        ZStack(alignment: .bottomLeading) {
                            if let photoURL = entry.photoURL {
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
                                                .init(color: entry.moodColor.opacity(0.65), location: 0.0),
                                                .init(color: entry.moodColor.opacity(0.35), location: 0.5),
                                                .init(color: entry.moodColor.opacity(0.15), location: 1.0)
                                            ],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    }
                                    .frame(height: 180)
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
                            } else {
                                // Gradient background with wabi-sabi design
                                ZStack {
                                    // Base gradient
                                    LinearGradient(
                                        stops: [
                                            .init(color: entry.moodColor.opacity(0.65), location: 0.0),
                                            .init(color: entry.moodColor.opacity(0.35), location: 0.5),
                                            .init(color: entry.moodColor.opacity(0.15), location: 1.0)
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
                                        colors: [entry.moodColor.opacity(0.15), .clear],
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
                                Text("\(entry.time)'te")
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
                        .frame(height: 180)
                        .frame(maxWidth: .infinity)
                        
                        // Song info section
                        VStack(alignment: .leading, spacing: ONETokens.spacingLG) {
                            // Song name
                            Text(entry.songName)
                                .displayMD()
                                .foregroundColor(ONETokens.oneInk)
                                .tracking(-0.8)
                                .lineLimit(2)
                            
                            // Artist & genre
                            Text("\(entry.artistName) · \(entry.genre)")
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
                                        .fill(entry.moodColor)
                                        .frame(width: 7, height: 7)
                                    Text(entry.moodLabel.uppercased())
                                        .monoLabel(tracking: 1.2)
                                        .foregroundColor(ONETokens.oneCharcoal)
                                }
                                .padding(.horizontal, ONETokens.spacingMD)
                                .padding(.vertical, 6)
                                .background(
                                    Capsule()
                                        .fill(entry.moodColor.opacity(0.12))
                                )
                                
                                // Feeling
                                HStack(spacing: 6) {
                                    FeelingIconView(type: entry.feeling)
                                        .frame(width: 20, height: 16)
                                    Text(entry.feelingLabel.uppercased())
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
                                    Text(entry.weatherIcon)
                                        .font(.system(size: 11))
                                    Text(entry.weatherDesc)
                                        .monoLabel()
                                        .foregroundColor(ONETokens.oneCharcoal)
                                }
                                
                                if entry.shareWithCircle {
                                    HStack(spacing: 5) {
                                        Text("🌍")
                                            .font(.system(size: 11))
                                        Text("Çevre'de paylaşıldı")
                                            .monoLabel()
                                            .foregroundColor(ONETokens.oneCharcoal)
                                    }
                                }
                            }
                            .padding(.top, 4)

                            if entry.shareWithCircle {
                                HStack(spacing: 8) {
                                    Image(systemName: "person.2.fill")
                                        .font(.system(size: 11, weight: .medium))
                                    Text("Çevren bugünkü mood'unu görebiliyor")
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
                            if let note = entry.note, !note.isEmpty {
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
                                        .fill(entry.moodColor.opacity(0.08))
                                )
                                .padding(.top, ONETokens.spacingLG)
                            }

                            // Divider
                            Rectangle()
                                .fill(ONETokens.oneCreamLow)
                                .frame(height: 1)
                                .padding(.top, 8)

                            // Action buttons
                            HStack(spacing: 8) {
                                Button(action: {
                                    ONEHaptics.feelingSelected()
                                    showEvents = true
                                }) {
                                    HStack(spacing: 4) {
                                        Image(systemName: "sparkles")
                                            .font(.system(size: 10, weight: .medium))
                                        Text("Keşfet")
                                            .monoBase(tracking: 0.8)
                                    }
                                    .foregroundColor(ONETokens.oneCream)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 8)
                                    .background(Capsule().fill(entry.moodColor))
                                }

                                Spacer()

                                HStack(spacing: 8) {
                                    Button(action: {
                                        ONEHaptics.feelingSelected()
                                        showShareOptions = true
                                    }) {
                                        HStack(spacing: 4) {
                                            Image(systemName: "square.and.arrow.up")
                                                .font(.system(size: 10, weight: .medium))
                                            Text("Paylaş")
                                                .monoBase(tracking: 0.8)
                                        }
                                        .foregroundColor(ONETokens.oneCharcoal)
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 8)
                                        .background(
                                            Capsule().stroke(ONETokens.oneCreamLow, lineWidth: 1.5)
                                        )
                                    }

                                    Button(action: {
                                        ONEHaptics.moodSelected()
                                        showChangeConfirm = true
                                    }) {
                                        HStack(spacing: 4) {
                                            Image(systemName: "arrow.triangle.2.circlepath")
                                                .font(.system(size: 10, weight: .medium))
                                            Text("Değiştir")
                                                .monoBase(tracking: 0.8)
                                        }
                                        .foregroundColor(ONETokens.oneCream)
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 8)
                                        .background(Capsule().fill(ONETokens.oneInk))
                                    }
                                }
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
                    
                    // Context card
                    DailyContextCard(entry: entry)
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    .padding(.bottom, 24)
                    .opacity(appeared ? 1 : 0)
                    .animation(.easeOut(duration: ONEAnimation.durationLong).delay(0.35), value: appeared)
                }
            }
        }
        .fullScreenCover(isPresented: $showPhotoViewer) {
            if let photoURL = entry.photoURL {
                PhotoViewerSheet(photoURL: photoURL, isPresented: $showPhotoViewer)
            }
        }
        .sheet(isPresented: $showShareOptions) {
            ONEShareSheet(entry: entry)
        }
        .sheet(isPresented: $showEvents) {
            MoodEventsSheet(entry: entry)
        }
        .confirmationDialog(
            "Seçimini değiştir",
            isPresented: $showChangeConfirm,
            titleVisibility: .visible
        ) {
            Button("Evet, değiştir", role: .destructive) {
                onEdit()
            }
            Button("Vazgeç", role: .cancel) { }
        } message: {
            Text("Bugünkü şarkın silinecek ve yeniden seçebileceksin.")
        }
        .onAppear {
            withAnimation(ONEAnimation.screenTransition) { appeared = true }
        }
    }
}

// MARK: - Full Screen Photo Viewer
struct PhotoViewerSheet: View {
    let photoURL: URL
    @Binding var isPresented: Bool

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

            AsyncImage(url: photoURL) { phase in
                switch phase {
                case .success(let image):
                    image
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
                                        } else if val.translation.height > dismissThreshold {
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
                case .failure:
                    VStack(spacing: 12) {
                        Image(systemName: "photo.fill")
                            .font(.system(size: 48))
                            .foregroundColor(.white.opacity(0.3))
                        Text("Fotoğraf yüklenemedi")
                            .monoBase()
                            .foregroundColor(.white.opacity(0.6))
                    }
                case .empty:
                    ProgressView().tint(.white)
                @unknown default:
                    EmptyView()
                }
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
    }
}


// MARK: - Daily Context Card
struct DailyContextCard: View {
    let entry: DailyEntry
    @State private var showEvents = false
    @AppStorage(ONETokens.cityPreferenceKey) private var preferredCity: String = ONETokens.defaultCity
    @State private var liveEventCount: Int? = nil
    @State private var liveCategories: String? = nil

    private var moodCategories: String {
        switch canonicalMoodLabel(entry.moodLabel) {
        case "Ateşli":    return "Aktivite · Konser · Tiyatro"
        case "Coşkulu":   return "Aktivite · Konser · Tiyatro"
        case "Mutlu":     return "Aktivite · Sergi · Konser"
        case "Doğal":     return "Aktivite · Sergi · Konser"
        case "Huzurlu":   return "Aktivite · Tiyatro · Sergi"
        case "Özgür":     return "Aktivite · Konser · Sergi"
        case "Derin":     return "Aktivite · Tiyatro · Konser"
        case "Nostaljik": return "Aktivite · Konser · Sergi"
        case "Gizemli":   return "Aktivite · Sergi · Konser"
        case "Hassas":    return "Aktivite · Konser · Sergi"
        case "Sessiz":    return "Aktivite · Sergi · Tiyatro"
        case "Nötr":      return "Aktivite · Sergi · Konser"
        default:           return "Aktivite · Konser · Sergi"
        }
    }

    private var eventCount: Int { liveEventCount ?? mockEvents(for: entry.moodLabel, city: preferredCity).count }

    private var buttonTextColor: Color {
        let moodLabel = canonicalMoodLabel(entry.moodLabel)
        // Light-background moods need dark text for legibility
        return ["Mutlu", "Doğal", "Nötr"].contains(moodLabel)
            ? ONETokens.oneInk : .white
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 7) {
                Circle()
                    .fill(entry.moodColor)
                    .frame(width: 5, height: 5)
                Text("KESFET · \(entry.moodLabel.uppercased()) · \(preferredCity.uppercased())")
                    .monoSM(tracking: 1.5)
                    .foregroundColor(.white.opacity(0.45))
            }

            Text("Bu mood için\n\(eventCount) yakın öneri hazır.")
                .displayMD()
                .foregroundColor(.white)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)

            Text(liveCategories ?? moodCategories)
                .monoSM(tracking: 0.8)
                .foregroundColor(.white.opacity(0.4))

            Text("Konserlerden sergilere, bugünkü enerjine uyan rotaları aç.")
                .bodySM()
                .foregroundColor(.white.opacity(0.72))

            Button(action: {
                ONEHaptics.feelingSelected()
                showEvents = true
            }) {
                HStack(spacing: 4) {
                    Text("Etkinlikleri keşfet")
                        .monoBase(tracking: 0.5)
                    Text("→")
                }
                .foregroundColor(buttonTextColor)
                .padding(.horizontal, 18)
                .padding(.vertical, 10)
                .background(Capsule().fill(entry.moodColor))
            }
            .padding(.top, 2)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(red: 0.157, green: 0.129, blue: 0.110))
        )
        .sheet(isPresented: $showEvents) {
            MoodEventsSheet(entry: entry)
        }
        .task(id: preferredCity) {
            if preferredCity == "İzmit" {
                preferredCity = "Kocaeli"
                return
            }
            let fetched = await ActivityRecommendationEngine.shared.fetchRecommendations(for: entry, city: preferredCity)
            liveEventCount = fetched.count
            let topCategories = Dictionary(grouping: fetched, by: { $0.category })
                .mapValues(\.count)
                .sorted { $0.value > $1.value }
                .prefix(3)
                .map { $0.key.rawValue }
            if !topCategories.isEmpty {
                liveCategories = topCategories.joined(separator: " · ")
            } else {
                liveCategories = moodCategories
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
                            
                            Text("Kartın hazırlanıyor...")
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
                            
                            Text("Paylaşım kartını oluştur")
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
                                    Text("Paylaş")
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
                                    Text("Fotoğraflara Kaydet")
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
                                    Text("Kart Oluştur")
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
            .navigationTitle("Paylaş")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Kapat") {
                        dismiss()
                    }
                    .foregroundColor(ONETokens.oneCharcoal)
                }
            }
        }
        .alert("Hata", isPresented: $showError) {
            Button("Tamam", role: .cancel) {}
            if generatedImage == nil {
                Button("Tekrar Dene") {
                    handleGenerate()
                }
            }
        } message: {
            Text(errorMessage ?? "Bir hata oluştu")
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
