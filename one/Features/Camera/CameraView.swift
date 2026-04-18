//
//  CameraView.swift
//  one
//
//  Native iPhone camera — clean rewrite v4
//  • CameraState: plain ObservableObject (no @MainActor, no Task overhead)
//  • CameraVC: all AVFoundation on sq queue, UI updates via DispatchQueue.main.async
//  • Safe area: read from UIWindowScene (bulletproof, no GeometryReader tricks)
//  • SwiftUI overlay sits in ZStack above UIViewControllerRepresentable
//  • CoreMotion at 10 fps — no excessive re-renders
//

import SwiftUI
import AVFoundation
import UIKit
import MediaPlayer
import CoreMotion
import Combine

// MARK: - Support types

enum CaptureRatio: String, CaseIterable {
    case story    = "9:16"
    case standard = "4:3"
    case square   = "1:1"
    var wh: CGFloat {
        switch self {
        case .story:    return 9.0 / 16.0
        case .standard: return 3.0 / 4.0
        case .square:   return 1.0
        }
    }
}

enum CameraFlash: Int, CaseIterable {
    case off, auto, on
    var next: CameraFlash { CameraFlash(rawValue: (rawValue + 1) % 3) ?? .off }
    var icon: String {
        switch self {
        case .off:  return "bolt.slash.fill"
        case .auto: return "bolt.badge.a.fill"
        case .on:   return "bolt.fill"
        }
    }
    var avMode: AVCaptureDevice.FlashMode {
        switch self { case .off: return .off; case .auto: return .auto; case .on: return .on }
    }
    var isActive: Bool { self != .off }
}

enum CaptureDelayMode: Int, CaseIterable {
    case off, three, ten
    var next: CaptureDelayMode { CaptureDelayMode(rawValue: (rawValue + 1) % 3) ?? .off }
    var seconds: Int { switch self { case .off: return 0; case .three: return 3; case .ten: return 10 } }
    var badge: String? { switch self { case .off: return nil; case .three: return "3"; case .ten: return "10" } }
    var isActive: Bool { self != .off }
}

private enum PermState { case checking, authorized, denied }

// MARK: - Film Presets

enum FilmPreset: String, CaseIterable {
    case normal = "Normal"
    case kodak  = "Kodak"
    case fuji   = "Fuji"
    case dispo  = "Dispo"
    case bw     = "B&W"
    case fade   = "Soluk"

    struct Params {
        var saturation:  Float  = 1.0
        var brightness:  Float  = 0.0
        var contrast:    Float  = 1.0
        var temperature: Double = 6500   // Kelvin
        var vignette:    Float  = 0.0
        var grain:       Float  = 0.0    // 0–1
    }

    var params: Params {
        switch self {
        case .normal: return Params()
        case .kodak:  return Params(saturation: 1.08, brightness:  0.04, contrast: 0.94, temperature: 7000, vignette: 0.45, grain: 0.06)
        case .fuji:   return Params(saturation: 0.88, brightness: -0.02, contrast: 1.06, temperature: 6200, vignette: 0.30, grain: 0.04)
        case .dispo:  return Params(saturation: 0.82, brightness:  0.06, contrast: 0.86, temperature: 7400, vignette: 0.72, grain: 0.14)
        case .bw:     return Params(saturation: 0.0,  brightness:  0.00, contrast: 1.10, temperature: 6500, vignette: 0.50, grain: 0.09)
        case .fade:   return Params(saturation: 0.68, brightness:  0.08, contrast: 0.78, temperature: 6800, vignette: 0.22, grain: 0.05)
        }
    }

    // Preview overlay intensities (lighter than photo processing)
    var previewVignette:    Double { Double(params.vignette) * 0.55 }
    var previewGrain:       Double { Double(params.grain) * 1.8   }
    // Live camera modifiers — applied via SwiftUI compositing to the UIKit preview layer
    var previewSaturation:  Double { Double(params.saturation) }
    var previewContrast:    Double { Double(params.contrast) }
    var previewBrightness:  Double { Double(params.brightness) }
}

// MARK: - CameraState  (plain ObservableObject — no @MainActor, updates always on main thread)

final class CameraState: ObservableObject {
    @Published var flash:     CameraFlash      = .off
    @Published var delay:     CaptureDelayMode
    @Published var grid:      Bool
    @Published var zoom:       CGFloat          = 1.0
    @Published var minZoom:    CGFloat          = 1.0
    @Published var maxZoom:    CGFloat          = 12.0
    /// Actual AVFoundation zoom factors + display labels for each lens (0.5×, 1×, 3× …)
    @Published var lensPresets: [(factor: CGFloat, label: String)] = [(1.0, "1×")]
    @Published var isLocked:  Bool             = false
    @Published var exposure:  Float            = 0
    @Published var minExp:    Float            = -2
    @Published var maxExp:    Float            = 2
    @Published var showExp:   Bool             = false
    @Published var counting:  Bool             = false
    @Published var capturing: Bool             = false
    @Published var pinching:  Bool             = false
    @Published var isFront:   Bool             = false
    @Published var flashOK:            Bool             = false
    /// Shutter disabled briefly after returning from preview (prevents accidental re-shoot)
    @Published var isInRetakeCooldown: Bool             = false
    @Published var pitch:     Double           = 0
    @Published var focusPt:   CGPoint?         = nil   // screen-space tap point for exposure handle

    // Commands wired up by CameraVC
    var onShoot:    (() -> Void)?
    var onFlip:     (() -> Void)?
    var onSetZoom:  ((CGFloat) -> Void)?
    var onSetExp:   ((Float) -> Void)?

    private let ud = UserDefaults.standard

    init() {
        delay = CaptureDelayMode(rawValue: ud.integer(forKey: "cam.delay")) ?? .off
        grid  = ud.object(forKey: "cam.grid") != nil ? ud.bool(forKey: "cam.grid") : false
    }

    // Called from SwiftUI buttons — always on main thread
    func cycleFlash()  { flash = flash.next; ud.set(flash.rawValue, forKey: "cam.flash"); haptic(.light) }
    func cycleDelay()  { delay = delay.next; ud.set(delay.rawValue, forKey: "cam.delay"); haptic(.light) }
    func toggleGrid()  { grid.toggle(); ud.set(grid, forKey: "cam.grid"); haptic(.light) }
    func shoot()       { haptic(.heavy); onShoot?() }
    func flip()        { haptic(.medium); onFlip?() }
    func zoomPreset(_ f: CGFloat) { haptic(.light); onSetZoom?(f) }
    func adjustExp(_ v: Float)    { onSetExp?(v) }

    private func haptic(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        UIImpactFeedbackGenerator(style: style).impactOccurred()
    }
}

// MARK: - CameraView (SwiftUI root)

struct CameraView: View {
    @Binding var image: UIImage?
    @Environment(\.dismiss) private var dismiss

