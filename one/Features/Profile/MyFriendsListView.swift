//
//  MyFriendsListView.swift
//  one
//
//  Profil sekmesinde "N Arkadaş" satırına tıklayınca açılan,
//  yalnızca arkadaş listesi + her birinin profiline geçiş sunan
//  odaklı bir ekran. Çevre sekmesinin tamamını açmak yerine
//  kullanıcı sadece arkadaşlarını gözden geçirir.
//

import SwiftUI
import CloudKit

/// v2.6 — Identifiable wrapper for sheet(item:) profile presentation.
private struct ProfileSheetID: Identifiable, Hashable {
    let id: String
}

struct MyFriendsListView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var cloudKitManager = CloudKitManager.shared
    @ObservedObject var vm: ProfileViewModel

    @State private var friends: [CloudKitManager.FriendCircleData] = []
    @State private var isLoading = true
    @State private var loadError: String? = nil
    @State private var selectedFriend: CloudKitManager.FriendCircleData? = nil
    @State private var showAddFriend = false
    @State private var profileUserID: String? = nil  // v2.6 — public profile sheet

    private var profileColor: Color { Color(hex: vm.selectedAvatarColor) }
    private var screenBG: Color { vm.isDarkMode ? Color.black : ONETokens.oneCream }
    private var cardBG: Color { vm.isDarkMode ? Color.white.opacity(0.06) : ONETokens.onePaper.opacity(0.6) }
    private var cardBorder: Color { vm.isDarkMode ? Color.white.opacity(0.06) : ONETokens.oneSilver }
    private var primaryText: Color { vm.isDarkMode ? Color.white : ONETokens.oneInk }
    private var secondaryText: Color { vm.isDarkMode ? Color.white.opacity(0.55) : ONETokens.oneAsh }
    private var tertiaryText: Color { vm.isDarkMode ? Color.white.opacity(0.30) : ONETokens.oneStone }

    var body: some View {
        NavigationStack {
            ZStack {
                screenBG.ignoresSafeArea()

                if isLoading {
                    loadingView
                } else if let error = loadError {
                    errorView(error)
                } else if friends.isEmpty {
                    emptyView
                } else {
                    listView
                }
            }
            .navigationTitle(NSLocalizedString("myFriends.title", comment: ""))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(secondaryText)
                            .frame(width: 32, height: 32)
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showAddFriend = true }) {
                        Image(systemName: "person.badge.plus")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(primaryText)
                    }
                    .accessibilityLabel(NSLocalizedString("profile.addFriend.a11y", comment: ""))
                }
            }
            .onAppear { loadFriends() }
            .sheet(isPresented: $showAddFriend, onDismiss: { loadFriends() }) {
                AddFriendView()
            }
            .sheet(item: $selectedFriend) { data in
                FriendDetailView(friendData: data, onRefresh: { loadFriends() })
            }
            .sheet(item: Binding(
                get: { profileUserID.map { ProfileSheetID(id: $0) } },
                set: { profileUserID = $0?.id }
            )) { wrap in
                PublicProfileView(userID: wrap.id)
            }
        }
    }

    // MARK: - List

    private var listView: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 10) {
                ForEach(friends, id: \.user.recordID.recordName) { data in
                    Button(action: {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        if let uid = data.user["userID"] as? String, !uid.isEmpty {
                            profileUserID = uid
                        } else {
                            selectedFriend = data
                        }
                    }) {
                        friendRow(data: data)
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button {
                            selectedFriend = data
                        } label: {
                            Label(NSLocalizedString("myFriends.dailyShare", comment: "Günlük paylaşım"), systemImage: "music.note")
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 80)
        }
    }

    private func friendRow(data: CloudKitManager.FriendCircleData) -> some View {
        let name = data.user["displayName"] as? String ?? "Kullanıcı"
        let uname = data.user["username"] as? String ?? ""
        let colorHex = data.user["avatarColor"] as? String ?? "#888888"
        let initial = String(name.prefix(1)).uppercased()
        let moodHex = data.share?["moodColor"] as? String

        return HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color(hex: colorHex))
                    .frame(width: 46, height: 46)
                Text(initial)
                    .displayMD()
                    .fontWeight(.regular)
                    .italic()
                    .foregroundColor(.white.opacity(0.92))
            }
            // Bugün paylaştıysa mood color halkası
            .overlay(
                Circle()
                    .stroke(
                        moodHex != nil ? Color(hex: moodHex!) : Color.clear,
                        lineWidth: 2.5
                    )
                    .padding(-3)
            )

            VStack(alignment: .leading, spacing: 3) {
                Text(name)
                    .bodySMMedium()
                    .foregroundColor(primaryText)
                    .lineLimit(1)
                if !uname.isEmpty {
                    Text("@\(uname)")
                        .monoLabel(tracking: 0.3)
                        .foregroundColor(secondaryText)
                        .lineLimit(1)
                }
            }

            Spacer()

            // Bugün paylaştıysa "bugün" rozeti
            if let moodHex {
                HStack(spacing: 5) {
                    Circle().fill(Color(hex: moodHex)).frame(width: 6, height: 6)
                    Text(NSLocalizedString("myFriends.today", comment: ""))
                        .monoLabel(tracking: 0.4)
                        .foregroundColor(secondaryText)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Capsule().fill(Color(hex: moodHex).opacity(vm.isDarkMode ? 0.18 : 0.12)))
            }

            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(tertiaryText)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(cardBG)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(cardBorder, lineWidth: 1))
    }

    // MARK: - Empty

    private var emptyView: some View {
        VStack(spacing: 18) {
            Spacer()
            ZStack {
                Circle()
                    .stroke(profileColor.opacity(0.45), lineWidth: 1.4)
                    .frame(width: 78, height: 78)
                    .offset(x: -16)
                Circle()
                    .stroke(primaryText.opacity(0.3), lineWidth: 1.4)
                    .frame(width: 78, height: 78)
                    .offset(x: 16)
            }
            VStack(spacing: 8) {
                Text(NSLocalizedString("myFriends.empty.title", comment: ""))
                    .displaySM()
                    .foregroundColor(primaryText)
                    .multilineTextAlignment(.center)
                Text(NSLocalizedString("myFriends.empty.body", comment: ""))
                    .bodySM()
                    .foregroundColor(secondaryText)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .padding(.horizontal, 40)
            }
            Button(action: { showAddFriend = true }) {
                HStack(spacing: 6) {
                    Image(systemName: "person.badge.plus")
                        .font(.system(size: 13, weight: .medium))
                    Text(NSLocalizedString("circle.addFriend", comment: ""))
                        .monoSM(tracking: 0.6)
                }
                .foregroundColor(.white)
                .padding(.horizontal, 22)
                .padding(.vertical, 13)
                .background(Capsule().fill(profileColor))
            }
            .padding(.top, 6)
            Spacer()
            Spacer().frame(height: 80)
        }
        .padding(.horizontal, 24)
    }

    // MARK: - Loading / Error

    private var loadingView: some View {
        VStack(spacing: 12) {
            ProgressView()
                .scaleEffect(1.1)
                .tint(secondaryText)
            Text(NSLocalizedString("myFriends.loading", comment: ""))
                .monoSM(tracking: 0)
                .foregroundColor(secondaryText)
        }
    }

    private func errorView(_ msg: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 28, weight: .light))
                .foregroundColor(secondaryText)
            Text(msg)
                .bodySM()
                .foregroundColor(secondaryText)
                .multilineTextAlignment(.center)
            Button(NSLocalizedString("general.retry", comment: "")) {
                loadFriends()
            }
            .monoSM(tracking: 0.6)
            .foregroundColor(profileColor)
        }
        .padding(.horizontal, 32)
    }

    // MARK: - Loader

    private func loadFriends() {
        isLoading = true
        loadError = nil
        cloudKitManager.fetchFriendsDailyShares(for: Date()) { result in
            DispatchQueue.main.async {
                isLoading = false
                switch result {
                case .success(let list):
                    friends = list
                case .failure(let e):
                    loadError = e.localizedDescription
                }
            }
        }
    }
}
