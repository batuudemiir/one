//
//  ReactionComposer.swift
//  one
//
//  Prototipin "karşılık ver" bölümü — bir arkadaşın bugününe efemer tepki
//  + tek satır yanıt. Birden fazla arkadaş-detay ekranı kullandığı için
//  paylaşılan bileşen (FriendShareDetailView, FriendDetailView).
//

import SwiftUI
import CloudKit

struct ReactionComposer: View {
    let shareRecordName: String
    let shareOwnerID: String
    /// Yer tutucu ve efemerlik notunda geçen ad ("yalnızca X görür").
    let friendDisplayName: String

    @StateObject private var cloudKitManager = CloudKitManager.shared
    @State private var sentReaction: DailyReaction.Kind? = nil
    @State private var replyText = ""
    @State private var replySent = false
    @State private var isSending = false

    private var myColorHex: String {
        cloudKitManager.currentUser?["avatarColor"] as? String ?? "#5B8DEF"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(NSLocalizedString("reaction.respond", comment: ""))
                .monoLabel(tracking: 1.3)
                .foregroundColor(V3Tokens.faintText)
                .padding(.bottom, V3Tokens.spacingSM)

            // .rx-strip
            HStack(spacing: 7) {
                ForEach([DailyReaction.Kind.yanindayim, .bende, .iyiki], id: \.rawValue) { kind in
                    chip(kind)
                }
                Button { send(kind: .color, colorHex: myColorHex) } label: {
                    Text(DailyReaction.Kind.color.glyph)
                        .bodyMDMedium()
                        .foregroundColor(.white)
                        .frame(width: 38, height: 38)
                        .background(Circle().fill(Color(hex: myColorHex)))
                        .overlay(Circle().strokeBorder(Color.white.opacity(0.4), lineWidth: 2))
                        // Görsel 38 kalır, dokunma alanı Apple minimumu 44pt.
                        .frame(minWidth: 44, minHeight: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.onePressable)
                .disabled(isSending)
                .accessibilityLabel(Text("\(DailyReaction.Kind.color.label) tepkisi"))
                .accessibilityHint(Text(NSLocalizedString("general.a11y.toggle", comment: "")))
                .accessibilityAddTraits(sentReaction == .color ? .isSelected : [])
            }

            // .reply
            HStack(spacing: 9) {
                TextField(
                    String(format: NSLocalizedString("reaction.replyPlaceholder", comment: ""), friendDisplayName),
                    text: $replyText
                )
                .textFieldStyle(.plain)
                .bodySM()
                .foregroundColor(V3Tokens.ink)
                .submitLabel(.send)
                .onSubmit { sendReply() }
                .onChange(of: replyText) { _, v in
                    if v.count > DailyReaction.maxReplyLength {
                        replyText = String(v.prefix(DailyReaction.maxReplyLength))
                    }
                }

                Button(action: sendReply) {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(ONEBrand.bone)
                        .frame(width: 34, height: 34)
                        .background(Circle().fill(V3Tokens.ink))
                        // Görsel 34 kalır, dokunma alanı Apple minimumu 44pt.
                        .frame(minWidth: 44, minHeight: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.onePressable)
                .disabled(replyText.trimmingCharacters(in: .whitespaces).isEmpty || isSending)
                .opacity(replyText.trimmingCharacters(in: .whitespaces).isEmpty ? 0.3 : 1)
                .accessibilityLabel("Yanıtı gönder")
            }
            .padding(.leading, 15)
            .padding(.trailing, V3Tokens.spacingSM)
            .padding(.vertical, V3Tokens.spacingSM)
            .background(
                Capsule(style: .continuous)
                    .fill(Color.white.opacity(0.82))
                    .overlay(Capsule().strokeBorder(V3Tokens.ink.opacity(0.09), lineWidth: 1))
            )
            .padding(.top, V3Tokens.spacingMD)

            if replySent {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark").font(.system(size: 11, weight: .semibold))
                    Text(NSLocalizedString("reaction.sent", comment: "")).bodyMicro()
                }
                .foregroundColor(V3Tokens.mutedText)
                .frame(maxWidth: .infinity)
                .padding(.top, V3Tokens.spacingMD)
                .transition(.opacity)
            }

            HStack(spacing: 7) {
                Circle().fill(V3Tokens.faintText).frame(width: 5, height: 5)
                Text(String(format: NSLocalizedString("reaction.ephemeralNote", comment: ""), friendDisplayName))
                    .bodyMicro()
                    .foregroundColor(V3Tokens.faintText)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, V3Tokens.spacingLG)
        }
    }

    private func chip(_ kind: DailyReaction.Kind) -> some View {
        let selected = sentReaction == kind
        return Button { send(kind: kind) } label: {
            HStack(spacing: 7) {
                Text(kind.glyph).bodySM()
                Text(kind.label).bodyXSSemibold()
            }
            .foregroundColor(selected ? ONEBrand.bone : V3Tokens.ink)
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(
                Capsule(style: .continuous)
                    .fill(selected ? V3Tokens.ink : Color.white.opacity(0.72))
                    .overlay(Capsule().strokeBorder(V3Tokens.ink.opacity(selected ? 0 : 0.09), lineWidth: 1))
            )
        }
        .buttonStyle(.onePressable)
        .disabled(isSending)
        .accessibilityLabel(Text("\(kind.label) tepkisi"))
        .accessibilityHint(Text(NSLocalizedString("general.a11y.toggle", comment: "")))
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private func send(kind: DailyReaction.Kind, colorHex: String? = nil) {
        isSending = true
        ONEHaptics.feelingSelected()
        withAnimation(ONEAnimation.micro) { sentReaction = kind }
        cloudKitManager.sendDailyReaction(
            shareRecordName: shareRecordName,
            shareOwnerID: shareOwnerID,
            kind: kind,
            colorHex: colorHex
        ) { result in
            isSending = false
            if case .failure = result { withAnimation { sentReaction = nil } }
        }
    }

    private func sendReply() {
        let trimmed = replyText.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, !isSending else { return }
        isSending = true
        ONEHaptics.songSaved()
        cloudKitManager.sendDailyReaction(
            shareRecordName: shareRecordName,
            shareOwnerID: shareOwnerID,
            kind: .reply,
            text: trimmed
        ) { result in
            isSending = false
            if case .success = result {
                replyText = ""
                withAnimation { replySent = true }
            }
        }
    }
}
