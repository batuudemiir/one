//
//  MonthlySummaryViewModel.swift
//  one
//
//  CoreData'dan seçili ayın verilerini çekip MonthlySummaryData'ya dönüştürür.
//

import SwiftUI
import Combine
import CoreData

@MainActor
class MonthlySummaryViewModel: ObservableObject {
    @Published var summaryData: MonthlySummaryData?
    @Published var isLoading = true

    private let context: NSManagedObjectContext
    private let year: Int
    private let month: Int

    init(context: NSManagedObjectContext, year: Int, month: Int) {
        self.context = context
        self.year = year
        self.month = month
    }

    func load() {
        Task {
            let songs = fetchMonthSongs()
            let data  = Self.build(year: year, month: month, songs: songs)
            self.summaryData = data
            self.isLoading   = false
        }
    }

    // MARK: — CoreData Fetch
    private func fetchMonthSongs() -> [DailySong] {
        PersistenceController.shared.fetchDailySongsForMonth(
            year: year,
            month: month,
            context: context
        )
    }

    // MARK: — Build MonthlySummaryData
    private static func build(year: Int, month: Int, songs: [DailySong]) -> MonthlySummaryData {
        let calendar = Calendar.current

        // Ay adı (Türkçe)
        var comps = DateComponents()
        comps.year = year; comps.month = month; comps.day = 1
        let firstDay = calendar.date(from: comps) ?? Date()
        let monthFmt = DateFormatter()
        monthFmt.locale = LanguageManager.shared.currentLocale
        monthFmt.dateFormat = "MMMM"
        let monthName = monthFmt.string(from: firstDay).capitalized

        // Ayın gün sayısı
        let range      = calendar.range(of: .day, in: .month, for: firstDay)
        let totalDays  = range?.count ?? 30

        // Helper: DailySong → Color
        func color(for song: DailySong?) -> Color {
            guard let hex = song?.moodColorHex else { return Color.gray.opacity(0.3) }
            return Color(hex: hex)
        }

        // Günlük mood dizisi (totalDays eleman, veri yoksa gri)
        let dailyMoods: [Color] = (1...totalDays).map { day -> Color in
            var dc = DateComponents()
            dc.year = year; dc.month = month; dc.day = day
            guard let date = calendar.date(from: dc) else { return Color.gray.opacity(0.2) }
            let start = calendar.startOfDay(for: date)
            let end   = calendar.date(byAdding: .day, value: 1, to: start)!
            let match = songs.first { s in
                guard let d = s.date else { return false }
                return d >= start && d < end
            }
            return color(for: match)
        }

        // Benzersiz sanatçı sayısı
        let uniqueArtists = Set(songs.compactMap { $0.artistName }).count

        // Tekrar sayısı (en çok çalınan şarkı)
        var songCount: [String: Int] = [:]
        for s in songs {
            guard let n = s.songName, let a = s.artistName else { continue }
            let k = "\(n)|\(a)"
            songCount[k, default: 0] += 1
        }
        let maxRepeat = songCount.values.max() ?? 1

        // Benzersiz gün sayısı (daysLogged)
        let loggedDayNumbers: Set<Int> = Set(songs.compactMap { s -> Int? in
            guard let d = s.date else { return nil }
            return calendar.component(.day, from: d)
        })
        let daysLogged = loggedDayNumbers.count

        // Ay içindeki en uzun ardışık seri (monthStreak)
        let monthStreak: Int = {
            var streak = 0, current = 0
            for day in 1...totalDays {
                if loggedDayNumbers.contains(day) { current += 1; streak = max(streak, current) }
                else { current = 0 }
            }
            return streak
        }()

        // Baskın mood (en çok tekrar eden moodWord)
        var moodCount: [String: (count: Int, hex: String)] = [:]
        for s in songs {
            guard let word = s.moodWord else { continue }
            let hex = s.moodColorHex ?? "#6B6965"
            var entry = moodCount[word] ?? (0, hex)
            entry.count += 1
            moodCount[word] = entry
        }
        let dominantEntry    = moodCount.max(by: { $0.value.count < $1.value.count })
        let dominantMood     = dominantEntry?.key ?? "—"
        let dominantColor    = Color(hex: dominantEntry?.value.hex ?? "#C97840")

        // Duygu dağılımı — 12 yeni mood etiketleri + eski uyum
        let moodPalette: [String: Color] = [
            "Ateşli"     : ONETokens.oneRed,
            "Coşkulu"    : ONETokens.moodOrange,
            "Mutlu"      : ONETokens.moodYellow,
            "Doğal"      : ONETokens.moodLime,
            "Huzurlu"    : ONETokens.oneGreen,
            "Özgür"      : ONETokens.moodTeal,
            "Derin"      : ONETokens.oneBlue,
            "Nostaljik"  : ONETokens.moodIndigo,
            "Gizemli"    : ONETokens.moodPurple,
            "Hassas"     : ONETokens.moodRose,
            "Sessiz"     : ONETokens.moodDark,
            "Nötr"       : ONETokens.oneIvory,
            // Legacy labels
            "Enerjik"    : ONETokens.moodOrange,
            "Neşeli"     : ONETokens.moodYellow,
            "Sakin"      : ONETokens.oneGreen,
            "Melankolik" : ONETokens.moodPurple,
            "Gergin"     : ONETokens.oneRed,
            "Üzgün"      : ONETokens.moodIndigo,
        ]
        let total = Double(max(1, daysLogged))
        let emotionBreakdown: [(name: String, percentage: Double, color: Color)] = moodCount
            .sorted { $0.value.count > $1.value.count }
            .prefix(5)
            .map { word, val in
                let c = moodPalette[word] ?? Color(hex: val.hex)
                return (name: word, percentage: min(1.0, Double(val.count) / total), color: c)
            }

        // Top parçalar (en fazla tekrar eden, max 5) — eşitlikte en yakın tarihe göre
        let gradientPairs: [[Color]] = [
            [ONETokens.summaryFireStart,  ONETokens.summaryFireEnd],     // #D85A1A → #E6A61A
            [ONETokens.summaryMockBlue,   ONETokens.summaryMockTeal],    // #4070C9 → #40A89C
            [ONETokens.summaryMockPurple, ONETokens.summaryMockRed],     // #7840C9 → #C94040
            [ONETokens.summaryMockRed,    ONETokens.summaryEmberAmber],  // #C94040 → #D8801A
            [ONETokens.summaryMockTeal,   ONETokens.summaryMockBlue],    // #40A89C → #4070C9
        ]
        // Build recency map for tie-breaking
        var recencyMap: [String: Date] = [:]
        for s in songs {
            guard let n = s.songName, let a = s.artistName, let d = s.date else { continue }
            let k = "\(n)|\(a)"
            recencyMap[k] = max(recencyMap[k] ?? .distantPast, d)
        }
        let topTracks: [TrackEntry] = songCount
            .sorted { lhs, rhs in
                if lhs.value != rhs.value { return lhs.value > rhs.value }
                return (recencyMap[lhs.key] ?? .distantPast) > (recencyMap[rhs.key] ?? .distantPast)
            }
            .prefix(5)
            .enumerated()
            .map { idx, pair -> TrackEntry in
                let parts   = pair.key.components(separatedBy: "|")
                let name    = parts[0]
                let artist  = parts.count > 1 ? parts[1] : ""
                let emoji   = songs.first { $0.songName == name && $0.artistName == artist }?.emoji ?? "🎵"
                return TrackEntry(
                    rank:           idx + 1,
                    name:           name,
                    artist:         artist,
                    days:           pair.value,
                    gradientColors: gradientPairs[idx % gradientPairs.count],
                    emoji:          emoji
                )
            }
            
        // MARK: - Storytelling Elements
        var hourCount: [Int: Int] = [:]
        for s in songs {
            guard let d = s.date else { continue }
            let hour = calendar.component(.hour, from: d)
            hourCount[hour, default: 0] += 1
        }
        let mostActiveHour = hourCount.max(by: { $0.value < $1.value })?.key ?? 20
        let hourString = String(format: "%02d:00", mostActiveHour)

        let storyTitle = String(format: NSLocalizedString("monthly.storyTitle", comment: ""), dominantMood)
        let storySubtitle = String(format: NSLocalizedString("monthly.storySubtitle", comment: ""), hourString)

        return MonthlySummaryData(
            month:              monthName,
            year:               year,
            totalDays:          totalDays,
            uniqueArtists:      uniqueArtists,
            maxRepeat:          maxRepeat,
            dominantMood:       dominantMood,
            dominantMoodColor:  dominantColor,
            dailyMoods:         dailyMoods,
            emotionBreakdown:   emotionBreakdown.isEmpty
                                    ? [(name: "—", percentage: 1.0, color: .gray.opacity(0.3))]
                                    : emotionBreakdown,
            topTracks:          topTracks,
            totalEntries:       songs.count,
            daysLogged:         daysLogged,
            monthStreak:        monthStreak,
            storyTitle:         storyTitle,
            storySubtitle:      storySubtitle
        )
    }
}
