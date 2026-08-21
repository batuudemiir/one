//
//  CloudKitDailyShareService.swift
//  one
//
//  Daily share management extension for CloudKitManager
//

import Foundation
import CloudKit
import Combine

// MARK: - Emoji Reaction Item

struct EmojiReactionItem: Identifiable {
    let id = UUID()
    let emoji: String
    let senderName: String
    let senderUserID: String
}

// MARK: - Daily Share Management
extension CloudKitManager {
    
    func shareDailySong(songName: String, artistName: String, genre: String?, emoji: String?, albumArtURL: String?, moodWord: String, moodColor: String, moodTheme: String, dailyNote: String?, platform: String, date: Date, photoData: Data? = nil, feeling: String? = nil, feelingLabel: String? = nil, weatherIcon: String? = nil, weatherDesc: String? = nil, currentStreak: Int = 0, entryIndex: Int = 0, completion: @escaping (Result<CKRecord, Error>) -> Void) {

        // If CloudKit is throttled, don't hammer the server further
        if userLoadFailed {
            ONELogger.warning("shareDailySong: CloudKit throttled, skipping", category: .cloudkit)
            completion(.failure(NSError(domain: "CloudKit", code: -1, userInfo: [NSLocalizedDescriptionKey: "CloudKit throttled"])))
            return
        }

        // If currentUser is nil, wait for it to load before proceeding
        if currentUser == nil {
            ONELogger.warning("shareDailySong: currentUser is nil, waiting for it to load...", category: .cloudkit)
            Task {
                let loaded = await ensureCurrentUser()
                if loaded {
                    ONELogger.success("shareDailySong: currentUser loaded after waiting, proceeding", category: .cloudkit)
                    self.performShareDailySong(
                        songName: songName, artistName: artistName, genre: genre, emoji: emoji,
                        albumArtURL: albumArtURL, moodWord: moodWord, moodColor: moodColor,
                        moodTheme: moodTheme, dailyNote: dailyNote, platform: platform, date: date,
                        photoData: photoData, feeling: feeling, feelingLabel: feelingLabel,
                        weatherIcon: weatherIcon, weatherDesc: weatherDesc,
                        currentStreak: currentStreak, entryIndex: entryIndex, completion: completion
                    )
                } else {
                    ONELogger.error("shareDailySong: currentUser still nil after waiting, cannot share", category: .cloudkit)
                    completion(.failure(NSError(domain: "CloudKit", code: -1, userInfo: [NSLocalizedDescriptionKey: "User not authenticated — could not load currentUser"])))
                }
            }
            return
        }

        performShareDailySong(
            songName: songName, artistName: artistName, genre: genre, emoji: emoji,
            albumArtURL: albumArtURL, moodWord: moodWord, moodColor: moodColor,
            moodTheme: moodTheme, dailyNote: dailyNote, platform: platform, date: date,
            photoData: photoData, feeling: feeling, feelingLabel: feelingLabel,
            weatherIcon: weatherIcon, weatherDesc: weatherDesc,
            currentStreak: currentStreak, entryIndex: entryIndex, completion: completion
        )
    }

