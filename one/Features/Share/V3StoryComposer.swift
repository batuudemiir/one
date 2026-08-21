//
//  V3StoryComposer.swift
//  one
//
//  Kaydedildi ekranından "Story kart oluştur" ile açılan besteci.
//  Spec: 3 toggle (oran 9:16/1:1 · zemin Renk/Kağıt/Fotoğraf · içerik Not/Şarkı),
//  canlı önizleme, Kaydet ve Paylaş.
//

import SwiftUI
import UIKit

// MARK: - Enums

enum V3StoryRatio: String, CaseIterable, Identifiable {
    case story  // 9:16
    case square // 1:1
    var id: String { rawValue }
    var label: String { self == .story ? "9:16" : "1:1" }
    var aspect: CGFloat { self == .story ? 9.0 / 16.0 : 1.0 }
    /// Export boyutu (piksel). Story: 1080×1920, Kare: 1080×1080.
    var exportSize: CGSize { self == .story ? .init(width: 1080, height: 1920) : .init(width: 1080, height: 1080) }
}

enum V3StoryBackground: String, CaseIterable, Identifiable {
    case color   // mood color
    case paper   // v3 paper
    case photo   // kullanıcının çektiği fotoğraf (varsa)
    var id: String { rawValue }
    var label: String {
        switch self {
        case .color: return "Renk"
        case .paper: return "Kağıt"
        case .photo: return "Fotoğraf"
        }
    }
}

enum V3StoryContent: String, CaseIterable, Identifiable {
    case note
    case song
    var id: String { rawValue }
    var label: String { self == .note ? "Not" : "Şarkı" }
}

// MARK: - Composer

struct V3StoryComposerView: View {
    let mood: V3Mood
    let note: String?
    let photo: UIImage?
    let songName: String?
    let songArtist: String?
    let dateLabel: String

    let onClose: () -> Void

    @State private var ratio: V3StoryRatio = .story
    @State private var background: V3StoryBackground
    @State private var content: V3StoryContent

    @State private var isSharing = false
    @State private var toast: String?
    @State private var toastKey = UUID()

    init(
        mood: V3Mood,
        note: String?,
        photo: UIImage?,
        songName: String?,
        songArtist: String?,
        dateLabel: String,
        onClose: @escaping () -> Void
    ) {
        self.mood = mood
        self.note = note
        self.photo = photo
        self.songName = songName
        self.songArtist = songArtist
        self.dateLabel = dateLabel
        self.onClose = onClose
        // Foto varsa varsayılan fotoğraf; yoksa renk. İçerik: not > şarkı.
        _background = State(initialValue: photo != nil ? .photo : .color)
        let hasNote = !(note?.isEmpty ?? true)
        _content = State(initialValue: hasNote ? .note : .song)
    }

    /// Foto olmadığında toggle'da sadece iki seçenek gösterilir.
    private var availableBackgrounds: [V3StoryBackground] {
        photo == nil ? [.color, .paper] : V3StoryBackground.allCases
    }

