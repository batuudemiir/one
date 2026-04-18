//
//  Persistence.swift
//  one
//
//  Created by Batu Demir on 23.02.2026.
//

import CoreData
import SwiftUI
import CloudKit

struct PersistenceController {
    static let shared = PersistenceController()

    @MainActor
    static let preview: PersistenceController = {
        let result = PersistenceController(inMemory: true)
        let viewContext = result.container.viewContext
        // Preview data can be added here if needed
        return result
    }()

    let container: NSPersistentCloudKitContainer

    init(inMemory: Bool = false) {
        container = NSPersistentCloudKitContainer(name: "one")
        
        if inMemory {
            container.persistentStoreDescriptions.first!.url = URL(fileURLWithPath: "/dev/null")
        } else {
            // CloudKit configuration
            guard let description = container.persistentStoreDescriptions.first else {
                fatalError("Failed to retrieve persistent store description")
            }
            
            // Enable CloudKit sync
            description.cloudKitContainerOptions = NSPersistentCloudKitContainerOptions(
                containerIdentifier: "iCloud.com.batu.ones"
            )
            
            // Enable remote change notifications
            description.setOption(true as NSNumber, 
                                forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
            
            // Enable history tracking
            description.setOption(true as NSNumber,
                                forKey: NSPersistentHistoryTrackingKey)
            
            // Enable automatic migration
            description.setOption(true as NSNumber,
                                forKey: NSMigratePersistentStoresAutomaticallyOption)
            description.setOption(true as NSNumber,
                                forKey: NSInferMappingModelAutomaticallyOption)

            // Enable file protection — store encrypted until first unlock
            description.setOption(
                FileProtectionType.completeUntilFirstUserAuthentication as NSObject,
                forKey: NSPersistentStoreFileProtectionKey
            )
        }
        
        container.loadPersistentStores(completionHandler: { (storeDescription, error) in
            if let error = error as NSError? {
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
        })
        
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        
        // Setup remote change notifications
        setupRemoteChangeNotifications()
    }
    
    private func setupRemoteChangeNotifications() {
        NotificationCenter.default.addObserver(
            forName: .NSPersistentStoreRemoteChange,
            object: container.persistentStoreCoordinator,
            queue: .main
        ) { notification in
            ONELogger.debug("CloudKit: Remote change detected", category: .persistence)
        }
    }
    
    // MARK: - Daily Song Management
    
    func saveDailySong(
        date: Date,
        song: Song,
        mood: Mood,
        note: String,
        platform: String,
        photo: UIImage? = nil,
        shareWithCircle: Bool = false,
        context: NSManagedObjectContext
    ) {
        // Normalize date to start of day
        let normalizedDate = Calendar.current.startOfDay(for: date)
        
        // Check if entry already exists for this date
        let fetchRequest: NSFetchRequest<DailySong> = DailySong.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "date == %@", normalizedDate as NSDate)
        
        do {
            let results = try context.fetch(fetchRequest)
            let dailySong: DailySong
            let now = Date() // Gerçek timestamp
            
            if let existing = results.first {
                // Update existing entry
                dailySong = existing
                // Güncelleme zamanını kaydet
                dailySong.createdAt = now
            } else {
                // Create new entry
                dailySong = DailySong(context: context)
                dailySong.date = normalizedDate
                dailySong.createdAt = now
            }
            
            // Update properties
            dailySong.songName = song.name
            dailySong.artistName = song.artist
            dailySong.genre = song.genre
            dailySong.emoji = song.emoji
            dailySong.artworkURL = song.artworkURL?.absoluteString
            dailySong.moodWord = mood.word
            dailySong.moodColorHex = mood.color.toHex()
            dailySong.moodIsDark = mood.isDark
            dailySong.dailyNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
            dailySong.platform = platform
            
            // Save photo if provided
            if let photo = photo {
                // Compress image to JPEG with 0.7 quality
                if let imageData = photo.jpegData(compressionQuality: 0.7) {
                    dailySong.photoData = imageData
                }
            } else if dailySong.photoData == nil {
                // If no photo provided and no existing photo, try to download artwork
                if let artworkURL = song.artworkURL {
                    Task.detached(priority: .utility) {
                        do {
                            let (data, _) = try await URLSession.shared.data(from: artworkURL)
                            try Task.checkCancellation()
                            if let image = UIImage(data: data),
                               let compressedData = image.jpegData(compressionQuality: 0.7) {
                                await MainActor.run {
                                    dailySong.photoData = compressedData
                                    try? context.save()
                                }
                            }
                        } catch {
                            await MainActor.run {
                                ONELogger.debug("Failed to download artwork: \(error)", category: .persistence)
                            }
                        }
                    }
                }
            }
            
            // Circle sharing
            if shareWithCircle {
                dailySong.isSharedWithCircle = true
                dailySong.sharedAt = Date()
                
                // Set expiration to midnight (00:00) of next day
                var calendar = Calendar.current
                calendar.timeZone = TimeZone.current
                if let midnight = calendar.date(bySettingHour: 0, minute: 0, second: 0, of: calendar.date(byAdding: .day, value: 1, to: Date())!) {
                    dailySong.shareExpiresAt = midnight
                }
            } else {
                dailySong.isSharedWithCircle = false
                dailySong.shareExpiresAt = nil
            }
            
            try context.save()
        } catch {
            ONELogger.debug("Error saving daily song: \(error)", category: .persistence)
        }
    }
    
    func fetchDailySong(for date: Date, context: NSManagedObjectContext) -> DailySong? {
        let normalizedDate = Calendar.current.startOfDay(for: date)
        let fetchRequest: NSFetchRequest<DailySong> = DailySong.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "date == %@", normalizedDate as NSDate)
        fetchRequest.fetchLimit = 1
        
        do {
            return try context.fetch(fetchRequest).first
        } catch {
            ONELogger.debug("Error fetching daily song: \(error)", category: .persistence)
            return nil
        }
    }
    