    @StateObject private var state   = CameraState()
    @State private var perm:   PermState    = .checking
    @State private var ratio:  CaptureRatio = .standard
    @State private var captured: UIImage?   = nil
    @State private var showPreview          = false
    @State private var cameraKey            = UUID()
    @State private var safeTop:    CGFloat  = 0
    @State private var safeBottom: CGFloat  = 0
    @State private var filmPreset: FilmPreset = .normal

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            content
        }
        .ignoresSafeArea()
        .statusBarHidden(true)
        .onAppear {
            readSafeArea()
            checkPerm()
        }
    }

    @ViewBuilder
    private var content: some View {
        switch perm {
        case .authorized:
            // Keep liveScreen always in the hierarchy so CameraVC is never destroyed.
            // Destroying it on preview would recreate AVFoundation session on retake,
            // resetting zoom to default (visible as a zoom-out on front camera).
            ZStack {
                liveScreen
                    .zIndex(1)
                if showPreview, let img = captured {
                    previewScreen(img)
                        .transition(.opacity)
                        .zIndex(2)
                }
            }
        case .checking:
            ProgressView().tint(.white)
        case .denied:
            deniedScreen
        }
    }

    // MARK: Live camera screen

    private var liveScreen: some View {
        ZStack {
            LivePreviewView(
                state:     state,
                ratio:     ratio,
                onPhoto:   handleCapture,
                onDismiss: { dismiss() }
            )
            .id(cameraKey)
            .ignoresSafeArea()
            .saturation(filmPreset.previewSaturation)
            .contrast(filmPreset.previewContrast)
            .brightness(filmPreset.previewBrightness)
            .animation(.easeInOut(duration: 0.22), value: filmPreset)

            CameraOverlay(
                state:      state,
                ratio:      $ratio,
                film:       $filmPreset,
                safeTop:    safeTop,
                safeBottom: safeBottom,
                onDismiss:  { dismiss() }
            )
            .ignoresSafeArea()
        }
        // Swipe-to-dismiss kaldırıldı — ışık ayarı drag gesture ile çakışıyordu.
        // Çıkmak için sol üst köşedeki X butonunu kullan.
    }

    // MARK: Photo preview screen

    @ViewBuilder
    private func previewScreen(_ raw: UIImage) -> some View {
        let img = cropImage(raw, to: ratio)
        CameraPreviewOverlay(
            image: img,
            safeTop: safeTop,
            safeBottom: safeBottom,
            onRetake: { retake() },
            onUse: {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                image = img; dismiss()
            }
        )
    }

    // MARK: Permission denied screen

    private var deniedScreen: some View {
        VStack(spacing: 18) {
            Image(systemName: "camera.slash.fill")
                .font(.system(size: 44)).foregroundColor(.white)
            Text(NSLocalizedString("camera.permissionTitle", comment: ""))
                .font(.system(size: 19, weight: .semibold)).foregroundColor(.white)
            Text(NSLocalizedString("camera.permissionMessage", comment: ""))
                .font(.system(size: 14)).foregroundColor(.white.opacity(0.75))
                .multilineTextAlignment(.center)
            Button {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            } label: {
                Text(NSLocalizedString("camera.openSettings", comment: ""))
                    .font(.system(size: 15, weight: .semibold)).foregroundColor(.black)
                    .padding(.horizontal, 22).padding(.vertical, 12)
                    .background(Capsule().fill(.white))
            }
            Button { dismiss() } label: {
                Text(NSLocalizedString("camera.cancel", comment: ""))
                    .font(.system(size: 14)).foregroundColor(.white.opacity(0.7))
            }
        }.padding(.horizontal, 32)
    }

    // MARK: Helpers

    /// Read safe area from UIWindowScene — 100% reliable for Dynamic Island
    private func readSafeArea() {
        guard let scene  = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = scene.windows.first(where: { $0.isKeyWindow }) ?? scene.windows.first
        else { return }
        safeTop    = window.safeAreaInsets.top
        safeBottom = window.safeAreaInsets.bottom
    }

    private func checkPerm() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            perm = .authorized
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { ok in
                DispatchQueue.main.async { perm = ok ? .authorized : .denied }
            }
        default:
            perm = .denied
        }
    }

    private func handleCapture(_ raw: UIImage) {
        let preset = filmPreset
        DispatchQueue.global(qos: .userInitiated).async {
            let processed = applyFilmToPhoto(raw, preset: preset)
            DispatchQueue.main.async {
                captured = processed
                withAnimation(.spring(response: 0.34, dampingFraction: 0.8)) { showPreview = true }
            }
        }
    }

    // CIFilter chain applied to captured photo
    private func applyFilmToPhoto(_ img: UIImage, preset: FilmPreset) -> UIImage {
        guard preset != .normal else { return img }
        guard let ciImg = CIImage(image: img) else { return img }
        let p = preset.params
        let ctx = CIContext(options: [.useSoftwareRenderer: false])
        var out = ciImg

        // 1. Color controls (saturation / brightness / contrast)
        if let f = CIFilter(name: "CIColorControls") {
            f.setValue(out, forKey: kCIInputImageKey)
            f.setValue(p.saturation, forKey: kCIInputSaturationKey)
            f.setValue(p.brightness, forKey: kCIInputBrightnessKey)
            f.setValue(p.contrast,   forKey: kCIInputContrastKey)
            if let o = f.outputImage { out = o }
        }

        // 2. Temperature & tint
        if let f = CIFilter(name: "CITemperatureAndTint") {
            f.setValue(out, forKey: kCIInputImageKey)
            f.setValue(CIVector(x: p.temperature, y: 0), forKey: "inputNeutral")
            f.setValue(CIVector(x: 6500,          y: 0), forKey: "inputTargetNeutral")
            if let o = f.outputImage { out = o }
        }

        // 3. Vignette
        if p.vignette > 0, let f = CIFilter(name: "CIVignette") {
            f.setValue(out, forKey: kCIInputImageKey)
            f.setValue(p.vignette, forKey: kCIInputIntensityKey)
            f.setValue(Float(1.4), forKey: kCIInputRadiusKey)
            if let o = f.outputImage { out = o }
        }

        // 4. Grain (noise composite)
        if p.grain > 0,
           let noise = CIFilter(name: "CIRandomGenerator")?.outputImage {
            let cropped = noise.cropped(to: ciImg.extent)
            // Desaturate and reduce opacity of noise
            if let mono = CIFilter(name: "CIColorMatrix",
                                   parameters: [kCIInputImageKey: cropped,
                                                "inputRVector": CIVector(x: CGFloat(p.grain), y: 0, z: 0, w: 0),
                                                "inputGVector": CIVector(x: 0, y: CGFloat(p.grain), z: 0, w: 0),
                                                "inputBVector": CIVector(x: 0, y: 0, z: CGFloat(p.grain), w: 0),
                                                "inputAVector": CIVector(x: 0, y: 0, z: 0, w: 0.18)]),
               let monoOut = mono.outputImage,
               let blend   = CIFilter(name: "CIScreenBlendMode",
                                      parameters: [kCIInputImageKey: monoOut,
                                                   kCIInputBackgroundImageKey: out]),
               let blended = blend.outputImage {
                out = blended
            }
        }

        guard let cg = ctx.createCGImage(out, from: ciImg.extent) else { return img }
        return UIImage(cgImage: cg, scale: img.scale, orientation: img.imageOrientation)
    }

    private func retake() {
        UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
        state.capturing = false
        state.isInRetakeCooldown = true   // Block shutter briefly to prevent accidental re-shoot
        withAnimation(.easeInOut(duration: 0.16)) { showPreview = false }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.17) {
            self.captured = nil
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) {
            self.state.isInRetakeCooldown = false
        }
    }

    private func cropImage(_ img: UIImage, to ratio: CaptureRatio) -> UIImage {
        let w = img.size.width, h = img.size.height
        guard w > 0, h > 0 else { return img }
        let targetRatio = (h >= w) ? ratio.wh : (1.0 / ratio.wh)
        let current = w / h
        guard abs(current - targetRatio) > 0.005 else { return img }
        let rect: CGRect
        if current > targetRatio {
            let cw = h * targetRatio
            rect = CGRect(x: (w - cw) / 2, y: 0, width: cw, height: h)
        } else {
            let ch = w / targetRatio
            rect = CGRect(x: 0, y: (h - ch) / 2, width: w, height: ch)
        }
        let s = img.scale
        guard let cg = img.cgImage?.cropping(to: rect.applying(.init(scaleX: s, y: s))) else { return img }
        return UIImage(cgImage: cg, scale: s, orientation: img.imageOrientation)
    }

}

// MARK: - PhotoPreviewContainer (UIKit)
// UIScrollView-based zoom: pinch anchor = finger midpoint, pan clamped to content bounds.
// Dismiss gesture lives on the parent view so it never fights the scroll pan recognizer.

