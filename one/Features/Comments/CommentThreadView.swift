//
//  CommentThreadView.swift
//  one
//
//  v2.5 — Bir paylaşımın yorum thread'i.
//

import SwiftUI
import Combine
import CloudKit

// MARK: - Notification

extension Notification.Name {
    static let commentCountChanged = Notification.Name("commentCountChanged")
}

struct ShareSongInfo {
    let songName: String
    let artistName: String
    let albumArtURLString: String?
    let moodColorHex: String
}

@MainActor
final class CommentThreadViewModel: ObservableObject {
    @Published var comments: [Comment] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var editingComment: Comment?
    @Published var shareInfo: ShareSongInfo?

    let shareRecordName: String
    let shareOwnerID: String

    init(shareRecordName: String, shareOwnerID: String) {
        self.shareRecordName = shareRecordName
        self.shareOwnerID = shareOwnerID
    }

    func load() {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        fetchShareInfo()
        CloudKitManager.shared.fetchComments(shareRecordName: shareRecordName) { [weak self] result in
            Task { @MainActor in
                self?.isLoading = false
                switch result {
                case .success(let list):
                    let outgoing = CloudKitManager.shared.myOutgoingBlockedIDs
                    let incoming = CloudKitManager.shared.myIncomingBlockedIDs
                    let filtered = list.filter {
                        !outgoing.contains($0.authorUserID) && !incoming.contains($0.authorUserID)
                    }
                    withAnimation(.easeOut(duration: 0.22)) {
                        self?.comments = filtered
                    }
                case .failure:
                    self?.errorMessage = "Yorumlar yüklenemedi. Tekrar dene."
                }
            }
        }
    }

    func submit(body: String, onComplete: @escaping (Bool) -> Void) {
        if let editing = editingComment {
            CloudKitManager.shared.editComment(commentID: editing.id, newBody: body) { [weak self] result in
                Task { @MainActor in
                    switch result {
                    case .success(let updated):
                        if let idx = self?.comments.firstIndex(where: { $0.id == updated.id }) {
                            withAnimation(.easeOut(duration: 0.2)) {
                                self?.comments[idx] = updated
                            }
                        }
                        self?.editingComment = nil
                        onComplete(true)
                    case .failure:
                        self?.errorMessage = "Yorum gönderilemedi. Tekrar dene."
                        onComplete(false)
                    }
                }
            }
            return
        }

        CloudKitManager.shared.createComment(
            body: body,
            shareRecordName: shareRecordName,
            shareOwnerID: shareOwnerID
        ) { [weak self] result in
            Task { @MainActor in
                switch result {
                case .success(let created):
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        self?.comments.append(created)
                    }
                    CloudKitManager.shared.commentCountCache.removeValue(forKey: self?.shareRecordName ?? "")
                    CommentRateLimiter.shared.record()
                    AppAnalytics.shared.track(.commentCreated)
                    NotificationCenter.default.post(name: .commentCountChanged, object: self?.shareRecordName)
                    onComplete(true)
                case .failure:
                    self?.errorMessage = "Yorum gönderilemedi. Tekrar dene."
                    onComplete(false)
                }
            }
        }
    }

    func delete(_ c: Comment) {
        CloudKitManager.shared.deleteComment(commentID: c.id) { [weak self] result in
            Task { @MainActor in
                if case .success = result {
                    withAnimation(.easeOut(duration: 0.2)) {
                        self?.comments.removeAll { $0.id == c.id }
                    }
                    NotificationCenter.default.post(name: .commentCountChanged, object: self?.shareRecordName)
                } else if case .failure = result {
                    self?.errorMessage = "Yorum silinemedi. Tekrar dene."
                }
            }
        }
    }

    private func fetchShareInfo() {
        let recordID = CKRecord.ID(recordName: shareRecordName)
        CloudKitManager.shared.publicDatabase.fetch(withRecordID: recordID) { [weak self] record, _ in
            guard let self, let record else { return }
            let info = ShareSongInfo(
                songName:          record["songName"]    as? String ?? "",
                artistName:        record["artistName"]  as? String ?? "",
                albumArtURLString: record["albumArtURL"] as? String,
                moodColorHex:      record["moodColor"]   as? String ?? "#888888"
            )
            Task { @MainActor in
                self.shareInfo = info
            }
        }
    }
}

// MARK: - View

struct CommentThreadView: View {
    @StateObject private var vm: CommentThreadViewModel
    @State private var profileSheetUserID: String?

    let showComposer: Bool

    private var currentUserID: String? {
        CloudKitManager.shared.currentUser?["userID"] as? String
    }

