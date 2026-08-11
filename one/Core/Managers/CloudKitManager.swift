//
//  CloudKitManager.swift
//  one
//
//  Created for Circle feature
//

import Foundation
import CloudKit
import Combine
import Security

class CloudKitManager: ObservableObject {
    static let shared = CloudKitManager()
    
    /// v3: bir arkadaşın **o güne ait tüm anları**. `share` ilk an (entryIndex 0)
    /// — eski çağrı yerleri bozulmasın diye duruyor; kart ızgarası `shares`
    /// üzerinden "N an" ve çok renkli şeridi çiziyor.
    struct FriendCircleData: Identifiable {
        /// Stable across refreshes — `UUID()` her fetch'te değişip
        /// `ForEach` kimliğini kaydırıyordu.
        var id: String { user["userID"] as? String ?? user.recordID.recordName }
        let user: CKRecord
        let shares: [CKRecord]

        /// Günün ilk anı — tek-an varsayan eski okuma yolları için.
        var share: CKRecord? { shares.first }

        init(user: CKRecord, shares: [CKRecord]) {
            self.user = user
            self.shares = shares
        }

        init(user: CKRecord, share: CKRecord?) {
            self.user = user
            self.shares = share.map { [$0] } ?? []
        }
    }
    
    let container: CKContainer
    let privateDatabase: CKDatabase
    let publicDatabase: CKDatabase
    
    @Published var isCloudKitAvailable = false
    @Published var currentUser: CKRecord? {
        didSet {
            guard let record = currentUser,
                  let profile = PublicUserProfile(record: record) else { return }
            Task { @MainActor in
                UserProfileStore.shared.upsert(profile)
            }
        }
    }
    @Published var isFetchingUser = false
    /// `loadCurrentUser()` uçuşta mı. `isFetchingUser`'dan ayrı: o main'e
    /// async yazıldığı için reentrancy guard olarak kullanılamıyor.
    private var isLoadingCurrentUser = false
    @Published var userLoadFailed = false
    @Published var throttleRetryAfter: Date? = nil
    @Published var syncStatus: SyncStatus = .idle
    @Published var friendsSharedTodayCount: Int = 0
    /// Unseen friend shares — drives the Circle tab badge dot.
    /// Updated by CircleView whenever the unseen count changes.
    @Published var unseenFriendShareCount: Int = 0
    /// Bekleyen arkadaş isteği sayısı — üst bardaki istek ikonunun kor noktası
    /// bunu okuyor. `fetchPendingRequestCount` her çağrıda tazeliyor.
    @Published var pendingFriendRequestCount: Int = 0

    /// True if we're still within a CloudKit throttle window.
    var isThrottled: Bool {
        guard let retryAfter = throttleRetryAfter else { return false }
        return Date() < retryAfter
    }

    // MARK: - Circle cache
    /// In-memory cache for today's friends' shares. Invalidated at midnight or after 5 min.
    var cachedCircleData: [FriendCircleData]?
    var circleDataLastFetched: Date?
    private let circleCacheTTL: TimeInterval = 5 * 60 // 5 minutes

    // MARK: - Weekly circle cache (last 7 days, not tied to daily cache)
    var cachedWeeklyCircleData: [FriendCircleData]?
    var weeklyCircleDataLastFetched: Date?
    private let weeklyCircleCacheTTL: TimeInterval = 10 * 60 // 10 minutes

    var isWeeklyCircleCacheValid: Bool {
        guard let last = weeklyCircleDataLastFetched,
              cachedWeeklyCircleData != nil else { return false }
        return Date().timeIntervalSince(last) < weeklyCircleCacheTTL
    }

    func invalidateWeeklyCircleCache() {
        cachedWeeklyCircleData = nil
        weeklyCircleDataLastFetched = nil
    }

    // MARK: - Friend ID cache (for push notification fast-path)
    var cachedFriendIDs: Set<String> = []
    var cachedFriendIDsTimestamp: Date = .distantPast
    let friendCacheTTL: TimeInterval = 5 * 60 // 5 minutes

    var isCircleCacheValid: Bool {
        guard let last = circleDataLastFetched,
              let cached = cachedCircleData else { return false }
        // Invalidate at midnight
        let cacheDay  = Calendar.current.startOfDay(for: last)
        let today     = Calendar.current.startOfDay(for: Date())
        guard cacheDay == today else { return false }
        _ = cached
        return Date().timeIntervalSince(last) < circleCacheTTL
    }