private final class PhotoPreviewContainer: UIView {
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
        scrollView.zoomScale = 1.0
        let cx = (fillSize.width  - viewSize.width)  / 2
        let cy = (fillSize.height - viewSize.height) / 2
        scrollView.contentOffset = CGPoint(x: max(0, cx), y: max(0, cy))
    }

    private func centerContent() {
        // Called by scrollViewDidZoom — keeps image centred when smaller than the viewport
        // (i.e. when user zooms out to fit level).
        let ox = max((scrollView.bounds.width  - scrollView.contentSize.width)  / 2, 0)
        let oy = max((scrollView.bounds.height - scrollView.contentSize.height) / 2, 0)
        imageView.center = CGPoint(
            x: scrollView.contentSize.width  / 2 + ox,
            y: scrollView.contentSize.height / 2 + oy
        )
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

private struct ZoomablePhotoView: UIViewRepresentable {
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

private struct CameraPreviewOverlay: View {
    let image: UIImage
    let safeTop: CGFloat
    let safeBottom: CGFloat
    let onRetake: () -> Void
    let onUse: () -> Void

    @State private var isZoomed:  Bool   = false
    @State private var bgOpacity: Double = 1.0

    var body: some View {
        ZStack {
            Color.black.opacity(bgOpacity).ignoresSafeArea()

            ZoomablePhotoView(
                image: image,
                onZoomChanged: { z in
                    withAnimation(.easeInOut(duration: 0.15)) { isZoomed = z }
                },
                onDismissProgress: { prog in
                    bgOpacity = Double(max(0.25, 1.0 - prog))
                },
                onDismissFired: {
                    withAnimation(.easeOut(duration: 0.18)) { bgOpacity = 0 }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { onRetake() }
                },
                onDismissCancelled: {
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.76)) { bgOpacity = 1.0 }
                }
            )
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

                    HStack(spacing: 10) {
                        Button { onRetake() } label: {
                            Text(NSLocalizedString("camera.retake", comment: ""))
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity).padding(.vertical, 14)
                                .background(Capsule().fill(.ultraThinMaterial)
                                    .overlay(Capsule().stroke(.white.opacity(0.25), lineWidth: 1)))
                        }
                        Button { onUse() } label: {
                            Text(NSLocalizedString("camera.use", comment: ""))
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(.black)
                                .frame(maxWidth: .infinity).padding(.vertical, 14)
                                .background(Capsule().fill(.white))
                        }
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
                .background(Circle().fill(.ultraThinMaterial)
                    .overlay(Circle().stroke(.white.opacity(0.2), lineWidth: 1)))
        }
    }
}

// MARK: - LivePreviewView (UIViewControllerRepresentable)

private struct LivePreviewView: UIViewControllerRepresentable {
    let state:     CameraState
    let ratio:     CaptureRatio
    let onPhoto:   (UIImage) -> Void
    let onDismiss: () -> Void

    func makeUIViewController(context: Context) -> CameraVC {
        let vc        = CameraVC(state: state)
        vc.onPhoto    = onPhoto
        vc.onDismiss  = onDismiss
        return vc
    }
    func updateUIViewController(_ vc: CameraVC, context: Context) {
        vc.currentRatio = ratio
        vc.onPhoto      = onPhoto   // keep closure fresh so filmPreset is always current
    }
}

// MARK: - CameraVC

final class CameraVC: UIViewController {

    // Deps
    private unowned let camState: CameraState
    var onPhoto:   ((UIImage) -> Void)?
    var onDismiss: (() -> Void)?
    var currentRatio: CaptureRatio = .standard

    // AVFoundation
    private let session   = AVCaptureSession()
    private let photoOut  = AVCapturePhotoOutput()
    private var devInput: AVCaptureDeviceInput?
    private var previewLayer: AVCaptureVideoPreviewLayer!
    private var camPos: AVCaptureDevice.Position = .back

    // Session queue — ALL AVFoundation work goes here
    private let sq = DispatchQueue(label: "one.cam", qos: .userInitiated)

    // Local mirrors (accessed only on sq or main as noted)
    private var currentZoom:  CGFloat = 1.0
    private var baseZoom:     CGFloat = 1.0
    private var localMinZoom: CGFloat = 1.0
    private var localMaxZoom: CGFloat = 12.0
    private var localFlash:   CameraFlash = .off   // mirror of state.flash, read on sq

    // State flags (main thread only)
    private var isLocked        = false
    private var isCounting      = false
    private var isCapturing     = false
    /// Prevents volume-button auto-shoot briefly after retake/viewWillAppear
    private var volShutterCooldown = false

    // UIKit overlays
    private var focusView:   UIView?
    private var focusItem:   DispatchWorkItem?
    private var expHideItem: DispatchWorkItem?
    private var cdTimer:     Timer?
    private var cdLabel:     UILabel?
    private var volView:     MPVolumeView?
    private var volObs:      NSKeyValueObservation?
    private var lastVol:     Float = 0.5

    // CoreMotion
    private let motion = CMMotionManager()

    init(state: CameraState) {
        camState = state
        super.init(nibName: nil, bundle: nil)
    }
    @available(*, unavailable) required init?(coder: NSCoder) { fatalError() }

