//
//  PhotoViewerSheet.swift
//  one
//
//  Tam ekran fotoğraf görüntüleyici. `TodayCompletedView.swift`'ten ayrıldı.
//  Enhanced with modern MagnifyGesture (iOS 17+) and @GestureState for auto-reset.
//

import SwiftUI

struct PhotoViewerSheet: View {
    let photoURL: URL
    @Binding var isPresented: Bool

    /// Root'tan gelen hero namespace — kaynak thumb ile morph için.
    @Environment(\.todayPhotoNamespace) private var envPhotoNS
    @Namespace private var localPhotoNS
    private var photoNS: Namespace.ID { envPhotoNS ?? localPhotoNS }

    @State private var loadedImage: UIImage? = nil
    @State private var scale: CGFloat = 1.0
    @GestureState private var gestureScale: CGFloat = 1.0
    @State private var dragOffset: CGFloat = 0
    @State private var panOffset: CGSize = .zero
    @GestureState private var gesturePanOffset: CGSize = .zero
    @State private var appeared = false

    private var backgroundOpacity: Double {
        Double(max(0.15, 1.0 - dragOffset / 320))
    }

    private var chromeOpacity: Double {
        // Sürükleme başlar başlamaz krom (X + chevron) siliniyor —
        // parmak fotoğrafla, göz kromla meşgul olmasın.
        let fade = 1.0 - min(1.0, dragOffset / 80)
        return appeared ? fade : 0
    }

    private func dismiss() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        withAnimation(.spring(response: 0.44, dampingFraction: 0.88)) {
            isPresented = false
        }
    }

    var body: some View {
        let isZoomed = scale > 1.01
        let combinedScale = scale * gestureScale
        let combinedPanOffset = CGSize(
            width: panOffset.width + gesturePanOffset.width,
            height: panOffset.height + gesturePanOffset.height
        )

        ZStack {
            // Arkaplan tüm ekranı doldursun — safe area dahil.
            Color.black.opacity(backgroundOpacity)
                .ignoresSafeArea()
                .animation(.linear(duration: 0.01), value: dragOffset)
                .onTapGesture { if !isZoomed { dismiss() } }

            // Fotoğraf: safe area'ya SAYGI. Böylece Dynamic Island altına
            // girmiyor, üstten/alttan taşmıyor.
            Group {
                if let uiImage = loadedImage {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .drawingGroup()
                        .matchedGeometryEffect(id: "todayPhoto", in: photoNS, isSource: true)
                        .scaleEffect(combinedScale)
                        .offset(
                            x: isZoomed ? combinedPanOffset.width : 0,
                            y: isZoomed ? combinedPanOffset.height : dragOffset
                        )
                        .gesture(
                            SimultaneousGesture(
                                MagnifyGesture(minimumScaleDelta: 0.01)
                                    .updating($gestureScale) { value, state, _ in
                                        state = value.magnification
                                    }
                                    .onEnded { value in
                                        scale = min(max(scale * value.magnification, 1.0), 5.0)
                                        if scale <= 1.0 {
                                            withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                                                scale = 1.0
                                                panOffset = .zero
                                            }
                                        }
                                    },
                                DragGesture(minimumDistance: 5)
                                    .updating($gesturePanOffset) { value, state, _ in
                                        if scale > 1.01 { state = value.translation }
                                    }
                                    .onChanged { value in
                                        guard scale <= 1.01 else { return }
                                        let dy = value.translation.height
                                        if dy > 0 { dragOffset = dy }
                                    }
                                    .onEnded { value in
                                        if scale > 1.01 {
                                            panOffset.width  += value.translation.width
                                            panOffset.height += value.translation.height
                                            return
                                        }
                                        let vel = value.velocity.height
                                        let dy  = value.translation.height
                                        let shouldDismiss = dy > 90 || (dy > 20 && vel > 600)
                                        if shouldDismiss {
                                            dismiss()
                                        } else {
                                            withAnimation(.spring(response: 0.38, dampingFraction: 0.72)) {
                                                dragOffset = 0
                                            }
                                        }
                                    }
                            )
                        )
                        .onTapGesture(count: 2) {
                            ONEHaptics.nudge()
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                                if isZoomed {
                                    scale = 1.0
                                    panOffset = .zero
                                } else {
                                    scale = 2.5
                                }
                            }
                        }
                        .accessibilityLabel(NSLocalizedString("accessibility.today.photoViewer", comment: "Fotoğraf görüntüleyici"))
                        .accessibilityHint(NSLocalizedString("accessibility.today.photoViewerHint", comment: "Yakınlaştırmak için çift dokunun, kapatmak için aşağı kaydırın"))
                } else {
                    ProgressView()
                        .tint(.white)
                        .accessibilityLabel(NSLocalizedString("accessibility.loading", comment: "Yükleniyor"))
                }
            }
            .padding(.horizontal, 0)
            .padding(.vertical, 12)
        }
        .overlay(alignment: .top) {
            // Kapatma butonu safe area İÇİNDE — Dynamic Island'a değmez.
            HStack {
                Button(action: dismiss) {
                    Image(systemName: "xmark")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 36, height: 36)
                        .background(
                            Circle()
                                .fill(.ultraThinMaterial)
                                .environment(\.colorScheme, .dark)
                        )
                        .overlay(
                            Circle().stroke(Color.white.opacity(0.18), lineWidth: 1)
                        )
                }
                .accessibilityLabel(NSLocalizedString("general.close", comment: ""))
                .accessibilityHint(NSLocalizedString("accessibility.today.closeViewer", comment: "Fotoğraf görüntüleyiciyi kapat"))
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .opacity(chromeOpacity)
        }
        .overlay(alignment: .bottom) {
            Image(systemName: "chevron.compact.down")
                .font(.system(size: 34, weight: .light))
                .foregroundColor(.white.opacity(isZoomed ? 0 : 0.32))
                .padding(.bottom, 8)
                .opacity(chromeOpacity)
                .accessibilityHidden(true)
        }
        .statusBarHidden(true)
        .task {
            if let data = try? Data(contentsOf: photoURL) {
                loadedImage = UIImage(data: data)
            }
            withAnimation(.easeOut(duration: 0.25)) { appeared = true }
        }
    }
}
