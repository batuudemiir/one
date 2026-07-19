//
//  CloudKitManager+PinnedSong.swift
//  one
//
//  Pinned song + mutual friend count CloudKit operations.
//

import Foundation
import CloudKit

extension CloudKitManager {

    // MARK: - Pinned Song

    /// Kendi AppUser record'una sabitlenen şarkıyı JSON olarak yazar.
    /// `nil` göndermek sabitlenmiş şarkıyı kaldırır.
    func updatePinnedSong(_ song: PinnedSong?) async throws {
        guard let record = currentUser else {
            throw NSError(domain: "CloudKit", code: -1,
                          userInfo: [NSLocalizedDescriptionKey: "No current user"])
        }
        if let song, let json = song.toJSONString() {
            record["pinnedSongData"] = json as CKRecordValue
            if let artworkURL = song.artworkURLString {
                record["pinnedSongArtworkURL"] = artworkURL as CKRecordValue
            } else {
                record["pinnedSongArtworkURL"] = nil
            }
        } else {
            record["pinnedSongData"] = nil
            record["pinnedSongArtworkURL"] = nil
        }
        let updated = try await publicDatabase.save(record)
        await MainActor.run { self.currentUser = updated }
        ONELogger.success("Pinned song updated", category: .cloudkit)
    }

    // MARK: - Mood Strip Visibility

    /// Mood geçmişi strip görünürlüğünü CloudKit'e yazar.
    func updateMoodStripVisibility(_ visible: Bool) async throws {
        guard let record = currentUser else {
            throw NSError(domain: "CloudKit", code: -1,
                          userInfo: [NSLocalizedDescriptionKey: "No current user"])
        }
        record["moodHistoryVisible"] = Int64(visible ? 1 : 0) as CKRecordValue
        let updated = try await publicDatabase.save(record)
        await MainActor.run { self.currentUser = updated }
        ONELogger.success("Mood strip visibility updated: \(visible)", category: .cloudkit)
    }

    // MARK: - Mutual Friend Count

    /// Benim arkadaşlarım ile hedef kullanıcının arkadaşları arasındaki kesişimi döndürür.
    /// Benim listemi `cachedFriendIDs`'den alır; hedefin listesi 1 CloudKit query ile çekilir.
    func fetchMutualFriendCount(withUserID targetID: String) async -> Int {
        let myIDs = cachedFriendIDs
        guard !myIDs.isEmpty else { return 0 }

        let pred1 = NSPredicate(format: "user1ID == %@ AND status == %@", targetID, "accepted")
        let pred2 = NSPredicate(format: "user2ID == %@ AND status == %@", targetID, "accepted")
        let q1 = CKQuery(recordType: "Friendship", predicate: pred1)
        let q2 = CKQuery(recordType: "Friendship", predicate: pred2)

        var theirIDs: Set<String> = []

        @Sendable func fetch(query: CKQuery) async -> [CKRecord] {
            await withCheckedContinuation { (cont: CheckedContinuation<[CKRecord], Never>) in
                publicDatabase.fetch(withQuery: query, inZoneWith: nil,
                                     desiredKeys: ["user1ID", "user2ID"],
                                     resultsLimit: CKQueryOperation.maximumResults) { result in
                    if case .success(let (matches, _)) = result {
                        cont.resume(returning: matches.compactMap { try? $0.1.get() })
                    } else {
                        cont.resume(returning: [])
                    }
                }
            }
        }

        async let r1 = fetch(query: q1)
        async let r2 = fetch(query: q2)
        let results1 = await r1
        let results2 = await r2

        for r in results1 + results2 {
            let u1 = r["user1ID"] as? String ?? ""
            let u2 = r["user2ID"] as? String ?? ""
            let other = (u1 == targetID) ? u2 : u1
            if !other.isEmpty { theirIDs.insert(other) }
        }

        return myIDs.intersection(theirIDs).count
    }
}