    // MARK: Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        setupPreviewLayer()
        setupGestures()
        setupVolumeShutter()
        wireStateCommands()
        sq.async { [weak self] in self?.setupSession() }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer.frame = view.bounds
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        sq.async { [weak self] in
            guard let s = self, !s.session.isRunning else { return }
            s.session.startRunning()
        }
        startVolumeObserver()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        startMotion()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        sq.async { [weak self] in self?.session.stopRunning() }
        stopMotion()
        cancelCountdown(haptic: false)
        stopVolumeObserver()
    }

    // MARK: Wire commands  (CameraState → CameraVC)

    private func wireStateCommands() {
        camState.onShoot   = { [weak self] in self?.triggerShoot() }
        camState.onFlip    = { [weak self] in self?.flipCamera() }
        camState.onSetZoom = { [weak self] f in self?.rampZoom(to: f) }
        camState.onSetExp  = { [weak self] v in self?.setExposure(v) }
    }

    // MARK: Preview layer

    private func setupPreviewLayer() {
        previewLayer              = AVCaptureVideoPreviewLayer()
        previewLayer.videoGravity = .resizeAspectFill
        previewLayer.frame        = view.bounds
        view.layer.insertSublayer(previewLayer, at: 0)
    }

    // MARK: Session setup (runs on sq)

    private func setupSession() {
        session.beginConfiguration()
        session.sessionPreset = .photo

        if let dev = bestDevice(pos: .back),
           let inp = try? AVCaptureDeviceInput(device: dev),
           session.canAddInput(inp) {
            session.addInput(inp); devInput = inp
            updateZoomBounds(dev)
            updateExpBounds(dev)
        }
        if session.canAddOutput(photoOut) {
            session.addOutput(photoOut)
            if let dev = devInput?.device,
               let dim = dev.activeFormat.supportedMaxPhotoDimensions.last {
                photoOut.maxPhotoDimensions = dim
            }
        }
        session.commitConfiguration()
        session.startRunning()

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.previewLayer.session = self.session
            self.fixOrientation()
            self.camState.flashOK = (self.devInput?.device.hasFlash ?? false)
            self.camState.isFront = false
        }
    }

    private func bestDevice(pos: AVCaptureDevice.Position) -> AVCaptureDevice? {
        let backTypes: [AVCaptureDevice.DeviceType] = [
            .builtInTripleCamera, .builtInDualWideCamera, .builtInDualCamera, .builtInWideAngleCamera
        ]
        let frontTypes: [AVCaptureDevice.DeviceType] = [
            .builtInTrueDepthCamera, .builtInWideAngleCamera
        ]
        return AVCaptureDevice.DiscoverySession(
            deviceTypes: pos == .back ? backTypes : frontTypes,
            mediaType: .video, position: pos
        ).devices.first
    }

    private func updateZoomBounds(_ dev: AVCaptureDevice) {
        let mn = dev.minAvailableVideoZoomFactor
        let mx = min(dev.maxAvailableVideoZoomFactor, 15.0)
        let switchFactors = dev.virtualDeviceSwitchOverVideoZoomFactors.map { CGFloat($0.doubleValue) }

        // Start at the wide (1×) lens if available, otherwise at min
        let startZoom: CGFloat = switchFactors.first ?? mn
        let z = startZoom.clamped(to: mn...mx)
        localMinZoom = mn; localMaxZoom = mx; currentZoom = z; baseZoom = z
        try? dev.lockForConfiguration()
        dev.videoZoomFactor = z
        dev.unlockForConfiguration()

        let presets = buildLensPresets(min: mn, max: mx, switchFactors: switchFactors)
        DispatchQueue.main.async { [weak self] in
            guard let s = self else { return }
            s.camState.minZoom = mn; s.camState.maxZoom = mx; s.camState.zoom = z
            s.camState.lensPresets = presets
        }
    }

    /// Maps physical camera lenses to (AVFoundation zoom factor, display label) pairs.
    private func buildLensPresets(min: CGFloat, max: CGFloat, switchFactors: [CGFloat]) -> [(factor: CGFloat, label: String)] {
        guard !switchFactors.isEmpty else {
            // Single-lens device: only digital zoom from 1×
            var result: [(CGFloat, String)] = [(min, "1×")]
            if max >= min * 2 { result.append((min * 2, "2×")) }
            return result
        }

        var result: [(CGFloat, String)] = []

        // Ultra-wide lens = minAvailableVideoZoomFactor → shows as 0.5×
        result.append((min, "0.5×"))

        // Main (wide) lens = first switch factor → shows as 1×
        let wideZoom = switchFactors[0]
        result.append((wideZoom, "1×"))

        // Telephoto lens = second switch factor (if present)
        if switchFactors.count >= 2 {
            let teleZoom = switchFactors[1]
            let ratio = (teleZoom / wideZoom).rounded()
            let label = ratio >= 2 ? "\(Int(ratio))×" : "2×"
            result.append((teleZoom, label))
        }

        // Optional 5× preset if the device supports it optically (e.g. iPhone 15 Pro Max)
        if switchFactors.count == 1 {
            // Dual-wide: add digital 2× shortcut
            let twoX = wideZoom * 2
            if twoX <= max { result.append((twoX, "2×")) }
        }

        return result
    }

    private func updateExpBounds(_ dev: AVCaptureDevice) {
        let mn = dev.minExposureTargetBias, mx = dev.maxExposureTargetBias
        DispatchQueue.main.async { [weak self] in
            self?.camState.minExp = mn; self?.camState.maxExp = mx; self?.camState.exposure = 0
        }
    }

    private func fixOrientation() {
        guard let conn = previewLayer.connection else { return }
        if #available(iOS 17, *) {
            if conn.isVideoRotationAngleSupported(90) { conn.videoRotationAngle = 90 }
        } else {
            if conn.isVideoOrientationSupported { conn.videoOrientation = .portrait }
        }
        conn.automaticallyAdjustsVideoMirroring = false
        conn.isVideoMirrored = (camPos == .front)
    }

    // MARK: Gestures

    private func setupGestures() {
        let tap  = UITapGestureRecognizer(target: self, action: #selector(onTap))
        let dbl  = UITapGestureRecognizer(target: self, action: #selector(onDblTap))
        dbl.numberOfTapsRequired = 2
        tap.require(toFail: dbl)
        let pinch = UIPinchGestureRecognizer(target: self, action: #selector(onPinch))
        let hold  = UILongPressGestureRecognizer(target: self, action: #selector(onHold))
        hold.minimumPressDuration = 0.6
        for g in [tap, dbl, pinch, hold] { view.addGestureRecognizer(g) }
    }

    @objc private func onDblTap(_ gr: UITapGestureRecognizer) {
        guard gr.state == .ended else { return }
        flipCamera()
    }

    @objc private func onTap(_ gr: UITapGestureRecognizer) {
        let pt    = gr.location(in: view)
        let camPt = previewLayer.captureDevicePointConverted(fromLayerPoint: pt)
        guard let dev = devInput?.device else { return }

        if isLocked {
            // Unlock
            isLocked = false
            hideFocusSquare()
            DispatchQueue.main.async { [weak self] in
                self?.camState.isLocked = false
                self?.camState.showExp  = false
                self?.camState.focusPt  = nil
            }
            sq.async {
                try? dev.lockForConfiguration()
                if dev.isFocusModeSupported(.continuousAutoFocus)       { dev.focusMode    = .continuousAutoFocus    }
                if dev.isExposureModeSupported(.continuousAutoExposure) { dev.exposureMode = .continuousAutoExposure }
                dev.unlockForConfiguration()
            }
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            return
        }

        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        showFocusSquare(at: pt, locked: false)
        DispatchQueue.main.async { [weak self] in
            self?.camState.focusPt  = pt
            self?.camState.showExp  = true
            self?.camState.exposure = 0
        }
        scheduleHideExposure()

        sq.async {
            try? dev.lockForConfiguration()
            if dev.isFocusPointOfInterestSupported    { dev.focusPointOfInterest    = camPt; dev.focusMode    = .autoFocus   }
            if dev.isExposurePointOfInterestSupported { dev.exposurePointOfInterest = camPt; dev.exposureMode = .autoExpose  }
            dev.unlockForConfiguration()
        }
    }

    @objc private func onHold(_ gr: UILongPressGestureRecognizer) {
        guard gr.state == .began else { return }
        let pt    = gr.location(in: view)
        let camPt = previewLayer.captureDevicePointConverted(fromLayerPoint: pt)
        guard let dev = devInput?.device else { return }

        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        isLocked = true
        showFocusSquare(at: pt, locked: true)
        DispatchQueue.main.async { [weak self] in
            self?.camState.isLocked = true
            self?.camState.showExp  = true
            self?.camState.exposure = 0
            self?.camState.focusPt  = pt
        }

        sq.async {
            try? dev.lockForConfiguration()
            if dev.isFocusPointOfInterestSupported    { dev.focusPointOfInterest    = camPt; dev.focusMode    = .locked }
            if dev.isExposurePointOfInterestSupported { dev.exposurePointOfInterest = camPt; dev.exposureMode = .locked }
            dev.unlockForConfiguration()
        }
    }

    @objc private func onPinch(_ gr: UIPinchGestureRecognizer) {
        guard let dev = devInput?.device else { return }
        switch gr.state {
        case .began:
            baseZoom = currentZoom
            DispatchQueue.main.async { self.camState.pinching = true }
            sq.async { try? dev.lockForConfiguration(); dev.cancelVideoZoomRamp(); dev.unlockForConfiguration() }
        case .changed:
            let req = (baseZoom * gr.scale).clamped(to: localMinZoom...localMaxZoom)
            if abs(req - currentZoom) > 0.005 {
                currentZoom = req
                DispatchQueue.main.async { self.camState.zoom = req }
                sq.async {
                    try? dev.lockForConfiguration()
                    dev.videoZoomFactor = req
                    dev.unlockForConfiguration()
                }
            }
        case .ended, .cancelled, .failed:
            DispatchQueue.main.async { self.camState.pinching = false }
        default: break
        }
    }

    // MARK: Focus square (UIKit layer — no SwiftUI layout overhead)

    private func showFocusSquare(at pt: CGPoint, locked: Bool) {
        focusItem?.cancel()
        focusView?.removeFromSuperview()

        let size: CGFloat = locked ? 88 : 72
        let fv = UIView(frame: CGRect(x: pt.x - size/2, y: pt.y - size/2, width: size, height: size))
        fv.layer.borderColor  = UIColor.systemYellow.cgColor
        fv.layer.borderWidth  = locked ? 2.0 : 1.5
        fv.layer.cornerRadius = 3
        fv.alpha              = 0
        fv.transform          = CGAffineTransform(scaleX: 1.25, y: 1.25)
        view.addSubview(fv)
        focusView = fv

        UIView.animate(withDuration: 0.15, delay: 0, options: .curveEaseOut,
                       animations: { fv.alpha = 1; fv.transform = .identity }, completion: nil)

        if !locked {
            let item = DispatchWorkItem { [weak self] in self?.hideFocusSquare() }
            focusItem = item
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.2, execute: item)
        }
    }

    private func hideFocusSquare() {
        focusItem?.cancel()
        let fv = focusView; focusView = nil
        UIView.animate(withDuration: 0.18, delay: 0, options: [],
                       animations: { fv?.alpha = 0 },
                       completion:  { _ in fv?.removeFromSuperview() })
        if !isLocked {
            DispatchQueue.main.async { self.camState.focusPt = nil; self.camState.showExp = false }
        }
    }

    // MARK: Exposure

    private func setExposure(_ value: Float) {
        guard let dev = devInput?.device else { return }
        let clamped = value.clamped(to: (dev.minExposureTargetBias)...(dev.maxExposureTargetBias))
        DispatchQueue.main.async { self.camState.exposure = clamped; self.camState.showExp = true }
        scheduleHideExposure()
        sq.async {
            try? dev.lockForConfiguration()
            dev.setExposureTargetBias(clamped, completionHandler: nil)
            dev.unlockForConfiguration()
        }
    }

    private func scheduleHideExposure() {
        expHideItem?.cancel()
        guard !isLocked else { return }
        let item = DispatchWorkItem { [weak self] in self?.camState.showExp = false }
        expHideItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0, execute: item)
    }

    // MARK: Zoom preset (ramp for smooth animation)

    private func rampZoom(to f: CGFloat) {
        guard let dev = devInput?.device else { return }
        let target = f.clamped(to: localMinZoom...localMaxZoom)
        currentZoom = target
        DispatchQueue.main.async { self.camState.zoom = target }
        sq.async {
            try? dev.lockForConfiguration()
            dev.ramp(toVideoZoomFactor: target, withRate: 28)
            dev.unlockForConfiguration()
        }
    }

    // MARK: Volume shutter

    // Called once in viewDidLoad — adds the hidden view that suppresses the system volume HUD.
    private func setupVolumeShutter() {
        let vv = MPVolumeView(frame: CGRect(x: -500, y: -500, width: 1, height: 1))
        vv.alpha = 0.001
        view.addSubview(vv)
        volView = vv
    }

    // Called in viewWillAppear so the observer is always active when the live viewfinder is shown,
    // including after a "retake" which tears down and rebuilds the SwiftUI view.
    private func startVolumeObserver() {
        guard volObs == nil else { return }   // already observing
        let sess = AVAudioSession.sharedInstance()
        try? sess.setCategory(.playAndRecord, options: [.mixWithOthers, .defaultToSpeaker])
        try? sess.setActive(true)
        lastVol = sess.outputVolume

        // Brief cooldown after audio session activation to avoid spurious KVO callbacks
        volShutterCooldown = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard let self else { return }
            self.lastVol = AVAudioSession.sharedInstance().outputVolume
            self.volShutterCooldown = false
        }

        volObs = sess.observe(\.outputVolume, options: [.new]) { [weak self] s, _ in
            guard let self, !self.volShutterCooldown, abs(s.outputVolume - self.lastVol) > 0.05 else { return }
            self.lastVol = s.outputVolume
            DispatchQueue.main.async { self.triggerShoot() }
        }
    }

    private func stopVolumeObserver() {
        volObs?.invalidate()
        volObs = nil
    }

    // MARK: CoreMotion (10 fps — minimal main-thread load)

    private func startMotion() {
        guard motion.isDeviceMotionAvailable else { return }
        motion.deviceMotionUpdateInterval = 0.1   // 10 fps
        motion.startDeviceMotionUpdates(to: .main) { [weak self] m, _ in
            guard let self, let m else { return }
            // π/2 offset — 0 means phone is perfectly level
            let p = m.attitude.pitch - (Double.pi / 2.0)
            self.camState.pitch = p
        }
    }

    private func stopMotion() { motion.stopDeviceMotionUpdates() }

    // MARK: Capture

    func triggerShoot() {
        guard !isCapturing else { return }
        if isCounting { cancelCountdown(haptic: true); return }
        let sec = camState.delay.seconds
        if sec > 0 { startCountdown(sec); return }
        fireCapture()
    }

    private func fireCapture() {
        guard !isCapturing else { return }
        isCapturing = true
        DispatchQueue.main.async { self.camState.capturing = true }
        flashScreen()

        // Capture flash mode on main thread before going to sq
        let flashMode = camState.flash.avMode
        let front     = camPos == .front

        sq.async { [weak self] in
            guard let self else { return }
            let settings = AVCapturePhotoSettings()
            if self.photoOut.supportedFlashModes.contains(flashMode) {
                settings.flashMode = flashMode
            }
            self.photoOut.capturePhoto(with: settings, delegate: self)
            _ = front   // captured for use in delegate
        }
    }

    private func flashScreen() {
        guard let w = view.window else { return }
        let fl = UIView(frame: w.bounds)
        fl.backgroundColor = .white; fl.alpha = 0; fl.isUserInteractionEnabled = false
        w.addSubview(fl)
        UIView.animate(withDuration: 0.04, animations: { fl.alpha = 1 }) { _ in
            UIView.animate(withDuration: 0.2, delay: 0, options: .curveEaseOut,
                           animations: { fl.alpha = 0 },
                           completion:  { _ in fl.removeFromSuperview() })
        }
    }

    // MARK: Countdown

    private func startCountdown(_ secs: Int) {
        isCounting = true
        DispatchQueue.main.async { self.camState.counting = true }
        cdTimer?.invalidate()
        var left = secs; showCdLabel(left)
        cdTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] t in
            guard let self else { t.invalidate(); return }
            left -= 1
            if left <= 0 {
                t.invalidate(); self.cdTimer = nil
                self.isCounting = false
                self.hideCdLabel(animated: true)
                DispatchQueue.main.async { self.camState.counting = false }
                self.fireCapture()
            } else {
                self.showCdLabel(left)
            }
        }
    }

    private func cancelCountdown(haptic: Bool) {
        guard isCounting || cdTimer != nil else { return }
        cdTimer?.invalidate(); cdTimer = nil
        isCounting = false; hideCdLabel(animated: false)
        DispatchQueue.main.async { self.camState.counting = false }
        if haptic { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
    }

    private func showCdLabel(_ n: Int) {
        let lbl: UILabel
        if let e = cdLabel { lbl = e }
        else {
            let l = UILabel()
            l.translatesAutoresizingMaskIntoConstraints = false
            l.textColor = .white; l.font = .systemFont(ofSize: 92, weight: .semibold)
            l.textAlignment = .center
            view.addSubview(l)
            NSLayoutConstraint.activate([l.centerXAnchor.constraint(equalTo: view.centerXAnchor),
                                         l.centerYAnchor.constraint(equalTo: view.centerYAnchor)])
            cdLabel = l; lbl = l
        }
        lbl.text = "\(n)"; lbl.alpha = 1
        lbl.transform = CGAffineTransform(scaleX: 1.3, y: 1.3)
        UIView.animate(withDuration: 0.18, delay: 0, options: .curveEaseOut,
                       animations: { lbl.transform = .identity }, completion: nil)
        UIImpactFeedbackGenerator(style: .rigid).impactOccurred(intensity: 0.9)
    }

    private func hideCdLabel(animated: Bool) {
        guard let lbl = cdLabel else { return }
        if animated {
            UIView.animate(withDuration: 0.12, animations: { lbl.alpha = 0 }) { _ in
                lbl.removeFromSuperview(); self.cdLabel = nil
            }
        } else { lbl.removeFromSuperview(); cdLabel = nil }
    }

    // MARK: Flip camera

    func flipCamera() {
        if isCounting { cancelCountdown(haptic: false) }
        let next: AVCaptureDevice.Position = camPos == .back ? .front : .back

        let tr = CATransition(); tr.duration = 0.25; tr.type = .fade
        previewLayer.add(tr, forKey: nil)

        sq.async { [weak self] in
            guard let self,
                  let dev = self.bestDevice(pos: next),
                  let inp = try? AVCaptureDeviceInput(device: dev)
            else { return }
            self.session.beginConfiguration()
            if let old = self.devInput { self.session.removeInput(old) }
            if self.session.canAddInput(inp) { self.session.addInput(inp); self.devInput = inp }
            self.session.commitConfiguration()
            self.updateZoomBounds(dev)
            self.updateExpBounds(dev)
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.camPos  = next
                self.isLocked = false
                self.hideFocusSquare()
                self.fixOrientation()
                self.camState.flash    = .off
                self.camState.showExp  = false
                self.camState.isLocked = false
                self.camState.focusPt  = nil
                self.camState.isFront  = (next == .front)
                self.camState.flashOK  = (inp.device.hasFlash && next == .back)
            }
        }
    }
}

