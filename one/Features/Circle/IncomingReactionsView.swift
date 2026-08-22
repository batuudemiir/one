//
//  IncomingReactionsView.swift
//  one
//
//  Prototipin "yankılar · bugüne gelenler" ekranı: kendi paylaşımına gelen
//  efemer karşılıklar. Kim tepki verdi + her arkadaşla baloncuk thread'i +
//  geri yanıt. Gün sonunda kaybolur, sayaç yok.
//
//  Kaydedildi ekranından `EchoesEntryButton` ile açılır.
//

import SwiftUI

// MARK: - Entry button (kaydedildi ekranı)

/// Kendi paylaşımına gelen karşılıkları açan buton. Share record adını
/// lazy çözer (CommentEntryButton deseni), varsa gelen karşılık sayısını
/// sessizce gösterir — ama bu bir "yorum sayacı" değil, yalnız "var/yok".
struct EchoesEntryButton: View {
    let shareOwnerID: String
    let accentColorHex: String
    let resolveShareRecordName: (@escaping (String?) -> Void) -> Void

    @State private var resolvedName: String? = nil
    @State private var hasIncoming = false
    @State private var showSheet = false

    var body: some View {
        Button {
            ONEHaptics.feelingSelected()
            showSheet = true
        } label: {
            HStack(spacing: V3Tokens.spacingSM) {
                Image(systemName: "dot.radiowaves.left.and.right")
                    .font(.system(size: 14, weight: .medium))
                Text(NSLocalizedString("echoes.title", comment: ""))
                    .monoBase(tracking: 0.5)
                Spacer()
                if hasIncoming {
                    Circle().fill(Color(hex: accentColorHex)).frame(width: 7, height: 7)
                }
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
            }
            .foregroundColor(V3Tokens.mutedText)
            .padding(.horizontal, V3Tokens.spacingXL)
            .padding(.vertical, V3Tokens.spacingLG)
            .background(RoundedRectangle(cornerRadius: V3Tokens.radiusCard).fill(V3Tokens.wash))
        }
        .buttonStyle(.onePressable)
        .task {
            resolveShareRecordName { name in
                resolvedName = name
                guard let name else { return }
                CloudKitManager.shared.fetchDailyReactions(shareRecordName: name) { list in
                    hasIncoming = list.contains { $0.senderUserID != shareOwnerID }
                }
            }
        }
        .sheet(isPresented: $showSheet) {
            IncomingReactionsView(
                shareRecordName: resolvedName,
                myUserID: shareOwnerID,
                accentColorHex: accentColorHex
            )
            .v3Sheet(detents: [.large])
        }
    }
}

// MARK: - Yankılar ekranı

struct IncomingReactionsView: View {
    let shareRecordName: String?
    let myUserID: String
    let accentColorHex: String

    @Environment(\.dismiss) private var dismiss
    @State private var reactions: [DailyReaction] = []
    @State private var loading = true
    @State private var replyDrafts: [String: String] = [:]   // otherUserID -> draft
    @State private var isSending = false

