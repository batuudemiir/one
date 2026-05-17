//
//  UserProfileStore.swift
//  one
//
//  v3.2 — Instagram tarzı **tek profil cache**.
//  Tüm yüzeyler (yorum satırı, public profile sheet, friend kartları) bir
//  kullanıcının displayName / username / profil fotoğrafı / sabitlenmiş şarkı
//  gibi alanlarını bu store üzerinden okur.
//
//  Profil değiştiğinde (örn. ProfileViewModel `saveProfile` veya
//  `updatePinnedSong`) `invalidate(userID:)` çağrılır → store taze fetch yapar
//  ve `.userProfileDidChange(userID:)` notification yayar. Tüm satırlar
//  reaktif olarak yenilenir.
//
//  Avatar fotoğrafı CKAsset olarak gelir; `fileURL` cache'lenir, satırlar
//  background thread'de bu URL'den `UIImage`'i decode eder.
//

import Foundation
import CloudKit
import Combine

extension Notification.Name {
    /// Belirli bir kullanıcının profili değiştiğinde yayılır.
    /// `object`: userID String.
    static let userProfileDidChange  = Notification.Name("userProfileDidChange")
    static let profilePhotoDidChange = Notification.Name("profilePhotoDidChange")
}

@MainActor
final class UserProfileStore: ObservableObject {

    // MARK: - Singleton

    static let shared = UserProfileStore()

    private init() {}

    // MARK: - Cache

    /// userID → en son bilinen profil snapshot'ı.
    private var cache: [String: PublicUserProfile] = [:]

    /// userID → fetch in-flight (race-condition önler).
    private var inflight: Set<String> = []

    /// userID → son fetch zamanı (TTL kontrolü için).
    private var lastFetched: [String: Date] = [:]

    /// Cache TTL — 5 dk içinde tekrar fetch yapma.
    private let ttl: TimeInterval = 5 * 60

    /// AppUser kaydından okunacak alanlar.
    private static let desiredKeys: [CKRecord.FieldKey] = [
        "userID", "displayName", "username", "avatarColor",
        "isPublic", "createdDate",
        "dominantMoodColor", "dominantMoodWord", "peakActivityHour",
        "topTracks", "topArtists", "topGenre",
        "moodHistoryColors", "musicTasteVisible", "moodHistoryVisible",
        "pinnedSongData", "pinnedSongArtworkURL",
        "profilePhoto"
    ]

    // MARK: - Read

    /// Cache'deki profili senkron döndürür. Yoksa nil — caller `prefetch` çağırabilir.
    func snapshot(for userID: String) -> PublicUserProfile? {
        cache[userID]
    }

    /// Bir veya daha fazla userID'yi cache'le (henüz yoksa veya TTL geçtiyse).
    /// Tamamlandığında `.userProfileDidChange` notification'ları fire edilir.
    func prefetch(_ userIDs: [String]) {
        let now = Date()
        let toFetch = userIDs.filter { uid in
            guard !uid.isEmpty else { return false }
            guard !inflight.contains(uid) else { return false }
            if let last = lastFetched[uid], now.timeIntervalSince(last) < ttl,
               cache[uid] != nil {
                return false
            }
            return true
        }
        guard !toFetch.isEmpty else { return }
        toFetch.forEach { inflight.insert($0) }
        fetchProfiles(userIDs: toFetch)
    }

    /// TTL'i baypas ederek tek bir kullanıcıyı taze çeker (örn. profile düzenlendiğinde).
    func invalidate(userID: String) {
        lastFetched.removeValue(forKey: userID)
        guard !inflight.contains(userID) else { return }
        inflight.insert(userID)
        fetchProfiles(userIDs: [userID])
    }

    /// Mevcut kullanıcı kendi CKRecord'unu güncelledi → cache'i hemen yenile.
    func invalidateCurrentUser() {
        guard let uid = CloudKitManager.shared.currentUser?["userID"] as? String else { return }
        invalidate(userID: uid)
    }

    // MARK: - Fetch

    private func fetchProfiles(userIDs: [String]) {
        let predicate = NSPredicate(format: "userID IN %@", userIDs)
        let query = CKQuery(recordType: "AppUser", predicate: predicate)
        CloudKitManager.shared.publicDatabase.fetch(
            withQuery: query,
            inZoneWith: nil,
            desiredKeys: Self.desiredKeys,
            resultsLimit: max(userIDs.count, 1)
        ) { [weak self] result in
            Task { @MainActor [weak self] in
                guard let self else { return }
                userIDs.forEach { self.inflight.remove($0) }

                guard case .success(let (matches, _)) = result else {
                    ONELogger.error("UserProfileStore fetch failed: \(result)", category: .cloudkit)
                    return
                }
                let now = Date()
                for record in matches.compactMap({ try? $0.1.get() }) {
                    guard let profile = PublicUserProfile(record: record) else { continue }
                    self.cache[profile.id] = profile
                    self.lastFetched[profile.id] = now
                    NotificationCenter.default.post(
                        name: .userProfileDidChange,
                        object: profile.id
                    )
                }
            }
        }
    }

    // MARK: - Direct upsert (opsiyonel — local optimistic update için)

    /// Bilinen bir profil snapshot'ını (örn. kendi düzenlemeden sonra) cache'e yaz.
    func upsert(_ profile: PublicUserProfile) {
        cache[profile.id] = profile
        lastFetched[profile.id] = Date()
        NotificationCenter.default.post(name: .userProfileDidChange, object: profile.id)
    }
}
