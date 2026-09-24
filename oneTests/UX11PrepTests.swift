//
//  UX11PrepTests.swift
//  oneTests
//
//  UX-11 öncesi motor tarafı: ekranların view data'sının istediği ama
//  motorda eksik olan okuma yüzeyleri (05 › UX-11, UX_istekleri.md).
//

import Testing
import Foundation
import CoreData
@testable import OneDailyBatuhan

@MainActor
struct UX11PrepTests {

    struct Rig {
        let clock: TestClock
        let container: NSPersistentContainer
        let content: ContentRepository
        let journal: JournalStore
        let mood: MoodStore
        let day: DayStore
        let exposure: ExposureStore
        let profile: ProfileStore
    }

    static func rig(_ iso: String = "2026-09-23T06:00:00Z") -> Rig {
        let clock = TestClock(iso)
        let container = ONE2TestStack.makeContainer()
        let ctx = container.viewContext
        let content = ContentRepository(bundle: BundleContentSource(bundle: Bundle(for: PersistenceController.self)),
                                        cacheDirectory: FileManager.default.temporaryDirectory.appendingPathComponent("u-\(UUID())"),
                                        fetcher: FakeContentFetcher(files: nil), clock: clock,
                                        defaults: UserDefaults(suiteName: "u-\(UUID())")!)
        return Rig(clock: clock, container: container, content: content,
                   journal: JournalStore(context: ctx, clock: clock), mood: MoodStore(context: ctx, clock: clock),
                   day: DayStore(context: ctx, clock: clock), exposure: ExposureStore(context: ctx, clock: clock),
                   profile: ProfileStore(cloud: MemoryKeyValueStore(), local: MemoryKeyValueStore()))
    }

    // MARK: - Check-in dilimi ve kalıcı yankı

    @Test("Check-in dilimi bağlı girdinin türünden: sabah, akşam, günlük")
    func checkInSlot() throws {
        let r = Self.rig()
        let morning = try r.journal.create(EntryDraft(kind: .morning))
        let evening = try r.journal.create(EntryDraft(kind: .evening))
        #expect(try r.mood.log(score: 3, source: .checkIn, linkedTo: morning.id).slot == .morning)
        #expect(try r.mood.log(score: 3, source: .checkIn, linkedTo: evening.id).slot == .evening)
        #expect(try r.mood.log(score: 3, source: .checkIn).slot == .daily)
        #expect(try r.mood.logs(on: r.clock.today).map(\.slot) == [.morning, .evening, .daily])
    }

    @Test("Yankı check-in'e saklanır: yeniden açılışta ve 14 gün kuralı işledikten sonra da aynı cümle")
    func echoPersisted() throws {
        let r = Self.rig()
        let echoes = EchoEngine(content: r.content, exposure: r.exposure, profile: r.profile, clock: r.clock, mood: r.mood)
        let checkIn = try r.mood.log(score: 2, emotionIDs: ["kaygi.gergin"], source: .checkIn)
        let first = try #require(echoes.echo(for: checkIn))
        let reloaded = try #require(try r.mood.logs(on: r.clock.today).first)
        #expect(reloaded.echoID == first.id)
        #expect(echoes.echo(for: reloaded)?.id == first.id)
        #expect(echoes.echoText(reloaded.echoID) == first.text)
    }

    // MARK: - Yolculuk akışı (MIGRATION T7)

    private func legacyRow(_ ctx: NSManagedObjectContext, day: String, hour: Double) {
        var cal = Calendar(identifier: .gregorian); cal.timeZone = TimeZone(identifier: "Europe/Istanbul")!
        let midnight = DayKey(day)!.startDate(in: cal)!
        let row = NSEntityDescription.insertNewObject(forEntityName: "DailySong", into: ctx)
        row.setValue(UUID(), forKey: "id")
        row.setValue(midnight, forKey: "date")
        row.setValue(midnight.addingTimeInterval(hour * 3600), forKey: "createdAt")
        row.setValue("#123456", forKey: "moodColorHex")
        row.setValue(false, forKey: "passed")
    }

