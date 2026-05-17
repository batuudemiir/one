//
//  FriendRequestsView.swift
//  one
//
//  Çevre Bildirimleri — tek birleşik Instagram tarzı aktivite akışı
//  Arkadaşlık istekleri + tüm çevre aktiviteleri tek listede
//

import SwiftUI
import CloudKit

// MARK: - FriendRequestsView (Birleşik Aktivite Akışı)

struct FriendRequestsView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var cloudKitManager = CloudKitManager.shared
    @StateObject private var notificationStore = CircleNotificationStore.shared

    @State private var items: [FriendNotificationItem] = []
    @State private var isLoading = false
    @State private var processingIDs: Set<String> = []

    // Sheet state
    @State private var selectedCommentShareName: IdentifiableString? = nil   // comment taps
    @State private var fetchedFriendShare: IdentifiableCKRecord? = nil        // friendShare taps
    @State private var isFetchingShare = false

    // MARK: - Computed

    private var incoming: [FriendNotificationItem] {
        items.filter { if case .incoming = $0 { return true }; return false }
    }
    private var outgoing: [FriendNotificationItem] {
        items.filter { if case .outgoing = $0 { return true }; return false }
    }

    /// Birleşik akış: istek kartları üstte, aktivite akışı altta
    private var unifiedSections: [NotificationSection] {
        var sections: [NotificationSection] = []

        // Bölüm 1: Bekleyen arkadaşlık istekleri (live CloudKit)
        let requestItems = (incoming.map { $0 } + outgoing.map { $0 })
            .sorted { $0.date > $1.date }
        if !requestItems.isEmpty {
            sections.append(.requests(requestItems))
        }

        // Bölüm 2: Aktivite akışı (store'dan)
        let activities = notificationStore.activityNotifications
        if !activities.isEmpty {
            sections.append(.activity(activities))
        }

        return sections
    }

    var body: some View {
        NavigationStack {
            ZStack {
                ONETokens.oneCream.ignoresSafeArea()

                if isLoading && items.isEmpty && notificationStore.notifications.isEmpty {
                    skeletonList
                } else if unifiedSections.isEmpty {
                    emptyState
                } else {
                    unifiedList
                }
            }
            .navigationTitle(NSLocalizedString("friendRequests.title", comment: ""))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if notificationStore.unreadCount > 0 {
                        Button {
                            withAnimation(ONEAnimation.micro) { notificationStore.markAllRead() }
                        } label: {
                            Text(NSLocalizedString("friendRequests.markAllRead", comment: ""))
                                .monoSM(tracking: 0)
                                .foregroundColor(ONETokens.oneAsh)
                        }
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(NSLocalizedString("general.close", comment: "")) { dismiss() }
                        .monoSM(tracking: 0)
                        .foregroundColor(ONETokens.oneInk)
                }
            }
            .onAppear {
                load()
                notificationStore.markAllRead()
            }
            .sheet(item: $selectedCommentShareName) { item in
                CommentThreadView(
                    shareRecordName: item.value,
                    shareOwnerID: cloudKitManager.currentUser?["userID"] as? String ?? "",
                    showComposer: false
                )
                .id(item.value)
                .presentationDetents([.large])
                .presentationDragIndicator(.hidden)
            }
            .sheet(item: $fetchedFriendShare) { item in
                FriendShareDetailView(share: item.record, friendDisplayName: item.friendDisplayName)
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
            }
        }
    }

    // MARK: - Unified List

    private var unifiedList: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: 10) {
                ForEach(unifiedSections) { section in
                    switch section {
                    case .requests(let requestItems):
                        // İstek bölümü başlığı
                        SectionHeader(
                            icon: "person.badge.plus",
                            title: NSLocalizedString("friendRequests.requestsSection", comment: ""),
                            count: requestItems.count
                        )
                        .padding(.horizontal, 20)

                        ForEach(Array(requestItems.enumerated()), id: \.element.id) { index, item in
                            Group {
                                switch item {
                                case .incoming(let req, let sender):
                                    incomingCard(req: req, sender: sender)
                                case .outgoing(let req, let receiver):
                                    outgoingCard(req: req, receiver: receiver)
                                }
                            }
                            .transition(.opacity.combined(with: .move(edge: .top)))
                            .animation(
                                .spring(response: 0.35, dampingFraction: 0.8)
                                .delay(Double(index) * 0.05),
                                value: requestItems.count
                            )
                        }

                    case .activity(let activities):
                        // Aktivite bölümü başlığı
                        SectionHeader(
                            icon: "bell.fill",
                            title: NSLocalizedString("friendRequests.activitySection", comment: ""),
                            count: activities.count
                        )
                        .padding(.horizontal, 20)
                        .padding(.top, requestSection.isEmpty ? 0 : 12)

                        ForEach(Array(activities.enumerated()), id: \.element.id) { index, notif in
                            activityCard(notif)
                                .transition(.opacity.combined(with: .move(edge: .top)))
                                .animation(
                                    .spring(response: 0.35, dampingFraction: 0.8)
                                    .delay(Double(index) * 0.03),
                                    value: activities.count
                                )
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 40)
        }
        .refreshable { load() }
    }

    private var requestSection: [FriendNotificationItem] {
        (incoming + outgoing).sorted { $0.date > $1.date }
    }

    // MARK: - Section Header

    private struct SectionHeader: View {
        let icon: String
        let title: String
        let count: Int

        var body: some View {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .monoBase()
                    .foregroundColor(ONETokens.oneAsh)
                Text(title)
                    .monoSM(tracking: 0.8)
                    .foregroundColor(ONETokens.oneAsh)
                if count > 0 {
                    Text("\(count)")
                        .monoMicro().fontWeight(.bold)
                        .foregroundColor(ONETokens.oneCream)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(ONETokens.oneInk))
                }
                Spacer()
            }
        }
    }

    // MARK: - Activity Card (Instagram tarzı)

    @ViewBuilder
    private func activityCard(_ notif: CircleNotification) -> some View {
        HStack(spacing: 16) {
            // Sol ikon — mood rengi veya tip ikonu
            ZStack {
                Circle()
                    .fill(activityIconBackground(notif))
                    .frame(width: 48, height: 48)
                if let emoji = notif.emoji {
                    Text(emoji)
                        .font(.system(size: 22))
                } else {
                    Image(systemName: activityIcon(notif))
                        .bodyXL().fontWeight(.medium)
                        .foregroundColor(activityIconColor(notif))
                }
            }

            // İçerik
            VStack(alignment: .leading, spacing: 4) {
                Text(notif.title)
                    .bodySM().fontWeight(notif.isRead ? .medium : .bold)
                    .foregroundColor(ONETokens.oneInk)
                    .lineLimit(2)
                
                if !notif.body.isEmpty {
                    Text(notif.body)
                        .bodyXS()
                        .foregroundColor(ONETokens.oneMist)
                        .lineLimit(2)
                }
                
                HStack(spacing: 6) {
                    Text(relativeTime(notif.date))
                        .monoBase()
                        .foregroundColor(ONETokens.oneMist)
                    
                    if let hex = notif.moodColorHex {
                        Circle()
                            .fill(Color(hex: hex))
                            .frame(width: 8, height: 8)
                    }
                }
            }

            Spacer()
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 20)
        .background(notif.isRead ? Color.clear : ONETokens.oneCreamLow.opacity(0.5))
        .contentShape(Rectangle())
        .onTapGesture { handleActivityTap(notif) }
    }

    // MARK: - Activity Helpers

    private func activityIcon(_ notif: CircleNotification) -> String {
        switch notif.type {
        case .friendAccepted: return "person.fill.checkmark"
        case .friendShare:    return "music.note"
        case .emojiReaction:  return "heart.fill"
        case .friendRequest:  return "person.badge.plus"
        case .comment:        return "bubble.left.fill"
        case .moodResonance:  return "wave.3.forward"
        case .resonance:      return "wave.3.right"
        case .outgoingRequest: return "paperplane"
        }
    }

    private func activityIconColor(_ notif: CircleNotification) -> Color {
        switch notif.type {
        case .friendAccepted: return .green
        case .friendShare:    return .blue
        case .emojiReaction:  return .orange
        case .friendRequest:  return ONETokens.oneInk
        case .comment:        return .purple
        case .moodResonance:  return Color(hex: (notif.moodColorHex?.isValidHexColor == true ? notif.moodColorHex! : "#888888"))
        case .resonance:      return Color(hex: (notif.moodColorHex?.isValidHexColor == true ? notif.moodColorHex! : "#888888"))
        case .outgoingRequest: return ONETokens.oneAsh
        }
    }

    private func activityIconBackground(_ notif: CircleNotification) -> Color {
        if let hex = notif.moodColorHex {
            return Color(hex: hex).opacity(0.15)
        }
        return activityIconColor(notif).opacity(0.15)
    }

    private func handleActivityTap(_ notif: CircleNotification) {
        notificationStore.update(id: notif.id) { n in n.isRead = true }

        switch notif.type {
        case .comment, .resonance:
            // Kendi paylaşımıma gelen yorum — doğrudan yorum thread'i
            if let shareName = notif.shareRecordName {
                selectedCommentShareName = IdentifiableString(shareName)
            }
        case .friendShare:
            // Arkadaşın paylaşımı — CKRecord fetch edip detay aç
            if let shareName = notif.shareRecordName, !isFetchingShare {
                isFetchingShare = true
                let recordID = CKRecord.ID(recordName: shareName)
                CloudKitManager.shared.publicDatabase.fetch(withRecordID: recordID) { record, _ in
                    DispatchQueue.main.async {
                        self.isFetchingShare = false
                        guard let record else { return }
                        let displayName = notif.relatedUserID.flatMap { _ in
                            // Title'dan ad parçasını al: "X paylaşım yaptı 🎵"
                            notif.title.components(separatedBy: " paylaşım").first
                        } ?? ""
                        self.fetchedFriendShare = IdentifiableCKRecord(record, displayName: displayName)
                    }
                }
            }
        default:
            break
        }
    }

    // MARK: - Skeleton

    private var skeletonList: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: 0) {
                ForEach(0..<4, id: \.self) { i in
                    skeletonCard
                        .animation(.easeInOut(duration: 0.6).delay(Double(i) * 0.1).repeatForever(autoreverses: true),
                                   value: isLoading)
                }
            }
            .padding(.top, 8)
        }
    }

    private var skeletonCard: some View {
        HStack(spacing: 16) {
            Circle()
                .fill(ONETokens.oneCreamMid)
                .frame(width: 48, height: 48)
            VStack(alignment: .leading, spacing: 7) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(ONETokens.oneCreamMid)
                    .frame(width: 140, height: 12)
                RoundedRectangle(cornerRadius: 4)
                    .fill(ONETokens.oneSilver)
                    .frame(width: 90, height: 9)
            }
            Spacer()
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 20)
        .shimmeringCircle()
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 0) {
            Spacer()
            VStack(spacing: 20) {
                ZStack {
                    Circle()
                        .fill(ONETokens.oneSilver.opacity(0.4))
                        .frame(width: 80, height: 80)
                    Image(systemName: "bell.slash")
                        .displayHero().fontWeight(.light)
                        .foregroundColor(ONETokens.oneAsh)
                }

                VStack(spacing: 8) {
                    Text(NSLocalizedString("friendRequests.noNotifications", comment: ""))
                        .bodyXL().fontWeight(.semibold)
                        .foregroundColor(ONETokens.oneInk)
                    Text(NSLocalizedString("friendRequests.noNotificationsHint", comment: ""))
                        .bodySM()
                        .multilineTextAlignment(.center)
                        .foregroundColor(ONETokens.oneAsh)
                        .lineSpacing(3)
                        .padding(.horizontal, 20)
                }
            }
            .padding(.horizontal, 40)
            .transition(.opacity.combined(with: .scale(scale: 0.95)))
            Spacer()
        }
    }

    // MARK: - Incoming Card

    private func incomingCard(req: CKRecord, sender: CKRecord) -> some View {
        let name       = sender["displayName"] as? String ?? NSLocalizedString("friendRequests.unknown", comment: "")
        let color      = sender["avatarColor"] as? String ?? "#888888"
        let initial    = String(name.prefix(1)).uppercased()
        let recName    = req.recordID.recordName
        let processing = processingIDs.contains(recName)

        return HStack(spacing: 16) {
            avatarCircle(initial: initial, colorHex: color, size: 52)
                .overlay(alignment: .bottomTrailing) {
                    ZStack {
                        Circle().fill(ONETokens.oneCream)
                        Image(systemName: "arrow.down.circle.fill")
                            .bodyLG()
                            .foregroundColor(ONETokens.oneInk)
                    }
                    .frame(width: 22, height: 22)
                    .offset(x: 2, y: 2)
                }

            VStack(alignment: .leading, spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(name)
                        .bodyMD().fontWeight(.bold)
                        .foregroundColor(ONETokens.oneInk)
                    Text(String(format: NSLocalizedString("friendRequests.sentYouRequest", comment: ""), name))
                        .bodyXS()
                        .foregroundColor(ONETokens.oneMist)
                }

                if processing {
                    ProgressView().scaleEffect(0.85)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    HStack(spacing: 10) {
                        Button(action: { accept(recName: recName) }) {
                            Text(NSLocalizedString("friendRequests.accept", comment: "Kabul Et"))
                                .bodyXS().fontWeight(.semibold)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .background(RoundedRectangle(cornerRadius: 8).fill(ONETokens.oneInk))
                        }
                        
                        Button(action: { decline(recName: recName) }) {
                            Text(NSLocalizedString("friendRequests.decline", comment: "Reddet"))
                                .bodyXS().fontWeight(.semibold)
                                .foregroundColor(ONETokens.oneInk)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .background(RoundedRectangle(cornerRadius: 8).fill(ONETokens.oneSilver.opacity(0.5)))
                        }
                    }
                }
            }
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 20)
        .background(ONETokens.oneCreamLow.opacity(0.5))
    }

    // MARK: - Outgoing Card

    private func outgoingCard(req: CKRecord, receiver: CKRecord) -> some View {
        let name       = receiver["displayName"] as? String ?? NSLocalizedString("friendRequests.unknown", comment: "")
        let color      = receiver["avatarColor"] as? String ?? "#888888"
        let initial    = String(name.prefix(1)).uppercased()
        let recName    = req.recordID.recordName
        let processing = processingIDs.contains(recName)

        return HStack(spacing: 16) {
            avatarCircle(initial: initial, colorHex: color, size: 52)
                .overlay(alignment: .bottomTrailing) {
                    ZStack {
                        Circle().fill(ONETokens.oneCream)
                        Image(systemName: "paperplane.fill")
                            .monoBase().fontWeight(.medium)
                            .foregroundColor(ONETokens.oneAsh)
                    }
                    .frame(width: 22, height: 22)
                    .offset(x: 2, y: 2)
                }

            VStack(alignment: .leading, spacing: 4) {
                Text(name)
                    .bodyMD().fontWeight(.bold)
                    .foregroundColor(ONETokens.oneInk)
                Text(NSLocalizedString("friendRequests.pending", comment: "Bekliyor"))
                    .bodyXS()
                    .foregroundColor(ONETokens.oneMist)
            }

            Spacer()

            if processing {
                ProgressView().scaleEffect(0.8)
            } else {
                Button {
                    cancelOutgoing(req: req, receiverID: receiver["userID"] as? String ?? "")
                } label: {
                    Text(NSLocalizedString("friendRequests.withdraw", comment: "Geri Çek"))
                        .bodyXS().fontWeight(.semibold)
                        .foregroundColor(ONETokens.oneAsh)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(RoundedRectangle(cornerRadius: 8).fill(ONETokens.oneSilver.opacity(0.3)))
                }
            }
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 20)
    }

    // MARK: - Helpers

    @ViewBuilder
    private func avatarCircle(initial: String, colorHex: String, size: CGFloat) -> some View {
        Circle()
            .fill(Color(hex: colorHex))
            .frame(width: size, height: size)
            .overlay(
                Text(initial)
                    .font(.system(size: size * 0.4, weight: .bold, design: .default))
                    .foregroundColor(.white.opacity(0.95))
            )
    }

    private func relativeTime(_ date: Date?) -> String {
        guard let d = date else { return "" }
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .short
        f.locale = LanguageManager.shared.currentLocale
        return f.localizedString(for: d, relativeTo: Date())
    }

    // MARK: - Load

    private func load() {
        isLoading = true
        Task {
            if cloudKitManager.currentUser == nil {
                let loaded = await cloudKitManager.ensureCurrentUser()
                guard loaded else {
                    await MainActor.run { isLoading = false }
                    return
                }
            }
            await MainActor.run { performLoad() }
        }
    }

    private func performLoad() {
        let group = DispatchGroup()
        var incomingItems: [FriendNotificationItem] = []
        var outgoingItems: [FriendNotificationItem] = []

        group.enter()
        cloudKitManager.fetchPendingRequests { result in
            if case .success(let pairs) = result {
                incomingItems = pairs.map { .incoming(request: $0.request, sender: $0.sender) }
            }
            group.leave()
        }

        group.enter()
        cloudKitManager.fetchSentRequests { result in
            if case .success(let pairs) = result {
                outgoingItems = pairs.map { .outgoing(request: $0.request, receiver: $0.receiver) }
            }
            group.leave()
        }

        group.notify(queue: .main) {
            isLoading = false
            let combined = (incomingItems + outgoingItems).sorted { $0.date > $1.date }
            withAnimation(.easeInOut(duration: 0.2)) { self.items = combined }
        }
    }

    // MARK: - Actions

    private func accept(recName: String) {
        processingIDs.insert(recName)
        cloudKitManager.acceptFriendRequest(recordID: recName) { result in
            processingIDs.remove(recName)
            switch result {
            case .success:
                withAnimation(ONEAnimation.micro) {
                    items.removeAll { $0.id == "in_\(recName)" }
                }
                notificationStore.removeByRequestRecordName(recName)
                ErrorHandler.shared.showSuccess(NSLocalizedString("friendRequests.friendAccepted", comment: ""))
            case .failure(let e):
                ErrorHandler.shared.handle(e, context: "accept friend request")
            }
        }
    }

    private func decline(recName: String) {
        processingIDs.insert(recName)
        cloudKitManager.declineFriendRequest(recordID: recName) { result in
            processingIDs.remove(recName)
            if case .success = result {
                withAnimation(ONEAnimation.micro) {
                    items.removeAll { $0.id == "in_\(recName)" }
                }
                notificationStore.removeByRequestRecordName(recName)
            }
        }
    }

    private func cancelOutgoing(req: CKRecord, receiverID: String) {
        let recName = req.recordID.recordName
        processingIDs.insert(recName)
        cloudKitManager.cancelFriendRequest(toUserID: receiverID) { result in
            processingIDs.remove(recName)
            if case .success = result {
                withAnimation(ONEAnimation.micro) {
                    items.removeAll { $0.id == "out_\(recName)" }
                }
                notificationStore.removeByRequestRecordName(recName)
                ErrorHandler.shared.showSuccess(NSLocalizedString("friendRequests.requestWithdrawn", comment: ""))
            }
        }
    }
}

// MARK: - Notification Section Model

private enum NotificationSection: Identifiable {
    case requests([FriendNotificationItem])
    case activity([CircleNotification])

    var id: String {
        switch self {
        case .requests: return "requests"
        case .activity: return "activity"
        }
    }
}

// MARK: - Friend Notification Item (live CloudKit data)

enum FriendNotificationItem: Identifiable {
    case incoming(request: CKRecord, sender: CKRecord)
    case outgoing(request: CKRecord, receiver: CKRecord)

    var id: String {
        switch self {
        case .incoming(let r, _):  return "in_\(r.recordID.recordName)"
        case .outgoing(let r, _):  return "out_\(r.recordID.recordName)"
        }
    }

    var date: Date {
        switch self {
        case .incoming(let r, _):  return r["createdDate"] as? Date ?? r.creationDate ?? .distantPast
        case .outgoing(let r, _):  return r["createdDate"] as? Date ?? r.creationDate ?? .distantPast
        }
    }
}

// MARK: - IdentifiableString Helper

struct IdentifiableString: Identifiable {
    let id = UUID()
    let value: String

    init(_ value: String) {
        self.value = value
    }
}