    var body: some View {
        GeometryReader { proxy in
            let safeTop = proxy.safeAreaInsets.top
            let safeBottom = proxy.safeAreaInsets.bottom
            let screenH = proxy.size.height
            let screenW = proxy.size.width
            // Toplam UI'nin öncelik yüksekliği: header 62 + toggles 200 + actionBar 88.
            // Önizleme kalanı doldurur, ama en fazla ekranın %60'ı.
            let togglesHeight: CGFloat = 210
            let headerHeight: CGFloat = 62
            let actionBarHeight: CGFloat = 88
            let verticalChrome = safeTop + safeBottom + headerHeight + togglesHeight + actionBarHeight + 36
            let previewMaxH = max(240, min(screenH * 0.58, screenH - verticalChrome))
            let previewMaxW = screenW - 40
            // Karta sığdır: aspect'e göre en kısıtlayıcı boyut kazanır.
            let byHeight = CGSize(width: previewMaxH * ratio.aspect, height: previewMaxH)
            let byWidth  = CGSize(width: previewMaxW, height: previewMaxW / ratio.aspect)
            let cardSize = byHeight.width <= previewMaxW ? byHeight : byWidth

            ZStack(alignment: .top) {
                V3Tokens.paper.ignoresSafeArea()

                VStack(spacing: 0) {
                    header

                    Spacer(minLength: 8)

                    storyCard
                        .frame(width: cardSize.width, height: cardSize.height)
                        .clipShape(RoundedRectangle(cornerRadius: V3Tokens.radiusPanel, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: V3Tokens.radiusPanel, style: .continuous)
                                .stroke(V3Tokens.hairline, lineWidth: 1)
                        )
                        .shadow(color: Color.black.opacity(0.10), radius: 22, x: 0, y: 10)
                        .animation(.timingCurve(0.2, 0.9, 0.25, 1, duration: 0.32), value: ratio)
                        .animation(.timingCurve(0.2, 0.9, 0.25, 1, duration: 0.22), value: background)
                        .animation(.timingCurve(0.2, 0.9, 0.25, 1, duration: 0.22), value: content)

                    Spacer(minLength: 8)

                    togglesGroup
                        .padding(.horizontal, V3Tokens.spacingXL)

                    actionBar
                        .padding(.horizontal, V3Tokens.spacingXL)
                        .padding(.top, 14)
                        .padding(.bottom, max(safeBottom, 10) + 4)
                }

                if let toast {
                    toastView(toast)
                        .id(toastKey)
                        .padding(.top, safeTop + 12)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
        }
        .ignoresSafeArea(.keyboard)
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Story kart")
                    .font(V3Typography.display(22, weight: .semibold))
                    .tracking(-0.5)
                    .foregroundColor(V3Tokens.ink)
                Text(NSLocalizedString("share.orSave", comment: ""))
                    .bodyMicro()
                    .foregroundColor(V3Tokens.mutedText)
            }
            Spacer()
            V3TopBarIconButton(
                systemName: "xmark",
                label: NSLocalizedString("general.close", comment: "")
            ) { onClose() }
        }
        .padding(.horizontal, V3Tokens.spacingXL)
        .padding(.top, 10)
        .padding(.bottom, V3Tokens.spacingXS)
        .frame(height: 62, alignment: .center)
    }

    // MARK: - Card (aynı view hem preview hem export'ta kullanılır)

    private var storyCard: some View {
        ZStack(alignment: .topLeading) {
            backgroundLayer
            scrimLayer
            contentLayer
        }
    }

    @ViewBuilder
    private var backgroundLayer: some View {
        switch background {
        case .color:
            Rectangle().fill(mood.color)
        case .paper:
            // `V3Tokens.paper` adaptive: koyu temadaki kullanıcı "kağıt"
            // zeminli story'yi koyu export ediyordu. Kart sabit tuvale
            // çizilip dışarı gidiyor — zemin de sabit olmalı.
            Rectangle().fill(V3Tokens.Export.paper)
        case .photo:
            if let photo {
                Image(uiImage: photo)
                    .resizable()
                    .scaledToFill()
            } else {
                Rectangle().fill(mood.color)
            }
        }
    }

    /// Foto zeminde okunabilirlik için alt gradient scrim.
    @ViewBuilder
    private var scrimLayer: some View {
        if background == .photo {
            LinearGradient(
                stops: [
                    .init(color: .black.opacity(0.0),  location: 0.20),
                    .init(color: .black.opacity(0.62), location: 1.0)
                ],
                startPoint: .top, endPoint: .bottom
            )
        }
    }

