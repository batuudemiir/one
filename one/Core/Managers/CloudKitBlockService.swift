//
//  CloudKitBlockService.swift
//  one
//
//  v2.5 — Kullanıcı engelleme servisi. Apple App Store Guideline 1.2
//  gereği UGC içeren her uygulama `block` + `report` sunmak zorunda.
//
//  Record type: `UserBlock`
//    - blockerUserID : String   (engelleyen — indexed)
//    - blockedUserID : String   (engellenen — indexed)
//    - createdAt     : Date
//    - reason        : String?  (opsiyonel serbest metin)
//
//  Semantik:
//  - Engelleme **çift yönlü etki** yapar: her iki taraftan biri diğerini
//    engellerse yorum/profil/push karşılıklı gizlenir.
//  - Kayıt tek yönlü tutulur (blocker → blocked); bidirectional check için
//    `hasBlockRelation(with:)` kullanılır.
//  - Dedup deterministic record name ile sağlanır:
//    `block_<blocker16>_<blocked16>`.
//

import Foundation
import CloudKit
import Combine

enum BlockServiceError: LocalizedError {
    case noCurrentUser
    case cannotBlockSelf
    case notFound
    case underlying(Error)

    var errorDescription: String? {
        switch self {
        case .noCurrentUser:    return "Kullanıcı bilgisi yüklenmedi."
        case .cannotBlockSelf:  return "Kendini engelleyemezsin."
        case .notFound:         return "Engelleme kaydı bulunamadı."
        case .underlying(let e): return e.localizedDescription
        }
    }
}

// MARK: - Service

extension CloudKitManager {

    // MARK: Record helpers

    private static let blockRecordType = "UserBlock"

    private enum BlockField {
        static let blocker   = "blockerUserID"
        static let blocked   = "blockedUserID"
        static let createdAt = "createdAt"
        static let reason    = "reason"
    }

    private static func blockRecordName(blocker: String, blocked: String) -> String {
        "block_\(blocker.prefix(16))_\(blocked.prefix(16))"
    }

    // MARK: Cache (my outgoing blocks + incoming blocks)

    /// UserDefaults-backed cache. Profile/comment render'ında senkron erişim için.
    /// `fetchMyBlockRelations(force:)` ile doldurulur.
    private static let blockCacheTTL: TimeInterval = 5 * 60
    private static var cachedOutgoingBlocks: Set<String> = []
    private static var cachedIncomingBlocks: Set<String> = []
    private static var cachedBlockTimestamp: Date? = nil

    var myOutgoingBlockedIDs: Set<String> { Self.cachedOutgoingBlocks }
    var myIncomingBlockedIDs: Set<String> { Self.cachedIncomingBlocks }

    /// Senkron — cache üzerinden. UI filter'ları için.
    func isBlockedByMe(_ userID: String) -> Bool {
        myOutgoingBlockedIDs.contains(userID)
    }

    func isBlockedByThem(_ userID: String) -> Bool {
        myIncomingBlockedIDs.contains(userID)
    }

    /// Herhangi bir yönde engel var mı — yorum/profil erişim kapısı.
    func hasBlockRelation(with userID: String) -> Bool {
        isBlockedByMe(userID) || isBlockedByThem(userID)
    }

    private var isBlockCacheFresh: Bool {
        guard let ts = Self.cachedBlockTimestamp else { return false }
        return Date().timeIntervalSince(ts) < Self.blockCacheTTL
    }

    // MARK: Block / Unblock

