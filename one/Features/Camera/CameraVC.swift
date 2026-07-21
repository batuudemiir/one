//
//  CameraVC.swift
//  one
//
//  AVFoundation camera controller: session, gestures, capture, CoreMotion.
//  Extracted from CameraView.swift as part of Faz 3 decomposition.
//

import UIKit
import AVFoundation
import MediaPlayer
import CoreMotion
import SwiftUI

// Scalar clamping — keeps value within a ClosedRange.
extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}

// MARK: - LivePreviewView (UIViewControllerRepresentable)

struct LivePreviewView: UIViewControllerRepresentable {
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

        let startZoom: CGFloat = switchFactors.first ?? mn
        let z = startZoom.clamped(to: mn...mx)
        localMinZoom = mn; localMaxZoom = mx; currentZoom = z; baseZoom = z
        try? dev.lockForConfiguration()
        dev.videoZoomFactor = z
        dev.unlockForConfiguration()

        let presets = buildLensPresets(min: mn, max: mx, switchFactors: switchFactors)
        let wideFactor = switchFactors.first ?? mn
        DispatchQueue.main.async { [weak self] in
            guard let s = self else { return }
            s.camState.minZoom = mn; s.camState.maxZoom = mx; s.camState.zoom = z
            s.camState.lensPresets = presets
            s.camState.wideZoomFactor = wideFactor
            // Base focal length: 26mm for wide, 13mm for ultra-wide base
            s.camState.baseFocalMM = switchFactors.isEmpty ? 26 : 26
        }
    }

    private func buildLensPresets(min: CGFloat, max: CGFloat, switchFactors: [CGFloat]) -> [(factor: CGFloat, label: String)] {
        guard !switchFactors.isEmpty else {
            var result: [(CGFloat, String)] = [(min, "1×")]
            if max >= min * 2 { result.append((min * 2, "2×")) }
            return result
        }
        var result: [(CGFloat, String)] = []
        result.append((min, "0.5×"))
        let wideZoom = switchFactors[0]
        result.append((wideZoom, "1×"))
        if switchFactors.count >= 2 {
            let teleZoom = switchFactors[1]
            let ratio = (teleZoom / wideZoom).rounded()
            let label = ratio >= 2 ? "\(Int(ratio))×" : "2×"
            result.append((teleZoom, label))
        }
        if switchFactors.count == 1 {
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
            ONEHaptics.moodSelected()
            return
        }

        ONEHaptics.moodSelected()
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

        ONEHaptics.feelingSelected()
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

    // MARK: Focus square

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

    // MARK: Zoom preset

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

    private func setupVolumeShutter() {
        let vv = MPVolumeView(frame: CGRect(x: -500, y: -500, width: 1, height: 1))
        vv.alpha = 0.001
        view.addSubview(vv)
        volView = vv
    }

    private func startVolumeObserver() {
        guard volObs == nil else { return }
        let sess = AVAudioSession.sharedInstance()
        // setActive(_:) main thread'de bloklayabiliyor — kamera açılışını geciktiriyordu.
        DispatchQueue.global(qos: .userInitiated).async {
            try? sess.setCategory(.playAndRecord, options: [.mixWithOthers, .defaultToSpeaker])
            try? sess.setActive(true)
        }
        lastVol = sess.outputVolume

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

    // MARK: CoreMotion

    private func startMotion() {
        guard motion.isDeviceMotionAvailable else { return }
        motion.deviceMotionUpdateInterval = 0.1
        motion.startDeviceMotionUpdates(to: .main) { [weak self] m, _ in
            guard let self, let m else { return }
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

        let flashMode = camState.flash.avMode
        if camPos == .front, camState.flash != .off {
            frontScreenFlashThenCapture()
            return
        }

        flashScreen()
        capturePhoto(flashMode: flashMode)
    }

    private func capturePhoto(flashMode: AVCaptureDevice.FlashMode) {
        sq.async { [weak self] in
            guard let self else { return }
            let settings = AVCapturePhotoSettings()
            if self.photoOut.supportedFlashModes.contains(flashMode) {
                settings.flashMode = flashMode
            }
            self.photoOut.capturePhoto(with: settings, delegate: self)
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

    private func frontScreenFlashThenCapture() {
        guard let w = view.window else {
            capturePhoto(flashMode: .off)
            return
        }

        let fl = UIView(frame: w.bounds)
        fl.backgroundColor = .white
        fl.alpha = 0
        fl.isUserInteractionEnabled = false
        w.addSubview(fl)

        UIView.animate(withDuration: 0.12, delay: 0, options: .curveEaseOut) {
            fl.alpha = 1
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) { [weak self] in
            self?.capturePhoto(flashMode: .off)
        }

        UIView.animate(withDuration: 0.24, delay: 0.38, options: .curveEaseInOut) {
            fl.alpha = 0
        } completion: { _ in
            fl.removeFromSuperview()
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
        if haptic { ONEHaptics.moodSelected() }
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
        ONEHaptics.tabSwitch()
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
                self.camState.flashOK  = (next == .front) || inp.device.hasFlash
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

// MARK: - UIImage helpers

func fixImageOrientation(_ img: UIImage) -> UIImage {
    guard img.imageOrientation != .up else { return img }
    UIGraphicsBeginImageContextWithOptions(img.size, false, img.scale)
    defer { UIGraphicsEndImageContext() }
    img.draw(in: CGRect(origin: .zero, size: img.size))
    return UIGraphicsGetImageFromCurrentImageContext() ?? img
}

func mirrorImage(_ img: UIImage) -> UIImage {
    UIGraphicsBeginImageContextWithOptions(img.size, false, img.scale)
    defer { UIGraphicsEndImageContext() }
    guard let ctx = UIGraphicsGetCurrentContext() else { return img }
    ctx.translateBy(x: img.size.width, y: 0); ctx.scaleBy(x: -1, y: 1)
    img.draw(in: CGRect(origin: .zero, size: img.size))
    return UIGraphicsGetImageFromCurrentImageContext() ?? img
}
