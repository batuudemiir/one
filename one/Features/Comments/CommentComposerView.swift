//
//  CommentComposerView.swift
//  one
//
//  v2.5 — Yorum yazma alanı.
//

import SwiftUI
import CloudKit
import Combine
import CoreData

struct CommentComposerView: View {
    let editingComment: Comment?
    let placeholder: String
    let onSubmit: (String, @escaping (Bool) -> Void) -> Void
    let onCancelEdit: (() -> Void)?

    @Environment(\.managedObjectContext) private var context
    @State private var text: String = ""
    @State private var attachedSong: AttachedSong? = nil   // Müzik eklendiğinde input'ta ham metin yerine kart
    @State private var isSubmitting = false
    @State private var rateLimitMessage: String?
    @State private var showSongSearch = false
    @State private var profileImage: UIImage? = nil
    @State private var now = Date()
    @FocusState private var focused: Bool
    @ObservedObject private var cloudKitManager = CloudKitManager.shared

    /// Composer içinde tutulan ek şarkı modeli — submit anında [SONG] payload'una dönüştürülür.
    struct AttachedSong: Equatable {
        let name: String
        let artist: String
    }

    init(
        editingComment: Comment? = nil,
        placeholder: String = "Yorum yaz…",
        onSubmit: @escaping (String, @escaping (Bool) -> Void) -> Void,
        onCancelEdit: (() -> Void)? = nil
    ) {
        self.editingComment = editingComment
        self.placeholder = placeholder
        self.onSubmit = onSubmit
        self.onCancelEdit = onCancelEdit
        // Düzenleme modunda body [SONG] prefix'ı taşıyabilir — parse edip
        // attachedSong olarak ayır; aksi halde plain text.
        if let body = editingComment?.body, body.hasPrefix("[SONG] ") {
            let parts = body.replacingOccurrences(of: "[SONG] ", with: "").components(separatedBy: "|")
            _attachedSong = State(initialValue: AttachedSong(
                name: parts.first ?? "",
                artist: parts.count > 1 ? parts[1] : ""
            ))
            _text = State(initialValue: "")
        } else {
            _text = State(initialValue: editingComment?.body ?? "")
        }
    }

    private var remaining: Int { Comment.maxBodyLength - text.count }
    private var showCounter: Bool { remaining < 40 }
    private var isOverLimit: Bool { remaining < 0 }

