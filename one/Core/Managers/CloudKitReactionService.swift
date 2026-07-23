//
//  CloudKitReactionService.swift
//  one
//
//  Prototipin efemer "sessiz cevaplaşma" veri katmanı. `DailyReaction`
//  (EmojiReaction kayıt tipi) üstünde gönder / getir. Kalıcı Comment
//  servisinin yerini alıyor — karşılıklar gün bitince istemci tarafında
//  filtrelenir (isToday), sayaç yok, yalnız sahibe gösterilir.
//

import Foundation
import CloudKit

enum ReactionServiceError: LocalizedError {
    case noCurrentUser
    case replyEmpty
    case replyTooLong
    case underlying(Error)

    var errorDescription: String? {
        switch self {
        case .noCurrentUser: return "Kullanıcı bilgisi yüklenmedi."
        case .replyEmpty:    return "Yanıt boş olamaz."
        case .replyTooLong:  return "Yanıt \(DailyReaction.maxReplyLength) karakterden uzun olamaz."
        case .underlying(let e): return e.localizedDescription
        }
    }
}

extension CloudKitManager {

    // MARK: - Gönder

    /// Bir paylaşıma karşılık gönderir.
    ///
    /// Tepkiler (`.yanindayim/.bende/.iyiki/.color`) aynı gönderen için
    /// yerinde güncellenir — kişi tek bir tepki taşır. Yanıtlar (`.reply`)
    /// her seferinde yeni kayıt: thread birikir.
    func sendDailyReaction(
        shareRecordName: String,
        shareOwnerID: String,
        kind: DailyReaction.Kind,
        text: String? = nil,
        colorHex: String? = nil,
        toUserID: String? = nil,
        completion: @escaping (Result<Void, ReactionServiceError>) -> Void
    ) {
        guard let currentUserID = currentUser?["userID"] as? String else {
            completion(.failure(.noCurrentUser)); return
        }

        var replyText: String? = nil
        if kind == .reply {
            let trimmed = (text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { completion(.failure(.replyEmpty)); return }
            guard trimmed.count <= DailyReaction.maxReplyLength else {
                completion(.failure(.replyTooLong)); return
            }
            replyText = trimmed
        }

        let write: (CKRecord) -> Void = { [weak self] record in
            guard let self else { return }
            record["shareRecordName"] = shareRecordName as CKRecordValue
            record["shareOwnerID"]    = shareOwnerID as CKRecordValue
            record["senderUserID"]    = currentUserID as CKRecordValue
            record["kind"]            = kind.rawValue as CKRecordValue
            record["date"]            = Date() as CKRecordValue
            if let replyText { record["text"] = replyText as CKRecordValue }
            if let colorHex  { record["colorHex"] = colorHex as CKRecordValue }
            if let toUserID  { record["toUserID"] = toUserID as CKRecordValue }
            // Emoji alanı geriye uyumluluk için: eski istemciler glifi görsün.
            record["emoji"] = (kind == .reply ? "" : kind.glyph) as CKRecordValue

            self.publicDatabase.save(record) { _, error in
                DispatchQueue.main.async {
                    if let error {
                        if let ck = error as? CKError,
                           ck.code == .invalidArguments || ck.code == .unknownItem {
                            ONELogger.error(
                                "sendDailyReaction: EmojiReaction şemasına text/kind/toUserID/colorHex alanları CloudKit'e deploy edilmemiş. Dashboard → Deploy Schema Changes.",
                                error: error, category: .cloudkit
                            )
                        } else {
                            ONELogger.error("sendDailyReaction failed: \(error.localizedDescription)", error: error, category: .cloudkit)
                        }
                        completion(.failure(.underlying(error)))
                    } else {
                        completion(.success(()))
                    }
                }
            }
        }

        // Yanıtlar her zaman yeni; tepkiler gönderen başına yerinde güncellenir.
        guard kind != .reply else { write(CKRecord(recordType: DailyReaction.recordType)); return }

        let predicate = NSPredicate(
            format: "shareRecordName == %@ AND senderUserID == %@ AND kind != %@",
            shareRecordName, currentUserID, DailyReaction.Kind.reply.rawValue
        )
        let query = CKQuery(recordType: DailyReaction.recordType, predicate: predicate)
        publicDatabase.fetch(withQuery: query, inZoneWith: nil, desiredKeys: nil, resultsLimit: 1) { result in
            let existing: CKRecord?
            if case .success(let (matches, _)) = result {
                existing = matches.compactMap { try? $0.1.get() }.first
            } else {
                existing = nil
            }
            write(existing ?? CKRecord(recordType: DailyReaction.recordType))
        }
    }

    // MARK: - Getir

    /// Bir paylaşıma gelen tüm karşılıkları (bugün) gönderen adı/rengiyle
    /// döndürür. Sıralama istemci tarafında `createdAt` artan. Efemerlik de
    /// istemci tarafında: yalnız bugüne ait olanlar.
    func fetchDailyReactions(
        shareRecordName: String,
        completion: @escaping ([DailyReaction]) -> Void
    ) {
        let predicate = NSPredicate(format: "shareRecordName == %@", shareRecordName)
        let query = CKQuery(recordType: DailyReaction.recordType, predicate: predicate)

        publicDatabase.fetch(withQuery: query, inZoneWith: nil, desiredKeys: nil, resultsLimit: 100) { [weak self] result in
            guard let self else { completion([]); return }
            guard case .success(let (matches, _)) = result else {
                DispatchQueue.main.async { completion([]) }; return
            }

            let reactions = matches
                .compactMap { try? $0.1.get() }
                .compactMap { DailyReaction(record: $0) }
                .filter { $0.isToday }
                .sorted { $0.createdAt < $1.createdAt }

            guard !reactions.isEmpty else { DispatchQueue.main.async { completion([]) }; return }

            // Gönderen adlarını toplu getir (fetchReceivedEmojiReactions deseni).
            let ids = Array(Set(reactions.map { $0.senderUserID }))
            let nameQuery = CKQuery(recordType: "AppUser",
                                    predicate: NSPredicate(format: "userID IN %@", ids))
            self.publicDatabase.fetch(withQuery: nameQuery, inZoneWith: nil,
                                      desiredKeys: ["userID", "displayName", "avatarColor"],
                                      resultsLimit: ids.count) { nameResult in
                var nameMap: [String: String] = [:]
                var colorMap: [String: String] = [:]
                if case .success(let (nameMatches, _)) = nameResult {
                    for rec in nameMatches.compactMap({ try? $0.1.get() }) {
                        guard let uid = rec["userID"] as? String else { continue }
                        nameMap[uid] = rec["displayName"] as? String
                        colorMap[uid] = rec["avatarColor"] as? String
                    }
                }
                let enriched = reactions.map { r -> DailyReaction in
                    var out = r
                    out.senderName = nameMap[r.senderUserID]
                    out.senderColorHex = colorMap[r.senderUserID]
                    return out
                }
                DispatchQueue.main.async { completion(enriched) }
            }
        }
    }
}