    private func performShareDailySong(songName: String, artistName: String, genre: String?, emoji: String?, albumArtURL: String?, moodWord: String, moodColor: String, moodTheme: String, dailyNote: String?, platform: String, date: Date, photoData: Data? = nil, feeling: String? = nil, feelingLabel: String? = nil, weatherIcon: String? = nil, weatherDesc: String? = nil, currentStreak: Int = 0, entryIndex: Int = 0, completion: @escaping (Result<CKRecord, Error>) -> Void) {
        guard let currentUserID = currentUser?["userID"] as? String else {
            ONELogger.error("performShareDailySong: currentUser is nil even after retry", category: .cloudkit)
            completion(.failure(NSError(domain: "CloudKit", code: -1, userInfo: [NSLocalizedDescriptionKey: "No current user ID available"])))
            return
        }
        
        // Önce bugüne ait bir kayıt var mı kontrol edelim (çoklu an: her zaman yeni kayıt)
        fetchUserDailyShare(for: date) { [weak self] fetchResult in
            let shareRecord: CKRecord

            if entryIndex > 0 {
                // Çoklu an: mevcut kaydı güncelleme, her zaman yeni kayıt
                shareRecord = CKRecord(recordType: "DailyShare")
                shareRecord["shareID"] = UUID().uuidString as CKRecordValue
                shareRecord["userID"] = currentUserID as CKRecordValue
                shareRecord["date"] = date as CKRecordValue
                shareRecord["entryIndex"] = entryIndex as CKRecordValue
                ONELogger.debug("✨ Yeni DailyShare oluşturuluyor (entryIndex=\(entryIndex))...", category: .cloudkit)
            } else {
                switch fetchResult {
                case .success(let existingRecord):
                    // Mevcut kaydı güncelle (recordID sabit kalır → yorumlar kaybolmaz).
                    shareRecord = existingRecord
                    ONELogger.debug("Mevcut DailyShare güncelleniyor (recordID sabit)...", category: .cloudkit)
                case .failure(_):
                    shareRecord = CKRecord(recordType: "DailyShare")
                    shareRecord["shareID"] = UUID().uuidString as CKRecordValue
                    shareRecord["userID"] = currentUserID as CKRecordValue
                    shareRecord["date"] = date as CKRecordValue
                    shareRecord["entryIndex"] = 0 as CKRecordValue
                    ONELogger.debug("✨ Yeni DailyShare oluşturuluyor...", category: .cloudkit)
                }
            }
            
            shareRecord["songName"] = songName as CKRecordValue
            shareRecord["artistName"] = artistName as CKRecordValue
            shareRecord["genre"] = (genre ?? "") as CKRecordValue
            shareRecord["emoji"] = (emoji ?? "") as CKRecordValue
            shareRecord["albumArtURL"] = (albumArtURL ?? "") as CKRecordValue
            shareRecord["moodWord"] = moodWord as CKRecordValue
            shareRecord["moodColor"] = moodColor as CKRecordValue
            shareRecord["moodTheme"] = moodTheme as CKRecordValue
            shareRecord["dailyNote"] = (dailyNote.map { String($0.prefix(500)).trimmingCharacters(in: .whitespacesAndNewlines) } ?? "") as CKRecordValue
            shareRecord["platform"] = platform as CKRecordValue
            shareRecord["isPublic"] = 1 as CKRecordValue
            shareRecord["createdAt"] = Date() as CKRecordValue
            shareRecord["feeling"] = (feeling ?? "") as CKRecordValue
            shareRecord["feelingLabel"] = (feelingLabel ?? "") as CKRecordValue
            shareRecord["weatherIcon"] = (weatherIcon ?? "") as CKRecordValue
            shareRecord["weatherDesc"] = (weatherDesc ?? "") as CKRecordValue
            shareRecord["currentStreak"] = currentStreak as CKRecordValue
            let displayName = (self?.currentUser?["displayName"] as? String ?? "")
            shareRecord["userName"] = String(displayName.prefix(100)).trimmingCharacters(in: .whitespacesAndNewlines) as CKRecordValue

            var tempFileURL: URL? = nil
            if let photoData = photoData {
                let tempDirectory = FileManager.default.temporaryDirectory
                let fileURL = tempDirectory.appendingPathComponent(UUID().uuidString + ".jpg")
                do {
                    try photoData.write(to: fileURL)
                    let asset = CKAsset(fileURL: fileURL)
                    shareRecord["photoAsset"] = asset
                    tempFileURL = fileURL
                } catch {
                    ONELogger.debug("Failed to write photoData to temp file for CKAsset: \(error)", category: .cloudkit)
                }
            }

            // Tracks whether the temp file has been cleaned up — prevents double-delete
            // and ensures cleanup happens even when the conflict-resolution nested save
            // completes after the operation's completionBlock fires.
            var tempCleaned = false
            let cleanupTemp: () -> Void = {
                guard !tempCleaned, let tempURL = tempFileURL else { return }
                tempCleaned = true
                try? FileManager.default.removeItem(at: tempURL)
            }

            let operation = CKModifyRecordsOperation(recordsToSave: [shareRecord], recordIDsToDelete: nil)
            operation.savePolicy = .changedKeys
            operation.perRecordSaveBlock = { [weak self] _, result in
                switch result {
                case .success(let saved):
                    cleanupTemp()
                    self?.invalidateCircleCache()
                    completion(.success(saved))
                case .failure(let error):
                    if let ckError = error as? CKError, ckError.code == .serverRecordChanged,
                       let serverRecord = ckError.serverRecord {
                        // Apply local changes onto the server record version.
                        serverRecord["songName"]     = shareRecord["songName"]
                        serverRecord["artistName"]   = shareRecord["artistName"]
                        serverRecord["moodWord"]     = shareRecord["moodWord"]
                        serverRecord["moodColor"]    = shareRecord["moodColor"]
                        serverRecord["moodTheme"]    = shareRecord["moodTheme"]
                        serverRecord["dailyNote"]    = shareRecord["dailyNote"]
                        serverRecord["feeling"]      = shareRecord["feeling"]
                        serverRecord["feelingLabel"] = shareRecord["feelingLabel"]
                        serverRecord["createdAt"]    = shareRecord["createdAt"]
                        // Preserve photo if present — temp file still alive at this point.
                        if let asset = shareRecord["photoAsset"] as? CKAsset {
                            serverRecord["photoAsset"] = asset
                        }
                        self?.publicDatabase.save(serverRecord) { [weak self] saved, _ in
                            // Cleanup after the nested save finishes — not before.
                            cleanupTemp()
                            if let saved { self?.invalidateCircleCache(); completion(.success(saved)) }
                            else { completion(.failure(error)) }
                        }
                    } else {
                        cleanupTemp()
                        completion(.failure(error))
                    }
                }
            }
            // Fallback: if the operation finishes without perRecordSaveBlock firing
            // (e.g. operation-level error), ensure temp file is cleaned up.
            operation.completionBlock = { cleanupTemp() }
            self?.publicDatabase.add(operation)
        }
    }
    
