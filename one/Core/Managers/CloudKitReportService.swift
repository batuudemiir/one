//
//  CloudKitReportService.swift
//  one
//
//  v2.5 — Yorum / kullanıcı raporlama servisi. Apple Guideline 1.2:
//  "apps with UGC must provide a mechanism for users to report
//  objectionable content and abusive users."
//
//  Record type: `ContentReport`
//    - reporterUserID : String   (şikâyet eden)
//    - targetType     : String   ("comment" | "user" | "share")
//    - targetID       : String   (yorum.id / userID / shareRecordName)
//    - reason         : String   (enum rawValue)
//    - note           : String?  (opsiyonel serbest metin)
//    - createdAt      : Date
//    - status         : String   ("pending" | "reviewed" | "dismissed")
//
//  Yorum raporlarında ek olarak `Comment.reportCount` artırılır
//  (`incrementCommentReportCount` — CloudKitCommentService'te).
//  3+ rapora ulaşan yorum otomatik hidden olur.
//

import Foundation
import CloudKit
import Combine

enum ReportReason: String, CaseIterable, Codable, Identifiable {
    case spam
    case harassment
    case hateSpeech        = "hate_speech"
    case sexualContent     = "sexual_content"
    case violence
    case selfHarm          = "self_harm"
    case impersonation
    case other

    var id: String { rawValue }

    var localized: String {
        switch self {
        case .spam:           return "Spam"
        case .harassment:     return "Taciz / zorbalık"
        case .hateSpeech:     return "Nefret söylemi"
        case .sexualContent:  return "Cinsel içerik"
        case .violence:       return "Şiddet"
        case .selfHarm:       return "Kendine zarar verme"
        case .impersonation:  return "Kimlik taklidi"
        case .other:          return "Diğer"
        }
    }
}

enum ReportTargetType: String {
    case comment
    case user
    case share
}

enum ReportServiceError: LocalizedError {
    case noCurrentUser
    case duplicate
    case underlying(Error)

    var errorDescription: String? {
        switch self {
        case .noCurrentUser:    return "Kullanıcı bilgisi yüklenmedi."
        case .duplicate:        return "Bu içeriği zaten raporladın."
        case .underlying(let e): return e.localizedDescription
        }
    }
}

// MARK: - Service

extension CloudKitManager {

    private static let reportRecordType = "ContentReport"

    private enum ReportField {
        static let reporter   = "reporterUserID"
        static let targetType = "targetType"
        static let targetID   = "targetID"
        static let reason     = "reason"
        static let note       = "note"
        static let createdAt  = "createdAt"
        static let status     = "status"
    }

    /// Deterministic dedup: aynı reporter + target ikilisi tek kayıt.
    private static func reportRecordName(
        reporter: String, targetType: ReportTargetType, targetID: String
    ) -> String {
        "report_\(targetType.rawValue)_\(reporter.prefix(16))_\(targetID.prefix(40))"
    }

    /// Rapor kaydı oluşturur. Yorum raporuysa `Comment.reportCount`'u da artırır
    /// (3+ ulaşırsa auto-hidden). Aynı reporter aynı hedefi tekrar raporlarsa reason/note overwrite edilir.
    func submitReport(
        targetType: ReportTargetType,
        targetID: String,
        reason: ReportReason,
        note: String? = nil,
        completion: @escaping (Result<Void, ReportServiceError>) -> Void
    ) {
        guard let currentUserID = currentUser?["userID"] as? String else {
            completion(.failure(.noCurrentUser)); return
        }

        let recordID = CKRecord.ID(
            recordName: Self.reportRecordName(
                reporter: currentUserID,
                targetType: targetType,
                targetID: targetID
            )
        )
        let record = CKRecord(recordType: Self.reportRecordType, recordID: recordID)
        record[ReportField.reporter]   = currentUserID as CKRecordValue
        record[ReportField.targetType] = targetType.rawValue as CKRecordValue
        record[ReportField.targetID]   = targetID as CKRecordValue
        record[ReportField.reason]     = reason.rawValue as CKRecordValue
        if let note, !note.trimmingCharacters(in: .whitespaces).isEmpty {
            record[ReportField.note]   = note as CKRecordValue
        }
        record[ReportField.createdAt] = Date() as CKRecordValue
        record[ReportField.status]    = "pending" as CKRecordValue

        let op = CKModifyRecordsOperation(recordsToSave: [record], recordIDsToDelete: nil)
        op.savePolicy = .allKeys
        op.modifyRecordsResultBlock = { [weak self] result in
            switch result {
            case .success:
                ONELogger.success("Report submitted: \(targetType.rawValue)/\(targetID) [\(reason.rawValue)]", category: .cloudkit)

                // Yorum raporu → Comment.reportCount++
                if targetType == .comment {
                    self?.incrementCommentReportCount(commentID: targetID) { _ in
                        // Hata olsa bile report kaydı oluştu — kullanıcıya success dön
                        DispatchQueue.main.async { completion(.success(())) }
                    }
                } else {
                    DispatchQueue.main.async { completion(.success(())) }
                }
            case .failure(let err):
                ONELogger.error("submitReport failed", error: err, category: .cloudkit)
                DispatchQueue.main.async { completion(.failure(.underlying(err))) }
            }
        }
        publicDatabase.add(op)
    }
}
