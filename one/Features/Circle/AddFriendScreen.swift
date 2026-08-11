//
//  AddFriendScreen.swift
//  one
//
//  Prototip 21 — arkadaş ekle: kullanıcı adı / kod / kişiler.
//

import SwiftUI
import CloudKit
import CoreImage.CIFilterBuiltins

/// Arkadaş ekleme.
///
/// Prototipin duruşu ilk sekmenin altındaki cümlede: **"tam kullanıcı adını
/// yaz. ONE'da rastgele insan önerilmez."** Arama bir keşif aracı değil,
/// bilerek ekleme aracı — sonuç listesi yok, tek eşleşme var.
///
/// Eski `AddFriendView`'ın (1119 satır) kanıtlanmış servis çağrıları
/// (`findUserByCodeOrUsername`, `sendFriendRequest`, `QRScannerView`)
/// aynen kullanılıyor; yalnız sunum prototipe indi.
struct AddFriendScreen: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var cloudKitManager = CloudKitManager.shared

    /// Deep link ile gelen davet kodu — kod aramasına önden doldurulur.
    var prefilledCode: String? = nil

    // MARK: State

    @State private var showCode = false       // "kodunu göster" kutucuğu
    @State private var query = ""
    @State private var isSearching = false
    @State private var foundUser: CKRecord? = nil
    @State private var notFound = false
    @State private var isSending = false
    @State private var sentToName: String? = nil
    @State private var showScanner = false
    @State private var codeCopied = false
    /// Prototip 19'daki "hızlı ekle" önerileri. `fetchSuggestedUsers`
    /// zaten vardı ama hiçbir ekrandan çağrılmıyordu — ortak arkadaş
    /// sayısına göre sıralı geliyor, rastgele insan önermiyor.
    @State private var suggestions: [SuggestedUser] = []
    @State private var sentUserIDs: Set<String> = []
    /// İstek gönderiminde servisin döndüğü kullanıcıya dönük hata
    /// (zaten arkadaş / bekleyen istek / engelli / kendini ekleme).
    /// Önceden sessizce yutuluyordu.
    @State private var errorText: String? = nil

    private var myInviteCode: String {
        cloudKitManager.currentUser?["inviteCode"] as? String ?? "------"
    }

    private var myHandle: String {
        let uname = cloudKitManager.currentUser?["username"] as? String ?? ""
        return uname.isEmpty ? myInviteCode : "\(uname)-\(myInviteCode.prefix(4))"
    }

    var body: some View {
        SubScreen(
            title: NSLocalizedString("addFriend.screenTitle", comment: ""),
            actionTitle: nil,
            onBack: { dismiss() }
        ) {
            VStack(alignment: .leading, spacing: 0) {
                // Prototip: segment yok. Üstte üç hızlı eylem, altında
                // "rehberinde ONE'da olanlar" şeridi, en altta kullanıcı
                // adı araması.
                quickTiles

                suggestionRail

                usernameTab
                    .padding(.top, ONETokens.spacingXL)
            }
        }
        .sheet(isPresented: $showScanner) {
            QRScannerView { scanned in
                showScanner = false
                query = scanned
                search()
            }
        }
        .sheet(isPresented: $showCode) {
            codeSheet
        }
        .task {
            CloudKitManager.shared.fetchSuggestedUsers(limit: 5) { list in
                DispatchQueue.main.async { suggestions = list }
            }
        }
        .onAppear {
            if let code = prefilledCode, !code.isEmpty {
                query = code
                search()
            }
        }
    }

    // MARK: - Hızlı ekle kutucukları

    /// Prototipteki `.qadd`: üç eşit kutucuk — bağlantı paylaş, kodunu
    /// göster, kod okut. Segmentli sekmelerin yerini alıyor; kod ve tarama
    /// artık burada, kişiler ise aşağıdaki öneri şeridiyle.
    private var quickTiles: some View {
        HStack(spacing: 8) {
            ShareLink(
                item: URL(string: "https://one.forvibe.app/invite/\(myInviteCode)")!,
                message: Text(NSLocalizedString("addFriend.inviteMessage", comment: ""))
            ) {
                quickTileLabel(glyph: "arrow.up.forward", title: NSLocalizedString("addFriend.tileShareLink", comment: ""))
            }
            .buttonStyle(.plain)

            Button { showCode = true } label: {
                quickTileLabel(glyph: "qrcode", title: NSLocalizedString("addFriend.tileShowCode", comment: ""))
            }
            .buttonStyle(.plain)

            Button { showScanner = true } label: {
                quickTileLabel(glyph: "viewfinder", title: NSLocalizedString("addFriend.tileScan", comment: ""))
            }
            .buttonStyle(.plain)
        }
    }

    private func quickTileLabel(glyph: String, title: String) -> some View {
        VStack(spacing: 7) {
            Image(systemName: glyph)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(ONEBrand.bone)
                .frame(width: 32, height: 32)
                .background(Circle().fill(V3Tokens.ink))

            Text(title)
                .font(V3Typography.sans(11, weight: .semibold))
                .multilineTextAlignment(.center)
                .foregroundColor(V3Tokens.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: ONETokens.radiusCardLg, style: .continuous)
                .fill(Color.white.opacity(0.6))
                .overlay(
                    RoundedRectangle(cornerRadius: ONETokens.radiusCardLg, style: .continuous)
                        .strokeBorder(V3Tokens.ink.opacity(0.16),
                                      style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
                )
        )
    }

    // MARK: - "rehberinde ONE'da olanlar" şeridi

    @ViewBuilder
    private var suggestionRail: some View {
        if !suggestions.isEmpty {
            Text(NSLocalizedString("addFriend.contactsOnOne", comment: ""))
                .monoLabel(tracking: 1.3)
                .foregroundColor(V3Tokens.faintText)
                .padding(.top, ONETokens.spacingXL)
                .padding(.bottom, ONETokens.spacingSM)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(suggestions) { user in
                        QuickSuggestCard(user: user, sent: sentUserIDs.contains(user.id)) {
                            sendToSuggested(user)
                        }
                    }
                }
            }

            // Prototipin gizlilik sözü.
            Text(NSLocalizedString("addFriend.contactsOnlyHint", comment: ""))
                .bodyXS()
                .foregroundColor(V3Tokens.mutedText)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, ONETokens.spacingSM)
        }
    }

    // MARK: - Kod sayfası (kutucuktan açılır)

    private var codeSheet: some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(V3Tokens.ink.opacity(0.16))
                .frame(width: 36, height: 4)
                .padding(.top, 10)
                .padding(.bottom, ONETokens.spacingXL)

            codeTab
                .padding(.horizontal, ONETokens.spacingXL)

            Spacer()
        }
        .presentationDetents([.medium, .large])
    }

    // MARK: - Kullanıcı adı

    private var usernameTab: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 9) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 14))
                    .foregroundColor(V3Tokens.faintText)
                TextField(
                    NSLocalizedString("addFriend.usernamePlaceholder", comment: ""),
                    text: $query
                )
                .textFieldStyle(.plain)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.search)
                .onSubmit { search() }
            }
            .padding(.horizontal, 15)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.white.opacity(0.8))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(V3Tokens.ink.opacity(0.09), lineWidth: 1)
            )

            if isSearching {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.top, ONETokens.spacingXL)
            } else if let sent = sentToName {
                Text(String(format: NSLocalizedString("addFriend.requestSent", comment: ""), sent))
                    .bodySM()
                    .foregroundColor(V3Tokens.ink)
                    .frame(maxWidth: .infinity)
                    .padding(.top, ONETokens.spacingXL)
            } else if let user = foundUser {
                resultRow(user)
                    .padding(.top, ONETokens.spacingMD)
            } else if notFound {
                Text(NSLocalizedString("addFriend.notFound", comment: ""))
                    .bodySM()
                    .foregroundColor(V3Tokens.mutedText)
                    .frame(maxWidth: .infinity)
                    .padding(.top, ONETokens.spacingXL)
            }

            // İstek gönderilemediyse (zaten arkadaş / bekleyen istek /
            // engelli / kendini ekleme) servisin mesajını yumuşak bir
            // uyarı tonuyla göster — eskiden sessizce yutuluyordu.
            if let errorText {
                Text(errorText)
                    .bodyXS()
                    .multilineTextAlignment(.center)
                    .foregroundColor(ONETokens.moodOrange)
                    .frame(maxWidth: .infinity)
                    .padding(.top, ONETokens.spacingMD)
                    .transition(.opacity)
            }

            // Prototipin sözü: rastgele insan önerilmez, tam eşleşme gerekir.
            Text(NSLocalizedString("addFriend.exactHint", comment: ""))
                .bodyXS()
                .multilineTextAlignment(.center)
                .foregroundColor(V3Tokens.mutedText)
                .frame(maxWidth: .infinity)
                .padding(.top, ONETokens.spacingXL)
        }
    }

    private func resultRow(_ user: CKRecord) -> some View {
        let name = user["displayName"] as? String ?? "?"
        let uname = user["username"] as? String ?? ""
        let colorHex = user["avatarColor"] as? String ?? "#5B8DEF"

        return HStack(spacing: 12) {
            Circle()
                .fill(Color(hex: colorHex))
                .frame(width: 36, height: 36)
                .overlay(
                    Text(String(name.prefix(1)).uppercased())
                        .font(V3Typography.sans(13, weight: .semibold))
                        .foregroundColor(.white)
                )

            VStack(alignment: .leading, spacing: 1) {
                Text(name)
                    .font(V3Typography.sans(14, weight: .semibold))
                    .foregroundColor(V3Tokens.ink)
                if !uname.isEmpty {
                    Text("@\(uname)")
                        .bodyXS()
                        .foregroundColor(V3Tokens.mutedText)
                }
            }

            Spacer()

            if isSending {
                ProgressView().controlSize(.small)
            } else {
                Button(NSLocalizedString("addFriend.addAction", comment: "")) {
                    send(to: user)
                }
                .font(.system(size: 12.5, weight: .semibold))
                .foregroundColor(ONEBrand.kor)
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .oneCardBackground(radius: 14, opacity: 0.75)
    }

    // MARK: - Kod

    private var codeTab: some View {
        VStack(spacing: 0) {
            qrImage
                .frame(width: 168, height: 168)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(V3Tokens.ink.opacity(0.09), lineWidth: 1)
                )

            Text(myHandle)
                .font(V3Typography.sans(19, weight: .bold))
                .foregroundColor(V3Tokens.ink)
                .padding(.top, ONETokens.spacingLG)

            Text(NSLocalizedString("addFriend.codeHint", comment: ""))
                .bodyXS()
                .foregroundColor(V3Tokens.mutedText)
                .padding(.top, 6)

            VStack(spacing: 8) {
                Button {
                    UIPasteboard.general.string = myInviteCode
                    ONEHaptics.feelingSelected()
                    codeCopied = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) { codeCopied = false }
                } label: {
                    Text(NSLocalizedString(
                        codeCopied ? "addFriend.codeCopied" : "addFriend.copyCode",
                        comment: ""
                    ))
                    .bodySMMedium()
                    .foregroundColor(ONEBrand.bone)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .background(Capsule(style: .continuous).fill(V3Tokens.ink))
                }
                .buttonStyle(.plain)

                Button {
                    showScanner = true
                } label: {
                    Text(NSLocalizedString("addFriend.scanWithCamera", comment: ""))
                        .bodySMMedium()
                        .foregroundColor(V3Tokens.ink)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .background(
                            Capsule(style: .continuous)
                                .stroke(V3Tokens.ink.opacity(0.14), lineWidth: 1.5)
                        )
                }
                .buttonStyle(.plain)
            }
            .padding(.top, ONETokens.spacingXL)
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private var qrImage: some View {
        if let img = generateQR(from: "https://one.forvibe.app/invite/\(myInviteCode)") {
            Image(uiImage: img)
                .interpolation(.none)
                .resizable()
                .scaledToFit()
                .padding(12)
        } else {
            Image(systemName: "qrcode")
                .font(.system(size: 64, weight: .light))
                .foregroundColor(V3Tokens.faintText)
        }
    }

    private func generateQR(from string: String) -> UIImage? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(string.utf8)
        guard let output = filter.outputImage else { return nil }
        let scaled = output.transformed(by: CGAffineTransform(scaleX: 8, y: 8))
        guard let cg = CIContext().createCGImage(scaled, from: scaled.extent) else { return nil }
        return UIImage(cgImage: cg)
    }

    // MARK: - Actions

    private func search() {
        let q = query.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return }

        isSearching = true
        foundUser = nil
        notFound = false
        sentToName = nil
        errorText = nil

        // @ ile başlıyorsa kullanıcı adı, 6 karakterse kod olarak aranır.
        let term = q.hasPrefix("@") ? q : (q.count == 6 ? q.uppercased() : q)
        cloudKitManager.findUserByCodeOrUsername(term) { result in
            DispatchQueue.main.async {
                isSearching = false
                switch result {
                case .success(let user):
                    ONEHaptics.feelingSelected()
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        foundUser = user
                    }
                case .failure:
                    withAnimation(.easeOut(duration: 0.15)) { notFound = true }
                }
            }
        }
    }

    private func sendToSuggested(_ user: SuggestedUser) {
        sentUserIDs.insert(user.id)
        errorText = nil
        ONEHaptics.songSaved()
        CloudKitManager.shared.sendFriendRequest(toUserID: user.id) { result in
            DispatchQueue.main.async {
                if case .failure(let err) = result {
                    sentUserIDs.remove(user.id)   // kart "eklenmedi"e döner
                    ONEHaptics.error()
                    withAnimation(.easeOut(duration: 0.15)) {
                        errorText = err.localizedDescription
                    }
                }
            }
        }
    }

    private func send(to user: CKRecord) {
        let userID = user["userID"] as? String ?? ""
        let name = user["displayName"] as? String ?? "?"
        guard !userID.isEmpty else { return }

        isSending = true
        errorText = nil
        cloudKitManager.sendFriendRequest(toUserID: userID) { result in
            DispatchQueue.main.async {
                isSending = false
                switch result {
                case .success:
                    ONEHaptics.songSaved()
                    withAnimation(.easeOut(duration: 0.2)) {
                        sentToName = name
                        foundUser = nil
                        query = ""
                    }
                case .failure(let err):
                    // Zaten arkadaş / bekleyen istek / engelli / kendini ekleme —
                    // servisin mesajını göster, foundUser'ı bırak ki kimi
                    // eklemeye çalıştığı görünsün.
                    ONEHaptics.error()
                    withAnimation(.easeOut(duration: 0.15)) {
                        errorText = err.localizedDescription
                    }
                }
            }
        }
    }
}