    private var contentLayer: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(dateLabel.uppercased())
                    .font(V3Typography.monoFixed(10))
                    .tracking(1.5)
                    .foregroundColor(topInk.opacity(0.72))
                Spacer()
                ONEWordmark(size: 14, tone: brandTone)
            }
            .padding(.horizontal, V3Tokens.spacingXL)
            .padding(.top, V3Tokens.spacingXL)

            Spacer(minLength: 0)

            VStack(alignment: .leading, spacing: 10) {
                Circle()
                    .fill(dotFill)
                    .frame(width: 26, height: 26)
                    .overlay(
                        (background == .color)
                            ? Circle().stroke(bodyInk.opacity(0.22), lineWidth: 1)
                            : nil
                    )

                Text(mood.label.lowercased())
                    .font(V3Typography.displayFixed(30))
                    .tracking(-0.8)
                    .foregroundColor(bodyInk)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                contentBlock
            }
            .padding(.horizontal, V3Tokens.spacingXL)
            .padding(.bottom, V3Tokens.spacingXL)
        }
    }

    @ViewBuilder
    private var contentBlock: some View {
        switch content {
        case .note:
            if let n = note, !n.isEmpty {
                Text(n)
                    .font(V3Typography.sansFixed(14))
                    .foregroundColor(bodyInk.opacity(0.86))
                    .lineSpacing(3)
                    .lineLimit(4)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text(NSLocalizedString("share.noNote", comment: ""))
                    .font(V3Typography.sansFixed(12))
                    .foregroundColor(bodyInk.opacity(0.55))
            }
        case .song:
            if let s = songName, !s.isEmpty {
                VStack(alignment: .leading, spacing: 3) {
                    Text(s)
                        .font(V3Typography.sansFixed(14, weight: .semibold))
                        .foregroundColor(bodyInk)
                        .lineLimit(1)
                    if let a = songArtist, !a.isEmpty {
                        Text(a)
                            .font(V3Typography.sansFixed(12))
                            .foregroundColor(bodyInk.opacity(0.72))
                            .lineLimit(1)
                    }
                }
            } else {
                Text(NSLocalizedString("share.noSong", comment: ""))
                    .font(V3Typography.sansFixed(12))
                    .foregroundColor(bodyInk.opacity(0.55))
            }
        }
    }

    // MARK: - Ink selection (auto-contrast)

    /// Kart üstündeki tarih + wordmark için ink.
    private var topInk: Color {
        switch background {
        case .color: return mood.ink
        // Sabit: zemin de sabit (`Export.paper`). Adaptive `V3Tokens.ink`
        // koyu temada açık mürekkep döner ve açık kağıt üstünde kaybolur.
        case .paper: return V3Tokens.Export.ink
        case .photo: return ONEBrand.bone
        }
    }
    /// ONE kelime işareti tonu: paper'da kor; renk zeminde mood'un kendi
    /// mürekkebi; foto zeminde bone.
    private var brandTone: ONEWordmark.Tone {
        switch background {
        case .color: return .custom(mood.ink)
        case .paper: return .kor
        case .photo: return .bone
        }
    }
    /// Ana içerik (duygu / not / şarkı) ink'i.
    private var bodyInk: Color {
        switch background {
        case .color: return mood.ink
        case .paper: return V3Tokens.Export.ink
        case .photo: return ONEBrand.bone
        }
    }
    /// Renk noktasının dolgusu — renk zeminde soluk ink; paper/foto'da mood rengi.
    private var dotFill: Color {
        background == .color ? bodyInk.opacity(0.14) : mood.color
    }

    // MARK: - Toggles

    private var togglesGroup: some View {
        VStack(spacing: V3Tokens.spacingMD) {
            toggleRow(title: "ORAN") {
                segmented(V3StoryRatio.allCases, selection: $ratio) { $0.label }
            }
            toggleRow(title: "ZEMİN") {
                segmented(availableBackgrounds, selection: $background) { $0.label }
            }
            toggleRow(title: "İÇERİK") {
                segmented(V3StoryContent.allCases, selection: $content) { $0.label }
            }
        }
    }

    private func toggleRow<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        HStack(alignment: .center, spacing: V3Tokens.spacingMD) {
            Text(title)
                .font(V3Typography.mono(10))
                .tracking(1.5)
                .foregroundColor(V3Tokens.faintText)
                .frame(width: 60, alignment: .leading)
            content()
        }
    }

    private func segmented<T: Identifiable & Equatable>(
        _ items: [T],
        selection: Binding<T>,
        label: @escaping (T) -> String
    ) -> some View {
        HStack(spacing: V3Tokens.spacingXS) {
            ForEach(items) { item in
                let isOn = selection.wrappedValue == item
                Button {
                    ONEHaptics.feelingSelected()
                    selection.wrappedValue = item
                } label: {
                    Text(label(item))
                        .font(V3Typography.sans(13, weight: isOn ? .semibold : .medium))
                        .foregroundColor(isOn ? V3Tokens.ink : V3Tokens.mutedText)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                        .background(
                            Group {
                                if isOn {
                                    Capsule().fill(V3Tokens.paper)
                                        .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
                                }
                            }
                        )
                }
                .buttonStyle(.onePressable)
            }
        }
        .padding(V3Tokens.spacingXS)
        .background(Capsule().fill(V3Tokens.wash))
    }

    // MARK: - Actions

    private var actionBar: some View {
        HStack(spacing: 10) {
            Button {
                saveToPhotos()
            } label: {
                HStack(spacing: V3Tokens.spacingSM) {
                    Image(systemName: "arrow.down.to.line")
                        .font(.system(size: 14, weight: .semibold))
                    Text("Kaydet")
                        .bodyLGSemibold()
                }
                .foregroundColor(V3Tokens.ink)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Capsule().stroke(V3Tokens.ink, lineWidth: 1.5))
            }
            .buttonStyle(.onePressable)

            Button {
                sharePhoto()
            } label: {
                HStack(spacing: V3Tokens.spacingSM) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 14, weight: .semibold))
                    Text(NSLocalizedString("general.share", comment: ""))
                        .bodyLGSemibold()
                }
                .foregroundColor(V3Tokens.paper)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Capsule().fill(V3Tokens.ink))
            }
            .buttonStyle(.onePressable)
            .disabled(isSharing)
        }
    }

    // MARK: - Toast

    private func toastView(_ text: String) -> some View {
        Text(text)
            .font(V3Typography.mono(11))
            .tracking(1.2)
            .foregroundColor(V3Tokens.paper)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Capsule().fill(V3Tokens.ink))
            .shadow(color: .black.opacity(0.12), radius: 8, y: 3)
    }

    private func showToast(_ text: String) {
        toastKey = UUID()
        withAnimation(.timingCurve(0.2, 0.9, 0.25, 1, duration: 0.32)) {
            toast = text
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.4) {
            withAnimation(.easeInOut) { toast = nil }
        }
    }

    // MARK: - Rendering (aynı storyCard, export boyutunda)

    @MainActor
    private func renderImage() -> UIImage? {
        let size = ratio.exportSize
        // Point boyutunda (piksel/scale) render + 3x scale = export piksel.
        let pointSize = CGSize(width: size.width / 3, height: size.height / 3)
        let content = storyCard
            .frame(width: pointSize.width, height: pointSize.height)

        let renderer = ImageRenderer(content: content)
        renderer.scale = 3.0
        renderer.proposedSize = ProposedViewSize(width: pointSize.width, height: pointSize.height)
        return renderer.uiImage
    }

    private func saveToPhotos() {
        ONEHaptics.feelingSelected()
        guard let img = renderImage() else {
            showToast("Kart oluşturulamadı"); return
        }
        UIImageWriteToSavedPhotosAlbum(img, nil, nil, nil)
        showToast("Fotoğraflara kaydedildi")
    }

    private func sharePhoto() {
        ONEHaptics.feelingSelected()
        guard let img = renderImage() else {
            showToast("Kart oluşturulamadı"); return
        }
        isSharing = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            presentActivity(image: img)
            isSharing = false
        }
    }

    private func presentActivity(image: UIImage) {
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let root = scene.windows.first?.rootViewController else { return }
        let ac = UIActivityViewController(activityItems: [image], applicationActivities: nil)
        var top: UIViewController = root
        while let presented = top.presentedViewController { top = presented }
        top.present(ac, animated: true)
    }
}
