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
import UIKit

// MARK: - CloudKit Notification Service

extension CloudKitManager {

    private static let friendRequestSubID  = "friend-request-notification-v6"
    private static let friendShareSubID    = "friend-daily-share-notification-v6"
    private static let friendAcceptSubID   = "friend-accept-notification-v6"
    private static let emojiReactionSubID  = "emoji-reaction-notification-v4"

    // Subscription version — artırınca tüm subscriptionlar silinip yeniden kaydedilir
    private static let currentSubVersion   = 6
    private static let subVersionKey       = "cloudkit_subscription_version"

    // Eski subscription ID'leri (temizleme için)
    private static let legacySubIDs = [
        "friend-request-notification-v2",
        "friend-daily-share-notification-v2",
        "friend-accept-notification-v2",
        "emoji-reaction-notification-v1",
        "friend-request-notification-v3",
        "friend-daily-share-notification-v3",
        "friend-accept-notification-v3",
        "emoji-reaction-notification-v2",
        "friend-request-notification-v4",
        "friend-daily-share-notification-v4",
        "friend-accept-notification-v4",
        "emoji-reaction-notification-v3",
        // v5 → v6 migration
        "friend-request-notification-v5",
        "friend-daily-share-notification-v5",
        "friend-accept-notification-v5",
        "emoji-reaction-notification-v4"
    ]

    // MARK: - Register all subscriptions