// MARK: - AVCapturePhotoCaptureDelegate

extension CameraVC: AVCapturePhotoCaptureDelegate {
    nonisolated func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishProcessingPhoto photo: AVCapturePhoto,
        error: Error?
    ) {
        let data = photo.fileDataRepresentation()
        let capturedError = error
        Task { @MainActor [weak self] in
            guard let self else { return }
            let isFront = self.camPos == .front
            self.isCapturing = false
            self.camState.capturing = false
            guard capturedError == nil, let data, let raw = UIImage(data: data) else { return }
            let fixed = fixImageOrientation(raw)
            let final = isFront ? mirrorImage(fixed) : fixed
            self.onPhoto?(final)
        }
    }
}

// MARK: - CameraOverlay (pure SwiftUI)

private struct CameraOverlay: View {
    @ObservedObject var state:  CameraState
    @Binding       var ratio:   CaptureRatio
    @Binding       var film:    FilmPreset
    let safeTop:    CGFloat
    let safeBottom: CGFloat
    let onDismiss:  () -> Void

    @State private var shutterDown  = false
    @State private var expBase: Float = 0
    @State private var expDragging  = false
    @State private var showFilmPanel = false

    private var bInset: CGFloat { max(safeBottom, 20) }
    // Screen dimensions from UIKit — avoids full-screen GeometryReader blocking touches
    private var sw: CGFloat { UIScreen.main.bounds.width  }
    private var sh: CGFloat { UIScreen.main.bounds.height }

