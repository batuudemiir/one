//
//  MyFriendsListView.swift
//  one
//
//  Prototip 19 — arkadaşlar. Tek ekranda: hızlı ekle, çevre listesi, istekler.
//

import SwiftUI
import CloudKit

/// Identifiable wrapper for sheet(item:) profile presentation.
private struct ProfileSheetID: Identifiable, Hashable {
    let id: String
}

/// Arkadaşlar ekranı.
///
/// Prototipin iki cümlesi bu ekranın omurgası:
/// - "yalnızca telefonunda kayıtlı olanlar. ONE tanımadığın kimseyi önermez."
/// - "arkadaşlar birbirinin sadece bugününü görür. geçmiş herkesin kendinde kalır."
/// Güvenceler listenin dibine gömülmüyor; ait oldukları bölümün hemen
/// yanında duruyor — güvence, özelliğin yanında verilince inandırıcı.
struct MyFriendsListView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var cloudKitManager = CloudKitManager.shared
    @ObservedObject var vm: ProfileViewModel

    // MARK: Data

    @State private var friends: [CloudKitManager.FriendCircleData] = []
    @State private var incoming: [(request: CKRecord, sender: CKRecord)] = []
    @State private var outgoing: [(request: CKRecord, receiver: CKRecord)] = []
    @State private var isLoading = true

    // MARK: UI state

    @State private var segment = 0            // 0 = hepsi, 1 = istekler
    @State private var query = ""
    @State private var showAddFriend = false
    @State private var showShare = false
    @State private var selectedFriend: CloudKitManager.FriendCircleData? = nil
    @State private var profileUserID: String? = nil
    @State private var workingRequestID: String? = nil

    private var filteredFriends: [CloudKitManager.FriendCircleData] {
        guard !query.isEmpty else { return friends }
        return friends.filter {
            ($0.user["displayName"] as? String ?? "")
                .localizedCaseInsensitiveContains(query)
        }
    }

    var body: some View {
        SubScreen(
            title: NSLocalizedString("myFriends.title", comment: ""),
            actionTitle: NSLocalizedString("friends.addAction", comment: ""),
            onBack: { dismiss() },
            onAction: { showAddFriend = true }
        ) {
            VStack(alignment: .leading, spacing: 0) {
                SegmentedControl(
                    options: [
                        String(format: NSLocalizedString("friends.segAll", comment: ""), friends.count),
                        String(format: NSLocalizedString("friends.segRequests", comment: ""), incoming.count)
                    ],
                    selection: $segment
                )
                .padding(.bottom, V3Tokens.spacingLG)

                if segment == 0 {
                    allTab
                } else {
                    requestsTab
                }
            }
        }
        .onAppear { loadAll() }
        .sheet(isPresented: $showAddFriend, onDismiss: { loadAll() }) {
            AddFriendScreen()
        }
        .sheet(isPresented: $showShare) {
            if vm.inviteCode != "------" {
                InviteShareSheet(
                    inviteCode: vm.inviteCode,
                    userName: vm.displayName.isEmpty ? "ONE" : vm.displayName
                )
            }
        }
        .v3Sheet()
        .sheet(item: $selectedFriend) { data in
            FriendDetailView(friendData: data, onRefresh: { loadAll() })
        }
        .v3Sheet()
        .sheet(item: Binding(
            get: { profileUserID.map { ProfileSheetID(id: $0) } },
            set: { profileUserID = $0?.id }
        )) { wrap in
            FriendProfileScreen(userID: wrap.id, onBack: { profileUserID = nil })
        }
        .v3Sheet()
    }

    // MARK: - Hepsi

    private var allTab: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionLabel(NSLocalizedString("friends.quickAdd", comment: ""))

            // Prototip `.qadd`: üç kesikli karo.
            HStack(spacing: V3Tokens.spacingSM) {
                quickTile(
                    glyph: "arrow.up.right",
                    label: NSLocalizedString("friends.shareLink", comment: "")
                ) { showShare = true }
                quickTile(
                    glyph: "square.grid.2x2",
                    label: NSLocalizedString("friends.showCode", comment: "")
                ) { showAddFriend = true }
                quickTile(
                    glyph: "qrcode.viewfinder",
                    label: NSLocalizedString("friends.scanCode", comment: "")
                ) { showAddFriend = true }
            }

            Rectangle()
                .fill(V3Tokens.ink.opacity(0.09))
                .frame(height: 1)
                .padding(.vertical, V3Tokens.spacingXL)

            sectionLabel(String(
                format: NSLocalizedString("friends.circleCount", comment: ""),
                friends.count
            ))

            searchField
                .padding(.bottom, V3Tokens.spacingLG)

            if isLoading && friends.isEmpty {
                V3Loading(.region)
            } else if filteredFriends.isEmpty {
                Text(NSLocalizedString(
                    query.isEmpty ? "friends.emptyList" : "friends.noMatch",
                    comment: ""
                ))
                .bodySM()
                .foregroundColor(V3Tokens.mutedText)
                .frame(maxWidth: .infinity)
                .padding(.vertical, V3Tokens.spacingXL)
            } else {
                VStack(spacing: 9) {
                    ForEach(filteredFriends, id: \.user.recordID.recordName) { data in
                        friendCard(data)
                    }
                }
            }

            Rectangle()
                .fill(V3Tokens.ink.opacity(0.09))
                .frame(height: 1)
                .padding(.vertical, V3Tokens.spacingXL)

            // Ekranın kapanış sözü: geçmiş herkesin kendinde kalır.
            Text(NSLocalizedString("friends.footer", comment: ""))
                .bodyXS()
                .multilineTextAlignment(.center)
                .foregroundColor(V3Tokens.mutedText)
                .frame(maxWidth: .infinity)
        }
    }

    // MARK: - İstekler

    private var requestsTab: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionLabel(NSLocalizedString("friends.addedYou", comment: ""))

            if incoming.isEmpty {
                Text(NSLocalizedString("friends.noIncoming", comment: ""))
                    .bodySM()
                    .foregroundColor(V3Tokens.mutedText)
                    .padding(.vertical, V3Tokens.spacingMD)
            } else {
                VStack(spacing: 7) {
                    ForEach(incoming, id: \.request.recordID.recordName) { pair in
                        incomingRow(pair)
                    }
                }
            }

            Rectangle()
                .fill(V3Tokens.ink.opacity(0.09))
                .frame(height: 1)
                .padding(.vertical, V3Tokens.spacingXL)

            sectionLabel(NSLocalizedString("friends.sentByYou", comment: ""))

            if outgoing.isEmpty {
                Text(NSLocalizedString("friends.noOutgoing", comment: ""))
                    .bodySM()
                    .foregroundColor(V3Tokens.mutedText)
                    .padding(.vertical, V3Tokens.spacingMD)
            } else {
                VStack(spacing: 7) {
                    ForEach(outgoing, id: \.request.recordID.recordName) { pair in
                        outgoingRow(pair)
                    }
                }
            }
        }
    }

    // MARK: - Parçalar

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .monoLabel(tracking: 1.3)
            .foregroundColor(V3Tokens.faintText)
            .padding(.bottom, V3Tokens.spacingSM)
    }

    /// Prototip `.qtile`: kesikli çerçeve, üstte mürekkep yuvarlakta glif.
    private func quickTile(
        glyph: String,
        label: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 7) {
                Circle()
                    .fill(V3Tokens.ink)
                    .frame(width: 32, height: 32)
                    .overlay(
                        Image(systemName: glyph)
                            .font(.system(size: 13))
                            .foregroundColor(ONEBrand.bone)
                    )
                Text(label)
                    .bodyMicroSemibold()
                    .multilineTextAlignment(.center)
                    .foregroundColor(V3Tokens.ink)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: V3Tokens.radiusCard, style: .continuous)
                    .fill(Color.white.opacity(0.6))
            )
            .overlay(
                RoundedRectangle(cornerRadius: V3Tokens.radiusCard, style: .continuous)
                    .strokeBorder(
                        V3Tokens.ink.opacity(0.16),
                        style: StrokeStyle(lineWidth: 1, dash: [4, 3])
                    )
            )
        }
        .buttonStyle(.onePressable)
    }

    private var searchField: some View {
        HStack(spacing: 9) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14))
                .foregroundColor(V3Tokens.faintText)
            TextField(
                NSLocalizedString("friends.searchPlaceholder", comment: ""),
                text: $query
            )
            .textFieldStyle(.plain)
        }
        .padding(.horizontal, 15)
        .padding(.vertical, V3Tokens.spacingMD)
        .background(
            RoundedRectangle(cornerRadius: V3Tokens.radiusCard, style: .continuous)
                .fill(Color.white.opacity(0.8))
        )
        .overlay(
            RoundedRectangle(cornerRadius: V3Tokens.radiusCard, style: .continuous)
                .stroke(V3Tokens.ink.opacity(0.09), lineWidth: 1)
        )
    }

    /// Çevre'deki kartla aynı dil: 46pt halka + %22 dış çember,
    /// isim + renkli mood etiketi, tek satır şarkı.
    private func friendCard(_ data: CloudKitManager.FriendCircleData) -> some View {
        let name = data.user["displayName"] as? String ?? "?"
        let hasSong = !(data.share?["songName"] as? String ?? "").isEmpty
        let moodHex = data.share?["moodColor"] as? String
            ?? data.user["avatarColor"] as? String ?? "#888888"
        let moodWord = (data.share?["moodWord"] as? String ?? "").lowercased()
        let song = data.share?["songName"] as? String ?? ""
        let artist = data.share?["artistName"] as? String ?? ""

        return Button {
            ONEHaptics.feelingSelected()
            if let uid = data.user["userID"] as? String, !uid.isEmpty {
                profileUserID = uid
            } else {
                selectedFriend = data
            }
        } label: {
            HStack(spacing: 13) {
                V3PersonAvatar(
                    name: name,
                    colorHex: hasSong ? moodHex : nil,
                    size: .medium
                )

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 7) {
                        Text(name)
                            .bodySMSemibold()
                            .foregroundColor(V3Tokens.ink)
                            .lineLimit(1)

                        if hasSong && !moodWord.isEmpty {
                            Text(moodWord)
                                .bodyMicroSemibold()
                                .foregroundColor(Color(hex: moodHex))
                                .padding(.horizontal, 7)
                                .padding(.vertical, 2)
                                .background(
                                    RoundedRectangle(cornerRadius: V3Tokens.radiusSwatch, style: .continuous)
                                        .fill(Color(hex: moodHex).opacity(0.14))
                                )
                        }
                        Spacer(minLength: 4)
                    }

                    Text(hasSong
                         ? "\(song) — \(artist)"
                         : NSLocalizedString("circle.notSharedYet", comment: ""))
                        .font(.system(size: 12.5))
                        .foregroundColor(V3Tokens.mutedText)
                        .lineLimit(1)
                }
            }
            .padding(.horizontal, 15)
            .padding(.vertical, 13)
            .frame(maxWidth: .infinity, alignment: .leading)
            .oneCardBackground(radius: V3Tokens.radiusPanel)
        }
        .buttonStyle(.onePressable)
    }

    /// Prototip `.inv`: avatar + isim + kabul/yoksay.
    private func incomingRow(_ pair: (request: CKRecord, sender: CKRecord)) -> some View {
        let name = pair.sender["displayName"] as? String ?? "?"
        let recordName = pair.request.recordID.recordName
        let isWorking = workingRequestID == recordName

        return HStack(spacing: V3Tokens.spacingMD) {
            V3PersonAvatar(name: name, size: .small)

            Text(name)
                .bodySMSemibold()
                .foregroundColor(V3Tokens.ink)
                .lineLimit(1)

            Spacer()

            if isWorking {
                V3Loading(.inline)
            } else {
                Button(NSLocalizedString("friends.accept", comment: "")) {
                    accept(recordName: recordName)
                }
                .font(.system(size: 12.5, weight: .semibold))
                .foregroundColor(ONEBrand.kor)
                .buttonStyle(.onePressable)

                Button(NSLocalizedString("friends.ignore", comment: "")) {
                    decline(recordName: recordName)
                }
                .font(.system(size: 12.5, weight: .semibold))
                .foregroundColor(V3Tokens.faintText)
                .buttonStyle(.onePressable)
                .padding(.leading, 6)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .oneCardBackground(radius: 14)
    }

    private func outgoingRow(_ pair: (request: CKRecord, receiver: CKRecord)) -> some View {
        let name = pair.receiver["displayName"] as? String ?? "?"

        return HStack(spacing: V3Tokens.spacingMD) {
            V3PersonAvatar(name: name, size: .small)

            Text(name)
                .bodySMSemibold()
                .foregroundColor(V3Tokens.ink)
                .lineLimit(1)

            Spacer()

            Text(NSLocalizedString("friends.waiting", comment: ""))
                .bodyMicroSemibold()
                .foregroundColor(V3Tokens.faintText)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .oneCardBackground(radius: 14)
    }

    // MARK: - Loaders

    private func loadAll() {
        isLoading = true

        cloudKitManager.fetchFriendsDailyShares(for: Date()) { result in
            DispatchQueue.main.async {
                isLoading = false
                if case .success(let list) = result { friends = list }
            }
        }
        cloudKitManager.fetchPendingRequests { result in
            DispatchQueue.main.async {
                if case .success(let pairs) = result { incoming = pairs }
            }
        }
        cloudKitManager.fetchSentRequests { result in
            DispatchQueue.main.async {
                if case .success(let pairs) = result { outgoing = pairs }
            }
        }
    }

    private func finishRequestAction() {
        workingRequestID = nil
        loadAll()
        vm.loadFriendCount()
    }

    private func accept(recordName: String) {
        workingRequestID = recordName
        cloudKitManager.acceptFriendRequest(recordID: recordName) { _ in
            DispatchQueue.main.async { finishRequestAction() }
        }
    }

    private func decline(recordName: String) {
        workingRequestID = recordName
        cloudKitManager.declineFriendRequest(recordID: recordName) { _ in
            DispatchQueue.main.async { finishRequestAction() }
        }
    }
}