    /// Ekrana **hemen** basılabilecek en son çevre verisi (varsa).
    ///
    /// `isCircleCacheValid` "ağa gitmem gerekiyor mu" sorusunu yanıtlıyor ve
    /// 5 dakikalık TTL uyguluyor. Bu ise farklı bir soruyu yanıtlıyor:
    /// "elimde bugüne ait, gösterebileceğim bir şey var mı?" Gün değişmediyse
    /// bayat veri de gösterilir — tazelemesi arkada koşar. Böylece Çevre
    /// sekmesi skeleton'ı yalnızca gerçekten hiçbir şey yokken gösterir.
    var circleCacheForDisplay: [FriendCircleData]? {
        guard let last = circleDataLastFetched, let cached = cachedCircleData else { return nil }
        guard Calendar.current.isDate(last, inSameDayAs: Date()) else { return nil }
        return cached
    }

    func invalidateCircleCache() {
        cachedCircleData = nil
        circleDataLastFetched = nil
    }

    func invalidateFriendCache() {
        cachedFriendIDs.removeAll()
        cachedFriendIDsTimestamp = .distantPast
    }
    
    enum SyncStatus {
        case idle
        case syncing
        case success
        case error(String)
    }
    
    private init() {
        // Launch contract: bu init Tier 0. Bütçe <30ms. Ağır iş için Tier 2/3'e
        // taşı (oneApp.body .onAppear). Regresyon guard'ı için defer'lı assert.
        let __initT0 = CFAbsoluteTimeGetCurrent()
        defer {
            let elapsed = CFAbsoluteTimeGetCurrent() - __initT0
            assert(elapsed < 0.03, "CloudKitManager.init > 30ms (\(Int(elapsed * 1000))ms) — added sync work?")
        }

        container = CKContainer(identifier: "iCloud.com.batu.ones")
        privateDatabase = container.privateCloudDatabase
        publicDatabase = container.publicCloudDatabase

        // Restore throttle window from previous session
        if let saved = UserDefaults.standard.object(forKey: "cloudKitThrottleRetryAfter") as? Date,
           saved > Date() {
            throttleRetryAfter = saved
            ONELogger.warning("CloudKit throttle restored — retry after \(saved)", category: .cloudkit)
        }

        // Cold start optimizasyonu: checkCloudKitAvailability() ve loadCurrentUser()
        // eskiden burada senkron çağrılıyordu. `@StateObject` construction'ı ilk
        // frame'den önce çalıştığı için iki hesap round-trip'i splash'a bindiriyordu.
        // Artık her ikisi de oneApp.body .onAppear'daki Tier 2 Task.detached'te
        // (userInitiated) çağrılıyor; init ucuz kalıyor.
    }
    
    // MARK: - Load Current User
    
    func loadCurrentUser() {
        // Reentrancy guard: init(), ContentView.checkProfileStatus(), retry
        // zamanlayıcısı ve CloudKitRetryOverlay hepsi bu metodu çağırıyor.
        // `isFetchingUser` main'e async yazıldığı için tek başına yeterli
        // değildi — aynı anda iki fetch turu atılıyordu.
        if isLoadingCurrentUser {
            ONELogger.debug("loadCurrentUser skipped — already in flight", category: .cloudkit)
            return
        }

        // Don't retry while server-side throttle is still active
        if isThrottled {
            let until = throttleRetryAfter.map { "\($0)" } ?? "unknown"
            ONELogger.warning("loadCurrentUser skipped — throttle active until \(until)", category: .cloudkit)
            return
        }

        // Throttle window has passed — clear persisted date
        if throttleRetryAfter != nil {
            throttleRetryAfter = nil
            UserDefaults.standard.removeObject(forKey: "cloudKitThrottleRetryAfter")
        }

        isLoadingCurrentUser = true

        DispatchQueue.main.async {
            self.isFetchingUser = true
            self.userLoadFailed = false
        }

        // Tek çıkış noktası — guard bayrağı ve isFetchingUser birlikte düşer.
        func finish(failed: Bool, user: CKRecord? = nil) {
            DispatchQueue.main.async {
                if let user { self.currentUser = user }
                self.isFetchingUser = false
                self.userLoadFailed = failed
                self.isLoadingCurrentUser = false
            }
        }

        container.fetchUserRecordID { [weak self] recordID, error in
            guard let self = self else { return }

            guard let recordID = recordID else {
                ONELogger.error("Could not fetch user record ID: \(error?.localizedDescription ?? "unknown")", category: .cloudkit)
                finish(failed: true)
                return
            }

            let userID = recordID.recordName

            // Check if custom User record exists in PUBLIC database
            let predicate = NSPredicate(format: "userID == %@", userID)
            let query = CKQuery(recordType: "AppUser", predicate: predicate)
            // Sort by createdDate ascending so the original profile is always picked first
            query.sortDescriptors = [NSSortDescriptor(key: "createdDate", ascending: true)]

            self.publicDatabase.fetch(withQuery: query, inZoneWith: nil, desiredKeys: nil, resultsLimit: CKQueryOperation.maximumResults) { result in
                switch result {
                case .success(let (matchResults, _)):
                    let records = matchResults.compactMap { try? $0.1.get() }
                    // Pick the oldest record — the user's real profile
                    if let existingUser = records.first {
                        ONELogger.success("Loaded existing user profile", category: .cloudkit)
                        finish(failed: false, user: existingUser)
                    } else {
                        ONELogger.info("No user profile found, will create one", category: .cloudkit)
                        finish(failed: false)
                    }
                case .failure(let error):
                    let nsError = error as NSError
                    if nsError.domain == CKErrorDomain && nsError.code == 12 {
                        // Schema not yet indexed — treat as "no user found" (new install)
                        ONELogger.info("User profile not found (this is normal for new users)", category: .cloudkit)
                        finish(failed: false)
                    } else {
                        // Real error (throttle, network, etc.) — do NOT proceed to profile creation
                        ONELogger.error("Failed to load user", error: error, category: .cloudkit)
                        self.handleThrottleError(error)
                        finish(failed: true)
                    }
                }
            }
        }
    }
    
