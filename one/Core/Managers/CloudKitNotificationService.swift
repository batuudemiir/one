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
import Combine
import UserNotifications
import UIKit

// MARK: - CloudKit Notification Service

extension CloudKitManager {

    private static let friendRequestSubID  = "friend-request-notification-v6"
    private static let friendShareSubID    = "friend-daily-share-notification-v6"
    private static let friendAcceptSubID   = "friend-accept-notification-v6"
    private static let emojiReactionSubID  = "emoji-reaction-notification-v4"
    // v2.5 — yorum notification'ı
    private static let commentSubID        = "comment-notification-v1"

    // Subscription version — artırınca tüm subscriptionlar silinip yeniden kaydedilir
    // v9: friendShare + comment silent push → visible push (alertBody eklendi).
    //     Silent push iOS tarafından throttle edildiği için uygulama kapalıyken bildirim
    //     gelmiyordu. Visible push CloudKit sunucu tarafında APNs'e dönüşür, app state'ten bağımsız.
    private static let currentSubVersion   = 9
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
        "emoji-reaction-notification-v4",
        // v6 → v7 migration (generic alertBody removed → silent push)
        "friend-request-notification-v6",
        "friend-daily-share-notification-v6",
        "friend-accept-notification-v6",
        // v7 → v8 migration (emoji reactions removed → yorum sistemi)
        // Emoji subscription ID'sini buraya ekle — migration'da silinsin.
        // (emoji-reaction-notification-v4 yukarıda zaten var, çift eklemiyoruz)
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
                // Yorum sistemi kaldırıldı (efemer karşılığa geçildi) — abonelik yok.
                // v2.5 — emoji subscription artık kayıt edilmiyor (v8)
                // Eski kayıt legacy list'te silindi. Tutulan handler back-compat
                // için — yeni sub olmadığı için handler hiç tetiklenmez.
                UserDefaults.standard.set(Self.currentSubVersion, forKey: Self.subVersionKey)
                ONELogger.success("Subscriptions migrated to v\(Self.currentSubVersion)", category: .notification)
            }
        } else {
            registerFriendRequestSubscription()
            registerFriendShareSubscription()
            registerFriendAcceptSubscription()
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
    /// Silent push (alertBody = nil): APNs never shows a visible notification.
    /// The push handler schedules a personalized local notification after
    /// isFriendWith filtering, eliminating duplicate/generic notifications.
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
            // Visible push — uygulama kapalıyken de APNs bildirim gösterir.
            // Handler arka planda çalışıp personalize lokal bildirim üretirse generic APNs
            // bildirimi temizlenir (dedup). App tamamen kapalıysa generic metin kalır.
            // Not: arkadaş olmayanların paylaşımları handler tarafında isFriendWith ile filtrelenir;
            // onlar için generic bildirim birkaç saniye görünüp silinir (iOS throttle'ı nedeniyle
            // kabul edilebilir tradeoff — uygulama kapalıyken tümü kaybolmasından iyi).
            info.alertBody                  = "Çevrenden birisi paylaşım yaptı 🎵"
            info.shouldSendContentAvailable = true
            info.shouldBadge                = true
            info.collapseIDKey              = "userID"
            info.category                   = "FRIEND_SHARED"
            info.desiredKeys                = ["userID"]
            sub.notificationInfo            = info

            self.publicDatabase.save(sub) { _, error in
                if let error { ONELogger.error("Friend share sub failed", error: error, category: .notification) }
                else { ONELogger.success("Friend daily share subscription registered (v7 silent)", category: .notification) }
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
            // v2.5 — emoji reactions deprecated. Kayıt olmuyor; handler back-compat için.
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
            // Store'a friendRequest bildirimi ekle — birleşik akışta gösterim için
            let notif = CircleNotification(
                id: "friendRequest_\(senderID)_\(Int(Date().timeIntervalSince1970))",
                type: .friendRequest,
                title: "\(name) seni çevresine eklemek istiyor",
                body: "Kabul et veya incele.",
                date: Date(),
                isRead: false,
                relatedUserID: senderID,
                emoji: nil,
                requestRecordName: notification.recordID?.recordName,
                requestStatus: "pending"
            )
            Task { @MainActor in CircleNotificationStore.shared.add(notif) }

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

        // BUG FIX (v2.5.1) — Block check.
        // Block sistemi friendship kaydını silmiyor; bu yüzden engellenmiş kullanıcının
        // paylaşımı isFriendWith=true döner ama Circle feed filter'ı kayıt göstermez →
        // kullanıcı "yeni paylaşım var dediler ama yok" hatası yaşar.
        if isBlockedByMe(sharerID) || isBlockedByThem(sharerID) {
            ONELogger.info("Friend share push dropped — block relation exists with \(sharerID)", category: .notification)
            completion()
            return
        }

        isFriendWith(userID: sharerID) { [weak self] result in
            guard let self else { completion(); return }

            switch result {
            case .success(false):
                // Confirmed not a friend — skip notification silently
                completion()

            case .success(true):
                let notifID = "friendShare_\(sharerID)_\(Self.todayDateKey())"

                DispatchQueue.main.async {
                    NotificationCenter.default.post(name: .init("circleDataNeedsRefresh"), object: nil)
                }

                self.fetchDisplayName(for: sharerID) { name in
                    guard name != "Birisi" else {
                        ONELogger.info("Friend share push dropped — could not resolve displayName for \(sharerID)", category: .notification)
                        completion()
                        return
                    }
                    self.fetchDailyShare(for: sharerID, date: Date()) { shareResult in
                        let moodLabel: String?
                        let moodColorHex: String?
                        if case .success(let record) = shareResult {
                            moodLabel    = record["moodWord"] as? String
                            moodColorHex = record["moodColor"] as? String
                        } else {
                            moodLabel = nil
                            moodColorHex = nil
                        }

                        let moodBody: String = {
                            if let mood = moodLabel {
                                return "\(name) bugün \(mood) hissediyor — dinlemek ister misin?"
                            }
                            return "\(name) bugün mood'unu ve şarkısını seçti. Bakmak ister misin?"
                        }()

                        DispatchQueue.main.async {
                            let notif = CircleNotification(
                                id: notifID,
                                type: .friendShare,
                                title: "\(name) paylaşım yaptı 🎵",
                                body: moodBody,
                                date: Date(),
                                isRead: false,
                                relatedUserID: sharerID,
                                emoji: nil,
                                moodColorHex: moodColorHex,
                                shareRecordName: sharerID
                            )
                            CircleNotificationStore.shared.add(notif)

                            var userInfo: [String: Any] = [
                                "type": "friend_shared",
                                "sharerID": sharerID,
                                "friendName": name
                            ]
                            if let hex = moodColorHex { userInfo["moodColorHex"] = hex }
                            if let mood = moodLabel { userInfo["moodLabel"] = mood }

                            self.scheduleLocalNotification(
                                title: "\(name) paylaşım yaptı 🎵",
                                body:  moodBody,
                                category: "FRIEND_SHARED",
                                identifier: notifID,
                                userInfo: userInfo
                            )
                            completion()
                        }

                        if case .success(let record) = shareResult {
                            let moodColorHex = record["moodColor"] as? String ?? "#5B8DEF"

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
                    }
                }

            case .failure:
                // Network error — arkadaşlık bilinmiyor. Sessizce geç; silent push olduğu için
                // kullanıcıya yanlış generic bildirim gösterilmiyor.
                ONELogger.info("isFriendWith network error — silent push, no visible alert shown", category: .notification)
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
                title: "\(name) artık çevrende 🎉",
                body: "İlk paylaşımını görmeye hazır mısın?",
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
        // Cache hit — background processing için kritik hızlandırma
        if Date().timeIntervalSince(cachedFriendIDsTimestamp) < friendCacheTTL {
            completion(.success(cachedFriendIDs.contains(userID)))
            return
        }

        fetchFriends { result in
            switch result {
            case .success(let friends):
                let ids = friends.compactMap { r -> String? in
                    let u1 = r["user1ID"] as? String ?? ""
                    let u2 = r["user2ID"] as? String ?? ""
                    guard let me = self.currentUser?["userID"] as? String else { return nil }
                    return u1 == me ? u2 : u1
                }
                // Cache güncelle
                self.cachedFriendIDs = Set(ids)
                self.cachedFriendIDsTimestamp = Date()
                completion(.success(ids.contains(userID)))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    /// CloudKit tarafından iletilen generic APNs bildirimlerini temizler.
    /// Tanımlama: bizim lokal bildirimlerimizde her zaman "type" anahtarı bulunur;
    /// CloudKit APNs bildirimlerinde ise "ck" anahtarı vardır, "type" yoktur.
    private func removeDeliveredCloudKitNotifications(forCategory category: String) {
        UNUserNotificationCenter.current().getDeliveredNotifications { delivered in
            let ckIDs = delivered
                .filter { $0.request.content.categoryIdentifier == category }
                .filter { $0.request.content.userInfo["type"] == nil }
                .map { $0.request.identifier }
            if !ckIDs.isEmpty {
                UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: ckIDs)
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

        let moodHex = userInfo["moodColorHex"] as? String
        let notificationID = identifier ?? "\(category)_\(UUID().uuidString)"
        if let att = RichAttachmentFactory.attachment(forMoodHex: moodHex,
                                                      identifier: notificationID) {
            content.attachments = [att]
        }

        let kind: NotificationKind = {
            switch category {
            case "FRIEND_REQUEST":   return .friendRequest
            case "FRIEND_ACCEPTED":  return .friendAccepted
            case "FRIEND_SHARED":    return .friendShared
            case "EMOJI_REACTION":   return .friendReaction
            case "MOOD_RESONANCE":   return .moodResonance
            default:                 return .circleActivity
            }
        }()

        let decision = NotificationOrchestrator.shared.schedule(
            kind: kind,
            identifier: notificationID,
            trigger: nil,
            content: content
        )

        // Generic CloudKit APNs bildirimi yalnızca orchestrator izin verirse temizle.
        // Drop durumunda generic bildirim görünür kalır — kullanıcı hiçbir şey görmez sorunu önlenir.
        if case .drop = decision {} else {
            removeDeliveredCloudKitNotifications(forCategory: category)
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
                (Self.friendAcceptSubID,   { self.registerFriendAcceptSubscription() })
                // v2.5 — emojiReactionSubID kaldırıldı.
                // Yorum aboneliği kaldırıldı (efemer karşılığa geçildi).
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
                      Self.friendAcceptSubID, Self.emojiReactionSubID,
                      Self.commentSubID]
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