    var body: some View {
        ZStack {
            // Film preview effects (vignette + grain)
            filmOverlay

            GridFrameGuide(ratio: ratio, grid: state.grid)
                .allowsHitTesting(false)

            gradients

            // Lock banner
            if state.isLocked { lockBanner }

            // Exposure handle — positioned exactly at focus tap point
            if state.showExp, let pt = state.focusPt {
                exposureHandle(at: pt)
            }

            // Pinch zoom label
            if state.pinching { zoomBadge }

            // All buttons
            controls

            // Film panel — slides up from bottom, tap outside to dismiss
            if showFilmPanel {
                Color.black.opacity(0.01)
                    .ignoresSafeArea()
                    .contentShape(Rectangle())
                    .onTapGesture {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.82)) { showFilmPanel = false }
                    }
                    .zIndex(9)
                filmPanel
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .zIndex(10)
            }
        }
        .ignoresSafeArea()
        .animation(.easeInOut(duration: 0.16), value: state.isLocked)
        .animation(.easeInOut(duration: 0.15), value: state.showExp)
        .animation(.easeInOut(duration: 0.12), value: state.pinching)
        .animation(.easeInOut(duration: 0.2),  value: film)
        .animation(.spring(response: 0.3, dampingFraction: 0.82), value: showFilmPanel)
    }

    // MARK: Film preview overlay (vignette + grain — no pipeline change)

    @ViewBuilder
    private var filmOverlay: some View {
        if film != .normal {
            ZStack {
                // Vignette — radial gradient from center outward
                if film.previewVignette > 0 {
                    RadialGradient(
                        colors: [.clear, .black.opacity(film.previewVignette)],
                        center: .center,
                        startRadius: 80,
                        endRadius: 340
                    )
                    .allowsHitTesting(false)
                }
                // Grain
                if film.previewGrain > 0 {
                    FilmGrainView(intensity: film.previewGrain)
                }
                // B&W tint overlay
                if film == .bw {
                    Color.black.opacity(0.08)
                        .blendMode(.saturation)
                        .allowsHitTesting(false)
                }
            }
            .ignoresSafeArea()
            .allowsHitTesting(false)
            .transition(.opacity)
        }
    }

    // MARK: Gradients

    private var gradients: some View {
        VStack(spacing: 0) {
            LinearGradient(colors: [.black.opacity(0.62), .clear], startPoint: .top, endPoint: .bottom)
                .frame(height: safeTop + 90)
            Spacer()
            LinearGradient(colors: [.clear, .black.opacity(0.80)], startPoint: .top, endPoint: .bottom)
                .frame(height: bInset + 240)
        }
        .allowsHitTesting(false)
    }

    // MARK: AE/AF lock banner

    private var lockBanner: some View {
        VStack {
            Spacer()
            Text("AE/AF LOCK")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .tracking(1.4)
                .foregroundColor(.black)
                .padding(.horizontal, 10).padding(.vertical, 4)
                .background(Capsule().fill(.yellow))
                .padding(.bottom, bInset + 232)
        }
        .transition(.opacity.combined(with: .scale(scale: 0.9)))
    }

    // MARK: Exposure handle — native iPhone Camera style
    // Appears to the right of the focus square, drag up/down to adjust EV
    // Uses UIScreen bounds directly — no GeometryReader so nothing blocks shutter touches

    @ViewBuilder
    private func exposureHandle(at pt: CGPoint) -> some View {
        let barH: CGFloat = 120
        let sunX  = min(pt.x + 58, sw - 36)
        let norm  = CGFloat((state.exposure - state.minExp) / (state.maxExp - state.minExp))
        let sunY  = (pt.y - barH * (norm - 0.5)).clamped(to: (pt.y - barH / 2)...(pt.y + barH / 2))
        let fillH = max(CGFloat(0), min(barH, barH * norm))

        ZStack {
            // Track line (not interactive)
            Capsule()
                .fill(Color.white.opacity(0.35))
                .frame(width: 2, height: barH)
                .position(x: sunX, y: pt.y)
                .allowsHitTesting(false)

            // Fill bar (not interactive)
            Capsule()
                .fill(Color.yellow.opacity(0.85))
                .frame(width: 2, height: fillH)
                .position(x: sunX, y: pt.y + barH / 2 - fillH / 2)
                .allowsHitTesting(false)

            // Sun icon — ONLY interactive element; drag up/down for EV
            Image(systemName: abs(state.exposure) > 0.08 ? "sun.max.fill" : "sun.max")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(.yellow)
                .shadow(color: .black.opacity(0.55), radius: 3)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
                .position(x: sunX, y: sunY)
                .gesture(
                    DragGesture(minimumDistance: 1, coordinateSpace: .global)
                        .onChanged { v in
                            if !expDragging { expDragging = true; expBase = state.exposure }
                            let range = state.maxExp - state.minExp
                            let delta = Float(-v.translation.height / barH) * range
                            state.adjustExp((expBase + delta).clamped(to: state.minExp...state.maxExp))
                        }
                        .onEnded { _ in expDragging = false }
                )

            // EV label (not interactive)
            if abs(state.exposure) > 0.08 {
                Text(String(format: "%+.1f", state.exposure))
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .foregroundColor(.yellow)
                    .shadow(color: .black.opacity(0.6), radius: 2)
                    .position(x: sunX + 26, y: sunY)
                    .allowsHitTesting(false)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // Only the sun icon has hit-testing — everything else passes through
        .allowsHitTesting(true)
        .transition(.opacity.combined(with: .scale(scale: 0.9, anchor: .leading)))
    }

    // MARK: Zoom badge during pinch

    private var zoomBadge: some View {
        Text(String(format: "%.1f×", state.zoom))
            .font(.system(size: 30, weight: .bold, design: .rounded))
            .foregroundColor(.white)
            .shadow(color: .black.opacity(0.4), radius: 3)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            .padding(.bottom, bInset + 240)
            .allowsHitTesting(false)
            .transition(.opacity.combined(with: .scale(scale: 0.85)))
    }

    // MARK: Level indicator

    @ViewBuilder
    private var levelIndicator: some View {
        let p  = abs(state.pitch)
        let ok = p < 0.025
        if p > 0.01 && p < 0.35 {
            HStack(spacing: 4) {
                Rectangle().fill(ok ? Color.yellow : Color.white).frame(width: 24, height: 1.5)
                Rectangle().fill(ok ? Color.yellow : Color.white).frame(width: 24, height: 1.5)
            }
            .opacity(0.78)
            .animation(.easeInOut(duration: 0.18), value: ok)
        }
    }

    // MARK: Controls column

    private var controls: some View {
        VStack(spacing: 0) {
            topBar
            Spacer()
            levelIndicator.padding(.bottom, 8)
            zoomPills.padding(.bottom, 8)
            // Film preset indicator badge (tapping opens full panel via top-bar icon)
            if film != .normal {
                Text(film.rawValue.uppercased())
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .tracking(1.2)
                    .foregroundColor(.yellow)
                    .padding(.horizontal, 10).padding(.vertical, 4)
                    .background(Capsule().fill(.black.opacity(0.45))
                        .overlay(Capsule().stroke(.yellow.opacity(0.4), lineWidth: 1)))
                    .padding(.bottom, 6)
                    .transition(.opacity.combined(with: .scale(scale: 0.9)))
                    .allowsHitTesting(false)
            }
            modeStrip.padding(.bottom, 14)
            bottomBar
        }
    }

    // MARK: Top bar

    private var topBar: some View {
        HStack(spacing: 6) {
            camBtn(sf: "xmark", sz: 13) { onDismiss() }
            Spacer()
            camBtn(sf: state.flash.icon, sz: 14, active: state.flash.isActive) {
                if state.flashOK { state.cycleFlash() }
            }.opacity(state.flashOK ? 1 : 0.3)
            camBtn(sf: "timer", sz: 13, active: state.delay.isActive, badge: state.delay.badge) {
                state.cycleDelay()
            }
            camBtn(sf: state.grid ? "square.grid.3x3.fill" : "square.grid.3x3", sz: 13, active: state.grid) {
                state.toggleGrid()
            }
            camBtn(sf: "camera.filters", sz: 14, active: film != .normal) {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                withAnimation(.spring(response: 0.3, dampingFraction: 0.82)) { showFilmPanel.toggle() }
            }
        }
        .padding(.horizontal, 14)
        .padding(.top, safeTop + 10)
    }

    // MARK: Zoom pills

    private var zoomPills: some View {
        let presets = state.lensPresets
        return HStack(spacing: 5) {
            ForEach(Array(presets.enumerated()), id: \.offset) { idx, preset in
                let (factor, label) = preset
                // A preset is "active" when the current zoom is in [this factor, next factor)
                let nextFactor: CGFloat = idx + 1 < presets.count ? presets[idx + 1].factor : CGFloat.infinity
                let active = state.zoom >= factor - 0.05 && state.zoom < nextFactor
                Button { state.zoomPreset(factor) } label: {
                    Text(label)
                        .font(.system(size: 13, weight: .semibold, design: .monospaced))
                        .foregroundColor(active ? .black : .white)
                        .padding(.horizontal, active ? 11 : 8)
                        .padding(.vertical, active ? 6 : 5)
                        .background(Capsule().fill(active ? .white.opacity(0.95) : .black.opacity(0.35)))
                        .animation(.spring(response: 0.2, dampingFraction: 0.7), value: active)
                }
            }
        }
        .padding(.horizontal, 10).padding(.vertical, 6)
        .background(Capsule().fill(.black.opacity(0.28))
            .overlay(Capsule().stroke(.white.opacity(0.13), lineWidth: 1)))
    }

    // MARK: Mode strip

    private var modeStrip: some View {
        HStack(spacing: 28) {
            ForEach(CaptureRatio.allCases, id: \.self) { r in
                let active = ratio == r
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    ratio = r
                } label: {
                    Text(modeLabel(r))
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                        .tracking(1.0)
                        .foregroundColor(active ? .yellow : .white.opacity(0.65))
                        .scaleEffect(active ? 1.06 : 1.0)
                        .animation(.spring(response: 0.2, dampingFraction: 0.7), value: active)
                }
            }
        }
    }

    private func modeLabel(_ r: CaptureRatio) -> String {
        let key: String
        switch r {
        case .story:    key = "camera.mode.story"
        case .standard: key = "camera.mode.photo"
        case .square:   key = "camera.mode.square"
        }
        return NSLocalizedString(key, comment: "").uppercased(with: .current)
    }

    // MARK: Bottom bar

    private var bottomBar: some View {
        HStack(alignment: .center) {
            Color.clear.frame(width: 48, height: 48)
            Spacer()
            shutterBtn
            Spacer()
            camBtn(sf: "arrow.triangle.2.circlepath.camera.fill", sz: 20) { state.flip() }
        }
        .padding(.horizontal, 28)
        .padding(.bottom, bInset + 14)
    }

    // MARK: Shutter button

    private var shutterBtn: some View {
        Button {
            withAnimation(.spring(response: 0.14, dampingFraction: 0.5)) { shutterDown = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.09) {
                withAnimation(.spring(response: 0.26)) { shutterDown = false }
            }
            state.shoot()
        } label: {
            ZStack {
                Circle()
                    .stroke(state.counting ? Color.yellow.opacity(0.88) : Color.white.opacity(0.8), lineWidth: 3.5)
                    .frame(width: 78, height: 78)
                Circle()
                    .fill(state.counting ? Color.yellow : Color.white)
                    .frame(width: 64, height: 64)
                    .scaleEffect(shutterDown ? 0.76 : (state.capturing ? 0.9 : 1.0))
                    .animation(.spring(response: 0.18, dampingFraction: 0.6), value: state.capturing)
                if state.counting {
                    Image(systemName: "xmark")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(.black.opacity(0.7))
                }
            }
        }
        .disabled(state.capturing || state.isInRetakeCooldown)
        .opacity((state.capturing || state.isInRetakeCooldown) ? 0.5 : 1)
    }

    // MARK: Film Panel (slide-up sheet with 2×3 grid)

    private var filmPanel: some View {
        VStack(spacing: 0) {
            // Drag handle
            Capsule()
                .fill(.white.opacity(0.35))
                .frame(width: 36, height: 4)
                .padding(.top, 14)
                .padding(.bottom, 18)

            // 3-column preset grid
            let cols = [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]
            LazyVGrid(columns: cols, spacing: 18) {
                ForEach(FilmPreset.allCases, id: \.self) { preset in
                    filmPresetCell(preset)
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, max(bInset, 24) + 12)
        }
        .frame(maxWidth: .infinity)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .stroke(.white.opacity(0.12), lineWidth: 1)
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
    }

    @ViewBuilder
    private func filmPresetCell(_ preset: FilmPreset) -> some View {
        let active = film == preset
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            film = preset
            // Always close panel so user immediately sees the effect on the live feed
            withAnimation(.spring(response: 0.3, dampingFraction: 0.82)) { showFilmPanel = false }
        } label: {
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(filmCircleGradient(preset))
                        .frame(width: 58, height: 58)
                    Circle()
                        .stroke(active ? Color.yellow : Color.white.opacity(0.2),
                                lineWidth: active ? 2.5 : 1)
                        .frame(width: 58, height: 58)
                    if active {
                        Image(systemName: "checkmark")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
                Text(preset.rawValue)
                    .font(.system(size: 11, weight: active ? .bold : .medium, design: .monospaced))
                    .foregroundColor(active ? .yellow : .white.opacity(0.8))
            }
        }
        .animation(.spring(response: 0.2, dampingFraction: 0.7), value: active)
    }

    private func filmCircleGradient(_ preset: FilmPreset) -> LinearGradient {
        switch preset {
        case .normal:
            return LinearGradient(colors: [.gray.opacity(0.5), .gray.opacity(0.25)],
                                  startPoint: .topLeading, endPoint: .bottomTrailing)
        case .kodak:
            return LinearGradient(colors: [Color(hue: 0.08, saturation: 0.7, brightness: 0.85),
                                           Color(hue: 0.05, saturation: 0.55, brightness: 0.45)],
                                  startPoint: .topLeading, endPoint: .bottomTrailing)
        case .fuji:
            return LinearGradient(colors: [Color(hue: 0.55, saturation: 0.5, brightness: 0.75),
                                           Color(hue: 0.50, saturation: 0.6, brightness: 0.4)],
                                  startPoint: .topLeading, endPoint: .bottomTrailing)
        case .dispo:
            return LinearGradient(colors: [Color(hue: 0.85, saturation: 0.65, brightness: 0.9),
                                           Color(hue: 0.90, saturation: 0.7, brightness: 0.5)],
                                  startPoint: .topLeading, endPoint: .bottomTrailing)
        case .bw:
            return LinearGradient(colors: [.white.opacity(0.7), .gray.opacity(0.3)],
                                  startPoint: .topLeading, endPoint: .bottomTrailing)
        case .fade:
            return LinearGradient(colors: [Color(hue: 0.6, saturation: 0.2, brightness: 0.9),
                                           Color(hue: 0.55, saturation: 0.15, brightness: 0.55)],
                                  startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }

    // MARK: Generic button

    private func camBtn(sf: String, sz: CGFloat, active: Bool = false,
                        badge: String? = nil, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: sf)
                .font(.system(size: sz, weight: .semibold))
                .foregroundColor(active ? .yellow : .white)
                .frame(width: 42, height: 42)
                .background(Circle().fill(.ultraThinMaterial)
                    .overlay(Circle().stroke(.white.opacity(0.16), lineWidth: 1)))
                .overlay(alignment: .topTrailing) {
                    if let b = badge {
                        Text(b)
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundColor(.black)
                            .padding(.horizontal, 4).padding(.vertical, 2)
                            .background(Capsule().fill(.yellow))
                            .offset(x: 3, y: -3)
                    }
                }
        }
    }
}

