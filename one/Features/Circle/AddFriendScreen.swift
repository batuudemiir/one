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

    @State private var segment = 0            // 0 kullanıcı adı · 1 kod · 2 kişiler
    @State private var query = ""
    @State private var isSearching = false
    @State private var foundUser: CKRecord? = nil
    @State private var notFound = false
    @State private var isSending = false
    @State private var sentToName: String? = nil
    @State private var showScanner = false
    @State private var showContacts = false
    @State private var codeCopied = false

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
                SegmentedControl(
                    options: [
                        NSLocalizedString("addFriend.segUsername", comment: ""),
                        NSLocalizedString("addFriend.segCode", comment: ""),
                        NSLocalizedString("addFriend.segContacts", comment: "")
                    ],
                    selection: $segment
                )
                .padding(.bottom, ONETokens.spacingLG)

                switch segment {
                case 0: usernameTab
                case 1: codeTab
                default: contactsTab
                }
            }
        }
        .sheet(isPresented: $showScanner) {
            QRScannerView { scanned in
                showScanner = false
                segment = 0
                query = scanned
                search()
            }
        }
        .sheet(isPresented: $showContacts) {
            ContactsInviteView()
        }
        .onAppear {
            if let code = prefilledCode, !code.isEmpty {
                query = code
                search()
            }
        }
    }

    // MARK: - Kullanıcı adı

    private var usernameTab: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 9) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 14))
                    .foregroundColor(ONETokens.oneStone)
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
                    .stroke(ONETokens.oneInk.opacity(0.09), lineWidth: 1)
            )

            if isSearching {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.top, ONETokens.spacingXL)
            } else if let sent = sentToName {
                Text(String(format: NSLocalizedString("addFriend.requestSent", comment: ""), sent))
                    .bodySM()
                    .foregroundColor(ONETokens.oneInk)
                    .frame(maxWidth: .infinity)
                    .padding(.top, ONETokens.spacingXL)
            } else if let user = foundUser {
                resultRow(user)
                    .padding(.top, ONETokens.spacingMD)
            } else if notFound {
                Text(NSLocalizedString("addFriend.notFound", comment: ""))
                    .bodySM()
                    .foregroundColor(ONETokens.oneAsh)
                    .frame(maxWidth: .infinity)
                    .padding(.top, ONETokens.spacingXL)
            }

            // Prototipin sözü: rastgele insan önerilmez.
            Text(NSLocalizedString("addFriend.exactHint", comment: ""))
                .bodyXS()
                .multilineTextAlignment(.center)
                .foregroundColor(ONETokens.oneAsh)
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
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white)
                )

            VStack(alignment: .leading, spacing: 1) {
                Text(name)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(ONETokens.oneInk)
                if !uname.isEmpty {
                    Text("@\(uname)")
                        .bodyXS()
                        .foregroundColor(ONETokens.oneAsh)
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
                .foregroundColor(ONETokens.oneBrand)
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
                        .stroke(ONETokens.oneInk.opacity(0.09), lineWidth: 1)
                )

            Text(myHandle)
                .font(.system(size: 19, weight: .bold))
                .foregroundColor(ONETokens.oneInk)
                .padding(.top, ONETokens.spacingLG)

            Text(NSLocalizedString("addFriend.codeHint", comment: ""))
                .bodyXS()
                .foregroundColor(ONETokens.oneAsh)
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
                    .foregroundColor(ONETokens.oneCream)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .background(Capsule(style: .continuous).fill(ONETokens.oneInk))
                }
                .buttonStyle(.plain)

                Button {
                    showScanner = true
                } label: {
                    Text(NSLocalizedString("addFriend.scanWithCamera", comment: ""))
                        .bodySMMedium()
                        .foregroundColor(ONETokens.oneInk)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .background(
                            Capsule(style: .continuous)
                                .stroke(ONETokens.oneInk.opacity(0.14), lineWidth: 1.5)
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
                .foregroundColor(ONETokens.oneStone)
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

    // MARK: - Kişiler

    /// Prototipin gizlilik sözü buradaki caption: "kişilerin telefonundan
    /// çıkmaz — sadece şifrelenmiş özetleri karşılaştırılır." İzin butonuna
    /// basmadan ÖNCE okunuyor; izin ekranına güvenle gidilsin diye.
    private var contactsTab: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(NSLocalizedString("addFriend.contactsPrivacy", comment: ""))
                .bodyXS()
                .foregroundColor(ONETokens.oneAsh)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.bottom, ONETokens.spacingMD)

            Button {
                showContacts = true
            } label: {
                Text(NSLocalizedString("addFriend.allowContacts", comment: ""))
                    .bodySMMedium()
                    .foregroundColor(ONETokens.oneCream)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .background(Capsule(style: .continuous).fill(ONETokens.oneInk))
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Actions

    private func search() {
        let q = query.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return }

        isSearching = true
        foundUser = nil
        notFound = false
        sentToName = nil

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

    private func send(to user: CKRecord) {
        let userID = user["userID"] as? String ?? ""
        let name = user["displayName"] as? String ?? "?"
        guard !userID.isEmpty else { return }

        isSending = true
        cloudKitManager.sendFriendRequest(toUserID: userID) { result in
            DispatchQueue.main.async {
                isSending = false
                if case .success = result {
                    ONEHaptics.songSaved()
                    withAnimation(.easeOut(duration: 0.2)) {
                        sentToName = name
                        foundUser = nil
                        query = ""
                    }
                }
            }
        }
    }
}
