//
//  CommentRowView.swift
//  one
//
//  v2.5 — Instagram/BeReal tarzı kompakt yorum satırı.
//

import SwiftUI

struct CommentRowView: View {
    let comment: Comment
    let currentUserID: String?
    let shareOwnerID: String

    var onDelete: ((Comment) -> Void)? = nil
    var onEdit: ((Comment) -> Void)? = nil
    var onAvatarTap: ((String) -> Void)? = nil

    @State private var showReport = false
    @State private var showDeleteConfirm = false
    @State private var avatarImage: UIImage? = nil
    @State private var lastLoadedAvatarURL: URL? = nil
    /// Author profil snapshot'ı — UserProfileStore'dan reaktif okunur.
    /// Store'da varsa Comment.author* alanlarına göre öncelikli; yoksa fallback.
    @State private var authorProfile: PublicUserProfile? = nil

    // MARK: - Resolved author display fields
    // Tek kaynak: Profile cache > Comment denormalized fallback

    private var resolvedDisplayName: String {
        authorProfile?.displayName
            ?? comment.authorDisplayName
            ?? "Kullanıcı"
    }

    private var resolvedAvatarColorHex: String {
        authorProfile?.avatarColorHex
            ?? comment.authorAvatarColorHex
            ?? "#8888CC"
    }

    private var resolvedAvatarURL: URL? {
        // Fallback path — used only when UserProfileStore image cache misses.
        authorProfile?.profilePhotoFileURL
    }

    private var canDelete: Bool {
        guard let me = currentUserID else { return false }
        return comment.canDelete(by: me)
    }

    private var canEdit: Bool {
        guard let me = currentUserID else { return false }
        return comment.canEdit(by: me)
    }

    private var isMine: Bool {
        comment.authorUserID == currentUserID
    }

    private var isShareOwner: Bool {
        comment.authorUserID == shareOwnerID
    }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            avatarButton

            VStack(alignment: .leading, spacing: 3) {
                inlineText
                timeRow
            }

            Spacer(minLength: 0)

