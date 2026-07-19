//
//  ArchiveStore.swift
//  One - Günlük Mood
//

import SwiftUI
import CoreData
import Combine

class ArchiveStore: ObservableObject {
    @Published var currentMonth: MonthSummary
    @Published var yearData: [MonthSummary]
    @Published var isLoading: Bool = false
    /// Prototipteki "bugün · geçen yıl" içgörüsü. Geçen yıl aynı günde kayıt
    /// yoksa nil — kart o zaman hiç çizilmez, uydurma metin gösterilmez.
    @Published var lastYearToday: DailyEntry?

    private let context: NSManagedObjectContext

    init(context: NSManagedObjectContext = PersistenceController.shared.container.viewContext) {
        self.context = context
        self.currentMonth = MonthSummary(year: 2025, month: 2, entries: [:], totalDays: 28)
        self.yearData = []
    }

    func loadData() {
        Task { await loadDataAsync() }
    }

    func loadDataAsync() async {
        await MainActor.run { isLoading = true }

        let calendar = Calendar.current
        let now = Date()
        let currentYear = calendar.component(.year, from: now)
        let currentMonthNum = calendar.component(.month, from: now)

        let bg = PersistenceController.shared.container.newBackgroundContext()
        let (newCurrentMonth, newYearData, lastYear) = await bg.perform {
            let month = self.loadMonth(year: currentYear, month: currentMonthNum, context: bg)
            let year  = (1...12).map { self.loadMonth(year: currentYear, month: $0, context: bg) }
            return (month, year, self.loadLastYearToday(now: now, context: bg))
        }

        await MainActor.run {
            self.currentMonth = newCurrentMonth
            self.yearData = newYearData
            self.lastYearToday = lastYear
            self.isLoading = false
        }
    }

    /// Bir yıl önce bugüne ait kayıt. Tek günlük dar sorgu — arşivin geri
    /// kalanı zaten yüklenirken aynı arka plan bağlamında koşar.
    private func loadLastYearToday(now: Date, context ctx: NSManagedObjectContext) -> DailyEntry? {
        let calendar = Calendar.current
        guard let lastYear = calendar.date(byAdding: .year, value: -1, to: now) else { return nil }
        let start = calendar.startOfDay(for: lastYear)
        guard let end = calendar.date(byAdding: .day, value: 1, to: start) else { return nil }

        let request: NSFetchRequest<DailySong> = DailySong.fetchRequest()
        request.predicate = NSPredicate(
            format: "date >= %@ AND date < %@", start as NSDate, end as NSDate
        )
        request.fetchLimit = 1

        guard let item = try? ctx.fetch(request).first else { return nil }
        return createEntry(from: item, using: calendar)
    }

    /// Yıl görünümünden seçilen aya geçiş için: o aya ait veriyi yükler.
    func loadSpecificMonth(month: Int) {
        Task { await loadSpecificMonthAsync(month: month) }
    }

    @MainActor
    private func loadSpecificMonthAsync(month: Int) async {
        let year = Calendar.current.component(.year, from: Date())
        let bg = PersistenceController.shared.container.newBackgroundContext()
        let result = await bg.perform { self.loadMonth(year: year, month: month, context: bg) }
        currentMonth = result
    }

    /// ← → navigasyon: offset = -1 (önceki ay), +1 (sonraki ay)
    func navigateMonth(by offset: Int) {
        Task { await navigateMonthAsync(by: offset) }
    }

    @MainActor
    private func navigateMonthAsync(by offset: Int) async {
        let calendar = Calendar.current
        guard let first = calendar.date(from: DateComponents(year: currentMonth.year, month: currentMonth.month, day: 1)),
              let target = calendar.date(byAdding: .month, value: offset, to: first) else { return }
        let y = calendar.component(.year,  from: target)
        let m = calendar.component(.month, from: target)
        let bg = PersistenceController.shared.container.newBackgroundContext()
        let newMonth = await bg.perform { self.loadMonth(year: y, month: m, context: bg) }
        currentMonth = newMonth
        if y != yearData.first?.year {
            let newYear = await bg.perform { (1...12).map { self.loadMonth(year: y, month: $0, context: bg) } }
            yearData = newYear
        }
    }

    var canGoForward: Bool {
        let cal = Calendar.current
        let now = Date()
        return !(currentMonth.year == cal.component(.year, from: now) &&
                 currentMonth.month == cal.component(.month, from: now))
    }
    
    /// Returns the primary (last) entry for a given date
    func entry(for date: Date) -> DailyEntry? {
        let startOfDay = Calendar.current.startOfDay(for: date)
        if let entry = currentMonth.entries[startOfDay]?.last { return entry }
        for month in yearData {
            if let entry = month.entries[startOfDay]?.last { return entry }
        }
        return nil
    }

