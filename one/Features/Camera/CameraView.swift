//
//  CameraView.swift
//  one
//
//  Sıfırdan yazılmış, AVFoundation tabanlı tam custom kamera.
//  Donma / deadlock yok — session yönetimi tek bir dedicated queue'da.
//
//  - Varsayılan 9:16 (Instagram Story)
//  - Oran: 9:16 · 4:3 · 1:1
//  - Ön kamera her zaman yansıtılır
//  - Preview: fotoğraf + "Bu anı güzel yakaladın" + Tekrar Çek / Kullan
//

import SwiftUI
import AVFoundation
import UIKit

// MARK: - Aspect Ratio

enum CaptureRatio: String, CaseIterable {
    case story    = "9:16"
    case standard = "4:3"
    case square   = "1:1"

    /// width / height in portrait orientation
    var wh: CGFloat {
        switch self {
        case .story:    return 9.0 / 16.0
        case .standard: return 3.0 / 4.0
        case .square:   return 1.0
        }
    }
}

// MARK: - CameraView (SwiftUI shell)

struct CameraView: View {
    @Binding var image: UIImage?
    @Environment(\.dismiss) var dismiss

    @State private var capturedImage: UIImage? = nil
    @State private var showPreview = false
    @State private var previewScale: CGFloat = 0.9
    @State private var previewOpacity: Double = 0
    @State private var selectedRatio: CaptureRatio = .story
    @State private var cameraKey = UUID()

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if showPreview, let img = capturedImage {
                photoPreview(img)
                    .transition(.opacity)
                    .zIndex(1)
            } else {
                LiveCameraView(
                    ratio: $selectedRatio,
                    onPhoto: { img in
                        capturedImage = img
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            showPreview    = true
                            previewScale   = 1.0
                            previewOpacity = 1.0
                        }
                    },
                    onDismiss: { dismiss() }
                )
                .id(cameraKey)
                .ignoresSafeArea()
                .zIndex(0)
            }
        }
    }

    // MARK: Photo preview

    @ViewBuilder
    private func photoPreview(_ raw: UIImage) -> some View {
        let display = cropped(raw, ratio: selectedRatio)

        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                HStack {
                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        retake()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 44, height: 44)
                            .background(Color.white.opacity(0.15))
                            .clipShape(Circle())
                    }
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)

                Spacer()

                Image(uiImage: display)
                    .resizable()
                    .scaledToFit()
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .shadow(color: .black.opacity(0.4), radius: 24, x: 0, y: 12)
                    .padding(.horizontal, 20)
                    .scaleEffect(previewScale)
                    .opacity(previewOpacity)

                Text("Bu anı güzel yakaladın")
                    .displayMD()
                    .foregroundColor(.white.opacity(0.65))
                    .padding(.top, 18)
                    .opacity(previewOpacity)

                Spacer()

                HStack(spacing: 14) {
                    Button {
                        UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
                        retake()
                    } label: {
                        Label("Tekrar Çek", systemImage: "arrow.counterclockwise")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .stroke(Color.white.opacity(0.3), lineWidth: 1.5)
                            )
                    }

                    Button {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        image = display
                        dismiss()
                    } label: {
                        Label("Kullan", systemImage: "checkmark")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(Color.white)
                            )
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 48)
                .opacity(previewOpacity)
            }
        }
    }

    // MARK: Actions

    private func retake() {
        withAnimation(.easeInOut(duration: 0.2)) {
            showPreview    = false
            previewScale   = 0.9
            previewOpacity = 0
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            capturedImage = nil
            cameraKey = UUID()
        }
    }

    // MARK: Crop

    private func cropped(_ img: UIImage, ratio: CaptureRatio) -> UIImage {
        let w = img.size.width, h = img.size.height
        guard w > 0, h > 0 else { return img }
        let target = (h >= w) ? ratio.wh : (1.0 / ratio.wh)
        let current = w / h
        guard abs(current - target) > 0.005 else { return img }
        let rect: CGRect
        if current > target {
            let cw = h * target
            rect = CGRect(x: (w - cw) / 2, y: 0, width: cw, height: h)
        } else {
            let ch = w / target
            rect = CGRect(x: 0, y: (h - ch) / 2, width: w, height: ch)
        }
        let s = img.scale
        guard let cg = img.cgImage?.cropping(to: rect.applying(.init(scaleX: s, y: s))) else { return img }
        return UIImage(cgImage: cg, scale: s, orientation: img.imageOrientation)
    }
}

