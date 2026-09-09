//
//  V3CameraView.swift
//  one
//
//  v3 kamera — prototipteki minimal düzen:
//   - Paper (bone) zemin
//   - 3:4 dikey vizör kartı (radius 28), koyu gradient overlay
//   - Üst: flaş + ızgara cam çipleri (vizör içinde)
//   - Alt kenar: 6pt mood renk şeridi
//   - Bottom bar (vizör dışında): 52pt galeri | 74pt deklanşör | 52pt front/back
//   - Deklanşörün altında "Ön kamera" / "Arka kamera" mikro etiket
//
//  Karmaşık film preset / exposure / timer / zoom pill'leri KALDIRILDI.
//  Kullanıcı istediği zaman kaydeder. Sonrası tek adım: "Bu anı kullan / Değiştir".
//

import SwiftUI
import PhotosUI
import UIKit
import AVFoundation

struct V3CameraView: View {
    @Binding var image: UIImage?
    var moodColor: Color = ONEBrand.kor    // Alt şerit rengi (an akışında seçili mood).
    @Environment(\.dismiss) private var dismiss

    @StateObject private var state = CameraState()
    @State private var perm: CameraPermState = .checking
    @State private var captured: UIImage? = nil
    @State private var showPreview = false
    @State private var showGalleryPicker = false
    @State private var galleryPickerItem: PhotosPickerItem?

