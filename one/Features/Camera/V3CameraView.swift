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
            ONEBrand.bone.ignoresSafeArea()

            VStack(spacing: 0) {
                topBar
                    .padding(.horizontal, 24)
                    .padding(.top, 20)

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

    // MARK: - Top bar (Kapat + "Kamera" başlık)

    private var topBar: some View {
        HStack {
            Button(action: { dismiss() }) {
                Text("← Kapat")
                    .font(V3Typography.sans(14, weight: .semibold))
                    .foregroundColor(V3Tokens.mutedText)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .overlay(Capsule().stroke(V3Tokens.hairline, lineWidth: 1))
            }
            .buttonStyle(.plain)

            Spacer()

            Text("KAMERA")
                .font(V3Typography.mono(11, weight: .regular))
                .tracking(1.4)
                .textCase(.uppercase)
                .foregroundColor(V3Tokens.mutedText)

            Spacer()

            // Simetri için placeholder — sağ tarafta boşluk.
            Color.clear.frame(width: 60, height: 32)
        }
    }

    // MARK: - Content router

    @ViewBuilder
    private var content: some View {
        switch perm {
        case .authorized:
            if showPreview, let raw = captured {
                previewScreen(raw)
                    .transition(.opacity)
                    .padding(.horizontal, 24)
                    .padding(.top, 20)
            } else {
                captureScreen
                    .padding(.horizontal, 24)
                    .padding(.top, 20)
            }
        case .checking:
            ProgressView()
                .tint(V3Tokens.mutedText)
                .padding(.top, 120)
        case .denied:
            deniedScreen
                .padding(.horizontal, 24)
                .padding(.top, 60)
        }
    }

    // MARK: - Capture screen

    private var captureScreen: some View {
        VStack(spacing: 22) {
            // Viewfinder card — 3:4 aspect, dark ground.
            ZStack {
                // Ön izleme (AVCaptureSession).
                LivePreviewView(
                    state: state,
                    ratio: .standard,        // 3:4 storage
                    onPhoto: handleCapture,
                    onDismiss: { dismiss() }
                )
                .aspectRatio(3.0 / 4.0, contentMode: .fit)
                .background(
                    LinearGradient(
                        stops: [
                            .init(color: Color(hex: "#23232B"), location: 0),
                            .init(color: Color(hex: "#0C0C10"), location: 0.62),
                            .init(color: Color(hex: "#1A1A20"), location: 1)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))

                // 33% grid overlay (spec).
                if state.grid {
                    GridOverlay()
                        .stroke(Color.white.opacity(0.16), lineWidth: 1)
                        .allowsHitTesting(false)
                }

                // Top chips — flash + grid (vizör içinde).
                VStack {
                    HStack(spacing: 8) {
                        chip(active: state.flash != .off, label: state.flash == .off ? "Flaş kapalı" : "Flaş açık") {
                            state.cycleFlash()
                        }
                        chip(active: state.grid, label: state.grid ? "Izgara açık" : "Izgara kapalı") {
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
                .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
            }
            .aspectRatio(3.0 / 4.0, contentMode: .fit)

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

            Text(state.isFront ? "ÖN KAMERA" : "ARKA KAMERA")
                .font(V3Typography.mono(10, weight: .regular))
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
                    .aspectRatio(3.0 / 4.0, contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))

                VStack {
                    Spacer()
                    Rectangle().fill(moodColor).frame(height: 6)
                }
                .allowsHitTesting(false)
                .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
            }

            HStack(spacing: 10) {
                Button {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    image = raw
                    dismiss()
                } label: {
                    Text("Bu anı kullan")
                        .font(V3Typography.sans(16, weight: .semibold))
                        .foregroundColor(V3Tokens.paper)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(Capsule().fill(V3Tokens.ink))
                }
                .buttonStyle(.plain)

                Button {
                    withAnimation(.easeInOut(duration: 0.16)) { showPreview = false }
                    captured = nil
                } label: {
                    Text("Değiştir")
                        .font(V3Typography.sans(15, weight: .medium))
                        .foregroundColor(V3Tokens.mutedText)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 18)
                        .overlay(Capsule().stroke(V3Tokens.hairline, lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Permission denied

    private var deniedScreen: some View {
        VStack(spacing: 14) {
            Image(systemName: "camera.slash")
                .font(.system(size: 34, weight: .light))
                .foregroundColor(V3Tokens.mutedText)
            Text("Kamera erişimi yok")
                .font(ONEBrand.display(20))
                .tracking(-0.4)
                .foregroundColor(V3Tokens.ink)
            Text("Ayarlardan izin verebilirsin.")
                .font(V3Typography.sans(14))
                .foregroundColor(V3Tokens.mutedText)
            Button {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            } label: {
                Text("Ayarları aç")
                    .font(V3Typography.sans(15, weight: .semibold))
                    .foregroundColor(V3Tokens.paper)
                    .padding(.horizontal, 22).padding(.vertical, 12)
                    .background(Capsule().fill(V3Tokens.ink))
            }
        }
    }

    // MARK: - Components

    private var shutterBtn: some View {
        Button {
            state.shoot()
        } label: {
            Circle()
                .fill(ONEBrand.bone)
                .frame(width: 74, height: 74)
                .overlay(
                    Circle().stroke(V3Tokens.hairline, lineWidth: 4).padding(-4)
                )
                .scaleEffect(state.capturing ? 0.94 : 1.0)
                .animation(.spring(response: 0.16, dampingFraction: 0.6), value: state.capturing)
        }
        .buttonStyle(.plain)
        .disabled(state.capturing)
    }

    private func sideBtn(systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(V3Tokens.mutedText)
                .frame(width: 52, height: 52)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(V3Tokens.hairline, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }

    private func chip(active: Bool, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(V3Typography.mono(11, weight: .semibold))
                .tracking(1.0)
                .textCase(.uppercase)
                .foregroundColor(active ? ONEBrand.ink : ONEBrand.bone)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(active ? Color(red: 0.984, green: 0.980, blue: 0.969).opacity(0.92) : Color(red: 0.047, green: 0.047, blue: 0.063).opacity(0.34))
                        .background(Capsule().fill(.ultraThinMaterial))
                )
        }
        .buttonStyle(.plain)
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
            withAnimation(.spring(response: 0.32, dampingFraction: 0.8)) { showPreview = true }
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
