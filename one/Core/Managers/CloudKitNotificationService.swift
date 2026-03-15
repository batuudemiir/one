//
//  CloudKitNotificationService.swift
//  one
//
//  CloudKit push notification subscriptions:
//  - Arkadaşlık isteği geldiğinde bildirim
//  - Arkadaş günlük şarkısını seçtiğinde bildirim (DailyShare)
//  - İstek kabul edildiğinde bildirim
//

import Foundation
import CloudKit
import UserNotifications

// MARK: - CloudKit Notification Service

extension CloudKitManager {

    private static let friendRequestSubID  = "friend-request-notification-v2"
    private static let friendShareSubID    = "friend-daily-share-notification-v2"
    private static let friendAcceptSubID   = "friend-accept-notification-v2"
    private static let emojiReactionSubID  = "emoji-reaction-notification-v1"

    // MARK: - Register all subscriptions

    func registerAllSubscriptions() {
        registerFriendRequestSubscription()
        registerFriendShareSubscription()
        registerFriendAcceptSubscription()
        registerEmojiReactionSubscription()
    }

    // MARK: - 1. Friend Request Subscription (gelen istek)

    func registerFriendRequestSubscription() {
        guard let currentUserID = currentUser?["userID"] as? String else { return }

        let subID = Self.friendRequestSubID
        publicDatabase.fetch(withSubscriptionID: subID) { [weak self] existing, _ in
            guard let self else { return }
            if existing != nil { return }   // already registered

            let predicate = NSPredicate(format: "user2ID == %@ AND status == %@",
                                        currentUserID, "pending")
            let sub = CKQuerySubscription(
                recordType: "Friendship",
                predicate: predicate,
                subscriptionID: subID,
                options: [.firesOnRecordCreation]
            )
            let info = CKSubscription.NotificationInfo()
            info.shouldSendContentAvailable = true      // silent push → app processes it
            info.desiredKeys = ["user1ID", "status"]
            sub.notificationInfo = info

            self.publicDatabase.save(sub) { _, error in
                if let error { ONELogger.error("Friend request sub failed", error: error, category: .notification) }
                else { ONELogger.success("Friend request subscription registered", category: .notification) }
            }
        }
    }

    // MARK: - 2. Friend DailyShare Subscription (arkadaş şarkı seçti)

    /// Subscribes to DailyShare records created by friends today.
    /// Because CloudKit public DB can't filter by a dynamic friend list,
    /// we store the user's friendIDs in their AppUser record and use a
    /// server-side subscription that fires for ANY new DailyShare; the
    /// app then filters locally. This is the recommended pattern for fan-out.
    func registerFriendShareSubscription() {
        guard currentUser?["userID"] as? String != nil else { return }

        let subID = Self.friendShareSubID
        publicDatabase.fetch(withSubscriptionID: subID) { [weak self] existing, _ in
            guard let self else { return }
            if existing != nil { return }

            // Fire on any new DailyShare — we filter in handleCloudKitNotification
            let sub = CKQuerySubscription(
                recordType: "DailyShare",
                predicate: NSPredicate(value: true),   // all records; filter in app
                subscriptionID: subID,
                options: [.firesOnRecordCreation, .firesOnRecordUpdate]
            )
            let info = CKSubscription.NotificationInfo()
            info.shouldSendContentAvailable = true      // silent push
            info.desiredKeys = ["userID"]  // Minimize payload; app fetches full record server-side
            sub.notificationInfo = info

            self.publicDatabase.save(sub) { _, error in
                if let error { ONELogger.error("Friend share sub failed", error: error, category: .notification) }
                else { ONELogger.success("Friend daily share subscription registered", category: .notification) }
            }
        }
    }

    // MARK: - 4. Emoji Reaction Subscription (birileri şarkımı duydu)

    func registerEmojiReactionSubscription() {
        guard currentUser?["userID"] as? String != nil else { return }

        let subID = Self.emojiReactionSubID
        publicDatabase.fetch(withSubscriptionID: subID) { [weak self] existing, _ in
            guard let self else { return }
            if existing != nil { return }

            let sub = CKQuerySubscription(
                recordType: "EmojiReaction",
                predicate: NSPredicate(value: true),   // tümünü al, app tarafında filtrele
                subscriptionID: subID,
                options: [.firesOnRecordCreation]
            )
            let info = CKSubscription.NotificationInfo()
            info.shouldSendContentAvailable = true
            info.desiredKeys = ["shareRecordName", "senderUserID", "emoji"]
            sub.notificationInfo = info

            self.publicDatabase.save(sub) { _, error in
                if let error { ONELogger.error("Emoji reaction sub failed", error: error, category: .notification) }
                else { ONELogger.success("Emoji reaction subscription registered", category: .notification) }
            }
        }
    }

