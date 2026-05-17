//
//  CloudKitCommentService.swift
//  one
//
//  v2.5 — Yorum CRUD servisi. `Comment` record type'ına karşı
//  create / fetch / edit / delete + author (AppUser) join işlemleri.
//  Subscription kaydı `CloudKitNotificationService`a bırakıldı;
//  burası sadece veri katmanıdır.
//

import Foundation
import CloudKit
import Combine

// MARK: - Errors

enum CommentServiceError: LocalizedError {
    case noCurrentUser
    case bodyEmpty
    case bodyTooLong
    case editWindowExpired
    case notAuthorized
    case blocked          // karşı taraf beni engellemiş / ben onu engellemişim
    case rateLimited      // dakika içinde çok fazla yorum
    case notFound
    case underlying(Error)

    var errorDescription: String? {
        switch self {
        case .noCurrentUser:     return "Kullanıcı bilgisi yüklenmedi."
        case .bodyEmpty:         return "Yorum boş olamaz."
        case .bodyTooLong:       return "Yorum \(Comment.maxBodyLength) karakterden uzun olamaz."
        case .editWindowExpired: return "Düzenleme süresi (5 dk) doldu."
        case .notAuthorized:     return "Bu işlemi yapma yetkin yok."
        case .blocked:           return "Bu kullanıcıyla etkileşim kısıtlı."
        case .rateLimited:       return "Çok hızlı yorum gönderiyorsun, biraz bekle."
        case .notFound:          return "Yorum bulunamadı."
        case .underlying(let e): return e.localizedDescription
        }
    }
}

// MARK: - Service (extension on CloudKitManager)

extension CloudKitManager {

    // MARK: Create

    /// Yeni yorum kaydı oluşturur. Body trim + length + rate-limit kontrolünü çağıran yapmalı.
    /// Buradaki guard'lar son savunma hattı — offline/edge case için.
    func createComment(
        body rawBody: String,
        shareRecordName: String,
        shareOwnerID: String,
        parentCommentID: String? = nil,
        completion: @escaping (Result<Comment, CommentServiceError>) -> Void
    ) {
        let body = rawBody.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !body.isEmpty else { completion(.failure(.bodyEmpty)); return }
        guard body.count <= Comment.maxBodyLength else { completion(.failure(.bodyTooLong)); return }

        guard let currentUserID = currentUser?["userID"] as? String else {
            completion(.failure(.noCurrentUser)); return
        }

        let id = Comment.newID(shareRecordName: shareRecordName, authorUserID: currentUserID)
        let now = Date()
        // Profil fotoğrafı için UserProfileStore'u öncelikli kullan — store her zaman
        // profil sekmesiyle senkron tutulur (CloudKitManager.currentUser didSet).
        // Stale CKAsset.fileURL yerine store'daki taze URL kullanılır.
        let cachedProfile = UserProfileStore.shared.snapshot(for: currentUserID)
        let myPhotoURL: URL? = cachedProfile?.profilePhotoFileURL
            ?? (currentUser?["profilePhoto"] as? CKAsset)?.fileURL
        let draft = Comment(
            id: id,
            shareRecordName: shareRecordName,
            shareOwnerID: shareOwnerID,
            authorUserID: currentUserID,
            body: body,
            createdAt: now,
            editedAt: nil,
            parentCommentID: parentCommentID,
            moderationStatus: .active,
            reportCount: 0,
            authorDisplayName: cachedProfile?.displayName ?? currentUser?["displayName"] as? String,
            authorAvatarColorHex: cachedProfile?.avatarColorHex ?? currentUser?["avatarColor"] as? String,
            authorProfilePhotoFileURL: myPhotoURL
        )
        let record = draft.makeRecord()

        publicDatabase.save(record) { saved, error in
            DispatchQueue.main.async {
                if let error {
                    if let ck = error as? CKError,
                       ck.code == .invalidArguments || ck.code == .unknownItem {
                        ONELogger.error(
                            "createComment: Comment schema CloudKit production'a deploy edilmemiş. CloudKit Dashboard → Deploy Schema Changes.",
                            error: error, category: .cloudkit
                        )
                    } else {
                        ONELogger.error("createComment failed: \(error.localizedDescription)", error: error, category: .cloudkit)
                    }
                    completion(.failure(.underlying(error)))
                    return
                }
                guard let saved, let model = Comment(record: saved) else {
                    completion(.failure(.notFound))
                    return
                }
                var out = model
                out.authorDisplayName = draft.authorDisplayName
                out.authorAvatarColorHex = draft.authorAvatarColorHex
                out.authorProfilePhotoFileURL = draft.authorProfilePhotoFileURL
                ONELogger.success("Comment saved: \(id)", category: .cloudkit)
                completion(.success(out))
            }
        }
    }

