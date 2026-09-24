//
//  FriendRequestsView.swift
//  one
//
//  Çevre Bildirimleri — tek birleşik aktivite akışı
//  Arkadaşlık istekleri + tüm çevre aktiviteleri tek listede
//

import SwiftUI
import CloudKit
import UIKit

// MARK: - Feed Grouping

private enum FeedSection: String {
    case today    = "today"
    case thisWeek = "thisWeek"
    case earlier  = "earlier"

    /// Başlık katalogdan; `rawValue` kimlik olarak kalıyor (gruplama anahtarı).
    var title: String {
        NSLocalizedString("circle.feed.\(rawValue)", comment: "")
    }
}

// MARK: - FriendRequestsView

struct FriendRequestsView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var cloudKitManager = CloudKitManager.shared
    @StateObject private var notificationStore = CircleNotificationStore.shared

    @State private var items: [FriendNotificationItem] = []
    @State private var isLoading = false
    @State private var processingIDs: Set<String> = []

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
        // Kabuk `V3TopBar`'a geçti. Sistem toolbar'ında kapat SAĞDA metin
        // düğmesiydi; uygulamanın geri kalanında SOLDA dairesel xmark.
        // "Tümünü okundu işaretle" sağ yuvaya geçti — orası eylem yuvası.
        ZStack {
            V3Tokens.paper.ignoresSafeArea()

            if isLoading && items.isEmpty && notificationStore.notifications.isEmpty {
                skeletonList
            } else if groupedFeed.isEmpty {
                emptyState
            } else {
                unifiedList
            }
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            V3TopBar(
                leading: .close { dismiss() },
                title: NSLocalizedString("friendRequests.title", comment: ""),
                progress: 1
            ) {
                if notificationStore.unreadCount > 0 {
                    V3SheetAction(
                        title: NSLocalizedString("friendRequests.markAllRead", comment: "")
                    ) {
                        withAnimation(ONEAnimation.micro) { notificationStore.markAllRead() }
                    }
                }
            }
        }
        .onAppear {
            load()
            notificationStore.markAllRead()
        }
        .sheet(item: $fetchedFriendShare) { item in
            FriendShareDetailView(share: item.record, friendDisplayName: item.friendDisplayName)
                .v3Sheet(detents: [.large])
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
                            ONEAnimation.cardSpring
                                .delay(Double(index) * 0.04),
                            value: unifiedFeed.count
                        )

                        if index < group.items.count - 1 {
                            Divider()
                                .padding(.leading, 76)
                                .padding(.trailing, V3Tokens.spacingXL)
                        }
                    }
                }
            }
            .padding(.bottom, V3Tokens.spacingXL4)
        }
        .refreshable { load() }
    }

    // MARK: - Section Header

    private func sectionHeader(_ section: FeedSection) -> some View {
        HStack(spacing: 10) {
            Text(section.title.localizedUppercase)
                .monoSM(tracking: 1.5)
                .foregroundColor(V3Tokens.mutedText)
            Rectangle()
                .fill(V3Tokens.hairline)
                .frame(height: 1)
        }
        .padding(.horizontal, V3Tokens.spacingXL)
        .padding(.top, V3Tokens.spacingXL2)
        .padding(.bottom, 6)
    }

    // MARK: - Activity Card

    @ViewBuilder
    private func activityCard(_ notif: CircleNotification) -> some View {
        HStack(alignment: .top, spacing: 0) {
            // Unread accent bar
            Group {
                if !notif.isRead {
                    RoundedRectangle(cornerRadius: V3Tokens.radiusMicro)
                        .fill(accentColor(for: notif))
                        .frame(width: 3)
                        .padding(.vertical, 18)
                        .padding(.leading, V3Tokens.spacingSM)
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
                            .font(V3Typography.sans(20))
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
                        .foregroundColor(V3Tokens.ink)
                        .lineLimit(2)

                    // Type-specific body
                    if notif.type == .comment && !notif.body.isEmpty {
                        commentExcerptView(notif.body, moodHex: notif.moodColorHex)
                    } else if !notif.body.isEmpty {
                        Text(notif.body)
                            .bodyXS()
                            .foregroundColor(V3Tokens.mutedText)
                            .lineLimit(2)
                    }

                    Text(relativeTime(notif.date))
                        .monoBase()
                        .foregroundColor(V3Tokens.mutedText.opacity(0.65))
                        .padding(.top, 1)
                }

                Spacer(minLength: 8)

                // Unread dot
                if !notif.isRead {
                    Circle()
                        .fill(accentColor(for: notif))
                        .frame(width: 8, height: 8)
                        .padding(.top, V3Tokens.spacingSM)
                }
            }
            .padding(.vertical, 15)
            .padding(.trailing, V3Tokens.spacingXL)
            .padding(.leading, V3Tokens.spacingMD)
        }
        .background(notif.isRead ? Color.clear : V3Tokens.wash.opacity(0.45))
        .contentShape(Rectangle())
        // `onTapGesture` yerine `Button`: satır dokunulabilir ama basıldığında
        // hiçbir şey olmuyordu. Basma anındaki geri bildirim, dokunuşun kayda
        // geçtiğini söyleyen tek işaret.
        .modifier(ActivityRowButton { handleActivityTap(notif) })
        .accessibilityElement(children: .combine)
        .accessibilityLabel(notif.title + (notif.body.isEmpty ? "" : ", " + notif.body))
        .accessibilityHint(notif.isRead ? "" : NSLocalizedString("accessibility.unread", comment: ""))
        // `accessibilityElement(children: .combine)` yeni bir öğe üretiyor;
        // `Button`'ın kendi özelliğinin o öğeye taşındığına güvenmek yerine
        // açıkça ekleniyor. Satır dokunulabilir olduğunu VoiceOver'a da
        // söylemeli.
        .accessibilityAddTraits(.isButton)
    }

    // MARK: - Comment Excerpt View

    @ViewBuilder
    private func commentExcerptView(_ text: String, moodHex: String?) -> some View {
        HStack(spacing: 0) {
            RoundedRectangle(cornerRadius: V3Tokens.radiusMicro)
                .fill(
                    moodHex.flatMap { h in h.isValidHexColor ? Color(hex: h) : nil }
                    ?? V3Tokens.mutedText.opacity(0.5)
                )
                .frame(width: 3)

            Text(text)
                .bodyXS()
                .foregroundColor(V3Tokens.ink.opacity(0.65))
                .lineLimit(2)
                .padding(.horizontal, 9)
                .padding(.vertical, 6)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(V3Tokens.wash.opacity(0.7))
        }
        .clipShape(RoundedRectangle(cornerRadius: V3Tokens.radiusSwatch, style: .continuous))
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
        case .friendAccepted:  return V3Tokens.success
        case .friendShare:     return V3Tokens.info
        // Bu fonksiyon zaten mood paletinden besleniyor (`.moodResonance`
        // aşağıda `notif.moodColorHex` okuyor); vurgular da oradan gelsin.
        case .emojiReaction:   return V3Mood.coskulu.color
        case .friendRequest:   return V3Tokens.ink
        case .comment:         return V3Mood.gergin.color
        case .moodResonance, .resonance:
            if let hex = notif.moodColorHex, hex.isValidHexColor { return Color(hex: hex) }
            return V3Tokens.mutedText
        case .outgoingRequest: return V3Tokens.mutedText
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
            // Yorum thread'i kaldırıldı (efemer karşılık sistemine geçildi).
            // Bildirim yalnız okundu işaretlenir.
            break
        case .friendShare:
            if let shareName = notif.shareRecordName, !isFetchingShare {
                isFetchingShare = true
                let recordID = CKRecord.ID(recordName: shareName)
                CloudKitManager.shared.publicDatabase.fetch(withRecordID: recordID) { record, _ in
                    DispatchQueue.main.async {
                        self.isFetchingShare = false
                        guard let record else { return }
                        // v4: başlık artık kişinin adının kendisi ("Deniz"),
                        // gövde olay. Eskiden başlık "Deniz paylaşım yaptı 🎵"
                        // olduğu için adı ayrıştırmak gerekiyordu.
                        let displayName = notif.title
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
        let recName    = req.recordID.recordName
        let processing = processingIDs.contains(recName)

        return HStack(alignment: .top, spacing: 14) {
            avatarCircle(name: name, colorHex: color, size: .large)
                .overlay(alignment: .bottomTrailing) {
                    ZStack {
                        Circle().fill(V3Tokens.surface)
                        Image(systemName: "arrow.down.circle.fill")
                            .bodyLG()
                            .foregroundColor(V3Tokens.ink)
                    }
                    .frame(width: 22, height: 22)
                    .offset(x: 2, y: 2)
                }
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: V3Tokens.spacingMD) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(name)
                        .bodyMD().fontWeight(.semibold)
                        .foregroundColor(V3Tokens.ink)
                    Text(String(format: NSLocalizedString("friendRequests.sentYouRequest", comment: ""), name))
                        .bodyXS()
                        .foregroundColor(V3Tokens.mutedText)
                }

                if processing {
                    ProgressView()
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, V3Tokens.spacingSM)
                } else {
                    VStack(spacing: V3Tokens.spacingSM) {
                        Button(action: { accept(recName: recName) }) {
                            Text(NSLocalizedString("friendRequests.accept", comment: "Kabul Et"))
                                .bodySM().fontWeight(.semibold)
                                // `.white` değil `paper`. Zemin `V3Tokens.ink`
                                // ve o adaptif: koyu temada #F2F1EE'ye dönüyor.
                                // Yani "Kabul Et" düğmesi koyu temada beyaz
                                // üstüne beyaz yazıyordu — okunmuyordu.
                                // `paper` zeminle birlikte ters çevriliyor;
                                // `V3PrimaryButton` da bu çifti kullanıyor.
                                .foregroundColor(V3Tokens.paper)
                                .frame(maxWidth: .infinity)
                                .frame(height: V3Tokens.minTouchTarget)
                                .background(
                                    RoundedRectangle(cornerRadius: V3Tokens.radiusInner, style: .continuous)
                                        .fill(V3Tokens.ink)
                                )
                        }
                        .buttonStyle(.onePressable)
                        .accessibilityLabel(NSLocalizedString("friendRequests.accept", comment: "") + " " + name)

                        Button(action: { decline(recName: recName) }) {
                            Text(NSLocalizedString("friendRequests.decline", comment: "Reddet"))
                                .bodySM().fontWeight(.medium)
                                .foregroundColor(V3Tokens.ink.opacity(0.7))
                                .frame(maxWidth: .infinity)
                                .frame(height: 40)
                                .background(
                                    RoundedRectangle(cornerRadius: V3Tokens.radiusInner, style: .continuous)
                                        .stroke(V3Tokens.hairline, lineWidth: 1)
                                )
                        }
                        .buttonStyle(.onePressable)
                        .accessibilityLabel(NSLocalizedString("friendRequests.decline", comment: "") + " " + name)
                    }
                }
            }
        }
        .padding(.vertical, 18)
        .padding(.horizontal, V3Tokens.spacingXL)
        .background(V3Tokens.wash.opacity(0.4))
    }

    // MARK: - Outgoing Request Card

    private func outgoingCard(req: CKRecord, receiver: CKRecord) -> some View {
        let name       = receiver["displayName"] as? String ?? NSLocalizedString("friendRequests.unknown", comment: "")
        let color      = receiver["avatarColor"] as? String ?? "#888888"
        let recName    = req.recordID.recordName
        let processing = processingIDs.contains(recName)

        return HStack(spacing: 14) {
            avatarCircle(name: name, colorHex: color, size: .large)
                .overlay(alignment: .bottomTrailing) {
                    ZStack {
                        Circle().fill(V3Tokens.surface)
                        Image(systemName: "paperplane.fill")
                            .monoBase().fontWeight(.medium)
                            .foregroundColor(V3Tokens.mutedText)
                    }
                    .frame(width: 22, height: 22)
                    .offset(x: 2, y: 2)
                }

            VStack(alignment: .leading, spacing: V3Tokens.spacingXS) {
                Text(name)
                    .bodyMD().fontWeight(.semibold)
                    .foregroundColor(V3Tokens.ink)
                Text(NSLocalizedString("friendRequests.pending", comment: "Bekliyor"))
                    .bodyXS()
                    .foregroundColor(V3Tokens.mutedText)
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
                        .foregroundColor(V3Tokens.mutedText)
                        .padding(.horizontal, 14)
                        .frame(height: 36)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(V3Tokens.hairline, lineWidth: 1)
                        )
                }
                .buttonStyle(.onePressable)
            }
        }
        .padding(.vertical, V3Tokens.spacingLG)
        .padding(.horizontal, V3Tokens.spacingXL)
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
                    if i < 4 { Divider().padding(.leading, 76).padding(.trailing, V3Tokens.spacingXL) }
                }
            }
            .padding(.top, V3Tokens.spacingLG)
        }
    }

    private func skeletonCard(index: Int) -> some View {
        HStack(spacing: 14) {
            Circle()
                .fill(V3Tokens.surface)
                .frame(width: 44, height: 44)
            VStack(alignment: .leading, spacing: V3Tokens.spacingSM) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(V3Tokens.surface)
                    .frame(width: Self.skeletonWidths[index % 5], height: 12)
                RoundedRectangle(cornerRadius: 3)
                    .fill(V3Tokens.hairline)
                    .frame(width: 80, height: 9)
            }
            Spacer()
        }
        .padding(.vertical, 14)
        .padding(.horizontal, V3Tokens.spacingXL)
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
                            .fill(V3Mood.atesli.pastelColor)
                            .frame(width: 48, height: 48)
                            .offset(x: 12, y: 10)
                        Spacer()
                        Circle()
                            .fill(V3Mood.huzurlu.pastelColor)
                            .frame(width: 36, height: 36)
                            .offset(x: -12, y: -8)
                    }
                    .frame(width: 120)

                    // Center bell
                    ZStack {
                        Circle()
                            .fill(V3Tokens.wash)
                            .frame(width: 72, height: 72)
                        Image(systemName: "bell")
                            .font(.system(size: 28, weight: .light))
                            .foregroundColor(V3Tokens.mutedText)
                    }

                    // Small accent dot
                    Circle()
                        .fill(V3Mood.huzunlu.pastelColor)
                        .frame(width: 20, height: 20)
                        .offset(x: 42, y: -24)
                }
                .frame(height: 100)

                VStack(spacing: V3Tokens.spacingSM) {
                    Text(NSLocalizedString("friendRequests.noNotifications", comment: ""))
                        .bodyLG().fontWeight(.semibold)
                        .foregroundColor(V3Tokens.ink)

                    Text(NSLocalizedString("friendRequests.noNotificationsHint", comment: ""))
                        .bodySM()
                        .multilineTextAlignment(.center)
                        .foregroundColor(V3Tokens.mutedText)
                        .lineSpacing(4)
                        .padding(.horizontal, V3Tokens.spacingXL3)
                }
            }
            .padding(.horizontal, V3Tokens.spacingXL4)
            .transition(.opacity.combined(with: .scale(scale: 0.95)))

            Spacer()
        }
    }

    // MARK: - Avatar Helper

    @ViewBuilder
    /// Yerel sarmalayıcı — gövdeyi `V3PersonAvatar` çiziyor. Çağrı yerleri
    /// baş harfi kendisi hesaplıyordu; bileşen adı alıp kendisi türetiyor.
    private func avatarCircle(name: String, colorHex: String, size: V3PersonAvatar.Size) -> some View {
        V3PersonAvatar(name: name, colorHex: colorHex, size: size)
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
            withAnimation(ONEAnimation.cardSpring) { self.items = combined }
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

// MARK: - IdentifiableCKRecord

/// `CKRecord`'u `.sheet(item:)` ile kullanılabilir kılan sarmalayıcı.
///
/// Eskiden `CircleView.swift`'in tepesinde duruyordu. O ekran (v2 bubble-cloud
/// Çevre) `V3CircleView` ile değiştirilip kabuktan çıkarıldı; dosya silinirken
/// bu tip tek canlı tüketicisi olan buraya taşındı.
struct IdentifiableCKRecord: Identifiable {
    let id: String
    let record: CKRecord
    let friendDisplayName: String
    let friendProfilePhoto: UIImage?

    init(_ record: CKRecord, displayName: String = "", profilePhoto: UIImage? = nil) {
        self.id = record.recordID.recordName
        self.record = record
        self.friendDisplayName = displayName
        self.friendProfilePhoto = profilePhoto
    }
}

// MARK: - Etkinlik satırı basma geri bildirimi

/// Satırı `Button`'a sarar. Ayrı bir `ViewModifier` olmasının nedeni,
/// çağrı yerindeki erişilebilirlik zincirinin (`accessibilityElement` →
/// `Label` → `Hint`) sarmalayıcının *dışında* kalması gerekmesi: içeride
/// kalsaydı `children: .combine` butonun kendi birleştirmesiyle çakışırdı.
private struct ActivityRowButton: ViewModifier {
    let action: () -> Void

    func body(content: Content) -> some View {
        Button(action: action) { content }
            .buttonStyle(.onePressable)
    }
}