    private var canSubmit: Bool {
        let hasText = !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let hasSong = attachedSong != nil
        return (hasText || hasSong) && !isOverLimit && !isSubmitting
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let editingComment {
                editingBanner(for: editingComment)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }

            // Eklenen şarkı kartı — input'un üstünde, ham metin yerine
            if let song = attachedSong {
                attachedSongCard(song)
                    .padding(.bottom, 8)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }

            HStack(alignment: .bottom, spacing: 10) {
                avatarView

                TextField(placeholder, text: $text, axis: .vertical)
                    .lineLimit(1...6)
                    .focused($focused)
                    .font(.body)
                    .submitLabel(.send)
                    .accessibilityLabel("Yorum alanı")

                // İki ayrı buton — paralel HStack ile, aynı pozisyonda üst üste binmesin
                HStack(spacing: 8) {
                    Button(action: { showSongSearch = true }) {
                        Image(systemName: attachedSong == nil ? "music.note" : "music.note.list")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(attachedSong == nil ? Color.accentColor : .white)
                            .frame(width: 32, height: 32)
                            .background(
                                Circle()
                                    .fill(attachedSong == nil
                                          ? Color.accentColor.opacity(0.12)
                                          : Color.accentColor)
                            )
                    }
                    .accessibilityLabel(attachedSong == nil ? "Şarkı Ekle" : "Şarkıyı Değiştir")

                    submitButton
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Color(.systemBackground).opacity(0.6))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .strokeBorder(
                        focused ? Color.accentColor.opacity(0.4) : Color(.separator).opacity(0.6),
                        lineWidth: focused ? 1.5 : 1
                    )
                    .animation(.easeInOut(duration: 0.2), value: focused)
            )
            .onChange(of: editingComment?.id) { _, newID in
                if newID == nil {
                    text = ""
                    attachedSong = nil
                } else if let body = editingComment?.body {
                    if body.hasPrefix("[SONG] ") {
                        let parts = body.replacingOccurrences(of: "[SONG] ", with: "").components(separatedBy: "|")
                        attachedSong = AttachedSong(
                            name: parts.first ?? "",
                            artist: parts.count > 1 ? parts[1] : ""
                        )
                        text = ""
                    } else {
                        attachedSong = nil
                        text = body
                    }
                }
            }
            .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { date in
                if editingComment != nil { now = date }
            }

            if showCounter || rateLimitMessage != nil {
                HStack(spacing: 6) {
                    if let msg = rateLimitMessage {
                        Label(msg, systemImage: "clock")
                            .font(.caption2)
                            .foregroundStyle(.orange)
                    }
                    Spacer()
                    if showCounter {
                        Text("\(remaining)")
                            .font(.caption2.monospacedDigit())
                            .foregroundStyle(isOverLimit ? .red : .secondary)
                            .transition(.opacity.combined(with: .scale(scale: 0.8)))
                    }
                }
                .padding(.horizontal, 4)
                .padding(.top, 4)
                .animation(.easeOut(duration: 0.15), value: showCounter)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .liquidGlassSheetBackground()
        .animation(.easeInOut(duration: 0.22), value: attachedSong)
        .sheet(isPresented: $showSongSearch) {
            CommentSongSearchView { song in
                // Ham metin yerine attached chip — submit anında payload'a çevrilir
                attachedSong = AttachedSong(name: song.name, artist: song.artist)
            }
            .environment(\.managedObjectContext, context)
        }
        .onAppear {
            loadProfilePhoto()
        }
        .onReceive(NotificationCenter.default.publisher(for: .profilePhotoDidChange)) { _ in
            loadProfilePhoto()
        }
    }

    private func loadProfilePhoto() {
        if let img = ProfileViewModel.loadProfilePhotoFromDisk() {
            profileImage = img
            return
        }
        guard let user = cloudKitManager.currentUser,
              let asset = user["profilePhoto"] as? CKAsset,
              let url = asset.fileURL else { return }
        Task {
            let data = try? await Task.detached(priority: .userInitiated) {
                try Data(contentsOf: url)
            }.value
            guard let data, let image = UIImage(data: data) else { return }
            profileImage = image
        }
    }

    // MARK: - Attached song card

    /// Composer'a eklenen şarkıyı gösterir — `[SONG]` ham metni yerine.
    private func attachedSongCard(_ song: AttachedSong) -> some View {
        HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 8)
                .fill(ONETokens.oneCreamMid)
                .frame(width: 36, height: 36)
                .overlay(Text("🎵").font(.system(size: 16)))

            VStack(alignment: .leading, spacing: 2) {
                Text(song.name)
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(ONETokens.oneInk)
                    .lineLimit(1)
                Text(song.artist)
                    .font(.caption)
                    .foregroundColor(ONETokens.oneAsh)
                    .lineLimit(1)
            }

            Spacer()

            Button {
                attachedSong = nil
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 18))
                    .foregroundColor(ONETokens.oneAsh)
            }
            .accessibilityLabel("Şarkıyı kaldır")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(ONETokens.oneCreamLow)
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(ONETokens.oneCreamMid, lineWidth: 1)
                )
        )
    }

    // MARK: - Subviews

    @ViewBuilder
    private var avatarView: some View {
        if let user = cloudKitManager.currentUser {
            Group {
                if let img = profileImage {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFill()
                } else {
                    let color = user["avatarColor"] as? String ?? "#888888"
                    let initial = String((user["displayName"] as? String ?? "?").prefix(1)).uppercased()
                    
                    Circle()
                        .fill(Color(hex: color))
                        .overlay(
                            Text(initial)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(.white)
                        )
                }
            }
            .frame(width: 32, height: 32)
            .clipShape(Circle())
            .overlay(Circle().stroke(Color.black.opacity(0.1), lineWidth: 1))
        }
    }

    private var submitButton: some View {
        ZStack {
            if isSubmitting {
                ProgressView()
                    .frame(width: 32, height: 32)
            } else {
                Button(action: submit) {
                    Image(systemName: editingComment == nil ? "arrow.up" : "checkmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(canSubmit ? .white : Color.secondary)
                        .frame(width: 32, height: 32)
                        .background(
                            Circle()
                                .fill(canSubmit ? Color.accentColor : Color(.systemFill))
                        )
                }
                .disabled(!canSubmit)
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: canSubmit)
                .accessibilityLabel(editingComment == nil ? "Gönder" : "Güncelle")
                .sensoryFeedback(.impact(weight: .light), trigger: isSubmitting)
            }
        }
        .frame(width: 32, height: 32)
    }

    // MARK: - Edit banner

    private func editingBanner(for c: Comment) -> some View {
        HStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 2)
                .fill(Color.accentColor)
                .frame(width: 3, height: 28)

            VStack(alignment: .leading, spacing: 1) {
                Text("Düzenleniyor")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.accentColor)
                Text("Kalan süre: \(editWindowRemaining(for: c))")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                onCancelEdit?()
                text = ""
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.secondary)
                    .font(.title3)
            }
            .accessibilityLabel("Düzenlemeyi iptal et")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Color.accentColor.opacity(0.06), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .padding(.bottom, 6)
    }

    private func editWindowRemaining(for c: Comment) -> String {
        let deadline = c.createdAt.addingTimeInterval(Comment.editWindow)
        let r = max(0, deadline.timeIntervalSince(now))
        guard r > 0 else { return "süre doldu" }
        return "\(Int(r))sn"
    }

    // MARK: - Submit

    private func submit() {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        // Müzik eklendiyse [SONG] payload'ı kullanıcının yazdığı metin yerine geçer
        // (mevcut renderer `comment.body.hasPrefix("[SONG] ")` ile chip'e çevirir).
        let payload: String
        if let song = attachedSong {
            payload = "[SONG] \(song.name)|\(song.artist)"
        } else {
            payload = trimmed
        }
        guard !payload.isEmpty, !isOverLimit else { return }

        if editingComment == nil {
            let decision = CommentRateLimiter.shared.check()
            if case .deny(let reason, let retry) = decision {
                rateLimitMessage = "\(reason) (\(Int(retry))sn)"
                return
            }
            rateLimitMessage = nil
        }

        isSubmitting = true
        focused = false
        onSubmit(payload) { success in
            isSubmitting = false
            if success, editingComment == nil {
                text = ""
                attachedSong = nil
            }
        }
    }
}