    // MARK: Fetch

    /// Belirli bir paylaşımın tüm aktif yorumlarını, yazar displayName/avatarColor ile birlikte döndürür.
    /// Sıralama client-side yapılır — `createdAt` field'ı üzerinden artan.
    /// Moderasyon filtrelemesi client-side; compound predicate index bağımlılığını kaldırır.
    ///
    /// Not: Sortable CKQuery descriptor (örn. `creationDate`) production CloudKit
    /// schema'sında index'lenmemişse `invalidArguments` ile fail olur ve servis sessizce
    /// boş liste döndürürdü → "2 yorum" rozeti dolu, thread boş hatası.
    /// Sort'u client-side yaparak server-side index gereksinimini ortadan kaldırıyoruz.
    func fetchComments(
        shareRecordName: String,
        limit: Int = 200,
        completion: @escaping (Result<[Comment], CommentServiceError>) -> Void
    ) {
        // Tek alan predicate: sadece `shareRecordName` queryable olması yeterli.
        let predicate = NSPredicate(format: "shareRecordName == %@", shareRecordName)
        let query = CKQuery(recordType: Comment.recordType, predicate: predicate)
        // sortDescriptors set ETMİYORUZ — herhangi bir field için index varsayımı
        // production fetch'i kırabilir. Client-side `createdAt` ile sıralıyoruz.

        publicDatabase.fetch(
            withQuery: query, inZoneWith: nil,
            desiredKeys: nil, resultsLimit: limit
        ) { [weak self] result in
            guard let self else { completion(.success([])); return }

            switch result {
            case .failure(let err):
                // Schema henüz oluşturulmamışsa sessizce boş dön
                if let ck = err as? CKError,
                   ck.code == .invalidArguments || ck.code == .unknownItem {
                    ONELogger.info("Comment schema CloudKit'te henüz yok — boş liste.", category: .cloudkit)
                    DispatchQueue.main.async { completion(.success([])) }
                    return
                }
                ONELogger.error("fetchComments failed: \(err.localizedDescription)", error: err, category: .cloudkit)
                DispatchQueue.main.async { completion(.failure(.underlying(err))) }

            case .success(let (matches, _)):
                let records = matches.compactMap { try? $0.1.get() }
                // moderationStatus: client-side filtre — active olmayanları düşür
                // Sıralama: createdAt artan — en eski yorum üstte, en yeni altta.
                let comments = records
                    .compactMap { Comment(record: $0) }
                    .filter { $0.moderationStatus == .active }
                    .sorted { $0.createdAt < $1.createdAt }
                guard !comments.isEmpty else {
                    DispatchQueue.main.async { completion(.success([])) }
                    return
                }
                self.attachAuthorInfo(to: comments) { enriched in
                    DispatchQueue.main.async { completion(.success(enriched)) }
                }
            }
        }
    }