    // MARK: - Ensure Current User is Loaded

    /// Waits until currentUser is non-nil, with a timeout.
    /// If currentUser is already loaded, returns immediately.
    /// If not yet loaded, triggers loadCurrentUser() and waits up to 10 seconds.
    @MainActor
    func ensureCurrentUser() async -> Bool {
        // Already loaded
        if currentUser != nil { return true }

        // Don't wait if CloudKit is throttled or already errored — fail fast
        if isThrottled || userLoadFailed {
            ONELogger.warning("ensureCurrentUser: skipped — throttled or load failed", category: .cloudkit)
            return false
        }

        // Trigger a load if not already fetching
        if !isFetchingUser {
            loadCurrentUser()
        }

        // Wait for currentUser using exponential backoff instead of busy-loop
        let maxWait: TimeInterval = 10
        var elapsed: TimeInterval = 0
        var interval: UInt64 = 500_000_000 // Start at 0.5s

        while currentUser == nil && elapsed < maxWait {
            // Bail early if throttle or error becomes known while waiting
            if isThrottled || userLoadFailed { break }
            do {
                try await Task.sleep(nanoseconds: interval)
            } catch {
                // Task was cancelled — propagate
                return false
            }
            elapsed += Double(interval) / 1_000_000_000
            interval = min(interval * 2, 2_000_000_000) // Cap at 2s
        }

        if currentUser == nil {
            ONELogger.warning("ensureCurrentUser: user unavailable (throttled=\(isThrottled) failed=\(userLoadFailed))", category: .cloudkit)
        }
        return currentUser != nil
    }

    // MARK: - CloudKit Availability

    func checkCloudKitAvailability() {
        container.accountStatus { [weak self] status, error in
            DispatchQueue.main.async {
                let isAvailable = (status == .available)
                self?.isCloudKitAvailable = isAvailable
                
                // Debug logging
                ONELogger.debug("CloudKit Status: \(self?.statusDescription(status) ?? "unknown") | Available: \(isAvailable)", category: .cloudkit)
                
                if let error = error {
                    ONELogger.error("CloudKit status check error", error: error, category: .cloudkit)
                }
                
                // Additional container info check
                self?.container.fetchUserRecordID { recordID, fetchError in
                    if recordID != nil {
                        ONELogger.debug("User record ID fetched", category: .cloudkit)
                    } else if let fetchError = fetchError {
                        ONELogger.error("Could not fetch user record", error: fetchError, category: .cloudkit)
                    }
                }
            }
        }
    }
    