    @Test("Yolculuk: gün yeniden eskiye, gün içinde yeniden eskiye; metinsiz check-in girdisi tekrar etmez; v3 anıları aynı günde")
    func journeyMerge() throws {
        let r = Self.rig()
        let ctx = r.container.viewContext
        let checkInEntry = try r.journal.create(EntryDraft(kind: .dailyCheckIn))
        try r.mood.log(score: 4, source: .checkIn, linkedTo: checkInEntry.id)
        r.clock.advance(hours: 1)
        let text = try r.journal.create(EntryDraft(kind: .freeform, body: "Bugün yürüdüm."))
        let photo: MediaMO = ctx.insert("Media")
        photo.id = UUID(); photo.type = "photo"; photo.data = Data([1])
        photo.entry = try ctx.fetchOne(ONE2Entity.entry, id: text.id, as: EntryMO.self)
        legacyRow(ctx, day: "2026-09-23", hour: 1)   // aynı gün, daha erken
        legacyRow(ctx, day: "2026-09-20", hour: 9)
        try ctx.save()

        let feed = JourneyFeed(context: ctx, journal: r.journal, mood: r.mood,
                               legacy: LegacyMomentStore(context: ctx, calendar: r.clock.calendar))
        let days = try feed.days(from: DayKey("2026-09-01")!, through: r.clock.today)
        #expect(days.map(\.day.string) == ["2026-09-23", "2026-09-20"])
        let today = days[0].items
        #expect(today.count == 4) // girdi + foto (aynı an) + check-in + v3 anısı; metinsiz check-in girdisi yok
        #expect(!today.contains { if case .entry(let e) = $0 { return e.id == checkInEntry.id } else { return false } })
        #expect(today.last?.isLegacy == true)
        #expect(zip(today, today.dropFirst()).allSatisfy { $0.time >= $1.time })
        #expect(try feed.days(from: DayKey("2026-09-01")!, through: r.clock.today, includeLegacy: false)
            .flatMap(\.items).allSatisfy { !$0.isLegacy })
        #expect(try feed.month(containing: r.clock.today).count == 2)
    }

    // MARK: - Eğilimler, rozet, Keşfet

    @Test("Eğilimler: aylık (son 12 ay) ve yıllık seriler, eşik 3")
    func periodSeries() {
        func log(_ d: String, _ s: Int) -> MoodCheckIn {
            MoodCheckIn(id: UUID(), day: DayKey(d)!, timeZoneID: nil, timestamp: Date(), score: s, emotionIDs: [],
                        causeIDs: [], note: nil, source: .checkIn, healthKitSampleID: nil, entryID: nil)
        }
        let today = DayKey("2026-09-23")!
        let logs = [log("2026-09-01", 4), log("2026-09-20", 2), log("2026-08-05", 5), log("2025-09-30", 1), log("2024-01-10", 3)]
        let months = Insights.monthlySeries(logs, today: today).value!
        #expect(months.map(\.day.string) == ["2026-08-01", "2026-09-01"]) // 2025-09-30 son 12 ayın dışında
        #expect(months.last?.average == 3)
        let years = Insights.yearlySeries(logs, today: today).value!
        #expect(years.map(\.day.string) == ["2024-01-01", "2025-01-01", "2026-01-01"])
        #expect(Insights.yearlySeries(Array(logs.prefix(2)), today: today) == .insufficient(needed: 3, have: 2))
    }

    @Test("Rozet ilerlemesi: kilitlide kalan, kazanılanda tarih")
    func badgeProgress() throws {
        var s = BadgeStats(); s.longestStreak = 4; s.totalWords = 1_500
        let streak = BadgeRules.progress(.streak(7), stats: s)
        #expect(streak.current == 4 && streak.target == 7)
        let first = BadgeRules.progress(.firstOf(.guided), stats: s)
        #expect(first.current == 0 && first.target == 1)
        let status = BadgeStatus(badge: BadgeDefinition(id: "b", title: "b", summary: "", rule: .streak(7), premium: false,
                                                        active: true, addedIn: 1, lang: "tr"),
                                 earnedAt: nil, current: 4, target: 7)
        #expect(status.remaining == 3 && !status.isEarned)

        let r = Self.rig()
        let library = LibraryStore(context: r.container.viewContext, clock: r.clock)
        let engine = BadgeEngine(content: r.content, journal: r.journal, day: r.day, library: library, profile: r.profile)
        _ = try r.journal.create(EntryDraft(kind: .freeform, body: "ilk"))
        try engine.evaluateOnLaunch()
        let overview = try engine.overview()
        #expect(overview.count == r.content.catalog.badges.count)
        #expect(overview.first { $0.badge.id == "b_first_entry" }?.isEarned == true)
        #expect(overview.first { $0.badge.id == "b_streak_7" }?.remaining == 7)
    }

    @Test("Öne çıkan haftanın tarih aralığı ve Yeni rozeti")
    func exploreBits() throws {
        let r = Self.rig()
        let week = try #require(ThemeCalendar.theme(for: DayKey("2026-09-23")!, catalog: r.content.catalog,
                                                    salt: r.profile.profile.userSalt))
        #expect(week.firstDay?.string == "2026-09-21" && week.lastDay?.string == "2026-09-27")
        // contentVersion 1: ilk paketteki hiçbir şey "yeni" değil.
        #expect(!r.content.catalog.guided.contains { r.content.catalog.isNew($0) })
    }
}