    func fetchFriendsDailyShares(for date: Date, completion: @escaping (Result<[FriendCircleData], Error>) -> Void) {
        // Return cache immediately if still valid for today
        if isCircleCacheValid, let cached = cachedCircleData {
            completion(.success(cached))
            return
        }
        // Get friend IDs first
        fetchFriends { [weak self] result in
            switch result {
            case .success(let friendships):
                let friendIDs = friendships.compactMap { friendship -> String? in
                    let user1 = friendship["user1ID"] as? String
                    let user2 = friendship["user2ID"] as? String
                    let currentID = self?.currentUser?["userID"] as? String
                    if currentID == nil {
                        ONELogger.warning("fetchFriendsDailyShares: currentUser is nil, friend ID extraction may fail", category: .cloudkit)
                    }
                    return user1 == currentID ? user2 : user1
                }
                
                guard !friendIDs.isEmpty else {
                    completion(.success([]))
                    return
                }
                
                let userPredicate = NSPredicate(format: "userID IN %@", friendIDs)
                let userQuery = CKQuery(recordType: "AppUser", predicate: userPredicate)
                self?.publicDatabase.fetch(withQuery: userQuery, inZoneWith: nil, desiredKeys: nil, resultsLimit: CKQueryOperation.maximumResults) { res in
                    switch res {
                    case .success(let (matchResults, _)):
                        let friendUsers = matchResults.compactMap { try? $0.1.get() }
                        let appUserIDs = friendUsers.compactMap { $0["userID"] as? String }
                        
                        if appUserIDs.isEmpty {
                            DispatchQueue.main.async { completion(.success([])) }
                            return
                        }
                        
                        // Fetch DailyShare records
                        let calendar = Calendar.current
                        let startOfDay = calendar.startOfDay(for: date)
                        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
                        
                        let sharePredicate = NSPredicate(format: "userID IN %@ AND date >= %@ AND date < %@",
                                                  appUserIDs, startOfDay as NSDate, endOfDay as NSDate)
                        let shareQuery = CKQuery(recordType: "DailyShare", predicate: sharePredicate)
                        
                        self?.publicDatabase.fetch(withQuery: shareQuery, inZoneWith: nil, desiredKeys: nil, resultsLimit: CKQueryOperation.maximumResults) { shareRes in
                            switch shareRes {
                            case .success(let (shareMatchResults, _)):
                                let records = shareMatchResults.compactMap { try? $0.1.get() }
                                // v3: gün artık N an. Dedup YOK — her kullanıcının
                                // o güne ait tüm kayıtları kronolojik sırada tutulur
                                // (entryIndex artan, eşitse creationDate artan).
                                // Kart ızgarası "N an" ve çok renkli şeridi buradan çiziyor;
                                // `share` (ilk an) eski okuma yolları için hesaplanıyor.
                                let sortedRecords = records.sorted { a, b in
                                    let ai = a["entryIndex"] as? Int ?? 0
                                    let bi = b["entryIndex"] as? Int ?? 0
                                    if ai != bi { return ai < bi }
                                    return (a.creationDate ?? Date.distantPast) < (b.creationDate ?? Date.distantPast)
                                }
                                var friendShares: [String: [CKRecord]] = [:]
                                for record in sortedRecords {
                                    guard let uid = record["userID"] as? String else { continue }
                                    friendShares[uid, default: []].append(record)
                                }

                                DispatchQueue.main.async {
                                    var combined: [FriendCircleData] = []
                                    for user in friendUsers {
                                        let uid = user["userID"] as? String ?? ""
                                        combined.append(FriendCircleData(user: user, shares: friendShares[uid] ?? []))
                                    }

                                    // Sort: friends with shares first, then alphabetically
                                    combined.sort { a, b in
                                        if a.share != nil && b.share == nil { return true }
                                        if a.share == nil && b.share != nil { return false }
                                        let nameA = a.user["displayName"] as? String ?? ""
                                        let nameB = b.user["displayName"] as? String ?? ""
                                        return nameA < nameB
                                    }
                                    // Store in cache
                                    self?.cachedCircleData = combined
                                    self?.circleDataLastFetched = Date()
                                    completion(.success(combined))
                                }

                            case .failure(let error):
                                DispatchQueue.main.async { completion(.failure(error)) }
                            }
                        }
                    case .failure(let error):
                        DispatchQueue.main.async { completion(.failure(error)) }
                    }
                }
            case .failure(let error):
                DispatchQueue.main.async { completion(.failure(error)) }
            }
        }
    }
    
