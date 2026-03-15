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
    
    private let context: NSManagedObjectContext
    
    init(context: NSManagedObjectContext = PersistenceController.shared.container.viewContext) {
        self.context = context
        
        // Başlangıç değerleri
        self.currentMonth = MonthSummary(year: 2025, month: 2, entries: [:], totalDays: 28)
        self.yearData = []
        
        // Veriyi yükle
        loadData()
    }
    
    func loadData() {
        let calendar = Calendar.current
        let now = Date()
        let currentYear = calendar.component(.year, from: now)
        let currentMonthNum = calendar.component(.month, from: now)
        
        // Mevcut ayı yükle
        currentMonth = loadMonth(year: currentYear, month: currentMonthNum)
        
        // Tüm yılı yükle (12 ay)
        yearData = (1...12).map { month in
            loadMonth(year: currentYear, month: month)
        }
    }
    
    /// Yıl görünümünden seçilen aya geçiş için: o aya ait veriyi yükler.
    func loadSpecificMonth(month: Int) {
        let calendar = Calendar.current
        let year = calendar.component(.year, from: Date())
        currentMonth = loadMonth(year: year, month: month)
    }

    /// ← → navigasyon: offset = -1 (önceki ay), +1 (sonraki ay)
    func navigateMonth(by offset: Int) {
        let calendar = Calendar.current
        guard let first = calendar.date(from: DateComponents(year: currentMonth.year, month: currentMonth.month, day: 1)),
              let target = calendar.date(byAdding: .month, value: offset, to: first) else { return }
        let y = calendar.component(.year,  from: target)
        let m = calendar.component(.month, from: target)
        currentMonth = loadMonth(year: y, month: m)
        // yearData'yı doğru yıl için güncelle
        if y != yearData.first?.year {
            yearData = (1...12).map { loadMonth(year: y, month: $0) }
        }
    }

    var canGoForward: Bool {
        let cal = Calendar.current
        let now = Date()
        return !(currentMonth.year == cal.component(.year, from: now) &&
                 currentMonth.month == cal.component(.month, from: now))
    }
    
    func entry(for date: Date) -> DailyEntry? {
        let startOfDay = Calendar.current.startOfDay(for: date)
        // Search currentMonth first, then fallback to any month in yearData
        if let entry = currentMonth.entries[startOfDay] { return entry }
        for month in yearData {
            if let entry = month.entries[startOfDay] { return entry }
        }
        return nil
    }
    
    private func loadMonth(year: Int, month: Int) -> MonthSummary {
        let calendar = Calendar.current
        
        // Ayın gün sayısını hesapla
        guard let firstDay = calendar.date(from: DateComponents(year: year, month: month, day: 1)),
              let range = calendar.range(of: .day, in: .month, for: firstDay) else {
            // Tarih hesaplama hatası - varsayılan 30 gün kullan
            ONELogger.warning("Tarih hesaplama hatası: year=\(year), month=\(month)", category: .persistence)
            return MonthSummary(year: year, month: month, entries: [:], totalDays: 30)
        }
        
        let totalDays = range.count
        
        // CoreData'dan entry'leri çek
        let fetchRequest: NSFetchRequest<DailySong> = DailySong.fetchRequest()
        
        // Sonraki ayın ilk gününü güvenli şekilde hesapla
        guard let nextMonthFirstDay = calendar.date(byAdding: .month, value: 1, to: firstDay) else {
            ONELogger.warning("Sonraki ay hesaplama hatası", category: .persistence)
            return MonthSummary(year: year, month: month, entries: [:], totalDays: totalDays)
        }
        
        fetchRequest.predicate = NSPredicate(
            format: "date >= %@ AND date < %@",
            firstDay as NSDate,
            nextMonthFirstDay as NSDate
        )
        
        var entries: [Date: DailyEntry] = [:]
        
        do {
            let items = try context.fetch(fetchRequest)
            
            for item in items {
                guard let timestamp = item.date else { continue }
                let startOfDay = calendar.startOfDay(for: timestamp)
                
                if let entry = createEntry(from: item, using: calendar) {
                    entries[startOfDay] = entry
                }
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
            // Temp dizine kaydet ve URL oluştur
            let tempURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("\(item.id?.uuidString ?? UUID().uuidString).jpg")
            try? photoData.write(to: tempURL)
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
            songName: item.songName ?? "Bilinmeyen Şarkı",
            artistName: item.artistName ?? "Bilinmeyen Sanatçı",
            genre: item.genre ?? "Bilinmeyen",
            moodColor: Color(hex: item.moodColorHex ?? "#607D8B"),
            moodColorHex: item.moodColorHex ?? "#607D8B",
            moodLabel: item.moodLabel ?? item.moodWord ?? "Nötr",
            feeling: FeelingType(rawValue: item.feeling ?? "calm") ?? .calm,
            feelingLabel: item.feelingLabel ?? "Dingin",
            time: formatTime(actualTime),
            photoURL: photoURL,
            shareWithCircle: item.shareWithCircle,
            weatherIcon: item.weatherIcon ?? "☀️",
            weatherDesc: item.weatherDesc ?? "—",
            spotifyURL: item.spotifyURL.flatMap { URL(string: $0) },
            platform: "Spotify",
            note: item.dailyNote
        )
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
}
