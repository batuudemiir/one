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

    var prefilledCode: String?

    // Smart unified search
    @State private var smartQuery       = ""
    @State private var foundUser: CKRecord? = nil
    @State private var isSearching      = false
    @State private var userNotFound     = false

    // Result
    @State private var isLoading        = false
    @State private var showSuccess      = false
    @State private var successMessage   = ""
    @State private var showError        = false
    @State private var errorMessage     = ""

    // Deep link
    @State private var inviterUser: CKRecord?  = nil
    @State private var isLookingUpInviter      = false

    // Cancel pending
    @State private var showCancelAlert       = false
    @State private var pendingUserIDToCancel = ""
    @State private var pendingUserName       = ""

    // UI
    @State private var codeCopied           = false
    @State private var showQRCode           = false
    @State private var showQRScanner        = false
    @State private var showInviteShareSheet = false
    @State private var showContactsInvite   = false

    // MARK: - Derived

    var myInviteCode: String {
        cloudKitManager.currentUser?["inviteCode"] as? String ?? "------"
    }

    private var queryTrimmed: String { smartQuery.trimmingCharacters(in: .whitespaces) }

    private var isCodeQuery: Bool {
        let upper = queryTrimmed.uppercased().filter { $0.isLetter || $0.isNumber }
        return upper.count == 6
    }

    private var isQueryReady: Bool {
        if queryTrimmed.hasPrefix("@") { return queryTrimmed.count >= 4 }
        return isCodeQuery || queryTrimmed.count >= 3
    }

    private var searchFieldIcon: String {
        if queryTrimmed.hasPrefix("@") { return "at" }
        if isCodeQuery { return "number" }
        return "magnifyingglass"
    }

    private var searchBorderColor: Color {
        if foundUser != nil { return ONETokens.oneGreen }
        if userNotFound { return Color.red.opacity(0.4) }
        if isQueryReady { return ONETokens.oneInk.opacity(0.3) }
        return Color.clear
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack {
                ONETokens.oneCream.ignoresSafeArea()

                if prefilledCode != nil {
                    if showSuccess {
                        ScrollView { successSection.padding(.horizontal, 20) }
                    } else if isLookingUpInviter {
                        lookupLoadingView
                    } else if inviterUser != nil {
                        inviteWelcomeView
                    } else {
                        mainContent
                    }
                } else {
                    mainContent
                }
            }
            .navigationTitle(NSLocalizedString("addFriend.title", comment: ""))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(NSLocalizedString("addFriend.cancel", comment: "")) { dismiss() }
                        .foregroundColor(ONETokens.oneAsh)
                }
            }
            .alert(NSLocalizedString("addFriend.pendingTitle", comment: ""), isPresented: $showCancelAlert) {
                Button(NSLocalizedString("addFriend.withdraw", comment: ""), role: .destructive) { cancelPendingRequest() }
                Button(NSLocalizedString("addFriend.dismiss", comment: ""), role: .cancel) { }
            } message: {
                Text(String(format: NSLocalizedString("addFriend.pendingMessage", comment: ""), pendingUserName))
            }
            .alert(NSLocalizedString("general.error", comment: ""), isPresented: $showError) {
                Button(NSLocalizedString("addFriend.ok", comment: ""), role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
            .sheet(isPresented: $showQRCode) {
                QRCodeView(code: myInviteCode)
            }
            .sheet(isPresented: $showQRScanner) {
                QRScannerView { scannedCode in
                    smartQuery = scannedCode.uppercased()
                    showQRScanner = false
                    performSmartSearch()
                }
            }
            .sheet(isPresented: $showInviteShareSheet) {
                InviteShareSheet(
                    inviteCode: myInviteCode,
                    userName: cloudKitManager.currentUser?["displayName"] as? String ?? "BİRİ"
                )
            }
            .sheet(isPresented: $showContactsInvite) {
                ContactsInviteView()
            }
            .onAppear {
                initializeUser()
                if let prefilled = prefilledCode, !prefilled.isEmpty {
                    smartQuery = prefilled.uppercased()
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

    // MARK: - Main Content
    //
    // İki niyet mimarisi:
    //   1) "Seni eklesinler"  → büyük kod kartı + 3 paylaşım kanalı (SMS, link, QR göster)
    //   2) "Birini ekle"      → arama kutusu (kod/@username) + sağda QR tara aksiyonu
    //
    // Bu ayrım kullanıcının niyeti netleşir: kendi kodumu paylaşıyor muyum
    // yoksa birinin kodunu mu arıyorum? Önceki tasarımda iki niyet
    // karışıyordu — QR göster ve QR tara aynı satırdaydı.

    private var mainContent: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                // ── BÖLÜM 1: Arama ────────────────────────
                smartSearchSection
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .padding(.bottom, 24)

                // ── BÖLÜM 2: Kodunuz (Davet Gönder) ───────
                if showSuccess {
                    successSection
                        .padding(.horizontal, 20)
                } else if foundUser == nil && !isSearching {
                    
                    inviteHero
                        .padding(.horizontal, 20)
                        .padding(.bottom, 24)

                    quickShareRow
                        .padding(.horizontal, 20)
                        .padding(.bottom, 30)
                }

                Color.clear.frame(height: 60)
            }
        }
        .scrollDismissesKeyboard(.interactively)
    }

    // MARK: - Header & section helpers

    private var pageHeader: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(NSLocalizedString("addFriend.hero.title", comment: ""))
                .displayLG()
                .foregroundColor(ONETokens.oneInk)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(NSLocalizedString("addFriend.hero.subtitle", comment: ""))
                .bodySM()
                .foregroundColor(ONETokens.oneAsh)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func sectionHeader(_ text: String) -> some View {
        Text(text.uppercased())
            .monoLabel(tracking: 1.8)
            .foregroundColor(ONETokens.oneAsh)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var orDivider: some View {
        HStack(spacing: 14) {
            Rectangle()
                .fill(ONETokens.oneSilver)
                .frame(height: 1)
            Text(NSLocalizedString("addFriend.or", comment: "").uppercased())
                .monoLabel(tracking: 2.0)
                .foregroundColor(ONETokens.oneStone)
            Rectangle()
                .fill(ONETokens.oneSilver)
                .frame(height: 1)
        }
        .accessibilityHidden(true)
    }

    // MARK: - Invite Hero (kod kartı — ana CTA)
    //
    // Eski profileCard'da kullanıcının profili ve kod yan yanaydı; kod
    // küçük kalıyordu. Yeni hero kartında **kod ana kahraman**: büyük,
    // mood-tinted, tek dokunuşla kopyalanır. Kullanıcı kimliği üst
    // sırada minik bir chip olarak ikincil planda durur.
    private var inviteHero: some View {
        let displayName = cloudKitManager.currentUser?["displayName"] as? String ?? "ONE"
        let username    = cloudKitManager.currentUser?["username"]    as? String
        let colorHex    = cloudKitManager.currentUser?["avatarColor"] as? String ?? "#888888"
        let accent      = Color(hex: colorHex)
        let initial     = String(displayName.prefix(1)).uppercased()

        return VStack(spacing: 24) {
            // Identity
            VStack(spacing: 12) {
                ZStack {
                    Circle().fill(accent).frame(width: 72, height: 72)
                    Text(initial)
                        .editorialMD()
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                }
                
                VStack(spacing: 4) {
                    Text(displayName)
                        .displaySM()
                        .fontWeight(.bold)
                        .foregroundColor(ONETokens.oneInk)
                    if let uname = username, !uname.isEmpty {
                        Text("@\(uname)")
                            .bodyLG()
                            .foregroundColor(ONETokens.oneAsh)
                    }
                }
            }

            // Kod
            Button(action: copyInviteCode) {
                VStack(spacing: 10) {
                    Text(myInviteCode)
                        .displayXXL()
                        .fontWeight(.bold)
                        .tracking(10)
                        .foregroundColor(codeCopied ? ONETokens.oneGreen : ONETokens.oneInk)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)

                    HStack(spacing: 6) {
                        Image(systemName: codeCopied ? "checkmark.circle.fill" : "doc.on.doc")
                            .font(.system(size: 13, weight: .medium))
                        Text(codeCopied
                             ? NSLocalizedString("addFriend.copied", comment: "")
                             : NSLocalizedString("addFriend.tapToCopy", comment: "Kopyalamak için dokun"))
                            .bodySM()
                            .fontWeight(.medium)
                    }
                    .foregroundColor(codeCopied ? ONETokens.oneGreen : ONETokens.oneMist)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 28)
                .background(RoundedRectangle(cornerRadius: 16).fill(ONETokens.oneSilver.opacity(0.4)))
                .animation(ONEAnimation.micro, value: codeCopied)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(String(format: NSLocalizedString("addFriend.codeA11y", comment: ""), myInviteCode))
            .accessibilityHint(NSLocalizedString("addFriend.codeA11yHint", comment: ""))
        }
        .padding(.horizontal, 24)
        .padding(.top, 32)
        .padding(.bottom, 24)
        .background(
            RoundedRectangle(cornerRadius: 28)
                .fill(ONETokens.onePaper)
                .shadow(color: Color.black.opacity(0.04), radius: 16, x: 0, y: 6)
        )
    }

    // MARK: - Quick Share Row (3 kanal)
    //
    // SMS / iMessage TR Gen Z için en güçlü dağıtım kanalı — bu yüzden
    // ilk sıraya çıkarıldı (önceki tasarımda 4. butondu). QR tara
    // BÖLÜM 2'ye taşındı çünkü o "birini eklemek" niyeti.

    private var quickShareRow: some View {
        HStack(spacing: 12) {
            shareOptionBtn(
                label: NSLocalizedString("addFriend.shareSMS", comment: "Rehber"),
                icon: "person.crop.circle.badge.plus",
                primary: true
            ) { showContactsInvite = true }

            shareOptionBtn(
                label: NSLocalizedString("addFriend.share", comment: "Paylaş"),
                icon: "square.and.arrow.up"
            ) { showInviteShareSheet = true }

            shareOptionBtn(
                label: NSLocalizedString("addFriend.showQR", comment: "QR Kod"),
                icon: "qrcode"
            ) { showQRCode = true }
        }
    }

    private func shareOptionBtn(label: String, icon: String, primary: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(primary ? ONETokens.oneInk : ONETokens.oneSilver.opacity(0.6))
                        .frame(width: 56, height: 56)
                    Image(systemName: icon)
                        .displaySM()
                        .fontWeight(primary ? .regular : .medium)
                        .foregroundColor(primary ? .white : ONETokens.oneInk)
                }
                Text(label)
                    .bodySM()
                    .fontWeight(.medium)
                    .foregroundColor(ONETokens.oneInk)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(ScaleButtonStyle())
    }

    // MARK: - Smart Search Section
    //
    // Bölüm 2'nin gövdesi. Kullanıcı bir kişiyi ekliyor: kod yazar,
    // @username yazar, ya da QR tarar. Üç davranış da bu satırdan
    // erişilebilir — en sağda QR tarayıcı action olarak.

    private var smartSearchSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Arama alanı
            ZStack(alignment: .trailing) {
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .displayXS()
                        .foregroundColor(ONETokens.oneMist)

                    TextField(
                        NSLocalizedString("addFriend.searchPlaceholder", comment: ""),
                        text: $smartQuery
                    )
                    .textFieldStyle(.plain)
                    .autocapitalization(.none)
                    .autocorrectionDisabled()
                    .displayXS()
                    .fontWeight(.medium)
                    .onSubmit { performSmartSearch() }
                    .onChange(of: smartQuery) { _, newValue in
                        foundUser     = nil
                        userNotFound  = false
                        // Otomatik arama: tam 6 karakter kod girilince
                        let upper = newValue.uppercased().filter { $0.isLetter || $0.isNumber }
                        if upper.count == 6 && !newValue.hasPrefix("@") {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                guard self.isCodeQuery, !self.isSearching, !self.isLoading else { return }
                                self.performSmartSearch()
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .padding(.trailing, 50)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(ONETokens.oneSilver.opacity(0.5))
                )

                if smartQuery.isEmpty {
                    Button(action: { showQRScanner = true }) {
                        Image(systemName: "qrcode.viewfinder")
                            .displaySM()
                            .fontWeight(.light)
                            .foregroundColor(ONETokens.oneInk)
                    }
                    .padding(.trailing, 16)
                    .transition(.opacity)
                } else {
                    Button(action: performSmartSearch) {
                        ZStack {
                            Circle()
                                .fill(isQueryReady ? ONETokens.oneInk : ONETokens.oneSilver)
                                .frame(width: 36, height: 36)
                            if isSearching || isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: ONETokens.oneCream))
                                    .scaleEffect(0.7)
                            } else {
                                Image(systemName: "arrow.right")
                                    .bodySM()
                                    .fontWeight(.semibold)
                                    .foregroundColor(isQueryReady ? ONETokens.oneCream : ONETokens.oneMist)
                            }
                        }
                    }
                    .disabled(!isQueryReady || isSearching || isLoading)
                    .padding(.trailing, 6)
                    .transition(.opacity.combined(with: .scale(scale: 0.9)))
                    .animation(ONEAnimation.micro, value: isQueryReady)
                }
            }
            .animation(ONEAnimation.micro, value: smartQuery.isEmpty)

            // Bulunan kullanıcı kartı
            if let user = foundUser {
                foundUserCard(user: user)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }

            // Bulunamadı mesajı
            if userNotFound {
                HStack(spacing: 8) {
                    Image(systemName: "person.slash")
                        .font(.system(size: 13, weight: .light))
                    Text(NSLocalizedString("addFriend.usernameNotFound", comment: ""))
                        .bodySM()
                        .fontWeight(.medium)
                }
                .foregroundColor(ONETokens.oneAsh)
                .padding(.vertical, 4)
                .transition(.opacity)
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: foundUser?.recordID.recordName)
        .animation(ONEAnimation.micro, value: userNotFound)
    }

    // MARK: - Hint Chip

    private func hintChip(text: String, icon: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .medium))
            Text(text)
                .monoSM(tracking: 0.3)
                .fontWeight(.medium)
        }
        .foregroundColor(ONETokens.oneAsh)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(ONETokens.oneSilver.opacity(0.8))
                .overlay(Capsule().stroke(ONETokens.oneCreamMid, lineWidth: 1))
        )
    }

    // MARK: - Found User Card

    private func foundUserCard(user: CKRecord) -> some View {
        let name     = user["displayName"] as? String ?? "Kullanıcı"
        let colorHex = user["avatarColor"] as? String ?? "#888888"
        let uname    = user["username"]    as? String ?? ""
        let initial  = String(name.prefix(1)).uppercased()

        return HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color(hex: colorHex))
                    .frame(width: 46, height: 46)
                Text(initial)
                    .editorialMD()
                    .fontWeight(.regular)
                    .italic()
                    .foregroundColor(.white.opacity(0.9))
            }
            .overlay(alignment: .bottomTrailing) {
                ZStack {
                    Circle().fill(ONETokens.oneCream)
                    Image(systemName: "checkmark.circle.fill")
                        .bodySM()
                        .foregroundColor(ONETokens.oneGreen)
                }
                .frame(width: 20, height: 20)
                .offset(x: 3, y: 3)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .displaySM()
                    .foregroundColor(ONETokens.oneInk)
                if !uname.isEmpty {
                    Text("@\(uname)")
                        .monoLabel(tracking: 0.3)
                        .foregroundColor(ONETokens.oneAsh)
                }
            }

            Spacer()

            Button(action: sendRequestToFoundUser) {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: ONETokens.oneCream))
                        .scaleEffect(0.8)
                        .frame(width: 72, height: 36)
                } else {
                    HStack(spacing: 4) {
                        Image(systemName: "person.badge.plus")
                            .monoSM()
                            .fontWeight(.medium)
                        Text(NSLocalizedString("addFriend.addUser", comment: ""))
                            .monoSM(tracking: 0.5)
                    }
                    .foregroundColor(ONETokens.oneCream)
                    .frame(width: 72, height: 36)
                }
            }
            .background(RoundedRectangle(cornerRadius: 10).fill(ONETokens.oneInk))
            .disabled(isLoading)
            .buttonStyle(ScaleButtonStyle())
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(ONETokens.onePaper.opacity(0.6))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(ONETokens.oneGreen.opacity(0.25), lineWidth: 1.5)
                )
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(String(format: NSLocalizedString("accessibility.addFriend.foundUser", comment: ""), (user["displayName"] as? String ?? "Kullanıcı")))
    }

    // MARK: - Davet Karşılama (Deep Link)

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
                    Text(String(format: NSLocalizedString("addFriend.invitedYou", comment: ""), name))
                        .displayLG()
                        .foregroundColor(ONETokens.oneInk)
                        .multilineTextAlignment(.center)
                        .lineSpacing(3)
                    Text(NSLocalizedString("onboarding.slogan", comment: ""))
                        .monoSM(tracking: 0.6)
                        .foregroundColor(ONETokens.oneAsh)
                }

                VStack(spacing: 12) {
                    Button(action: acceptInvite) {
                        HStack(spacing: 8) {
                            if isLoading {
                                ProgressView().tint(ONETokens.oneCream).scaleEffect(0.85)
                            } else {
                                Text(NSLocalizedString("addFriend.joinCircle", comment: ""))
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
                        Text(NSLocalizedString("addFriend.notNow", comment: ""))
                            .monoSM(tracking: 0.5)
                            .foregroundColor(ONETokens.oneAsh)
                    }
                }
            }
            .padding(.horizontal, 36)
            Spacer()
        }
    }

    // MARK: - Başarı

    private var successSection: some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.circle.fill")
                .displayXXL()
                .foregroundColor(ONETokens.oneGreen)

            Text(NSLocalizedString("addFriend.requestSent", comment: ""))
                .displayMD()
                .foregroundColor(ONETokens.oneInk)

            Text(successMessage)
                .monoSM(tracking: 0)
                .multilineTextAlignment(.center)
                .foregroundColor(ONETokens.oneAsh)

            Text(NSLocalizedString("addFriend.acceptedInfo", comment: ""))
                .monoSM(tracking: 0)
                .multilineTextAlignment(.center)
                .foregroundColor(ONETokens.oneMist)
                .padding(.top, 4)

            Button(action: {
                withAnimation(ONEAnimation.micro) {
                    showSuccess  = false
                    smartQuery   = ""
                    foundUser    = nil
                    userNotFound = false
                }
            }) {
                Text(NSLocalizedString("addFriend.addAnother", comment: ""))
                    .monoSM(tracking: 1.0)
                    .foregroundColor(ONETokens.oneInk)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Capsule().stroke(ONETokens.oneCreamMid, lineWidth: 1.5))
            }
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Loading (Deep Link)

    private var lookupLoadingView: some View {
        VStack(spacing: 14) {
            ProgressView().scaleEffect(1.1).tint(ONETokens.oneAsh)
            Text(NSLocalizedString("addFriend.loading", comment: ""))
                .monoBase()
                .foregroundColor(ONETokens.oneAsh)
        }
    }

    // MARK: - Actions

    private func initializeUser() {
        guard cloudKitManager.currentUser == nil else { return }
        cloudKitManager.createOrFetchUser(displayName: "ONE User") { result in
            if case .failure(let error) = result {
                ONELogger.error("User initialization failed", error: error, category: .circle)
                DispatchQueue.main.async {
                    self.errorMessage = "Kullanıcı oluşturulamadı. iCloud bağlantınızı kontrol edin."
                    self.showError = true
                }
            }
        }
    }

    private func performSmartSearch() {
        let q = queryTrimmed
        guard !q.isEmpty, isQueryReady else { return }

        isSearching  = true
        foundUser    = nil
        userNotFound = false

        // findUserByCodeOrUsername: @ ile başlıyorsa username, 6 char ise kod arar
        let searchTerm = q.hasPrefix("@") ? q : (isCodeQuery ? q.uppercased() : q)
        cloudKitManager.findUserByCodeOrUsername(searchTerm) { result in
            DispatchQueue.main.async {
                self.isSearching = false
                switch result {
                case .success(let user):
                    ONEHaptics.songSaved()
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                        self.foundUser = user
                    }
                case .failure:
                    ONEHaptics.error()
                    withAnimation(ONEAnimation.micro) { self.userNotFound = true }
                }
            }
        }
    }

    private func sendRequestToFoundUser() {
        guard let user = foundUser else { return }
        let userID      = user["userID"]      as? String ?? ""
        let displayName = user["displayName"] as? String ?? "Kullanıcı"

        isLoading = true
        cloudKitManager.sendFriendRequest(toUserID: userID) { result in
            isLoading = false
            switch result {
            case .success:
                ONEHaptics.songSaved()
                withAnimation(ONEAnimation.micro) {
                    successMessage = "\(displayName) adlı kullanıcıya istek gönderildi!"
                    showSuccess    = true
                    foundUser      = nil
                    smartQuery     = ""
                }
            case .failure(let error):
                let nsError = error as NSError
                if nsError.code == -2 {
                    pendingUserIDToCancel = userID
                    pendingUserName       = displayName
                    showCancelAlert       = true
                } else {
                    ONEHaptics.error()
                    errorMessage = error.localizedDescription
                    showError    = true
                }
            }
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

    private func cancelPendingRequest() {
        guard !pendingUserIDToCancel.isEmpty else { return }
        isLoading = true
        cloudKitManager.cancelFriendRequest(toUserID: pendingUserIDToCancel) { result in
            isLoading = false
            switch result {
            case .success:
                ONEHaptics.songSaved()
                withAnimation(ONEAnimation.micro) {
                    successMessage = NSLocalizedString("circle.requestWithdrawn", comment: "")
                    showSuccess    = true
                    smartQuery     = ""
                }
            case .failure(let error):
                ONEHaptics.error()
                errorMessage = error.localizedDescription
                showError    = true
            }
        }
    }

    private func copyInviteCode() {
        UIPasteboard.general.string = myInviteCode
        ONEHaptics.moodSelected()
        withAnimation(ONEAnimation.micro) { codeCopied = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation(ONEAnimation.micro) { codeCopied = false }
        }
    }

    private func pasteFromClipboard() {
        guard let raw = UIPasteboard.general.string else { return }
        let cleaned = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return }
        ONEHaptics.moodSelected()
        smartQuery = cleaned
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
        NavigationStack {
            ZStack {
                ONETokens.oneCream.ignoresSafeArea()

                VStack(spacing: 0) {
                    Spacer()

                    ZStack {
                        RoundedRectangle(cornerRadius: 24)
                            .fill(ONETokens.onePaper)
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
                                .displayXS()
                                .fontWeight(.bold)
                                .foregroundColor(ONETokens.oneInk)
                        }
                    }
                    .padding(.bottom, 28)
                    .accessibilityLabel(String(format: NSLocalizedString("accessibility.addFriend.qrCode", comment: ""), code))

                    Button(action: {
                        UIPasteboard.general.string = code
                        ONEHaptics.moodSelected()
                        withAnimation(ONEAnimation.micro) { codeCopied = true }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            withAnimation(ONEAnimation.micro) { codeCopied = false }
                        }
                    }) {
                        VStack(spacing: 6) {
                            Text(code)
                                .displayLG()
                                .fontWeight(.bold)
                                .tracking(8)
                                .foregroundColor(codeCopied ? ONETokens.oneGreen : ONETokens.oneInk)

                            HStack(spacing: 4) {
                                Image(systemName: codeCopied ? "checkmark" : "doc.on.doc")
                                    .monoSM()
                                Text(codeCopied
                                     ? NSLocalizedString("addFriend.copied", comment: "")
                                     : NSLocalizedString("addFriend.tapToCopy", comment: ""))
                                    .monoLabel(tracking: 0.4)
                            }
                            .foregroundColor(codeCopied ? ONETokens.oneGreen : ONETokens.oneMist)
                        }
                        .animation(ONEAnimation.micro, value: codeCopied)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .padding(.bottom, 16)

                    Text(NSLocalizedString("addFriend.friendScansCode", comment: ""))
                        .monoSM(tracking: 0.5)
                        .foregroundColor(ONETokens.oneAsh)

                    Spacer()
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(NSLocalizedString("addFriend.cancel", comment: "")) { dismiss() }
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
    @State private var permissionDenied  = false

    var body: some View {
        NavigationStack {
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
                    VStack(spacing: 20) {
                        Image(systemName: "camera.slash")
                            .displayXXL()
                            .fontWeight(.ultraLight)
                            .foregroundColor(.white)
                        Text(NSLocalizedString("addFriend.cameraRequired", comment: ""))
                            .displaySM()
                            .foregroundColor(.white)
                        Button(NSLocalizedString("circle.goToSettings", comment: "")) {
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
                    Button(NSLocalizedString("addFriend.cancel", comment: "")) { dismiss() }
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

// MARK: - Preview

struct AddFriendView_Previews: PreviewProvider {
    static var previews: some View {
        AddFriendView()
    }
}
