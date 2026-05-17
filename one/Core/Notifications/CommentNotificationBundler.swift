//
//  CommentNotificationBundler.swift
//  one
//
//  v2.5 — Aynı paylaşıma ard arda gelen yorumları 5 sn pencere içinde
//  bundle'layan debounce'lı scheduler. Üç durum:
//
//    1 yorum (tek)  → `commentReceived` (yazar adı + excerpt)
//    2+ yorum       → `commentBatch` (ilk yazar adı + "ve N kişi daha")
//
//  Amaç: kısa sürede 3 arkadaş yorum yazdıysa kullanıcıya 3 ayrı push yerine
//  tek batch push göndermek. Yorum yazarı paylaşım sahibi değilse bildirim
//  yazarına da "kendi yorumun" push'u gitmez (owner filter).
//
//  Thread-safety: `DispatchQueue(label: ...)` serial queue.
//

import Foundation
import CloudKit
import UserNotifications

final class CommentNotificationBundler {
    static let shared = CommentNotificationBundler()

    // MARK: State

    private struct PendingBundle {
        var shareRecordName: String
        var firstAuthorName: String?
        var firstAuthorID: String?
        var firstExcerpt: String?
        var moodColorHex: String?
        var commentIDs: [String] = []
        var createdAt: Date = Date()
        var workItem: DispatchWorkItem?
    }

    private let debounceInterval: TimeInterval = 5
    private var pending: [String: PendingBundle] = [:]   // keyed by shareRecordName
    private let queue = DispatchQueue(label: "com.batudemir.ones.CommentNotificationBundler")

    private init() {}

    // MARK: Public

    /// Yeni yorum push'u gelince çağır. `shareOwnerID` push alıcısı olmalı
    /// (yani bu cihazın kullanıcısı). `authorUserID` yorum yazarı — eğer
    /// authorUserID == currentUser ise buraya hiç düşmemeli.
    func ingest(
        commentID: String,
        shareRecordName: String,
        authorUserID: String,
        authorDisplayName: String?,
        bodyExcerpt: String?,
        moodColorHex: String?,
        isReplyToMe: Bool = false
    ) {
        queue.async { [weak self] in
            guard let self else { return }

            if isReplyToMe {
                // Reply benim yorumumaysa bundle'lama — tekil yüksek-öncelikli push.
                self.fireImmediate(
                    kind: .commentReply,
                    shareRecordName: shareRecordName,
                    authorUserID: authorUserID,
                    authorDisplayName: authorDisplayName,
                    bodyExcerpt: bodyExcerpt,
                    moodColorHex: moodColorHex,
                    commentID: commentID
                )
                return
            }

            // Mevcut bundle var mı?
            if var bundle = self.pending[shareRecordName] {
                bundle.commentIDs.append(commentID)
                // İlk yazarın adı sabit kalır; sonrakiler count artırır.
                bundle.workItem?.cancel()
                self.scheduleFlush(for: shareRecordName, bundle: &bundle)
                self.pending[shareRecordName] = bundle
            } else {
                var bundle = PendingBundle(
                    shareRecordName: shareRecordName,
                    firstAuthorName: authorDisplayName,
                    firstAuthorID: authorUserID,
                    firstExcerpt: bodyExcerpt,
                    moodColorHex: moodColorHex,
                    commentIDs: [commentID],
                    createdAt: Date()
                )
                self.scheduleFlush(for: shareRecordName, bundle: &bundle)
                self.pending[shareRecordName] = bundle
            }
        }
    }

    /// Bundle tutmadan hemen push — test / unit için.
    func flushAll() {
        queue.async { [weak self] in
            guard let self else { return }
            let keys = Array(self.pending.keys)
            for k in keys { self.flush(shareRecordName: k) }
        }
    }

    // MARK: Internal

    private func scheduleFlush(for key: String, bundle: inout PendingBundle) {
        let work = DispatchWorkItem { [weak self] in
            self?.queue.async { self?.flush(shareRecordName: key) }
        }
        bundle.workItem = work
        queue.asyncAfter(deadline: .now() + debounceInterval, execute: work)
    }

