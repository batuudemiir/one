import Foundation
import CloudKit

// MARK: - Dismissed Suggestions Store
//
// Kullanıcının "Gizle" dediği önerileri persist eder. UserDefaults tabanlı,
// hafif. Süre sınırı yok — bir kez gizlersen tekrar gelmez (kullanıcı arkadaş
// olursa veya manuel ekleme yaparsa zaten listeye karışmaz).

enum DismissedSuggestionsStore {
    private static let key = "quickAdd.dismissedSuggestions.v1"

    static var ids: Set<String> {
        let arr = UserDefaults.standard.stringArray(forKey: key) ?? []
        return Set(arr)
    }

    static func dismiss(_ userID: String) {
        var current = ids
        current.insert(userID)
        UserDefaults.standard.set(Array(current), forKey: key)
    }

    static func clear() {
        UserDefaults.standard.removeObject(forKey: key)
    }
}

// MARK: - Suggestion Cache

private struct SuggestionCache {
    static var users: [SuggestedUser] = []
    static var timestamp: Date = .distantPast
    static let ttl: TimeInterval = 600  // 10 dk
}

// MARK: - CloudKitManager + Suggestions

extension CloudKitManager {

    /// Önerilen kullanıcıları getirir. Algoritma: "Friends of Friends" — sahibi
    /// olmadığın ama arkadaşlarının arkadaşı olan kişiler. Ortak arkadaş sayısı
    /// fazla olanlar önce gelir.
    ///
    /// - parameters:
    ///   - limit: kaç öneri döndürülsün (default 5)
    ///   - forceRefresh: cache'i yok say
    ///   - completion: ana thread'de çağrılır
    func fetchSuggestedUsers(
        limit: Int = 5,
        forceRefresh: Bool = false,
        completion: @escaping ([SuggestedUser]) -> Void
    ) {
        // Cache check
        if !forceRefresh,
           Date().timeIntervalSince(SuggestionCache.timestamp) < SuggestionCache.ttl,
           !SuggestionCache.users.isEmpty {
            completion(Array(SuggestionCache.users.prefix(limit)))
            return
        }

        guard let currentUserID = currentUser?["userID"] as? String else {
            completion([]); return
        }

        // 1. Arkadaş listesi — cache eskidiyse refresh et
        let friendCacheAge = Date().timeIntervalSince(cachedFriendIDsTimestamp)
        let needsFriendRefresh = cachedFriendIDs.isEmpty || friendCacheAge > 300

        if needsFriendRefresh {
            fetchFriends { [weak self] _ in
                self?.continueSuggestions(currentUserID: currentUserID, limit: limit, completion: completion)
            }
            return
        }

        continueSuggestions(currentUserID: currentUserID, limit: limit, completion: completion)
    }