    /// Author displayName + avatarColor + profilePhoto alanlarını AppUser'dan çekip yorumlara iliştirir.
    private func attachAuthorInfo(
        to comments: [Comment],
        completion: @escaping ([Comment]) -> Void
    ) {
        let uniqueIDs = Array(Set(comments.map { $0.authorUserID }))
        guard !uniqueIDs.isEmpty else { completion(comments); return }

        let userQuery = CKQuery(
            recordType: "AppUser",
            predicate: NSPredicate(format: "userID IN %@", uniqueIDs)
        )
        publicDatabase.fetch(
            withQuery: userQuery, inZoneWith: nil,
            desiredKeys: ["userID", "displayName", "avatarColor", "profilePhoto"],
            resultsLimit: max(uniqueIDs.count, 1)
        ) { result in
            var nameMap: [String: String] = [:]
            var colorMap: [String: String] = [:]
            var photoMap: [String: URL] = [:]
            if case .success(let (matches, _)) = result {
                for rec in matches.compactMap({ try? $0.1.get() }) {
                    guard let uid = rec["userID"] as? String else { continue }
                    if let n = rec["displayName"] as? String { nameMap[uid] = n }
                    if let c = rec["avatarColor"] as? String { colorMap[uid] = c }
                    if let asset = rec["profilePhoto"] as? CKAsset, let url = asset.fileURL {
                        photoMap[uid] = url
                    }
                }
            }
            let enriched = comments.map { c -> Comment in
                var copy = c
                copy.authorDisplayName = nameMap[c.authorUserID] ?? copy.authorDisplayName
                copy.authorAvatarColorHex = colorMap[c.authorUserID] ?? copy.authorAvatarColorHex
                copy.authorProfilePhotoFileURL = photoMap[c.authorUserID] ?? copy.authorProfilePhotoFileURL
                return copy
            }
            completion(enriched)
        }
    }

    // MARK: Edit

    /// Yazar 5 dakika içinde yorumunu düzenleyebilir. Window dışındaysa `editWindowExpired` döner.
    func editComment(
        commentID: String,
        newBody rawBody: String,
        completion: @escaping (Result<Comment, CommentServiceError>) -> Void
    ) {
        let body = rawBody.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !body.isEmpty else { completion(.failure(.bodyEmpty)); return }
        guard body.count <= Comment.maxBodyLength else { completion(.failure(.bodyTooLong)); return }
        guard let currentUserID = currentUser?["userID"] as? String else {
            completion(.failure(.noCurrentUser)); return
        }

        let recordID = CKRecord.ID(recordName: commentID)
        publicDatabase.fetch(withRecordID: recordID) { [weak self] record, error in
            guard let self else { return }
            if let error {
                DispatchQueue.main.async { completion(.failure(.underlying(error))) }
                return
            }
            guard let record, let existing = Comment(record: record) else {
                DispatchQueue.main.async { completion(.failure(.notFound)) }
                return
            }
            guard existing.canEdit(by: currentUserID) else {
                DispatchQueue.main.async {
                    completion(.failure(existing.authorUserID == currentUserID
                                        ? .editWindowExpired : .notAuthorized))
                }
                return
            }

            record[Comment.Field.body] = body as CKRecordValue
            record[Comment.Field.editedAt] = Date() as CKRecordValue

            self.publicDatabase.save(record) { saved, err in
                DispatchQueue.main.async {
                    if let err {
                        completion(.failure(.underlying(err)))
                        return
                    }
                    guard let saved, var updated = Comment(record: saved) else {
                        completion(.failure(.notFound))
                        return
                    }
                    updated.authorDisplayName = existing.authorDisplayName
                        ?? (self.currentUser?["displayName"] as? String)
                    updated.authorAvatarColorHex = existing.authorAvatarColorHex
                        ?? (self.currentUser?["avatarColor"] as? String)
                    updated.authorProfilePhotoFileURL = existing.authorProfilePhotoFileURL
                        ?? (self.currentUser?["profilePhoto"] as? CKAsset)?.fileURL
                    ONELogger.success("Comment edited: \(commentID)", category: .cloudkit)
                    completion(.success(updated))
                }
            }
        }
    }

    // MARK: Delete

