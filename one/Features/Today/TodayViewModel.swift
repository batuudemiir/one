//
//  TodayViewModel.swift
//  One - Günlük Mood
//

import SwiftUI
import Combine
import CoreData
import MusicKit
import CloudKit
import ActivityKit

// MARK: - TodayViewModel
@MainActor
class TodayViewModel: ObservableObject {
    @Published var todayEntries: [DailyEntry] = []
    @Published var searchResults: [SongResult] = []
    @Published var recentArtists: [String] = []
    @Published var recommendedSongs: [SongResult] = []
    @Published var isSearching: Bool = false
    @Published var searchError: String? = nil
    @Published var showLiveActivityAlert: Bool = false
    @Published var circleShareFailed: Bool = false
    @Published var streakMilestone: Int? = nil
    @Published var lastYearEntry: DailyEntry? = nil
    /// C3 — "1 hafta önce bugün" mini Echo (D14+ daha anlamlı, ama her zaman göster).
    @Published var lastWeekEntry: DailyEntry? = nil
    @Published var showLastWeekReflection: Bool = false
    private var hasShownLastWeekReflectionThisSession: Bool = false
    /// A4 — Çevre davet kancası: yalnızca ilk kayıttan sonra bir kez tetiklenir.
    @Published var showFirstEntryInvite: Bool = false
    /// B1 — Streak freeze son hesaplamada devreye girdi mi?
    @Published var streakFreezeUsedRecently: Bool = false
    /// B1 — Şu an kullanıcının taze bir freeze hakkı var mı?
    @Published var streakFreezeAvailable: Bool = true
    /// Mevcut streak gün sayısı — UI bileşenlerine doğrudan açılır.
    @Published var streakDays: Int = 0
    /// Son kırılan streak gün sayısı (kırılma ≥ 7 gün ise empati kartı göster).
    @Published var lastBrokenStreakDays: Int = 0
    /// This week's logged entries for WeeklyProgressDots.
    @Published var thisWeekEntries: [(date: Date, moodColorHex: String)] = []
    /// Total entry count ever (for milestone insights).
    @Published var totalEntryCount: Int = 0
    /// Days since last entry before today (nil = no prior entry).
    @Published var daysSinceLastEntry: Int? = nil
    /// Yesterday's mood, if logged.
    @Published var yesterdayMood: (label: String, color: Color)? = nil

    /// Last recorded mood surfaced instantly from UserDefaults so the first
    /// frame can echo it while the real CoreData fetch settles. `nil` on a
    /// fresh install — fall back to the normal empty state.
    let cachedEchoMood: (hex: String, label: String)?

    /// Flips true after the initial CoreData fetch of today's entries
    /// finishes. Views cross-fade the echo overlay off when this trips.
    @Published private(set) var hasHydratedTodayEntry: Bool = false

    let context: NSManagedObjectContext
    private var searchTask: Task<Void, Never>? = nil
    private var syncTask: Task<Void, Never>? = nil
    /// `.momentsDidChangeRemotely` aboneliği — bkz. `refreshAfterRemoteChange()`.
    private var remoteChangeSubscription: AnyCancellable?

    // MARK: - Echo mood cache (fastest possible first frame)
    private static let echoMoodHexKey   = "todayEchoMoodHex"
    private static let echoMoodLabelKey = "todayEchoMoodLabel"

    static func readCachedEchoMood() -> (hex: String, label: String)? {
        let d = UserDefaults.standard
        guard let hex = d.string(forKey: echoMoodHexKey),
              let label = d.string(forKey: echoMoodLabelKey) else { return nil }
        return (hex, label)
    }

    static func writeCachedEchoMood(hex: String, label: String) {
        let d = UserDefaults.standard
        d.set(hex,   forKey: echoMoodHexKey)
        d.set(label, forKey: echoMoodLabelKey)
    }