    private func continueSuggestions(
        currentUserID: String,
        limit: Int,
        completion: @escaping ([SuggestedUser]) -> Void
    ) {
        let myFriendIDs = Array(cachedFriendIDs)
        guard !myFriendIDs.isEmpty else {
            SuggestionCache.users = []
            SuggestionCache.timestamp = Date()
            DispatchQueue.main.async { completion([]) }
            return
        }

        // 2. Arkadaşlarımın accepted friendship'lerini getir (batch)
        fetchFriendshipsInvolving(userIDs: myFriendIDs) { [weak self] friendshipRecords in
            guard let self = self else { completion([]); return }

            // 3. "Other side" ID'lerini topla — ortak arkadaş sayısı
            let myFriendIDsSet = Set(myFriendIDs)
            let dismissed       = DismissedSuggestionsStore.ids
            var mutualCount: [String: Int] = [:]

            for record in friendshipRecords {
                let u1 = record["user1ID"] as? String ?? ""
                let u2 = record["user2ID"] as? String ?? ""

                // Hangisi "öteki taraf"? Arkadaşımın arkadaşı = arkadaş listesinde olmayan
                let candidate: String
                if myFriendIDsSet.contains(u1) && !myFriendIDsSet.contains(u2) {
                    candidate = u2
                } else if myFriendIDsSet.contains(u2) && !myFriendIDsSet.contains(u1) {
                    candidate = u1
                } else {
                    continue  // her ikisi de arkadaşım veya hiçbiri değil
                }

                // Filtreler
                guard !candidate.isEmpty,
                      candidate != currentUserID,
                      !myFriendIDsSet.contains(candidate),
                      !dismissed.contains(candidate) else { continue }

                // Engelleme filtresi
                if self.hasBlockRelation(with: candidate) { continue }

                mutualCount[candidate, default: 0] += 1
            }

            // 4. Top N adayı seç
            let topIDs = mutualCount
                .sorted { $0.value > $1.value }
                .prefix(limit * 2)  // fetch'ten sonra düşenler olabilir → buffer
                .map { $0.key }

            guard !topIDs.isEmpty else {
                SuggestionCache.users = []
                SuggestionCache.timestamp = Date()
                DispatchQueue.main.async { completion([]) }
                return
            }

            // 5. AppUser kayıtlarını batch çek
            self.fetchAppUsers(userIDs: Array(topIDs)) { users in
                let suggestions: [SuggestedUser] = users.compactMap { record in
                    let userID      = record["userID"]      as? String ?? ""
                    let displayName = record["displayName"] as? String ?? ""
                    guard !userID.isEmpty, !displayName.isEmpty else { return nil }

                    // isPublic = false ise öneri listesinde gösterme
                    if let pub = record["isPublic"] as? Int, pub == 0 { return nil }

                    return SuggestedUser(
                        id: userID,
                        displayName: displayName,
                        username: record["username"] as? String,
                        avatarColorHex: record["avatarColor"] as? String ?? "#888888",
                        mutualFriendCount: mutualCount[userID] ?? 0
                    )
                }
                .sorted { $0.mutualFriendCount > $1.mutualFriendCount }

                SuggestionCache.users = suggestions
                SuggestionCache.timestamp = Date()
                DispatchQueue.main.async {
                    completion(Array(suggestions.prefix(limit)))
                }
            }
        }
    }

    /// Önerileri zorla yeniler (arkadaş eklendikten sonra refresh için).
    func invalidateSuggestionsCache() {
        SuggestionCache.users = []
        SuggestionCache.timestamp = .distantPast
    }

    // MARK: - Private helpers

    /// Verilen kullanıcı ID'lerinin dahil olduğu accepted friendship kayıtlarını
    /// batch olarak getirir (2 query: user1ID IN ve user2ID IN).
    private func fetchFriendshipsInvolving(
        userIDs: [String],
        completion: @escaping ([CKRecord]) -> Void
    ) {
        let pred1 = NSPredicate(format: "user1ID IN %@ AND status == %@", userIDs, "accepted")
        let pred2 = NSPredicate(format: "user2ID IN %@ AND status == %@", userIDs, "accepted")
        let queries = [
            CKQuery(recordType: "Friendship", predicate: pred1),
            CKQuery(recordType: "Friendship", predicate: pred2)
        ]

        var allRecords: [CKRecord] = []
        let group = DispatchGroup()
        let lock  = DispatchQueue(label: "com.one.suggestions.lock")

        for q in queries {
            group.enter()
            publicDatabase.fetch(
                withQuery: q,
                inZoneWith: nil,
                desiredKeys: ["user1ID", "user2ID", "status"],
                resultsLimit: CKQueryOperation.maximumResults
            ) { result in
                lock.async {
                    if case .success(let (matches, _)) = result {
                        allRecords.append(contentsOf: matches.compactMap { try? $0.1.get() })
                    }
                    group.leave()
                }
            }
        }

        group.notify(queue: .global(qos: .userInitiated)) {
            completion(allRecords)
        }
    }

    /// AppUser kayıtlarını userID IN ile batch çeker.
    private func fetchAppUsers(
        userIDs: [String],
        completion: @escaping ([CKRecord]) -> Void
    ) {
        let pred = NSPredicate(format: "userID IN %@", userIDs)
        let query = CKQuery(recordType: "AppUser", predicate: pred)
        publicDatabase.fetch(
            withQuery: query,
            inZoneWith: nil,
            desiredKeys: ["userID", "displayName", "username", "avatarColor", "isPublic"],
            resultsLimit: CKQueryOperation.maximumResults
        ) { result in
            if case .success(let (matches, _)) = result {
                completion(matches.compactMap { try? $0.1.get() })
            } else {
                completion([])
            }
        }
    }
}
