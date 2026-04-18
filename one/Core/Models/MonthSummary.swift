//
//  MonthSummary.swift
//  One - Günlük Mood
//

import Foundation

// MARK: - Month Summary Model
struct MonthSummary {
    let year: Int
    let month: Int            // 1–12
    let entries: [Date: [DailyEntry]]
    let totalDays: Int

    /// Number of unique days that have at least one entry
    var filledDays: Int { entries.count }

    /// Primary entry per day (last entry) — used for calendar display
    func primaryEntry(for date: Date) -> DailyEntry? {
        let startOfDay = Calendar.current.startOfDay(for: date)
        return entries[startOfDay]?.last
    }

    /// All entries for a given day
    func allEntries(for date: Date) -> [DailyEntry] {
        let startOfDay = Calendar.current.startOfDay(for: date)
        return entries[startOfDay] ?? []
    }

    /// Whether a day has multiple entries (premium multi-entry)
    func hasMultipleEntries(for date: Date) -> Bool {
        let startOfDay = Calendar.current.startOfDay(for: date)
        return (entries[startOfDay]?.count ?? 0) > 1
    }

    // Mood dağılımı — renk: gün sayısı (uses primary entry per day)
    var moodDistribution: [(color: String, count: Int)] {
        let primaryEntries = entries.values.compactMap { $0.last }
        let counts = primaryEntries.reduce(into: [String: Int]()) { dict, entry in
            dict[entry.moodColorHex, default: 0] += 1
        }
        return counts.map { ($0.key, $0.value) }.sorted { $0.count > $1.count }
    }

    // O ayın tüm günlerini sıralı döndür (takvim için)
    var orderedDays: [Date?] {
        let calendar = Calendar.current
        guard let firstDay = calendar.date(from: DateComponents(year: year, month: month, day: 1)) else {
            return []
        }

        let weekday = calendar.component(.weekday, from: firstDay)
        let offset = (weekday + 5) % 7  // Pazartesi = 0

        var days: [Date?] = Array(repeating: nil, count: offset)

        for day in 1...totalDays {
            if let date = calendar.date(from: DateComponents(year: year, month: month, day: day)) {
                days.append(date)
            }
        }

        return days
    }

    // Takvim grid için hücreler (7'nin katı olacak şekilde)
    var calendarCells: [Date?] {
        var cells = orderedDays
        let remainder = cells.count % 7
        if remainder != 0 {
            cells.append(contentsOf: Array(repeating: nil, count: 7 - remainder))
        }
        return cells
    }
}

// MARK: - Month Summary Extensions
extension MonthSummary {
    var monthName: String {
        let monthNames = [
            "Ocak", "Şubat", "Mart", "Nisan", "Mayıs", "Haziran",
            "Temmuz", "Ağustos", "Eylül", "Ekim", "Kasım", "Aralık"
        ]
        guard month >= 1 && month <= 12 else { return "" }
        return monthNames[month - 1]
    }

    var monthNameShort: String {
        let monthAbbreviations = [
            "OCA", "ŞUB", "MAR", "NİS", "MAY", "HAZ",
            "TEM", "AĞU", "EYL", "EKİ", "KAS", "ARA"
        ]
        guard month >= 1 && month <= 12 else { return "" }
        return monthAbbreviations[month - 1]
    }
}
