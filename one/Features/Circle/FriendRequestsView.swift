//
//  FriendRequestsView.swift
//  one
//
//  Arkadaşlık Bildirimleri — gelen istekler + giden istekler birlikte
//

import SwiftUI
import CloudKit

// MARK: - Notification Item

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

// MARK: - FriendRequestsView (Bildirimler)

struct FriendRequestsView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var cloudKitManager = CloudKitManager.shared
    @StateObject private var notificationStore = CircleNotificationStore.shared

    @State private var items: [FriendNotificationItem] = []
    @State private var isLoading = false
    @State private var processingIDs: Set<String> = []

    // Segment
    @State private var selectedTab: Int = 0   // 0 = Gelen, 1 = Giden, 2 = Bildirimler

    private var incoming: [FriendNotificationItem] {
        items.filter { if case .incoming = $0 { return true }; return false }
    }
    private var outgoing: [FriendNotificationItem] {
        items.filter { if case .outgoing = $0 { return true }; return false }
    }
    private var displayed: [FriendNotificationItem] { selectedTab == 0 ? incoming : outgoing }

    var body: some View {
        NavigationView {
            ZStack {
                ONETokens.oneCream.ignoresSafeArea()

                VStack(spacing: 0) {
                    // Summary banner
                    summaryBanner
                        .padding(.horizontal, 20)
                        .padding(.top, 12)
                        .padding(.bottom, 8)

                    // Segment picker
                    segmentPicker
                        .padding(.horizontal, 20)
                        .padding(.bottom, 12)

                    if selectedTab == 2 {
                        if notificationStore.displayable.isEmpty {
                            notificationsEmptyState
                        } else {
                            notificationsList
                        }
                    } else if isLoading && items.isEmpty {
                        skeletonList
                    } else if displayed.isEmpty {
                        emptyState
                    } else {
                        list
                    }
                }
            }
            .navigationTitle(NSLocalizedString("friendRequests.title", comment: ""))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(NSLocalizedString("general.close", comment: "")) { dismiss() }
                        .monoSM(tracking: 0)
                        .foregroundColor(ONETokens.oneInk)
                }
            }
            .onAppear { load() }
            .onChange(of: selectedTab) { _, tab in
                if tab == 2 { notificationStore.markAllRead() }
            }
        }
    }

    // MARK: Summary banner

    private var summaryBanner: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(incoming.isEmpty ? ONETokens.oneSilver.opacity(0.7) : ONETokens.oneInk.opacity(0.08))
                    .frame(width: 36, height: 36)
                Image(systemName: incoming.isEmpty ? "checkmark" : "bell.badge")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(incoming.isEmpty ? ONETokens.oneMist : ONETokens.oneInk)
                    .symbolRenderingMode(incoming.isEmpty ? .monochrome : .hierarchical)
            }

            if incoming.isEmpty {
                Text(NSLocalizedString("friendRequests.allClear", comment: ""))
                    .monoSM(tracking: 0.5)
                    .foregroundColor(ONETokens.oneMist)
            } else {
                Text(String(format: NSLocalizedString("friendRequests.summaryPending", comment: ""), incoming.count))
                    .monoSM(tracking: 0.5)
                    .foregroundColor(ONETokens.oneInk)
            }

            Spacer()

            if isLoading {
                ProgressView().scaleEffect(0.75).tint(ONETokens.oneMist)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(incoming.isEmpty ? ONETokens.oneSilver.opacity(0.4) : ONETokens.oneCreamLow)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(incoming.isEmpty ? Color.clear : ONETokens.oneInk.opacity(0.08), lineWidth: 1)
                )
        )
        .animation(ONEAnimation.micro, value: incoming.count)
    }

    // MARK: Skeleton list

    private var skeletonList: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: 10) {
                ForEach(0..<3, id: \.self) { i in
                    skeletonCard
                        .animation(.easeInOut(duration: 0.6).delay(Double(i) * 0.1).repeatForever(autoreverses: true),
                                   value: isLoading)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 4)
        }
    }

    private var skeletonCard: some View {
        HStack(spacing: 14) {
            Circle()
                .fill(ONETokens.oneCreamMid)
                .frame(width: 46, height: 46)
            VStack(alignment: .leading, spacing: 7) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(ONETokens.oneCreamMid)
                    .frame(width: 120, height: 12)
                RoundedRectangle(cornerRadius: 4)
                    .fill(ONETokens.oneSilver)
                    .frame(width: 80, height: 9)
            }
            Spacer()
            RoundedRectangle(cornerRadius: 8)
                .fill(ONETokens.oneSilver)
                .frame(width: 64, height: 32)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(ONETokens.onePaper.opacity(0.5))
        )
        .shimmeringCircle()
    }

    // MARK: Segment picker

    private var segmentPicker: some View {
        HStack(spacing: 0) {
            segmentBtn(
                NSLocalizedString("friendRequests.incoming", comment: ""),
                icon: selectedTab == 0 ? "arrow.down.circle.fill" : "arrow.down.circle",
                badge: incoming.count,
                tag: 0
            )
            segmentBtn(
                NSLocalizedString("friendRequests.outgoing", comment: ""),
                icon: selectedTab == 1 ? "paperplane.fill" : "paperplane",
                badge: outgoing.count,
                tag: 1
            )
            segmentBtn(
                NSLocalizedString("friendRequests.notifications", comment: ""),
                icon: selectedTab == 2 ? "bell.fill" : "bell",
                badge: notificationStore.unreadCount,
                tag: 2
            )
        }
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(ONETokens.onePaper.opacity(0.6))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(ONETokens.oneSilver, lineWidth: 1))
        )
    }

    private func segmentBtn(_ label: String, icon: String, badge: Int, tag: Int) -> some View {
        let isSelected = selectedTab == tag
        return Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { selectedTab = tag }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(isSelected ? ONETokens.oneCream : ONETokens.oneAsh)
                Text(label)
                    .monoSM(tracking: 0.8)
                    .foregroundColor(isSelected ? ONETokens.oneCream : ONETokens.oneAsh)
                if badge > 0 {
                    ZStack {
                        Circle()
                            .fill(isSelected ? Color.white.opacity(0.25) : ONETokens.oneCreamMid)
                        Text("\(badge)")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(isSelected ? ONETokens.oneCream : ONETokens.oneAsh)
                    }
                    .frame(width: 18, height: 18)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 11)
                    .fill(isSelected ? ONETokens.oneInk : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(3)
    }

    // MARK: Empty state

    private var emptyState: some View {
        VStack(spacing: 0) {
            Spacer()
            VStack(spacing: 20) {
                ZStack {
                    Circle()
                        .fill(ONETokens.oneSilver.opacity(0.6))
                        .frame(width: 72, height: 72)
                    Image(systemName: selectedTab == 0 ? "arrow.down.circle" : "paperplane.circle")
                        .font(.system(size: 30, weight: .ultraLight))
                        .foregroundColor(ONETokens.oneAsh)
                }

                VStack(spacing: 8) {
                    Text(selectedTab == 0
                         ? NSLocalizedString("friendRequests.noIncoming", comment: "")
                         : NSLocalizedString("friendRequests.noOutgoing", comment: ""))
                        .displayMD()
                        .foregroundColor(ONETokens.oneInk)
                    Text(selectedTab == 0
                         ? NSLocalizedString("friendRequests.noIncomingHint", comment: "")
                         : NSLocalizedString("friendRequests.noOutgoingHint", comment: ""))
                        .monoSM(tracking: 0)
                        .multilineTextAlignment(.center)
                        .foregroundColor(ONETokens.oneAsh)
                        .lineSpacing(3)
                }
            }
            .padding(.horizontal, 40)
            .transition(.opacity.combined(with: .scale(scale: 0.95)))
            Spacer()
        }
    }

    private var notificationsEmptyState: some View {
        VStack(spacing: 0) {
            Spacer()
            VStack(spacing: 20) {
                ZStack {
                    Circle()
                        .fill(ONETokens.oneSilver.opacity(0.6))
                        .frame(width: 72, height: 72)
                    Image(systemName: "bell.slash")
                        .font(.system(size: 30, weight: .ultraLight))
                        .foregroundColor(ONETokens.oneAsh)
                }
                VStack(spacing: 8) {
                    Text(NSLocalizedString("friendRequests.noNotifications", comment: ""))
                        .displayMD()
                        .foregroundColor(ONETokens.oneInk)
                    Text(NSLocalizedString("friendRequests.noNotificationsHint", comment: ""))
                        .monoSM(tracking: 0)
                        .multilineTextAlignment(.center)
                        .foregroundColor(ONETokens.oneAsh)
                        .lineSpacing(3)
                }
            }
            .padding(.horizontal, 40)
            .transition(.opacity.combined(with: .scale(scale: 0.95)))
            Spacer()
        }
    }

    // MARK: Notifications list (stored CircleNotifications)

    private var notificationsList: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: 10) {
                ForEach(Array(notificationStore.displayable.enumerated()), id: \.element.id) { index, notif in
                    storedNotificationCard(notif)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                        .animation(
                            .spring(response: 0.35, dampingFraction: 0.8)
                            .delay(Double(index) * 0.05),
                            value: notificationStore.displayable.count
                        )
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 4)
            .padding(.bottom, 40)
        }
    }

    @ViewBuilder
    private func storedNotificationCard(_ notif: CircleNotification) -> some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(notifColor(notif).opacity(0.12))
                    .frame(width: 46, height: 46)
                if let emoji = notif.emoji {
                    Text(emoji)
                        .font(.system(size: 22))
                } else {
                    Image(systemName: notifIcon(notif))
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(notifColor(notif))
                }
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(notif.title)
                    .displaySM()
                    .foregroundColor(notif.isRead ? ONETokens.oneAsh : ONETokens.oneInk)
                Text(notif.body)
                    .monoSM(tracking: 0)
                    .foregroundColor(ONETokens.oneMist)
                    .lineLimit(1)
                Text(relativeTime(notif.date))
                    .monoLabel(tracking: 0.3)
                    .foregroundColor(ONETokens.oneMist)
            }

            Spacer()

            if !notif.isRead {
                Circle()
                    .fill(ONETokens.oneInk)
                    .frame(width: 6, height: 6)
            }
        }
        .padding(14)
        .background(cardBG())
    }

    private func notifIcon(_ notif: CircleNotification) -> String {
        switch notif.type {
        case .friendAccepted: return "person.fill.checkmark"
        case .friendShare:    return "music.note"
        case .emojiReaction:  return "heart.fill"
        case .friendRequest:  return "person.badge.plus"
        }
    }

    private func notifColor(_ notif: CircleNotification) -> Color {
        switch notif.type {
        case .friendAccepted: return .green
        case .friendShare:    return .blue
        case .emojiReaction:  return .orange
        case .friendRequest:  return ONETokens.oneInk
        }
    }

    // MARK: List

    private var list: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: 10) {
                ForEach(Array(displayed.enumerated()), id: \.element.id) { index, item in
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
                        value: displayed.count
                    )
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 4)
            .padding(.bottom, 40)
        }
        .refreshable { load() }
    }

    // MARK: Incoming card

    private func incomingCard(req: CKRecord, sender: CKRecord) -> some View {
        let name       = sender["displayName"] as? String ?? NSLocalizedString("friendRequests.unknown", comment: "")
        let color      = sender["avatarColor"] as? String ?? "#888888"
        let initial    = String(name.prefix(1)).uppercased()
        let recName    = req.recordID.recordName
        let processing = processingIDs.contains(recName)

        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 14) {
                avatarCircle(initial: initial, colorHex: color, size: 46)
                    .overlay(alignment: .bottomTrailing) {
                        ZStack {
                            Circle().fill(ONETokens.oneCream)
                            Image(systemName: "arrow.down.circle.fill")
                                .font(.system(size: 13))
                                .foregroundColor(ONETokens.oneInk)
                        }
                        .frame(width: 20, height: 20)
                        .offset(x: 3, y: 3)
                    }

                VStack(alignment: .leading, spacing: 3) {
                    Text(name)
                        .displaySM()
                        .foregroundColor(ONETokens.oneInk)
                    Text(relativeTime(req["createdDate"] as? Date))
                        .monoLabel(tracking: 0.3)
                        .foregroundColor(ONETokens.oneMist)
                }

                Spacer()

                if processing {
                    ProgressView().scaleEffect(0.85)
                        .frame(width: 80)
                }
            }

            if !processing {
                HStack(spacing: 8) {
                    // Reddet
                    Button(action: { decline(recName: recName) }) {
                        Text(NSLocalizedString("friendRequests.decline", comment: ""))
                            .monoSM(tracking: 0.5)
                            .foregroundColor(ONETokens.oneAsh)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(ONETokens.oneCreamLow)
                            )
                    }
                    .accessibilityLabel(String(format: NSLocalizedString("accessibility.circle.declineFriend", comment: ""), name))

                    // Kabul et
                    Button(action: { accept(recName: recName) }) {
                        HStack(spacing: 5) {
                            Image(systemName: "checkmark")
                                .font(.system(size: 11, weight: .semibold))
                            Text(NSLocalizedString("addFriend.joinCircle", comment: ""))
                                .monoSM(tracking: 0.5)
                        }
                        .foregroundColor(ONETokens.oneCream)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(ONETokens.oneInk)
                        )
                    }
                    .accessibilityLabel(String(format: NSLocalizedString("accessibility.circle.acceptFriend", comment: ""), name))
                }
            }
        }
        .padding(14)
        .background(incomingCardBG())
    }

    private func incomingCardBG() -> some View {
        RoundedRectangle(cornerRadius: 14)
            .fill(ONETokens.onePaper.opacity(0.6))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(ONETokens.oneInk.opacity(0.12), lineWidth: 1.5)
            )
    }

    // MARK: Outgoing card

    private func outgoingCard(req: CKRecord, receiver: CKRecord) -> some View {
        let name       = receiver["displayName"] as? String ?? NSLocalizedString("friendRequests.unknown", comment: "")
        let color      = receiver["avatarColor"] as? String ?? "#888888"
        let initial    = String(name.prefix(1)).uppercased()
        let recName    = req.recordID.recordName
        let processing = processingIDs.contains(recName)

        return HStack(spacing: 14) {
            avatarCircle(initial: initial, colorHex: color, size: 46)
                .overlay(alignment: .bottomTrailing) {
                    ZStack {
                        Circle().fill(ONETokens.oneCream)
                        Image(systemName: "paperplane.fill")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundColor(ONETokens.oneAsh)
                    }
                    .frame(width: 20, height: 20)
                    .offset(x: 3, y: 3)
                }

            VStack(alignment: .leading, spacing: 4) {
                Text(name)
                    .displaySM()
                    .foregroundColor(ONETokens.oneInk)
                Text(relativeTime(req["createdDate"] as? Date))
                    .monoLabel(tracking: 0.3)
                    .foregroundColor(ONETokens.oneMist)
                // Bekliyor durum pill
                PendingStatusPill()
            }

            Spacer()

            if processing {
                ProgressView().scaleEffect(0.8)
            } else {
                Button {
                    cancelOutgoing(req: req, receiverID: receiver["userID"] as? String ?? "")
                } label: {
                    Text(NSLocalizedString("addFriend.withdraw", comment: ""))
                        .monoSM(tracking: 0.5)
                        .foregroundColor(ONETokens.oneAsh)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(
                            Capsule()
                                .stroke(ONETokens.oneStone, lineWidth: 1)
                        )
                }
            }
        }
        .padding(14)
        .background(cardBG())
    }

    // MARK: Pending Status Pill (sub-view)

    private struct PendingStatusPill: View {
        @State private var dotOpacity: Double = 1.0

        var body: some View {
            HStack(spacing: 4) {
                Circle()
                    .fill(Color.orange.opacity(0.85))
                    .frame(width: 5, height: 5)
                    .opacity(dotOpacity)
                    .onAppear {
                        withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) {
                            dotOpacity = 0.25
                        }
                    }
                Text(NSLocalizedString("friendRequests.pendingStatus", comment: ""))
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .tracking(0.4)
                    .foregroundColor(Color.orange.opacity(0.85))
            }
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(
                Capsule()
                    .fill(Color.orange.opacity(0.08))
                    .overlay(Capsule().stroke(Color.orange.opacity(0.18), lineWidth: 1))
            )
        }
    }

    // MARK: Helpers

    @ViewBuilder
    private func avatarCircle(initial: String, colorHex: String, size: CGFloat) -> some View {
        Circle()
            .fill(Color(hex: colorHex))
            .frame(width: size, height: size)
            .overlay(
                Text(initial)
                    .font(.system(size: size * 0.36, weight: .regular, design: .serif))
                    .italic()
                    .foregroundColor(.white.opacity(0.9))
            )
    }

    private func iconBtn(systemName: String, bg: Color, fg: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(fg)
                .frame(width: 34, height: 34)
                .background(Circle().fill(bg))
        }
        .frame(minWidth: ONETokens.minTouchTarget, minHeight: ONETokens.minTouchTarget)
        .contentShape(Rectangle())
    }

    private func cardBG() -> some View {
        RoundedRectangle(cornerRadius: 14)
            .fill(ONETokens.onePaper.opacity(0.55))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(ONETokens.oneCreamLow.opacity(0.7), lineWidth: 1)
            )
    }

    private func relativeTime(_ date: Date?) -> String {
        guard let d = date else { return "" }
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .short
        f.locale = LanguageManager.shared.currentLocale
        return f.localizedString(for: d, relativeTo: Date())
    }

    // MARK: Load

    private func load() {
        isLoading = true
        Task {
            // currentUser nil ise yüklenene kadar bekle (ensureCurrentUser max 10sn dener)
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

        // Gelen istekler
        group.enter()
        cloudKitManager.fetchPendingRequests { result in
            if case .success(let pairs) = result {
                incomingItems = pairs.map { .incoming(request: $0.request, sender: $0.sender) }
            }
            group.leave()
        }

        // Giden istekler
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

    // MARK: Actions

    private func accept(recName: String) {
        processingIDs.insert(recName)
        cloudKitManager.acceptFriendRequest(recordID: recName) { result in
            processingIDs.remove(recName)
            switch result {
            case .success:
                withAnimation(ONEAnimation.micro) {
                    items.removeAll { $0.id == "in_\(recName)" }
                }
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
                ErrorHandler.shared.showSuccess(NSLocalizedString("friendRequests.requestWithdrawn", comment: ""))
            }
        }
    }
}
