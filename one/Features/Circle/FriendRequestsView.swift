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

    @State private var items: [FriendNotificationItem] = []
    @State private var isLoading = false
    @State private var processingIDs: Set<String> = []

    // Segment
    @State private var selectedTab: Int = 0   // 0 = Gelen, 1 = Giden

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
                    // Segment picker
                    segmentPicker
                        .padding(.horizontal, 20)
                        .padding(.top, 8)
                        .padding(.bottom, 12)

                    if isLoading && items.isEmpty {
                        Spacer()
                        ProgressView().scaleEffect(1.2)
                        Spacer()
                    } else if displayed.isEmpty {
                        emptyState
                    } else {
                        list
                    }
                }
            }
            .navigationTitle("Bildirimler")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Kapat") { dismiss() }
                        .monoSM(tracking: 0)
                        .foregroundColor(ONETokens.oneInk)
                }
            }
            .onAppear { load() }
        }
    }

    // MARK: Segment picker

    private var segmentPicker: some View {
        HStack(spacing: 0) {
            segmentBtn("Gelen", badge: incoming.count, tag: 0)
            segmentBtn("Giden", badge: outgoing.count, tag: 1)
        }
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.6))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(ONETokens.oneSilver, lineWidth: 1))
        )
    }

    private func segmentBtn(_ label: String, badge: Int, tag: Int) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.18)) { selectedTab = tag }
        } label: {
            HStack(spacing: 5) {
                Text(label)
                    .monoSM(tracking: 0.8)
                    .foregroundColor(selectedTab == tag ? ONETokens.oneCream : ONETokens.oneAsh)
                if badge > 0 {
                    Text("\(badge)")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(selectedTab == tag ? ONETokens.oneCream : ONETokens.oneAsh)
                        .frame(width: 18, height: 18)
                        .background(Circle().fill(selectedTab == tag ? Color.white.opacity(0.3) : ONETokens.oneCreamMid))
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 11)
                    .fill(selectedTab == tag ? ONETokens.oneInk : Color.clear)
            )
        }
        .buttonStyle(.plain)
        .padding(3)
    }

    // MARK: Empty state

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: selectedTab == 0 ? "tray" : "paperplane")
                .font(.system(size: 38, weight: .ultraLight))
                .foregroundColor(ONETokens.oneAsh)
            Text(selectedTab == 0 ? "Gelen istek yok" : "Gönderilmiş istek yok")
                .displayMD()
                .foregroundColor(ONETokens.oneInk)
            Text(selectedTab == 0
                 ? "Birisi seni çevresine çağırdığında\nburada görünür."
                 : "Gönderdiğin çevre davetleri\nburada görünür.")
                .monoSM(tracking: 0)
                .multilineTextAlignment(.center)
                .foregroundColor(ONETokens.oneAsh)
            Spacer()
        }
    }

    // MARK: List

    private var list: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: 10) {
                ForEach(displayed) { item in
                    switch item {
                    case .incoming(let req, let sender):
                        incomingCard(req: req, sender: sender)
                    case .outgoing(let req, let receiver):
                        outgoingCard(req: req, receiver: receiver)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 4)
            .padding(.bottom, 40)
        }
    }

    // MARK: Incoming card

    private func incomingCard(req: CKRecord, sender: CKRecord) -> some View {
        let name      = sender["displayName"] as? String ?? "Bilinmeyen"
        let color     = sender["avatarColor"] as? String ?? "#888888"
        let initial   = String(name.prefix(1)).uppercased()
        let recName   = req.recordID.recordName
        let processing = processingIDs.contains(recName)

        return HStack(spacing: 14) {
            avatarCircle(initial: initial, colorHex: color, size: 44)

            VStack(alignment: .leading, spacing: 3) {
                Text(name)
                    .displaySM()
                    .foregroundColor(ONETokens.oneInk)
                Text("Çevresine eklemek istiyor  ·  \(relativeTime(req["createdDate"] as? Date))")
                    .monoSM(tracking: 0.3)
                    .foregroundColor(ONETokens.oneAsh)
            }

            Spacer()

            if processing {
                ProgressView().scaleEffect(0.8)
            } else {
                HStack(spacing: 8) {
                    iconBtn(systemName: "xmark", bg: ONETokens.oneCreamLow, fg: ONETokens.oneAsh) {
                        decline(recName: recName)
                    }
                    iconBtn(systemName: "checkmark", bg: ONETokens.oneInk, fg: ONETokens.oneCream) {
                        accept(recName: recName)
                    }
                }
            }
        }
        .padding(14)
        .background(cardBG())
    }

    // MARK: Outgoing card

    private func outgoingCard(req: CKRecord, receiver: CKRecord) -> some View {
        let name    = receiver["displayName"] as? String ?? "Bilinmeyen"
        let color   = receiver["avatarColor"] as? String ?? "#888888"
        let initial = String(name.prefix(1)).uppercased()
        let recName = req.recordID.recordName
        let processing = processingIDs.contains(recName)

        return HStack(spacing: 14) {
            avatarCircle(initial: initial, colorHex: color, size: 44)

            VStack(alignment: .leading, spacing: 3) {
                Text(name)
                    .displaySM()
                    .foregroundColor(ONETokens.oneInk)
                Text("İstek gönderildi  ·  \(relativeTime(req["createdDate"] as? Date))")
                    .monoSM(tracking: 0.3)
                    .foregroundColor(ONETokens.oneAsh)
            }

            Spacer()

            if processing {
                ProgressView().scaleEffect(0.8)
            } else {
                // Geri çek butonu
                Button {
                    cancelOutgoing(req: req, receiverID: receiver["userID"] as? String ?? "")
                } label: {
                    Text("Geri Çek")
                        .monoSM(tracking: 0.5)
                        .foregroundColor(ONETokens.oneAsh)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
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
    }

    private func cardBG() -> some View {
        RoundedRectangle(cornerRadius: 14)
            .fill(Color.white.opacity(0.55))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(ONETokens.oneCreamLow.opacity(0.7), lineWidth: 1)
            )
    }

    private func relativeTime(_ date: Date?) -> String {
        guard let d = date else { return "" }
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .short
        f.locale = Locale(identifier: "tr_TR")
        return f.localizedString(for: d, relativeTo: Date())
    }

    // MARK: Load

    private func load() {
        isLoading = true
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
                ErrorHandler.shared.showSuccess("Arkadaşlık kabul edildi!")
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
                ErrorHandler.shared.showSuccess("İstek geri çekildi")
            }
        }
    }
}
