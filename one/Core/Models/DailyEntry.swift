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
    case calm = "calm"
    case happy = "happy"
    case sad = "sad"
    case anxious = "anxious"
    case excited = "excited"
    case tired = "tired"
    case angry = "angry"
    case peaceful = "peaceful"
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