    var body: some View {
        ZStack {
            V3Tokens.paper.ignoresSafeArea()

            VStack(spacing: 0) {
                topBar

                content

                Spacer(minLength: 0)
            }
        }
        .statusBarHidden(false)
        .onAppear(perform: checkPerm)
        .photosPicker(isPresented: $showGalleryPicker, selection: $galleryPickerItem, matching: .images)
        .onChange(of: galleryPickerItem) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self),
                   let ui = UIImage(data: data) {
                    await MainActor.run {
                        image = ui
                        dismiss()
                    }
                }
            }
        }
    }

    // MARK: - Üst çubuk

    /// Uygulamadaki beşinci ve son "kendi çubuğunu çizen" ekrandı.
    ///
    /// Dördü birden yanlıştı: kapatma bir **metin kapsülüydü** ("← Kapat",
    /// kendi ok karakteriyle) — her yerdeki dairesel xmark değil; başlık
    /// **ortalanmıştı** — diğer her ekranda sola dayalı; iki dize de
    /// **yerelleştirilmemişti**, yani dokuz dilin sekizinde Türkçe kalıyordu;
    /// ve sağdaki boşluğu ortalamayı ayakta tutmak için 60×32'lik sahte bir
    /// `Color.clear` dolduruyordu — düzen kendi kendini taşımıyordu.
    private var topBar: some View {
        V3TopBar(
            leading: .close { dismiss() },
            title: NSLocalizedString("screen.camera.title", comment: ""),
            progress: 0
        )
    }

    // MARK: - Content router

    @ViewBuilder
    private var content: some View {
        switch perm {
        case .authorized:
            if showPreview, let raw = captured {
                previewScreen(raw)
                    .transition(.opacity)
                    .padding(.horizontal, V3Tokens.channel)
                    .padding(.top, V3Tokens.spacingXL)
            } else {
                captureScreen
                    .padding(.horizontal, V3Tokens.channel)
                    .padding(.top, V3Tokens.spacingXL)
            }
        case .checking:
            V3Loading(.region)
                .padding(.top, 120)
        case .denied:
            deniedScreen
                .padding(.horizontal, V3Tokens.channel)
                .padding(.top, 60)
        }
    }

    // MARK: - Capture screen

    private var captureScreen: some View {
        VStack(spacing: V3Tokens.spacingXL) {
            // Viewfinder card — 3:4 aspect, dark ground.
            ZStack {
                // Ön izleme (AVCaptureSession).
                LivePreviewView(
                    state: state,
                    // 9:16 çekim: story'ye kırpmasız gitsin. Kartta 4:5
                    // gösteriliyor (bkz. V3MomentCard.canvasAspect) — çekim
                    // oranı ile gösterim oranı bilinçli olarak ayrı.
                    ratio: .story,
                    onPhoto: handleCapture,
                    onDismiss: { dismiss() }
                )
                .aspectRatio(CaptureRatio.story.wh, contentMode: .fit)
                .background(
                    LinearGradient(
                        stops: [
                            .init(color: V3Tokens.darkHairline, location: 0),
                            .init(color: V3Tokens.darkGround, location: 0.62),
                            .init(color: V3Tokens.darkWash, location: 1)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: V3Tokens.radiusTile, style: .continuous))

                // 33% grid overlay (spec).
                if state.grid {
                    GridOverlay()
                        .stroke(Color.white.opacity(0.16), lineWidth: 1)
                        .allowsHitTesting(false)
                }

                // Top chips — flash + grid (vizör içinde).
                VStack {
                    HStack(spacing: V3Tokens.spacingSM) {
                        chip(active: state.flash != .off, label: state.flash == .off ? NSLocalizedString("camera.flashOff", comment: "") : NSLocalizedString("camera.flashOn", comment: "")) {
                            state.cycleFlash()
                        }
                        chip(active: state.grid, label: state.grid ? NSLocalizedString("camera.gridOn", comment: "") : NSLocalizedString("camera.gridOff", comment: "")) {
                            state.toggleGrid()
                        }
                        Spacer()
                    }
                    .padding(14)
                    Spacer()
                }
                .allowsHitTesting(true)

                // Alt kenar mood şeridi (spec: 6pt).
                VStack {
                    Spacer()
                    Rectangle().fill(moodColor).frame(height: 6)
                }
                .allowsHitTesting(false)
                .clipShape(RoundedRectangle(cornerRadius: V3Tokens.radiusTile, style: .continuous))
            }
            .aspectRatio(CaptureRatio.story.wh, contentMode: .fit)

            // Bottom bar: galeri | shutter | front/back
            HStack {
                sideBtn(systemImage: "photo.on.rectangle") {
                    showGalleryPicker = true
                }
                Spacer()
                shutterBtn
                Spacer()
                sideBtn(systemImage: "arrow.triangle.2.circlepath.camera") {
                    state.isFront.toggle()
                }
            }

            Text(state.isFront ? NSLocalizedString("camera.front", comment: "") : NSLocalizedString("camera.back", comment: ""))
                .monoLabel(weight: .regular)
                .tracking(1.3)
                .textCase(.uppercase)
                .foregroundColor(V3Tokens.faintText)
        }
    }

    // MARK: - Preview after capture

    private func previewScreen(_ raw: UIImage) -> some View {
        VStack(spacing: 18) {
            ZStack {
                Image(uiImage: raw)
                    .resizable()
                    .aspectRatio(CaptureRatio.story.wh, contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: V3Tokens.radiusTile, style: .continuous))

                VStack {
                    Spacer()
                    Rectangle().fill(moodColor).frame(height: 6)
                }
                .allowsHitTesting(false)
                .clipShape(RoundedRectangle(cornerRadius: V3Tokens.radiusTile, style: .continuous))
            }

            HStack(spacing: 10) {
                Button {
                    ONEHaptics.commit()
                    image = raw
                    dismiss()
                } label: {
                    Text(NSLocalizedString("camera.useThisMoment", comment: ""))
                        .bodyLGSemibold()
                        .foregroundColor(V3Tokens.paper)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(Capsule().fill(V3Tokens.ink))
                }
                .buttonStyle(.onePressable)

                Button {
                    withAnimation(.easeInOut(duration: 0.16)) { showPreview = false }
                    captured = nil
                } label: {
                    Text(NSLocalizedString("general.change", comment: ""))
                        .bodyMDMedium()
                        .foregroundColor(V3Tokens.mutedText)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 18)
                        .overlay(Capsule().stroke(V3Tokens.hairline, lineWidth: 1))
                }
                .contentShape(Rectangle())
                .buttonStyle(.onePressable)
            }
        }
    }

    // MARK: - Permission denied

    private var deniedScreen: some View {
        VStack(spacing: 14) {
            Image(systemName: "camera.slash")
                .font(.system(size: 34, weight: .light))
                .foregroundColor(V3Tokens.mutedText)
            Text(NSLocalizedString("camera.noAccess", comment: ""))
                .font(ONEBrand.display(20))
                .tracking(-0.4)
                .foregroundColor(V3Tokens.ink)
            Text(NSLocalizedString("camera.grantInSettings", comment: ""))
                .bodySM()
                .foregroundColor(V3Tokens.mutedText)
            Button {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            } label: {
                Text(NSLocalizedString("general.openSettings", comment: ""))
                    .bodyMDSemibold()
                    .foregroundColor(V3Tokens.paper)
                    .padding(.horizontal, V3Tokens.spacingXL).padding(.vertical, V3Tokens.spacingMD)
                    .background(Capsule().fill(V3Tokens.ink))
            }
            .buttonStyle(.onePressable)
        }
    }

    // MARK: - Components

    private var shutterBtn: some View {
        Button {
            state.shoot()
        } label: {
            Circle()
                .fill(V3Tokens.surface)
                .frame(width: 74, height: 74)
                .overlay(
                    Circle().stroke(V3Tokens.hairline, lineWidth: 4).padding(-4)
                )
                .scaleEffect(state.capturing ? 0.94 : 1.0)
                .animation(ONEAnimation.buttonReleaseAnimation, value: state.capturing)
        }
        .buttonStyle(.onePressable)
        .disabled(state.capturing)
    }

    private func sideBtn(systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .iconLG(weight: .medium)
                .foregroundColor(V3Tokens.mutedText)
                .frame(width: 52, height: 52)
                .overlay(
                    RoundedRectangle(cornerRadius: V3Tokens.radiusCard, style: .continuous)
                        .stroke(V3Tokens.hairline, lineWidth: 1)
                )
        }
        .contentShape(Rectangle())
        .buttonStyle(.onePressable)
    }

    private func chip(active: Bool, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .monoSM(weight: .semibold)
                .tracking(1.0)
                .textCase(.uppercase)
                .foregroundColor(active ? ONEBrand.ink : ONEBrand.bone)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(active ? Color(red: 0.984, green: 0.980, blue: 0.969).opacity(0.92) : Color(red: 0.047, green: 0.047, blue: 0.063).opacity(0.34))
                        .background(Capsule().glassFill(opaque: Color(red: 0.047, green: 0.047, blue: 0.063)))
                )
        }
        .buttonStyle(.onePressable)
    }

    // MARK: - Helpers

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
        DispatchQueue.main.async {
            captured = raw
            withAnimation(ONEAnimation.screenTransition) { showPreview = true }
        }
    }
}

// MARK: - Grid overlay shape

private struct GridOverlay: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let cols = 3
        let rows = 3
        for i in 1..<cols {
            let x = rect.width * CGFloat(i) / CGFloat(cols)
            p.move(to: CGPoint(x: x, y: 0))
            p.addLine(to: CGPoint(x: x, y: rect.height))
        }
        for i in 1..<rows {
            let y = rect.height * CGFloat(i) / CGFloat(rows)
            p.move(to: CGPoint(x: 0, y: y))
            p.addLine(to: CGPoint(x: rect.width, y: y))
        }
        return p
    }
}