    /// Parses a CKError.requestRateLimited / 503 throttle error and stores the retry-after date.
    func handleThrottleError(_ error: Error) {
        let nsError = error as NSError
        // CKError.Code.requestRateLimited = 7, serverRejectedRequest = 15
        // Retry-after comes in userInfo under CKErrorRetryAfterKey
        if let retryInterval = nsError.userInfo[CKErrorRetryAfterKey] as? TimeInterval {
            let retryDate = Date().addingTimeInterval(retryInterval)
            DispatchQueue.main.async {
                self.throttleRetryAfter = retryDate
                UserDefaults.standard.set(retryDate, forKey: "cloudKitThrottleRetryAfter")
            }
            ONELogger.warning("CloudKit throttled — retry after \(Int(retryInterval))s (\(retryDate))", category: .cloudkit)
            return
        }
        // Fallback: parse seconds from the error description string
        let desc = nsError.localizedDescription
        if let range = desc.range(of: #"Retry after (\d+(\.\d+)?) seconds"#, options: .regularExpression),
           let secsRange = desc.range(of: #"\d+(\.\d+)?"#, options: .regularExpression, range: range) {
            if let secs = TimeInterval(desc[secsRange]) {
                let retryDate = Date().addingTimeInterval(secs)
                DispatchQueue.main.async {
                    self.throttleRetryAfter = retryDate
                    UserDefaults.standard.set(retryDate, forKey: "cloudKitThrottleRetryAfter")
                }
                ONELogger.warning("CloudKit throttled (parsed) — retry after \(Int(secs))s", category: .cloudkit)
            }
        }
    }

    private func statusDescription(_ status: CKAccountStatus) -> String {
        switch status {
        case .available:
            return "Available"
        case .noAccount:
            return "No Account"
        case .restricted:
            return "Restricted"
        case .couldNotDetermine:
            return "Could Not Determine"
        case .temporarilyUnavailable:
            return "Temporarily Unavailable"
        @unknown default:
            return "Unknown"
        }
    }
    
    // MARK: - User Management
    
    func createOrFetchUser(displayName: String, completion: @escaping (Result<CKRecord, Error>) -> Void) {
        container.fetchUserRecordID { [weak self] recordID, error in
            guard let self = self, let recordID = recordID else {
                completion(.failure(error ?? NSError(domain: "CloudKit", code: -1, userInfo: [NSLocalizedDescriptionKey: "Could not fetch user record ID"])))
                return
            }
            
            let userID = recordID.recordName
            
            // Check if custom User record exists in PUBLIC database
            let predicate = NSPredicate(format: "userID == %@", userID)
            let query = CKQuery(recordType: "AppUser", predicate: predicate)
            query.sortDescriptors = [NSSortDescriptor(key: "createdDate", ascending: true)]

            self.publicDatabase.fetch(withQuery: query, inZoneWith: nil, desiredKeys: nil, resultsLimit: CKQueryOperation.maximumResults) { result in
                switch result {
                case .success(let (matchResults, _)):
                    let records = matchResults.compactMap { try? $0.1.get() }
                    if let existingUser = records.first {
                        // User exists — pick oldest (real profile, not a duplicate)
                        DispatchQueue.main.async {
                            self.currentUser = existingUser
                        }
                        completion(.success(existingUser))
                    } else {
                        // Create new user in PUBLIC database
                        self.createNewUser(userID: userID, displayName: displayName, completion: completion)
                    }
                case .failure(let queryError):
                    // Query failed — do NOT create a new user; propagate the error
                    // Creating on error risks duplicate AppUser records for the same iCloud account
                    ONELogger.error("createOrFetchUser query failed, not creating new user", error: queryError, category: .cloudkit)
                    completion(.failure(queryError))
                }
            }
        }
    }
    
    private func createNewUser(userID: String, displayName: String, completion: @escaping (Result<CKRecord, Error>) -> Void) {
        let inviteCode = generateInviteCode()
        
        // Check if invite code is unique (retry if not)
        checkAndCreateUser(userID: userID, displayName: displayName, inviteCode: inviteCode, retryCount: 0, completion: completion)
    }
    
    private func checkAndCreateUser(userID: String, displayName: String, inviteCode: String, retryCount: Int, completion: @escaping (Result<CKRecord, Error>) -> Void) {
        // Max 5 retries to find unique code
        guard retryCount < 5 else {
            completion(.failure(NSError(domain: "CloudKit", code: -1, userInfo: [NSLocalizedDescriptionKey: "Could not generate unique invite code"])))
            return
        }
        
        isInviteCodeUnique(inviteCode) { [weak self] isUnique in
            guard let self = self else { return }
            
            if isUnique {
                // Code is unique, create user
                let userRecord = CKRecord(recordType: "AppUser")
                userRecord["userID"] = userID as CKRecordValue
                userRecord["displayName"] = displayName as CKRecordValue
                userRecord["inviteCode"] = inviteCode as CKRecordValue
                userRecord["avatarColor"] = self.generateRandomColor() as CKRecordValue
                userRecord["isPublic"] = 0 as CKRecordValue
                userRecord["createdDate"] = Date() as CKRecordValue
                
                ONELogger.debug("Creating new user record", category: .cloudkit)
                
                // Use CKModifyRecordsOperation for PUBLIC database
                let operation = CKModifyRecordsOperation(recordsToSave: [userRecord], recordIDsToDelete: nil)
                operation.savePolicy = .allKeys
                operation.qualityOfService = .userInitiated
                
                operation.modifyRecordsResultBlock = { result in
                    switch result {
                    case .success:
                        ONELogger.success("User record created successfully", category: .cloudkit)
                        DispatchQueue.main.async {
                            self.currentUser = userRecord
                            ONELogger.debug("currentUser set in CloudKitManager", category: .cloudkit)
                        }
                        completion(.success(userRecord))
                    case .failure(let error):
                        ONELogger.error("Failed to create user", error: error, category: .cloudkit)
                        completion(.failure(error))
                    }
                }
                
                self.publicDatabase.add(operation)
            } else {
                // Code exists, generate new one and retry
                let newCode = self.generateInviteCode()
                self.checkAndCreateUser(userID: userID, displayName: displayName, inviteCode: newCode, retryCount: retryCount + 1, completion: completion)
            }
        }
    }
    
    // MARK: - Invite Code
    
    func generateInviteCode() -> String {
        let charset = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        let charsetCount = UInt32(charset.count)
        var result = ""
        for _ in 0..<6 {
            var randomValue: UInt32 = 0
            _ = SecRandomCopyBytes(kSecRandomDefault, 4, &randomValue)
            let index = charset.index(charset.startIndex, offsetBy: Int(randomValue % charsetCount))
            result.append(charset[index])
        }
        return result
    }
    
    private func generateRandomColor() -> String {
        let colors = [
            "#E84040", "#FF8C42", "#F5C842", "#4CAF82",
            "#5B8DEF", "#9B7FD4", "#E8334A", "#1DB954"
        ]
        return colors.randomElement() ?? "#4ECDC4"
    }
    
    // MARK: - Update User Profile
    
    func updateUserProfile(displayName: String, avatarColor: String, username: String? = nil, completion: @escaping (Result<CKRecord, Error>) -> Void) {
        guard let currentUser = currentUser else {
            ONELogger.error("No current user to update", category: .cloudkit)
            completion(.failure(NSError(domain: "CloudKit", code: -1, userInfo: [NSLocalizedDescriptionKey: "No current user"])))
            return
        }
        
        ONELogger.debug("Updating user profile", category: .cloudkit)
        
        // Update the current record directly (don't fetch again)
        currentUser["displayName"] = displayName as CKRecordValue
        currentUser["avatarColor"] = avatarColor as CKRecordValue
        if let username = username {
            currentUser["username"] = username.lowercased() as CKRecordValue
        }
        
        // Save with operation
        let operation = CKModifyRecordsOperation(recordsToSave: [currentUser], recordIDsToDelete: nil)
        operation.savePolicy = .changedKeys
        operation.qualityOfService = .userInitiated
        
        operation.modifyRecordsResultBlock = { [weak self] result in
            switch result {
            case .success:
                ONELogger.success("User profile updated", category: .cloudkit)
                DispatchQueue.main.async {
                    self?.currentUser = currentUser
                }
                completion(.success(currentUser))
            case .failure(let error):
                ONELogger.error("Failed to update user profile", error: error, category: .cloudkit)
                
                let nsError = error as NSError
                if nsError.domain == CKErrorDomain {
                    ONELogger.debug("CloudKit Error Code: \(nsError.code)", category: .cloudkit)
                    if nsError.code == 26 {
                        ONELogger.warning("Schema not deployed to Production", category: .cloudkit)
                    } else if nsError.code == 14 {
                        // Server record changed - fetch and retry
                        ONELogger.info("Server record changed, fetching latest version", category: .cloudkit)
                        self?.fetchAndRetryUpdate(displayName: displayName, avatarColor: avatarColor, username: username, completion: completion)
                        return
                    }
                }
                
                completion(.failure(error))
            }
        }
        
        publicDatabase.add(operation)
    }
    
    private func fetchAndRetryUpdate(displayName: String, avatarColor: String, username: String?, retryCount: Int = 0, completion: @escaping (Result<CKRecord, Error>) -> Void) {
        guard retryCount < 3 else {
            completion(.failure(NSError(domain: "CloudKit", code: 14, userInfo: [NSLocalizedDescriptionKey: "Server conflict persisted after 3 retries"])))
            return
        }
        guard let currentUser = currentUser else {
            completion(.failure(NSError(domain: "CloudKit", code: -1, userInfo: [NSLocalizedDescriptionKey: "No current user"])))
            return
        }

        // Exponential backoff delay before retry
        let delay = Double(retryCount) * 0.5
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            self?.publicDatabase.fetch(withRecordID: currentUser.recordID) { [weak self] fetchedRecord, error in
                guard let self = self, let fetchedRecord = fetchedRecord else {
                    completion(.failure(error ?? NSError(domain: "CloudKit", code: -1)))
                    return
                }

                // Update fetched record
                fetchedRecord["displayName"] = displayName as CKRecordValue
                fetchedRecord["avatarColor"] = avatarColor as CKRecordValue
                if let username = username {
                    fetchedRecord["username"] = username.lowercased() as CKRecordValue
                }

                // Update currentUser reference
                DispatchQueue.main.async {
                    self.currentUser = fetchedRecord
                }

                // Save again
                self.saveRecordWithOperation(fetchedRecord, completion: completion)
            }
        }
    }
    