    func fetchAllDailySongs(context: NSManagedObjectContext) -> [DailySong] {
        let fetchRequest: NSFetchRequest<DailySong> = DailySong.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "date", ascending: false)]
        
        do {
            return try context.fetch(fetchRequest)
        } catch {
            ONELogger.debug("Error fetching all daily songs: \(error)", category: .persistence)
            return []
        }
    }
    
    func fetchDailySongsForMonth(year: Int, month: Int, context: NSManagedObjectContext) -> [DailySong] {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = 1
        
        guard let startDate = Calendar.current.date(from: components),
              let endDate = Calendar.current.date(byAdding: .month, value: 1, to: startDate) else {
            return []
        }
        
        let fetchRequest: NSFetchRequest<DailySong> = DailySong.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "date >= %@ AND date < %@", startDate as NSDate, endDate as NSDate)
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "date", ascending: true)]
        
        do {
            return try context.fetch(fetchRequest)
        } catch {
            ONELogger.debug("Error fetching monthly songs: \(error)", category: .persistence)
            return []
        }
    }
    
    // MARK: - Pattern Analysis
    
    struct SongPattern: Identifiable {
        let id = UUID()
        let songName: String
        let artistName: String
        let count: Int
        let percentage: Double
        let color: Color
        let dates: [Date]
        let emoji: String?
        
        var dateString: String {
            let formatter = DateFormatter()
            formatter.dateFormat = "d MMM"
            formatter.locale = LanguageManager.shared.currentLocale
            
            let sortedDates = dates.sorted()
            let dateStrings = sortedDates.prefix(4).map { formatter.string(from: $0) }
            
            if sortedDates.count > 4 {
                return dateStrings.joined(separator: " · ") + "..."
            } else {
                return dateStrings.joined(separator: " · ")
            }
        }
    }
    
    func analyzeSongPatterns(context: NSManagedObjectContext) -> [SongPattern] {
        let allSongs = fetchAllDailySongs(context: context)
        
        guard !allSongs.isEmpty else { return [] }
        
        // Group by song name + artist
        var songCounts: [String: (count: Int, dates: [Date], color: String?, emoji: String?)] = [:]
        
        for song in allSongs {
            guard let songName = song.songName, let artistName = song.artistName else { continue }
            let key = "\(songName)|\(artistName)"
            
            if var existing = songCounts[key] {
                existing.count += 1
                if let date = song.date {
                    existing.dates.append(date)
                }
                songCounts[key] = existing
            } else {
                songCounts[key] = (
                    count: 1,
                    dates: song.date != nil ? [song.date!] : [],
                    color: song.moodColorHex,
                    emoji: song.emoji
                )
            }
        }
        
        // Filter songs that appear more than once
        let repeatedSongs = songCounts.filter { $0.value.count > 1 }
        
        // Convert to SongPattern
        let patterns = repeatedSongs.map { key, value -> SongPattern in
            let components = key.components(separatedBy: "|")
            let songName = components[0]
            let artistName = components[1]
            let percentage = Double(value.count) / Double(allSongs.count)
            
            return SongPattern(
                songName: songName,
                artistName: artistName,
                count: value.count,
                percentage: percentage,
                color: Color(hex: value.color ?? "#5B8DEF"),
                dates: value.dates,
                emoji: value.emoji
            )
        }
        
        // Sort by count descending
        return patterns.sorted { $0.count > $1.count }
    }
    
    func getMostFrequentSong(context: NSManagedObjectContext) -> SongPattern? {
        return analyzeSongPatterns(context: context).first
    }
}

// MARK: - Color Extension for Hex Conversion
extension Color {
    func toHex() -> String {
        guard let components = UIColor(self).cgColor.components else { return "#000000" }
        
        let r = components[0]
        let g = components.count > 1 ? components[1] : components[0]
        let b = components.count > 2 ? components[2] : components[0]
        
        return String(format: "#%02X%02X%02X",
                     Int(r * 255),
                     Int(g * 255),
                     Int(b * 255))
    }
}
