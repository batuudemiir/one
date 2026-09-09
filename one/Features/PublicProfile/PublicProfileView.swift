//
//  PublicProfileView.swift
//  one
//
//  Public profil sheet — hero gradient, CTA matrisi, pinned song, mood strip.
//  Sheet olarak açılır. .self_ durumunda hiçbir şey göstermez (caller guard).
//

@preconcurrency import SwiftUI
import Combine
import CloudKit

private final class TokenBox: @unchecked Sendable { var token: NSObjectProtocol? }
private final class ResumedBox: @unchecked Sendable { var value = false }

// MARK: - ViewModel

@MainActor
final class PublicProfileViewModel: ObservableObject {
    @Published var profile: PublicUserProfile?
    @Published var relationship: PublicProfileRelationship = .none
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var pendingIncomingRecordID: CKRecord.ID?
    @Published var mutualFriendCount: Int = 0

    let userID: String

    init(userID: String) {
        self.userID = userID
    }

    func load() {
        Task {
            isLoading = true
            defer { isLoading = false }
            await refreshBlockCache()
            await loadProfile()
            await loadRelationship()
            // isPublic gate — arkadaş veya kendisi değilse gizli profili gösterme
            if let p = profile, !p.isPublic,
               relationship != .friend, relationship != .self_ {
                profile = nil
                errorMessage = "Bu profil gizlidir."
                return
            }
            await loadMutualFriendCount()
        }
    }

    private func refreshBlockCache() async {
        await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
            CloudKitManager.shared.fetchMyBlockRelations { _ in cont.resume() }
        }
    }

    private func loadProfile() async {
        // Cache snapshot — anında render, ardından store'dan taze fetch
        if let snap = UserProfileStore.shared.snapshot(for: userID) {
            profile = snap
        }
        UserProfileStore.shared.invalidate(userID: userID)

        // Profil cache'de yoksa store fetch'inin tamamlanmasını bekle (en fazla 4 sn)
        if profile == nil {
            await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
                let box = TokenBox()
                let resumed = ResumedBox()
                let observer = NotificationCenter.default.addObserver(
                    forName: .userProfileDidChange, object: nil, queue: .main
                ) { [weak self] notif in
                    guard let self,
                          let uid = notif.object as? String, uid == self.userID else { return }
                    if let t = box.token { NotificationCenter.default.removeObserver(t) }
                    guard !resumed.value else { return }
                    resumed.value = true
                    cont.resume()
                }
                box.token = observer
                DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
                    if let t = box.token { NotificationCenter.default.removeObserver(t) }
                    guard !resumed.value else { return }
                    resumed.value = true
                    cont.resume()
                }
            }
            if let snap = UserProfileStore.shared.snapshot(for: userID) {
                profile = snap
            } else {
                errorMessage = NSLocalizedString("publicProfile.loadFailed", comment: "")
            }
        }
    }

    private func loadRelationship() async {
        let currentUserID = CloudKitManager.shared.currentUser?["userID"] as? String ?? ""
        if userID == currentUserID { relationship = .self_; return }

        if CloudKitManager.shared.isBlockedByMe(userID) {
            relationship = .blockedByMe; return
        }
        if CloudKitManager.shared.isBlockedByThem(userID) {
            relationship = .blockedMe; return
        }

        await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
            CloudKitManager.shared.checkExistingRelationship(with: userID) { [weak self] status in
                guard let self else { cont.resume(); return }
                switch status {
                case .alreadyFriends:
                    Task { @MainActor in self.relationship = .friend }
                    cont.resume()
                case .pendingSent:
                    Task { @MainActor in
                        self.relationship = .pendingOutgoing
                    }
                    cont.resume()
                case .pendingReceived:
                    CloudKitManager.shared.fetchPendingRequestFrom(userID: self.userID) { result in
                        if case .success(let rec) = result {
                            Task { @MainActor in
                                self.pendingIncomingRecordID = rec.recordID
                                self.relationship = .pendingIncoming(recordID: rec.recordID)
                            }
                        } else {
                            Task { @MainActor in self.relationship = .none }
                        }
                        cont.resume()
                    }
                case .blocked(let byMe):
                    Task { @MainActor in self.relationship = byMe ? .blockedByMe : .blockedMe }
                    cont.resume()
                case .none:
                    Task { @MainActor in self.relationship = .none }
                    cont.resume()
                }
            }
        }
    }

    private func loadMutualFriendCount() async {
        let count = await CloudKitManager.shared.fetchMutualFriendCount(withUserID: userID)
        mutualFriendCount = count
        if var p = profile {
            p.mutualFriendCount = count
            profile = p
        }
    }

    // MARK: - CTA Actions

    func sendRequest(completion: @escaping (Result<Void, Error>) -> Void) {
        CloudKitManager.shared.sendFriendRequest(toUserID: userID) { [weak self] result in
            switch result {
            case .success:
                Task { @MainActor in
                    self?.relationship = .pendingOutgoing
                }
                AppAnalytics.shared.track(.friendRequestSent)
                completion(.success(()))
            case .failure(let e):
                completion(.failure(e))
            }
        }
    }

    func cancelRequest(completion: @escaping (Result<Void, Error>) -> Void) {
        CloudKitManager.shared.cancelFriendRequest(toUserID: userID) { [weak self] result in
            switch result {
            case .success:
                Task { @MainActor in self?.relationship = .none }
                completion(.success(()))
            case .failure(let e): completion(.failure(e))
            }
        }
    }

    func acceptIncoming(completion: @escaping (Result<Void, Error>) -> Void) {
        guard let rec = pendingIncomingRecordID else {
            completion(.failure(NSError(domain: "none", code: 0))); return
        }
        CloudKitManager.shared.acceptFriendRequest(recordID: rec.recordName) { [weak self] result in
            switch result {
            case .success:
                Task { @MainActor in self?.relationship = .friend }
                completion(.success(()))
            case .failure(let e): completion(.failure(e))
            }
        }
    }

    func declineIncoming(completion: @escaping (Result<Void, Error>) -> Void) {
        guard let rec = pendingIncomingRecordID else {
            completion(.failure(NSError(domain: "none", code: 0))); return
        }
        CloudKitManager.shared.declineFriendRequest(recordID: rec.recordName) { [weak self] result in
            switch result {
            case .success:
                Task { @MainActor in self?.relationship = .none }
                completion(.success(()))
            case .failure(let e): completion(.failure(e))
            }
        }
    }

    func block(completion: @escaping (Result<Void, Error>) -> Void) {
        CloudKitManager.shared.blockUser(userID: userID) { [weak self] result in
            switch result {
            case .success:
                Task { @MainActor in self?.relationship = .blockedByMe }
                completion(.success(()))
            case .failure(let e): completion(.failure(e))
            }
        }
    }

    func unblock(completion: @escaping (Result<Void, Error>) -> Void) {
        CloudKitManager.shared.unblockUser(userID: userID) { [weak self] result in
            switch result {
            case .success:
                Task { @MainActor in self?.relationship = .none }
                completion(.success(()))
            case .failure(let e): completion(.failure(e))
            }
        }
    }
}

