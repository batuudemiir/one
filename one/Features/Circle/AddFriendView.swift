//
//  AddFriendView.swift
//  one
//

import SwiftUI
import CloudKit
import AVFoundation
import CoreImage.CIFilterBuiltins

struct AddFriendView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var cloudKitManager = CloudKitManager.shared

    // Optional prefilled code from Deep Link
    var prefilledCode: String?

    @State private var inviteCode = ""
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var isLoading = false
    @State private var showSuccess = false
    @State private var successMessage = ""
    @State private var showQRCode = false
    @State private var showQRScanner = false

    // Deep link welcome card
    @State private var inviterUser: CKRecord? = nil
    @State private var isLookingUpInviter = false

    // Cancel pending request
    @State private var showCancelAlert = false
    @State private var pendingUserIDToCancel = ""
    @State private var pendingUserName = ""

    // Copy feedback
    @State private var codeCopied = false
    @State private var showInviteShareSheet = false

    var myInviteCode: String {
        cloudKitManager.currentUser?["inviteCode"] as? String ?? "------"
    }

    var body: some View {
        NavigationView {
            ZStack {
                ONETokens.oneCream.ignoresSafeArea()

                if prefilledCode != nil {
                    // ── Deep link karşılama modu ──────────────────
                    if showSuccess {
                        ScrollView { successSection.padding(.horizontal, 24) }
                    } else if isLookingUpInviter {
                        VStack(spacing: 14) {
                            ProgressView().scaleEffect(1.1).tint(ONETokens.oneAsh)
                            Text("Davet bilgileri yükleniyor…")
                                .monoBase()
                                .foregroundColor(ONETokens.oneAsh)
                        }
                    } else if inviterUser != nil {
                        inviteWelcomeView
                    } else {
                        mainContent
                    }
                } else {
                    mainContent
                }
            }
            .navigationTitle("Davet Et")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Kapat") { dismiss() }
                        .foregroundColor(ONETokens.oneAsh)
                }
            }
            .alert("İstek Zaten Gönderildi", isPresented: $showCancelAlert) {
                Button("İsteği Geri Çek", role: .destructive) { cancelPendingRequest() }
                Button("Vazgeç", role: .cancel) { }
            } message: {
                Text("\(pendingUserName) adlı kullanıcıya zaten davet gönderdin. Bu isteği geri çekmek ister misin?")
            }
            .alert("Hata", isPresented: $showError) {
                Button("Tamam", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
            .sheet(isPresented: $showQRCode) {
                QRCodeView(code: myInviteCode)
            }
            .sheet(isPresented: $showQRScanner) {
                QRScannerView { scannedCode in
                    inviteCode = scannedCode
                    showQRScanner = false
                    addFriend()
                }
            }
            .sheet(isPresented: $showInviteShareSheet) {
                InviteShareSheet(
                    inviteCode: myInviteCode,
                    userName: cloudKitManager.currentUser?["name"] as? String ?? "BİRİ"
                )
            }
            .onAppear {
                initializeUser()
                if let prefilled = prefilledCode, !prefilled.isEmpty {
                    inviteCode = prefilled.uppercased()
                    isLookingUpInviter = true
                    cloudKitManager.findUserByInviteCode(prefilled.uppercased()) { result in
                        DispatchQueue.main.async {
                            isLookingUpInviter = false
                            if case .success(let user) = result {
                                withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) {
                                    inviterUser = user
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Ana içerik

    private var mainContent: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {

                // ── Senin kodun ──────────────────────────────────
                VStack(alignment: .leading, spacing: 8) {
                    Text("SENİN KODUN")
                        .monoLabel(tracking: 2.0)
                        .foregroundColor(ONETokens.oneAsh)

                    Button(action: copyInviteCode) {
                        Text(myInviteCode)
                            .font(.system(size: 46, weight: .bold, design: .monospaced))
                            .tracking(10)
                            .foregroundColor(codeCopied ? ONETokens.oneGreen : ONETokens.oneInk)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.plain)
                    .animation(ONEAnimation.micro, value: codeCopied)

                    HStack(spacing: 5) {
                        Image(systemName: codeCopied ? "checkmark" : "doc.on.doc")
                            .font(.system(size: 10, weight: .medium))
                        Text(codeCopied ? "Kopyalandı" : "Koda dokunarak kopyala")
                            .monoLabel(tracking: 0.4)
                    }
                    .foregroundColor(codeCopied ? ONETokens.oneGreen : ONETokens.oneMist)
                    .animation(ONEAnimation.micro, value: codeCopied)
                }
                .padding(.horizontal, 24)
                .padding(.top, 28)
                .padding(.bottom, 20)

                // Eylem butonları
                HStack(spacing: 10) {
                    codeActionButton("Paylaş", icon: "square.and.arrow.up") {
                        showInviteShareSheet = true
                    }
                    codeActionButton("QR Göster", icon: "qrcode") {
                        showQRCode = true
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 32)

                // ── Divider ──────────────────────────────────────
                Rectangle()
                    .fill(ONETokens.oneSilver)
                    .frame(height: 1)
                    .padding(.horizontal, 24)

                // ── Arkadaş kodu gir ─────────────────────────────
                if showSuccess {
                    successSection
                        .padding(.horizontal, 24)
                        .padding(.top, 28)
                } else {
                    VStack(alignment: .leading, spacing: 14) {

                        Text("ARKADAŞININ KODU")
                            .monoLabel(tracking: 2.0)
                            .foregroundColor(ONETokens.oneAsh)
                            .padding(.top, 28)

                        // Input
                        ZStack(alignment: .trailing) {
                            TextField("ABC123", text: $inviteCode)
                                .textFieldStyle(.plain)
                                .autocapitalization(.allCharacters)
                                .font(.system(size: 28, weight: .semibold, design: .monospaced))
                                .tracking(6)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 14)
                                .padding(.trailing, inviteCode.isEmpty ? 80 : 0)
                                .background(
                                    RoundedRectangle(cornerRadius: 13)
                                        .fill(ONETokens.oneSilver)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 13)
                                                .stroke(
                                                    inviteCode.count == 6 ? ONETokens.oneGreen : Color.clear,
                                                    lineWidth: 1.5
                                                )
                                        )
                                )
                                .onChange(of: inviteCode) { _, newValue in
                                    var processed = newValue.uppercased()
                                        .filter { $0.isLetter || $0.isNumber }
                                    if processed.count > 6 { processed = String(processed.prefix(6)) }
                                    if inviteCode != processed { inviteCode = processed }
                                    if processed.count == 6 {
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                                            guard inviteCode.count == 6, !isLoading, !showSuccess else { return }
                                            addFriend()
                                        }
                                    }
                                }
                                .onSubmit { addFriend() }

                            if inviteCode.isEmpty {
                                Button(action: pasteFromClipboard) {
                                    HStack(spacing: 4) {
                                        Image(systemName: "doc.on.clipboard")
                                            .font(.system(size: 10))
                                        Text("Yapıştır")
                                            .monoLabel(tracking: 0.3)
                                    }
                                    .foregroundColor(ONETokens.oneAsh)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(Capsule().fill(ONETokens.oneCreamMid))
                                }
                                .padding(.trailing, 12)
                                .transition(.opacity.combined(with: .scale(scale: 0.9)))
                            }
                        }
                        .animation(ONEAnimation.micro, value: inviteCode.isEmpty)

                        // Karakter sayacı
                        HStack {
                            Spacer()
                            Text("\(inviteCode.count)/6")
                                .monoLabel(tracking: 0.3)
                                .foregroundColor(inviteCode.count == 6 ? ONETokens.oneGreen : ONETokens.oneMist)
                                .animation(ONEAnimation.micro, value: inviteCode.count)
                        }

                        // Gönder butonu
                        Button(action: addFriend) {
                            HStack(spacing: 8) {
                                if isLoading {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        .scaleEffect(0.85)
                                } else {
                                    Text("Davet Gönder")
                                        .monoSM(tracking: 1.2)
                                }
                            }
                            .foregroundColor(ONETokens.oneCream)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(inviteCode.count == 6 ? ONETokens.oneInk : ONETokens.oneSilver)
                            )
                        }
                        .disabled(inviteCode.count != 6 || isLoading)
                        .animation(ONEAnimation.micro, value: inviteCode.count == 6)

                        // QR tara
                        Button(action: { showQRScanner = true }) {
                            HStack(spacing: 10) {
                                Image(systemName: "qrcode.viewfinder")
                                    .font(.system(size: 16, weight: .light))
                                    .foregroundColor(ONETokens.oneAsh)
                                Text("QR Kod Tara")
                                    .bodyMD()
                                    .foregroundColor(ONETokens.oneShadow)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(ONETokens.oneMist)
                            }
                            .padding(.vertical, 14)
                        }
                        .buttonStyle(ScaleButtonStyle())

                    }
                    .padding(.horizontal, 24)
                }

                Color.clear.frame(height: 40)
            }
        }
        .scrollDismissesKeyboard(.interactively)
    }

    // MARK: - Eylem butonu yardımcısı

    private func codeActionButton(_ label: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .medium))
                Text(label)
                    .monoSM(tracking: 0.8)
            }
            .foregroundColor(ONETokens.oneShadow)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                Capsule()
                    .fill(ONETokens.oneSilver)
                    .overlay(Capsule().stroke(ONETokens.oneCreamMid, lineWidth: 1))
            )
        }
        .buttonStyle(ScaleButtonStyle())
    }

    // MARK: - Davet Karşılama

    private var inviteWelcomeView: some View {
        let name     = inviterUser?["displayName"] as? String ?? "Birisi"
        let colorHex = inviterUser?["avatarColor"]  as? String ?? "#888888"
        let initial  = String(name.prefix(1)).uppercased()

        return VStack(spacing: 0) {
            Spacer()
            VStack(spacing: 36) {
                ZStack {
                    Circle()
                        .fill(Color(hex: colorHex))
                        .frame(width: 88, height: 88)
                    Text(initial)
                        .displayXL()
                        .foregroundColor(.white.opacity(0.9))
                }

                VStack(spacing: 10) {
                    Text("\(name) seni çevresine\ndavet etti.")
                        .displayLG()
                        .foregroundColor(ONETokens.oneInk)
                        .multilineTextAlignment(.center)
                        .lineSpacing(3)

                    Text("Hisset. Keşfet. Paylaş.")
                        .monoSM(tracking: 0.6)
                        .foregroundColor(ONETokens.oneAsh)
                }

                VStack(spacing: 12) {
                    Button(action: acceptInvite) {
                        HStack(spacing: 8) {
                            if isLoading {
                                ProgressView().tint(ONETokens.oneCream).scaleEffect(0.85)
                            } else {
                                Text("Çevreye Katıl")
                                    .monoSM(tracking: 1.0)
                            }
                        }
                        .foregroundColor(ONETokens.oneCream)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(RoundedRectangle(cornerRadius: 14).fill(ONETokens.oneInk))
                    }
                    .disabled(isLoading)
                    .buttonStyle(ScaleButtonStyle())

                    Button(action: { dismiss() }) {
                        Text("Şimdi değil")
                            .monoSM(tracking: 0.5)
                            .foregroundColor(ONETokens.oneAsh)
                    }
                }
            }
            .padding(.horizontal, 36)
            Spacer()
        }
    }

    private func acceptInvite() {
        guard let user = inviterUser else { return }
        let userID      = user["userID"]      as? String ?? ""
        let displayName = user["displayName"] as? String ?? "Birisi"

        isLoading = true
        cloudKitManager.sendFriendRequest(toUserID: userID) { result in
            isLoading = false
            switch result {
            case .success:
                withAnimation(ONEAnimation.micro) {
                    successMessage = "\(displayName) adlı kullanıcıya istek gönderildi!"
                    showSuccess    = true
                    inviterUser    = nil
                }
            case .failure(let error):
                errorMessage = error.localizedDescription
                showError    = true
            }
        }
    }

    // MARK: - Başarı bölümü

    private var successSection: some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 44))
                .foregroundColor(ONETokens.oneGreen)

            Text("İstek Gönderildi!")
                .displayMD()
                .foregroundColor(ONETokens.oneInk)

            Text(successMessage)
                .monoSM(tracking: 0)
                .multilineTextAlignment(.center)
                .foregroundColor(ONETokens.oneAsh)

            Text("Kabul edildiğinde bugünkü şarkılarınızı\naynı çevrede paylaşabileceksiniz.")
                .monoSM(tracking: 0)
                .multilineTextAlignment(.center)
                .foregroundColor(ONETokens.oneMist)
                .padding(.top, 4)

            Button(action: {
                withAnimation(ONEAnimation.micro) { showSuccess = false; inviteCode = "" }
            }) {
                Text("Başka birini ekle")
                    .monoSM(tracking: 1.0)
                    .foregroundColor(ONETokens.oneInk)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(
                        Capsule()
                            .stroke(ONETokens.oneCreamMid, lineWidth: 1.5)
                    )
            }
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Kopyala / Yapıştır

    private func copyInviteCode() {
        UIPasteboard.general.string = myInviteCode
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        withAnimation(ONEAnimation.micro) { codeCopied = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation(ONEAnimation.micro) { codeCopied = false }
        }
    }

    private func pasteFromClipboard() {
        guard let raw = UIPasteboard.general.string else { return }
        let cleaned = String(raw.uppercased().filter { $0.isLetter || $0.isNumber }.prefix(6))
        guard !cleaned.isEmpty else { return }
        inviteCode = cleaned
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    // MARK: - Actions

    private func initializeUser() {
        guard cloudKitManager.currentUser == nil else { return }
        cloudKitManager.createOrFetchUser(displayName: "ONE User") { result in
            switch result {
            case .success:
                ONELogger.success("User initialized", category: .circle)
            case .failure(let error):
                ONELogger.error("User initialization failed", error: error, category: .circle)
                DispatchQueue.main.async {
                    self.errorMessage = "Kullanıcı oluşturulamadı. iCloud bağlantınızı kontrol edin."
                    self.showError = true
                }
            }
        }
    }

    private func addFriend() {
        guard inviteCode.count == 6 else { return }
        isLoading = true

        cloudKitManager.findUserByInviteCode(inviteCode.uppercased()) { result in
            switch result {
            case .success(let user):
                let userID      = user["userID"]      as? String ?? ""
                let displayName = user["displayName"] as? String ?? "Bilinmeyen"

                cloudKitManager.sendFriendRequest(toUserID: userID) { result in
                    isLoading = false
                    switch result {
                    case .success:
                        UINotificationFeedbackGenerator().notificationOccurred(.success)
                        withAnimation(ONEAnimation.micro) {
                            successMessage = "\(displayName) adlı kullanıcıya istek gönderildi!"
                            showSuccess = true
                        }
                        inviteCode = ""
                    case .failure(let error):
                        let nsError = error as NSError
                        if nsError.code == -2 {
                            pendingUserIDToCancel = userID
                            pendingUserName = displayName
                            showCancelAlert = true
                        } else {
                            UINotificationFeedbackGenerator().notificationOccurred(.error)
                            errorMessage = error.localizedDescription
                            showError = true
                        }
                    }
                }
            case .failure:
                isLoading = false
                UINotificationFeedbackGenerator().notificationOccurred(.error)
                #if DEBUG
                errorMessage = "Kullanıcı bulunamadı.\n\nKod: \(inviteCode.uppercased())\n\nHer iki kullanıcı da aynı uygulama versiyonunu kullanmalı."
                #else
                errorMessage = "Kullanıcı bulunamadı. Kodu kontrol et."
                #endif
                showError = true
            }
        }
    }

    private func cancelPendingRequest() {
        guard !pendingUserIDToCancel.isEmpty else { return }
        isLoading = true
        cloudKitManager.cancelFriendRequest(toUserID: pendingUserIDToCancel) { result in
            isLoading = false
            switch result {
            case .success:
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                withAnimation(ONEAnimation.micro) {
                    successMessage = "Arkadaşlık isteği geri çekildi."
                    showSuccess = true
                }
                inviteCode = ""
            case .failure(let error):
                UINotificationFeedbackGenerator().notificationOccurred(.error)
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }
}

// MARK: - QR Code View

struct QRCodeView: View {
    @Environment(\.dismiss) var dismiss
    let code: String

    @State private var codeCopied = false

    private var qrImage: UIImage? {
        let deepLink = "ones://add-friend?code=\(code)"
        guard let data = deepLink.data(using: .utf8) else { return nil }
        let filter = CIFilter.qrCodeGenerator()
        filter.message = data
        filter.correctionLevel = "M"
        guard let output = filter.outputImage else { return nil }
        let scaled = output.transformed(by: CGAffineTransform(scaleX: 12, y: 12))
        let context = CIContext()
        guard let cgImage = context.createCGImage(scaled, from: scaled.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }

    var body: some View {
        NavigationView {
            ZStack {
                ONETokens.oneCream.ignoresSafeArea()

                VStack(spacing: 0) {
                    Spacer()

                    // QR kare
                    ZStack {
                        RoundedRectangle(cornerRadius: 24)
                            .fill(Color.white)
                            .frame(width: 260, height: 260)
                            .shadow(color: Color.black.opacity(0.08), radius: 24, x: 0, y: 8)

                        if let img = qrImage {
                            Image(uiImage: img)
                                .interpolation(.none)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 210, height: 210)
                        } else {
                            Text(code)
                                .font(.system(size: 18, weight: .bold, design: .monospaced))
                                .foregroundColor(ONETokens.oneInk)
                        }
                    }
                    .padding(.bottom, 28)

                    // Kod
                    Button(action: {
                        UIPasteboard.general.string = code
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        withAnimation(ONEAnimation.micro) { codeCopied = true }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            withAnimation(ONEAnimation.micro) { codeCopied = false }
                        }
                    }) {
                        VStack(spacing: 6) {
                            Text(code)
                                .font(.system(size: 32, weight: .bold, design: .monospaced))
                                .tracking(8)
                                .foregroundColor(codeCopied ? ONETokens.oneGreen : ONETokens.oneInk)

                            HStack(spacing: 4) {
                                Image(systemName: codeCopied ? "checkmark" : "doc.on.doc")
                                    .font(.system(size: 11))
                                Text(codeCopied ? "Kopyalandı" : "Kopyalamak için dokun")
                                    .monoLabel(tracking: 0.4)
                            }
                            .foregroundColor(codeCopied ? ONETokens.oneGreen : ONETokens.oneMist)
                        }
                        .animation(ONEAnimation.micro, value: codeCopied)
                    }
                    .buttonStyle(.plain)
                    .padding(.bottom, 16)

                    Text("Arkadaşın bu kodu tarasın")
                        .monoSM(tracking: 0.5)
                        .foregroundColor(ONETokens.oneAsh)

                    Spacer()
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Kapat") { dismiss() }
                        .foregroundColor(ONETokens.oneAsh)
                }
            }
        }
    }
}

// MARK: - QR Scanner View

struct QRScannerView: View {
    @Environment(\.dismiss) var dismiss
    let onScan: (String) -> Void

    @State private var permissionGranted = false
    @State private var permissionDenied = false

    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()

                if permissionGranted {
                    CameraQRScannerRepresentable { code in
                        onScan(code)
                        dismiss()
                    }
                    .ignoresSafeArea()

                    // Vizör overlay
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
                        Text("QR kodu çerçeve içine al")
                            .monoSM(tracking: 0)
                            .foregroundColor(.white.opacity(0.75))
                            .padding(.bottom, 60)
                    }

                } else if permissionDenied {
                    VStack(spacing: 20) {
                        Image(systemName: "camera.slash")
                            .font(.system(size: 48, weight: .ultraLight))
                            .foregroundColor(.white)
                        Text("Kamera erişimi gerekli")
                            .displaySM()
                            .foregroundColor(.white)
                        Button("Ayarlar'a Git") {
                            if let url = URL(string: UIApplication.openSettingsURLString) {
                                UIApplication.shared.open(url)
                            }
                        }
                        .monoSM(tracking: 0)
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(Capsule().stroke(Color.white.opacity(0.5), lineWidth: 1))
                    }
                } else {
                    ProgressView().tint(.white)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("İptal") { dismiss() }
                        .foregroundColor(.white)
                }
            }
            .onAppear { requestCameraPermission() }
        }
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

// MARK: - AVFoundation QR scanner wrapper

struct CameraQRScannerRepresentable: UIViewRepresentable {
    let onScan: (String) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onScan: onScan) }

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        let session = AVCaptureSession()

        guard let device = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device),
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

        context.coordinator.session = session
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
                  let value = object.stringValue else { return }

            hasScanned = true
            session?.stopRunning()
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()

            let code: String
            if let url = URL(string: value),
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

// MARK: - Preview

struct AddFriendView_Previews: PreviewProvider {
    static var previews: some View {
        AddFriendView()
    }
}