// MARK: - Film Grain View (animated Canvas — no pipeline change)

private struct FilmGrainView: View {
    let intensity: Double
    @State private var seed: UInt64 = 1

    // 8 fps grain animation — imperceptible overhead
    private let timer = Timer.publish(every: 0.12, on: .main, in: .common).autoconnect()

    var body: some View {
        Canvas { ctx, size in
            var rng  = LCG(state: seed)
            let count = Int(intensity * 900)
            for _ in 0..<count {
                let x = CGFloat(rng.nextFloat()) * size.width
                let y = CGFloat(rng.nextFloat()) * size.height
                let a = Double(rng.nextFloat()) * intensity * 0.65
                let r = CGFloat(rng.nextFloat()) * 1.4 + 0.4
                ctx.fill(Path(ellipseIn: CGRect(x: x, y: y, width: r, height: r)),
                         with: .color(.white.opacity(a)))
            }
        }
        .blendMode(.overlay)
        .allowsHitTesting(false)
        .onReceive(timer) { _ in seed = seed &* 6364136223846793005 &+ 1442695040888963407 }
    }
}

// Minimal LCG random — zero dependencies, fast
private struct LCG {
    var state: UInt64
    mutating func next() -> UInt64 {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return state
    }
    mutating func nextFloat() -> Float { Float(next() >> 33) / Float(1 << 31) }
}