    // MARK: - 3. Friend Accept Subscription (isteğim kabul edildi)

    func registerFriendAcceptSubscription() {
        guard let currentUserID = currentUser?["userID"] as? String else { return }

        let subID = Self.friendAcceptSubID
        publicDatabase.fetch(withSubscriptionID: subID) { [weak self] existing, _ in
            guard let self else { return }
            if existing != nil { return }

            // Fires when someone creates an accepted Friendship record towards me
            let predicate = NSPredicate(format: "user2ID == %@ AND status == %@",
                                        currentUserID, "accepted")
            let sub = CKQuerySubscription(
                recordType: "Friendship",
                predicate: predicate,
                subscriptionID: subID,
                options: [.firesOnRecordCreation]
            )
            let info = CKSubscription.NotificationInfo()
            info.shouldSendContentAvailable = true
            info.desiredKeys = ["user1ID", "status"]
            sub.notificationInfo = info

            self.publicDatabase.save(sub) { _, error in
                if let error { ONELogger.error("Friend accept sub failed", error: error, category: .notification) }
                else { ONELogger.success("Friend accept subscription registered", category: .notification) }
            }
        }
    }

    // MARK: - Handle incoming CloudKit push

    func handleCloudKitNotification(_ userInfo: [String: Any], completion: @escaping () -> Void) {
        guard let notification = CKNotification(fromRemoteNotificationDictionary: userInfo) as? CKQueryNotification else {
            completion(); return
        }

        switch notification.subscriptionID {

        case Self.friendRequestSubID:
            handleFriendRequestPush(notification: notification, completion: completion)

        case Self.friendShareSubID:
            handleFriendSharePush(notification: notification, completion: completion)

        case Self.friendAcceptSubID:
            handleFriendAcceptPush(notification: notification, completion: completion)

        case Self.emojiReactionSubID:
            handleEmojiReactionPush(notification: notification, completion: completion)

        default:
            completion()
        }
    }

    // MARK: - Friend request push handler

