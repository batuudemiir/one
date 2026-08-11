//
//  Persistence.swift
//  one
//
//  Created by Batu Demir on 23.02.2026.
//

import CoreData
import SwiftUI
import CloudKit
import Combine

final class PersistenceController: ObservableObject {
    static let shared = PersistenceController()

    @MainActor
    static let preview: PersistenceController = {
        let result = PersistenceController(inMemory: true)
        let viewContext = result.container.viewContext
        // Preview data can be added here if needed
        return result
    }()

    let container: NSPersistentCloudKitContainer

    /// Whether `loadPersistentStores` has completed. Consumers that render off
    /// CoreData at launch should gate their content until this flips true;
    /// fetches issued before that will silently return empty rows.
    @Published private(set) var isReady: Bool = false

    init(inMemory: Bool = false) {
        // Launch contract: bu init Tier 0. Bütçe <20ms — loadPersistentStores
        // async; sadece kurulum senkron. Yeni sync iş buraya değil, Tier 2/3'e.
        let __initT0 = CFAbsoluteTimeGetCurrent()
        defer {
            let elapsed = CFAbsoluteTimeGetCurrent() - __initT0
            if !inMemory && elapsed >= 0.02 {
                ONELogger.warning("PersistenceController.init > 20ms (\(Int(elapsed * 1000))ms)", category: .persistence)
            }
        }

        container = NSPersistentCloudKitContainer(name: "one")

        if inMemory {
            container.persistentStoreDescriptions.first!.url = URL(fileURLWithPath: "/dev/null")
        } else {
            // CloudKit configuration
            guard let description = container.persistentStoreDescriptions.first else {
                ONELogger.error("CoreData: persistentStoreDescriptions is empty — CloudKit sync disabled", category: .persistence)
                container.loadPersistentStores(completionHandler: { _, _ in })
                // No description = no CloudKit but container is still usable.
                self.isReady = true
                return
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

            // Async load — completion handler fires on a background queue,
            // publish `isReady` on main so SwiftUI reacts on the right actor.
            // Tests / previews (`inMemory`) load synchronously below to keep
            // fixtures deterministic.
            ONELaunchSignpost.begin("coredata.load")
            container.loadPersistentStores { [weak self] _, error in
                if let error = error as NSError? {
                    // A store that can't open is unrecoverable — pretending
                    // otherwise means silent data loss on every write.
                    ONELogger.error("CoreData store failed to load: \(error.code) — \(error.localizedDescription)", category: .persistence)
                    ErrorHandler.shared.handle(error, context: "CoreDataStoreLoad")
                    fatalError("CoreData store failed to load: \(error)")
                }
                DispatchQueue.main.async {
                    ONELaunchSignpost.end("coredata.load")
                    self?.isReady = true
                    // Register the remote-change observer only after the
                    // store is loaded — before this point the coordinator
                    // has no store attached, so the observer would either
                    // miss events or fire against an unready stack.
                    // TODO: observer-side reload must still tolerate
                    // notifications arriving before consumers are subscribed.
                    self?.setupRemoteChangeNotifications()
                }
            }

            container.viewContext.automaticallyMergesChangesFromParent = true
            container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
            return
        }

        // In-memory path (tests, previews) — synchronous load is fine and
        // keeps `pc.fetchDailySong(...)` valid immediately after `init`.
        ONELaunchSignpost.begin("coredata.load")
        container.loadPersistentStores { _, error in
            ONELaunchSignpost.end("coredata.load")
            if let error = error as NSError? {
                ONELogger.error("CoreData store failed to load: \(error.code) — \(error.localizedDescription)", category: .persistence)
                fatalError("CoreData store failed to load: \(error)")
            }
        }
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        self.isReady = true
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
                // Update existing entry — do NOT overwrite `createdAt`;
                // the model has no `updatedAt` field so the original
                // insertion timestamp is the only signal of when the row
                // first appeared. Overwriting it broke archive sort order
                // and made "edited" indistinguishable from "just created".
                dailySong = existing
            } else {
                // Create new entry
                dailySong = DailySong(context: context)
                // `id` ZORUNLU: `Moment.init?(from:)` id'siz satırı nil döner
                // ve satır Profil istatistiklerinden, renk dağılımından,
                // arşiv gün gruplamasından sessizce düşer. Bu yol (şarkı
                // akışı) eskiden id yazmıyordu — kayıtların bir kısmı
                // görünmez oluyordu.
                dailySong.id = UUID()
                dailySong.date = normalizedDate
                dailySong.createdAt = now
            }
            // Geriye dönük onarım: id'siz eski satır güncelleniyorsa doldur.
            if dailySong.id == nil { dailySong.id = UUID() }
            
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
                                    guard !dailySong.isDeleted, dailySong.managedObjectContext != nil else { return }
                                    dailySong.photoData = compressedData
                                    do {
                                        try context.save()
                                    } catch {
                                        ErrorHandler.shared.handle(error, context: "artworkDownload")
                                    }
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
                if let tomorrow = calendar.date(byAdding: .day, value: 1, to: Date()),
                   let midnight = calendar.date(bySettingHour: 0, minute: 0, second: 0, of: tomorrow) {
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
    
    // #10 — Pas günü: renk/şarkı yok, streak korunur
    func savePassedDay(date: Date, context: NSManagedObjectContext) {
        let normalizedDate = Calendar.current.startOfDay(for: date)
        let fetchRequest: NSFetchRequest<DailySong> = DailySong.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "date == %@", normalizedDate as NSDate)
        fetchRequest.fetchLimit = 1

        do {
            let results = try context.fetch(fetchRequest)
            guard results.isEmpty else { return } // Gerçek giriş varsa pas'ı geçersiz kıl
            let entry = DailySong(context: context)
            entry.id = UUID()
            entry.date = normalizedDate
            entry.createdAt = Date()
            entry.passed = true
            entry.moodColorHex = "#9E9E9E"  // nötr gri — archive gösterimi için
            entry.songName = ""
            entry.artistName = ""
            try context.save()
        } catch {
            ONELogger.debug("Error saving passed day: \(error)", category: .persistence)
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
    
    // MARK: - v3 multi-moment reads (additive)

    /// v3: bir güne ait TÜM anlar. `entryIndex` sonra `createdAt` sıralı.
    /// Boş gün için `[]`. Legacy `fetchDailySong(for:)` mostRecent semantiğine
    /// benziyor; artık en son entryIndex'i döndüren `mostRecentMoment(for:)`
    /// kullanılmalı.
    func fetchMoments(for date: Date, context: NSManagedObjectContext) -> [Moment] {
        let normalizedDate = Calendar.current.startOfDay(for: date)
        let fetchRequest: NSFetchRequest<DailySong> = DailySong.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "date == %@", normalizedDate as NSDate)
        fetchRequest.sortDescriptors = [
            NSSortDescriptor(key: "entryIndex", ascending: true),
            NSSortDescriptor(key: "createdAt", ascending: true)
        ]

        do {
            let rows = try context.fetch(fetchRequest)
            return rows.compactMap { Moment(from: $0) }
        } catch {
            ONELogger.debug("Error fetching moments: \(error)", category: .persistence)
            return []
        }
    }

    /// v3: bir aya ait tüm günler (an koleksiyonu ile). Boş günler dahil DEĞİL —
    /// UI takvim gridini kendi tarafında boşlukla doldurur.
    func fetchDaysForMonth(year: Int, month: Int, context: NSManagedObjectContext) -> [Day] {
        let songs = fetchDailySongsForMonth(year: year, month: month, context: context)
        return songs.compactMap { Moment(from: $0) }.groupedByDay()
    }

    /// Bir güne yeni an eklerken bir sonraki `entryIndex`. Concurrency yok —
    /// aynı gün içinde çift ekleme (nadir) CloudKit merge sırasında ele
    /// alınmalı; UI tek kullanıcı, tek cihazda peş peşe fetch/insert yapıyor.
    func nextEntryIndex(for date: Date, context: NSManagedObjectContext) -> Int16 {
        let existing = fetchMoments(for: date, context: context)
        guard let last = existing.map(\.entryIndex).max() else { return 0 }
        return Int16(last + 1)
    }

    /// Legacy helper — bir gündeki en son an. Eski `fetchDailySong(for:)`
    /// çağrı yerlerinden geçiş sırasında kullanılsın.
    func mostRecentMoment(for date: Date, context: NSManagedObjectContext) -> Moment? {
        fetchMoments(for: date, context: context).last
    }

    /// v3 write path — daima YENİ satır ekle. entryIndex auto. Legacy
    /// `savePickResults` upsert (overwrite) mantığı v2 tek-an döneminden;
    /// v3'te An hub'ı bu fonksiyonu çağırır.
    ///
    /// Not: caller `context.save()` sorumlu — hata yönetimi tek yerde kalsın.
    @discardableResult
    func insertNewMoment(
        for date: Date,
        moodColorHex: String,
        moodWord: String? = nil,
        note: String? = nil,
        songName: String? = nil,
        songArtist: String? = nil,
        photoData: Data? = nil,
        scope: MomentScope = .private,
        context: NSManagedObjectContext
    ) -> DailySong {
        let normalizedDate = Calendar.current.startOfDay(for: date)
        let now = Date()

        let song = DailySong(context: context)
        song.id = UUID()
        song.date = normalizedDate
        song.createdAt = now
        song.entryIndex = nextEntryIndex(for: normalizedDate, context: context)
        song.moodColorHex = moodColorHex
        song.moodWord = moodWord
        song.dailyNote = note?.trimmingCharacters(in: .whitespacesAndNewlines)
        song.songName = songName
        song.artistName = songArtist
        song.photoData = photoData
        song.shareWithCircle = (scope == .friends)
        song.isSharedWithCircle = (scope == .friends)
        return song
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
        let patterns = repeatedSongs.compactMap { key, value -> SongPattern? in
            let components = key.components(separatedBy: "|")
            guard components.count >= 2 else { return nil }
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

    /// Off-main variant. `analyzeSongPatterns` yukarıda tüm DailySong'ları
    /// çekip O(N) grup + hex→Color çevirisi yapıyor; kayıt büyüdükçe main'i
    /// bloke ediyordu. Bu sürüm ağır kısmı background context'te çalıştırır,
    /// yalnız `SongPattern` inşasını çağıran actor'da yapar.
    func analyzeSongPatternsAsync() async -> [SongPattern] {
        ONELaunchSignpost.begin("songPatterns")
        defer { ONELaunchSignpost.end("songPatterns") }
        let bgContext = container.newBackgroundContext()
        struct RawPattern {
            let songName: String
            let artistName: String
            let count: Int
            let percentage: Double
            let colorHex: String
            let dates: [Date]
            let emoji: String?
        }
        let raw: [RawPattern] = await withCheckedContinuation { continuation in
            bgContext.perform {
                let request: NSFetchRequest<DailySong> = DailySong.fetchRequest()
                request.sortDescriptors = [NSSortDescriptor(key: "date", ascending: false)]
                let songs = (try? bgContext.fetch(request)) ?? []
                guard !songs.isEmpty else {
                    continuation.resume(returning: [])
                    return
                }

                var counts: [String: (count: Int, dates: [Date], color: String?, emoji: String?)] = [:]
                for song in songs {
                    guard let name = song.songName, let artist = song.artistName else { continue }
                    let key = "\(name)|\(artist)"
                    if var e = counts[key] {
                        e.count += 1
                        if let d = song.date { e.dates.append(d) }
                        counts[key] = e
                    } else {
                        counts[key] = (
                            count: 1,
                            dates: song.date.map { [$0] } ?? [],
                            color: song.moodColorHex,
                            emoji: song.emoji
                        )
                    }
                }

                let total = Double(songs.count)
                let repeated = counts.filter { $0.value.count > 1 }
                let out: [RawPattern] = repeated.compactMap { key, value in
                    let parts = key.components(separatedBy: "|")
                    guard parts.count >= 2 else { return nil }
                    return RawPattern(
                        songName: parts[0],
                        artistName: parts[1],
                        count: value.count,
                        percentage: Double(value.count) / total,
                        colorHex: value.color ?? "#5B8DEF",
                        dates: value.dates,
                        emoji: value.emoji
                    )
                }
                .sorted { $0.count > $1.count }

                continuation.resume(returning: out)
            }
        }

        return raw.map {
            SongPattern(
                songName: $0.songName,
                artistName: $0.artistName,
                count: $0.count,
                percentage: $0.percentage,
                color: Color(hex: $0.colorHex),
                dates: $0.dates,
                emoji: $0.emoji
            )
        }
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
