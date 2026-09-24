//
//  NotificationWidgetTests.swift
//  oneTests
//
//  E13 bildirim metin planlayıcı ve E14 widget yazıcı (04_arka_plan_motorlari.md).
//

import Testing
import Foundation
import CoreData
@testable import OneDailyBatuhan

@MainActor
struct NotificationPlannerTests {

    private static let copy = NotificationCopy(
        morningTitle: "Günün sözü", morningFallbacks: ["F1", "F2", "F3"],
        eveningTitle: "Günü kapatma vakti.", eveningBody: "Akşam",
        weeklyThemeTitle: { "Tema: \($0)" }, streakTitle: "Seri", streakBody: { "\($0) gün" },
        comparisonTitle: "Karşılaştır", resurfaceTitle: "Geri dön")

    /// 2026-09-23 çarşamba, 07:00.
    private func input(_ mutate: (inout NotificationPlanInput) -> Void = { _ in }) -> NotificationPlanInput {
        var i = NotificationPlanInput(today: DayKey("2026-09-23")!, nowHour: 7, nowMinute: 0,
                                      profile: UserProfile(userSalt: UUID()))
        mutate(&i)
        return i
    }

    @Test("7 günlük pencere: sabah + akşam, kimlik şeması, bütçe ≤ 20")
    func window() {
        let plan = NotificationPlanner.plan(input(), copy: Self.copy)
        #expect(plan.filter { $0.kind == .morningRitual }.count == 7)
        #expect(plan.filter { $0.kind == .eveningRitual }.count == 7)
        #expect(plan.first?.identifier == "one2.morningRitual.2026-09-23")
        #expect(plan.allSatisfy { $0.identifier.hasPrefix("one2.") })
        #expect(Set(plan.map(\.identifier)).count == plan.count)
        #expect(plan.count <= 20)
        #expect(plan.first?.categoryIdentifier == "ONE2_MORNINGRITUAL")
    }

    @Test("Uygulama bugün açıldıysa bugünün sabahı, ritüel yapıldıysa bugünün akşamı kurulmaz; geçmiş saat kurulmaz")
    func todaySkips() {
        let opened = NotificationPlanner.plan(input { $0.openedToday = true; $0.eveningDoneToday = true }, copy: Self.copy)
        #expect(!opened.contains { $0.day == DayKey("2026-09-23")! && [.morningRitual, .eveningRitual].contains($0.kind) })
        let late = NotificationPlanner.plan(input { $0.nowHour = 22 }, copy: Self.copy)
        #expect(!late.contains { $0.day == DayKey("2026-09-23")! })
        #expect(late.filter { $0.kind == .morningRitual }.count == 6)
    }

    @Test("Metin: sözün ilk cümlesi, yoksa dönen cümle; akşamda tema sorusu; pazartesi tema bildirimi")
    func copyContent() {
        let tomorrow = DayKey("2026-09-24")!, monday = DayKey("2026-09-28")!
        let plan = NotificationPlanner.plan(input {
            $0.dailyQuotes[tomorrow] = "Dikkatini verdiğin şey büyür. İkinci cümle."
            $0.themePrompts[tomorrow] = "Bugün neye acele ettin?"
            $0.weekStarts[monday] = ("Minnet", "Bu sabah neye minnettarsın?")
        }, copy: Self.copy)
        #expect(plan.first { $0.kind == .morningRitual && $0.day == tomorrow }?.body == "Dikkatini verdiğin şey büyür.")
        #expect(["F1", "F2", "F3"].contains(plan.first { $0.kind == .morningRitual && $0.day == monday }?.body ?? ""))
        #expect(plan.first { $0.kind == .eveningRitual && $0.day == tomorrow }?.body == "Bugün neye acele ettin?")
        #expect(plan.first { $0.kind == .eveningRitual && $0.day == monday }?.body == "Akşam")
        let theme = plan.first { $0.kind == .weeklyTheme }
        #expect(theme?.day == monday && theme?.title == "Tema: Minnet")
    }