    /// Önbelleği boşaltır — bugüne ait hiç an kalmadığında.
    ///
    /// Karşılığı yoktu: yalnız *yazan* bir önbellek, kullanıcı günün tek
    /// anını sildiğinde eski mood'u tutmaya devam ediyordu.
    static func clearCachedEchoMood() {
        let d = UserDefaults.standard
        d.removeObject(forKey: echoMoodHexKey)
        d.removeObject(forKey: echoMoodLabelKey)
    }

    /// B1 — Tek kaynak: StreakEngine.milestones ile hizalı.
    private static let streakMilestones: Set<Int> = Set(StreakEngine.milestones)

    /// Primary (last) entry for today — used by existing views
    var todayEntry: DailyEntry? { todayEntries.last }

    var todayState: TodayState {
        todayEntries.isEmpty ? .empty : .completed
    }

    /// Whether the user can add a new entry right now (only if no entry today)
    var canAddNewEntry: Bool { todayEntries.isEmpty }

    /// Number of entries today
    var todayEntryCount: Int { todayEntries.count }

    init(context: NSManagedObjectContext) {
        self.context = context
        // Read the cached mood synchronously — this is the ONLY thing that
        // must happen before first frame so the echo overlay can render.
        self.cachedEchoMood = Self.readCachedEchoMood()

        // Initial CoreData fetch deferred one runloop tick. The view renders
        // the echo overlay for that tick, then cross-fades to real state.
        // Follow-up refreshes (post-save) stay synchronous — we already own
        // the write timing there.
        //
        // Two-phase publish (fetch, then hydration flag one tick later) is
        // deliberate: the ritual `.onChange(of: vm.todayEntry)` needs a
        // render pass where `hasHydratedTodayEntry == false` so it can
        // ignore the initial nil → cached-entry transition. Collapsing both
        // writes into one tick would trigger SaveRitualMoment on cold launch.
        Task { @MainActor in
            self.loadTodayEntry()
            // Preserve the "one runloop tick later" guarantee that the
            // two-phase publish depends on, without mixing GCD and the
            // Swift concurrency domain. `Task.yield()` suspends and
            // resumes on the next MainActor turn.
            await Task.yield()
            self.hasHydratedTodayEntry = true
        }
        loadRecentArtists()
        loadLastYearEntry()
        loadLastWeekEntry()
        loadThisWeekEntries()
        loadTotalEntryCount()
        loadYesterdayMood()
        loadRecommendedSongs()

        remoteChangeSubscription = NotificationCenter.default
            .publisher(for: .momentsDidChangeRemotely)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                Task { @MainActor in self?.refreshAfterRemoteChange() }
            }
    }

    /// Başka bir cihazdan inen kayıttan sonra CoreData türevi state'i tazeler.
    ///
    /// `reloadAfterV3Save()` kullanılmıyor: o AppReviewManager'ı tetikliyor
    /// ve puan istemi kullanıcının *kendi* kaydına ait bir ödül — uzaktan
    /// inen bir satır onu hak etmiyor.
    ///
    /// `loadLastWeekEntry()` de bilerek dışarıda: `showLastWeekReflection`'ı
    /// kaldırıyor, yani arka planda inen sync kullanıcının ortasında bir
    /// yansıma kartı açardı. O açılış ritüeli, sync tepkisi değil.
    private func refreshAfterRemoteChange() {
        // CloudKit'e geri yazmadan tazele. `syncLocalEntryToCloudKitIfNeeded`
        // `entryIndex > 0` olan anlarda upsert guard'ını atlayıp koşulsuz
        // YENİ kayıt açıyor; indirmeye cevaben çağırmak her bildirimde bir
        // kopya üretir ve kopya kendi remote-change'ini doğurur.
        loadTodayEntry(syncingToCloudKit: false)
        loadThisWeekEntries()
        loadTotalEntryCount()
        loadYesterdayMood()
        loadLastYearEntry()
    }

    /// v3 kayıt sonrası ViewModel'in `todayEntries`/`thisWeekEntries`/streak
    /// state'ini yeniden yükler. Sonraki view render'ında Kaydedildi ekranı ve
    /// son 7 gün şeridi doğru veriyle boyanır.
    func reloadAfterV3Save() {
        loadTodayEntry()
        loadThisWeekEntries()
        loadTotalEntryCount()
        loadYesterdayMood()

        // Rozet ve App Store puan istemi.
        //
        // Bunlar silinen legacy `saveEntry`'nin içindeydi ve v3 çok-an yolu
        // onu yalnızca şarkı seçildiğinde çağırıyordu. Yani şarkısız kaydeden
        // kullanıcı — v3'ün varsayılan akışı — hiç rozet kazanmıyor, puan
        // istemi de hiç görmüyordu. Tek yazma yoluna inince buraya taşındı.
        AppReviewManager.shared.evaluateAfterSave(
            totalEntryCount: totalEntryCount,
            uniqueDayCount: uniqueEntryDayCount()
        )
    }

    // MARK: - Load today's entries from CoreData
    private func loadTodayEntry(syncingToCloudKit: Bool = true) {
        let today = Calendar.current.startOfDay(for: Date())
        let fetchRequest: NSFetchRequest<DailySong> = DailySong.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "date == %@", today as NSDate)
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: true)]

        do {
            let items = try context.fetch(fetchRequest)
            todayEntries = items.map { dailyEntryFrom($0) }

            // Sync the latest entry to CloudKit if needed
            if syncingToCloudKit, let lastItem = items.last {
                syncLocalEntryToCloudKitIfNeeded(item: lastItem)
            }
        } catch {
            ONELogger.debug("TodayViewModel: fetch error \(error)", category: .general)
        }
        refreshStreakDays()
    }

    /// Streak gün sayısını hesaplar, published property'leri günceller.
    private func refreshStreakDays() {
        let todayHasEntry = !todayEntries.isEmpty
        let current = computeCurrentStreak(includingToday: todayHasEntry)
        streakDays = current

        // Empati kartı: dün entry vardı ama bugün yoksa kırılma tespiti.
        if !todayHasEntry {
            let cal = Calendar.current
            let yesterday = cal.startOfDay(for: cal.date(byAdding: .day, value: -1, to: Date()) ?? Date())
            let fetchReq: NSFetchRequest<DailySong> = DailySong.fetchRequest()
            fetchReq.predicate = NSPredicate(format: "date == %@", yesterday as NSDate)
            fetchReq.fetchLimit = 1
            let hasYesterday = ((try? context.fetch(fetchReq))?.count ?? 0) > 0

            if hasYesterday {
                // Dün giriş yapılmış → streak henüz kırılmamış (bugün yapılırsa devam eder)
                // Bu durumda yesterdayStreak'i dünün hesabıyla bul
                let filledDates = fetchFilledDates()
                let yesterdayStreak = StreakEngine.compute(
                    filledDates: filledDates,
                    today: yesterday,
                    includeToday: true
                ).count
                if yesterdayStreak >= 7 {
                    let key = "lastBrokenStreakDays"
                    UserDefaults.standard.set(yesterdayStreak, forKey: key)
                    lastBrokenStreakDays = yesterdayStreak
                }
            } else {
                // Dün de boş — daha önce kaydedilmiş kırılma değerini oku
                let key = "lastBrokenStreakDays"
                lastBrokenStreakDays = UserDefaults.standard.integer(forKey: key)
            }
        } else {
            // Bugün entry var — kırılma yok, sıfırla
            UserDefaults.standard.removeObject(forKey: "lastBrokenStreakDays")
            lastBrokenStreakDays = 0
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

    // MARK: - Load recommended songs (MusicKit charts, daily cached)

    private static let recSongsCacheKey     = "recommendedSongsCache_v2"
    private static let recSongsCacheDateKey = "recommendedSongsCacheDate_v2"
    @Published var isLoadingRecommendations = false

    func loadRecommendedSongs() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        // Return today's cached picks if they exist.
        if let cachedDate = UserDefaults.standard.object(forKey: Self.recSongsCacheDateKey) as? Date,
           calendar.isDate(cachedDate, inSameDayAs: today),
           let data = UserDefaults.standard.data(forKey: Self.recSongsCacheKey),
           let cached = try? JSONDecoder().decode([SongResult].self, from: data),
           !cached.isEmpty {
            recommendedSongs = cached
            return
        }

        // Stale cache — clear immediately so UI shows loading state.
        recommendedSongs = []
        isLoadingRecommendations = true

        // Already-logged song keys — exclude from recommendations.
        // Yalnız iki metin kolonu okunuyor; tabloyu NSManagedObject olarak
        // materialize etmeye gerek yok (bkz. `fetchFilledDates`).
        let allReq = NSFetchRequest<NSDictionary>(entityName: "DailySong")
        allReq.resultType = .dictionaryResultType
        allReq.propertiesToFetch = ["songName", "artistName"]
        allReq.returnsDistinctResults = true
        let loggedKeys = Set(((try? context.fetch(allReq)) ?? []).compactMap { row -> String? in
            guard let t = row["songName"] as? String, let a = row["artistName"] as? String else { return nil }
            return "\(t)|\(a)"
        })

        // Daily seed: same day → same 16 songs; next day → different 16.
        let dayOfYear = calendar.ordinality(of: .day, in: .year, for: Date()) ?? 1
        let year      = calendar.component(.year, from: Date())
        let dailySeed = UInt64(year) &* 366 &+ UInt64(dayOfYear)

        Task {
            defer { isLoadingRecommendations = false }
            guard MusicAuthorization.currentStatus == .authorized else { return }
            do {
                var chartRequest = MusicCatalogChartsRequest(genre: nil, types: [MusicKit.Song.self])
                chartRequest.limit = 40
                let response = try await chartRequest.response()
                let chartItems = response.songCharts.first?.items.map { $0 } ?? []

                // Shuffle with daily seed so each day presents a different 16-song window.
                let shuffled = chartItems.deterministicShuffled(seed: dailySeed)

                var songs: [SongResult] = []
                for s in shuffled {
                    let key = "\(s.title)|\(s.artistName)"
                    guard !loggedKeys.contains(key) else { continue }
                    songs.append(SongResult(
                        id: UUID(),
                        name: s.title,
                        artist: s.artistName,
                        genre: s.genreNames.first ?? "Müzik",
                        coverURL: s.artwork?.url(width: 200, height: 200),
                        spotifyURL: nil,
                        artworkURLString: s.artwork?.url(width: 600, height: 600)?.absoluteString,
                        previewURL: s.previewAssets?.first?.url
                    ))
                    if songs.count == 16 { break }
                }
                guard !songs.isEmpty else { return }
                recommendedSongs = songs
                if let data = try? JSONEncoder().encode(songs) {
                    UserDefaults.standard.set(data, forKey: Self.recSongsCacheKey)
                    UserDefaults.standard.set(today, forKey: Self.recSongsCacheDateKey)
                }
            } catch {
                ONELogger.error("Recommended songs fetch failed", error: error, category: .general)
            }
        }
    }

    /// Clears the daily cache and re-fetches. Kullanıcı "Yenile" butonuna basınca çağrılır.
    func refreshRecommendedSongs() {
        UserDefaults.standard.removeObject(forKey: Self.recSongsCacheKey)
        UserDefaults.standard.removeObject(forKey: Self.recSongsCacheDateKey)
        loadRecommendedSongs()
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
        AppAnalytics.shared.track(.songSearched(query: query, source: "apple"))

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
                    searchError = NSLocalizedString("search.appleMusicPermission", comment: "")
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
                        genre: s.genreNames.first ?? NSLocalizedString("genre.music", comment: ""),
                        coverURL: s.artwork?.url(width: 200, height: 200),
                        spotifyURL: nil,
                        artworkURLString: s.artwork?.url(width: 600, height: 600)?.absoluteString,
                        previewURL: s.previewAssets?.first?.url
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

    // MARK: - Pas günü (#10)
    func markTodayAsPassed() {
        PersistenceController.shared.savePassedDay(date: Date(), context: context)
        AppAnalytics.shared.track(.passButtonTapped)
        loadTodayEntry()
    }

    // MARK: - Attach photo / note after saving
    /// Kaydedilmiş bugünkü entry'ye sonradan fotoğraf ve/veya not ekler.
    ///
    /// `saveEntry` de bir upsert ama onu tekrar çağırmak `createdAt`'i sıfırlar ve
    /// analytics / rozet / streak / CloudKit / Live Activity yan etkilerini yeniden
    /// tetikler. Bu metod bilerek dar: sadece iki alanı yazar.
    /// `TodayCompletedView`'daki yıkıcı "Değiştir" (`clearToday`) ile karıştırılmamalı.
    func attachPhotoAndNote(photo: UIImage? = nil, note: String? = nil) {
        guard photo != nil || note != nil else { return }

        let today = Calendar.current.startOfDay(for: Date())
        let request: NSFetchRequest<DailySong> = DailySong.fetchRequest()
        request.predicate = NSPredicate(format: "date == %@", today as NSDate)
        request.fetchLimit = 1

        guard let item = (try? context.fetch(request))?.first else {
            ONELogger.error("attachPhotoAndNote: bugüne ait entry bulunamadı", category: .general)
            ErrorHandler.shared.handle(AppError.unknown(message: "Bugünkü kaydın bulunamadı."))
            return
        }

        if let photo {
            item.photoData = ONEPhotoEncoder.encode(photo)
        }
        if let note {
            let trimmed = note.trimmingCharacters(in: .whitespacesAndNewlines)
            item.dailyNote = trimmed.isEmpty ? nil : trimmed
        }

        do {
            try context.save()
            loadTodayEntry()
            // Not ve fotoğraf widget'ta görünüyor — türetilmiş yüzeyler
            // diskteki yeni duruma göre yeniden yazılmalı.
            MomentWriter.refreshTodaySurfaces(context: context)
        } catch {
            ONELogger.error("attachPhotoAndNote kaydedilemedi: \(error.localizedDescription)", category: .general)
            ErrorHandler.shared.handle(error, context: "attachPhotoAndNote")
        }
    }

    // MARK: - Clear today (tüm entry'leri sil)
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
            do {
                try context.save()
                // Bugün boşaldı — widget ve Echo önbelleği de boşalmalı.
                // Bu çağrı olmadan widget silinen mood'u gece yarısına kadar
                // göstermeye devam ediyordu.
                MomentWriter.refreshTodaySurfaces(context: context)
            } catch {
                ErrorHandler.shared.handle(error, context: "clearToday")
            }
        }
        todayEntries = []
        searchResults = []
        searchError = nil
        circleShareFailed = false
    }

    /// Clear a specific entry by ID (v3 çoklu an)
    func clearEntry(id: UUID) {
        let fetchRequest: NSFetchRequest<DailySong> = DailySong.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "id == %@", id as CVarArg)

        if let item = try? context.fetch(fetchRequest).first {
            context.delete(item)
            do {
                try context.save()
                // Günün son anı silindiyse widget temizlenir, değilse bir
                // önceki ana düşer. `refreshTodaySurfaces` diski okuduğu için
                // hangisi olduğunu burada bilmek gerekmiyor.
                MomentWriter.refreshTodaySurfaces(context: context)
            } catch {
                ErrorHandler.shared.handle(error, context: "clearEntry")
            }
        }
        loadTodayEntry()
    }

    // MARK: - Milestone & Memory

    func clearStreakMilestone() {
        streakMilestone = nil
    }

    // MARK: - A4 — First-entry Circle invite hook

    /// Onboarding kendi davet adımını gösterdiğinde bu anahtarı `saveEntry`'den
    /// ÖNCE yazıyor — yoksa `total == 1` koşulu sağlanıp davet sheet'i ana
    /// ekranda ikinci kez açılır. O yüzden `internal`.
    static let firstEntryInviteHookKey = "firstEntryInviteHookConsumed"

    /// İlk kayıt sonrası Çevre davet kancasını tetikler. Yalnızca toplam
    /// entry sayısı 1 ise VE daha önce gösterilmediyse açılır. Mevcut
    /// kullanıcılarda (zaten birden fazla entry'si olanlar) sessiz kalır.
    private func evaluateFirstEntryInviteHook() {
        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: Self.firstEntryInviteHookKey) else { return }

        let countRequest: NSFetchRequest<DailySong> = DailySong.fetchRequest()
        let total = (try? context.count(for: countRequest)) ?? 0
        guard total == 1 else {
            // Mevcut kullanıcı — sessiz tüket, bir daha kontrol etme.
            defaults.set(true, forKey: Self.firstEntryInviteHookKey)
            return
        }

        defaults.set(true, forKey: Self.firstEntryInviteHookKey)
        // Save ritual + milestone animasyonlarının bitmesini beklet.
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) { [weak self] in
            guard let self else { return }
            self.showFirstEntryInvite = true
            AppAnalytics.shared.track(.firstEntryInviteHookShown)
        }
    }

    func dismissFirstEntryInvite(action: String) {
        showFirstEntryInvite = false
        AppAnalytics.shared.track(.firstEntryInviteHookAction(action: action))
    }

    func loadLastYearEntry() {
        let calendar = Calendar.current
        guard let oneYearAgo = calendar.date(byAdding: .year, value: -1, to: Date()) else { return }
        let targetDate = calendar.startOfDay(for: oneYearAgo)

        let fetchRequest: NSFetchRequest<DailySong> = DailySong.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "date == %@", targetDate as NSDate)
        fetchRequest.fetchLimit = 1

        if let item = try? context.fetch(fetchRequest).first {
            lastYearEntry = dailyEntryFrom(item)
        }
    }

    /// C3 — "1 hafta önce bugün" entry'sini yükler (varsa).
    func loadLastWeekEntry() {
        let calendar = Calendar.current
        guard let oneWeekAgo = calendar.date(byAdding: .day, value: -7, to: Date()) else { return }
        let targetDate = calendar.startOfDay(for: oneWeekAgo)

        let fetchRequest: NSFetchRequest<DailySong> = DailySong.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "date == %@", targetDate as NSDate)
        fetchRequest.fetchLimit = 1

        if let item = try? context.fetch(fetchRequest).first {
            lastWeekEntry = dailyEntryFrom(item)
            if !hasShownLastWeekReflectionThisSession {
                showLastWeekReflection = true
                hasShownLastWeekReflectionThisSession = true
            }
        }
    }

    func dismissLastWeekReflection() {
        showLastWeekReflection = false
    }

    // MARK: - Streak Calculation
    /// Counts consecutive days ending at today, applying StreakEngine's
    /// soft-streak rules (1 freeze per 7-day window). Returns 1 on first save.
    /// Kayıt bulunan günlerin kümesi.
    ///
    /// Streak hesabı yalnızca **tarihlere** bakıyor, ama eskiden iki ayrı
    /// yerde predicate'siz `DailySong.fetchRequest()` ile tablonun tamamı
    /// `NSManagedObject` olarak materialize ediliyordu. `loadTodayEntry()`
    /// on ayrı yerden çağrılıyor (açılış, kayıt, silme, güncelleme…) ve her
    /// çağrıda bu tarama koşuyordu — bir yıllık kullanımda yüzlerce satır.
    ///
    /// Dictionary fetch yalnız `date` kolonunu okuyor: nesne kurulumu yok.
    /// `returnsDistinctResults` da v3'ün gün içi çoklu girişlerini tek
    /// satıra indiriyor, çünkü küme zaten gün bazlı.
    private func fetchFilledDates() -> Set<Date> {
        let request = NSFetchRequest<NSDictionary>(entityName: "DailySong")
        request.resultType = .dictionaryResultType
        request.propertiesToFetch = ["date"]
        request.returnsDistinctResults = true

        let calendar = Calendar.current
        let rows = (try? context.fetch(request)) ?? []
        return Set(rows.compactMap { row -> Date? in
            guard let d = row["date"] as? Date else { return nil }
            return calendar.startOfDay(for: d)
        })
    }

    private func computeCurrentStreak(includingToday: Bool = true) -> Int {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        let filledDates = fetchFilledDates()
        guard !filledDates.isEmpty else { return 1 }

        // Önceki gün entry yoksa freeze köprüsüne gerek yok — sadece 1.
        let hasPriorEntry = filledDates.contains { $0 < today }
        guard hasPriorEntry else {
            streakFreezeUsedRecently = false
            streakFreezeAvailable = StreakEngine.isFreezeAvailable(today: today)
            return 1
        }

        let result = StreakEngine.compute(
            filledDates: filledDates,
            today: today,
            includeToday: includingToday
        )
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today) ?? today
        streakFreezeUsedRecently = result.frozenDates.contains(yesterday)
        streakFreezeAvailable = result.freezeAvailable
        if !result.newlyConsumedFreezes.isEmpty {
            // Bir tick ertele. Bu fonksiyon `init` → `loadTodayEntry` →
            // `refreshStreakDays` zinciriyle view güncellemesinin İÇİNDE
            // çalışıyor; toast'ı oradan yayınlamak
            // "Publishing changes from within view updates" uyarısını
            // veriyordu — SwiftUI'da tanımsız davranış.
            DispatchQueue.main.async {
                ErrorHandler.shared.showInfo(
                    NSLocalizedString("streak.freezeUsed.toast", comment: "")
                )
                AppAnalytics.shared.track(.streakFreezeConsumed)
            }
        }
        return result.count
    }

    private func loadThisWeekEntries() {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        guard let weekStart = cal.date(from: cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: today)) else { return }
        let weekEnd = cal.date(byAdding: .day, value: 7, to: weekStart) ?? today

        let req: NSFetchRequest<DailySong> = DailySong.fetchRequest()
        req.predicate = NSPredicate(format: "date >= %@ AND date < %@", weekStart as NSDate, weekEnd as NSDate)
        req.sortDescriptors = [NSSortDescriptor(key: "date", ascending: true)]

        let songs = (try? context.fetch(req)) ?? []
        thisWeekEntries = songs.compactMap { s in
            guard let d = s.date, let hex = s.moodColorHex else { return nil }
            return (date: cal.startOfDay(for: d), moodColorHex: hex)
        }
    }

    private func loadTotalEntryCount() {
        let req: NSFetchRequest<DailySong> = DailySong.fetchRequest()
        totalEntryCount = (try? context.count(for: req)) ?? 0
    }

    /// Kaç farklı takvim gününde giriş yapıldığını döndürür.
    /// `fetchFilledDates()` ile aynı işi yapıyordu — tek kaynağa bağlandı.
    private func uniqueEntryDayCount() -> Int {
        fetchFilledDates().count
    }

    private func loadYesterdayMood() {
        let cal = Calendar.current
        guard let yesterday = cal.date(byAdding: .day, value: -1, to: cal.startOfDay(for: Date())) else { return }
        let req: NSFetchRequest<DailySong> = DailySong.fetchRequest()
        req.predicate = NSPredicate(format: "date == %@", yesterday as NSDate)
        req.fetchLimit = 1
        if let song = try? context.fetch(req).first, let hex = song.moodColorHex, let label = song.moodLabel ?? song.moodWord {
            yesterdayMood = (label: label, color: Color(hex: hex))
        } else {
            yesterdayMood = nil
        }

        // Compute days since last entry (before today)
        let allReq: NSFetchRequest<DailySong> = DailySong.fetchRequest()
        allReq.predicate = NSPredicate(format: "date < %@", cal.startOfDay(for: Date()) as NSDate)
        allReq.sortDescriptors = [NSSortDescriptor(key: "date", ascending: false)]
        allReq.fetchLimit = 1
        if let last = try? context.fetch(allReq).first, let lastDate = last.date {
            let diff = cal.dateComponents([.day], from: cal.startOfDay(for: lastDate), to: cal.startOfDay(for: Date())).day
            daysSinceLastEntry = diff
        } else {
            daysSinceLastEntry = nil
        }
    }

    // MARK: - Helpers

    // Photo URL cache — avoids writing a new temp file on every loadTodayEntry() call.
    private var photoURLCache: [NSManagedObjectID: URL] = [:]

    private func dailyEntryFrom(_ item: DailySong) -> DailyEntry {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        let timeStr = item.createdAt.map { formatter.string(from: $0) } ?? "--:--"

        var photoURL: URL? = nil
        if item.photoData != nil {
            if let cached = photoURLCache[item.objectID], FileManager.default.fileExists(atPath: cached.path) {
                photoURL = cached
            } else if let data = item.photoData {
                let url = FileManager.default.temporaryDirectory
                    .appendingPathComponent("\(item.id?.uuidString ?? UUID().uuidString).jpg")
                try? data.write(to: url)
                photoURL = url
                photoURLCache[item.objectID] = url
            }
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
            note: item.dailyNote,
            passed: item.passed
        )
    }

    // MARK: - Auto-Sync
    private func syncLocalEntryToCloudKitIfNeeded(item: DailySong) {
        let today = Calendar.current.startOfDay(for: Date())

        // Sadece bugünün kaydıysa ve daha önceden eklendiyse senkronize etmeyi deneriz.
        guard let itemDate = item.date, Calendar.current.isDate(itemDate, inSameDayAs: today) else { return }

        // Çevreyle paylaşılmamışsa CloudKit'e senkronize etme
        guard item.shareWithCircle else { return }

        // CloudKit throttled veya kullanıcı yüklenemedi — sync'i atla
        guard !CloudKitManager.shared.isThrottled, !CloudKitManager.shared.userLoadFailed else {
            ONELogger.warning("Senkronizasyon atlandı — CloudKit throttled veya kullanıcı yüklenmedi", category: .general)
            return
        }

        // v3: entryIndex > 0 ise (aynı güne ikinci+ an) her seferinde
        // YENİ CloudKit kaydı ekle — upsert guard'ını atla. entryIndex == 0
        // olan ilk an için upsert (idempotent tekrar yükleme).
        let itemEntryIndex = Int(item.entryIndex)
        let doSync: () -> Void = { [weak self] in
            guard let self else { return }
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
                currentStreak: syncStreak,
                entryIndex: itemEntryIndex
            ) { res in
                switch res {
                case .success(let record):
                    ONELogger.success("CloudKit sync ok (entryIndex=\(itemEntryIndex)): \(record.recordID)", category: .general)
                case .failure(let error):
                    ONELogger.error("CloudKit sync hata: \(error.localizedDescription)", category: .general)
                }
            }
        }

        if itemEntryIndex > 0 {
            doSync()
            return
        }

        CloudKitManager.shared.fetchUserDailyShare(for: today) { [weak self] result in
            self?.syncTask?.cancel()
            self?.syncTask = Task { @MainActor in
                switch result {
                case .success:
                    // Zaten CloudKit'te var — entryIndex==0 için upsert; sync gerekmez.
                    break
                case .failure:
                    ONELogger.debug("Senkronizasyon: Lokal an bulundu ama CloudKit'te yok. Yükleniyor...", category: .general)
                    doSync()
                }
            }
        }
    }
}
