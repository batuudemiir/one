//
//  CloudKitResonanceService.swift
//  one
//
//  v2.6 — Resonance (Rezonans) özelliği için CloudKit metotları.
//

import Foundation
import CloudKit

extension CloudKitManager {
    
    // MARK: - Resonance Features
    
    /// Arkadaşın paylaşımına rezonans gönderir
    func sendResonance(
        toShare shareID: String,
        receiverID: String,
        moodColor: String,
        moodWord: String,
        songSuggestionID: String?,
        songSuggestionName: String?,
        songSuggestionArtist: String?,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        guard let currentUserID = currentUser?["userID"] as? String else {
            completion(.failure(NSError(domain: "CloudKitManager", code: 401, userInfo: [NSLocalizedDescriptionKey: "Oturum açılmamış."])))
            return
        }
        
        let record = CKRecord(recordType: "Resonance")
        record["senderID"] = currentUserID as CKRecordValue
        record["receiverID"] = receiverID as CKRecordValue
        record["shareID"] = CKRecord.Reference(recordID: CKRecord.ID(recordName: shareID), action: .deleteSelf)
        record["moodColor"] = moodColor as CKRecordValue
        record["moodWord"] = moodWord as CKRecordValue
        
        if let songID = songSuggestionID {
            record["songSuggestionID"] = songID as CKRecordValue
            if let name = songSuggestionName { record["songSuggestionName"] = name as CKRecordValue }
            if let artist = songSuggestionArtist { record["songSuggestionArtist"] = artist as CKRecordValue }
        }
        
        publicDatabase.save(record) { savedRecord, error in
            DispatchQueue.main.async {
                if let error = error {
                    ONELogger.error("Rezonans gönderilirken hata: \(error.localizedDescription)", category: .circle)
                    completion(.failure(error))
                } else {
                    ONELogger.success("Rezonans başarıyla gönderildi", category: .circle)
                    completion(.success(()))
                }
            }
        }
    }
    
    /// Bir paylaşıma gelen rezonansları getirir; gönderen adları eklenir.
    func fetchResonances(forShare shareID: String, completion: @escaping (Result<[Resonance], Error>) -> Void) {
        let reference = CKRecord.Reference(recordID: CKRecord.ID(recordName: shareID), action: .none)
        let predicate = NSPredicate(format: "shareID == %@", reference)

        let query = CKQuery(recordType: "Resonance", predicate: predicate)
        query.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]

        publicDatabase.fetch(withQuery: query, inZoneWith: nil, desiredKeys: nil, resultsLimit: CKQueryOperation.maximumResults) { [weak self] result in
            switch result {
            case .success(let (matchResults, _)):
                let resonances = matchResults.compactMap { _, recordResult -> Resonance? in
                    guard case .success(let record) = recordResult else { return nil }
                    return Resonance(record: record)
                }
                self?.attachSenderDisplayNames(to: resonances) { enriched in
                    DispatchQueue.main.async { completion(.success(enriched)) }
                }
            case .failure(let error):
                ONELogger.error("Rezonanslar yüklenirken hata: \(error.localizedDescription)", category: .circle)
                DispatchQueue.main.async { completion(.failure(error)) }
            }
        }
    }

    private func attachSenderDisplayNames(
        to resonances: [Resonance],
        completion: @escaping ([Resonance]) -> Void
    ) {
        let uniqueIDs = Array(Set(resonances.map { $0.senderID }))
        guard !uniqueIDs.isEmpty else { completion(resonances); return }

        let userQuery = CKQuery(
            recordType: "AppUser",
            predicate: NSPredicate(format: "userID IN %@", uniqueIDs)
        )
        publicDatabase.fetch(
            withQuery: userQuery, inZoneWith: nil,
            desiredKeys: ["userID", "displayName"],
            resultsLimit: max(uniqueIDs.count, 1)
        ) { result in
            var nameMap: [String: String] = [:]
            if case .success(let (matches, _)) = result {
                for rec in matches.compactMap({ try? $0.1.get() }) {
                    guard let uid = rec["userID"] as? String,
                          let name = rec["displayName"] as? String else { continue }
                    nameMap[uid] = name
                }
            }
            let enriched = resonances.map { r -> Resonance in
                var copy = r
                copy.senderDisplayName = nameMap[r.senderID]
                return copy
            }
            completion(enriched)
        }
    }
}