// MARK: - View

struct PublicProfileView: View {
    @StateObject private var vm: PublicProfileViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var appeared = false
    @State private var isWorking = false
    @State private var toast: String?
    @State private var showReport = false
    @State private var showBlockConfirm = false
    @State private var storeObservation: AnyCancellable? = nil

    init(userID: String) {
        _vm = StateObject(wrappedValue: PublicProfileViewModel(userID: userID))
    }

    var body: some View {
        ZStack(alignment: .top) {
            V3Tokens.paper.ignoresSafeArea()

            if vm.relationship == .blockedMe {
                blockedMeState
            } else {
                mainContent
            }

            // Top bar — kendi ProfileTopBarOverlay gibi sticky, hero üzerinde gezer
            if vm.relationship != .blockedMe {
                topBar
                    .zIndex(10)
            }
        }
        .liquidGlassSheetBackground()
        .v3Sheet(detents: [.large])
        .onAppear {
            vm.load()
            // Store değişim observer'ı: kullanıcı profili (foto/pinned/isim) güncellenince
            // public profile sheet anında tazelensin.
            storeObservation = NotificationCenter.default
                .publisher(for: .userProfileDidChange)
                .receive(on: DispatchQueue.main)
                .sink { notif in
                    guard let uid = notif.object as? String,
                          uid == vm.userID,
                          let snap = UserProfileStore.shared.snapshot(for: uid) else { return }
                    var updated = snap
                    updated.mutualFriendCount = vm.profile?.mutualFriendCount
                    vm.profile = updated
                }
            withAnimation(ONEAnimation.panelSpring) { appeared = true }
        }
        .onDisappear {
            storeObservation?.cancel()
            storeObservation = nil
        }
        .sheet(isPresented: $showReport) {
            if let p = vm.profile {
                ReportSheet(target: .user(id: p.id, displayName: p.displayName))
            }
        }
        .v3Sheet()
        .confirmationDialog(
            NSLocalizedString("circle.blockConfirmTitle", comment: ""),
            isPresented: $showBlockConfirm,
            titleVisibility: .visible
        ) {
            Button(NSLocalizedString("circle.blockAction", comment: ""), role: .destructive) { blockAction() }
            Button(NSLocalizedString("common.cancel", comment: ""), role: .cancel) {}
        } message: {
            Text(NSLocalizedString("block.confirmBody", comment: ""))
        }
    }