    private func saveRecordWithOperation(_ record: CKRecord, completion: @escaping (Result<CKRecord, Error>) -> Void) {
        // Use CKModifyRecordsOperation with changedKeys policy
        let operation = CKModifyRecordsOperation(recordsToSave: [record], recordIDsToDelete: nil)
        operation.savePolicy = .changedKeys  // Only update changed fields
        operation.qualityOfService = .userInitiated
        
        operation.modifyRecordsResultBlock = { [weak self] result in
            switch result {
            case .success:
                ONELogger.success("User profile updated (retry)", category: .cloudkit)
                DispatchQueue.main.async {
                    self?.currentUser = record
                }
                completion(.success(record))
            case .failure(let error):
                ONELogger.error("Failed to update user profile (retry)", error: error, category: .cloudkit)
                
                // Check if it's a schema error
                let nsError = error as NSError
                if nsError.domain == CKErrorDomain {
                    ONELogger.debug("CloudKit Error Code: \(nsError.code)", category: .cloudkit)
                    if nsError.code == 26 {
                        ONELogger.warning("Schema not deployed to Production. Deploy via CloudKit Dashboard.", category: .cloudkit)
                    } else if nsError.code == 10 {
                        ONELogger.warning("CREATE not permitted — record may not exist in CloudKit", category: .cloudkit)
                    }
                }
                
                completion(.failure(error))
            }
        }
        
        publicDatabase.add(operation)
    }
    