// MARK: - LiveCameraView (UIViewControllerRepresentable)

struct LiveCameraView: UIViewControllerRepresentable {
    @Binding var ratio: CaptureRatio
    var onPhoto: (UIImage) -> Void
    var onDismiss: () -> Void

    func makeUIViewController(context: Context) -> CameraVC {
        let vc = CameraVC()
        vc.ratio     = ratio
        vc.onPhoto   = onPhoto
        vc.onDismiss = onDismiss
        return vc
    }

    func updateUIViewController(_ vc: CameraVC, context: Context) {
        guard vc.ratio != ratio else { return }
        vc.ratio = ratio
        vc.refreshOverlay()
    }
}

// MARK: - CameraVC

final class CameraVC: UIViewController {

    var ratio:     CaptureRatio = .story
    var onPhoto:   ((UIImage) -> Void)?
    var onDismiss: (() -> Void)?

    // AVFoundation
    private let session    = AVCaptureSession()
    private let output     = AVCapturePhotoOutput()
    private var input:       AVCaptureDeviceInput?
    private var preview:     AVCaptureVideoPreviewLayer!
    private var position:    AVCaptureDevice.Position = .back

    // Session queue — ALL session calls go here
    private let sq = DispatchQueue(label: "one.cam.session", qos: .userInitiated)

    // Overlay
    private var overlayVC: UIHostingController<OverlayView>?
    private var overlayAdded = false

    // MARK: Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        buildPreviewLayer()
        sq.async { [weak self] in self?.buildSession() }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        preview.frame = view.bounds
        overlayVC?.view.frame = view.bounds
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        sq.async { [weak self] in
            guard let s = self else { return }
            if !s.session.isRunning { s.session.startRunning() }
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if !overlayAdded { attachOverlay() }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        sq.async { [weak self] in self?.session.stopRunning() }
    }

    // MARK: Session setup

    private func buildPreviewLayer() {
        preview = AVCaptureVideoPreviewLayer()
        preview.videoGravity = .resizeAspectFill
        preview.frame = view.bounds
        view.layer.insertSublayer(preview, at: 0)
    }

    private func buildSession() {
        // All of this runs on sq
        session.beginConfiguration()
        session.sessionPreset = .photo

        // Input
        if let dev = camera(at: position),
           let inp = try? AVCaptureDeviceInput(device: dev),
           session.canAddInput(inp) {
            session.addInput(inp)
            input = inp
        }

        // Output
        if session.canAddOutput(output) {
            session.addOutput(output)
            if #available(iOS 16.0, *) {
                // Pick the largest dimension the active device format supports
                if let device = (input?.device),
                   let maxDim = device.activeFormat.supportedMaxPhotoDimensions.last {
                    output.maxPhotoDimensions = maxDim
                }
            } else {
                output.isHighResolutionCaptureEnabled = true
            }
        }

        session.commitConfiguration()