    init(shareRecordName: String, shareOwnerID: String, showComposer: Bool = true) {
        _vm = StateObject(wrappedValue: CommentThreadViewModel(
            shareRecordName: shareRecordName,
            shareOwnerID: shareOwnerID
        ))
        self.showComposer = showComposer
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Sheet tutamacı + nefes alan başlık alanı (estetik)
            grabberAndHeader

            Divider().opacity(0.12)

            // Mini şarkı kartı
            if let info = vm.shareInfo {
                shareSongCard(info)
                Divider().opacity(0.08)
            }

            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 0) {
                        if vm.isLoading && vm.comments.isEmpty {
                            skeletonList
                        } else if let err = vm.errorMessage, vm.comments.isEmpty {
                            errorState(message: err)
                        } else if vm.comments.isEmpty {
                            emptyState
                        } else {
                            commentList
                        }
                    }
                    .padding(.bottom, 16)
                }
                .scrollDismissesKeyboard(.interactively)
                .onChange(of: vm.comments.count) { _, _ in
                    if let last = vm.comments.last {
                        withAnimation(.easeOut(duration: 0.3)) {
                            proxy.scrollTo(last.id, anchor: .bottom)
                        }
                    }
                }
            }

            if let err = vm.errorMessage, !vm.comments.isEmpty {
                errorBanner(message: err)
            }
        }
        .safeAreaInset(edge: .bottom) {
            if showComposer {
                VStack(spacing: 0) {
                    Divider().opacity(0.15)
                    CommentComposerView(
                        editingComment: vm.editingComment,
                        onSubmit: { body, done in vm.submit(body: body, onComplete: done) },
                        onCancelEdit: { vm.editingComment = nil }
                    )
                }
                .background(Color(.systemBackground).ignoresSafeArea(.all, edges: .bottom))
            }
        }
        .liquidGlassSheetBackground()
        .onAppear { vm.load() }
        .onReceive(NotificationCenter.default.publisher(for: .init("circleDataNeedsRefresh"))) { _ in
            vm.load()
        }
        .sheet(item: Binding(
            get: { profileSheetUserID.map { IdentifiableID(id: $0) } },
            set: { profileSheetUserID = $0?.id }
        )) { wrap in
            PublicProfileView(userID: wrap.id)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
    }

    // MARK: - Header

    /// Sheet için kendi tutamacımız + nefes alan üst başlık. Estetik:
    /// drag indicator + 18pt boşluk + ortalanmış başlık + sağda yenile.
    @ViewBuilder
    private func shareSongCard(_ info: ShareSongInfo) -> some View {
        HStack(spacing: 12) {
            // Album kapağı
            if let urlStr = info.albumArtURLString, let url = URL(string: urlStr), !urlStr.isEmpty {
                CachedAsyncImage(url: url) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(hex: info.moodColorHex).opacity(0.25))
                }
                .frame(width: 44, height: 44)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(hex: info.moodColorHex).opacity(0.25))
                    .frame(width: 44, height: 44)
                    .overlay(
                        Image(systemName: "music.note")
                            .font(.system(size: 16))
                            .foregroundColor(Color(hex: info.moodColorHex))
                    )
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(info.songName)
                    .font(ONETypography.bodySMMedium)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Text(info.artistName)
                    .font(ONETypography.bodyXS)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            Rectangle()
                .fill(Color(hex: info.moodColorHex))
                .frame(width: 3)
                .clipShape(Capsule())
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color(hex: info.moodColorHex).opacity(0.06))
    }

    private var grabberAndHeader: some View {
        VStack(spacing: 0) {
            // Tutamaç
            Capsule()
                .fill(Color(.tertiaryLabel).opacity(0.55))
                .frame(width: 36, height: 5)
                .padding(.top, 8)
                .padding(.bottom, 14)
                .frame(maxWidth: .infinity)

            ZStack {
                // Ortalanmış başlık
                VStack(spacing: 2) {
                    Text(vm.comments.isEmpty ? "Yorumlar" : "\(vm.comments.count) Yorum")
                        .font(ONETypography.displayXS)
                        .foregroundStyle(.primary)
                    if !vm.comments.isEmpty {
                        Text("Konuşmaya katıl")
                            .font(ONETypography.monoSM)
                            .foregroundStyle(.tertiary)
                    }
                }
                .frame(maxWidth: .infinity)
                .multilineTextAlignment(.center)

                // Sağda yenile / progress
                HStack {
                    Spacer()
                    if vm.isLoading && !vm.comments.isEmpty {
                        ProgressView()
                            .scaleEffect(0.7)
                    } else {
                        Button {
                            vm.load()
                        } label: {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(.secondary)
                                .frame(width: 32, height: 32)
                                .background(Circle().fill(Color(.systemFill).opacity(0.6)))
                        }
                        .accessibilityLabel("Yorumları yenile")
                    }
                }
                .padding(.trailing, 16)
            }
            .padding(.bottom, 14)
        }
        .animation(.easeOut(duration: 0.2), value: vm.comments.count)
    }

    /// (Eski) — Geriye uyum: aktif olarak kullanılmıyor.
    private var header: some View {
        HStack(spacing: 6) {
            Text(vm.comments.isEmpty ? "Yorumlar" : "\(vm.comments.count) yorum")
                .font(ONETypography.bodySMMedium)
                .foregroundStyle(.primary)

            Spacer()

            if vm.isLoading && !vm.comments.isEmpty {
                ProgressView()
                    .scaleEffect(0.65)
                    .transition(.opacity)
            } else {
                Button {
                    vm.load()
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(ONETypography.monoSM)
                        .foregroundStyle(.tertiary)
                }
                .accessibilityLabel("Yorumları yenile")
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .animation(.easeOut(duration: 0.2), value: vm.comments.count)
    }

    // MARK: - Comment list

    private var commentList: some View {
        LazyVStack(alignment: .leading, spacing: 0) {
            ForEach(vm.comments) { c in
                CommentRowView(
                    comment: c,
                    currentUserID: currentUserID,
                    shareOwnerID: vm.shareOwnerID,
                    onDelete: { vm.delete($0) },
                    onEdit: { vm.editingComment = $0 },
                    onAvatarTap: { uid in
                        guard !CloudKitManager.shared.isBlockedByThem(uid) else { return }
                        profileSheetUserID = uid
                    }
                )
                .transition(
                    .asymmetric(
                        insertion: .move(edge: .bottom).combined(with: .opacity),
                        removal: .opacity
                    )
                )

                if c.id != vm.comments.last?.id {
                    Divider()
                        .padding(.leading, 62)
                        .opacity(0.2)
                }
            }
        }
    }

    // MARK: - Skeleton

    private var skeletonList: some View {
        VStack(spacing: 0) {
            ForEach(0..<3, id: \.self) { _ in
                CommentSkeletonRow()
                Divider().padding(.leading, 62).opacity(0.2)
            }
        }
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 36, weight: .light))
                .foregroundStyle(.tertiary)

            VStack(spacing: 4) {
                Text("Henüz yorum yok")
                    .font(ONETypography.bodySMMedium)
                    .foregroundStyle(.secondary)
                Text("İlk sesin sen ol.")
                    .font(ONETypography.bodyXS)
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Henüz yorum yok. İlk sesin sen ol.")
    }

    // MARK: - Error states

    private func errorState(message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 32, weight: .light))
                .foregroundStyle(.orange.opacity(0.8))

            VStack(spacing: 4) {
                Text("Yorumlar yüklenemedi")
                    .font(ONETypography.bodySMMedium)
                    .foregroundStyle(.secondary)
                Text(message)
                    .font(ONETypography.bodyXS)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
            }

            Button {
                vm.errorMessage = nil
                vm.load()
            } label: {
                Text("Tekrar dene")
                    .font(ONETypography.monoBase)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 7)
                    .background(Color(.systemFill), in: Capsule())
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
        .padding(.horizontal, 24)
    }

    private func errorBanner(message: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.circle.fill")
                .foregroundStyle(.orange)
                .font(ONETypography.bodyXS)
            Text(message)
                .font(ONETypography.bodyXS)
                .foregroundStyle(.secondary)
            Spacer()
            Button {
                vm.errorMessage = nil
            } label: {
                Image(systemName: "xmark")
                    .font(ONETypography.monoSM)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color.orange.opacity(0.08))
        .transition(.move(edge: .top).combined(with: .opacity))
    }
}

// MARK: - Skeleton row

private struct CommentSkeletonRow: View {
    @State private var phase: CGFloat = 0

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Circle()
                .fill(shimmerGradient)
                .frame(width: 36, height: 36)
                .padding(.horizontal, 4)

            VStack(alignment: .leading, spacing: 6) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(shimmerGradient)
                    .frame(width: 90, height: 10)

                RoundedRectangle(cornerRadius: 4)
                    .fill(shimmerGradient)
                    .frame(maxWidth: .infinity)
                    .frame(height: 10)

                RoundedRectangle(cornerRadius: 4)
                    .fill(shimmerGradient)
                    .frame(width: 160, height: 10)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .onAppear {
            withAnimation(.linear(duration: 1.4).repeatForever(autoreverses: false)) {
                phase = 1
            }
        }
    }

    private var shimmerGradient: LinearGradient {
        LinearGradient(
            stops: [
                .init(color: Color(.systemFill), location: phase - 0.3),
                .init(color: Color(.tertiarySystemFill), location: phase),
                .init(color: Color(.systemFill), location: phase + 0.3),
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
    }
}

// MARK: - Helper

private struct IdentifiableID: Identifiable, Equatable {
    let id: String
}