    func findUserByInviteCode(_ code: String, completion: @escaping (Result<CKRecord, Error>) -> Void) {
        ONELogger.debug("Searching for user by invite code", category: .cloudkit)
        
        let predicate = NSPredicate(format: "inviteCode == %@", code)
        let query = CKQuery(recordType: "AppUser", predicate: predicate)
        
        // Search in PUBLIC database (where all users are)
        publicDatabase.fetch(withQuery: query, inZoneWith: nil, desiredKeys: nil, resultsLimit: CKQueryOperation.maximumResults) { result in
            switch result {
            case .success(let (matchResults, _)):
                let records = matchResults.compactMap { try? $0.1.get() }
                ONELogger.debug("Invite code lookup: \(records.count) result(s)", category: .cloudkit)

                if let record = records.first {
                    ONELogger.success("User lookup by invite code succeeded", category: .cloudkit)
                    completion(.success(record))
                } else {
                    ONELogger.info("No user found with provided invite code", category: .cloudkit)
                    completion(.failure(NSError(domain: "CloudKit", code: 404, userInfo: [NSLocalizedDescriptionKey: "User not found"])))
                }
            case .failure(let error):
                let nsError = error as NSError
                // CKError code 12 = "Invalid Arguments" which can happen with system types
                // But for our custom Users type, this shouldn't happen
                if nsError.domain == CKErrorDomain && nsError.code == 12 {
                    ONELogger.warning("CloudKit query validation error — ensure 'AppUser' record type and 'inviteCode' index exist", category: .cloudkit)
                } else {
                    ONELogger.error("CloudKit query error", error: error, category: .cloudkit)
                }
                completion(.failure(error))
            }
        }
    }
    
