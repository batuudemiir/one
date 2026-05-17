//
//  CameraView.swift
//  one
//
//  Native iPhone camera — clean rewrite v4 (decomposed)
//  This file is the SwiftUI coordinator that ties together:
//  - CameraTypes.swift  (enums, presets)
//  - CameraState.swift  (ObservableObject)
//  - CameraVC.swift     (AVFoundation controller)
//  - CameraOverlay.swift (SwiftUI controls)
//  - CameraPreview.swift (photo preview + zoom)
//

import SwiftUI
import AVFoundation
import UIKit

// MARK: - CameraView (SwiftUI root)

struct CameraView: View {
    @Binding var image: UIImage?
    @Environment(\.dismiss) private var dismiss

    @StateObject private var state   = CameraState()
    @State private var perm:   CameraPermState = .checking
    /// Fixed to 9:16 — ONE always captures in story ratio
    private let ratio: CaptureRatio = .story
    @State private var captured: UIImage?      = nil
    @State private var showPreview             = false
    @State private var cameraKey               = UUID()
    @State private var safeTop:    CGFloat     = 0
    @State private var safeBottom: CGFloat     = 0

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            content
        }
        .ignoresSafeArea()
        .statusBarHidden(true)
        .clipShape(RoundedRectangle(cornerRadius: 44, style: .continuous))
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
            // Full-screen camera — Snapchat / Instagram style
            LivePreviewView(
                state:     state,
                ratio:     ratio,
                onPhoto:   handleCapture,
                onDismiss: { animatedDismiss() }
            )
            .id(cameraKey)
            .saturation(state.filmPreset.previewSaturation)
            .contrast(state.filmPreset.previewContrast)
            .brightness(state.filmPreset.previewBrightness)
            .ignoresSafeArea()

            CameraOverlay(
                state:      state,
                safeTop:    safeTop,
                safeBottom: safeBottom,
                onDismiss:  { animatedDismiss() }
            )
            .ignoresSafeArea()
        }
    }

    // MARK: Photo preview screen

    @ViewBuilder
    private func previewScreen(_ raw: UIImage) -> some View {
        let img = cropImage(raw, to: ratio).applyingFilmPreset(state.filmPreset)
        CameraPreviewOverlay(
            image: img,
            safeTop: safeTop,
            safeBottom: safeBottom,
            onRetake: { retake() },
            onUse: {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                image = img
                animatedDismiss()
            }
        )
    }

    // MARK: Permission denied screen

    private var deniedScreen: some View {
        VStack(spacing: 18) {
            Image(systemName: "camera.slash.fill")
                .font(.system(size: 44)).foregroundColor(.white)
            Text(NSLocalizedString("camera.permissionTitle", comment: ""))
                .displaySM().fontWeight(.semibold).foregroundColor(.white)
            Text(NSLocalizedString("camera.permissionMessage", comment: ""))
                .bodyMD().foregroundColor(.white.opacity(0.75))
                .multilineTextAlignment(.center)
            Button {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            } label: {
                Text(NSLocalizedString("camera.openSettings", comment: ""))
                    .bodyMD().fontWeight(.semibold).foregroundColor(.black)
                    .padding(.horizontal, 22).padding(.vertical, 12)
                    .background(Capsule().fill(.white))
            }
            .accessibilityLabel(NSLocalizedString("camera.openSettings", comment: ""))
            Button { dismiss() } label: {
                Text(NSLocalizedString("camera.cancel", comment: ""))
                    .bodyMD().foregroundColor(.white.opacity(0.7))
            }
            .accessibilityLabel(NSLocalizedString("camera.cancel", comment: ""))
        }.padding(.horizontal, 32)
    }

    // MARK: Helpers

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

    private func animatedDismiss() {
        guard !state.isDismissing else { return }
        withAnimation(.easeInOut(duration: 0.22)) {
            state.isDismissing = true
            showPreview = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
            dismiss()
        }
    }

    private func handleCapture(_ raw: UIImage) {
        DispatchQueue.main.async {
            captured = raw
            withAnimation(.spring(response: 0.34, dampingFraction: 0.8)) { showPreview = true }
        }
    }

    private func retake() {
        UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
        state.capturing = false
        state.isInRetakeCooldown = true
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

