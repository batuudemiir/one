//
//  CloudKitFriendshipService.swift
//  one
//
//  Friendship management extension for CloudKitManager.
//
//  ⚠️  ÖNEMLI — Production uyumluluğu:
//  Friendship record'larına YALNIZCA şu field'lar yazılır:
//    - user1ID   (String, Queryable index gerekli)
//    - user2ID   (String, Queryable index gerekli)
//    - status    (String, Queryable index gerekli)
//  Tarih için CloudKit'in built-in `creationDate` alanı kullanılır.
//  `createdDate`, `acceptedDate`, `friendshipID` gibi EXTRA field'lar
//  Production schema'sında olmayabileceğinden yazılmaz.
//

import Foundation
import CloudKit

// MARK: - Friendship Management

extension CloudKitManager {

    // MARK: - Relationship record date helper

    /// Record tarihi için her zaman CloudKit'in built-in creationDate'ini kullan.
    /// Custom createdDate field'ına asla güvenme — Production'da olmayabilir.
    private func recordDate(_ record: CKRecord) -> Date {
        record.creationDate ?? Date.distantPast
    }

    // MARK: - Unified Relationship Graph Fetcher

    private func fetchUserRelationships(completion: @escaping (Result<[String: CKRecord], Error>) -> Void) {
        guard let currentUserID = currentUser?["userID"] as? String else {
            completion(.failure(NSError(domain: "CloudKit", code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Current user not found"])))
            return
        }

        let predicate1 = NSPredicate(format: "user1ID == %@", currentUserID)
        let predicate2 = NSPredicate(format: "user2ID == %@", currentUserID)
        let query1 = CKQuery(recordType: "Friendship", predicate: predicate1)
        let query2 = CKQuery(recordType: "Friendship", predicate: predicate2)

        var allRecords: [CKRecord] = []
        var finalError: Error?
        let group     = DispatchGroup()
        let lockQueue = DispatchQueue(label: "com.one.relationshipLock")

        for query in [query1, query2] {
            group.enter()
            publicDatabase.fetch(withQuery: query, inZoneWith: nil,
                                 desiredKeys: nil,
                                 resultsLimit: CKQueryOperation.maximumResults) { result in
                lockQueue.async {
                    switch result {
                    case .success(let (matches, _)):
                        allRecords.append(contentsOf: matches.compactMap { try? $0.1.get() })
                    case .failure(let e):
                        finalError = e
                    }
                    group.leave()
                }
            }
        }

        group.notify(queue: .main) {
            if let error = finalError, allRecords.isEmpty {
                completion(.failure(error)); return
            }

            // Group records by the OTHER user, keep only the newest per pair
            var byOther: [String: [CKRecord]] = [:]
            for r in allRecords {
                let u1    = r["user1ID"] as? String ?? ""
                let u2    = r["user2ID"] as? String ?? ""
                let other = (u1 == currentUserID) ? u2 : u1
                guard !other.isEmpty else { continue }
                byOther[other, default: []].append(r)
            }

            var resolved: [String: CKRecord] = [:]
            for (other, records) in byOther {
                resolved[other] = records.max { self.recordDate($0) < self.recordDate($1) }
            }
            completion(.success(resolved))
        }
    }

    // MARK: - Send Friend Request

    func sendFriendRequest(toUserID: String,
                           completion: @escaping (Result<CKRecord, Error>) -> Void) {
        guard let currentUserID = currentUser?["userID"] as? String else {
            completion(.failure(NSError(domain: "CloudKit", code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Current user not found"]))); return
        }
        guard currentUserID != toUserID else {
            completion(.failure(AppError.circleSelfAdd)); return
        }

        checkExistingRelationship(with: toUserID) { [weak self] status in
            guard let self else { return }
            switch status {
            case .alreadyFriends:
                completion(.failure(AppError.circleAlreadyFriend))
            case .pendingSent:
                completion(.failure(NSError(domain: "Circle", code: -2,
                    userInfo: [NSLocalizedDescriptionKey: "Bu kişiye zaten istek gönderdin"])))
            case .pendingReceived:
                // Auto-accept mutual request
                self.fetchPendingRequestFrom(userID: toUserID) { result in
                    switch result {
                    case .success(let r): self.acceptFriendRequest(recordID: r.recordID.recordName, completion: completion)
                    case .failure(let e): completion(.failure(e))
                    }
                }
            case .blocked(let byMe):
                let msg = byMe ? "Bu kullanıcıyı engelledin." : "Bu kullanıcıya istek gönderilemez."
                completion(.failure(NSError(domain: "Circle", code: -3,
                    userInfo: [NSLocalizedDescriptionKey: msg])))
            case .none:
                // Only write the 3 required fields — no extra fields that may be missing in Production
                let rec = CKRecord(recordType: "Friendship")
                rec["user1ID"] = currentUserID as CKRecordValue
                rec["user2ID"] = toUserID      as CKRecordValue
                rec["status"]  = "pending"     as CKRecordValue

                self.publicDatabase.save(rec) { saved, error in
                    DispatchQueue.main.async {
                        if let saved {
                            ONELogger.success("Friend request sent", category: .circle)
                            AppAnalytics.shared.track(.friendRequestSent)
                            completion(.success(saved))
                        } else {
                            completion(.failure(error ?? NSError(domain: "CloudKit", code: -1)))
                        }
                    }
                }
            }
        }
    }

    // MARK: - Cancel Sent Request

    func cancelFriendRequest(toUserID: String,
                             completion: @escaping (Result<Bool, Error>) -> Void) {
        guard let currentUserID = currentUser?["userID"] as? String else {
            completion(.failure(NSError(domain: "CloudKit", code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Current user not found"]))); return
        }

        let rec = CKRecord(recordType: "Friendship")
        rec["user1ID"] = currentUserID as CKRecordValue
        rec["user2ID"] = toUserID      as CKRecordValue
        rec["status"]  = "cancelled"   as CKRecordValue

        publicDatabase.save(rec) { _, error in
            DispatchQueue.main.async {
                if let error {
                    ONELogger.error("Failed to cancel request", error: error, category: .circle)
                    completion(.failure(error))
                } else {
                    ONELogger.success("Friend request cancelled", category: .circle)
                    completion(.success(true))
                }
            }
        }
    }

    // MARK: - Accept Friend Request

    func acceptFriendRequest(recordID: String,
                             completion: @escaping (Result<CKRecord, Error>) -> Void) {
        let ckID = CKRecord.ID(recordName: recordID)
        publicDatabase.fetch(withRecordID: ckID) { [weak self] record, error in
            guard let self, let record else {
                DispatchQueue.main.async {
                    completion(.failure(error ?? NSError(domain: "CloudKit", code: -1)))
                }
                return
            }
            guard let currentUserID = self.currentUser?["userID"] as? String else {
                DispatchQueue.main.async {
                    completion(.failure(NSError(domain: "CloudKit", code: -1)))
                }
                return
            }

            let senderID = record["user1ID"] as? String ?? ""

            // Write the accepted record — minimal fields only
            let accepted = CKRecord(recordType: "Friendship")
            accepted["user1ID"] = currentUserID as CKRecordValue
            accepted["user2ID"] = senderID      as CKRecordValue
            accepted["status"]  = "accepted"    as CKRecordValue

            self.publicDatabase.save(accepted) { saved, saveError in
                if let saved {
                    ONELogger.success("Friend request accepted", category: .circle)
                    AppAnalytics.shared.track(.friendRequestAccepted)
                    DispatchQueue.main.async { completion(.success(saved)) }

                    // Also update the original pending record's status
                    record["status"] = "accepted" as CKRecordValue
                    self.publicDatabase.save(record) { _, _ in }
                } else {
                    DispatchQueue.main.async {
                        completion(.failure(saveError ?? NSError(domain: "CloudKit", code: -1)))
                    }
                }
            }
        }
    }

    // MARK: - Decline Friend Request

    func declineFriendRequest(recordID: String,
                              completion: @escaping (Result<Bool, Error>) -> Void) {
        let ckID = CKRecord.ID(recordName: recordID)
        publicDatabase.fetch(withRecordID: ckID) { [weak self] record, _ in
            guard let self else { DispatchQueue.main.async { completion(.success(true)) }; return }

            let senderID      = record?["user1ID"] as? String ?? ""
            let currentUserID = self.currentUser?["userID"] as? String ?? ""

            let declined = CKRecord(recordType: "Friendship")
            declined["user1ID"] = currentUserID as CKRecordValue
            declined["user2ID"] = senderID      as CKRecordValue
            declined["status"]  = "declined"    as CKRecordValue

            self.publicDatabase.save(declined) { _, _ in
                ONELogger.success("Friend request declined", category: .circle)
                DispatchQueue.main.async { completion(.success(true)) }
                if let record { self.publicDatabase.delete(withRecordID: record.recordID) { _, _ in } }
            }
        }
    }

    // MARK: - Remove Friend

    func removeFriend(friendUserID: String,
                      completion: @escaping (Result<Bool, Error>) -> Void) {
        guard let currentUserID = currentUser?["userID"] as? String else {
            completion(.failure(NSError(domain: "CloudKit", code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Current user not found"]))); return
        }

        let rec = CKRecord(recordType: "Friendship")
        rec["user1ID"] = currentUserID as CKRecordValue
        rec["user2ID"] = friendUserID  as CKRecordValue
        rec["status"]  = "removed"     as CKRecordValue

        publicDatabase.save(rec) { _, error in
            DispatchQueue.main.async {
                if let error {
                    ONELogger.error("Failed to remove friend", error: error, category: .circle)
                    completion(.failure(error))
                } else {
                    ONELogger.success("Friend removed", category: .circle)
                    completion(.success(true))
                }
            }
        }
    }

    // MARK: - Block User

    func blockUser(userID: String, completion: @escaping (Result<Bool, Error>) -> Void) {
        guard let currentUserID = currentUser?["userID"] as? String else {
            completion(.failure(NSError(domain: "CloudKit", code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Current user not found"]))); return
        }

        let rec = CKRecord(recordType: "Friendship")
        rec["user1ID"] = currentUserID as CKRecordValue
        rec["user2ID"] = userID        as CKRecordValue
        rec["status"]  = "blocked"     as CKRecordValue

        publicDatabase.save(rec) { _, error in
            DispatchQueue.main.async {
                if let error {
                    ONELogger.error("Failed to block user", error: error, category: .circle)
                    completion(.failure(error))
                } else {
                    ONELogger.success("User blocked", category: .circle)
                    completion(.success(true))
                }
            }
        }
    }

    // MARK: - Fetch Pending Incoming Requests

    func fetchPendingRequests(completion: @escaping (Result<[(request: CKRecord, sender: CKRecord)], Error>) -> Void) {
        guard let currentUserID = currentUser?["userID"] as? String else {
            completion(.failure(NSError(domain: "CloudKit", code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Current user not found"]))); return
        }

        fetchUserRelationships { [weak self] result in
            guard let self else { return }
            switch result {
            case .failure(let e):
                DispatchQueue.main.async { completion(.failure(e)) }
            case .success(let relationships):
                let pending = relationships.values.filter {
                    ($0["status"] as? String) == "pending" &&
                    ($0["user2ID"] as? String) == currentUserID
                }
                guard !pending.isEmpty else {
                    DispatchQueue.main.async { completion(.success([])) }; return
                }

                let senderIDs = pending.compactMap { $0["user1ID"] as? String }
                let query = CKQuery(recordType: "AppUser",
                                    predicate: NSPredicate(format: "userID IN %@", senderIDs))
                self.publicDatabase.fetch(withQuery: query, inZoneWith: nil,
                                          desiredKeys: nil,
                                          resultsLimit: CKQueryOperation.maximumResults) { userResult in
                    switch userResult {
                    case .failure(let e):
                        DispatchQueue.main.async { completion(.failure(e)) }
                    case .success(let (matches, _)):
                        var userMap: [String: CKRecord] = [:]
                        for u in matches.compactMap({ try? $0.1.get() }) {
                            if let uid = u["userID"] as? String { userMap[uid] = u }
                        }
                        var pairs: [(request: CKRecord, sender: CKRecord)] = []
                        for req in pending {
                            if let sid = req["user1ID"] as? String, let sender = userMap[sid] {
                                pairs.append((request: req, sender: sender))
                            }
                        }
                        pairs.sort { self.recordDate($0.request) > self.recordDate($1.request) }
                        DispatchQueue.main.async { completion(.success(pairs)) }
                    }
                }
            }
        }
    }

    // MARK: - Fetch Sent (Outgoing) Requests

    func fetchSentRequests(completion: @escaping (Result<[(request: CKRecord, receiver: CKRecord)], Error>) -> Void) {
        guard let currentUserID = currentUser?["userID"] as? String else {
            completion(.failure(NSError(domain: "CloudKit", code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Current user not found"]))); return
        }

        fetchUserRelationships { [weak self] result in
            guard let self else { return }
            switch result {
            case .failure(let e):
                DispatchQueue.main.async { completion(.failure(e)) }
            case .success(let relationships):
                let sent = relationships.values.filter {
                    ($0["status"] as? String) == "pending" &&
                    ($0["user1ID"] as? String) == currentUserID
                }
                guard !sent.isEmpty else {
                    DispatchQueue.main.async { completion(.success([])) }; return
                }

                let receiverIDs = sent.compactMap { $0["user2ID"] as? String }
                let query = CKQuery(recordType: "AppUser",
                                    predicate: NSPredicate(format: "userID IN %@", receiverIDs))
                self.publicDatabase.fetch(withQuery: query, inZoneWith: nil,
                                          desiredKeys: nil,
                                          resultsLimit: CKQueryOperation.maximumResults) { userResult in
                    switch userResult {
                    case .failure(let e):
                        DispatchQueue.main.async { completion(.failure(e)) }
                    case .success(let (matches, _)):
                        var userMap: [String: CKRecord] = [:]
                        for u in matches.compactMap({ try? $0.1.get() }) {
                            if let uid = u["userID"] as? String { userMap[uid] = u }
                        }
                        var pairs: [(request: CKRecord, receiver: CKRecord)] = []
                        for req in sent {
                            if let rid = req["user2ID"] as? String, let recv = userMap[rid] {
                                pairs.append((request: req, receiver: recv))
                            }
                        }
                        pairs.sort { self.recordDate($0.request) > self.recordDate($1.request) }
                        DispatchQueue.main.async { completion(.success(pairs)) }
                    }
                }
            }
        }
    }

    // MARK: - Fetch Pending Count

    func fetchPendingRequestCount(completion: @escaping (Int) -> Void) {
        guard let currentUserID = currentUser?["userID"] as? String else {
            completion(0); return
        }
        fetchUserRelationships { result in
            if case .success(let relationships) = result {
                let count = relationships.values.filter {
                    ($0["status"] as? String) == "pending" &&
                    ($0["user2ID"] as? String) == currentUserID
                }.count
                DispatchQueue.main.async { completion(count) }
            } else {
                DispatchQueue.main.async { completion(0) }
            }
        }
    }

    // MARK: - Fetch Accepted Friends

    func fetchFriends(completion: @escaping (Result<[CKRecord], Error>) -> Void) {
        fetchUserRelationships { result in
            switch result {
            case .success(let r):
                let friends = r.values.filter { ($0["status"] as? String) == "accepted" }
                DispatchQueue.main.async { completion(.success(Array(friends))) }
            case .failure(let e):
                DispatchQueue.main.async { completion(.failure(e)) }
            }
        }
    }

    // MARK: - Check Existing Relationship

    enum RelationshipStatus {
        case alreadyFriends
        case pendingSent
        case pendingReceived
        case none
        case blocked(byMe: Bool)
    }

    func checkExistingRelationship(with targetUserID: String,
                                   completion: @escaping (RelationshipStatus) -> Void) {
        guard let currentUserID = currentUser?["userID"] as? String else {
            completion(.none); return
        }
        fetchUserRelationships { result in
            guard case .success(let relationships) = result,
                  let record = relationships[targetUserID] else {
                DispatchQueue.main.async { completion(.none) }; return
            }

            let status = record["status"] as? String ?? ""
            let sender = record["user1ID"] as? String ?? ""

            DispatchQueue.main.async {
                switch status {
                case "blocked":  completion(.blocked(byMe: sender == currentUserID))
                case "accepted": completion(.alreadyFriends)
                case "pending":  completion(sender == currentUserID ? .pendingSent : .pendingReceived)
                default:         completion(.none)   // removed / declined / cancelled
                }
            }
        }
    }

    // MARK: - Private: Fetch Pending Request From Specific User

    private func fetchPendingRequestFrom(userID: String,
                                         completion: @escaping (Result<CKRecord, Error>) -> Void) {
        guard let currentUserID = currentUser?["userID"] as? String else {
            completion(.failure(NSError(domain: "CloudKit", code: -1))); return
        }

        let predicate = NSPredicate(format: "user1ID == %@ AND user2ID == %@ AND status == %@",
                                    userID, currentUserID, "pending")
        let query = CKQuery(recordType: "Friendship", predicate: predicate)

        publicDatabase.fetch(withQuery: query, inZoneWith: nil,
                             desiredKeys: nil, resultsLimit: 1) { result in
            switch result {
            case .success(let (matches, _)):
                if let record = matches.compactMap({ try? $0.1.get() }).first {
                    DispatchQueue.main.async { completion(.success(record)) }
                } else {
                    DispatchQueue.main.async {
                        completion(.failure(NSError(domain: "CloudKit", code: -1,
                            userInfo: [NSLocalizedDescriptionKey: "Pending request not found"])))
                    }
                }
            case .failure(let e):
                DispatchQueue.main.async { completion(.failure(e)) }
            }
        }
    }
}