    func findUserByUsername(_ username: String, completion: @escaping (Result<CKRecord, Error>) -> Void) {
        let normalizedUsername = username.lowercased().trimmingCharacters(in: .whitespaces)
        ONELogger.debug("Searching for user by username", category: .cloudkit)
        
        let predicate = NSPredicate(format: "username == %@", normalizedUsername)
        let query = CKQuery(recordType: "AppUser", predicate: predicate)
        
        publicDatabase.fetch(withQuery: query, inZoneWith: nil, desiredKeys: nil, resultsLimit: CKQueryOperation.maximumResults) { result in
            switch result {
            case .success(let (matchResults, _)):
                let records = matchResults.compactMap { try? $0.1.get() }
                ONELogger.debug("Username lookup: \(records.count) result(s)", category: .cloudkit)

                if let record = records.first {
                    ONELogger.success("User lookup by username succeeded", category: .cloudkit)
                    completion(.success(record))
                } else {
                    ONELogger.info("No user found with provided username", category: .cloudkit)
                    completion(.failure(NSError(domain: "CloudKit", code: 404, userInfo: [NSLocalizedDescriptionKey: "User not found"])))
                }
            case .failure(let error):
                ONELogger.error("CloudKit query error", error: error, category: .cloudkit)
                completion(.failure(error))
            }
        }
    }
    
    func findUserByCodeOrUsername(_ searchText: String, completion: @escaping (Result<CKRecord, Error>) -> Void) {
        let trimmed = String(searchText.trimmingCharacters(in: .whitespaces).prefix(40))
        
        // If starts with @, search by username
        if trimmed.hasPrefix("@") {
            let username = String(trimmed.dropFirst())
            findUserByUsername(username, completion: completion)
        } else if trimmed.count == 6 && trimmed.allSatisfy({ $0.isLetter || $0.isNumber }) {
            // Looks like invite code (6 chars, alphanumeric)
            findUserByInviteCode(trimmed.uppercased(), completion: completion)
        } else {
            // Try username first, then invite code
            findUserByUsername(trimmed) { result in
                switch result {
                case .success(let record):
                    completion(.success(record))
                case .failure:
                    // Try invite code as fallback
                    self.findUserByInviteCode(trimmed.uppercased(), completion: completion)
                }
            }
        }
    }
    
    // MARK: - Invite Code Uniqueness Check
    
    private func isInviteCodeUnique(_ code: String, completion: @escaping (Bool) -> Void) {
        findUserByInviteCode(code) { result in
            switch result {
            case .success:
                completion(false)
            case .failure(let error):
                let nsError = error as NSError
                if nsError.domain == "CloudKit" && nsError.code == 404 {
                    // Record not found — code is genuinely unique
                    completion(true)
                } else {
                    // Real network/CloudKit error — treat as not unique to prevent duplicate codes
                    ONELogger.warning("isInviteCodeUnique: CloudKit error, defaulting to not-unique for safety", category: .cloudkit)
                    completion(false)
                }
            }
        }
    }
    
    // MARK: - Username Management
    
    func checkUsernameAvailability(_ username: String, excludingCurrentUser: Bool = false, completion: @escaping (Result<Bool, Error>) -> Void) {
        let normalizedUsername = username.lowercased().trimmingCharacters(in: .whitespaces)
        
        guard !normalizedUsername.isEmpty else {
            completion(.success(false))
            return
        }
        
        ONELogger.debug("Checking username availability", category: .cloudkit)
        
        let predicate = NSPredicate(format: "username == %@", normalizedUsername)
        let query = CKQuery(recordType: "AppUser", predicate: predicate)
        
        publicDatabase.fetch(withQuery: query, inZoneWith: nil, desiredKeys: nil, resultsLimit: CKQueryOperation.maximumResults) { [weak self] result in
            switch result {
            case .success(let (matchResults, _)):
                let records = matchResults.compactMap { try? $0.1.get() }
                
                if excludingCurrentUser, let currentUserID = self?.currentUser?.recordID.recordName {
                    // Filter out current user's record
                    let otherUsers = records.filter { $0.recordID.recordName != currentUserID }
                    let isAvailable = otherUsers.isEmpty
                    ONELogger.debug(isAvailable ? "Username available" : "Username taken by another user", category: .cloudkit)
                    completion(.success(isAvailable))
                } else {
                    let isAvailable = records.isEmpty
                    ONELogger.debug(isAvailable ? "Username available" : "Username already taken", category: .cloudkit)
                    completion(.success(isAvailable))
                }
                
            case .failure(let error):
                let nsError = error as NSError
                // CKError code 12 = "Invalid Arguments" - schema not ready yet
                if nsError.domain == CKErrorDomain && nsError.code == 12 {
                    ONELogger.warning("Username field not queryable yet (schema not deployed). Allowing for now.", category: .cloudkit)
                    // Allow the username for now - schema will be created after first user
                    completion(.success(true))
                } else {
                    ONELogger.error("Username check error", error: error, category: .cloudkit)
                    // On error, fail closed to prevent duplicate usernames
                    completion(.failure(error))
                }
            }
        }
    }
    