    @Test("Seri hatırlatması ve içerik önerisi varsayılan kapalı; açılınca kurallara uyar")
    func optionalKinds() {
        let risk = StreakState(count: 5, atRisk: true, isVisible: true, longest: 5)
        let off = NotificationPlanner.plan(input { $0.streak = risk; $0.suggestion = .comparison(prompt: "Soru") }, copy: Self.copy)
        #expect(!off.contains { $0.kind == .streakReminder || $0.kind == .contentSuggestion })

        let all: Set<NotificationKind> = NotificationPlanner.defaultEnabled.union([.streakReminder, .contentSuggestion])
        let on = NotificationPlanner.plan(input {
            $0.enabled = all; $0.streak = risk; $0.suggestion = .resurface(quote: "Söz")
        }, copy: Self.copy)
        let streak = on.first { $0.kind == .streakReminder }
        #expect(streak?.hour == 23 && streak?.minute == 30) // 21:30 + 2 sa, 23:30'a kırpılır
        #expect(streak?.body == "5 gün")
        let suggestion = on.first { $0.kind == .contentSuggestion }
        #expect(suggestion?.hour == 13 && suggestion?.title == "Geri dön")

        let hidden = NotificationPlanner.plan(input {
            $0.enabled = all; $0.streak = StreakState(count: 5, atRisk: true, isVisible: false, longest: 5)
        }, copy: Self.copy)
        #expect(!hidden.contains { $0.kind == .streakReminder })
    }

    @Test("Yerelleştirilmiş metinler katalogda var")
    func localizedCopy() {
        let copy = NotificationCopy.localized
        #expect(!copy.morningTitle.hasPrefix("notif.one2"))
        #expect(copy.morningFallbacks.allSatisfy { !$0.hasPrefix("notif.one2") })
        #expect(copy.weeklyThemeTitle("X").contains("X"))
        #expect(copy.streakBody(4).contains("4"))
    }

    @Test("Zamanlayıcı: yalnız one2. önekli bekleyenleri iptal eder, planı kurar")
    func scheduler() async {
        let clock = TestClock("2026-09-23T04:00:00Z") // 07:00 İstanbul
        let container = ONE2TestStack.makeContainer()
        let ctx = container.viewContext
        let content = ContentRepository(bundle: BundleContentSource(bundle: Bundle(for: PersistenceController.self)),
                                        cacheDirectory: FileManager.default.temporaryDirectory.appendingPathComponent("n-\(UUID())"),
                                        fetcher: FakeContentFetcher(files: nil), clock: clock,
                                        defaults: UserDefaults(suiteName: "n-\(UUID())")!)
        let profile = ProfileStore(cloud: MemoryKeyValueStore(), local: MemoryKeyValueStore())
        let exposure = ExposureStore(context: ctx, clock: clock)
        let journal = JournalStore(context: ctx, clock: clock)
        let kv = MemoryKeyValueStore()
        let quotes = LiveQuoteEngine(content: content, exposure: exposure, profile: profile, clock: clock,
                                     cloud: kv, local: MemoryKeyValueStore())
        let prompts = LivePromptEngine(content: content, exposure: exposure, journal: journal, profile: profile,
                                       clock: clock, local: MemoryKeyValueStore())
        let fake = FakeScheduling(pending: ["one2.morningRitual.2026-09-20", "v3_daily_reminder_1"])
        let scheduler = ONE2NotificationScheduler(quotes: quotes, prompts: prompts, content: content,
                                                  day: DayStore(context: ctx, clock: clock), profile: profile, clock: clock,
                                                  scheduling: fake, local: MemoryKeyValueStore(), copy: Self.copy)
        let plan = await scheduler.rebuild(openedToday: false)
        #expect(fake.cancelled == ["one2.morningRitual.2026-09-20"])
        #expect(fake.added == plan.map(\.identifier))
        #expect(plan.count == 15) // 7 sabah + 7 akşam + pazartesi teması (28 Eylül)
        #expect(plan.first { $0.kind == .eveningRitual }?.body == content.catalog.theme(week: "2026-W39")?.prompt(forWeekday: 3))
        // Pencere yeni sözü KVS'ye yazmaz; bugünün sözü seçilmemiş kalır.
        #expect(kv.object(forKey: "quote.daily.2026-09-23") == nil)
    }
}

final class FakeScheduling: NotificationScheduling {
    var pending: [String]
    private(set) var cancelled: [String] = []
    private(set) var added: [String] = []

    init(pending: [String]) { self.pending = pending }

    func pendingIdentifiers() async -> [String] { pending }
    func cancel(_ identifiers: [String]) { cancelled += identifiers }
    func add(_ notification: PlannedNotification, calendar: Calendar) { added.append(notification.identifier) }
}

@MainActor
struct WidgetBridgeTests {