// MARK: - GridFrameGuide

private struct GridFrameGuide: View {
    let ratio: CaptureRatio
    let grid:  Bool

    var body: some View {
        GeometryReader { geo in
            draw(w: geo.size.width, h: geo.size.height)
        }
    }

    @ViewBuilder
    private func draw(w: CGFloat, h: CGFloat) -> some View {
        let tgt  = ratio.wh
        let cur  = w / h
        let fw   = cur <= tgt ? w : h * tgt
        let fh   = cur <= tgt ? w / tgt : h
        let hPad = max((w - fw) / 2, 0)
        let vPad = max((h - fh) / 2, 0)
        let fr   = CGRect(x: hPad, y: vPad, width: fw, height: fh)

        ZStack {
            // Letterbox masks
            if hPad > 0.5 {
                Color.black.opacity(0.5).frame(width: hPad)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                Color.black.opacity(0.5).frame(width: hPad)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
            }
            if vPad > 0.5 {
                Color.black.opacity(0.5).frame(height: vPad)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                Color.black.opacity(0.5).frame(height: vPad)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            }
            // Frame border
            Path { $0.addRect(fr) }
                .stroke(Color.white.opacity(0.2), lineWidth: 1)
            // Grid lines
            if grid {
                Path { p in
                    let x1 = fr.minX + fw / 3, x2 = fr.minX + fw * 2 / 3
                    let y1 = fr.minY + fh / 3, y2 = fr.minY + fh * 2 / 3
                    p.move(to: .init(x: x1, y: fr.minY)); p.addLine(to: .init(x: x1, y: fr.maxY))
                    p.move(to: .init(x: x2, y: fr.minY)); p.addLine(to: .init(x: x2, y: fr.maxY))
                    p.move(to: .init(x: fr.minX, y: y1)); p.addLine(to: .init(x: fr.maxX, y: y1))
                    p.move(to: .init(x: fr.minX, y: y2)); p.addLine(to: .init(x: fr.maxX, y: y2))
                }
                .stroke(Color.white.opacity(0.26), lineWidth: 0.75)
            }
        }
        .allowsHitTesting(false)
    }
}

// MARK: - UIImage helpers

private func fixImageOrientation(_ img: UIImage) -> UIImage {
    guard img.imageOrientation != .up else { return img }
    UIGraphicsBeginImageContextWithOptions(img.size, false, img.scale)
    defer { UIGraphicsEndImageContext() }
    img.draw(in: CGRect(origin: .zero, size: img.size))
    return UIGraphicsGetImageFromCurrentImageContext() ?? img
}

private func mirrorImage(_ img: UIImage) -> UIImage {
    UIGraphicsBeginImageContextWithOptions(img.size, false, img.scale)
    defer { UIGraphicsEndImageContext() }
    guard let ctx = UIGraphicsGetCurrentContext() else { return img }
    ctx.translateBy(x: img.size.width, y: 0); ctx.scaleBy(x: -1, y: 1)
    img.draw(in: CGRect(origin: .zero, size: img.size))
    return UIGraphicsGetImageFromCurrentImageContext() ?? img
}

// MARK: - Comparable clamp

extension Comparable {
    func clamped(to r: ClosedRange<Self>) -> Self { min(max(self, r.lowerBound), r.upperBound) }
}