    func validateUsername(_ username: String) -> (isValid: Bool, error: String?) {
        let trimmed = username.trimmingCharacters(in: .whitespaces)
        
        // Length check
        if trimmed.count < 3 {
            return (false, "En az 3 karakter olmalı")
        }
        
        if trimmed.count > 20 {
            return (false, "En fazla 20 karakter olabilir")
        }
        
        // Character check: only letters, numbers, underscore
        let allowedCharacters = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_"))
        if trimmed.unicodeScalars.contains(where: { !allowedCharacters.contains($0) }) {
            return (false, "Sadece harf, rakam ve _ kullanılabilir")
        }
        
        // Must start with letter
        if let firstChar = trimmed.first, !firstChar.isLetter {
            return (false, "Harf ile başlamalı")
        }
        
        return (true, nil)
    }
    
    // MARK: - Account Deletion

    /// App Store Privacy 5.1.1 + KVKK: Kullanıcıya ait tüm CloudKit kayıtlarını siler.
    /// DailyShare, Friendship, UserBlock, Comment, AppUser — tüm record type'lar temizlenir.
    func deleteAllUserData(userID: String) async {
        let recordTypes: [(type: String, field: String)] = [
            ("DailyShare",     "userID"),
            ("Friendship",     "user1ID"),
            ("Friendship",     "user2ID"),
            ("UserBlock",      "blockerUserID"),
            ("UserBlock",      "blockedUserID"),
            ("Comment",        "authorUserID"),
            ("Resonance",      "senderID"),
            ("Resonance",      "receiverID"),
            ("ContentReport",  "reporterUserID"),
            ("SubCircle",      "ownerID"),
        ]

        for (recordType, field) in recordTypes {
            let predicate = NSPredicate(format: "%K == %@", field, userID)
            let query = CKQuery(recordType: recordType, predicate: predicate)
            do {
                let (results, _) = try await publicDatabase.records(matching: query, desiredKeys: [])
                let ids = results.compactMap { try? $0.1.get().recordID }
                if ids.isEmpty { continue }
                let batchSize = 400
                for batch in stride(from: 0, to: ids.count, by: batchSize) {
                    let chunk = Array(ids[batch..<min(batch + batchSize, ids.count)])
                    _ = try? await publicDatabase.modifyRecords(saving: [], deleting: chunk)
                }
                ONELogger.success("Deleted \(ids.count) \(recordType)(\(field)) records", category: .cloudkit)
            } catch {
                ONELogger.error("Failed to delete \(recordType)(\(field))", error: error, category: .cloudkit)
                CrashReporter.shared.capture(error: error, context: ["operation": "deleteUserData", "recordType": recordType])
            }
        }

        // Son olarak AppUser kaydını sil
        if let record = currentUser {
            _ = try? await publicDatabase.deleteRecord(withID: record.recordID)
        }
        await MainActor.run { currentUser = nil }
    }

    // MARK: - Premium Status Sync

    /// Writes the user's ONE+ premium status to their public AppUser record in CloudKit
    /// so that friends can display the premium badge when viewing their profile/today card.
    func updatePremiumStatus(_ isPremium: Bool) async {
        guard PremiumManager.premiumEnabled else { return }
        guard let record = currentUser else { return }
        record["isPremium"] = Int64(isPremium ? 1 : 0) as CKRecordValue
        do {
            let updated = try await publicDatabase.save(record)
            await MainActor.run { self.currentUser = updated }
            ONELogger.success("CloudKit premium status synced: \(isPremium)", category: .cloudkit)
        } catch {
            ONELogger.error("Failed to sync premium status to CloudKit", error: error, category: .cloudkit)
            CrashReporter.shared.capture(error: error, context: ["operation": "syncPremiumStatus"])
        }
    }

    // MARK: - Helper Functions
    // Friendship management: see CloudKitFriendshipService.swift
    // Daily share management: see CloudKitDailyShareService.swift
}
