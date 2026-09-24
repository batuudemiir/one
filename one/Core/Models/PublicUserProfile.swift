//
//  PublicUserProfile.swift
//  one
//
//  Başka kullanıcıların hafif profil görünümü. Yorum → profil tap akışında
//  `PublicProfileView` tarafından kullanılır. AppUser CKRecord'ından
//  sadece paylaşılabilir alanları taşır.
//

import Foundation
import CloudKit

struct PublicUserProfile: Identifiable, Equatable {
    let id: String             // userID
    let displayName: String
    let username: String?
    let avatarColorHex: String?
    let isPublic: Bool
    let joinedAt: Date?
    let totalShareDays: Int?   // isPublic true ise populated
    /// CloudKit şemasında duran alan. Seri motoru kaldırıldı ve hiçbir
    /// yüzey bunu okumuyor; alan mevcut kayıtlar bozulmasın diye duruyor.
    /// Yeni kayıtlarda 0 yazılıyor. Şemadan düşürmek migration ister.
    let currentStreak: Int?
    
    // v2.6 Aggregate Stats
    let dominantMoodColor: String?
    let dominantMoodWord: String?
    let peakActivityHour: Int?
    let topTracks: [String]?
    let topArtists: [String]?
    let topGenre: String?
    let moodHistoryColors: [String]? // Son 30 gün hex kodları
    let musicTasteVisible: Bool      // gizlilik tercihi — default true
    let moodHistoryVisible: Bool     // gizlilik tercihi — default true

    // v3.1 Profile photo
    let profilePhotoFileURL: URL?

    // v3 Public Profile
    var pinnedSong: PinnedSong?       // pinnedSongData JSON'dan parse
    var pinnedSongArtworkURL: String? // ayrı alan
    var mutualFriendCount: Int?       // runtime doldurulan
}

// MARK: - Relationship state

enum PublicProfileRelationship: Equatable {
    case none
    case pendingOutgoing          // cancelFriendRequest toUserID üzerinden çalışır, recordID gereksiz
    case pendingIncoming(recordID: CKRecord.ID)
    case friend
    case blockedByMe
    case blockedMe
    case self_
}

// MARK: - CKRecord bridging

extension PublicUserProfile {
    static let recordType = "AppUser"

    init?(record: CKRecord) {
        guard record.recordType == Self.recordType,
              let userID = record["userID"] as? String,
              let displayName = record["displayName"] as? String
        else { return nil }

        self.id = userID
        self.displayName = displayName
        self.username = record["username"] as? String
        self.avatarColorHex = record["avatarColor"] as? String
        let pubRaw = (record["isPublic"] as? Int64).map(Int.init) ?? 0
        self.isPublic = pubRaw == 1
        self.joinedAt = record["createdDate"] as? Date
        self.totalShareDays = nil
        self.currentStreak = nil
        self.dominantMoodColor = record["dominantMoodColor"] as? String
        self.dominantMoodWord = record["dominantMoodWord"] as? String
        self.peakActivityHour = record["peakActivityHour"] as? Int
        self.topTracks = record["topTracks"] as? [String]
        self.topArtists = record["topArtists"] as? [String]
        self.topGenre = record["topGenre"] as? String
        let musicRaw = (record["musicTasteVisible"] as? Int64).map(Int.init)
        self.musicTasteVisible = musicRaw.map { $0 != 0 } ?? true
        let moodHistRaw = (record["moodHistoryVisible"] as? Int64).map(Int.init)
        self.moodHistoryVisible = moodHistRaw.map { $0 != 0 } ?? true
        // Gizlilik tercihi parse anında uygula — field response'ta gelse de
        // model üzerinde asla expose etme.
        self.moodHistoryColors = self.moodHistoryVisible
            ? record["moodHistoryColors"] as? [String]
            : nil

        // v3 Public Profile
        let pinnedJSON = record["pinnedSongData"] as? String ?? ""
        self.pinnedSong = PinnedSong.fromJSONString(pinnedJSON)
        self.pinnedSongArtworkURL = record["pinnedSongArtworkURL"] as? String
        self.mutualFriendCount = nil

        // v3.1 Profile photo
        self.profilePhotoFileURL = (record["profilePhoto"] as? CKAsset)?.fileURL
    }

    func with(totalShareDays: Int?, currentStreak: Int?) -> PublicUserProfile {
        var copy = PublicUserProfile(
            id: id,
            displayName: displayName,
            username: username,
            avatarColorHex: avatarColorHex,
            isPublic: isPublic,
            joinedAt: joinedAt,
            totalShareDays: totalShareDays,
            currentStreak: currentStreak,
            dominantMoodColor: dominantMoodColor,
            dominantMoodWord: dominantMoodWord,
            peakActivityHour: peakActivityHour,
            topTracks: topTracks,
            topArtists: topArtists,
            topGenre: topGenre,
            moodHistoryColors: moodHistoryColors,
            musicTasteVisible: musicTasteVisible,
            moodHistoryVisible: moodHistoryVisible,
            profilePhotoFileURL: profilePhotoFileURL
        )
        copy.pinnedSong = pinnedSong
        copy.pinnedSongArtworkURL = pinnedSongArtworkURL
        copy.mutualFriendCount = mutualFriendCount
        return copy
    }
}