            menuButton
        }
        .padding(.vertical, 8)
        .padding(.leading, 16)
        .padding(.trailing, 4)
        .contentShape(Rectangle())
        .onAppear {
            authorProfile = UserProfileStore.shared.snapshot(for: comment.authorUserID)
            UserProfileStore.shared.prefetch([comment.authorUserID])
            if comment.authorUserID == currentUserID, let img = ProfileViewModel.loadProfilePhotoFromDisk() {
                avatarImage = img
            } else if let img = UserProfileStore.shared.profileImage(for: comment.authorUserID) {
                avatarImage = img
            } else {
                loadAvatarIfNeeded()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .userProfileDidChange)) { notif in
            guard let uid = notif.object as? String, uid == comment.authorUserID else { return }
            authorProfile = UserProfileStore.shared.snapshot(for: uid)
            if let img = UserProfileStore.shared.profileImage(for: uid) {
                avatarImage = img
            } else {
                lastLoadedAvatarURL = nil
                loadAvatarIfNeeded()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .profilePhotoDidChange)) { _ in
            guard comment.authorUserID == currentUserID else { return }
            if let img = ProfileViewModel.loadProfilePhotoFromDisk() {
                avatarImage = img
            }
        }
        .sheet(isPresented: $showReport) {
            ReportSheet(target: .comment(id: comment.id, authorName: resolvedDisplayName))
        }
        .confirmationDialog("Yorumu sil?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button("Sil", role: .destructive) { onDelete?(comment) }
            Button("Vazgeç", role: .cancel) {}
        }
    }

    // MARK: - Avatar

    private var avatarButton: some View {
        Button {
            onAvatarTap?(comment.authorUserID)
        } label: {
            ZStack(alignment: .bottomTrailing) {
                avatarCircle
                    .overlay(
                        Circle()
                            .strokeBorder(isShareOwner ? Color.accentColor.opacity(0.7) : Color.clear, lineWidth: 1.5)
                    )

                if isShareOwner {
                    Image(systemName: "star.fill")
                        .font(.system(size: 6, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(1.5)
                        .background(Color.accentColor, in: Circle())
                        .offset(x: 2, y: 2)
                }
            }
        }
        .buttonStyle(.plain)
        .frame(width: 36, height: 36)
        .accessibilityLabel("\(resolvedDisplayName) profili")
    }

    /// Avatar görünümü: foto > renkli initial fallback.
    @ViewBuilder
    private var avatarCircle: some View {
        if let img = avatarImage {
            Image(uiImage: img)
                .resizable()
                .scaledToFill()
                .frame(width: 28, height: 28)
                .clipShape(Circle())
        } else {
            Circle()
                .fill(Color(hex: resolvedAvatarColorHex))
                .frame(width: 28, height: 28)
                .overlay(
                    Text(String(resolvedDisplayName.prefix(1)).uppercased())
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.white)
                )
        }
    }

    /// Profil fotoğrafını background thread'de yükler ve cache'ler.
    private func loadAvatarIfNeeded() {
        // Fast path: store image cache'i kontrol et.
        if let img = UserProfileStore.shared.profileImage(for: comment.authorUserID) {
            avatarImage = img
            return
        }
        // Fallback: profilePhotoFileURL'den yükle (URL hâlâ geçerliyse).
        guard let url = resolvedAvatarURL else {
            avatarImage = nil
            lastLoadedAvatarURL = nil
            return
        }
        guard url != lastLoadedAvatarURL else { return }
        lastLoadedAvatarURL = url
        DispatchQueue.global(qos: .userInitiated).async {
            guard let data = try? Data(contentsOf: url),
                  let img = UIImage(data: data) else { return }
            DispatchQueue.main.async { avatarImage = img }
        }
    }

    // MARK: - Inline text: **username** comment body

    @ViewBuilder
    private var inlineText: some View {
        if comment.body.hasPrefix("[SONG] ") {
            let songInfo = comment.body.replacingOccurrences(of: "[SONG] ", with: "").components(separatedBy: "|")
            let songName = songInfo.first ?? ""
            let artistName = songInfo.count > 1 ? songInfo[1] : ""

            VStack(alignment: .leading, spacing: 4) {
                Text(resolvedDisplayName)
                    .font(ONETypography.bodySMMedium)
                    .foregroundStyle(.primary)

                HStack(spacing: 6) {
                    Image(systemName: "music.note")
                        .font(ONETypography.monoLabel)
                        .foregroundStyle(.secondary)

                    VStack(alignment: .leading, spacing: 1) {
                        if !songName.isEmpty {
                            Text(songName)
                                .font(ONETypography.bodyXSMedium)
                                .foregroundStyle(.primary)
                                .lineLimit(1)
                        }
                        if !artistName.isEmpty {
                            Text(artistName)
                                .font(ONETypography.monoSM)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(Color(.secondarySystemFill), in: RoundedRectangle(cornerRadius: 8))
            }
        } else {
            Group {
                Text(resolvedDisplayName)
                    .font(ONETypography.bodySMMedium)
                    .foregroundStyle(.primary)
                + Text("  ")
                + Text(comment.body)
                    .font(ONETypography.bodySM)
                    .foregroundStyle(.primary)
                + (comment.isEdited
                   ? Text("  düzenlendi")
                        .font(ONETypography.monoSM)
                        .foregroundStyle(.tertiary)
                        .italic()
                   : Text(""))
            }
            .fixedSize(horizontal: false, vertical: true)
            .textSelection(.enabled)
            .accessibilityLabel("\(resolvedDisplayName): \(comment.body)")
        }
    }

    // MARK: - Time row

    private var timeRow: some View {
        Text(relativeTime(comment.createdAt))
            .font(ONETypography.monoSM)
            .foregroundStyle(.tertiary)
    }

    // MARK: - Menu

    private var menuButton: some View {
        Menu {
            if canEdit, let onEdit {
                Button { onEdit(comment) } label: {
                    Label("Düzenle", systemImage: "pencil")
                }
            }
            if canDelete {
                Button(role: .destructive) {
                    showDeleteConfirm = true
                } label: {
                    Label("Sil", systemImage: "trash")
                }
            }
            if !isMine {
                Divider()
                Button(role: .destructive) {
                    showReport = true
                } label: {
                    Label("Rapor et", systemImage: "flag")
                }
            }
        } label: {
            Image(systemName: "ellipsis")
                .font(ONETypography.monoSM)
                .foregroundStyle(.tertiary)
                .frame(width: 36, height: 36)
                .contentShape(Rectangle())
        }
        .accessibilityLabel("Yorum seçenekleri")
    }

    // MARK: - Time

    private func relativeTime(_ date: Date) -> String {
        let secs = Int(Date().timeIntervalSince(date))
        if secs < 60  { return "şimdi" }
        if secs < 3600 { return "\(secs / 60) dk" }
        if secs < 86400 { return "\(secs / 3600) sa" }
        if secs < 604800 { return "\(secs / 86400) g" }
        let fmt = DateFormatter()
        fmt.dateFormat = "d MMM"
        fmt.locale = Locale(identifier: "tr_TR")
        return fmt.string(from: date)
    }
}