    var body: some View {
        VStack(spacing: 0) {
            header

            if loading {
                Spacer()
                V3Loading(.region)
                Spacer()
            } else if reactors.isEmpty && threads.isEmpty {
                emptyState
            } else {
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 0) {
                        if !reactors.isEmpty { reactorsSection }
                        ForEach(threads, id: \.otherUserID) { thread in
                            threadSection(thread)
                        }

                        ephemNote
                    }
                    .padding(.horizontal, V3Tokens.spacingXL)
                    .padding(.bottom, V3Tokens.spacingXL3)
                }
            }
        }
        .background(V3Tokens.paper.ignoresSafeArea())
        .task { await load() }
    }

    // MARK: Header

    private var header: some View {
        HStack {
            Text(NSLocalizedString("echoes.screenTitle", comment: ""))
                .bodyLGSemibold()
                .foregroundColor(V3Tokens.ink)
            Spacer()
            V3TopBarIconButton(
                systemName: "xmark",
                label: NSLocalizedString("general.close", comment: "")
            ) { dismiss() }
        }
        .padding(.horizontal, V3Tokens.spacingXL)
        .padding(.top, V3Tokens.spacingLG)
        .padding(.bottom, V3Tokens.spacingMD)
    }

    /// Boş durum — paylaşılan `SubScreenState`. Eskiden burada 34pt ikon +
    /// 11pt aralık vardı; Şarkı seçicide 24pt + 10, Yankı'da 28pt + 18.
    /// Dört ekran, dört ölçü.
    private var emptyState: some View {
        SubScreenState(
            systemImage: "dot.radiowaves.left.and.right",
            message: NSLocalizedString("echoes.empty", comment: "")
        )
    }

    // MARK: Karşılık verenler

    private var reactorsSection: some View {
        VStack(alignment: .leading, spacing: V3Tokens.spacingSM) {
            Text(NSLocalizedString("echoes.reactors", comment: ""))
                .monoLabel(tracking: 1.3)
                .foregroundColor(V3Tokens.faintText)

            ForEach(reactors, id: \.id) { r in
                HStack(spacing: 11) {
                    V3PersonAvatar(
                        name: r.senderName ?? "?",
                        colorHex: r.senderColorHex,
                        size: .small
                    )
                    Text(r.senderName ?? NSLocalizedString("echoes.someone", comment: ""))
                        .bodyXSSemibold()
                        .foregroundColor(V3Tokens.ink)
                    Spacer()
                    // Renk karşılığıysa nokta, tepkiyse glif.
                    if r.kind == .color {
                        Circle().fill(Color(hex: r.colorHex ?? accentColorHex)).frame(width: 16, height: 16)
                    } else {
                        Text(r.kind.glyph).bodyLG()
                            .foregroundColor(V3Tokens.mutedText)
                    }
                }
                .padding(.vertical, 6)
            }
        }
        .padding(.top, V3Tokens.spacingLG)
    }

    // MARK: Thread (baloncuklar)

    private func threadSection(_ thread: Thread) -> some View {
        VStack(alignment: .leading, spacing: V3Tokens.spacingSM) {
            Text(String(format: NSLocalizedString("echoes.threadWith", comment: ""), thread.otherName))
                .monoLabel(tracking: 1.3)
                .foregroundColor(V3Tokens.faintText)

            VStack(alignment: .leading, spacing: 6) {
                ForEach(thread.bubbles, id: \.id) { b in
                    bubble(text: b.text ?? "", isMe: b.senderUserID == myUserID)
                }
            }

            replyBar(otherUserID: thread.otherUserID)
        }
        .padding(.top, V3Tokens.spacingXL)
    }

    private func bubble(text: String, isMe: Bool) -> some View {
        HStack {
            if isMe { Spacer(minLength: 40) }
            Text(text)
                .bodyXS()
                .foregroundColor(isMe ? ONEBrand.bone : V3Tokens.ink)
                .padding(.horizontal, 13)
                .padding(.vertical, 9)
                .background(
                    RoundedRectangle(cornerRadius: V3Tokens.radiusCard, style: .continuous)
                        .fill(isMe ? V3Tokens.ink : Color.white.opacity(0.85))
                        .overlay(
                            RoundedRectangle(cornerRadius: V3Tokens.radiusCard, style: .continuous)
                                .strokeBorder(V3Tokens.ink.opacity(isMe ? 0 : 0.09), lineWidth: 1)
                        )
                )
            if !isMe { Spacer(minLength: 40) }
        }
    }

    private func replyBar(otherUserID: String) -> some View {
        let draft = replyDrafts[otherUserID] ?? ""
        return HStack(spacing: 9) {
            TextField(
                NSLocalizedString("echoes.replyPlaceholder", comment: ""),
                text: Binding(
                    get: { replyDrafts[otherUserID] ?? "" },
                    set: { replyDrafts[otherUserID] = String($0.prefix(DailyReaction.maxReplyLength)) }
                )
            )
            .textFieldStyle(.plain)
            .font(.system(size: 14))
            .foregroundColor(V3Tokens.ink)
            .submitLabel(.send)
            .onSubmit { sendReply(to: otherUserID) }

            Button { sendReply(to: otherUserID) } label: {
                Image(systemName: "arrow.up")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(ONEBrand.bone)
                    .frame(width: 34, height: 34)
                    .background(Circle().fill(V3Tokens.ink))
            }
            .buttonStyle(.onePressable)
            .disabled(draft.trimmingCharacters(in: .whitespaces).isEmpty || isSending)
            .opacity(draft.trimmingCharacters(in: .whitespaces).isEmpty ? 0.3 : 1)
        }
        .padding(.leading, 15)
        .padding(.trailing, V3Tokens.spacingSM)
        .padding(.vertical, V3Tokens.spacingSM)
        .background(
            Capsule(style: .continuous)
                .fill(Color.white.opacity(0.82))
                .overlay(Capsule().strokeBorder(V3Tokens.ink.opacity(0.09), lineWidth: 1))
        )
        .padding(.top, V3Tokens.spacingXS)
    }

    private var ephemNote: some View {
        HStack(spacing: 7) {
            Circle().fill(V3Tokens.faintText).frame(width: 5, height: 5)
                .accessibilityHidden(true)
            Text(NSLocalizedString("echoes.ephemeralNote", comment: ""))
                .bodyMicro()
                .foregroundColor(V3Tokens.faintText)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, V3Tokens.spacingXL2)
    }

    // MARK: - Türetilmiş

    /// Tepki verenler (yanıt değil), gönderen başına en sonuncusu, ben hariç.
    private var reactors: [DailyReaction] {
        var seen = Set<String>()
        var out: [DailyReaction] = []
        for r in reactions.reversed() where r.kind != .reply && r.senderUserID != myUserID {
            if seen.insert(r.senderUserID).inserted { out.append(r) }
        }
        return out.reversed()
    }

    struct ThreadBubble { let id: String; let text: String?; let senderUserID: String }
    struct Thread { let otherUserID: String; let otherName: String; let bubbles: [ThreadBubble] }

    /// Yanıtları karşı tarafa göre grupla. Bir yanıtın "karşı taraf"ı:
    /// gönderen bensem hedef (toUserID), değilsem gönderen.
    private var threads: [Thread] {
        var byOther: [String: [DailyReaction]] = [:]
        var names: [String: String] = [:]
        for r in reactions where r.kind == .reply {
            let other = (r.senderUserID == myUserID) ? (r.toUserID ?? "") : r.senderUserID
            guard !other.isEmpty else { continue }
            byOther[other, default: []].append(r)
            if r.senderUserID != myUserID, let n = r.senderName { names[other] = n }
        }
        return byOther.map { (other, list) in
            let sorted = list.sorted { $0.createdAt < $1.createdAt }
            return Thread(
                otherUserID: other,
                otherName: names[other] ?? NSLocalizedString("echoes.someone", comment: ""),
                bubbles: sorted.map { ThreadBubble(id: $0.id, text: $0.text, senderUserID: $0.senderUserID) }
            )
        }
        .sorted { ($0.bubbles.last?.id ?? "") > ($1.bubbles.last?.id ?? "") }
    }

    // MARK: - Yükleme / gönderme

    private func load() async {
        guard let shareRecordName else { loading = false; return }
        CloudKitManager.shared.fetchDailyReactions(shareRecordName: shareRecordName) { list in
            reactions = list
            loading = false
        }
    }

    private func sendReply(to otherUserID: String) {
        guard let shareRecordName else { return }
        let draft = (replyDrafts[otherUserID] ?? "").trimmingCharacters(in: .whitespaces)
        guard !draft.isEmpty, !isSending else { return }
        isSending = true
        ONEHaptics.songSaved()
        CloudKitManager.shared.sendDailyReaction(
            shareRecordName: shareRecordName,
            shareOwnerID: myUserID,
            kind: .reply,
            text: draft,
            toUserID: otherUserID
        ) { result in
            isSending = false
            if case .success = result {
                replyDrafts[otherUserID] = ""
                Task { await load() }
            }
        }
    }
}
