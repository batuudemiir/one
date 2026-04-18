//
//  ContactsInviteView.swift
//  one
//
//  Rehberden arkadaş davet et — kişi listesi + SMS gönderme
//

import SwiftUI
import Contacts
import MessageUI
import CloudKit

// MARK: - ContactsInviteView

struct ContactsInviteView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var cloudKitManager = CloudKitManager.shared

    @State private var contacts: [CNContact] = []
    @State private var permissionStatus: CNAuthorizationStatus = .notDetermined
    @State private var isLoading = true
    @State private var searchText = ""
    @State private var smsRecipient: String = ""
    @State private var showMessageCompose = false
    @State private var showMessageUnavailableAlert = false

    private var myInviteCode: String {
        cloudKitManager.currentUser?["inviteCode"] as? String ?? "------"
    }

    private var inviteBody: String {
        "ONE uygulamasında mood ve müzik paylaşıyorum. Seni de davet ediyorum! Kodumu kullan: \(myInviteCode)\n\nhttps://one.forvibe.app"
    }

    private var filtered: [CNContact] {
        let hasPhone = contacts.filter { !$0.phoneNumbers.isEmpty }
        guard !searchText.isEmpty else { return hasPhone }
        return hasPhone.filter {
            $0.givenName.localizedCaseInsensitiveContains(searchText) ||
            $0.familyName.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        NavigationView {
            ZStack {
                ONETokens.oneCream.ignoresSafeArea()

                Group {
                    switch permissionStatus {
                    case .authorized:
                        contactList
                    case .denied, .restricted:
                        permissionDeniedView
                    default:
                        loadingView
                    }
                }
            }
            .navigationTitle(NSLocalizedString("contacts.navTitle", comment: ""))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(NSLocalizedString("general.close", comment: "")) { dismiss() }
                        .monoSM(tracking: 0)
                        .foregroundColor(ONETokens.oneInk)
                }
            }
            .sheet(isPresented: $showMessageCompose) {
                MessageComposeView(
                    recipients: [smsRecipient],
                    body: inviteBody
                )
                .ignoresSafeArea()
            }
            .alert(NSLocalizedString("contacts.alertSmsCantSend", comment: ""), isPresented: $showMessageUnavailableAlert) {
                Button(NSLocalizedString("general.ok", comment: ""), role: .cancel) {}
            } message: {
                Text(NSLocalizedString("contacts.smsNotAvailable", comment: ""))
            }
            .onAppear { requestContactsPermission() }
        }
    }

    // MARK: - Contact List

    private var contactList: some View {
        VStack(spacing: 0) {
            // Invite info banner
            HStack(spacing: 10) {
                Image(systemName: "link.circle.fill")
                    .foregroundColor(ONETokens.oneBrand)
                    .font(.system(size: 18))
                VStack(alignment: .leading, spacing: 1) {
                    Text(String(format: NSLocalizedString("contacts.inviteCodeText", comment: ""), myInviteCode))
                        .monoBase(tracking: 0.5)
                        .foregroundColor(ONETokens.oneInk)
                    Text(NSLocalizedString("contacts.smsSendHint", comment: ""))
                        .monoLabel(tracking: 0)
                        .foregroundColor(ONETokens.oneAsh)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(ONETokens.oneCreamMid)

            // Search
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(ONETokens.oneAsh)
                    .font(.system(size: 15))
                TextField(NSLocalizedString("contacts.searchPlaceholder", comment: ""), text: $searchText)
                    .monoBase()
                    .foregroundColor(ONETokens.oneInk)
                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(ONETokens.oneStone)
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(ONETokens.onePaper)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .padding(.horizontal, 16)
            .padding(.vertical, 10)

            if isLoading {
                Spacer()
                ProgressView().scaleEffect(1.2)
                Spacer()
            } else if filtered.isEmpty {
                Spacer()
                VStack(spacing: 10) {
                    Image(systemName: "person.crop.circle.badge.questionmark")
                        .font(.system(size: 38, weight: .ultraLight))
                        .foregroundColor(ONETokens.oneAsh)
                    Text(NSLocalizedString(searchText.isEmpty ? "contacts.noContacts" : "contacts.noResults", comment: ""))
                        .displaySM()
                        .foregroundColor(ONETokens.oneInk)
                }
                Spacer()
            } else {
                List(filtered, id: \.identifier) { contact in
                    ContactRow(contact: contact) {
                        invite(contact: contact)
                    }
                    .listRowBackground(ONETokens.onePaper.opacity(0.55))
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
        }
    }

    // MARK: - Permission Denied

    private var permissionDeniedView: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "lock.person.fill")
                .font(.system(size: 48, weight: .ultraLight))
                .foregroundColor(ONETokens.oneAsh)
            Text(NSLocalizedString("contacts.contactsRequired", comment: ""))
                .displayMD()
                .foregroundColor(ONETokens.oneInk)
            Text(NSLocalizedString("contacts.contactsPermissionHint", comment: ""))
                .monoSM(tracking: 0)
                .multilineTextAlignment(.center)
                .foregroundColor(ONETokens.oneAsh)
            Button(NSLocalizedString("contacts.openSettings", comment: "")) {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            .monoSM(tracking: 0.8)
            .foregroundColor(ONETokens.oneCream)
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(RoundedRectangle(cornerRadius: 12).fill(ONETokens.oneInk))
            Spacer()
        }
        .padding(.horizontal, 32)
    }

    // MARK: - Loading

    private var loadingView: some View {
        VStack(spacing: 14) {
            Spacer()
            ProgressView().scaleEffect(1.2)
            Text(NSLocalizedString("contacts.contactsLoading", comment: ""))
                .monoBase()
                .foregroundColor(ONETokens.oneAsh)
            Spacer()
        }
    }

    // MARK: - Logic

    private func requestContactsPermission() {
        let store = CNContactStore()
        switch CNContactStore.authorizationStatus(for: .contacts) {
        case .authorized:
            permissionStatus = .authorized
            fetchContacts()
        case .notDetermined:
            store.requestAccess(for: .contacts) { granted, _ in
                DispatchQueue.main.async {
                    permissionStatus = granted ? .authorized : .denied
                    if granted { fetchContacts() } else { isLoading = false }
                }
            }
        case .denied, .restricted:
            permissionStatus = .denied
            isLoading = false
        case .limited:
            permissionStatus = .authorized
            fetchContacts()
        @unknown default:
            isLoading = false
        }
    }

    private func fetchContacts() {
        isLoading = true
        DispatchQueue.global(qos: .userInitiated).async {
            let keys: [CNKeyDescriptor] = [
                CNContactGivenNameKey as CNKeyDescriptor,
                CNContactFamilyNameKey as CNKeyDescriptor,
                CNContactPhoneNumbersKey as CNKeyDescriptor,
                CNContactThumbnailImageDataKey as CNKeyDescriptor
            ]
            let request = CNContactFetchRequest(keysToFetch: keys)
            request.sortOrder = .userDefault
            let store = CNContactStore()
            var results: [CNContact] = []
            do {
                try store.enumerateContacts(with: request) { contact, _ in
                    results.append(contact)
                }
            } catch {
                ONELogger.error("Contact fetch failed", error: error, category: .general)
            }
            DispatchQueue.main.async {
                contacts = results
                isLoading = false
            }
        }
    }

    private func invite(contact: CNContact) {
        guard let phone = contact.phoneNumbers.first?.value.stringValue else { return }
        let cleaned = phone.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
        smsRecipient = cleaned

        if MFMessageComposeViewController.canSendText() {
            showMessageCompose = true
        } else {
            showMessageUnavailableAlert = true
        }
    }
}

// MARK: - Contact Row

private struct ContactRow: View {
    let contact: CNContact
    let onInvite: () -> Void

    private var fullName: String {
        "\(contact.givenName) \(contact.familyName)".trimmingCharacters(in: .whitespaces)
    }

    private var initial: String {
        String((contact.givenName.first ?? contact.familyName.first ?? "?").uppercased())
    }

    private var phone: String {
        contact.phoneNumbers.first?.value.stringValue ?? ""
    }

    var body: some View {
        HStack(spacing: 14) {
            // Avatar
            Circle()
                .fill(ONETokens.oneCreamMid)
                .frame(width: 44, height: 44)
                .overlay(
                    Text(initial)
                        .font(.system(size: 17, weight: .medium, design: .serif))
                        .italic()
                        .foregroundColor(ONETokens.oneAsh)
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(fullName.isEmpty ? NSLocalizedString("contacts.noName", comment: "") : fullName)
                    .displaySM()
                    .foregroundColor(ONETokens.oneInk)
                    .lineLimit(1)
                Text(phone)
                    .monoSM(tracking: 0)
                    .foregroundColor(ONETokens.oneAsh)
                    .lineLimit(1)
            }

            Spacer()

            Button(action: onInvite) {
                Text(NSLocalizedString("contacts.inviteButton", comment: ""))
                    .monoLabel(tracking: 0.6)
                    .foregroundColor(ONETokens.oneCream)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(ONETokens.oneInk))
            }
        }
        .padding(.vertical, 6)
    }
}

// MARK: - MessageComposeView (UIViewControllerRepresentable)

struct MessageComposeView: UIViewControllerRepresentable {
    let recipients: [String]
    let body: String

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIViewController(context: Context) -> MFMessageComposeViewController {
        let vc = MFMessageComposeViewController()
        vc.recipients = recipients
        vc.body = body
        vc.messageComposeDelegate = context.coordinator
        return vc
    }

    func updateUIViewController(_ uiViewController: MFMessageComposeViewController, context: Context) {}

    class Coordinator: NSObject, MFMessageComposeViewControllerDelegate {
        func messageComposeViewController(
            _ controller: MFMessageComposeViewController,
            didFinishWith result: MessageComposeResult
        ) {
            controller.dismiss(animated: true)
        }
    }
}