    private func handleFriendRequestPush(notification: CKQueryNotification, completion: @escaping () -> Void) {
        guard let senderID = notification.recordFields?["user1ID"] as? String,
              let status   = notification.recordFields?["status"]  as? String,
              status == "pending"
        else { completion(); return }

        fetchDisplayName(for: senderID) { name in
            self.scheduleLocalNotification(
                title: "Çevrenden yeni davet 🎵",
                body:  "\(name) seni ONE çevresine çağırıyor.",
                category: "FRIEND_REQUEST",
                userInfo: ["type": "friend_request", "senderID": senderID]
            )
            // Tell CircleView to refresh
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .init("circleDataNeedsRefresh"), object: nil)
            }
            completion()
        }
    }

    // MARK: - Friend share push handler

    private func handleFriendSharePush(notification: CKQueryNotification, completion: @escaping () -> Void) {
        // Only userID is in the push payload (desiredKeys minimized for privacy)
        guard let sharerID = notification.recordFields?["userID"] as? String else {
            completion(); return
        }

        // Only show if this person is actually our friend
        isFriendWith(userID: sharerID) { [weak self] isFriend in
            guard isFriend, let self else { completion(); return }

            self.fetchDisplayName(for: sharerID) { name in
                self.scheduleLocalNotification(
                    title: "Çevrende yeni paylaşım var 🎵",
                    body:  "\(name) bugün mood'unu ve şarkısını paylaştı.",
                    category: "FRIEND_SHARED",
                    userInfo: ["type": "friend_shared", "sharerID": sharerID]
                )
                DispatchQueue.main.async {
                    NotificationCenter.default.post(name: .init("circleDataNeedsRefresh"), object: nil)
                }
                completion()
            }
        }
    }

    // MARK: - Friend accept push handler

    private func handleFriendAcceptPush(notification: CKQueryNotification, completion: @escaping () -> Void) {
        guard let accepterID = notification.recordFields?["user1ID"] as? String else {
            completion(); return
        }

        fetchDisplayName(for: accepterID) { name in
            self.scheduleLocalNotification(
                title: "Çevrene yeni biri katıldı 🎵",
                body:  "\(name) artık bugünkü paylaşımlarını görebilir.",
                category: "FRIEND_ACCEPTED",
                userInfo: ["type": "friend_accepted", "accepterID": accepterID]
            )
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .init("circleDataNeedsRefresh"), object: nil)
            }
            completion()
        }
    }

    // MARK: - Emoji reaction push handler

    private func handleEmojiReactionPush(notification: CKQueryNotification, completion: @escaping () -> Void) {
        guard let shareRecordName = notification.recordFields?["shareRecordName"] as? String,
              let senderID        = notification.recordFields?["senderUserID"]    as? String,
              let emoji           = notification.recordFields?["emoji"]           as? String
        else { completion(); return }

        // Kendi gönderdiğimiz reaksiyonlarda bildirim gösterme
        guard let currentUserID = currentUser?["userID"] as? String,
              senderID != currentUserID
        else { completion(); return }

        // Share'in bize ait olup olmadığını kontrol et
        let shareRecordID = CKRecord.ID(recordName: shareRecordName)
        publicDatabase.fetch(withRecordID: shareRecordID) { [weak self] record, _ in
            guard let self,
                  let record = record,
                  let shareOwnerID = record["userID"] as? String,
                  shareOwnerID == currentUserID
            else { completion(); return }

            self.fetchDisplayName(for: senderID) { name in
                self.scheduleLocalNotification(
                    title: "\(name) paylaşımına tepki verdi \(emoji)",
                    body:  "Bugünkü seçimin çevrende karşılık buldu.",
                    category: "EMOJI_REACTION",
                    userInfo: ["type": "emoji_reaction", "senderID": senderID, "emoji": emoji]
                )
                DispatchQueue.main.async {
                    NotificationCenter.default.post(name: .init("circleDataNeedsRefresh"), object: nil)
                }
                completion()
            }
        }
    }

    // MARK: - Helpers

    private func fetchDisplayName(for userID: String, completion: @escaping (String) -> Void) {
        let predicate = NSPredicate(format: "userID == %@", userID)
        let query     = CKQuery(recordType: "AppUser", predicate: predicate)
        publicDatabase.fetch(withQuery: query, inZoneWith: nil,
                             desiredKeys: ["displayName"], resultsLimit: 1) { result in
            var name = "Birisi"
            if case .success(let (matches, _)) = result,
               let record = matches.compactMap({ try? $0.1.get() }).first {
                name = record["displayName"] as? String ?? "Birisi"
            }
            completion(name)
        }
    }

    private func isFriendWith(userID: String, completion: @escaping (Bool) -> Void) {
        fetchFriends { result in
            if case .success(let friends) = result {
                let ids = friends.compactMap { r -> String? in
                    let u1 = r["user1ID"] as? String ?? ""
                    let u2 = r["user2ID"] as? String ?? ""
                    guard let me = self.currentUser?["userID"] as? String else { return nil }
                    return u1 == me ? u2 : u1
                }
                completion(ids.contains(userID))
            } else {
                completion(false)
            }
        }
    }

    private func scheduleLocalNotification(title: String, body: String,
                                           category: String, userInfo: [String: Any]) {
        let content = UNMutableNotificationContent()
        content.title    = title
        content.body     = body
        content.sound    = .default
        content.categoryIdentifier = category
        content.userInfo = userInfo

        let request = UNNotificationRequest(
            identifier: "\(category)_\(UUID().uuidString)",
            content: content,
            trigger: nil   // deliver immediately
        )
        UNUserNotificationCenter.current().add(request) { error in
            if let error {
                ONELogger.error("Failed to schedule notification", error: error, category: .notification)
            } else {
                ONELogger.success("Notification scheduled: \(title)", category: .notification)
            }
        }
    }

    // MARK: - Remove all subscriptions (e.g. on sign-out)

    func removeAllSubscriptions() {
        for subID in [Self.friendRequestSubID, Self.friendShareSubID, Self.friendAcceptSubID, Self.emojiReactionSubID] {
            publicDatabase.delete(withSubscriptionID: subID) { _, _ in }
        }
    }

    // Legacy alias kept for any existing call sites
    func registerFriendRequestSubscription_legacy() {
        registerFriendRequestSubscription()
    }
    func removeFriendRequestSubscription() {
        publicDatabase.delete(withSubscriptionID: Self.friendRequestSubID) { _, _ in }
    }
}
