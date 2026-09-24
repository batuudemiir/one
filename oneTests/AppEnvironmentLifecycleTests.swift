//
//  AppEnvironmentLifecycleTests.swift
//  oneTests
//
//  AppEnvironment yaşam döngüsü ve kayıt kancaları: açılış, ön/arka plan,
//  gün değişimi; check-in, ritüel ve girdi sonrası analitik + yüzeyler.
//

import Testing
import Foundation
import CoreData
@testable import OneDailyBatuhan

@MainActor
struct AppEnvironmentLifecycleTests {

    struct Rig {
        let env: AppEnvironment
        let tracker: RecordingTracker
        let scheduling: FakeScheduling
        let local: MemoryKeyValueStore
        let clock: TestClock
        let container: NSPersistentContainer
    }

    static func rig(_ iso: String = "2026-09-23T06:00:00Z", storeBackend: StoreBackend = FakeStoreBackend()) -> Rig {
        let clock = TestClock(iso)
        let container = ONE2TestStack.makeContainer()
        let content = ContentRepository(bundle: BundleContentSource(bundle: Bundle(for: PersistenceController.self)),
                                        cacheDirectory: FileManager.default.temporaryDirectory.appendingPathComponent("l-\(UUID())"),
                                        fetcher: FakeContentFetcher(files: nil), clock: clock,
                                        defaults: UserDefaults(suiteName: "l-\(UUID())")!)
        let tracker = RecordingTracker(), scheduling = FakeScheduling(pending: []), local = MemoryKeyValueStore()
        let env = AppEnvironment(context: container.viewContext, clock: clock, guardLegacyWrites: false,
                                 content: content, analytics: tracker, cloud: MemoryKeyValueStore(), local: local,
                                 notificationScheduling: scheduling,
                                 widget: WidgetBridge(backing: local, reload: {}), storeBackend: storeBackend)
        return Rig(env: env, tracker: tracker, scheduling: scheduling, local: local, clock: clock, container: container)
    }

    /// Kancaların başlattığı `Task`'lerin bitmesini bekler.
    private func settle() async {
        for _ in 0..<20 { await Task.yield() }
    }

    @Test("Açılış: widget anahtarları ve bildirim penceresi kurulur, gün kaydedilir, içerik kontrol edilir")
    func launch() async {
        let r = Self.rig()
        await r.env.onLaunch()
        #expect(r.local.object(forKey: WidgetSnapshotV2.Key.dailyQuote) != nil)
        #expect(r.local.object(forKey: WidgetSnapshotV2.Key.week) != nil)
        #expect(!r.scheduling.added.isEmpty)
        #expect(r.local.object(forKey: "one2.lastActiveDay") as? String == "2026-09-23")
        // Çevrimdışı sahte istemci: günlük kontrol başarısız → sağlık olayı.
        #expect(r.tracker.events.contains(.contentUpdateFailed(reason: "network")))
    }

    @Test("Check-in: analitik olayı ve widget'taki bugünkü check-in")
    func checkInHook() async throws {
        let r = Self.rig()
        try r.env.mood.log(score: 4, emotionIDs: ["huzur.sakin", "nese.umutlu"], causeIDs: ["c_uyku"], source: .checkIn)
        #expect(r.tracker.events.contains(.checkInDone(score: 4, emotionCount: 2, causeCount: 1)))
        await settle()
        let checkIn = r.env.widget.read(WidgetSnapshotV2.Key.todayCheckIn, as: WidgetCheckIn.self)
        #expect(checkIn?.score == 4 && checkIn?.label == "Sakin")
    }

    @Test("Ritüel: ritual_done, günün ilk tamamlanması day_completed, geriye dönükte backfill_used, rozet")
    func ritualHook() async throws {
        let r = Self.rig()
        try r.env.day.markCompleted(.daily)
        try r.env.day.markCompleted(.daily) // ikinci kez: gün zaten tamam
        try r.env.day.markCompleted(.daily, on: r.clock.today.adding(days: -2))
        let events = r.tracker.events
        #expect(events.filter { $0 == .ritualDone(kind: .daily) }.count == 3)
        #expect(events.filter { $0 == .dayCompleted(by: .ritual, backfilled: false) }.count == 1)
        #expect(events.contains(.dayCompleted(by: .ritual, backfilled: true)))
        #expect(events.contains(.backfillUsed(daysBack: 2)))
    }

    @Test("Girdi: entry_saved aralıkla, ≥20 kelime günü yazıyla tamamlar, ilk girdi rozeti")
    func entryHook() throws {
        let r = Self.rig()
        _ = try r.env.badges.evaluateOnLaunch()
        _ = try r.env.journal.create(EntryDraft(kind: .freeform, body: String(repeating: "kelime ", count: 25), sourceContext: .free))
        let events = r.tracker.events
        #expect(events.contains(.entrySaved(kind: .freeform, words: 25, source: .free)))
        #expect(events.contains(.dayCompleted(by: .writing, backfilled: false)))
        #expect(events.contains(.badgeAwarded(badgeID: "b_first_entry", announced: true)))
    }

    @Test("Arka plan birikmiş görülmeleri yazar; ön plana dönüşte gün değiştiyse yüzeyler tazelenir")
    func backgroundAndDayChange() async throws {
        let r = Self.rig()
        await r.env.onLaunch()
        r.env.exposure.recordSeen("q_000001", kind: .quote)
        // Açılışta seçilen günün sözü de görüldü olarak bekliyor (E2.4).
        #expect(r.env.exposure.pendingCount >= 1)
        r.env.onBackground()
        #expect(r.env.exposure.pendingCount == 0)

        let before = r.scheduling.added.count
        await r.env.onForeground() // aynı gün: yalnız pencere "bugün açıldı" ile yeniden kurulur
        #expect(r.scheduling.added.count > before)
        #expect(r.local.object(forKey: "one2.lastActiveDay") as? String == "2026-09-23")

        r.clock.advance(hours: 24)
        await r.env.onForeground()
        #expect(r.local.object(forKey: "one2.lastActiveDay") as? String == "2026-09-24")
        let quote = r.env.widget.read(WidgetSnapshotV2.Key.dailyQuote, as: WidgetQuote.self)
        #expect(quote?.day == "2026-09-24")
    }

    @Test("Seri kırılınca bir kez one2_streak_broken")
    func streakBroken() async throws {
        let r = Self.rig()
        try r.env.day.markCompleted(.daily, on: r.clock.today.adding(days: -1))
        try r.env.day.markCompleted(.daily)
        await r.env.onLaunch() // seri 2 kaydedilir
        r.clock.advance(hours: 48) // dün boş kaldı
        await r.env.onDayChange()
        #expect(r.tracker.events.filter { $0 == .streakBroken(length: 2) }.count == 1)
        await r.env.onDayChange()
        #expect(r.tracker.events.filter { $0 == .streakBroken(length: 2) }.count == 1)
    }
}