    // MARK: - Main content

    private var mainContent: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                // Hero (full-bleed, 420pt) — kendi profil sekmesi ile aynı dil
                PublicProfileHeroSection(profile: vm.profile)
                    .listItemEntrance(isVisible: appeared, index: 0)

                VStack(alignment: .leading, spacing: 18) {
                    // CTA row (index 1)
                    PublicProfileCTARow(
                        relationship: vm.relationship,
                        mutualFriendCount: vm.mutualFriendCount > 0 ? vm.mutualFriendCount : nil,
                        isWorking: isWorking,
                        onAdd: addAction,
                        onCancelRequest: cancelAction,
                        onAccept: acceptAction,
                        onDecline: declineAction
                    )
                    .listItemEntrance(isVisible: appeared, index: 1)

                    // Sabitlenmiş şarkı (index 2) — kendi ProfilePinnedSongCard yerleşimi
                    if let song = vm.profile?.pinnedSong {
                        VStack(alignment: .leading, spacing: 10) {
                            Text(NSLocalizedString("profile.pinnedSong", comment: ""))
                                .monoBase(tracking: 1.5)
                                .foregroundColor(V3Tokens.mutedText)
                                .padding(.leading, V3Tokens.spacingXS)

                            PublicProfilePinnedSongCard(song: song)
                        }
                        .padding(.horizontal, V3Tokens.spacingXL)
                        .listItemEntrance(isVisible: appeared, index: 2)
                    }

                    // Son 7 gün (index 3) — kendi ProfileRecentMoodStrip ile aynı yerleşim
                    if let p = vm.profile, p.moodHistoryVisible {
                        moodStripSection
                            .padding(.horizontal, V3Tokens.spacingXL)
                            .listItemEntrance(isVisible: appeared, index: 3)
                    }

                    if let toast {
                        Text(toast)
                            .monoSM(tracking: 0)
                            .foregroundStyle(V3Tokens.mutedText)
                            .padding(.top, V3Tokens.spacingXS)
                            .frame(maxWidth: .infinity)
                    }
                }
                .padding(.top, 18)
                .padding(.bottom, V3Tokens.spacingXL4)
            }
        }
        .ignoresSafeArea(edges: .top)
    }

    // MARK: - Top bar (close + more)
    // Hero foto/gradient üzerinde gezer — Liquid Glass tarzı hafif blur kapsül.

    private var topBar: some View {
        // Ortak `V3TopBar`, `.media` zeminiyle: kapat zaten doğru köşedeydi
        // ama satır elle kuruluyordu — kendi yatay payı (16pt), kendi
        // yüksekliği. Artık diğer on bir ekranla aynı 44pt satır ve aynı
        // `barInset` hizası.
        //
        // Başlık yuvası boş: ekranın adı kişinin kendisi ve o, hemen
        // altındaki hero'da duruyor.
        V3TopBar(
            leading: .close { dismiss() },
            leadingGround: .media,
            progress: 0
        ) {
            moreMenu
        }
    }

    @ViewBuilder
    private var moreMenu: some View {
        if vm.relationship != .self_ {
            Menu {
                Button(NSLocalizedString("report.title", comment: ""), systemImage: "flag") {
                    showReport = true
                }
                if case .blockedByMe = vm.relationship {
                    Button(NSLocalizedString("circle.unblockAction", comment: ""), systemImage: "lock.open") {
                        unblockAction()
                    }
                } else {
                    Button(
                        NSLocalizedString("circle.blockAction", comment: ""),
                        systemImage: "hand.raised",
                        role: .destructive
                    ) { showBlockConfirm = true }
                }
            } label: {
                Image(systemName: "ellipsis")
                    .v3TopBarIconGround(.media)
                    .frame(width: 44, height: 44)
                    .contentShape(Circle())
            }
            .accessibilityLabel(NSLocalizedString("general.more", comment: ""))
        }
    }

    // MARK: - Mood strip section
    // Kendi profil sekmesi `ProfileRecentMoodStripSection` ile aynı dil:
    // başlık + bugün vurgulu kart + günler.

    @ViewBuilder
    private var moodStripSection: some View {
        if let p = vm.profile {
            let recentColors: [Color?] = {
                guard p.moodHistoryVisible,
                      let colors = p.moodHistoryColors else {
                    return Array(repeating: nil, count: 7)
                }
                let last7 = Array(colors.suffix(7))
                let cols: [Color?] = last7.map { Color(hex: $0) }
                return cols + Array(repeating: nil, count: max(0, 7 - cols.count))
            }()

            VStack(alignment: .leading, spacing: V3Tokens.spacingMD) {
                HStack(spacing: V3Tokens.spacingSM) {
                    Text(NSLocalizedString("profile.recentWeek.title", comment: ""))
                        .monoBase(tracking: 1.5)
                        .foregroundColor(V3Tokens.mutedText)
                    Spacer()
                    Text(NSLocalizedString("profile.recentWeek.subtitle", comment: ""))
                        .monoLabel(tracking: 0.6)
                        .foregroundColor(V3Tokens.faintText)
                }

                HStack(spacing: V3Tokens.spacingSM) {
                    ForEach(0..<7, id: \.self) { idx in
                        VStack(spacing: V3Tokens.spacingSM) {
                            ZStack {
                                RoundedRectangle(cornerRadius: V3Tokens.radiusInner)
                                    .fill(recentColors[idx] ?? V3Tokens.hairline.opacity(0.45))
                                if recentColors[idx] == nil {
                                    Image(systemName: "minus")
                                        .monoMicro()
                                        .foregroundColor(V3Tokens.faintText)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .overlay(
                                RoundedRectangle(cornerRadius: V3Tokens.radiusInner)
                                    .stroke(
                                        idx == 6 ? V3Tokens.ink.opacity(0.30) : Color.clear,
                                        lineWidth: 1.5
                                    )
                            )

                            Text(weekdayLabels[idx])
                                .monoLabel(tracking: 0.4)
                                .foregroundColor(idx == 6 ? V3Tokens.ink : V3Tokens.mutedText)
                        }
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 14)
                .oneCardBackground(radius: V3Tokens.radiusPanel)
            }
        }
    }

    /// Son 7 günün haftaiçi kısa etiketleri (Pzt, Sal, …, Bugün).
    private var weekdayLabels: [String] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let formatter = DateFormatter()
        formatter.locale = LanguageManager.shared.currentLocale
        formatter.dateFormat = "EE"
        return (0..<7).reversed().map { offset in
            guard let day = cal.date(byAdding: .day, value: -offset, to: today) else { return "·" }
            if offset == 0 { return NSLocalizedString("profile.recentWeek.todayShort", comment: "") }
            return formatter.string(from: day).prefix(3).description
        }
    }

    // MARK: - Blocked state

    private var blockedMeState: some View {
        VStack(spacing: V3Tokens.spacingLG) {
            Spacer()
            Image(systemName: "hand.raised.slash")
                .font(.system(size: 40, weight: .light))
                .foregroundStyle(V3Tokens.mutedText)
            Text(NSLocalizedString("publicProfile.unavailable", comment: ""))
                .bodySM()
                .foregroundStyle(V3Tokens.mutedText)
            Button(NSLocalizedString("general.close", comment: "")) { dismiss() }
            .buttonStyle(.onePressable)
                .foregroundStyle(V3Tokens.korText)
            Spacer()
        }
    }

    // MARK: - Actions

    private func addAction() {
        isWorking = true
        vm.sendRequest { result in
            isWorking = false
            handle(result, successToast: NSLocalizedString("circle.toast.requestSent", comment: ""))
        }
    }

    private func cancelAction() {
        isWorking = true
        vm.cancelRequest { result in
            isWorking = false
            handle(result, successToast: NSLocalizedString("circle.toast.requestCancelled", comment: ""))
        }
    }

    private func acceptAction() {
        isWorking = true
        vm.acceptIncoming { result in
            isWorking = false
            handle(result, successToast: NSLocalizedString("circle.toast.nowInCircle", comment: ""))
        }
    }

    private func declineAction() {
        isWorking = true
        vm.declineIncoming { result in
            isWorking = false
            handle(result, successToast: NSLocalizedString("circle.toast.declined", comment: ""))
        }
    }

    private func blockAction() {
        isWorking = true
        vm.block { result in
            isWorking = false
            handle(result, successToast: NSLocalizedString("circle.toast.blocked", comment: ""))
        }
    }

    private func unblockAction() {
        isWorking = true
        vm.unblock { result in
            isWorking = false
            handle(result, successToast: NSLocalizedString("circle.toast.unblocked", comment: ""))
        }
    }

    private func handle(_ result: Result<Void, Error>, successToast: String) {
        switch result {
        case .success: toast = successToast
        case .failure(let e): toast = e.localizedDescription
        }
    }
}