    func fetchFriendsDailySharesLastWeek(completion: @escaping (Result<[FriendCircleData], Error>) -> Void) {
        let sevenDaysAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()

        fetchFriends { [weak self] result in
            switch result {
            case .success(let friendships):
                let friendIDs = friendships.compactMap { friendship -> String? in
                    let user1 = friendship["user1ID"] as? String
                    let user2 = friendship["user2ID"] as? String
                    let currentID = self?.currentUser?["userID"] as? String
                    return user1 == currentID ? user2 : user1
                }.filter { !(self?.hasBlockRelation(with: $0) ?? false) }

                guard !friendIDs.isEmpty else {
                    completion(.success([]))
                    return
                }

                let userPredicate = NSPredicate(format: "userID IN %@", friendIDs)
                let userQuery = CKQuery(recordType: "AppUser", predicate: userPredicate)
                self?.publicDatabase.fetch(withQuery: userQuery, inZoneWith: nil, desiredKeys: nil, resultsLimit: CKQueryOperation.maximumResults) { res in
                    switch res {
                    case .success(let (matchResults, _)):
                        let friendUsers = matchResults.compactMap { try? $0.1.get() }
                        let appUserIDs = friendUsers.compactMap { $0["userID"] as? String }

                        guard !appUserIDs.isEmpty else {
                            DispatchQueue.main.async { completion(.success([])) }
                            return
                        }

                        let sharePredicate = NSPredicate(format: "userID IN %@ AND date >= %@",
                                                         appUserIDs, sevenDaysAgo as NSDate)
                        let shareQuery = CKQuery(recordType: "DailyShare", predicate: sharePredicate)

                        self?.publicDatabase.fetch(withQuery: shareQuery, inZoneWith: nil, desiredKeys: nil, resultsLimit: CKQueryOperation.maximumResults) { shareRes in
                            switch shareRes {
                            case .success(let (shareMatchResults, _)):
                                let records = shareMatchResults.compactMap { try? $0.1.get() }

                                // Build a user lookup map
                                var userMap: [String: CKRecord] = [:]
                                for user in friendUsers {
                                    if let uid = user["userID"] as? String {
                                        userMap[uid] = user
                                    }
                                }

                                // All records, dedup NOT applied — one entry per share record
                                var combined: [FriendCircleData] = records.compactMap { record in
                                    guard let uid = record["userID"] as? String,
                                          let userRecord = userMap[uid] else { return nil }
                                    return FriendCircleData(user: userRecord, share: record)
                                }

                                // Sort: most recent share first
                                combined.sort {
                                    ($0.share?.creationDate ?? .distantPast) > ($1.share?.creationDate ?? .distantPast)
                                }

                                DispatchQueue.main.async { completion(.success(combined)) }

                            case .failure(let error):
                                DispatchQueue.main.async { completion(.failure(error)) }
                            }
                        }

                    case .failure(let error):
                        DispatchQueue.main.async { completion(.failure(error)) }
                    }
                }

            case .failure(let error):
                DispatchQueue.main.async { completion(.failure(error)) }
            }
        }
    }

