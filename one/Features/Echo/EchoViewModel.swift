//
//  EchoViewModel.swift
//  One - Günlük Mood
//

import SwiftUI
import Combine
import CoreData

class EchoViewModel: ObservableObject {
    @Published var data: EchoData = .empty
    @Published var isLoading = true
    @Published var isSyncLoading = false
    /// "Bu Ay" toggle — affects moodDistribution and repeatedSongs shown in UI
    @Published var showThisMonth = false

    private let context: NSManagedObjectContext
    private let cloudKit = CloudKitManager.shared

    /// `.momentsDidChangeRemotely` aboneliği — bkz. `refreshAfterRemoteChange()`.
    ///
    /// Echo yalnızca `init` içinde bir kez hesaplıyordu; sayfa açıkken başka
    /// cihazdan inen kayıt, sheet kapanıp yeniden açılana kadar sayılara
    /// yansımıyordu.
    private var remoteChangeSubscription: AnyCancellable?

    init(context: NSManagedObjectContext) {
        self.context = context
        Task {
            await compute()
        }

        remoteChangeSubscription = NotificationCenter.default
            .publisher(for: .momentsDidChangeRemotely)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                Task { @MainActor in self?.refreshAfterRemoteChange() }
            }
    }

    /// Uzaktan inen kayıttan sonra yerel istatistikleri tazeler.
    ///
    /// `compute()` çağrılmıyor: o yerel hesabın ardından `fetchCircleSyncMatches`
    /// ile CloudKit'e gidiyor. Sync bir salvo hâlinde iniyor, yani bildirim
    /// başına bir çevre sorgusu demek olurdu — `CloudKitManager.isThrottled`
    /// bu uygulamada gerçek bir durum. Eşleşmeler zaten elde; yeniden kurulan
    /// `EchoData`'ya olduğu gibi taşınıyor.
    ///
    /// `MainActor` üzerinde: `fetchAllSongs()` viewContext okuyor.
    @MainActor
    private func refreshAfterRemoteChange() {
        let songs = fetchAllSongs()
        data = EchoViewModel.buildEchoData(
            from: songs,
            circleSyncMatches: data.circleSyncMatches
        )
        // İlk `compute()` bitmeden bildirim indiyse ekran yükleniyor'da
        // asılı kalmasın — veriyi az önce doldurduk.
        isLoading = false
    }

    /// `MainActor` üzerinde: `fetchAllSongs()` ve `buildEchoData()` ikisi de
    /// viewContext'e bağlı `DailySong` nesnelerine dokunuyor. Eskiden fetch
    /// izolasyonsuz koşuyor, yalnız `buildEchoData` `MainActor.run` ile
    /// sarılıyordu — yani okuma zaten ana aktördeydi, *fetch'in kendisi*
    /// değildi. Hesabın ağırlığı değişmiyor, yalnız kuyruk doğrulanıyor.
    @MainActor
    func compute() async {
        let songs = fetchAllSongs()

        // Yerel veriden temel istatistikleri hesapla
        data = EchoViewModel.buildEchoData(from: songs, circleSyncMatches: [])
        isLoading = false

        // CloudKit'ten çevre eşleşmelerini çek. Alanlar burada, ana aktörde
        // çıkarılıyor; sınırın ötesine `DailySong` geçmiyor.
        await fetchCircleSyncMatches(candidates: Self.syncCandidates(from: songs))
    }

    /// Eşleştirme için gereken alanları `DailySong`'dan çıkarır.
    ///
    /// Filtre eski davranışı koruyor: tarihsiz, şarkısız veya sanatçısız
    /// satır zaten eşleşemiyordu. Yan etkisi, arkadaş sorgusunun tarih
    /// aralığının artık yalnız şarkılı günlere göre kurulması — dışarıda
    /// kalan günlerde eşleşme mümkün olmadığı için sonuç aynı, çekilen
    /// kayıt daha az.
    @MainActor
    private static func syncCandidates(from songs: [DailySong]) -> [CircleSyncCandidate] {
        songs.compactMap { song in
            guard let date = song.date,
                  let name = song.songName,
                  let artist = song.artistName,
                  !name.trimmingCharacters(in: .whitespaces).isEmpty
            else { return nil }
            return CircleSyncCandidate(
                date: date,
                songName: name,
                artistName: artist,
                moodColorHex: song.moodColorHex ?? "#888888"
            )
        }
    }

    @MainActor
    private func fetchCircleSyncMatches(candidates: [CircleSyncCandidate]) async {
        isSyncLoading = true

        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            cloudKit.fetchCircleSyncMatches(myEntries: candidates) { [weak self] result in
                guard let self else { continuation.resume(); return }
                switch result {
                case .success(let matches):
                    ONELogger.success("EchoViewModel: \(matches.count) circle sync eşleşmesi", category: .circle)
                    Task { @MainActor in
                        // Mevcut data'yı eşleşmelerle güncelle
                        self.data = EchoData(
                            weekColors: self.data.weekColors,
                            dominantFeeling: self.data.dominantFeeling,
                            repeatedSongs: self.data.repeatedSongs,
                            silentDays: self.data.silentDays,
                            silentDates: self.data.silentDates,
                            hourDistribution: self.data.hourDistribution,
                            circleSyncMatches: matches,
                            last30DaysColors: self.data.last30DaysColors,
                            totalSongs: self.data.totalSongs,
                            thisMonthSongs: self.data.thisMonthSongs,
                            mostActiveDayOfWeek: self.data.mostActiveDayOfWeek,
                            averageSongsPerMonth: self.data.averageSongsPerMonth,
                            moodDistribution: self.data.moodDistribution,
                            thisMonthMoodDistribution: self.data.thisMonthMoodDistribution
                        )
                        self.isSyncLoading = false
                        continuation.resume()
                    }
                case .failure(let err):
                    ONELogger.error("EchoViewModel: circle sync hatası", error: err, category: .circle)
                    Task { @MainActor in
                        self.isSyncLoading = false
                        continuation.resume()
                    }
                }
            }
        }
    }

    /// viewContext okuyor — çağıranlar ana aktörde olmak zorunda.
    @MainActor
    private func fetchAllSongs() -> [DailySong] {
        let fetchRequest: NSFetchRequest<DailySong> = DailySong.fetchRequest()
        // Sinirsiz tarama: kayit sayisi buyudukce bellek dogrusal artiyordu.
        // Batch faulting ile tepe bellek sabit kaliyor.
        fetchRequest.fetchBatchSize = 100
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "date", ascending: false)]
        return (try? context.fetch(fetchRequest)) ?? []
    }

    // MARK: - Compute EchoData (runs on background thread)
    private static func buildEchoData(from songs: [DailySong], circleSyncMatches: [CircleSyncMatch]) -> EchoData {
        let calendar = Calendar.current
        let now = Date()
        let monthFmt = DateFormatter()
        monthFmt.locale = LanguageManager.shared.currentLocale
        monthFmt.dateFormat = "d MMM"

        // ── Bu haftanın Pazartesi'si ────────────────────────────
        let todayStartOfDay = calendar.startOfDay(for: now)
        // calendar.component(.weekday): 1=Pazar, 2=Pts, ..., 7=Cts
        let weekday = calendar.component(.weekday, from: todayStartOfDay)
        let daysFromMonday = (weekday + 5) % 7  // Pts=0, Sal=1, ..., Paz=6
        let thisMonday = calendar.date(byAdding: .day, value: -daysFromMonday, to: todayStartOfDay)!
        let nextMonday = calendar.date(byAdding: .day, value: 7, to: thisMonday)!

        // ── Week colors (Bu haftanın Pts–Paz'ı) ────────────────
        let weekColors: [Color?] = (0..<7).map { offset -> Color? in
            guard let day = calendar.date(byAdding: .day, value: offset, to: thisMonday) else { return nil }
            let start = calendar.startOfDay(for: day)
            // Gelecek günler boş
            if start > todayStartOfDay { return nil }
            let end = calendar.date(byAdding: .day, value: 1, to: start)!
            let match = songs
                .filter { s in guard let d = s.date else { return false }; return d >= start && d < end }
                .max(by: { ($0.createdAt ?? .distantPast) < ($1.createdAt ?? .distantPast) })
            if let hex = match?.moodColorHex { return Color(hex: hex) }
            return nil
        }

        // ── Dominant feeling this week (Pts–Paz) ───────────────
        let weekSongs = songs.filter {
            guard let d = $0.date else { return false }
            return d >= thisMonday && d < nextMonday
        }
        let feelingCounts = weekSongs.reduce(into: [String: Int]()) { d, s in
            guard let f = s.feeling else { return }
            d[f, default: 0] += 1
        }
        let dominantFeeling = feelingCounts.max(by: { $0.value < $1.value })
            .flatMap { FeelingType(rawValue: $0.key) }

        // ── Repeated songs ──────────────────────────────────────
        var songMap: [String: (count: Int, hex: String, dates: [String])] = [:]
        for s in songs {
            guard let name = s.songName, let artist = s.artistName else { continue }
            let key = "\(name)|\(artist)"
            let dateStr = s.date.map { monthFmt.string(from: $0) } ?? ""
            var entry = songMap[key] ?? (0, s.moodColorHex ?? "#888888", [])
            entry.count += 1
            if !dateStr.isEmpty { entry.dates.append(dateStr) }
            songMap[key] = entry
        }
        let repeatedSongs: [RepeatedSong] = songMap
            .filter { $0.value.count > 1 }
            .map { key, val -> RepeatedSong in
                let parts = key.components(separatedBy: "|")
                return RepeatedSong(
                    id: UUID(),
                    songName: parts[0],
                    artistName: parts.count > 1 ? parts[1] : "",
                    moodColorHex: val.hex,
                    dates: Array(val.dates.prefix(4)),
                    count: val.count
                )
            }
            .sorted { $0.count > $1.count }

        // ── Silent days in current year ──────────────────────────
        let year = calendar.component(.year, from: now)
        let yearStart = calendar.date(from: DateComponents(year: year, month: 1, day: 1)) ?? now
        let daysSoFar = max(0, calendar.dateComponents([.day], from: yearStart, to: now).day ?? 0)
        let filledDates = Set(songs.compactMap { s -> Date? in
            guard let d = s.date else { return nil }
            return calendar.startOfDay(for: d)
        })
        var silentDates: [String] = []
        for i in 0..<daysSoFar {
            if let day = calendar.date(byAdding: .day, value: i, to: yearStart) {
                let start = calendar.startOfDay(for: day)
                if !filledDates.contains(start) {
                    silentDates.append(monthFmt.string(from: start))
                }
            }
        }

        // ── Hour distribution ──────────────────────────────────
        let hourDist = songs.reduce(into: [Int: Int]()) { d, s in
            guard let date = s.createdAt ?? s.date else { return }
            let h = Calendar.current.component(.hour, from: date)
            d[h, default: 0] += 1
        }

        // ── Sync count: CloudKit'ten gelir, burada placeholder ──

        // ── Genel istatistikler ─────────────────────────────────
        let totalSongs = songs.count

        // Bu ay kayıtları
        let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: now)) ?? now
        let nextMonthStart = calendar.date(byAdding: .month, value: 1, to: monthStart) ?? now
        let thisMonthSongs = songs.filter { s in
            guard let d = s.date else { return false }
            return d >= monthStart && d < nextMonthStart
        }.count

        // Haftanın en aktif günü (tüm zamanlar)
        let dayCounts = songs.reduce(into: [Int: Int]()) { d, s in
            guard let date = s.date else { return }
            let weekday = calendar.component(.weekday, from: date) // 1=Sun, 2=Mon…7=Sat
            d[weekday, default: 0] += 1
        }
        let mostActiveWeekday = dayCounts.max(by: { $0.value < $1.value })?.key
        let df = DateFormatter()
        df.locale = Locale.current
        df.dateFormat = "EEEE"
        let mostActiveDayOfWeek: String? = mostActiveWeekday.flatMap { weekday in
            // weekday: 1=Sun, 2=Mon, ..., 7=Sat
            var comps = DateComponents()
            comps.weekday = weekday
            return calendar.nextDate(after: Date(), matching: comps, matchingPolicy: .nextTime)
                .map { df.string(from: $0) }
        }

        // Aylık ortalama şarkı sayısı
        let allMonths = Set(songs.compactMap { s -> String? in
            guard let d = s.date else { return nil }
            let comps = calendar.dateComponents([.year, .month], from: d)
            return "\(comps.year ?? 0)-\(comps.month ?? 0)"
        })
        let averageSongsPerMonth: Double = allMonths.isEmpty ? 0 :
            Double(totalSongs) / Double(allMonths.count)

        // Mood dağılımı (tüm zamanlar)
        let allMoodMap = songs.reduce(into: [String: (count: Int, hex: String)]()) { d, s in
            guard let mood = s.moodWord, !mood.isEmpty else { return }
            let hex = s.moodColorHex ?? "#888888"
            d[mood] = (d[mood].map { ($0.count + 1, $0.hex) } ?? (1, hex))
        }
        let moodDistribution = allMoodMap
            .map { MoodStat(label: $0.key, colorHex: $0.value.hex, count: $0.value.count) }
            .sorted { $0.count > $1.count }

        // Bu ayki mood dağılımı
        let thisMonthSongList = songs.filter { s in
            guard let d = s.date else { return false }
            return d >= monthStart && d < nextMonthStart
        }
        let monthMoodMap = thisMonthSongList.reduce(into: [String: (count: Int, hex: String)]()) { d, s in
            guard let mood = s.moodWord, !mood.isEmpty else { return }
            let hex = s.moodColorHex ?? "#888888"
            d[mood] = (d[mood].map { ($0.count + 1, $0.hex) } ?? (1, hex))
        }
        let thisMonthMoodDistribution = monthMoodMap
            .map { MoodStat(label: $0.key, colorHex: $0.value.hex, count: $0.value.count) }
            .sorted { $0.count > $1.count }

        // ── 30-Day Colors ──────────────────────────────────────
        let thirtyDaysAgo = calendar.date(byAdding: .day, value: -29, to: startOfDay(for: now, calendar: calendar)) ?? now
        let thirtyDayColors: [Color?] = (0..<30).map { offset -> Color? in
            guard let day = calendar.date(byAdding: .day, value: offset, to: thirtyDaysAgo) else { return nil }
            let start = calendar.startOfDay(for: day)
            let end = calendar.date(byAdding: .day, value: 1, to: start)!
            let match = songs
                .filter { s in guard let d = s.date else { return false }; return d >= start && d < end }
                .max(by: { ($0.createdAt ?? .distantPast) < ($1.createdAt ?? .distantPast) })
            if let hex = match?.moodColorHex { return Color(hex: hex) }
            return nil
        }

        return EchoData(
            weekColors: weekColors,
            dominantFeeling: dominantFeeling,
            repeatedSongs: repeatedSongs,
            silentDays: silentDates.count,
            silentDates: silentDates,
            hourDistribution: hourDist,
            circleSyncMatches: circleSyncMatches,
            last30DaysColors: thirtyDayColors,
            totalSongs: totalSongs,
            thisMonthSongs: thisMonthSongs,
            mostActiveDayOfWeek: mostActiveDayOfWeek,
            averageSongsPerMonth: averageSongsPerMonth,
            moodDistribution: moodDistribution,
            thisMonthMoodDistribution: thisMonthMoodDistribution
        )
    }

    @MainActor private static func startOfDay(for date: Date, calendar: Calendar) -> Date {
        calendar.startOfDay(for: date)
    }
}