    func registerAllSubscriptions() {
        let storedVersion = UserDefaults.standard.integer(forKey: Self.subVersionKey)
        if storedVersion < Self.currentSubVersion {
            // Eski subscriptionları temizle, yenilerini kaydet
            for oldID in Self.legacySubIDs {
                publicDatabase.delete(withSubscriptionID: oldID) { _, _ in }
            }
            removeAllSubscriptions()
            // CloudKit silme işlemi async — kısa bekleme sonrası yeniden kayıt
            DispatchQueue.global().asyncAfter(deadline: .now() + 1.5) { [weak self] in
                self?.registerFriendRequestSubscription()
                self?.registerFriendShareSubscription()
                self?.registerFriendAcceptSubscription()
                self?.registerEmojiReactionSubscription()
                UserDefaults.standard.set(Self.currentSubVersion, forKey: Self.subVersionKey)
                ONELogger.success("Subscriptions migrated to v\(Self.currentSubVersion)", category: .notification)
            }
        } else {
            registerFriendRequestSubscription()
            registerFriendShareSubscription()
            registerFriendAcceptSubscription()
            registerEmojiReactionSubscription()
        }
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
            // Görünür bildirim — uygulama kapalı olsa bile APNs gösterir
            info.alertBody  = "Yeni bir arkadaşlık isteğin var 🎵"
            info.soundName  = "default"
            info.shouldBadge = true
            // Arka planda da işlem yapılabilsin
            info.shouldSendContentAvailable = true
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
    ///
    /// Visible alertBody ensures APNs delivers the notification even when the
    /// app is killed. The push handler replaces it with a personalized local
    /// notification only when the app is in the foreground.
    func registerFriendShareSubscription() {
        guard let currentUserID = currentUser?["userID"] as? String else { return }

        let subID = Self.friendShareSubID
        publicDatabase.fetch(withSubscriptionID: subID) { [weak self] existing, _ in
            guard let self else { return }
            if existing != nil { return }

            // Kendi paylaşımlarımızı kapsam dışında bırak — en büyük false-positive kaynağı.
            // Diğer yabancı kullanıcıların paylaşımları app tarafında isFriendWith ile filtreleniyor.
            let predicate = NSPredicate(format: "userID != %@", currentUserID)
            let sub = CKQuerySubscription(
                recordType: "DailyShare",
                predicate: predicate,
                subscriptionID: subID,
                options: [.firesOnRecordCreation]
            )
            let info = CKSubscription.NotificationInfo()
            // APNs görünür bildirim — uygulama kapalıyken de teslim edilir.
            // App açıkken/arka plandayken handleFriendSharePush kişiselleştirilmiş
            // yerel bildirim gönderir; uygulama kapalıyken bu generic metin kullanılır.
            info.alertBody               = "Çevrende yeni bir şey var 🎵"
            info.soundName               = "default"
            info.shouldBadge             = true
            info.shouldSendContentAvailable = true  // Arka plan işleme için
            info.collapseIDKey           = "userID" // Aynı kişinin pushları birleşir
            info.desiredKeys             = ["userID"]
            sub.notificationInfo         = info

            self.publicDatabase.save(sub) { _, error in
                if let error { ONELogger.error("Friend share sub failed", error: error, category: .notification) }
                else { ONELogger.success("Friend daily share subscription registered (v6)", category: .notification) }
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
            // Görünür bildirim
            info.alertBody  = "Birisi paylaşımına tepki verdi 💫"
            info.soundName  = "default"
            info.shouldBadge = true
            info.shouldSendContentAvailable = true
            info.desiredKeys = ["shareRecordName", "senderUserID", "emoji"]
            sub.notificationInfo = info

            self.publicDatabase.save(sub) { _, error in
                if let ckError = error as? CKError {
                    // "Did not find record type: EmojiReaction" — schema henüz deploy edilmemiş.
                    // CloudKit Dashboard'da EmojiReaction record type oluşturulup deploy edilince
                    // bu sub otomatik kayıt olacak. Şimdilik sessizce geç.
                    if ckError.code == .invalidArguments || ckError.code == .unknownItem {
                        ONELogger.info("EmojiReaction schema CloudKit'te henüz yok — subscription atlandı. CloudKit Dashboard'dan deploy edin.", category: .notification)
                    } else {
                        ONELogger.error("Emoji reaction sub failed", error: ckError, category: .notification)
                    }
                } else if let error {
                    ONELogger.error("Emoji reaction sub failed", error: error, category: .notification)
                } else {
                    ONELogger.success("Emoji reaction subscription registered", category: .notification)
                }
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
            // Görünür bildirim
            info.alertBody  = "Arkadaşlık isteğin kabul edildi ✨"
            info.soundName  = "default"
            info.shouldBadge = true
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

        isFriendWith(userID: sharerID) { [weak self] result in
            guard let self else { completion(); return }

            switch result {
            case .success(false):
                // Confirmed not a friend — skip notification silently
                completion()

            case .success(true):
                // Onaylı arkadaş — her durumda (foreground/background/arka plan) kişisel bildirim gönder.
                // Uygulama kapalıyken APNs generic alertBody'yi zaten gösterdi; kişisel bildirim
                // onu tamamlar ve arkadaşın ismini taşır.
                self.fetchDisplayName(for: sharerID) { name in
                    DispatchQueue.main.async {
                        let notifID = "friendShare_\(sharerID)_\(Self.todayDateKey())"
                        let notif = CircleNotification(
                            id: notifID,
                            type: .friendShare,
                            title: "\(name) paylaşım yaptı 🎵",
                            body: "\(name) bugün mood'unu ve şarkısını seçti.",
                            date: Date(),
                            isRead: false,
                            relatedUserID: sharerID,
                            emoji: nil
                        )
                        CircleNotificationStore.shared.add(notif)

                        // Uygulama durumundan bağımsız: kişisel bildirim her zaman gönderilir.
                        // Foreground'da APNs görsel alert zaten gösterilmez; background/killed'da
                        // hem APNs generic hem de bu kişisel bildirim kullanıcıya ulaşır.
                        self.scheduleLocalNotification(
                            title: "\(name) paylaşım yaptı 🎵",
                            body:  "\(name) bugün mood'unu ve şarkısını seçti. Bakmak ister misin?",
                            category: "FRIEND_SHARED",
                            identifier: notifID,
                            userInfo: ["type": "friend_shared", "sharerID": sharerID]
                        )
                        NotificationCenter.default.post(name: .init("circleDataNeedsRefresh"), object: nil)
                    }

                    // Dynamic Island + Çevre Yankısı — arkadaş paylaşım kaydını çek
                    self.fetchDailyShare(for: sharerID, date: Date()) { shareResult in
                        if case .success(let record) = shareResult {
                            let moodColorHex = record["moodColor"] as? String ?? "#5B8DEF"

                            // Çevre Yankısı — kullanıcı bugün seçim yaptıysa renk karşılaştır
                            self.checkResonanceForFriendShare(
                                friendColorHex: moodColorHex,
                                friendUserID:   sharerID,
                                friendName:     name
                            )

                            if #available(iOS 16.1, *) {
                                let songName   = record["songName"]  as? String ?? ""
                                let artistName = record["artistName"] as? String ?? ""
                                let moodLabel  = record["moodWord"]  as? String ?? ""
                                let sfSymbol   = LiveActivityManager.sfSymbol(forMoodLabel: moodLabel)

                                Task { @MainActor in
                                    await LiveActivityManager.shared.startFriendShare(
                                        friendName:   name,
                                        songName:     songName,
                                        artistName:   artistName,
                                        moodLabel:    moodLabel,
                                        moodColorHex: moodColorHex,
                                        moodSFSymbol: sfSymbol
                                    )
                                }
                            }
                        }
                        completion()
                    }
                }

            case .failure:
                // Network error — arkadaşlık bilinmiyor. APNs generic alertBody yeterli,
                // ekstra bildirim gösterme (false positive riski).
                ONELogger.info("isFriendWith network error — APNs alertBody yeterli, yerel bildirim atlandı", category: .notification)
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
            let notif = CircleNotification(
                id: "friendAccepted_\(accepterID)_\(Self.todayDateKey())",
                type: .friendAccepted,
                title: "Çevrene yeni biri katıldı ✨",
                body: "\(name) senin çevrende artık.",
                date: Date(),
                isRead: false,
                relatedUserID: accepterID,
                emoji: nil
            )
            Task { @MainActor in CircleNotificationStore.shared.add(notif) }

            self.scheduleLocalNotification(
                title: "Çevrene yeni biri katıldı ✨",
                body:  "\(name) senin çevrende artık. Bugünkü paylaşımlarını göster!",
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
                let notif = CircleNotification(
                    id: "emojiReaction_\(senderID)_\(emoji)_\(shareRecordName)",
                    type: .emojiReaction,
                    title: "\(name) paylaşımına tepki verdi \(emoji)",
                    body: "Bugünkü seçimin çevrende karşılık buldu.",
                    date: Date(),
                    isRead: false,
                    relatedUserID: senderID,
                    emoji: emoji
                )
                Task { @MainActor in CircleNotificationStore.shared.add(notif) }

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

    private func isFriendWith(userID: String, completion: @escaping (Result<Bool, Error>) -> Void) {
        fetchFriends { result in
            switch result {
            case .success(let friends):
                let ids = friends.compactMap { r -> String? in
                    let u1 = r["user1ID"] as? String ?? ""
                    let u2 = r["user2ID"] as? String ?? ""
                    guard let me = self.currentUser?["userID"] as? String else { return nil }
                    return u1 == me ? u2 : u1
                }
                completion(.success(ids.contains(userID)))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    func scheduleLocalNotification(title: String, body: String,
                                       category: String,
                                       identifier: String? = nil,
                                       userInfo: [String: Any]) {
        let content = UNMutableNotificationContent()
        content.title    = title
        content.body     = body
        content.sound    = .default
        content.categoryIdentifier = category
        content.userInfo = userInfo

        // Deterministik identifier sağlanırsa aynı event için çift bildirim önlenir.
        // Sağlanmazsa UUID ile benzersiz ID üret (streak, discovery vb. için gerekli).
        let notificationID = identifier ?? "\(category)_\(UUID().uuidString)"

        let request = UNNotificationRequest(
            identifier: notificationID,
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

    private static func todayDateKey() -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        return fmt.string(from: Date())
    }

    // MARK: - Verify subscriptions (call on app launch / midnight reset)

    /// Fetches all existing CloudKit subscriptions and re-registers any that are missing.
    /// Apple can silently delete CKSubscriptions under certain conditions (account change,
    /// schema wipe, iCloud storage issues). Calling this periodically ensures Circle push
    /// notifications keep working without requiring a full version bump.
    func verifySubscriptions() {
        guard currentUser?["userID"] as? String != nil else { return }

        publicDatabase.fetchAllSubscriptions { [weak self] subscriptions, error in
            guard let self else { return }

            if let error {
                ONELogger.error("verifySubscriptions: fetchAll failed", error: error, category: .notification)
                return
            }

            let existingIDs = Set((subscriptions ?? []).map { $0.subscriptionID })
            ONELogger.debug("verifySubscriptions: found \(existingIDs.count) active subscriptions", category: .notification)

            let required: [(String, () -> Void)] = [
                (Self.friendRequestSubID,  { self.registerFriendRequestSubscription() }),
                (Self.friendShareSubID,    { self.registerFriendShareSubscription() }),
                (Self.friendAcceptSubID,   { self.registerFriendAcceptSubscription() }),
                (Self.emojiReactionSubID,  { self.registerEmojiReactionSubscription() })
            ]

            for (subID, register) in required where !existingIDs.contains(subID) {
                ONELogger.info("verifySubscriptions: \(subID) missing — re-registering", category: .notification)
                register()
            }
        }
    }

    // MARK: - Remove all subscriptions (e.g. on sign-out)

    func removeAllSubscriptions() {
        let allIDs = [Self.friendRequestSubID, Self.friendShareSubID,
                      Self.friendAcceptSubID, Self.emojiReactionSubID]
            + Self.legacySubIDs
        for subID in allIDs {
            publicDatabase.delete(withSubscriptionID: subID) { _, _ in }
        }
        UserDefaults.standard.removeObject(forKey: Self.subVersionKey)
    }

    // Legacy alias kept for any existing call sites
    func registerFriendRequestSubscription_legacy() {
        registerFriendRequestSubscription()
    }
    func removeFriendRequestSubscription() {
        publicDatabase.delete(withSubscriptionID: Self.friendRequestSubID) { _, _ in }
    }
}
