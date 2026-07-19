//
//  DailyEntry.swift
//  One - Günlük Mood
//

import SwiftUI
import CoreData

// MARK: - Daily Entry Model
struct DailyEntry: Identifiable, Hashable, Equatable {
    let id: UUID
    let date: Date
    let songName: String
    let artistName: String
    let genre: String
    let moodColor: Color
    let moodColorHex: String
    let moodLabel: String
    let feeling: FeelingType
    let feelingLabel: String
    let time: String              // "21:14"
    let photoURL: URL?
    let shareWithCircle: Bool
    let weatherIcon: String       // "⛅"
    let weatherDesc: String       // "14°C · Parçalı bulutlu"
    let spotifyURL: URL?
    let platform: String          // "Spotify" or "Apple Music"
    let note: String?             // Günlük not
    let passed: Bool              // #10 — "Bugün geçti" pas günü

    // Hashable: sadece id üzerinden eşitlik ve hash (Color Hashable değil)
    static func == (lhs: DailyEntry, rhs: DailyEntry) -> Bool {
        lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

// MARK: - Feeling Type
enum FeelingType: String, CaseIterable {
    // Mevcut (geriye uyumluluk için korunuyor)
    case calm = "calm"
    case happy = "happy"
    case sad = "sad"
    case anxious = "anxious"
    case excited = "excited"
    case tired = "tired"
    case angry = "angry"
    case peaceful = "peaceful"
    // v2.5 — yeni feeling seçenekleri
    case chill = "chill"
    case overthink = "overthink"
    case hype = "hype"
    case manifest = "manifest"
    case happierThanEver = "happierThanEver"
    case dance = "dance"
    case alone = "alone"
}

// MARK: - Mood Label Migration (v2.5)

extension DailyEntry {

    /// v2.5 öncesi CoreData/CloudKit'e kaydedilen eski mood etiketlerini
    /// yeni isimlere çevirir. Yeni kayıtlar zaten doğru geldiği için map'te
    /// olmayan değerler olduğu gibi döner.
    static let moodLabelMigrationMap: [String: String] = [
        // ── ateş ──────────────────────────────
        "ateşli"   : "ateş",
        "Ateşli"   : "ateş",

        // ── ışık ──────────────────────────────
        "ışıklı"   : "ışık",
        "Işıklı"   : "ışık",
        "isikli"   : "ışık",
        "neşeli"   : "ışık",
        "Neşeli"   : "ışık",
        "mutlu"    : "ışık",
        "Mutlu"    : "ışık",

        // ── enerji ────────────────────────────
        "enerjik"  : "enerji",
        "Enerjik"  : "enerji",
        "coşkulu"  : "enerji",
        "Coşkulu"  : "enerji",
        "canlı"    : "enerji",
        "Canlı"    : "enerji",

        // ── taze ────────────────────────────── (değişmedi — yine de güvenlik için)
        "doğal"    : "taze",
        "Doğal"    : "taze",

        // ── huzur ─────────────────────────────
        "sakin"    : "huzur",
        "Sakin"    : "huzur",
        "huzurlu"  : "huzur",
        "Huzurlu"  : "huzur",
        "dingin"   : "huzur",
        "Dingin"   : "huzur",

        // ── özlem ─────────────────────────────
        "nostaljik": "özlem",
        "Nostaljik": "özlem",
        "heyecanlı": "özlem",
        "Heyecanlı": "özlem",

        // ── loş ───────────────────────────────
        "gizemli"  : "loş",
        "Gizemli"  : "loş",

        // ── boşluk ────────────────────────────
        "boş"      : "boşluk",
        "Boş"      : "boşluk",
        "sessiz"   : "boşluk",
        "Sessiz"   : "boşluk",
        "bos"      : "boşluk",
        "Bos"      : "boşluk",
    ]

    /// Görüntüleme ve istatistik için kullanılacak normalize edilmiş mood etiketi.
    /// Eski kayıtlar otomatik olarak yeni isimlere çevrilir.
    var normalizedMoodLabel: String {
        Self.moodLabelMigrationMap[moodLabel] ?? moodLabel
    }
}

// MARK: - DailyEntry to DailySong Conversion
extension DailyEntry {
    func toDailySong(context: NSManagedObjectContext) -> DailySong {
        let dailySong = DailySong(context: context)
        dailySong.id = self.id
        dailySong.date = self.date
        dailySong.songName = self.songName
        dailySong.artistName = self.artistName
        dailySong.genre = self.genre
        dailySong.moodColorHex = self.moodColorHex
        dailySong.moodLabel = self.moodLabel
        dailySong.moodWord = self.moodLabel
        dailySong.feeling = self.feeling.rawValue
        dailySong.feelingLabel = self.feelingLabel
        dailySong.shareWithCircle = self.shareWithCircle
        dailySong.weatherIcon = self.weatherIcon
        dailySong.weatherDesc = self.weatherDesc
        dailySong.platform = self.platform
        dailySong.dailyNote = self.note
        dailySong.passed = self.passed
        
        // Convert time string back to date
        if let createdAt = parseTimeToDate(timeString: self.time, baseDate: self.date) {
            dailySong.createdAt = createdAt
        } else {
            dailySong.createdAt = self.date
        }
        
        // Convert photo URL to data
        if let photoURL = self.photoURL,
           let photoData = try? Data(contentsOf: photoURL) {
            dailySong.photoData = photoData
        }
        
        return dailySong
    }
    
    private func parseTimeToDate(timeString: String, baseDate: Date) -> Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        
        guard let time = formatter.date(from: timeString) else {
            return nil
        }
        
        let calendar = Calendar.current
        let timeComponents = calendar.dateComponents([.hour, .minute], from: time)
        let dateComponents = calendar.dateComponents([.year, .month, .day], from: baseDate)
        
        var combined = DateComponents()
        combined.year = dateComponents.year
        combined.month = dateComponents.month
        combined.day = dateComponents.day
        combined.hour = timeComponents.hour
        combined.minute = timeComponents.minute
        
        return calendar.date(from: combined)
    }
}