    /// Yazar her zaman silebilir; paylaşım sahibi başkasının yorumunu silebilir.
    /// Soft-delete değil, CloudKit record'u tamamen kaldırılır — UI tarafında anında kaybolur.
    func deleteComment(
        commentID: String,
        completion: @escaping (Result<Void, CommentServiceError>) -> Void
    ) {
        guard let currentUserID = currentUser?["userID"] as? String else {
            completion(.failure(.noCurrentUser)); return
        }

        let recordID = CKRecord.ID(recordName: commentID)
        publicDatabase.fetch(withRecordID: recordID) { [weak self] record, error in
            guard let self else { return }
            if let error {
                DispatchQueue.main.async { completion(.failure(.underlying(error))) }
                return
            }
            guard let record, let existing = Comment(record: record) else {
                DispatchQueue.main.async { completion(.failure(.notFound)) }
                return
            }
            guard existing.canDelete(by: currentUserID) else {
                DispatchQueue.main.async { completion(.failure(.notAuthorized)) }
                return
            }

            self.publicDatabase.delete(withRecordID: recordID) { _, err in
                DispatchQueue.main.async {
                    if let err {
                        completion(.failure(.underlying(err)))
                    } else {
                        ONELogger.success("Comment deleted: \(commentID)", category: .cloudkit)
                        completion(.success(()))
                    }
                }
            }
        }
    }

    // MARK: Comment Count

    /// Bir paylaşıma ait aktif yorum sayısını döndürür.
    /// Sadece `shareRecordName` alanı istenir — minimum network yükü.
    func fetchCommentCount(shareRecordName: String, completion: @escaping (Int) -> Void) {
        if let cached = commentCountCache[shareRecordName] {
            completion(cached)
            return
        }
        let predicate = NSPredicate(format: "shareRecordName == %@", shareRecordName)
        let query = CKQuery(recordType: Comment.recordType, predicate: predicate)
        publicDatabase.fetch(
            withQuery: query, inZoneWith: nil,
            desiredKeys: ["shareRecordName", "moderationStatus"],
            resultsLimit: 100
        ) { [weak self] result in
            switch result {
            case .success(let (matches, _)):
                let count = matches.filter { _, r in
                    guard case .success(let rec) = r else { return false }
                    let status = rec["moderationStatus"] as? String ?? "active"
                    return status == "active"
                }.count
                DispatchQueue.main.async {
                    self?.commentCountCache[shareRecordName] = count
                    completion(count)
                }
            case .failure:
                DispatchQueue.main.async { completion(0) }
            }
        }
    }

    // MARK: Moderation helpers

    /// `reportCount`'u artırır; 3'e ulaşırsa `moderationStatus` otomatik `.hidden` yapılır.
    /// `CloudKitReportService` bu helper'ı çağırır.
    func incrementCommentReportCount(
        commentID: String,
        completion: @escaping (Result<Int, CommentServiceError>) -> Void
    ) {
        let recordID = CKRecord.ID(recordName: commentID)
        publicDatabase.fetch(withRecordID: recordID) { [weak self] record, error in
            guard let self else { return }
            if let error {
                DispatchQueue.main.async { completion(.failure(.underlying(error))) }
                return
            }
            guard let record else {
                DispatchQueue.main.async { completion(.failure(.notFound)) }
                return
            }

            let current = (record[Comment.Field.reportCount] as? Int64).map(Int.init) ?? 0
            let next = current + 1
            record[Comment.Field.reportCount] = Int64(next) as CKRecordValue
            if next >= 3 {
                record[Comment.Field.moderationStatus] = CommentModerationStatus.hidden.rawValue as CKRecordValue
            }

            self.publicDatabase.save(record) { _, err in
                DispatchQueue.main.async {
                    if let err {
                        completion(.failure(.underlying(err)))
                    } else {
                        if next >= 3 {
                            ONELogger.info("Comment auto-hidden (\(next) reports): \(commentID)", category: .cloudkit)
                        }
                        completion(.success(next))
                    }
                }
            }
        }
    }
}
