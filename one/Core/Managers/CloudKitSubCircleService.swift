//
//  CloudKitSubCircleService.swift
//  one
//
//  Alt-çevre (SubCircle) CRUD. Kullanıcının kendi gruplarını public DB'de
//  `ownerID == me` altında tutar. Üyelik `memberIDs` listesinde — ayrı
//  membership kaydı yok. Çevre filtreleme istemci tarafında yapıldığı için
//  burada yalnız sahibin grupları getirilir/yazılır.
//
//  ⚠️ CloudKit şeması: `SubCircle` kayıt tipi + `ownerID` (Queryable),
//  `name`, `colorHex`, `emoji`, `memberIDs` (String List), `createdAt`
//  (Sortable) alanları Dashboard'dan deploy edilmeli.
//

import Foundation
import CloudKit

enum SubCircleServiceError: LocalizedError {
    case noCurrentUser
    case nameEmpty
    case nameTooLong
    case tooManyMembers
    case underlying(Error)

    var errorDescription: String? {
        switch self {
        case .noCurrentUser:   return "Kullanıcı bilgisi yüklenmedi."
        case .nameEmpty:       return "Grup adı boş olamaz."
        case .nameTooLong:     return "Grup adı \(SubCircle.maxNameLength) karakterden uzun olamaz."
        case .tooManyMembers:  return "Bir grupta en fazla \(SubCircle.maxMembers) kişi olabilir."
        case .underlying(let e): return e.localizedDescription
        }
    }
}

extension CloudKitManager {

    // MARK: - Oluştur

    /// Yeni alt-çevre yazar. `memberIDs` mevcut arkadaşların userID'leri
    /// olmalı — servis burada arkadaşlık doğrulaması yapmaz (UI yalnız
    /// arkadaşlardan seçtiriyor), sadece sayı sınırını uygular.
    func createSubCircle(
        name: String,
        colorHex: String,
        emoji: String,
        memberIDs: [String],
        completion: @escaping (Result<SubCircle, SubCircleServiceError>) -> Void
    ) {
        guard let ownerID = currentUser?["userID"] as? String else {
            completion(.failure(.noCurrentUser)); return
        }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { completion(.failure(.nameEmpty)); return }
        guard trimmed.count <= SubCircle.maxNameLength else { completion(.failure(.nameTooLong)); return }
        guard memberIDs.count <= SubCircle.maxMembers else { completion(.failure(.tooManyMembers)); return }

        let rec = CKRecord(recordType: SubCircle.recordType)
        rec["ownerID"]   = ownerID as CKRecordValue
        rec["name"]      = trimmed as CKRecordValue
        rec["colorHex"]  = colorHex as CKRecordValue
        rec["emoji"]     = emoji as CKRecordValue
        rec["createdAt"] = Date() as CKRecordValue
        if !memberIDs.isEmpty { rec["memberIDs"] = memberIDs as CKRecordValue }

        publicDatabase.save(rec) { saved, error in
            DispatchQueue.main.async {
                if let saved, let circle = SubCircle(record: saved) {
                    ONELogger.success("SubCircle oluşturuldu: \(trimmed)", category: .circle)
                    completion(.success(circle))
                } else {
                    ONELogger.error("SubCircle oluşturulamadı", error: error, category: .circle)
                    completion(.failure(.underlying(error ?? AppError.unknown(message: "SubCircle kaydı okunamadı"))))
                }
            }
        }
    }

    // MARK: - Getir

    /// Sahibin tüm alt-çevrelerini `createdAt` artan sırada getirir.
    /// Sorgu başarısızsa (şema henüz deploy edilmemiş vb.) boş liste döner —
    /// UI kırılmaz.
    func fetchMySubCircles(completion: @escaping ([SubCircle]) -> Void) {
        guard let ownerID = currentUser?["userID"] as? String else {
            completion([]); return
        }
        let predicate = NSPredicate(format: "ownerID == %@", ownerID)
        let query = CKQuery(recordType: SubCircle.recordType, predicate: predicate)
        query.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: true)]

        publicDatabase.fetch(withQuery: query, inZoneWith: nil,
                             desiredKeys: nil, resultsLimit: CKQueryOperation.maximumResults) { result in
            var circles: [SubCircle] = []
            if case .success(let (matches, _)) = result {
                circles = matches.compactMap { try? $0.1.get() }.compactMap { SubCircle(record: $0) }
            } else if case .failure(let error) = result {
                ONELogger.info("fetchMySubCircles başarısız (şema deploy edilmemiş olabilir): \(error.localizedDescription)", category: .circle)
            }
            DispatchQueue.main.async { completion(circles) }
        }
    }

    // MARK: - Güncelle

    /// Ada/renk/emoji/üye listesini tek turda günceller. Nil verilen alan
    /// değişmez. Kayıt önce fetch edilir, sonra üzerine yazılır (savePolicy
    /// çakışmalarını önlemek için).
    func updateSubCircle(
        id: String,
        name: String? = nil,
        colorHex: String? = nil,
        emoji: String? = nil,
        memberIDs: [String]? = nil,
        completion: @escaping (Result<SubCircle, SubCircleServiceError>) -> Void
    ) {
        if let name {
            let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { completion(.failure(.nameEmpty)); return }
            guard trimmed.count <= SubCircle.maxNameLength else { completion(.failure(.nameTooLong)); return }
        }
        if let memberIDs, memberIDs.count > SubCircle.maxMembers {
            completion(.failure(.tooManyMembers)); return
        }

        let recordID = CKRecord.ID(recordName: id)
        publicDatabase.fetch(withRecordID: recordID) { [weak self] record, error in
            guard let self else { return }
            guard let record else {
                DispatchQueue.main.async { completion(.failure(.underlying(error ?? AppError.unknown(message: "SubCircle kaydı okunamadı")))) }
                return
            }
            if let name { record["name"] = name.trimmingCharacters(in: .whitespacesAndNewlines) as CKRecordValue }
            if let colorHex { record["colorHex"] = colorHex as CKRecordValue }
            if let emoji { record["emoji"] = emoji as CKRecordValue }
            if let memberIDs {
                if memberIDs.isEmpty { record["memberIDs"] = nil }
                else { record["memberIDs"] = memberIDs as CKRecordValue }
            }

            self.publicDatabase.save(record) { saved, saveErr in
                DispatchQueue.main.async {
                    if let saved, let circle = SubCircle(record: saved) {
                        completion(.success(circle))
                    } else {
                        ONELogger.error("SubCircle güncellenemedi", error: saveErr, category: .circle)
                        completion(.failure(.underlying(saveErr ?? AppError.unknown(message: "SubCircle yazılamadı"))))
                    }
                }
            }
        }
    }

    // MARK: - Sil

    func deleteSubCircle(id: String, completion: @escaping (Result<Void, SubCircleServiceError>) -> Void) {
        let recordID = CKRecord.ID(recordName: id)
        publicDatabase.delete(withRecordID: recordID) { _, error in
            DispatchQueue.main.async {
                if let error {
                    ONELogger.error("SubCircle silinemedi", error: error, category: .circle)
                    completion(.failure(.underlying(error)))
                } else {
                    ONELogger.success("SubCircle silindi", category: .circle)
                    completion(.success(()))
                }
            }
        }
    }
}
