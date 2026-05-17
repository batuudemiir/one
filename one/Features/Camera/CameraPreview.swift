//
//  CameraPreview.swift
//  one
//
//  Photo preview: UIScrollView-based zoom, dismiss gesture, and SwiftUI overlay.
//  Extracted from CameraView.swift as part of Faz 3 decomposition.
//

import SwiftUI
import UIKit

// MARK: - PhotoPreviewContainer (UIKit)
// UIScrollView-based zoom: pinch anchor = finger midpoint, pan clamped to content bounds.
// Dismiss gesture lives on the parent view so it never fights the scroll pan recognizer.

final class PhotoPreviewContainer: UIView {
    let scrollView = UIScrollView()
    private let imageView  = UIImageView()
    private let dismissPan = UIPanGestureRecognizer()
    // Prevents re-initialising layout after first setup (e.g. during zoom delegate calls)
    private var didInitLayout = false

    var onZoomChanged:      ((Bool)    -> Void)?
    var onDismissProgress:  ((CGFloat) -> Void)?   // 0…1 while dragging
    var onDismissFired:     (() -> Void)?
    var onDismissCancelled: (() -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear

        // ScrollView — minimumZoomScale will be set in layoutSubviews once we know the image size
        scrollView.delegate   = self
        scrollView.minimumZoomScale = 1.0
        scrollView.maximumZoomScale = 6.0
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.showsVerticalScrollIndicator   = false
        scrollView.contentInsetAdjustmentBehavior = .never
        scrollView.bouncesZoom  = true
        scrollView.bounces      = false
        scrollView.backgroundColor = .clear
        addSubview(scrollView)

        imageView.contentMode = .scaleAspectFill
        scrollView.addSubview(imageView)

        // Double-tap: zoom 2.5× to tap point, or reset to fill level
        let dt = UITapGestureRecognizer(target: self, action: #selector(handleDoubleTap(_:)))
        dt.numberOfTapsRequired = 2
        scrollView.addGestureRecognizer(dt)

        // Dismiss pan on this (parent) view — never conflicts with scroll pan
        dismissPan.addTarget(self, action: #selector(handleDismissPan(_:)))
        dismissPan.delegate = self
        addGestureRecognizer(dismissPan)
    }
    required init?(coder: NSCoder) { fatalError() }

    func setImage(_ image: UIImage) {
        didInitLayout = false
        imageView.image = image
        setNeedsLayout()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        scrollView.frame = bounds
        guard let img = imageView.image,
              bounds.width > 0, bounds.height > 0,
              !didInitLayout else { return }
        didInitLayout = true

        let imgSize  = img.size
        let viewSize = bounds.size

        // Fill size: same gravity as AVCaptureVideoPreviewLayer.resizeAspectFill.
        // This makes the default zoom level exactly match what the user saw in the viewfinder.
        let fillScale = max(viewSize.width / imgSize.width, viewSize.height / imgSize.height)
        let fillSize  = CGSize(width:  imgSize.width  * fillScale,
                               height: imgSize.height * fillScale)

        // Minimum zoom: let the user pinch-out to see the full frame (fit level).
        let minZoom = min(viewSize.width  / fillSize.width,
                         viewSize.height / fillSize.height)
        scrollView.minimumZoomScale = minZoom
        scrollView.maximumZoomScale = 6.0

        scrollView.contentSize = fillSize
        imageView.frame        = CGRect(origin: .zero, size: fillSize)

        // Start at fill (zoomScale = 1.0) to match the live preview, centred.
        scrollView.contentInset = .zero
        scrollView.zoomScale = 1.0
        let cx = (fillSize.width  - viewSize.width)  / 2
        let cy = (fillSize.height - viewSize.height) / 2
        scrollView.contentOffset = CGPoint(x: max(0, cx), y: max(0, cy))
    }

    private func centerContent() {
        // Called by scrollViewDidZoom — keeps image centred when smaller than the viewport.
        // Uses contentInset (not imageView.center) so UIScrollView's pinch-anchor math stays intact.
        let ox = max((scrollView.bounds.width  - scrollView.contentSize.width)  / 2, 0)
        let oy = max((scrollView.bounds.height - scrollView.contentSize.height) / 2, 0)
        scrollView.contentInset = UIEdgeInsets(top: oy, left: ox, bottom: oy, right: ox)
    }

    @objc private func handleDoubleTap(_ gr: UITapGestureRecognizer) {
        if scrollView.zoomScale > 1.02 {
            // Zoomed in → reset to fill level (matching viewfinder)
            scrollView.setZoomScale(1.0, animated: true)
        } else {
            // At fill or fit level → zoom 2.5× to tap point
            let pt = gr.location(in: imageView)
            let s: CGFloat = 2.5
            let sz = CGSize(width:  scrollView.bounds.width  / s,
                            height: scrollView.bounds.height / s)
            scrollView.zoom(to: CGRect(x: pt.x - sz.width / 2,
                                       y: pt.y - sz.height / 2,
                                       width: sz.width, height: sz.height),
                            animated: true)
        }
    }

    @objc private func handleDismissPan(_ gr: UIPanGestureRecognizer) {
        let dy       = max(0, gr.translation(in: self).y)
        let progress = min(dy / 280.0, 1.0)
        switch gr.state {
        case .changed:
            scrollView.transform = CGAffineTransform(translationX: 0, y: dy)
            onDismissProgress?(progress)
        case .ended:
            let vy = gr.velocity(in: self).y
            if dy > 90 || (dy > 30 && vy > 400) {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                let screenH = UIScreen.main.bounds.height
                UIView.animate(withDuration: 0.22, delay: 0, options: .curveEaseOut) {
                    self.scrollView.transform = CGAffineTransform(translationX: 0, y: screenH)
                }
                onDismissFired?()
            } else {
                UIView.animate(withDuration: 0.3, delay: 0,
                               usingSpringWithDamping: 0.76, initialSpringVelocity: 0,
                               options: []) { self.scrollView.transform = .identity }
                onDismissCancelled?()
            }
        case .cancelled, .failed:
            UIView.animate(withDuration: 0.3) { self.scrollView.transform = .identity }
            onDismissCancelled?()
        default: break
        }
    }
}

extension PhotoPreviewContainer: UIScrollViewDelegate {
    func viewForZooming(in scrollView: UIScrollView) -> UIView? { imageView }
    func scrollViewDidZoom(_ scrollView: UIScrollView) {
        centerContent()
        onZoomChanged?(scrollView.zoomScale > 1.02)
    }
}

extension PhotoPreviewContainer: UIGestureRecognizerDelegate {
    /// Only begin dismiss pan when not zoomed and clearly dragging downward.
    override func gestureRecognizerShouldBegin(_ gr: UIGestureRecognizer) -> Bool {
        guard gr === dismissPan else { return super.gestureRecognizerShouldBegin(gr) }
        guard scrollView.zoomScale <= 1.02 else { return false }
        let vel = dismissPan.velocity(in: self)
        return vel.y > 80 && abs(vel.y) > abs(vel.x) * 1.2
    }
    func gestureRecognizer(_ gr: UIGestureRecognizer,
                           shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool { false }
}

// MARK: - ZoomablePhotoView (UIViewRepresentable)

struct ZoomablePhotoView: UIViewRepresentable {
    let image:              UIImage
    let onZoomChanged:      (Bool)    -> Void
    let onDismissProgress:  (CGFloat) -> Void
    let onDismissFired:     () -> Void
    let onDismissCancelled: () -> Void

    func makeUIView(context: Context) -> PhotoPreviewContainer {
        let v = PhotoPreviewContainer()
        v.setImage(image)
        v.onZoomChanged      = { z  in DispatchQueue.main.async { onZoomChanged(z) } }
        v.onDismissProgress  = { p  in DispatchQueue.main.async { onDismissProgress(p) } }
        v.onDismissFired     = {       DispatchQueue.main.async { onDismissFired() } }
        v.onDismissCancelled = {       DispatchQueue.main.async { onDismissCancelled() } }
        return v
    }
    func updateUIView(_ v: PhotoPreviewContainer, context: Context) {}
}

// MARK: - CameraPreviewOverlay
// Full-screen photo preview backed by UIScrollView for native zoom-to-finger and clamped pan.

struct CameraPreviewOverlay: View {
    let image: UIImage
    let safeTop: CGFloat
    let safeBottom: CGFloat
    let onRetake: () -> Void
    let onUse: () -> Void

    @State private var isZoomed:  Bool   = false
    @State private var bgOpacity: Double = 1.0

    var body: some View {
        ZStack {
            // As bgOpacity → 0 the live camera feed (zIndex 1 in CameraView) shows through.
            Color.black.opacity(bgOpacity).ignoresSafeArea()

            ZoomablePhotoView(
                image: image,
                onZoomChanged: { z in
                    withAnimation(.easeInOut(duration: 0.15)) { isZoomed = z }
                },
                onDismissProgress: { prog in
                    // Only fade the black bg — UIKit pan gesture owns the physical movement.
                    bgOpacity = Double(max(0.05, 1.0 - prog))
                },
                onDismissFired: {
                    withAnimation(.easeOut(duration: 0.18)) { bgOpacity = 0 }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.20) { onRetake() }
                },
                onDismissCancelled: {
                    withAnimation(.spring(response: 0.38, dampingFraction: 0.72)) { bgOpacity = 1.0 }
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: 44, style: .continuous))
            .ignoresSafeArea()

            // Gradient overlays
            VStack(spacing: 0) {
                LinearGradient(colors: [.black.opacity(0.65), .clear], startPoint: .top, endPoint: .bottom)
                    .frame(height: safeTop + 100)
                Spacer()
                LinearGradient(colors: [.clear, .black.opacity(0.82)], startPoint: .top, endPoint: .bottom)
                    .frame(height: safeBottom + 180)
            }
            .allowsHitTesting(false)
            .opacity(bgOpacity)

            // Buttons — hidden while zoomed so they don't clutter
            if !isZoomed {
                VStack {
                    HStack {
                        previewBtn(sf: "xmark", sz: 13) { onRetake() }
                        Spacer()
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, safeTop + 10)

                    // Swipe-down hint
                    Image(systemName: "chevron.compact.down")
                        .font(.system(size: 22, weight: .light))
                        .foregroundColor(.white.opacity(0.28))
                        .padding(.top, 4)

                    Spacer()

                    VStack(spacing: 8) {
                        Text("Bu anı güzel yakaladın!")
                            .displayMD()
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        Text("Bu fotoğrafı anıların arasına eklemek ister misin?")
                            .bodySM()
                            .fontWeight(.medium)
                            .foregroundColor(.white.opacity(0.75))
                            .multilineTextAlignment(.center)
                    }
                    .padding(.bottom, 20)

                    HStack(spacing: 10) {
                        Button { onRetake() } label: {
                            Text(NSLocalizedString("camera.retake", comment: ""))
                                .bodyMD()
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity).padding(.vertical, 14)
                                .liquidGlass(in: Capsule())
                        }
                        .accessibilityLabel(NSLocalizedString("camera.retake", comment: ""))
                        Button { onUse() } label: {
                            Text(NSLocalizedString("camera.use", comment: ""))
                                .bodyMD()
                                .fontWeight(.semibold)
                                .foregroundColor(.black)
                                .frame(maxWidth: .infinity).padding(.vertical, 14)
                                .background(Capsule().fill(.white))
                        }
                        .accessibilityLabel(NSLocalizedString("camera.use", comment: ""))
                    }
                    .padding(.horizontal, 22)
                    .padding(.bottom, safeBottom + 28)
                }
                .transition(.opacity)
                .animation(.easeInOut(duration: 0.15), value: isZoomed)
            }
        }
        .statusBarHidden(true)
    }

    private func previewBtn(sf: String, sz: CGFloat, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: sf)
                .font(.system(size: sz, weight: .semibold)).foregroundColor(.white)
                .frame(width: 40, height: 40)
                .liquidGlass(in: Circle())
        }
    }
}
