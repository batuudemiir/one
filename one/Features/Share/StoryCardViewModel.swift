//
//  StoryCardViewModel.swift
//  one
//
//  Instagram Story Cards - View Model
//

import SwiftUI
import UIKit

// MARK: - StoryCardViewModel

struct StoryCardViewModel {
    // Required fields
    let coverImage: UIImage
    let songTitle: String
    let artistName: String
    let moodColor: Color
    let dateString: String
    let brandWatermark: UIImage
    
    // Optional fields
    let userNote: String?
    
    // Computed properties
    var hasNote: Bool {
        userNote?.isEmpty == false
    }
    
    var gradientColors: [Color] {
        [
            Color.black.opacity(0.7),
            Color.black.opacity(0.4),
            Color.clear
        ]
    }
    
    // Factory method
    static func from(
        dailySong: DailySong,
        defaultImage: UIImage,
        watermark: UIImage
    ) throws -> StoryCardViewModel {
        // Extract cover image
        let coverImage = dailySong.coverImage ?? defaultImage
        
        // Extract or default song info
        let songTitle = dailySong.songName.flatMap { $0.isEmpty ? nil : $0 }
            ?? NSLocalizedString("untitled_song", comment: "Untitled")
        let artistName = dailySong.artistName.flatMap { $0.isEmpty ? nil : $0 }
            ?? NSLocalizedString("unknown_artist", comment: "Unknown Artist")
        
        // Extract mood color
        let moodColor: Color
        if let hex = dailySong.moodColorHex, !hex.isEmpty {
            moodColor = Color(hex: hex)
        } else {
            moodColor = ONETokens.oneCreamLow // Default neutral
        }
        
        // Format date
        let dateString = dailySong.formattedDate
        
        // Extract note
        let userNote = dailySong.dailyNote?.isEmpty == false 
            ? dailySong.dailyNote 
            : nil
        
        return StoryCardViewModel(
            coverImage: coverImage,
            songTitle: songTitle,
            artistName: artistName,
            moodColor: moodColor,
            dateString: dateString,
            brandWatermark: watermark,
            userNote: userNote
        )
    }
    
    // Factory method from DailyEntry
    static func from(
        dailyEntry: DailyEntry,
        defaultImage: UIImage,
        watermark: UIImage
    ) throws -> StoryCardViewModel {
        // Extract cover image from photoURL
        let coverImage: UIImage
        if let photoURL = dailyEntry.photoURL,
           let photoData = try? Data(contentsOf: photoURL),
           let image = UIImage(data: photoData) {
            coverImage = image
        } else {
            coverImage = defaultImage
        }
        
        // Song info
        let songTitle = dailyEntry.songName.isEmpty 
            ? NSLocalizedString("untitled_song", comment: "Untitled")
            : dailyEntry.songName
        let artistName = dailyEntry.artistName.isEmpty 
            ? NSLocalizedString("unknown_artist", comment: "Unknown Artist")
            : dailyEntry.artistName
        
        // Mood color
        let moodColor = dailyEntry.moodColor
        
        // Format date
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMMM yyyy"
        formatter.locale = LanguageManager.shared.currentLocale
        let dateString = formatter.string(from: dailyEntry.date)
        
        // Extract note
        let userNote = dailyEntry.note?.isEmpty == false 
            ? dailyEntry.note 
            : nil
        
        return StoryCardViewModel(
            coverImage: coverImage,
            songTitle: songTitle,
            artistName: artistName,
            moodColor: moodColor,
            dateString: dateString,
            brandWatermark: watermark,
            userNote: userNote
        )
    }
}
