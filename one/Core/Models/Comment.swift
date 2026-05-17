//
//  Comment.swift
//  one
//
//  v2.5 ile eklenen yorum primitifi. CloudKit'te `Comment` record type'ına
//  mapping'i içerir. Emoji reaction'ların halefi — 280 karakter düz metin.
//

import Foundation
import CloudKit

enum CommentModerationStatus: String, Codable {
    case active
    case hidden   // reportCount ≥ 3 otomatik
    case removed  // paylaşım sahibi veya yazar tarafından silindi
}

struct Comment: Identifiable, Equatable, Hashable {
    static let maxBodyLength: Int = 280
    static let editWindow: TimeInterval = 5 * 60   // 5 dakika

    let id: String                // CKRecord.recordID.recordName
    let shareRecordName: String
    let shareOwnerID: String
    let authorUserID: String
    var body: String
    let createdAt: Date
    var editedAt: Date?
    let parentCommentID: String?  // v2.5.1 reply için placeholder
    var moderationStatus: CommentModerationStatus
    var reportCount: Int

    // Resolved client-side (join ile)
    var authorDisplayName: String?
    var authorAvatarColorHex: String?
    var authorProfilePhotoFileURL: URL?  // AppUser.profilePhoto CKAsset → fileURL

    var isEdited: Bool { editedAt != nil }

    /// Yazar, oluşturduktan sonra 5 dakika içinde düzenleyebilir.
    func canEdit(by userID: String, now: Date = Date()) -> Bool {
        guard authorUserID == userID else { return false }
        return now.timeIntervalSince(createdAt) <= Self.editWindow
    }

    /// Yazar her zaman silebilir; paylaşım sahibi başkasının yorumunu silebilir.
    func canDelete(by userID: String) -> Bool {
        userID == authorUserID || userID == shareOwnerID
    }
}

// MARK: - CKRecord bridging

extension Comment {

    static let recordType: String = "Comment"

    enum Field {
        static let shareRecordName   = "shareRecordName"
        static let shareOwnerID      = "shareOwnerID"
        static let authorUserID      = "authorUserID"
        static let body              = "body"
        static let createdAt         = "createdAt"
        static let editedAt          = "editedAt"
        static let parentCommentID   = "parentCommentID"
        static let moderationStatus  = "moderationStatus"
        static let reportCount       = "reportCount"
    }

    init?(record: CKRecord) {
        guard record.recordType == Self.recordType,
              let shareRec  = record[Field.shareRecordName]  as? String,
              let ownerID   = record[Field.shareOwnerID]     as? String,
              let authorID  = record[Field.authorUserID]     as? String,
              let body      = record[Field.body]             as? String,
              let createdAt = record[Field.createdAt]        as? Date
        else { return nil }

        self.id = record.recordID.recordName
        self.shareRecordName = shareRec
        self.shareOwnerID = ownerID
        self.authorUserID = authorID
        self.body = String(body.prefix(Self.maxBodyLength))
        self.createdAt = createdAt
        self.editedAt = record[Field.editedAt] as? Date
        self.parentCommentID = record[Field.parentCommentID] as? String
        let statusRaw = record[Field.moderationStatus] as? String ?? "active"
        self.moderationStatus = CommentModerationStatus(rawValue: statusRaw) ?? .active
        self.reportCount = (record[Field.reportCount] as? Int64).map(Int.init) ?? 0
    }

    /// Create için new CKRecord döndürür. Record name deterministic:
    /// `comment_<shareRecordName>_<authorUserID>_<uuid8>` — dedup kolaylığı.
    func makeRecord() -> CKRecord {
        let recordID = CKRecord.ID(recordName: id)
        let record = CKRecord(recordType: Self.recordType, recordID: recordID)
        record[Field.shareRecordName]  = shareRecordName as CKRecordValue
        record[Field.shareOwnerID]     = shareOwnerID as CKRecordValue
        record[Field.authorUserID]     = authorUserID as CKRecordValue
        record[Field.body]             = body as CKRecordValue
        record[Field.createdAt]        = createdAt as CKRecordValue
        if let editedAt { record[Field.editedAt] = editedAt as CKRecordValue }
        if let parentCommentID { record[Field.parentCommentID] = parentCommentID as CKRecordValue }
        record[Field.moderationStatus] = moderationStatus.rawValue as CKRecordValue
        record[Field.reportCount]      = Int64(reportCount) as CKRecordValue
        return record
    }

    static func newID(shareRecordName: String, authorUserID: String) -> String {
        let short = UUID().uuidString.prefix(8)
        let safeShare = shareRecordName.prefix(24)
        return "comment_\(safeShare)_\(authorUserID.prefix(16))_\(short)"
    }
}