    /// Bir kullanıcıyı engeller. Zaten engelliyse no-op (.success(false)).
    func blockUser(
        userID blockedID: String,
        reason: String? = nil,
        completion: @escaping (Result<Bool, BlockServiceError>) -> Void
    ) {
        guard let currentUserID = currentUser?["userID"] as? String else {
            completion(.failure(.noCurrentUser)); return
        }
        guard currentUserID != blockedID else {
            completion(.failure(.cannotBlockSelf)); return
        }

        let recordID = CKRecord.ID(recordName: Self.blockRecordName(blocker: currentUserID, blocked: blockedID))
        let record = CKRecord(recordType: Self.blockRecordType, recordID: recordID)
        record[BlockField.blocker]   = currentUserID as CKRecordValue
        record[BlockField.blocked]   = blockedID as CKRecordValue
        record[BlockField.createdAt] = Date() as CKRecordValue
        if let reason, !reason.isEmpty {
            record[BlockField.reason] = reason as CKRecordValue
        }

        // `CKModifyRecordsOperation` ile savePolicy=.allKeys — varsa override eder,
        // yoksa oluşturur (true dedup).
        let op = CKModifyRecordsOperation(recordsToSave: [record], recordIDsToDelete: nil)
        op.savePolicy = .allKeys
        op.modifyRecordsResultBlock = { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    ONELogger.success("Blocked user: \(blockedID)", category: .cloudkit)
                    // Cache güncelle
                    Self.cachedOutgoingBlocks.insert(blockedID)
                    // İlişkili circle cache'leri invalide et
                    self?.invalidateCircleCache()
                    self?.invalidateFriendCache()
                    completion(.success(true))
                case .failure(let err):
                    ONELogger.error("blockUser failed", error: err, category: .cloudkit)
                    completion(.failure(.underlying(err)))
                }
            }
        }
        publicDatabase.add(op)
    }

    /// Engeli kaldırır. Kayıt zaten yoksa sessizce .success(false) döner.
    func unblockUser(
        userID blockedID: String,
        completion: @escaping (Result<Bool, BlockServiceError>) -> Void
    ) {
        guard let currentUserID = currentUser?["userID"] as? String else {
            completion(.failure(.noCurrentUser)); return
        }

        let recordID = CKRecord.ID(
            recordName: Self.blockRecordName(blocker: currentUserID, blocked: blockedID)
        )
        publicDatabase.delete(withRecordID: recordID) { [weak self] _, error in
            DispatchQueue.main.async {
                if let ck = error as? CKError, ck.code == .unknownItem {
                    // Zaten yok — idempotent
                    completion(.success(false))
                    return
                }
                if let error {
                    ONELogger.error("unblockUser failed", error: error, category: .cloudkit)
                    completion(.failure(.underlying(error)))
                    return
                }
                Self.cachedOutgoingBlocks.remove(blockedID)
                self?.invalidateCircleCache()
                self?.invalidateFriendCache()
                ONELogger.success("Unblocked user: \(blockedID)", category: .cloudkit)
                completion(.success(true))
            }
        }
    }

    // MARK: Fetch block relations (cache refresh)

    /// Bana ait tüm engelleme ilişkilerini (outgoing + incoming) çekip cache'ler.
    /// Uygulama açılışında ve PublicProfileView öncesi çağır.
    func fetchMyBlockRelations(
        force: Bool = false,
        completion: ((Result<(outgoing: Set<String>, incoming: Set<String>), BlockServiceError>) -> Void)? = nil
    ) {
        if !force, isBlockCacheFresh {
            completion?(.success((myOutgoingBlockedIDs, myIncomingBlockedIDs)))
            return
        }

        guard let currentUserID = currentUser?["userID"] as? String else {
            completion?(.failure(.noCurrentUser)); return
        }

        let group = DispatchGroup()
        var outgoing: Set<String> = []
        var incoming: Set<String> = []
        var firstError: Error?

        // Outgoing: blockerUserID == me
        group.enter()
        let outQuery = CKQuery(
            recordType: Self.blockRecordType,
            predicate: NSPredicate(format: "\(BlockField.blocker) == %@", currentUserID)
        )
        publicDatabase.fetch(
            withQuery: outQuery, inZoneWith: nil,
            desiredKeys: [BlockField.blocked],
            resultsLimit: CKQueryOperation.maximumResults
        ) { result in
            switch result {
            case .success(let (matches, _)):
                for rec in matches.compactMap({ try? $0.1.get() }) {
                    if let uid = rec[BlockField.blocked] as? String { outgoing.insert(uid) }
                }
            case .failure(let err):
                if let ck = err as? CKError,
                   ck.code == .invalidArguments || ck.code == .unknownItem {
                    // Schema yok — boş bırak
                } else {
                    firstError = firstError ?? err
                }
            }
            group.leave()
        }

        // Incoming: blockedUserID == me
        group.enter()
        let inQuery = CKQuery(
            recordType: Self.blockRecordType,
            predicate: NSPredicate(format: "\(BlockField.blocked) == %@", currentUserID)
        )
        publicDatabase.fetch(
            withQuery: inQuery, inZoneWith: nil,
            desiredKeys: [BlockField.blocker],
            resultsLimit: CKQueryOperation.maximumResults
        ) { result in
            switch result {
            case .success(let (matches, _)):
                for rec in matches.compactMap({ try? $0.1.get() }) {
                    if let uid = rec[BlockField.blocker] as? String { incoming.insert(uid) }
                }
            case .failure(let err):
                if let ck = err as? CKError,
                   ck.code == .invalidArguments || ck.code == .unknownItem {
                    // Schema yok
                } else {
                    firstError = firstError ?? err
                }
            }
            group.leave()
        }

        group.notify(queue: .main) {
            if let err = firstError {
                completion?(.failure(.underlying(err)))
                return
            }
            Self.cachedOutgoingBlocks = outgoing
            Self.cachedIncomingBlocks = incoming
            Self.cachedBlockTimestamp = Date()
            ONELogger.info("Block cache refreshed: out=\(outgoing.count) in=\(incoming.count)", category: .cloudkit)
            completion?(.success((outgoing, incoming)))
        }
    }

    /// Oturum kapanışında çağır — cihazda iz kalmasın.
    func clearBlockCache() {
        Self.cachedOutgoingBlocks = []
        Self.cachedIncomingBlocks = []
        Self.cachedBlockTimestamp = nil
    }
}
