//
//  FriendRequestsView.swift
//  one
//
//  Çevre Bildirimleri — tek birleşik aktivite akışı
//  Arkadaşlık istekleri + tüm çevre aktiviteleri tek listede
//

import SwiftUI
import CloudKit

// MARK: - Feed Grouping

private enum FeedSection: String {
    case today    = "Bugün"
    case thisWeek = "Bu Hafta"
    case earlier  = "Daha Önce"
}

// MARK: - FriendRequestsView

struct FriendRequestsView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var cloudKitManager = CloudKitManager.shared
    @StateObject private var notificationStore = CircleNotificationStore.shared

    @State private var items: [FriendNotificationItem] = []
    @State private var isLoading = false
    @State private var processingIDs: Set<String> = []

    @State private var selectedCommentShareName: IdentifiableString? = nil
    @State private var fetchedFriendShare: IdentifiableCKRecord? = nil
    @State private var isFetchingShare = false

    // MARK: - Computed

    private var unifiedFeed: [UnifiedFeedItem] {
        let requestItems = items.map { UnifiedFeedItem.request($0) }
        let activityItems = notificationStore.activityNotifications.map { UnifiedFeedItem.activity($0) }
        return (requestItems + activityItems).sorted { $0.date > $1.date }
    }

    private var groupedFeed: [(section: FeedSection, items: [UnifiedFeedItem])] {
        let cal = Calendar.current
        let now = Date()
        let todayStart  = cal.startOfDay(for: now)
        let weekStart   = cal.date(byAdding: .day, value: -7, to: now) ?? now

        var today: [UnifiedFeedItem] = []
        var week: [UnifiedFeedItem] = []
        var earlier: [UnifiedFeedItem] = []

        for item in unifiedFeed {
            if item.date >= todayStart        { today.append(item) }
            else if item.date >= weekStart    { week.append(item) }
            else                              { earlier.append(item) }
        }

        var result: [(section: FeedSection, items: [UnifiedFeedItem])] = []
        if !today.isEmpty   { result.append((.today, today)) }
        if !week.isEmpty    { result.append((.thisWeek, week)) }
        if !earlier.isEmpty { result.append((.earlier, earlier)) }
        return result
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack {
                ONETokens.oneCream.ignoresSafeArea()

                if isLoading && items.isEmpty && notificationStore.notifications.isEmpty {
                    skeletonList
                } else if groupedFeed.isEmpty {
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

    // MARK: - Unified List (sectioned)

    private var unifiedList: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: 0, pinnedViews: []) {
                ForEach(groupedFeed, id: \.section.rawValue) { group in
                    sectionHeader(group.section)

                    ForEach(Array(group.items.enumerated()), id: \.element.id) { index, feedItem in
                        Group {
                            switch feedItem {
                            case .request(let item):
                                switch item {
                                case .incoming(let req, let sender):
                                    incomingCard(req: req, sender: sender)
                                case .outgoing(let req, let receiver):
                                    outgoingCard(req: req, receiver: receiver)
                                }
                            case .activity(let notif):
                                activityCard(notif)
                            }
                        }
                        .transition(.opacity.combined(with: .move(edge: .top)))
                        .animation(
                            .spring(response: 0.35, dampingFraction: 0.8)
                                .delay(Double(index) * 0.04),
                            value: unifiedFeed.count
                        )

                        if index < group.items.count - 1 {
                            Divider()
                                .padding(.leading, 76)
                                .padding(.trailing, 20)
                        }
                    }
                }
            }
            .padding(.bottom, 40)
        }
        .refreshable { load() }
    }

    // MARK: - Section Header

    private func sectionHeader(_ section: FeedSection) -> some View {
        HStack(spacing: 10) {
            Text(section.rawValue.uppercased())
                .monoSM(tracking: 1.5)
                .foregroundColor(ONETokens.oneMist)
            Rectangle()
                .fill(ONETokens.oneSilver)
                .frame(height: 1)
        }
        .padding(.horizontal, 20)
        .padding(.top, 24)
        .padding(.bottom, 6)
    }

    // MARK: - Activity Card

    @ViewBuilder
    private func activityCard(_ notif: CircleNotification) -> some View {
        HStack(alignment: .top, spacing: 0) {
            // Unread accent bar
            Group {
                if !notif.isRead {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(accentColor(for: notif))
                        .frame(width: 3)
                        .padding(.vertical, 18)
                        .padding(.leading, 8)
                } else {
                    Color.clear.frame(width: 11)
                }
            }

            HStack(alignment: .top, spacing: 14) {
                // Icon
                ZStack {
                    Circle()
                        .fill(activityIconBackground(notif))
                        .frame(width: 44, height: 44)
                    if let emoji = notif.emoji {
                        Text(emoji)
                            .font(.system(size: 20))
                    } else {
                        Image(systemName: activityIcon(notif))
                            .bodyMD().fontWeight(.medium)
                            .foregroundColor(activityIconColor(notif))
                    }
                }
                .padding(.top, 2)

                // Content
                VStack(alignment: .leading, spacing: 5) {
                    Text(notif.title)
                        .bodySM()
                        .fontWeight(notif.isRead ? .medium : .semibold)
                        .foregroundColor(ONETokens.oneInk)
                        .lineLimit(2)

                    // Type-specific body
                    if notif.type == .comment && !notif.body.isEmpty {
                        commentExcerptView(notif.body, moodHex: notif.moodColorHex)
                    } else if !notif.body.isEmpty {
                        Text(notif.body)
                            .bodyXS()
                            .foregroundColor(ONETokens.oneMist)
                            .lineLimit(2)
                    }

                    Text(relativeTime(notif.date))
                        .monoBase()
                        .foregroundColor(ONETokens.oneMist.opacity(0.65))
                        .padding(.top, 1)
                }

                Spacer(minLength: 8)

                // Unread dot
                if !notif.isRead {
                    Circle()
                        .fill(accentColor(for: notif))
                        .frame(width: 8, height: 8)
                        .padding(.top, 8)
                }
            }
            .padding(.vertical, 15)
            .padding(.trailing, 20)
            .padding(.leading, 12)
        }
        .background(notif.isRead ? Color.clear : ONETokens.oneCreamLow.opacity(0.45))
        .contentShape(Rectangle())
        .onTapGesture { handleActivityTap(notif) }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(notif.title + (notif.body.isEmpty ? "" : ", " + notif.body))
        .accessibilityHint(notif.isRead ? "" : NSLocalizedString("accessibility.unread", comment: ""))
    }

    // MARK: - Comment Excerpt View

    @ViewBuilder
    private func commentExcerptView(_ text: String, moodHex: String?) -> some View {
        HStack(spacing: 0) {
            RoundedRectangle(cornerRadius: 2)
                .fill(
                    moodHex.flatMap { h in h.isValidHexColor ? Color(hex: h) : nil }
                    ?? ONETokens.oneMist.opacity(0.5)
                )
                .frame(width: 3)

            Text(text)
                .bodyXS()
                .foregroundColor(ONETokens.oneInk.opacity(0.65))
                .lineLimit(2)
                .padding(.horizontal, 9)
                .padding(.vertical, 6)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(ONETokens.oneCreamLow.opacity(0.7))
        }
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
    }

    // MARK: - Activity Icon Helpers

    private func activityIcon(_ notif: CircleNotification) -> String {
        switch notif.type {
        case .friendAccepted:  return "person.fill.checkmark"
        case .friendShare:     return "music.note"
        case .emojiReaction:   return "heart.fill"
        case .friendRequest:   return "person.badge.plus"
        case .comment:         return "bubble.left.fill"
        case .moodResonance:   return "wave.3.forward"
        case .resonance:       return "wave.3.right"
        case .outgoingRequest: return "paperplane"
        }
    }

    private func activityIconColor(_ notif: CircleNotification) -> Color {
        switch notif.type {
        case .friendAccepted:  return Color(hex: "#4CAF82")
        case .friendShare:     return Color(hex: "#5B8DEF")
        case .emojiReaction:   return Color(hex: "#FF8C42")
        case .friendRequest:   return ONETokens.oneInk
        case .comment:         return Color(hex: "#9B7FD4")
        case .moodResonance, .resonance:
            if let hex = notif.moodColorHex, hex.isValidHexColor { return Color(hex: hex) }
            return ONETokens.oneMist
        case .outgoingRequest: return ONETokens.oneAsh
        }
    }

    private func activityIconBackground(_ notif: CircleNotification) -> Color {
        if let hex = notif.moodColorHex, hex.isValidHexColor {
            return Color(hex: hex).opacity(0.14)
        }
        return activityIconColor(notif).opacity(0.12)
    }

    private func accentColor(for notif: CircleNotification) -> Color {
        if let hex = notif.moodColorHex, hex.isValidHexColor { return Color(hex: hex) }
        return activityIconColor(notif)
    }

    private func handleActivityTap(_ notif: CircleNotification) {
        notificationStore.update(id: notif.id) { n in n.isRead = true }

        switch notif.type {
        case .comment, .resonance:
            if let shareName = notif.shareRecordName {
                selectedCommentShareName = IdentifiableString(shareName)
            }
        case .friendShare:
            if let shareName = notif.shareRecordName, !isFetchingShare {
                isFetchingShare = true
                let recordID = CKRecord.ID(recordName: shareName)
                CloudKitManager.shared.publicDatabase.fetch(withRecordID: recordID) { record, _ in
                    DispatchQueue.main.async {
                        self.isFetchingShare = false
                        guard let record else { return }
                        let displayName = notif.relatedUserID.flatMap { _ in
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

    // MARK: - Incoming Request Card

    private func incomingCard(req: CKRecord, sender: CKRecord) -> some View {
        let name       = sender["displayName"] as? String ?? NSLocalizedString("friendRequests.unknown", comment: "")
        let color      = sender["avatarColor"] as? String ?? "#888888"
        let initial    = String(name.prefix(1)).uppercased()
        let recName    = req.recordID.recordName
        let processing = processingIDs.contains(recName)

        return HStack(alignment: .top, spacing: 14) {
            avatarCircle(initial: initial, colorHex: color, size: 50)
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
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(name)
                        .bodyMD().fontWeight(.semibold)
                        .foregroundColor(ONETokens.oneInk)
                    Text(String(format: NSLocalizedString("friendRequests.sentYouRequest", comment: ""), name))
                        .bodyXS()
                        .foregroundColor(ONETokens.oneMist)
                }

                if processing {
                    ProgressView()
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 8)
                } else {
                    VStack(spacing: 8) {
                        Button(action: { accept(recName: recName) }) {
                            Text(NSLocalizedString("friendRequests.accept", comment: "Kabul Et"))
                                .bodySM().fontWeight(.semibold)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 44)
                                .background(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .fill(ONETokens.oneInk)
                                )
                        }
                        .accessibilityLabel(NSLocalizedString("friendRequests.accept", comment: "") + " " + name)

                        Button(action: { decline(recName: recName) }) {
                            Text(NSLocalizedString("friendRequests.decline", comment: "Reddet"))
                                .bodySM().fontWeight(.medium)
                                .foregroundColor(ONETokens.oneInk.opacity(0.7))
                                .frame(maxWidth: .infinity)
                                .frame(height: 40)
                                .background(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .stroke(ONETokens.oneSilver, lineWidth: 1)
                                )
                        }
                        .accessibilityLabel(NSLocalizedString("friendRequests.decline", comment: "") + " " + name)
                    }
                }
            }
        }
        .padding(.vertical, 18)
        .padding(.horizontal, 20)
        .background(ONETokens.oneCreamLow.opacity(0.4))
    }

    // MARK: - Outgoing Request Card

    private func outgoingCard(req: CKRecord, receiver: CKRecord) -> some View {
        let name       = receiver["displayName"] as? String ?? NSLocalizedString("friendRequests.unknown", comment: "")
        let color      = receiver["avatarColor"] as? String ?? "#888888"
        let initial    = String(name.prefix(1)).uppercased()
        let recName    = req.recordID.recordName
        let processing = processingIDs.contains(recName)

        return HStack(spacing: 14) {
            avatarCircle(initial: initial, colorHex: color, size: 50)
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
                    .bodyMD().fontWeight(.semibold)
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
                        .bodyXS().fontWeight(.medium)
                        .foregroundColor(ONETokens.oneAsh)
                        .padding(.horizontal, 14)
                        .frame(height: 36)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(ONETokens.oneSilver, lineWidth: 1)
                        )
                }
            }
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 20)
    }

    // MARK: - Skeleton

    private static let skeletonWidths: [CGFloat] = [120, 150, 130, 140, 110]

    private var skeletonList: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: 0) {
                ForEach(0..<5, id: \.self) { i in
                    skeletonCard(index: i)
                        .animation(
                            .easeInOut(duration: 0.8).delay(Double(i) * 0.1).repeatForever(autoreverses: true),
                            value: isLoading
                        )
                    if i < 4 { Divider().padding(.leading, 76).padding(.trailing, 20) }
                }
            }
            .padding(.top, 16)
        }
    }

    private func skeletonCard(index: Int) -> some View {
        HStack(spacing: 14) {
            Circle()
                .fill(ONETokens.oneCreamMid)
                .frame(width: 44, height: 44)
            VStack(alignment: .leading, spacing: 8) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(ONETokens.oneCreamMid)
                    .frame(width: Self.skeletonWidths[index % 5], height: 12)
                RoundedRectangle(cornerRadius: 3)
                    .fill(ONETokens.oneSilver)
                    .frame(width: 80, height: 9)
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

            VStack(spacing: 28) {
                // Mood dots + icon composition
                ZStack {
                    // Background mood dots
                    HStack(spacing: 0) {
                        Circle()
                            .fill(Color(hex: "#FFB5A7").opacity(0.5))
                            .frame(width: 48, height: 48)
                            .offset(x: 12, y: 10)
                        Spacer()
                        Circle()
                            .fill(Color(hex: "#A8D5B5").opacity(0.5))
                            .frame(width: 36, height: 36)
                            .offset(x: -12, y: -8)
                    }
                    .frame(width: 120)

                    // Center bell
                    ZStack {
                        Circle()
                            .fill(ONETokens.oneCreamLow)
                            .frame(width: 72, height: 72)
                        Image(systemName: "bell")
                            .font(.system(size: 28, weight: .light))
                            .foregroundColor(ONETokens.oneAsh)
                    }

                    // Small accent dot
                    Circle()
                        .fill(Color(hex: "#B8C5F0").opacity(0.7))
                        .frame(width: 20, height: 20)
                        .offset(x: 42, y: -24)
                }
                .frame(height: 100)

                VStack(spacing: 8) {
                    Text(NSLocalizedString("friendRequests.noNotifications", comment: ""))
                        .bodyLG().fontWeight(.semibold)
                        .foregroundColor(ONETokens.oneInk)

                    Text(NSLocalizedString("friendRequests.noNotificationsHint", comment: ""))
                        .bodySM()
                        .multilineTextAlignment(.center)
                        .foregroundColor(ONETokens.oneAsh)
                        .lineSpacing(4)
                        .padding(.horizontal, 32)
                }
            }
            .padding(.horizontal, 40)
            .transition(.opacity.combined(with: .scale(scale: 0.95)))

            Spacer()
        }
    }

    // MARK: - Avatar Helper

    @ViewBuilder
    private func avatarCircle(initial: String, colorHex: String, size: CGFloat) -> some View {
        Circle()
            .fill(Color(hex: colorHex))
            .frame(width: size, height: size)
            .overlay(
                Text(initial)
                    .font(.system(size: size * 0.38, weight: .bold))
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

// MARK: - UnifiedFeedItem

private enum UnifiedFeedItem: Identifiable {
    case request(FriendNotificationItem)
    case activity(CircleNotification)

    var id: String {
        switch self {
        case .request(let item): return "req_\(item.id)"
        case .activity(let notif): return "act_\(notif.id)"
        }
    }

    var date: Date {
        switch self {
        case .request(let item): return item.date
        case .activity(let notif): return notif.date
        }
    }
}

// MARK: - FriendNotificationItem

enum FriendNotificationItem: Identifiable {
    case incoming(request: CKRecord, sender: CKRecord)
    case outgoing(request: CKRecord, receiver: CKRecord)

    var id: String {
        switch self {
        case .incoming(let r, _): return "in_\(r.recordID.recordName)"
        case .outgoing(let r, _): return "out_\(r.recordID.recordName)"
        }
    }

    var date: Date {
        switch self {
        case .incoming(let r, _): return r["createdDate"] as? Date ?? r.creationDate ?? .distantPast
        case .outgoing(let r, _): return r["createdDate"] as? Date ?? r.creationDate ?? .distantPast
        }
    }
}

// MARK: - IdentifiableString

struct IdentifiableString: Identifiable {
    let id = UUID()
    let value: String
    init(_ value: String) { self.value = value }
}
