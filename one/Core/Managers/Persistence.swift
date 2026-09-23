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
            container.loadPersistentStores { [weak self] storeDescription, error in
                if let error = error as NSError? {
                    // Açılamayan store'da sessizce devam etmek her yazımda veri
                    // kaybı demek — ama doğrudan `fatalError` de yanlış: bozuk
                    // store ya da yarım kalmış migration kullanıcıyı *her
                    // açılışta çöken* bir uygulamayla baş başa bırakıyor ve tek
                    // çıkışı silip yeniden kurmak oluyor.
                    //
                    // Anlar CloudKit'te duruyor. Yerel store'u atıp yeniden
                    // kurmak veriyi kaybettirmiyor, yalnızca yeniden indirtiyor.
                    ONELogger.error("CoreData store failed to load: \(error.code) — \(error.localizedDescription)", category: .persistence)
                    ErrorHandler.shared.handle(error, context: "CoreDataStoreLoad")
                    self?.recoverFromUnopenableStore(storeDescription, originalError: error)
                    return
                }
                DispatchQueue.main.async {
                    ONELaunchSignpost.end("coredata.load")
                    self?.isReady = true
                    // Register the remote-change observer only after the
                    // store is loaded — before this point the coordinator
                    // has no store attached, so the observer would either
                    // miss events or fire against an unready stack.
                    //
                    // Tüketicilerin abone olmasından önce gelen bildirimler
                    // sorun değil: uzlaştırma store üzerinde çalışıyor, yayın
                    // ise yalnızca tazeleme tetikleyicisi. Geç abone olan
                    // tüketici zaten uzlaşmış veriyi okuyor.
                    self?.setupRemoteChangeNotifications()
                    self?.schedulePersistentHistoryPurge()
                    #if DEBUG
                    self?.initializeCloudKitSchemaIfRequested()
                    #endif
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
    
    #if DEBUG
    /// `one 3` record type'larını CloudKit **development** ortamında üretir
    /// (MIGRATION.md §5, ADR-001 Faz 1 madde 10). Yalnız Xcode'dan, launch
    /// argument ile: `-ONE2InitializeCloudKitSchema YES`. Development'a örnek
    /// kayıtlar yazar; Dashboard'dan silinip Production'a deploy edilmeli.
    /// Model her değiştiğinde yeniden çalıştırılır.
    private func initializeCloudKitSchemaIfRequested() {
        guard UserDefaults.standard.bool(forKey: "ONE2InitializeCloudKitSchema") else { return }
        let container = self.container
        DispatchQueue.global(qos: .utility).async {
            let failure: Error?
            do {
                try container.initializeCloudKitSchema(options: [])
                failure = nil
            } catch {
                failure = error
            }
            DispatchQueue.main.async {
                if let failure {
                    ONELogger.error("CloudKit şeması üretilemedi", error: failure, category: .persistence)
                } else {
                    ONELogger.success("CloudKit şeması (development) üretildi", category: .persistence)
                }
            }
        }
    }
    #endif

    /// Store kurtarma yalnızca bir kez denenir — ikinci kez başarısız olması
    /// diskin kendisinde bir sorun olduğunu gösterir ve döngüye girmenin
    /// kullanıcıya faydası yok.
    private var didAttemptStoreRecovery = false

    /// Açılamayan store'u kenara taşıyıp sıfırdan kurar. Veri CloudKit'ten
    /// geri iner; iCloud'u kapalı kullanıcı için eski dosyalar
    /// `StoreBackups/` altında kalır (bkz. `StoreBackup`).
    private func recoverFromUnopenableStore(
        _ description: NSPersistentStoreDescription,
        originalError: NSError
    ) {
        guard !didAttemptStoreRecovery, let url = description.url else {
            ONELogger.error("CoreData kurtarma mümkün değil — store açılamıyor", category: .persistence)
            fatalError("CoreData store failed to load and could not be recovered: \(originalError)")
        }
        didAttemptStoreRecovery = true

        ONELogger.warning("CoreData store açılamadı, yerel kopya kenara alınıp yeniden kuruluyor", category: .persistence)

        if let root = StoreBackup.defaultRoot(),
           let folder = try? StoreBackup.moveAside(storeURL: url, root: root) {
            ONELogger.warning("Açılamayan store yedeklendi: \(folder.lastPathComponent)", category: .persistence)
        } else {
            do {
                try container.persistentStoreCoordinator.destroyPersistentStore(
                    at: url, ofType: NSSQLiteStoreType, options: description.options
                )
            } catch {
                // `destroy` başarısızsa dosyaları elle temizlemeyi dene — sqlite
                // yan dosyaları (-wal, -shm) geride kalırsa yeni store da açılmaz.
                let fm = FileManager.default
                for suffix in ["", "-wal", "-shm"] {
                    let sidecar = URL(fileURLWithPath: url.path + suffix)
                    try? fm.removeItem(at: sidecar)
                }
                ONELogger.error("destroyPersistentStore başarısız, dosyalar elle silindi: \(error.localizedDescription)", category: .persistence)
            }
        }

        container.loadPersistentStores { [weak self] _, retryError in
            if let retryError = retryError as NSError? {
                ONELogger.error("CoreData kurtarma da başarısız: \(retryError.localizedDescription)", category: .persistence)
                ErrorHandler.shared.handle(retryError, context: "CoreDataStoreRecovery")
                fatalError("CoreData store could not be recovered: \(retryError)")
            }
            DispatchQueue.main.async {
                ONELaunchSignpost.end("coredata.load")
                self?.isReady = true
                self?.setupRemoteChangeNotifications()
                ONELogger.warning("CoreData store yeniden kuruldu — veri CloudKit'ten inecek", category: .persistence)
            }
        }
    }

    // MARK: - Persistent history budama

    /// `NSPersistentHistoryTrackingKey` açık ve geçmiş hiç budanmıyordu.
    ///
    /// Transaction tablosu her yazımda büyüyor, WAL onunla birlikte şişiyor
    /// (açılışta 1000+ frame'lik checkpoint) ve `loadPersistentStores` her
    /// açılışta biraz daha uzuyor. Ölçülen 5079ms'lik store açılışının
    /// büyüyen kısmı bu.
    ///
    /// 7 gün, CloudKit mirroring için güvenli pencere: importer işlenmemiş
    /// transaction'ları bu süreden çok daha hızlı tüketiyor. Daha agresif bir
    /// eşik henüz export edilmemiş değişiklikleri silme riski taşır.
    private func schedulePersistentHistoryPurge() {
        let cutoff = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date().addingTimeInterval(-7 * 86_400)
        let context = container.newBackgroundContext()
        context.perform {
            let request = NSPersistentHistoryChangeRequest.deleteHistory(before: cutoff)
            do {
                try context.execute(request)
                ONELogger.debug("Persistent history budandı (<\(cutoff))", category: .persistence)
            } catch {
                // Budama başarısızlığı veri kaybı değil, yalnız açılış biraz
                // daha yavaş kalır — sessizce geç.
                ONELogger.warning("Persistent history budanamadı: \(error.localizedDescription)", category: .persistence)
            }
        }
    }

    /// Uzak değişiklik uzlaştırması için debounce penceresi.
    ///
    /// CloudKit ilk sync'te tek tek değil, salvo hâlinde bildirim yolluyor.
    /// Her biri için dedupe koşturmak hem boşuna iş hem de yarı-uzlaşmış
    /// durumlar üretiyor; salvonun dinmesini bekliyoruz.
    private var remoteChangeDebounce: DispatchWorkItem?
    private var remoteChangeObserver: NSObjectProtocol?

    private func setupRemoteChangeNotifications() {
        remoteChangeObserver = NotificationCenter.default.addObserver(
            forName: .NSPersistentStoreRemoteChange,
            object: container.persistentStoreCoordinator,
            queue: .main
        ) { [weak self] _ in
            self?.scheduleRemoteChangeReconcile()
        }
    }

    private func scheduleRemoteChangeReconcile() {
        remoteChangeDebounce?.cancel()
        let work = DispatchWorkItem { [weak self] in
            self?.reconcileAfterRemoteChange()
        }
        remoteChangeDebounce = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5, execute: work)
    }

    /// Uzak değişiklik indikten sonra: çakışmaları uzlaştır, sonra ekranlara
    /// haber ver.
    ///
    /// Sıra önemli — `ArchiveStore` gibi tüketiciler tazelendiğinde veri zaten
    /// uzlaşmış olmalı, yoksa kullanıcı bir an için çift satır görür.
    private func reconcileAfterRemoteChange() {
        // ONE 2.0: `DailySong` salt okunur (B'). v3 uzlaştırması ona yazdığı,
        // `refreshTodaySurfaces` de widget'a v3 verisi yazdığı için ikisi de
        // atlanır; yerine ONE 2.0'ın "gün başına bir" kayıtları birleştirilir
        // (ADR-001 §1, MIGRATION.md §1.3–1.4).
        if ONE2Flag.isEnabled {
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                let context = self.container.viewContext
                do {
                    let merged = try DayStore(context: context).reconcileDuplicates()
                        + LibraryStore(context: context).reconcileDuplicateBadges()
                    if merged > 0 { context.refreshAllObjects() }
                } catch {
                    ONELogger.warning("ONE2 uzlaştırma başarısız: \(error.localizedDescription)", category: .persistence)
                }
                NotificationCenter.default.post(name: .momentsDidChangeRemotely, object: nil)
            }
            return
        }

        let bg = container.newBackgroundContext()
        // Uzak değişiklik zaten kazanmış durumda; uzlaştırma yalnızca fazlalığı
        // temizliyor, bu yüzden çakışmada store'daki hâli tercih ediyoruz.
        bg.mergePolicy = NSMergeByPropertyStoreTrumpMergePolicy
        bg.perform { [weak self] in
            let result = MomentDeduplicator.reconcile(in: bg)
            DispatchQueue.main.async {
                guard let self else { return }
                if result.didChange {
                    // Uzlaştırma viewContext'in elindeki nesneleri bayatlattı.
                    self.container.viewContext.refreshAllObjects()
                }
                NotificationCenter.default.post(name: .momentsDidChangeRemotely, object: nil)
                // Ekranlar `.momentsDidChangeRemotely` ile kendi bellek içi
                // state'ini tazeliyor, ama uygulamanın **dışındaki** türetilmiş
                // yüzeyler (widget, cached echo mood) o bildirimi görmüyor.
                // Bu çağrı olmadan başka cihazdan gelen bir an widget'a hiç
                // düşmüyordu — yerel yazma/silme yollarındaki aynı boşluğun
                // uzak taraftaki eşi.
                // `notify: false` — bu yol zaten `.momentsDidChangeRemotely`
                // attı. `todaySongSaved`'i de atmak `ArchiveView`'ı
                // `loadDataAsync()`'e sokuyor ve geçmiş ayı gezen kullanıcıyı
                // bu aya fırlatıyordu. Burada gereken tek şey uygulamanın
                // **dışındaki** yüzeyleri (widget, cached echo) tazelemek.
                MomentWriter.refreshTodaySurfaces(
                    context: self.container.viewContext,
                    notify: false
                )
                ONELogger.debug("CloudKit: uzak değişiklik uzlaştırıldı", category: .persistence)
            }
        }
    }
    
    // #10 — Pas günü: renk/şarkı yok
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
        // Sinirsiz tarama: kayit sayisi buyudukce bellek dogrusal artiyordu.
        // Batch faulting ile tepe bellek sabit kaliyor.
        fetchRequest.fetchBatchSize = 100
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

    // MARK: - Şarkı tekrarı analizi — KALDIRILDI
    //
    // `SongPattern` + `analyzeSongPatterns` + `getMostFrequentSong` +
    // `analyzeSongPatternsAsync` (~164 satır) buradaydı.
    //
    // Üretimde tek bir çağıranı yoktu. Zincir kendi içinde dönüyordu
    // (`getMostFrequentSong` → `analyzeSongPatterns`) ve dışarıdan yalnız
    // testler tutuyordu — yani ölü kod, test kapsamı sayesinde kullanılıyor
    // gibi görünüyordu.
    //
    // İşlevi de yinelenmişti: "en sık çalınan şarkılar" hesabını
    // `MonthlySummaryViewModel` kendi içinde yapıyor (`songCount` →
    // `topTracks`) ve gerçekten ekrana çıkan o. Buradaki sürüm v2'nin
    // günde-tek-şarkı modelinden kalmaydı.
    //
    // İronik not: üçünden `analyzeSongPatternsAsync` işi doğru yapan
    // (arka plan context'i kullanan) sürümdü ve hiç çağrılmamıştı.

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

