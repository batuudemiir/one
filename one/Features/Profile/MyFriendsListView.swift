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
                .padding(.bottom, ONETokens.spacingLG)

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
        .sheet(item: $selectedFriend) { data in
            FriendDetailView(friendData: data, onRefresh: { loadAll() })
        }
        .sheet(item: Binding(
            get: { profileUserID.map { ProfileSheetID(id: $0) } },
            set: { profileUserID = $0?.id }
        )) { wrap in
            FriendProfileScreen(userID: wrap.id, onBack: { profileUserID = nil })
        }
    }

    // MARK: - Hepsi

    private var allTab: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionLabel(NSLocalizedString("friends.quickAdd", comment: ""))

            // Prototip `.qadd`: üç kesikli karo.
            HStack(spacing: 8) {
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
                .fill(ONETokens.oneInk.opacity(0.09))
                .frame(height: 1)
                .padding(.vertical, ONETokens.spacingXL)

            sectionLabel(String(
                format: NSLocalizedString("friends.circleCount", comment: ""),
                friends.count
            ))

            searchField
                .padding(.bottom, ONETokens.spacingLG)

            if isLoading && friends.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, ONETokens.spacingXL3)
            } else if filteredFriends.isEmpty {
                Text(NSLocalizedString(
                    query.isEmpty ? "friends.emptyList" : "friends.noMatch",
                    comment: ""
                ))
                .bodySM()
                .foregroundColor(ONETokens.oneAsh)
                .frame(maxWidth: .infinity)
                .padding(.vertical, ONETokens.spacingXL)
            } else {
                VStack(spacing: 9) {
                    ForEach(filteredFriends, id: \.user.recordID.recordName) { data in
                        friendCard(data)
                    }
                }
            }

            Rectangle()
                .fill(ONETokens.oneInk.opacity(0.09))
                .frame(height: 1)
                .padding(.vertical, ONETokens.spacingXL)

            // Ekranın kapanış sözü: geçmiş herkesin kendinde kalır.
            Text(NSLocalizedString("friends.footer", comment: ""))
                .bodyXS()
                .multilineTextAlignment(.center)
                .foregroundColor(ONETokens.oneAsh)
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
                    .foregroundColor(ONETokens.oneAsh)
                    .padding(.vertical, ONETokens.spacingMD)
            } else {
                VStack(spacing: 7) {
                    ForEach(incoming, id: \.request.recordID.recordName) { pair in
                        incomingRow(pair)
                    }
                }
            }

            Rectangle()
                .fill(ONETokens.oneInk.opacity(0.09))
                .frame(height: 1)
                .padding(.vertical, ONETokens.spacingXL)

            sectionLabel(NSLocalizedString("friends.sentByYou", comment: ""))

            if outgoing.isEmpty {
                Text(NSLocalizedString("friends.noOutgoing", comment: ""))
                    .bodySM()
                    .foregroundColor(ONETokens.oneAsh)
                    .padding(.vertical, ONETokens.spacingMD)
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
            .foregroundColor(ONETokens.oneStone)
            .padding(.bottom, ONETokens.spacingSM)
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
                    .fill(ONETokens.oneInk)
                    .frame(width: 32, height: 32)
                    .overlay(
                        Image(systemName: glyph)
                            .font(.system(size: 13))
                            .foregroundColor(ONETokens.oneCream)
                    )
                Text(label)
                    .font(.system(size: 11, weight: .semibold))
                    .multilineTextAlignment(.center)
                    .foregroundColor(ONETokens.oneInk)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: ONETokens.radiusCardLg, style: .continuous)
                    .fill(Color.white.opacity(0.6))
            )
            .overlay(
                RoundedRectangle(cornerRadius: ONETokens.radiusCardLg, style: .continuous)
                    .strokeBorder(
                        ONETokens.oneInk.opacity(0.16),
                        style: StrokeStyle(lineWidth: 1, dash: [4, 3])
                    )
            )
        }
        .buttonStyle(.plain)
    }

    private var searchField: some View {
        HStack(spacing: 9) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14))
                .foregroundColor(ONETokens.oneStone)
            TextField(
                NSLocalizedString("friends.searchPlaceholder", comment: ""),
                text: $query
            )
            .textFieldStyle(.plain)
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
    }

    /// Frekans'taki kartla aynı dil: 46pt halka + %22 dış çember,
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
                Circle()
                    .fill(hasSong ? Color(hex: moodHex) : ONETokens.oneStone)
                    .frame(width: 46, height: 46)
                    .overlay(
                        Text(String(name.prefix(1)).uppercased())
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(.white)
                    )
                    .overlay(
                        Circle()
                            .stroke(
                                hasSong ? Color(hex: moodHex) : ONETokens.oneStone,
                                lineWidth: 1.5
                            )
                            .opacity(0.22)
                            .padding(-4)
                    )

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 7) {
                        Text(name)
                            .font(.system(size: 14.5, weight: .semibold))
                            .foregroundColor(ONETokens.oneInk)
                            .lineLimit(1)

                        if hasSong && !moodWord.isEmpty {
                            Text(moodWord)
                                .font(.system(size: 10.5, weight: .semibold))
                                .foregroundColor(Color(hex: moodHex))
                                .padding(.horizontal, 7)
                                .padding(.vertical, 2)
                                .background(
                                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                                        .fill(Color(hex: moodHex).opacity(0.14))
                                )
                        }
                        Spacer(minLength: 4)
                    }

                    Text(hasSong
                         ? "\(song) — \(artist)"
                         : NSLocalizedString("circle.notSharedYet", comment: ""))
                        .font(.system(size: 12.5))
                        .foregroundColor(ONETokens.oneAsh)
                        .lineLimit(1)
                }
            }
            .padding(.horizontal, 15)
            .padding(.vertical, 13)
            .frame(maxWidth: .infinity, alignment: .leading)
            .oneCardBackground(radius: ONETokens.radiusFriend, opacity: 0.78)
        }
        .buttonStyle(.plain)
    }

    /// Prototip `.inv`: avatar + isim + kabul/yoksay.
    private func incomingRow(_ pair: (request: CKRecord, sender: CKRecord)) -> some View {
        let name = pair.sender["displayName"] as? String ?? "?"
        let recordName = pair.request.recordID.recordName
        let isWorking = workingRequestID == recordName

        return HStack(spacing: 12) {
            Circle()
                .fill(ONETokens.oneCreamLow)
                .frame(width: 36, height: 36)
                .overlay(
                    Text(String(name.prefix(1)).uppercased())
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(ONETokens.oneAsh)
                )

            Text(name)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(ONETokens.oneInk)
                .lineLimit(1)

            Spacer()

            if isWorking {
                ProgressView().controlSize(.small)
            } else {
                Button(NSLocalizedString("friends.accept", comment: "")) {
                    accept(recordName: recordName)
                }
                .font(.system(size: 12.5, weight: .semibold))
                .foregroundColor(ONETokens.oneBrand)
                .buttonStyle(.plain)

                Button(NSLocalizedString("friends.ignore", comment: "")) {
                    decline(recordName: recordName)
                }
                .font(.system(size: 12.5, weight: .semibold))
                .foregroundColor(ONETokens.oneStone)
                .buttonStyle(.plain)
                .padding(.leading, 6)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .oneCardBackground(radius: 14, opacity: 0.75)
    }

    private func outgoingRow(_ pair: (request: CKRecord, receiver: CKRecord)) -> some View {
        let name = pair.receiver["displayName"] as? String ?? "?"

        return HStack(spacing: 12) {
            Circle()
                .fill(ONETokens.oneCreamLow)
                .frame(width: 36, height: 36)
                .overlay(
                    Text(String(name.prefix(1)).uppercased())
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(ONETokens.oneAsh)
                )

            Text(name)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(ONETokens.oneInk)
                .lineLimit(1)

            Spacer()

            Text(NSLocalizedString("friends.waiting", comment: ""))
                .font(.system(size: 12.5, weight: .semibold))
                .foregroundColor(ONETokens.oneStone)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .oneCardBackground(radius: 14, opacity: 0.75)
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