    private func flush(shareRecordName: String) {
        guard let bundle = pending.removeValue(forKey: shareRecordName) else { return }

        let count = bundle.commentIDs.count
        let kind: NotificationKind = count >= 2 ? .commentBatch : .commentReceived

        let abBucket = EngagementTracker.abBucket(userID: nil)
        let ctx = MessageContext(
            kind: kind,
            friendName: bundle.firstAuthorName,
            friendCount: count,
            commentExcerpt: count == 1 ? bundle.firstExcerpt : nil,
            commentCount: count,
            abBucket: abBucket
        )
        let seed = Int(bundle.createdAt.timeIntervalSince1970)
        let msg = NotificationMessageBuilder.build(ctx, seed: seed)

        let content = UNMutableNotificationContent()
        content.title = msg.title
        content.body = msg.body
        content.sound = .default
        content.categoryIdentifier = kind.categoryIdentifier
        content.threadIdentifier = "comments-\(shareRecordName)"
        content.userInfo = [
            "kind": kind.rawValue,
            "variant": msg.variant,
            "shareRecordName": shareRecordName,
            "commentCount": count,
            "commentIDs": bundle.commentIDs,
            "friendID": bundle.firstAuthorID ?? "",
            "friendName": bundle.firstAuthorName ?? "",
            "scheduledAt": Date().timeIntervalSince1970,
            "shouldNavigateToComments": true
        ]
        if count == 1, let excerpt = bundle.firstExcerpt {
            content.userInfo["commentExcerpt"] = excerpt
        }
        if let hex = bundle.moodColorHex,
           let attachment = RichAttachmentFactory.attachment(
               forMoodHex: hex,
               identifier: "comment-\(shareRecordName)"
           ) {
            content.attachments = [attachment]
        }

        let identifier = "comment_\(shareRecordName)_\(Int(Date().timeIntervalSince1970))"
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 0.5, repeats: false)

        NotificationOrchestrator.shared.schedule(
            kind: kind,
            identifier: identifier,
            trigger: trigger,
            content: content,
            variant: msg.variant
        )
    }

    private func fireImmediate(
        kind: NotificationKind,
        shareRecordName: String,
        authorUserID: String,
        authorDisplayName: String?,
        bodyExcerpt: String?,
        moodColorHex: String?,
        commentID: String
    ) {
        let ctx = MessageContext(
            kind: kind,
            friendName: authorDisplayName,
            friendCount: 1,
            commentExcerpt: bodyExcerpt,
            commentCount: 1,
            abBucket: EngagementTracker.abBucket(userID: nil)
        )
        let msg = NotificationMessageBuilder.build(ctx, seed: Int(Date().timeIntervalSince1970))

        let content = UNMutableNotificationContent()
        content.title = msg.title
        content.body = msg.body
        content.sound = .default
        content.categoryIdentifier = kind.categoryIdentifier
        content.threadIdentifier = "comments-\(shareRecordName)"
        content.userInfo = [
            "kind": kind.rawValue,
            "variant": msg.variant,
            "shareRecordName": shareRecordName,
            "commentID": commentID,
            "friendID": authorUserID,
            "friendName": authorDisplayName ?? "",
            "commentExcerpt": bodyExcerpt ?? "",
            "scheduledAt": Date().timeIntervalSince1970,
            "shouldNavigateToComments": true
        ]
        if let hex = moodColorHex,
           let attachment = RichAttachmentFactory.attachment(
               forMoodHex: hex,
               identifier: "reply-\(commentID)"
           ) {
            content.attachments = [attachment]
        }

        let identifier = "commentreply_\(commentID)"
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 0.5, repeats: false)

        NotificationOrchestrator.shared.schedule(
            kind: kind,
            identifier: identifier,
            trigger: trigger,
            content: content,
            variant: msg.variant
        )
    }
}