// MARK: - Bildirimler

extension Notification.Name {
    /// CloudKit'ten gelen değişiklik indi ve uzlaştırıldı.
    ///
    /// Bu bildirim, fetch sonucunu `@Published` / `@State` dizilere kopyalayan
    /// tüketiciler için: merge context'e işlense de kopya bayat kalıyor.
    /// Projede `@FetchRequest` kullanan ekran yok, yani
    /// `automaticallyMergesChangesFromParent` tek başına hiçbir ekranı
    /// tazelemiyor.
    ///
    /// Aboneler:
    /// - `ArchiveStore.reloadAfterRemoteChange()` — takvimin kendisi,
    ///   görüntülenen ayı **koruyarak** (`loadDataAsync()` değil; o her zaman
    ///   bu aya döner ve `V3ArchiveView` kendi `@State year`'ını tuttuğu için
    ///   takvim sessizce boşalır)
    /// - `TodayViewModel.refreshAfterRemoteChange()`
    /// - `V3ProfileView` — `.onReceive` -> `loadMoments()`
    /// - `EchoViewModel.refreshAfterRemoteChange()`
    /// - `ArchiveContainerView` — yalnız AÇIK gün detayının `selectedMoments`
    ///   dilimi
    /// - `V3CircleView` — `loadMyMoments()`. Uzun süre **abone değildi**:
    ///   yalnız `todaySongSaved` dinliyordu, yani başka cihazdan gelen an
    ///   Çevre'ye hiç düşmüyordu. `loadFriends(force:)` bilerek çağrılmıyor —
    ///   uzak bir *an* değişikliği arkadaş listesini zorla tazelemeyi
    ///   gerektirmiyor.
    ///
    /// `ProfileViewModel` abone değil ve olmamalı: moment okumuyor, yalnızca
    /// `deleteAccount()` içinde toplu siliyor.
    static let momentsDidChangeRemotely = Notification.Name("momentsDidChangeRemotely")
}