        // Attach preview & start — must happen on main for layer
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.preview.session = self.session
            self.applyMirror()
        }

        session.startRunning()
    }

    private func camera(at pos: AVCaptureDevice.Position) -> AVCaptureDevice? {
        AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: pos)
    }

    private func applyMirror() {
        guard let conn = preview.connection else { return }

        // Orientation — use non-deprecated API on iOS 17+
        if #available(iOS 17.0, *) {
            if conn.isVideoRotationAngleSupported(0) {
                conn.videoRotationAngle = 90  // portrait
            }
        } else {
            if conn.isVideoOrientationSupported {
                conn.videoOrientation = .portrait
            }
        }

        // Mirror — must disable automaticAdjustment first
        if conn.isVideoMirroringSupported {
            conn.automaticallyAdjustsVideoMirroring = false
            conn.isVideoMirrored = (position == .front)
        }
    }

    // MARK: Overlay

    private func attachOverlay() {
        let ov = makeOverlay()
        let host = UIHostingController(rootView: ov)
        host.view.backgroundColor = .clear
        host.view.frame = view.bounds
        host.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        addChild(host)
        view.addSubview(host.view)
        host.didMove(toParent: self)
        overlayVC   = host
        overlayAdded = true
    }

    func refreshOverlay() {
        overlayVC?.rootView = makeOverlay()
    }

    private func makeOverlay() -> OverlayView {
        OverlayView(
            ratio:    ratio,
            isFront:  position == .front,
            onShutter: { [weak self] in self?.shoot() },
            onFlip:    { [weak self] in self?.flip() },
            onCancel:  { [weak self] in self?.onDismiss?() },
            onRatio:   { [weak self] r in
                self?.ratio = r
                self?.refreshOverlay()
            }
        )
    }

    // MARK: Actions

    private func shoot() {
        // Flash feedback on main, capture on sq
        DispatchQueue.main.async { [weak self] in self?.flash() }
        sq.async { [weak self] in
            guard let self else { return }
            let s = AVCapturePhotoSettings()
            self.output.capturePhoto(with: s, delegate: self)
        }
    }

    private func flip() {
        let next: AVCaptureDevice.Position = (position == .back) ? .front : .back
        sq.async { [weak self] in
            guard let self,
                  let dev = self.camera(at: next),
                  let inp = try? AVCaptureDeviceInput(device: dev)
            else { return }

            self.session.beginConfiguration()
            if let old = self.input { self.session.removeInput(old) }
            if self.session.canAddInput(inp) {
                self.session.addInput(inp)
                self.input = inp
            }
            self.session.commitConfiguration()

            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.position = next
                self.applyMirror()
                self.refreshOverlay()
            }
        }
    }

    private func flash() {
        guard let w = view.window else { return }
        let v = UIView(frame: w.bounds)
        v.backgroundColor = .white
        v.alpha = 1
        v.isUserInteractionEnabled = false
        w.addSubview(v)
        UIView.animate(withDuration: 0.18, delay: 0, options: .curveEaseOut) {
            v.alpha = 0
        } completion: { _ in v.removeFromSuperview() }
    }
}

// MARK: - Photo delegate

extension CameraVC: AVCapturePhotoCaptureDelegate {
    // nonisolated — AVFoundation calls this on an arbitrary background thread.
    // We do ALL image work here (no UIKit/MainActor), then hop to main to deliver.
    nonisolated func photoOutput(_ out: AVCapturePhotoOutput,
                                 didFinishProcessingPhoto photo: AVCapturePhoto,
                                 error: Error?) {
        guard error == nil,
              let data = photo.fileDataRepresentation(),
              let raw  = UIImage(data: data)
        else { return }

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            let fixed = cameraFixOrientation(raw)
            let final = (self.position == .front) ? cameraMirrorImage(fixed) : fixed
            self.onPhoto?(final)
        }
    }
}

// MARK: - OverlayView (SwiftUI)

struct OverlayView: View {
    let ratio:   CaptureRatio
    let isFront: Bool
    var onShutter: () -> Void
    var onFlip:    () -> Void
    var onCancel:  () -> Void
    var onRatio:   (CaptureRatio) -> Void

    @State private var ratioPicker = false

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .bottom) {
                // Frame guide
                FrameGuide(ratio: ratio)
                    .allowsHitTesting(false)

                // UI
                VStack(spacing: 0) {
                    topBar(geo)
                    Spacer()
                    if ratioPicker {
                        ratioRow
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                    bottomBar(geo)
                }
            }
        }
        .ignoresSafeArea()
    }

    // top bar
    private func topBar(_ geo: GeometryProxy) -> some View {
        HStack {
            pill(icon: "xmark") { onCancel() }
            Spacer()
            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                withAnimation(.easeInOut(duration: 0.18)) { ratioPicker.toggle() }
            } label: {
                HStack(spacing: 4) {
                    Text(ratio.rawValue)
                        .font(.system(size: 13, weight: .semibold))
                    Image(systemName: ratioPicker ? "chevron.up" : "chevron.down")
                        .font(.system(size: 9, weight: .bold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 12).padding(.vertical, 8)
                .background(Capsule().fill(Color.black.opacity(0.5)))
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, geo.safeAreaInsets.top + 8)
    }

    // ratio picker row
    private var ratioRow: some View {
        HStack(spacing: 8) {
            ForEach(CaptureRatio.allCases, id: \.self) { r in
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    withAnimation(.easeInOut(duration: 0.15)) {
                        ratioPicker = false
                        onRatio(r)
                    }
                } label: {
                    Text(r.rawValue)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(ratio == r ? .black : .white)
                        .padding(.horizontal, 14).padding(.vertical, 8)
                        .background(
                            Capsule().fill(ratio == r ? Color.yellow : Color.white.opacity(0.2))
                        )
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 12)
    }

    // bottom bar
    private func bottomBar(_ geo: GeometryProxy) -> some View {
        HStack {
            pill(icon: "arrow.triangle.2.circlepath.camera") { onFlip() }
            Spacer()
            // Shutter
            Button {
                UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                onShutter()
            } label: {
                ZStack {
                    Circle().stroke(Color.white.opacity(0.6), lineWidth: 3).frame(width: 80, height: 80)
                    Circle().fill(Color.white).frame(width: 66, height: 66)
                }
            }
            Spacer()
            Color.clear.frame(width: 52, height: 52)
        }
        .padding(.horizontal, 28)
        .padding(.bottom, max(geo.safeAreaInsets.bottom, 20) + 14)
    }

    private func pill(icon: String, action: @escaping () -> Void) -> some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            action()
        } label: {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.white)
                .frame(width: 52, height: 52)
                .background(Color.black.opacity(0.5))
                .clipShape(Circle())
        }
    }
}

