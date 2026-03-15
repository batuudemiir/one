//
//  TodayViewModel.swift
//  One - Günlük Mood
//

import SwiftUI
import Combine
import CoreData
import MusicKit
import CloudKit

// MARK: - TodayViewModel
@MainActor
class TodayViewModel: ObservableObject {
    @Published var todayEntry: DailyEntry? = nil
    @Published var searchResults: [SongResult] = []
    @Published var recentArtists: [String] = []
    @Published var isSearching: Bool = false
    @Published var searchError: String? = nil

    private let context: NSManagedObjectContext
    private var searchTask: Task<Void, Never>? = nil

    var todayState: TodayState {
        todayEntry == nil ? .empty : .completed
    }

    init(context: NSManagedObjectContext) {
        self.context = context
        loadTodayEntry()
        loadRecentArtists()
    }

    // MARK: - Load today's entry from CoreData
    private func loadTodayEntry() {
        let today = Calendar.current.startOfDay(for: Date())
        let fetchRequest: NSFetchRequest<DailySong> = DailySong.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "date == %@", today as NSDate)
        fetchRequest.fetchLimit = 1

        do {
            if let item = try context.fetch(fetchRequest).first {
                todayEntry = dailyEntryFrom(item)
                syncLocalEntryToCloudKitIfNeeded(item: item)
            }
        } catch {
            ONELogger.debug("TodayViewModel: fetch error \(error)", category: .general)
        }
    }

    // MARK: - Load recent artists from archive
    func loadRecentArtists() {
        let fetchRequest: NSFetchRequest<DailySong> = DailySong.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "date", ascending: false)]
        fetchRequest.fetchLimit = 30

        do {
            let items = try context.fetch(fetchRequest)
            var seen = Set<String>()
            var artists: [String] = []
            for item in items {
                if let a = item.artistName, !seen.contains(a) {
                    seen.insert(a)
                    artists.append(a)
                    if artists.count == 6 { break }
                }
            }
            recentArtists = artists
        } catch {}
    }

    // MARK: - Search via MusicKit
    func search(_ query: String) {
        // Önceki aramayı iptal et
        searchTask?.cancel()

        guard query.count > 1 else {
            searchResults = []
            searchError = nil
            isSearching = false
            return
        }

        isSearching = true
        searchError = nil

        searchTask = Task {
            // Debounce: kullanıcı yazmayı bırakana kadar bekle
            try? await Task.sleep(nanoseconds: 300_000_000) // 0.3s
            guard !Task.isCancelled else { return }

            // Önce izin durumunu kontrol et (request yapmadan)
            let currentStatus = MusicAuthorization.currentStatus
            if currentStatus != .authorized {
                // İzin iste
                let status = await MusicAuthorization.request()
                guard status == .authorized else {
                    searchError = "Apple Music izni gerekli. Lütfen Ayarlar > Gizlilik'ten izin verin."
                    isSearching = false
                    return
                }
            }

            guard !Task.isCancelled else { return }

            do {
                var request = MusicCatalogSearchRequest(term: query, types: [MusicKit.Song.self])
                request.limit = 12
                let response = try await request.response()

                guard !Task.isCancelled else { return }

                searchResults = response.songs.map { s in
                    SongResult(
                        id: UUID(),
                        name: s.title,
                        artist: s.artistName,
                        genre: s.genreNames.first ?? "Müzik",
                        coverURL: s.artwork?.url(width: 200, height: 200),
                        spotifyURL: nil,
                        artworkURLString: s.artwork?.url(width: 600, height: 600)?.absoluteString
                    )
                }
                searchError = nil
            } catch is CancellationError {
                // Sessizce iptal
            } catch {
                if !Task.isCancelled {
                    searchError = error.localizedDescription
                    searchResults = []
                }
            }
            isSearching = false
        }
    }

    // MARK: - Save entry
    func saveEntry(
        song: SongResult,
        mood: MoodOption,
        feeling: FeelingType,
        photo: UIImage?,
        note: String = "",
        sharePhoto: Bool
    ) {
        let today = Calendar.current.startOfDay(for: Date())
        let now = Date() // Gerçek timestamp

        let fetchRequest: NSFetchRequest<DailySong> = DailySong.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "date == %@", today as NSDate)

        let item: DailySong
        if let existing = try? context.fetch(fetchRequest).first {
            item = existing
            // Güncelleme zamanını kaydet
            item.createdAt = now
        } else {
            item = DailySong(context: context)
            item.date = today
            item.createdAt = now
            item.id = UUID()
        }

        item.songName    = song.name
        item.artistName  = song.artist
        item.genre       = song.genre
        item.emoji       = "🎵"
        item.artworkURL  = song.artworkURLString
        item.moodWord    = mood.label
        item.moodColorHex = mood.color.toHex()
        item.moodLabel   = mood.label
        item.feeling     = feeling.rawValue
        item.feelingLabel = FeelingOption.all.first { $0.type == feeling }?.label ?? feeling.rawValue
        item.platform    = "Apple Music"
        item.dailyNote   = note.isEmpty ? nil : note

        // Photo
        if let photo {
            item.photoData = photo.jpegData(compressionQuality: 0.75)
        }
        item.shareWithCircle = sharePhoto && photo != nil
        item.isSharedWithCircle = sharePhoto && photo != nil

        try? context.save()
        
        let photoData = (sharePhoto && photo != nil) ? photo?.jpegData(compressionQuality: 0.75) : nil
        let streak = computeCurrentStreak(includingToday: true)
        CloudKitManager.shared.shareDailySong(
            songName: song.name,
            artistName: song.artist,
            genre: song.genre,
            emoji: "🎵",
            albumArtURL: song.artworkURLString,
            moodWord: mood.label,
            moodColor: mood.color.toHex(),
            moodTheme: "",
            dailyNote: note,
            platform: "Apple Music",
            date: today,
            photoData: photoData,
            feeling: feeling.rawValue,
            feelingLabel: FeelingOption.all.first { $0.type == feeling }?.label ?? feeling.rawValue,
            weatherIcon: item.weatherIcon ?? "☀️",
            weatherDesc: item.weatherDesc ?? "",
            currentStreak: streak
        ) { result in
            switch result {
            case .success(let record):
                ONELogger.debug("Successfully shared daily song to CloudKit: \(record.recordID)", category: .general)
            case .failure(let error):
                ONELogger.debug("Failed to share daily song to CloudKit: \(error)", category: .general)
            }
        }
        
        NotificationCenter.default.post(name: .init("todaySongSaved"), object: nil)
        // Bugün seçim yapıldı — hatırlatıcıyı iptal et
        NotificationManager.shared.cancelTodayReminderIfNeeded()
        loadTodayEntry()
    }

    // MARK: - Clear today (değiştir)
    func clearToday() {
        let today = Calendar.current.startOfDay(for: Date())
        
        // CloudKit'ten sil
        CloudKitManager.shared.deleteUserDailyShare(for: today) { result in
            switch result {
            case .success:
                ONELogger.success("Başarıyla CloudKit'ten silindi.", category: .general)
            case .failure(let error):
                ONELogger.error("CloudKit silme hatası: \(error.localizedDescription)", category: .general)
            }
        }
        
        let fetchRequest: NSFetchRequest<DailySong> = DailySong.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "date == %@", today as NSDate)

        if let items = try? context.fetch(fetchRequest) {
            items.forEach { context.delete($0) }
            try? context.save()
        }
        todayEntry = nil
        searchResults = []
        searchError = nil
    }

    // MARK: - Streak Calculation
    /// Counts consecutive days ending at today (inclusive). Returns 1 on first save.
    private func computeCurrentStreak(includingToday: Bool = true) -> Int {
        let fetchRequest: NSFetchRequest<DailySong> = DailySong.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "date", ascending: false)]
        guard let songs = try? context.fetch(fetchRequest) else { return 1 }

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        let filledDates = Set(songs.compactMap { s -> Date? in
            guard let d = s.date else { return nil }
            return calendar.startOfDay(for: d)
        })

        // If saving today, today counts even though it may not be in DB yet
        var streak = includingToday ? 1 : 0
        var checkDay = calendar.date(byAdding: .day, value: -1, to: today) ?? today
        while filledDates.contains(checkDay) {
            streak += 1
            guard let prev = calendar.date(byAdding: .day, value: -1, to: checkDay) else { break }
            checkDay = prev
        }
        return streak
    }

    // MARK: - Helpers
    private func dailyEntryFrom(_ item: DailySong) -> DailyEntry {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        let timeStr = item.createdAt.map { formatter.string(from: $0) } ?? "--:--"

        var photoURL: URL? = nil
        if let data = item.photoData {
            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent("\(item.id?.uuidString ?? UUID().uuidString).jpg")
            try? data.write(to: url)
            photoURL = url
        }

        return DailyEntry(
            id: item.id ?? UUID(),
            date: item.date ?? Date(),
            songName: item.songName ?? "",
            artistName: item.artistName ?? "",
            genre: item.genre ?? "",
            moodColor: Color(hex: item.moodColorHex ?? "#5B8DEF"),
            moodColorHex: item.moodColorHex ?? "#5B8DEF",
            moodLabel: item.moodLabel ?? item.moodWord ?? "",
            feeling: FeelingType(rawValue: item.feeling ?? "calm") ?? .calm,
            feelingLabel: item.feelingLabel ?? "",
            time: timeStr,
            photoURL: photoURL,
            shareWithCircle: item.shareWithCircle,
            weatherIcon: item.weatherIcon ?? "☀️",
            weatherDesc: item.weatherDesc ?? "",
            spotifyURL: nil,
            platform: "Spotify",
            note: item.dailyNote
        )
    }
    
    // MARK: - Auto-Sync
    private func syncLocalEntryToCloudKitIfNeeded(item: DailySong) {
        let today = Calendar.current.startOfDay(for: Date())
        
        // Sadece bugünün kaydıysa ve daha önceden eklendiyse senkronize etmeyi deneriz.
        guard let itemDate = item.date, Calendar.current.isDate(itemDate, inSameDayAs: today) else { return }
        
        CloudKitManager.shared.fetchUserDailyShare(for: today) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(_):
                    // Zaten CloudKit'te var
                    break
                case .failure(_):
                    // CloudKit'te yok ama lokalde var. Hemen yükleyelim.
                    ONELogger.debug("Senkronizasyon: Lokal şarkı bulundu ama CloudKit'te yok. Yükleniyor...", category: .general)
                    let photoData = item.shareWithCircle ? item.photoData : nil
                    let syncStreak = self.computeCurrentStreak(includingToday: true)
                    CloudKitManager.shared.shareDailySong(
                        songName: item.songName ?? "",
                        artistName: item.artistName ?? "",
                        genre: item.genre,
                        emoji: item.emoji ?? "🎵",
                        albumArtURL: item.artworkURL,
                        moodWord: item.moodWord ?? item.moodLabel ?? "",
                        moodColor: item.moodColorHex ?? "#5B8DEF",
                        moodTheme: "",
                        dailyNote: item.dailyNote,
                        platform: item.platform ?? "Apple Music",
                        date: today,
                        photoData: photoData,
                        feeling: item.feeling,
                        feelingLabel: item.feelingLabel,
                        weatherIcon: item.weatherIcon,
                        weatherDesc: item.weatherDesc,
                        currentStreak: syncStreak
                    ) { res in
                        switch res {
                        case .success(let record):
                            ONELogger.success("Başarıyla CloudKit'e senkronize edildi: \(record.recordID)", category: .general)
                        case .failure(let error):
                            ONELogger.error("CloudKit senkronizasyon hatası: \(error.localizedDescription)", category: .general)
                        }
                    }
                }
            }
        }
    }
}
