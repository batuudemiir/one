//
//  ProfileViewModel.swift
//  one
//
//  ViewModel for ProfileView, handling all business logic, state, and data fetching.
//  Extracted as part of Faz 3 decomposition.
//

import SwiftUI
import CloudKit
import MusicKit
import CoreData
import PhotosUI
import Combine
import UserNotifications


final class ProfileViewModel: ObservableObject {
    // MARK: - Dependencies
    private let cloudKitManager = CloudKitManager.shared
    let spotifyManager = SpotifyManager.shared
    let notificationManager = NotificationManager.shared

    // MARK: - Profile Data
    @Published var displayName: String = ""
    @Published var username: String = ""
    @Published var selectedAvatarColor: String = "#5B8DEF"
    @Published var profileImage: UIImage? = nil
    @Published var selectedPhotoItem: PhotosPickerItem? = nil

    /// Profile redesign — friend count chip için canlı sayı.
    /// İlk render `EngagementTracker.lastKnownFriendCount`'tan başlar,
    /// `loadFriendCount()` CloudKit'ten taze değer çeker.
    @Published var friendCount: Int = EngagementTracker.lastKnownFriendCount
    /// CloudKit'ten arkadaş sayısı çekilirken UI inline spinner göstersin.
    @Published var isRefreshingFriendCount: Bool = false
    /// Her `loadFriendCount()` çağrısında artırılır; callback dönene
    /// kadar sayaç değiştiyse (yeni istek başladı) eski sonuç atılır.
    /// `checkUsernameAvailability` pattern'iyle aynı: concurrent
    /// fetch'ler eski değerin taze değerin üstüne yazmasını engeller.
    private var friendCountGeneration: Int = 0

    // MARK: - UI States
    @Published var isLoading = false
    @Published var showSuccess = false
    @Published var errorMessage: String?
    @Published var isEditMode = false
    @Published var isEditingFromTab = false
    @Published var profilePhotoZoomed = false
    @Published var isUploadingPhoto = false

    // MARK: - Validation
    @Published var usernameValidationMessage: String?
    @Published var isUsernameAvailable: Bool?
    @Published var isCheckingUsername = false
    private var usernameCheckTask: Task<Void, Never>?
    /// Her yeni check'te artırılır; callback dönene kadar sayaç değiştiyse sonuç atılır.
    private var usernameCheckGeneration: Int = 0

    // MARK: - Settings (AppStorage mirrors)
    @Published var dailyReminderHour: Int {
        didSet {
            UserDefaults.standard.set(dailyReminderHour, forKey: "dailyReminderHour")
            writeSettingToICloud(key: "dailyReminderHour", value: dailyReminderHour)
        }
    }
    @Published var dailyReminderMinute: Int {
        didSet {
            UserDefaults.standard.set(dailyReminderMinute, forKey: "dailyReminderMinute")
            writeSettingToICloud(key: "dailyReminderMinute", value: dailyReminderMinute)
        }
    }
    @Published var notificationsEnabled: Bool {
        didSet {
            UserDefaults.standard.set(notificationsEnabled, forKey: "notificationsEnabled")
            (UserDefaults(suiteName: "group.com.batudemir.ones") ?? .standard).set(notificationsEnabled, forKey: "notificationsEnabled")
            writeSettingToICloud(key: "notificationsEnabled", value: notificationsEnabled)
        }
    }
    @Published var streakNotificationsEnabled: Bool {
        didSet {
            UserDefaults.standard.set(streakNotificationsEnabled, forKey: "streakNotificationsEnabled")
            writeSettingToICloud(key: "streakNotificationsEnabled", value: streakNotificationsEnabled)
        }
    }
    @Published var weeklySummaryEnabled: Bool {
        didSet {
            UserDefaults.standard.set(weeklySummaryEnabled, forKey: "weeklySummaryEnabled")
            writeSettingToICloud(key: "weeklySummaryEnabled", value: weeklySummaryEnabled)
        }
    }
    @Published var hapticFeedbackEnabled: Bool {
        didSet {
            UserDefaults.standard.set(hapticFeedbackEnabled, forKey: "hapticFeedbackEnabled")
            writeSettingToICloud(key: "hapticFeedbackEnabled", value: hapticFeedbackEnabled)
        }
    }
    @Published var isDarkMode: Bool {
        didSet {
            UserDefaults.standard.set(isDarkMode, forKey: "isDarkMode")
            writeSettingToICloud(key: "isDarkMode", value: isDarkMode)
        }
    }
    @Published var preferredCity: String {
        didSet { UserDefaults.standard.set(preferredCity, forKey: ONEConfig.cityPreferenceKey) }
    }

