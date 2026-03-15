//
//  CloudKitDailyShareService.swift
//  one
//
//  Daily share management extension for CloudKitManager
//

import Foundation
import CloudKit

// MARK: - Daily Share Management
extension CloudKitManager {
    
    func shareDailySong(songName: String, artistName: String, genre: String?, emoji: String?, albumArtURL: String?, moodWord: String, moodColor: String, moodTheme: String, dailyNote: String?, platform: String, date: Date, photoData: Data? = nil, feeling: String? = nil, feelingLabel: String? = nil, weatherIcon: String? = nil, weatherDesc: String? = nil, currentStreak: Int = 0, completion: @escaping (Result<CKRecord, Error>) -> Void) {

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
                        currentStreak: currentStreak, completion: completion
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
            currentStreak: currentStreak, completion: completion
        )
    }

    private func performShareDailySong(songName: String, artistName: String, genre: String?, emoji: String?, albumArtURL: String?, moodWord: String, moodColor: String, moodTheme: String, dailyNote: String?, platform: String, date: Date, photoData: Data? = nil, feeling: String? = nil, feelingLabel: String? = nil, weatherIcon: String? = nil, weatherDesc: String? = nil, currentStreak: Int = 0, completion: @escaping (Result<CKRecord, Error>) -> Void) {
        guard let currentUserID = currentUser?["userID"] as? String else {
            ONELogger.error("performShareDailySong: currentUser is nil even after retry", category: .cloudkit)
            completion(.failure(NSError(domain: "CloudKit", code: -1, userInfo: [NSLocalizedDescriptionKey: "No current user ID available"])))
            return
        }
        
        // Önce bugüne ait bir kayıt var mı kontrol edelim
        fetchUserDailyShare(for: date) { [weak self] fetchResult in
            let shareRecord: CKRecord
            
            switch fetchResult {
            case .success(let existingRecord):
                // Varsa onu güncelleyeceğiz
                shareRecord = existingRecord
                ONELogger.debug("Mevcut DailyShare bulundu, güncelleniyor...", category: .cloudkit)
            case .failure(_):
                // Yoksa yeni oluşturacağız
                shareRecord = CKRecord(recordType: "DailyShare")
                shareRecord["shareID"] = UUID().uuidString as CKRecordValue
                shareRecord["userID"] = currentUserID as CKRecordValue
                shareRecord["date"] = date as CKRecordValue
                shareRecord["createdAt"] = Date() as CKRecordValue
                ONELogger.debug("✨ Yeni DailyShare oluşturuluyor...", category: .cloudkit)
            }
            
            shareRecord["songName"] = songName as CKRecordValue
            shareRecord["artistName"] = artistName as CKRecordValue
            shareRecord["genre"] = (genre ?? "") as CKRecordValue
            shareRecord["emoji"] = (emoji ?? "") as CKRecordValue
            shareRecord["albumArtURL"] = (albumArtURL ?? "") as CKRecordValue
            shareRecord["moodWord"] = moodWord as CKRecordValue
            shareRecord["moodColor"] = moodColor as CKRecordValue
            shareRecord["moodTheme"] = moodTheme as CKRecordValue
            shareRecord["dailyNote"] = (dailyNote ?? "") as CKRecordValue
            shareRecord["platform"] = platform as CKRecordValue
            shareRecord["isPublic"] = 1 as CKRecordValue
            shareRecord["createdAt"] = Date() as CKRecordValue
            shareRecord["feeling"] = (feeling ?? "") as CKRecordValue
            shareRecord["feelingLabel"] = (feelingLabel ?? "") as CKRecordValue
            shareRecord["weatherIcon"] = (weatherIcon ?? "") as CKRecordValue
            shareRecord["weatherDesc"] = (weatherDesc ?? "") as CKRecordValue
            shareRecord["currentStreak"] = currentStreak as CKRecordValue
            
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
            
            self?.publicDatabase.save(shareRecord) { record, error in
                if let record = record {
                    completion(.success(record))
                } else {
                    completion(.failure(error ?? NSError(domain: "CloudKit", code: -1)))
                }
                
                // Clean up temp file
                if let tempURL = tempFileURL {
                    try? FileManager.default.removeItem(at: tempURL)
                }
            }
        }
    }
    
    func fetchFriendsDailyShares(for date: Date, completion: @escaping (Result<[FriendCircleData], Error>) -> Void) {
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
                                let sortedRecords = records.sorted {
                                    ($0.creationDate ?? Date.distantPast) > ($1.creationDate ?? Date.distantPast)
                                }
                                var friendShares: [String: CKRecord] = [:]
                                for record in sortedRecords {
                                    if let uid = record["userID"] as? String, friendShares[uid] == nil {
                                        friendShares[uid] = record
                                    }
                                }
                                
                                DispatchQueue.main.async {
                                    var combined: [FriendCircleData] = []
                                    for user in friendUsers {
                                        let uid = user["userID"] as? String ?? ""
                                        combined.append(FriendCircleData(user: user, share: friendShares[uid]))
                                    }
                                    
                                    // Sort: friends with shares first, then alphabetically
                                    combined.sort { a, b in
                                        if a.share != nil && b.share == nil { return true }
                                        if a.share == nil && b.share != nil { return false }
                                        let nameA = a.user["displayName"] as? String ?? ""
                                        let nameB = b.user["displayName"] as? String ?? ""
                                        return nameA < nameB
                                    }
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

        publicDatabase.fetch(withQuery: query, inZoneWith: nil,
                             desiredKeys: nil, resultsLimit: 1) { result in
            switch result {
            case .success(let (matches, _)):
                if let record = matches.compactMap({ try? $0.1.get() }).first {
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
    func fetchReceivedEmojiReactions(shareRecordName: String, completion: @escaping ([String]) -> Void) {
        guard let currentUserID = currentUser?["userID"] as? String else {
            completion([])
            return
        }

        let predicate = NSPredicate(format: "shareRecordName == %@ AND senderUserID != %@",
                                    shareRecordName, currentUserID)
        let query = CKQuery(recordType: "EmojiReaction", predicate: predicate)

        publicDatabase.fetch(withQuery: query, inZoneWith: nil,
                             desiredKeys: ["emoji"], resultsLimit: 50) { result in
            switch result {
            case .success(let (matchResults, _)):
                let emojis = matchResults.compactMap { try? $0.1.get() }.compactMap { $0["emoji"] as? String }
                DispatchQueue.main.async { completion(emojis) }
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
                        dateFmt.locale = Locale(identifier: "tr_TR")
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
