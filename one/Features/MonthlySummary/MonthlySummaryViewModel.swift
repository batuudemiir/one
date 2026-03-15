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
        monthFmt.locale = Locale(identifier: "tr_TR")
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
        let total = Double(max(1, songs.count))
        let emotionBreakdown: [(name: String, percentage: Double, color: Color)] = moodCount
            .sorted { $0.value.count > $1.value.count }
            .prefix(5)
            .map { word, val in
                let c = moodPalette[word] ?? Color(hex: val.hex)
                return (name: word, percentage: Double(val.count) / total, color: c)
            }

        // Top parçalar (en fazla tekrar eden, max 5)
        let gradientPairs: [[Color]] = [
            [Color(red: 0.85, green: 0.35, blue: 0.10), Color(red: 0.90, green: 0.65, blue: 0.10)],
            [Color(red: 0.25, green: 0.44, blue: 0.80), Color(red: 0.25, green: 0.66, blue: 0.61)],
            [Color(red: 0.47, green: 0.25, blue: 0.80), Color(red: 0.78, green: 0.25, blue: 0.25)],
            [Color(red: 0.78, green: 0.25, blue: 0.25), Color(red: 0.85, green: 0.50, blue: 0.10)],
            [Color(red: 0.25, green: 0.66, blue: 0.61), Color(red: 0.25, green: 0.44, blue: 0.80)],
        ]
        let topTracks: [TrackEntry] = songCount
            .sorted { $0.value > $1.value }
            .prefix(5)
            .enumerated()
            .map { idx, pair -> TrackEntry in
                let parts   = pair.key.components(separatedBy: "|")
                let name    = parts[0]
                let artist  = parts.count > 1 ? parts[1] : ""
                // emoji'yi kayıtlı veriden bul
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
            topTracks:          topTracks
        )
    }
}