    // MARK: - Pinned Song
    @Published var pinnedSong: PinnedSong?

    private var cancellables = Set<AnyCancellable>()

    // MARK: - v2.6 Privacy
    /// Müzik zevki (top tracks/artists/genre) arkadaşların profilimde görsün mü?
    @Published var musicTasteVisibleToFriends: Bool {
        didSet { UserDefaults.standard.set(musicTasteVisibleToFriends, forKey: "privacy.musicTasteVisible") }
    }
    /// Mood geçmişi grid'i arkadaşların profilimde görsün mü?
    @Published var moodHistoryVisibleToFriends: Bool {
        didSet { UserDefaults.standard.set(moodHistoryVisibleToFriends, forKey: "privacy.moodHistoryVisible") }
    }

    @Published var dailyReminderTime: Date = Date()
    @Published var appleMusicStatus: MusicAuthorization.Status = .notDetermined

    init() {
        // Initialize AppStorage mirrors
        let ud = UserDefaults.standard
        dailyReminderHour = ud.integer(forKey: "dailyReminderHour") == 0 ? 20 : ud.integer(forKey: "dailyReminderHour")
        dailyReminderMinute = ud.integer(forKey: "dailyReminderMinute")
        notificationsEnabled = ud.oneNotificationsEnabled
        streakNotificationsEnabled = ud.object(forKey: "streakNotificationsEnabled") == nil ? true : ud.bool(forKey: "streakNotificationsEnabled")
        weeklySummaryEnabled = ud.object(forKey: "weeklySummaryEnabled") == nil ? true : ud.bool(forKey: "weeklySummaryEnabled")
        hapticFeedbackEnabled = ud.object(forKey: "hapticFeedbackEnabled") == nil ? true : ud.bool(forKey: "hapticFeedbackEnabled")
        isDarkMode = ud.bool(forKey: "isDarkMode")
        
        let city = ud.string(forKey: ONEConfig.cityPreferenceKey) ?? ONEConfig.defaultCity
        preferredCity = city == "İzmit" ? "Kocaeli" : city

        // v2.6 — Privacy defaults: ON for friends (plana göre).
        musicTasteVisibleToFriends = ud.object(forKey: "privacy.musicTasteVisible") == nil ? true : ud.bool(forKey: "privacy.musicTasteVisible")
        moodHistoryVisibleToFriends = ud.object(forKey: "privacy.moodHistoryVisible") == nil ? true : ud.bool(forKey: "privacy.moodHistoryVisible")

        // iCloud KV store'dan ayarları geri yükle (ilk kurulumdan sonra)
        syncSettingsFromICloud()

        // CloudKit user yüklenince pinned song'u güncelle (race condition fix)
        cloudKitManager.$currentUser
            .receive(on: DispatchQueue.main)
            .compactMap { $0 }
            .sink { [weak self] user in
                guard let self else { return }
                let json = user["pinnedSongData"] as? String ?? ""
                let loaded = PinnedSong.fromJSONString(json)
                if self.pinnedSong == nil {
                    self.pinnedSong = loaded
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - Computed Properties
    let avatarColors = [
        "#5B8DEF", "#E84040", "#4CAF82", "#F59E0B",
        "#8B5CF6", "#EC4899", "#10B981", "#F97316"
    ]

    var inviteCode: String {
        cloudKitManager.currentUser?["inviteCode"] as? String ?? "------"
    }
    
    var existingName: String {
        cloudKitManager.currentUser?["displayName"] as? String ?? ""
    }
    
    var existingUsername: String {
        cloudKitManager.currentUser?["username"] as? String ?? ""
    }
    
    var existingColor: String {
        cloudKitManager.currentUser?["avatarColor"] as? String ?? "#5B8DEF"
    }
    
    var hasExistingProfile: Bool {
        KeychainHelper.completionFlag(forKey: "hasCreatedProfile") && cloudKitManager.currentUser != nil
    }
    
    var canSaveProfile: Bool {
        !displayName.isEmpty && displayName.count <= 50
    }

    // MARK: - Methods

    // MARK: - Pinned Song

    func setPinnedSong(_ song: PinnedSong?) {
        self.pinnedSong = song
        Task {
            try? await cloudKitManager.updatePinnedSong(song)
            // Tüm yüzeyler (yorumlar, public profile, kartlar) anında tazelensin
            await MainActor.run { UserProfileStore.shared.invalidateCurrentUser() }
        }
    }

    // MARK: - Friend Count

    /// Profile redesign — CloudKit'ten taze arkadaş sayısı çek.
    /// Hata durumunda mevcut snapshot'ı korur.
    /// Concurrent invocation guard: aynı anda birden fazla fetch
    /// başlarsa geç dönen callback erken dönen callback'in yazdığı
    /// taze değeri ezmez — generation counter'la sırayı kontrol ederiz.
    func loadFriendCount() {
        // Re-entrance guard: zaten uçuşta olan bir istek varsa
        // (spinner açık) yeni bir tur açmayalım.
        guard !isRefreshingFriendCount else { return }
        friendCountGeneration += 1
        let myGeneration = friendCountGeneration
        DispatchQueue.main.async { self.isRefreshingFriendCount = true }
        cloudKitManager.fetchFriends { [weak self] result in
            guard let self else { return }
            DispatchQueue.main.async {
                // Bu callback dönene kadar yeni bir fetch başlatıldıysa
                // sonucu at — taze fetch'in çıktısını ezmesin.
                guard self.friendCountGeneration == myGeneration else { return }
                self.isRefreshingFriendCount = false
                if case .success(let friends) = result {
                    self.friendCount = friends.count
                    EngagementTracker.lastKnownFriendCount = friends.count
                }
            }
        }
    }

    func loadExistingProfile() {
        if !existingName.isEmpty {
            displayName = existingName
            isEditMode = true
        }
        if !existingUsername.isEmpty {
            username = existingUsername
            isUsernameAvailable = true
        }
        selectedAvatarColor = existingColor
        profileImage = Self.loadProfilePhotoFromDisk()

        var components = DateComponents()
        components.hour = dailyReminderHour
        components.minute = dailyReminderMinute
        if let date = Calendar.current.date(from: components) {
            dailyReminderTime = date
        }

        if cloudKitManager.currentUser != nil {
            isEditMode = true
            let pinnedJSON = cloudKitManager.currentUser?["pinnedSongData"] as? String ?? ""
            self.pinnedSong = PinnedSong.fromJSONString(pinnedJSON)
        }
    }

    func checkUsernameAvailability(_ newUsername: String) {
        let clean = newUsername.trimmingCharacters(in: .whitespacesAndNewlines)
        usernameValidationMessage = nil
        isUsernameAvailable = nil
        
        usernameCheckTask?.cancel()
        
        if clean.isEmpty {
            isCheckingUsername = false
            return
        }
        
        if clean.count < 3 {
            usernameValidationMessage = NSLocalizedString("profile.usernameTooShort", comment: "")
            isUsernameAvailable = false
            isCheckingUsername = false
            return
        }
        
        if !clean.allSatisfy({ $0.isLetter || $0.isNumber || $0 == "_" }) {
            usernameValidationMessage = NSLocalizedString("profile.usernameInvalidFormat", comment: "")
            isUsernameAvailable = false
            isCheckingUsername = false
            return
        }

        if isEditMode && clean == existingUsername {
            usernameValidationMessage = NSLocalizedString("profile.usernameCurrent", comment: "")
            isUsernameAvailable = true
            isCheckingUsername = false
            return
        }
        
        usernameCheckTask?.cancel()
        usernameCheckGeneration += 1
        let myGeneration = usernameCheckGeneration

        usernameCheckTask = Task { @MainActor in
            isCheckingUsername = true
            try? await Task.sleep(nanoseconds: 500_000_000)
            guard !Task.isCancelled else { isCheckingUsername = false; return }

            cloudKitManager.checkUsernameAvailability(clean, excludingCurrentUser: isEditMode) { [weak self] result in
                DispatchQueue.main.async {
                    // Sonuç gelene kadar yeni bir check başlatıldıysa bu callback'i yoksay
                    guard let self, self.usernameCheckGeneration == myGeneration else { return }
                    self.isCheckingUsername = false
                    switch result {
                    case .success(let isAvailable):
                        self.isUsernameAvailable = isAvailable
                        self.usernameValidationMessage = isAvailable
                            ? NSLocalizedString("profile.usernameAvailable", comment: "")
                            : NSLocalizedString("profile.usernameTaken", comment: "")
                    case .failure(let error):
                        ONELogger.error("Username check failed: \(error.localizedDescription)", category: .profile)
                        self.usernameValidationMessage = NSLocalizedString("profile.usernameCheckFailed", comment: "")
                    }
                }
            }
        }
    }

    func saveProfile(completion: @escaping (Bool) -> Void) {
        guard !displayName.isEmpty else { return }
        isLoading = true
        errorMessage = nil
        
        if cloudKitManager.currentUser != nil {
            let usernameToSave = username.isEmpty ? nil : username
            cloudKitManager.updateUserProfile(displayName: displayName, avatarColor: selectedAvatarColor, username: usernameToSave) { [weak self] result in
                DispatchQueue.main.async {
                    self?.isLoading = false
                    switch result {
                    case .success:
                        self?.showSuccess = true
                        KeychainHelper.set(true, forKey: "hasCreatedProfile")
                        UserProfileStore.shared.invalidateCurrentUser()
                        completion(true)
                    case .failure(let error):
                        let nsError = error as NSError
                        self?.errorMessage = nsError.domain == "CKErrorDomain" && nsError.code == 26
                            ? "CloudKit schema deploy edilmemiş."
                            : "Kaydedilemedi: \(error.localizedDescription)"
                        completion(false)
                    }
                }
            }
        } else {
            cloudKitManager.createOrFetchUser(displayName: displayName) { [weak self] result in
                DispatchQueue.main.async {
                    switch result {
                    case .success:
                        let usernameToSave = self?.username.isEmpty == true ? nil : self?.username
                        self?.cloudKitManager.updateUserProfile(displayName: self?.displayName ?? "", avatarColor: self?.selectedAvatarColor ?? "", username: usernameToSave) { updateResult in
                            DispatchQueue.main.async {
                                self?.isLoading = false
                                switch updateResult {
                                case .success(let record):
                                    self?.showSuccess = true
                                    KeychainHelper.set(true, forKey: "hasCreatedProfile")
                                    if self?.cloudKitManager.currentUser == nil {
                                        self?.cloudKitManager.currentUser = record
                                    }
                                    UserProfileStore.shared.invalidateCurrentUser()
                                    // Kurulum sırasında seçilen fotoğraf
                                    // kuyrukta bekliyorsa şimdi yükle —
                                    // AppUser kaydı artık var.
                                    self?.flushPendingProfilePhotoUpload()
                                    completion(true)
                                case .failure(let error):
                                    let nsError = error as NSError
                                    self?.errorMessage = nsError.domain == "CKErrorDomain" && nsError.code == 26
                                        ? "CloudKit schema deploy edilmemiş."
                                        : "Kaydedilemedi: \(error.localizedDescription)"
                                    completion(false)
                                }
                            }
                        }
                    case .failure(let error):
                        self?.isLoading = false
                        self?.errorMessage = "Oluşturulamadı: \(error.localizedDescription)"
                        completion(false)
                    }
                }
            }
        }
    }

    // MARK: - Profile Photo Helper
    func loadAndSaveProfilePhoto(from item: PhotosPickerItem) async {
        DispatchQueue.main.async { self.isUploadingPhoto = true }
        do {
            if let data = try await item.loadTransferable(type: Data.self),
               let uiImage = UIImage(data: data) {
                
                let maxDim: CGFloat = 800
                var targetSize = uiImage.size
                if targetSize.width > maxDim || targetSize.height > maxDim {
                    let ratio = targetSize.width / targetSize.height
                    if ratio > 1 {
                        targetSize = CGSize(width: maxDim, height: maxDim / ratio)
                    } else {
                        targetSize = CGSize(width: maxDim * ratio, height: maxDim)
                    }
                }
                
                let renderer = UIGraphicsImageRenderer(size: targetSize)
                let resizedImage = renderer.image { _ in
                    uiImage.draw(in: CGRect(origin: .zero, size: targetSize))
                }
                
                if let jpegData = resizedImage.jpegData(compressionQuality: 0.7) {
                    saveProfilePhotoToDisk(data: jpegData)
                    DispatchQueue.main.async {
                        self.profileImage = UIImage(data: jpegData)
                    }
                }
            }
        } catch {
            ONELogger.error("Fotoğraf yükleme hatası: \(error.localizedDescription)", category: .profile)
        }
        DispatchQueue.main.async { self.isUploadingPhoto = false }
    }
    
    private func saveProfilePhotoToDisk(data: Data) {
        let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("profile_photo.jpg")
        try? data.write(to: url)
        NotificationCenter.default.post(name: .profilePhotoDidChange, object: nil)
        // CloudKit'e yükle ki yorumlar ve çevre güncel fotoğrafı görsün
        uploadProfilePhotoToCloudKit(data: data)
        // Profil değişikliğini tüm yüzeylere yay
        UserProfileStore.shared.invalidateCurrentUser()
    }

    /// AppUser kaydı henüz yokken seçilen fotoğraf. Kayıt oluşur oluşmaz
    /// yüklenir — eskiden `guard` sessizce dönüyordu ve profil kurulumu
    /// sırasında seçilen fotoğraf **hiçbir zaman** CloudKit'e gitmiyordu.
    private static var pendingPhotoUpload: Data?

    /// `currentUser` oluştuktan sonra çağrılır (createOrFetchUser / login).
    func flushPendingProfilePhotoUpload() {
        guard let data = Self.pendingPhotoUpload else { return }
        Self.pendingPhotoUpload = nil
        uploadProfilePhotoToCloudKit(data: data)
    }

    private func uploadProfilePhotoToCloudKit(data: Data) {
        guard let record = cloudKitManager.currentUser else {
            // Kaydı bekle — kullanıcı fotoğrafı seçtiği anda AppUser henüz
            // yaratılmamış olabilir (ilk kurulum akışı).
            Self.pendingPhotoUpload = data
            ONELogger.info("Profil fotoğrafı kuyruğa alındı — AppUser henüz yok", category: .profile)
            return
        }
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".jpg")
        do {
            try data.write(to: tempURL)
        } catch { return }
        record["profilePhoto"] = CKAsset(fileURL: tempURL)
        let op = CKModifyRecordsOperation(recordsToSave: [record], recordIDsToDelete: nil)
        op.savePolicy = .changedKeys
        op.qualityOfService = .userInitiated
        op.modifyRecordsResultBlock = { [weak self] result in
            try? FileManager.default.removeItem(at: tempURL)
            guard case .success = result else { return }
            // Always mutate @Published properties and ObservableObject state on main.
            Task { @MainActor [weak self] in
                self?.cloudKitManager.currentUser = record
                UserProfileStore.shared.invalidateCurrentUser()
            }
        }
        cloudKitManager.publicDatabase.add(op)
    }
    
    static func loadProfilePhotoFromDisk() -> UIImage? {
        let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("profile_photo.jpg")
        if let data = try? Data(contentsOf: url) {
            return UIImage(data: data)
        }
        return nil
    }

    // MARK: - iCloud Settings Sync

    private static let icloudKeys: [String] = [
        "dailyReminderHour", "dailyReminderMinute",
        "notificationsEnabled", "streakNotificationsEnabled",
        "weeklySummaryEnabled",
        "hapticFeedbackEnabled", "isDarkMode",
        "privacy.musicTasteVisible", "privacy.moodHistoryVisible"
    ]

    /// synchronize() returns false when the ubiquity-kvstore entitlement is missing.
    /// Bir kez ölçülüp saklanıyor: her ayar yazımında synchronize() çağırmak
    /// hem gereksiz I/O hem de entitlement yoksa her seferinde konsola
    /// "BUG IN CLIENT OF KVS" satırı basıyordu.
    private static let iCloudStoreAvailableCached: Bool = NSUbiquitousKeyValueStore.default.synchronize()

    private var iCloudStoreAvailable: Bool { Self.iCloudStoreAvailableCached }

    func syncSettingsFromICloud() {
        guard iCloudStoreAvailable else { return }
        let store = NSUbiquitousKeyValueStore.default
        let ud = UserDefaults.standard
        for key in Self.icloudKeys {
            if let value = store.object(forKey: "one.\(key)") {
                if ud.object(forKey: key) == nil {
                    ud.set(value, forKey: key)
                }
            }
        }
    }

    func writeSettingToICloud(key: String, value: Any) {
        guard iCloudStoreAvailable else { return }
        let store = NSUbiquitousKeyValueStore.default
        store.set(value, forKey: "one.\(key)")
        store.synchronize()
    }

    func syncAllSettingsToICloud() {
        guard iCloudStoreAvailable else { return }
        let ud = UserDefaults.standard
        let store = NSUbiquitousKeyValueStore.default
        for key in Self.icloudKeys {
            if let value = ud.object(forKey: key) {
                store.set(value, forKey: "one.\(key)")
            }
        }
        store.synchronize()
    }

    func deleteAccount() {
        let userID = cloudKitManager.currentUser?["userID"] as? String ?? ""

        Task {
            // 1. CloudKit: tüm record type'ları sil (DailyShare, Friendship, UserBlock, Comment, AppUser)
            await cloudKitManager.deleteAllUserData(userID: userID)

            await MainActor.run {
                // 2. Spotify tokenları ve önbellek
                spotifyManager.logout()

                // 3. CoreData: tüm yerel entry'ler
                let context = PersistenceController.shared.container.viewContext
                let fetchRequest: NSFetchRequest<NSFetchRequestResult> = NSFetchRequest(entityName: "DailySong")
                let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
                _ = try? context.execute(deleteRequest)
                try? context.save()

                // 4. UserDefaults (tüm uygulama verisi)
                if let bundleID = Bundle.main.bundleIdentifier {
                    UserDefaults.standard.removePersistentDomain(forName: bundleID)
                }

                // 5. Widget App Group verisi
                WidgetDataWriter.clear()
                if let groupDefaults = UserDefaults(suiteName: WidgetDataWriter.appGroupID) {
                    groupDefaults.removePersistentDomain(forName: WidgetDataWriter.appGroupID)
                }

                // 6. Profil fotoğrafı
                let photoURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                    .appendingPathComponent("profile_photo.jpg")
                try? FileManager.default.removeItem(at: photoURL)

                // 7. Keychain (hasCreatedProfile ve diğer flagler)
                KeychainHelper.remove(forKey: "hasCreatedProfile")

                // 8. Bildirimler iptal
                UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
                UNUserNotificationCenter.current().removeAllDeliveredNotifications()

                // 9. Kullanıcıyı onboarding'e döndür.
                //
                // Bu adım eksikti: her şey silindikten sonra uygulama silinmiş
                // hesabın ekranında kalıyordu. `ContentView` bu bildirimi
                // dinleyip Apple oturumunu düşürüyor ve
                // `hasCompletedOnboarding`'i sıfırlıyor — tek çıkış yolu bu.
                NotificationCenter.default.post(name: NSNotification.Name("resetToOnboarding"), object: nil)
            }
        }
    }
}