    /// Returns all entries for a given date (supports premium multi-entry)
    func allEntries(for date: Date) -> [DailyEntry] {
        let startOfDay = Calendar.current.startOfDay(for: date)
        if let entries = currentMonth.entries[startOfDay], !entries.isEmpty { return entries }
        for month in yearData {
            if let entries = month.entries[startOfDay], !entries.isEmpty { return entries }
        }
        return []
    }
    
    private func loadMonth(year: Int, month: Int, context ctx: NSManagedObjectContext) -> MonthSummary {
        let calendar = Calendar.current

        guard let firstDay = calendar.date(from: DateComponents(year: year, month: month, day: 1)),
              let range = calendar.range(of: .day, in: .month, for: firstDay) else {
            ONELogger.warning("Tarih hesaplama hatası: year=\(year), month=\(month)", category: .persistence)
            return MonthSummary(year: year, month: month, entries: [:], totalDays: 30)
        }

        let totalDays = range.count

        guard let nextMonthFirstDay = calendar.date(byAdding: .month, value: 1, to: firstDay) else {
            ONELogger.warning("Sonraki ay hesaplama hatası", category: .persistence)
            return MonthSummary(year: year, month: month, entries: [:], totalDays: totalDays)
        }

        let fetchRequest: NSFetchRequest<DailySong> = DailySong.fetchRequest()
        fetchRequest.predicate = NSPredicate(
            format: "date >= %@ AND date < %@",
            firstDay as NSDate,
            nextMonthFirstDay as NSDate
        )
        
        var entries: [Date: [DailyEntry]] = [:]

        do {
            let items = try ctx.fetch(fetchRequest)

            for item in items {
                guard let timestamp = item.date else { continue }
                let startOfDay = calendar.startOfDay(for: timestamp)

                if let entry = createEntry(from: item, using: calendar) {
                    entries[startOfDay, default: []].append(entry)
                }
            }

            // Sort each day's entries by createdAt (via time string as proxy)
            for key in entries.keys {
                entries[key]?.sort { $0.time < $1.time }
            }
        } catch {
            // CoreData fetch hatası - boş entries ile devam et
            ONELogger.error("Arşiv yükleme hatası: \(error)", category: .persistence)
            return MonthSummary(year: year, month: month, entries: [:], totalDays: totalDays)
        }
        
        return MonthSummary(
            year: year,
            month: month,
            entries: entries,
            totalDays: totalDays
        )
    }
    
    // MARK: - CoreData Entity Mapper
    private func createEntry(from item: DailySong, using calendar: Calendar) -> DailyEntry? {
        guard let timestamp = item.date else { return nil }
        
        // Gerçek seçim zamanı için createdAt kullan, yoksa date'i fallback olarak kullan
        let actualTime = item.createdAt ?? timestamp
        
        // Fotoğraf URL'sini oluştur (photoData'dan)
        var photoURL: URL? = nil
        if let photoData = item.photoData, !photoData.isEmpty {
            let tempURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("\(item.id?.uuidString ?? UUID().uuidString).jpg")
            if !FileManager.default.fileExists(atPath: tempURL.path) {
                try? photoData.write(to: tempURL)
            }
            photoURL = tempURL
            ONELogger.debug("Fotoğraf yüklendi: \(item.songName ?? "?") - \(photoData.count) bytes", category: .persistence)
        } else if let photoURLString = item.photoURL {
            // Fallback: photoURL string varsa kullan
            photoURL = URL(string: photoURLString)
            ONELogger.debug("Fotoğraf URL'den yüklendi: \(item.songName ?? "?") - URL: \(photoURLString)", category: .persistence)
        }
        
        return DailyEntry(
            id: item.id ?? UUID(),
            date: timestamp,
            songName: item.songName ?? NSLocalizedString("archive.unknownSong", comment: ""),
            artistName: item.artistName ?? NSLocalizedString("archive.unknownArtist", comment: ""),
            genre: item.genre ?? NSLocalizedString("archive.unknown", comment: ""),
            moodColor: Color(hex: item.moodColorHex ?? "#607D8B"),
            moodColorHex: item.moodColorHex ?? "#607D8B",
            moodLabel: item.moodLabel ?? item.moodWord ?? NSLocalizedString("archive.defaultMood", comment: ""),
            feeling: FeelingType(rawValue: item.feeling ?? "calm") ?? .calm,
            feelingLabel: item.feelingLabel ?? NSLocalizedString("archive.defaultFeeling", comment: ""),
            time: formatTime(actualTime),
            photoURL: photoURL,
            shareWithCircle: item.shareWithCircle,
            weatherIcon: item.weatherIcon ?? "☀️",
            weatherDesc: item.weatherDesc ?? "—",
            spotifyURL: item.spotifyURL.flatMap { URL(string: $0) },
            platform: "Spotify",
            note: item.dailyNote,
            passed: item.passed
        )
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
}