    @Test("w2_* anahtarları yazılır, değişmeyince widget tazelenmez")
    func write() {
        let kv = MemoryKeyValueStore()
        var reloads = 0
        let bridge = WidgetBridge(backing: kv, reload: { reloads += 1 })
        let day = DayKey("2026-09-23")!
        var s = WidgetSnapshotV2()
        s.dailyQuote = WidgetSnapshotV2.quote(Quote(id: "q1", text: "Söz.", kind: .quote, author: "Seneca", source: "Mektuplar"), day: day)
        s.streak = WidgetStreak(count: 3, visible: true, atRisk: false)
        s.theme = WidgetTheme(title: "Minnet", prompt: "Soru?")
        let changed = bridge.write(s)
        #expect(changed.contains("w2_dailyQuote") && changed.contains("w2_version"))
        #expect(reloads == 1)
        #expect(bridge.read("w2_dailyQuote", as: WidgetQuote.self)?.source == "Seneca, Mektuplar")
        #expect(kv.object(forKey: "w2_version") as? Int == 1)
        #expect(bridge.write(s).isEmpty && reloads == 1)
        s.todayCheckIn = WidgetCheckIn(score: 4, label: "huzurlu", echo: nil)
        #expect(bridge.write(s) == ["w2_todayCheckin"])
        #expect(reloads == 2)
        s.todayCheckIn = nil
        #expect(bridge.write(s) == ["w2_todayCheckin"])
        #expect(kv.object(forKey: "w2_todayCheckin") == nil)
    }

    @Test("Hafta şeridi: ISO hafta, yarım/tam gün, bugün ve gelecek")
    func week() {
        let today = DayKey("2026-09-23")!
        let t = Date()
        let week = WidgetSnapshotV2.week([DayCompletion(day: DayKey("2026-09-21")!, morningCompletedAt: t),
                                          DayCompletion(day: DayKey("2026-09-22")!, morningCompletedAt: t, eveningCompletedAt: t)],
                                         mode: .morningEvening, today: today)
        #expect(week.map(\.day).first == "2026-09-21" && week.count == 7)
        #expect(week.map(\.status) == [.half, .full, .none, .none, .none, .none, .none])
        #expect(week[2].isToday && week[3].isFuture && !week[1].isFuture)
    }

    @Test("Anlık görüntü motorlardan: günün sözü ve ertesi gün, tema, check-in ve yankı")
    func snapshotSource() async throws {
        let clock = TestClock("2026-09-23T09:00:00Z")
        let container = ONE2TestStack.makeContainer()
        let ctx = container.viewContext
        let content = ContentRepository(bundle: BundleContentSource(bundle: Bundle(for: PersistenceController.self)),
                                        cacheDirectory: FileManager.default.temporaryDirectory.appendingPathComponent("w-\(UUID())"),
                                        fetcher: FakeContentFetcher(files: nil), clock: clock,
                                        defaults: UserDefaults(suiteName: "w-\(UUID())")!)
        let profile = ProfileStore(cloud: MemoryKeyValueStore(), local: MemoryKeyValueStore())
        let exposure = ExposureStore(context: ctx, clock: clock)
        let journal = JournalStore(context: ctx, clock: clock)
        let mood = MoodStore(context: ctx, clock: clock)
        let day = DayStore(context: ctx, clock: clock)
        let quotes = LiveQuoteEngine(content: content, exposure: exposure, profile: profile, clock: clock,
                                     cloud: MemoryKeyValueStore(), local: MemoryKeyValueStore())
        let prompts = LivePromptEngine(content: content, exposure: exposure, journal: journal, profile: profile,
                                       clock: clock, local: MemoryKeyValueStore())
        let echoes = EchoEngine(content: content, exposure: exposure, profile: profile, clock: clock)
        try mood.log(score: 4, emotionIDs: ["huzur.sakin"], source: .checkIn)
        let echo = try #require(echoes.echo(for: EchoInput(score: 4, checkInID: "x")))
        try day.markCompleted(.daily)

        let source = WidgetSnapshotSource(quotes: quotes, prompts: prompts, content: content, day: day,
                                          mood: mood, exposure: exposure, profile: profile, clock: clock)
        let s = await source.snapshot()
        #expect(s.dailyQuote?.day == "2026-09-23")
        #expect(s.dailyQuoteNext?.day == "2026-09-24")
        #expect(s.dailyQuote?.id != s.dailyQuoteNext?.id)
        #expect(s.theme?.title == content.catalog.theme(week: "2026-W39")?.title)
        #expect(s.todayCheckIn == WidgetCheckIn(score: 4, label: "Sakin", echo: echo.text))
        #expect(s.streak?.count == 1)
        #expect(s.week.first { $0.isToday }?.status == .full)
    }
}