// MARK: - Frame Guide

private struct FrameGuide: View {
    let ratio: CaptureRatio

    var body: some View {
        GeometryReader { geo in
            guide(w: geo.size.width, h: geo.size.height)
        }
    }

    @ViewBuilder
    private func guide(w: CGFloat, h: CGFloat) -> some View {
        let aspect = ratio.wh               // w/h portrait
        let fw: CGFloat = w / h <= aspect ? w       : h * aspect
        let fh: CGFloat = w / h <= aspect ? w / aspect : h
        let hPad = max((w - fw) / 2, 0)
        let vPad = max((h - fh) / 2, 0)

        ZStack {
            if hPad > 1 {
                HStack(spacing: 0) {
                    Rectangle().fill(Color.black.opacity(0.48)).frame(width: hPad)
                    Spacer(minLength: fw)
                    Rectangle().fill(Color.black.opacity(0.48)).frame(width: hPad)
                }
            }
            if vPad > 1 {
                VStack(spacing: 0) {
                    Rectangle().fill(Color.black.opacity(0.48)).frame(height: vPad)
                    Spacer(minLength: fh)
                    Rectangle().fill(Color.black.opacity(0.48)).frame(height: vPad)
                }
            }
            RoundedRectangle(cornerRadius: 2)
                .stroke(Color.white.opacity(0.35), lineWidth: 1)
                .frame(width: fw, height: fh)
        }
        .allowsHitTesting(false)
    }
}

// MARK: - UIImage helpers
// Free functions (not extension methods) so they can be called from nonisolated contexts.

/// Redraws the image upright regardless of EXIF orientation.
/// Safe to call on any thread — uses Core Graphics only.
func cameraFixOrientation(_ image: UIImage) -> UIImage {
    guard image.imageOrientation != .up else { return image }
    UIGraphicsBeginImageContextWithOptions(image.size, false, image.scale)
    defer { UIGraphicsEndImageContext() }
    image.draw(in: CGRect(origin: .zero, size: image.size))
    return UIGraphicsGetImageFromCurrentImageContext() ?? image
}

/// Returns a horizontally mirrored copy.
/// Safe to call on any thread — uses Core Graphics only.
func cameraMirrorImage(_ image: UIImage) -> UIImage {
    UIGraphicsBeginImageContextWithOptions(image.size, false, image.scale)
    defer { UIGraphicsEndImageContext() }
    guard let ctx = UIGraphicsGetCurrentContext() else { return image }
    ctx.translateBy(x: image.size.width, y: 0)
    ctx.scaleBy(x: -1, y: 1)
    image.draw(in: CGRect(origin: .zero, size: image.size))
    return UIGraphicsGetImageFromCurrentImageContext() ?? image
}

// UIImage convenience wrappers (MainActor-safe usage in SwiftUI)
extension UIImage {
    func fixedOrientation() -> UIImage { cameraFixOrientation(self) }
    func mirrored()          -> UIImage { cameraMirrorImage(self) }
}
