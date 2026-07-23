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

    @State private var loadedImage: UIImage? = nil
    @State private var scale: CGFloat = 1.0
    @GestureState private var gestureScale: CGFloat = 1.0
    @State private var dragOffset: CGFloat = 0          // @State → spring-back çalışır
    @State private var isDismissing = false
    @State private var panOffset: CGSize = .zero
    @GestureState private var gesturePanOffset: CGSize = .zero

    private var backgroundOpacity: Double {
        isDismissing ? 0 : Double(max(0.15, 1.0 - dragOffset / 280))
    }

    var body: some View {
        let isZoomed = scale > 1.01
        let combinedScale = scale * gestureScale
        let combinedPanOffset = CGSize(
            width: panOffset.width + gesturePanOffset.width,
            height: panOffset.height + gesturePanOffset.height
        )

        return ZStack {
            Color.black.opacity(backgroundOpacity).ignoresSafeArea()
                .animation(.linear(duration: 0.01), value: dragOffset)

            if let uiImage = loadedImage {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .drawingGroup()
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
                                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                        withAnimation(.easeOut(duration: 0.28)) {
                                            dragOffset = UIScreen.main.bounds.height
                                            isDismissing = true
                                        }
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                                            isPresented = false
                                        }
                                    } else {
                                        withAnimation(.spring(response: 0.38, dampingFraction: 0.72)) {
                                            dragOffset = 0
                                        }
                                    }
                                }
                        )
                    )
                    .onTapGesture(count: 2) {
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

            VStack {
                HStack {
                    Button(action: {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        withAnimation(.easeOut(duration: 0.22)) {
                            dragOffset = UIScreen.main.bounds.height
                            isDismissing = true
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) { isPresented = false }
                    }) {
                        Image(systemName: "xmark")
                            .bodyLG().fontWeight(.semibold)
                            .foregroundColor(.white)
                            .frame(width: 44, height: 44)
                            .background(Circle().fill(Color.black.opacity(0.5))
                                .overlay(Circle().stroke(Color.white.opacity(0.2), lineWidth: 1)))
                    }
                    .padding(20)
                    .accessibilityLabel(NSLocalizedString("general.close", comment: ""))
                    .accessibilityHint(NSLocalizedString("accessibility.today.closeViewer", comment: "Fotoğraf görüntüleyiciyi kapat"))
                    Spacer()
                }
                Spacer()
                Image(systemName: "chevron.compact.down")
                    .displayMD().fontWeight(.light)
                    .foregroundColor(.white.opacity(isZoomed ? 0 : 0.3))
                    .padding(.bottom, 24)
                    .animation(ONEAnimation.micro, value: isZoomed)
                    .accessibilityHidden(true)
            }
            .offset(y: isZoomed ? 0 : dragOffset)
        }
        .ignoresSafeArea()
        .statusBarHidden(true)
        .task {
            if let data = try? Data(contentsOf: photoURL) {
                loadedImage = UIImage(data: data)
            }
        }
    }
}
