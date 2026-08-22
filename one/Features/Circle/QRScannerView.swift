//
//  QRScannerView.swift
//  one
//
//  Davet kodu tarayıcı. `AddFriendView.swift` içinden çıkarıldı: o ekranın
//  yerini `AddFriendScreen` aldı ve dosyada canlı kalan tek parça buydu.
//

import SwiftUI
import AVFoundation

// MARK: - QR Scanner View

struct QRScannerView: View {
    @Environment(\.dismiss) var dismiss
    let onScan: (String) -> Void

    @State private var permissionGranted = false
    @State private var permissionDenied  = false

    var body: some View {
        // Vizör tam kanamalı ve koyu; `V3SheetScreen`'in kağıt gövdesi
        // buraya uymaz. Kabuk yalnız üst çubuk: `ground: .media` varyantı
        // koyu scrim + açık glif veriyor, yani düğme kameranın üstünde de
        // okunuyor. Sistem `toolbar`'ının beyaz metin düğmesi aydınlık bir
        // kareye denk geldiğinde kayboluyordu.
        ZStack {
                Color.black.ignoresSafeArea()

                if permissionGranted {
                    CameraQRScannerRepresentable { code in
                        onScan(code)
                        dismiss()
                    }
                    .ignoresSafeArea()

                    VStack {
                        Spacer()
                        RoundedRectangle(cornerRadius: 16)
                            .strokeBorder(Color.white, lineWidth: 2)
                            .frame(width: 230, height: 230)
                            .overlay(
                                ZStack {
                                    ForEach([false, true], id: \.self) { flipH in
                                        ForEach([false, true], id: \.self) { flipV in
                                            CornerAccent()
                                                .scaleEffect(x: flipH ? -1 : 1, y: flipV ? -1 : 1)
                                        }
                                    }
                                }
                            )
                        Spacer()
                        Text(NSLocalizedString("addFriend.frameQR", comment: ""))
                            .monoSM(tracking: 0)
                            .foregroundColor(.white.opacity(0.75))
                            .padding(.bottom, 60)
                    }

                } else if permissionDenied {
                    VStack(spacing: V3Tokens.spacingXL) {
                        Image(systemName: "camera.slash")
                            .displayXXL()
                            .fontWeight(.ultraLight)
                            .foregroundColor(V3Tokens.darkText)
                        Text(NSLocalizedString("addFriend.cameraRequired", comment: ""))
                            .displaySM()
                            .foregroundColor(V3Tokens.darkText)
                        Button(NSLocalizedString("circle.goToSettings", comment: "")) {
                            if let url = URL(string: UIApplication.openSettingsURLString) {
                                UIApplication.shared.open(url)
                            }
                        }
                        .monoSM(tracking: 0)
                        .foregroundColor(V3Tokens.darkText)
                        .padding(.horizontal, V3Tokens.spacingXL)
                        .padding(.vertical, 10)
                        .background(Capsule().stroke(Color.white.opacity(0.5), lineWidth: 1))
                    }
                } else {
                    ProgressView().tint(.white)
                }
            }
        .safeAreaInset(edge: .top, spacing: 0) {
            // Bağlam etiketi yok: `V3TopBar` onu `faintText` ile çiziyor ve
            // bu ekran temadan bağımsız siyah — açık temanın faint'i orada
            // okunmuyordu. Vizörün talimatı zaten çerçevenin altında.
            V3TopBar(leading: .none, progress: 0) {
                V3TopBarIconButton(
                    systemName: "xmark",
                    label: NSLocalizedString("general.close", comment: ""),
                    ground: .media
                ) { dismiss() }
            }
        }
        .onAppear { requestCameraPermission() }
    }

    private func requestCameraPermission() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            permissionGranted = true
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    if granted { permissionGranted = true } else { permissionDenied = true }
                }
            }
        default:
            permissionDenied = true
        }
    }
}

// MARK: - Vizör köşe aksanı

private struct CornerAccent: View {
    var body: some View {
        VStack {
            HStack {
                Rectangle()
                    .fill(Color.white)
                    .frame(width: 24, height: 3)
                    .offset(x: -1)
                    .overlay(
                        Rectangle()
                            .fill(Color.white)
                            .frame(width: 3, height: 24)
                            .offset(x: -11, y: 11),
                        alignment: .leading
                    )
                Spacer()
            }
            Spacer()
        }
        .padding(1)
    }
}

// MARK: - AVFoundation QR scanner

struct CameraQRScannerRepresentable: UIViewRepresentable {
    let onScan: (String) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onScan: onScan) }

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        let session = AVCaptureSession()

        guard let device = AVCaptureDevice.default(for: .video),
              let input  = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input) else { return view }

        session.addInput(input)

        let metadataOutput = AVCaptureMetadataOutput()
        guard session.canAddOutput(metadataOutput) else { return view }
        session.addOutput(metadataOutput)
        metadataOutput.setMetadataObjectsDelegate(context.coordinator, queue: .main)
        metadataOutput.metadataObjectTypes = [.qr]

        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.videoGravity = .resizeAspectFill
        previewLayer.frame = UIScreen.main.bounds
        view.layer.addSublayer(previewLayer)

        context.coordinator.session      = session
        context.coordinator.previewLayer = previewLayer

        DispatchQueue.global(qos: .userInitiated).async { session.startRunning() }
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.previewLayer?.frame = uiView.bounds
    }

    class Coordinator: NSObject, AVCaptureMetadataOutputObjectsDelegate {
        let onScan: (String) -> Void
        var session: AVCaptureSession?
        var previewLayer: AVCaptureVideoPreviewLayer?
        private var hasScanned = false

        init(onScan: @escaping (String) -> Void) { self.onScan = onScan }

        func metadataOutput(_ output: AVCaptureMetadataOutput,
                            didOutput metadataObjects: [AVMetadataObject],
                            from connection: AVCaptureConnection) {
            guard !hasScanned,
                  let object = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
                  let value  = object.stringValue else { return }

            hasScanned = true
            session?.stopRunning()
            ONEHaptics.feelingSelected()

            let code: String
            if let url   = URL(string: value),
               let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems,
               let extracted = items.first(where: { $0.name == "code" })?.value {
                code = extracted
            } else {
                code = value
            }
            onScan(code)
        }
    }
}