    /// Kullanıcının verilen tarihteki DailyShare kaydının `recordName`'ini döndürür.
    /// Comment thread için shareRecordName lookup'ında kullanılır.
    /// Kayıt yoksa veya hata varsa nil döner — yorum butonu sessizce devre dışı kalır.
    func fetchOwnDailyShareRecordName(date: Date, completion: @escaping (String?) -> Void) {
        fetchUserDailyShare(for: date) { result in
            switch result {
            case .success(let record):
                DispatchQueue.main.async { completion(record.recordID.recordName) }
            case .failure:
                DispatchQueue.main.async { completion(nil) }
            }
        }
    }

    func fetchUserDailyShare(for date: Date, completion: @escaping (Result<CKRecord, Error>) -> Void) {
        guard let currentUserID = currentUser?["userID"] as? String else {
            ONELogger.warning("fetchUserDailyShare: currentUser is nil, cannot fetch share", category: .cloudkit)
            completion(.failure(NSError(domain: "CloudKit", code: -1, userInfo: [NSLocalizedDescriptionKey: "No current user — cannot fetch daily share"])))
            return
        }
        
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        
        let predicate = NSPredicate(format: "userID == %@ AND date >= %@ AND date < %@",
                                  currentUserID, startOfDay as NSDate, endOfDay as NSDate)
        let query = CKQuery(recordType: "DailyShare", predicate: predicate)
        
        publicDatabase.fetch(withQuery: query, inZoneWith: nil, desiredKeys: nil, resultsLimit: CKQueryOperation.maximumResults) { result in
            switch result {
            case .success(let (matchResults, _)):
                let records = matchResults.compactMap { try? $0.1.get() }
                
                // Sort locally by creationDate
                let sortedRecords = records.sorted {
                    ($0.creationDate ?? Date.distantPast) > ($1.creationDate ?? Date.distantPast)
                }
                
                if let record = sortedRecords.first {
                    completion(.success(record))
                } else {
                    completion(.failure(NSError(domain: "CloudKit", code: -1, userInfo: [NSLocalizedDescriptionKey: "No share found for today"])))
                }
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    // MARK: - Fetch a Specific User's Daily Share

    /// Belirtilen userID'nin bugünkü DailyShare kaydını çeker.
    /// FriendDetailView'deki polling için kullanılır.
    func fetchDailyShare(for userID: String, date: Date,
                         completion: @escaping (Result<CKRecord, Error>) -> Void) {
        let cal        = Calendar.current
        let startOfDay = cal.startOfDay(for: date)
        let endOfDay   = cal.date(byAdding: .day, value: 1, to: startOfDay)!

        let predicate = NSPredicate(format: "userID == %@ AND date >= %@ AND date < %@",
                                    userID, startOfDay as NSDate, endOfDay as NSDate)
        let query = CKQuery(recordType: "DailyShare", predicate: predicate)

        // Birden fazla kayıt olabilir (günün diğer anları) — entryIndex=0 tercih et
        publicDatabase.fetch(withQuery: query, inZoneWith: nil,
                             desiredKeys: nil, resultsLimit: CKQueryOperation.maximumResults) { result in
            switch result {
            case .success(let (matches, _)):
                let records = matches.compactMap { try? $0.1.get() }
                // entryIndex=0 önce gelsin; eşitse creationDate azalan
                let sorted = records.sorted { a, b in
                    let ai = a["entryIndex"] as? Int ?? 0
                    let bi = b["entryIndex"] as? Int ?? 0
                    if ai != bi { return ai < bi }
                    return (a.creationDate ?? Date.distantPast) > (b.creationDate ?? Date.distantPast)
                }
                if let record = sorted.first {
                    DispatchQueue.main.async { completion(.success(record)) }
                } else {
                    DispatchQueue.main.async {
                        completion(.failure(NSError(domain: "CloudKit", code: -1,
                            userInfo: [NSLocalizedDescriptionKey: "No share found"])))
                    }
                }
            case .failure(let e):
                DispatchQueue.main.async { completion(.failure(e)) }
            }
        }
    }

    // MARK: - Delete Daily Share
    func deleteUserDailyShare(for date: Date, completion: @escaping (Result<Bool, Error>) -> Void) {
        fetchUserDailyShare(for: date) { [weak self] result in
            switch result {
            case .success(let record):
                self?.publicDatabase.delete(withRecordID: record.recordID) { deletedRecordID, error in
                    if let error = error {
                        completion(.failure(error))
                    } else {
                        completion(.success(true))
                    }
                }
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    // MARK: - Emoji Reactions

    /// Emoji reaksiyonunu CloudKit'e kaydeder (EmojiReaction record type).
    /// - Warning: v2.5 ile deprecated — yorum sistemine geçildi.
    @available(*, deprecated, message: "v2.5 — yorum sistemi kullan (CloudKitCommentService).")
    func sendEmojiReaction(shareRecordName: String, emoji: String, completion: @escaping (Result<Bool, Error>) -> Void) {
        guard let currentUserID = currentUser?["userID"] as? String else {
            completion(.failure(NSError(domain: "CloudKit", code: -1, userInfo: [NSLocalizedDescriptionKey: "No current user"])))
            return
        }

        // Daha önce aynı share'e reaksiyon gönderilmişse güncelle, yoksa yeni oluştur
        let predicate = NSPredicate(format: "shareRecordName == %@ AND senderUserID == %@", shareRecordName, currentUserID)
        let query = CKQuery(recordType: "EmojiReaction", predicate: predicate)

        publicDatabase.fetch(withQuery: query, inZoneWith: nil, desiredKeys: nil, resultsLimit: 1) { [weak self] result in
            guard let self else { return }

            let record: CKRecord
            switch result {
            case .success(let (matchResults, _)):
                record = matchResults.compactMap { try? $0.1.get() }.first ?? CKRecord(recordType: "EmojiReaction")
            case .failure:
                record = CKRecord(recordType: "EmojiReaction")
            }

            record["shareRecordName"] = shareRecordName as CKRecordValue
            record["senderUserID"] = currentUserID as CKRecordValue
            record["emoji"] = emoji as CKRecordValue
            record["date"] = Date() as CKRecordValue

            self.publicDatabase.save(record) { _, error in
                DispatchQueue.main.async {
                    if let error {
                        ONELogger.error("sendEmojiReaction failed: \(error)", category: .circle)
                        completion(.failure(error))
                    } else {
                        ONELogger.success("Emoji reaksiyonu kaydedildi: \(emoji)", category: .circle)
                        completion(.success(true))
                    }
                }
            }
        }
    }

    /// Kullanıcının bu share'e daha önce gönderdiği emoji reaksiyonunu yükler.
    @available(*, deprecated, message: "v2.5 — yorum sistemine geçildi.")
    func fetchEmojiReaction(shareRecordName: String, completion: @escaping (String?) -> Void) {
        guard let currentUserID = currentUser?["userID"] as? String else {
            completion(nil)
            return
        }

        let predicate = NSPredicate(format: "shareRecordName == %@ AND senderUserID == %@", shareRecordName, currentUserID)
        let query = CKQuery(recordType: "EmojiReaction", predicate: predicate)

        publicDatabase.fetch(withQuery: query, inZoneWith: nil, desiredKeys: nil, resultsLimit: 1) { result in
            switch result {
            case .success(let (matchResults, _)):
                let emoji = matchResults.compactMap { try? $0.1.get() }.first?["emoji"] as? String
                DispatchQueue.main.async { completion(emoji) }
            case .failure:
                DispatchQueue.main.async { completion(nil) }
            }
        }
    }

    /// Başkalarının bu share'e gönderdiği tüm emoji reaksiyonlarını yükler (current user hariç).
    /// Her reaksiyon için gönderenin displayName'ini de getirir.
    @available(*, deprecated, message: "v2.5 — yorum sistemine geçildi.")
    func fetchReceivedEmojiReactions(shareRecordName: String, completion: @escaping ([EmojiReactionItem]) -> Void) {
        guard let currentUserID = currentUser?["userID"] as? String else {
            completion([])
            return
        }

        let predicate = NSPredicate(format: "shareRecordName == %@ AND senderUserID != %@",
                                    shareRecordName, currentUserID)
        let query = CKQuery(recordType: "EmojiReaction", predicate: predicate)

        publicDatabase.fetch(withQuery: query, inZoneWith: nil,
                             desiredKeys: ["emoji", "senderUserID"], resultsLimit: 50) { [weak self] result in
            guard let self else { completion([]); return }

            switch result {
            case .success(let (matchResults, _)):
                let records = matchResults.compactMap { try? $0.1.get() }
                let pairs: [(emoji: String, senderID: String)] = records.compactMap { record in
                    guard let emoji = record["emoji"] as? String,
                          let senderID = record["senderUserID"] as? String else { return nil }
                    return (emoji: emoji, senderID: senderID)
                }
                guard !pairs.isEmpty else { DispatchQueue.main.async { completion([]) }; return }

                // Tekil gönderici ID'leri — toplu AppUser sorgusu
                let uniqueIDs = Array(Set(pairs.map { $0.senderID }))
                let nameQuery = CKQuery(recordType: "AppUser",
                                        predicate: NSPredicate(format: "userID IN %@", uniqueIDs))
                self.publicDatabase.fetch(withQuery: nameQuery, inZoneWith: nil,
                                          desiredKeys: ["userID", "displayName"],
                                          resultsLimit: uniqueIDs.count) { nameResult in
                    var nameMap: [String: String] = [:]
                    if case .success(let (nameMatches, _)) = nameResult {
                        for rec in nameMatches.compactMap({ try? $0.1.get() }) {
                            if let uid = rec["userID"] as? String,
                               let name = rec["displayName"] as? String {
                                nameMap[uid] = name
                            }
                        }
                    }
                    let items = pairs.map { pair in
                        EmojiReactionItem(
                            emoji: pair.emoji,
                            senderName: nameMap[pair.senderID] ?? "Birisi",
                            senderUserID: pair.senderID
                        )
                    }
                    DispatchQueue.main.async { completion(items) }
                }

            case .failure:
                DispatchQueue.main.async { completion([]) }
            }
        }
    }

    // MARK: - Circle Sync: Çevre ile aynı şarkı eşleşmeleri

    /// Kullanıcının tüm geçmiş girişleriyle arkadaşların DailyShare'lerini karşılaştırır.
    /// Aynı gün aynı şarkıyı (songName + artistName, büyük/küçük harf duyarsız) seçtikleri
    /// günleri döndürür.
    func fetchCircleSyncMatches(
        myEntries: [DailySong],
        completion: @escaping (Result<[CircleSyncMatch], Error>) -> Void
    ) {
        guard !myEntries.isEmpty else {
            completion(.success([]))
            return
        }

        // 1. Arkadaş listesini çek
        fetchFriends { [weak self] friendResult in
            guard let self else { return }
            switch friendResult {
            case .failure(let err):
                DispatchQueue.main.async { completion(.failure(err)) }
                return
            case .success(let friendships):
                let myID = self.currentUser?["userID"] as? String ?? ""
                let friendIDs: [String] = friendships.compactMap { f in
                    let u1 = f["user1ID"] as? String ?? ""
                    let u2 = f["user2ID"] as? String ?? ""
                    return u1 == myID ? u2 : u1
                }.filter { !$0.isEmpty }

                guard !friendIDs.isEmpty else {
                    DispatchQueue.main.async { completion(.success([])) }
                    return
                }

                // 2. Arkadaş profillerini çek (displayName için)
                let userPredicate = NSPredicate(format: "userID IN %@", friendIDs)
                let userQuery = CKQuery(recordType: "AppUser", predicate: userPredicate)
                self.publicDatabase.fetch(
                    withQuery: userQuery, inZoneWith: nil,
                    desiredKeys: ["userID", "displayName"],
                    resultsLimit: CKQueryOperation.maximumResults
                ) { [weak self] userRes in
                    guard let self else { return }
                    let friendUsers: [String: String] = {
                        guard case .success(let (matches, _)) = userRes else { return [:] }
                        var dict: [String: String] = [:]
                        for (_, result) in matches {
                            if let record = try? result.get(),
                               let uid = record["userID"] as? String,
                               let name = record["displayName"] as? String {
                                dict[uid] = name
                            }
                        }
                        return dict
                    }()

                    // 3. Kendi girişlerimin tarih aralığını belirle
                    let calendar = Calendar.current
                    let myDates = myEntries.compactMap { $0.date }.map { calendar.startOfDay(for: $0) }
                    guard let minDate = myDates.min(),
                          let maxDateBase = myDates.max(),
                          let maxDate = calendar.date(byAdding: .day, value: 1, to: maxDateBase)
                    else {
                        DispatchQueue.main.async { completion(.success([])) }
                        return
                    }

                    // 4. Bu tarih aralığındaki tüm arkadaş DailyShare'lerini çek
                    let sharePredicate = NSPredicate(
                        format: "userID IN %@ AND date >= %@ AND date < %@",
                        friendIDs, minDate as NSDate, maxDate as NSDate
                    )
                    let shareQuery = CKQuery(recordType: "DailyShare", predicate: sharePredicate)
                    self.publicDatabase.fetch(
                        withQuery: shareQuery, inZoneWith: nil,
                        desiredKeys: ["userID", "songName", "artistName", "date"],
                        resultsLimit: CKQueryOperation.maximumResults
                    ) { shareRes in
                        guard case .success(let (shareMatches, _)) = shareRes else {
                            if case .failure(let err) = shareRes {
                                DispatchQueue.main.async { completion(.failure(err)) }
                            }
                            return
                        }

                        let friendShares = shareMatches.compactMap { _, result -> CKRecord? in
                            try? result.get()
                        }

                        // 5. Karşılaştır: aynı gün + aynı şarkı + aynı sanatçı
                        let dateFmt = DateFormatter()
                        dateFmt.locale = LanguageManager.shared.currentLocale
                        dateFmt.dateFormat = "d MMM"

                        var matches: [CircleSyncMatch] = []
                        var seen = Set<String>() // deduplicate: aynı gün+şarkı+arkadaş

                        for myEntry in myEntries {
                            guard let myDate = myEntry.date,
                                  let mySong = myEntry.songName?.trimmingCharacters(in: .whitespaces).lowercased(),
                                  let myArtist = myEntry.artistName?.trimmingCharacters(in: .whitespaces).lowercased(),
                                  !mySong.isEmpty
                            else { continue }

                            let dayStart = calendar.startOfDay(for: myDate)
                            guard let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) else { continue }

                            for share in friendShares {
                                guard let shareDate = share["date"] as? Date,
                                      shareDate >= dayStart && shareDate < dayEnd,
                                      let friendID = share["userID"] as? String
                                else { continue }

                                let friendSong = (share["songName"] as? String ?? "")
                                    .trimmingCharacters(in: .whitespaces).lowercased()
                                let friendArtist = (share["artistName"] as? String ?? "")
                                    .trimmingCharacters(in: .whitespaces).lowercased()

                                guard mySong == friendSong && myArtist == friendArtist else { continue }

                                let dedupeKey = "\(dayStart)|\(mySong)|\(friendID)"
                                guard !seen.contains(dedupeKey) else { continue }
                                seen.insert(dedupeKey)

                                let match = CircleSyncMatch(
                                    id: UUID(),
                                    date: myDate,
                                    dateLabel: dateFmt.string(from: myDate),
                                    songName: myEntry.songName ?? "",
                                    artistName: myEntry.artistName ?? "",
                                    friendDisplayName: friendUsers[friendID] ?? "Arkadaş",
                                    moodColorHex: myEntry.moodColorHex ?? "#888888"
                                )
                                matches.append(match)
                            }
                        }

                        // En yeni eşleşme önce
                        let sorted = matches.sorted { $0.date > $1.date }
                        ONELogger.success("CircleSync: \(sorted.count) eşleşme bulundu", category: .circle)
                        DispatchQueue.main.async { completion(.success(sorted)) }
                    }
                }
            }
        }
    }

    // MARK: - Sync Management
    func syncAllData() {
        DispatchQueue.main.async {
            self.syncStatus = .syncing
        }
        
        fetchFriendsDailyShares(for: Date()) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    self?.syncStatus = .success
                case .failure(let error):
                    self?.syncStatus = .error(error.localizedDescription)
                }
            }
        }
    }

}
