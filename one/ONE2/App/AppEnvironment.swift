//
//  AppEnvironment.swift
//  ONE 2.0
//
//  ONE 2.0'ın bağımlılıkları tek yerde (ADR-001 §4). Ekranlar servisleri
//  `@Environment(\.one2)` ile alır; yeni `.shared` singleton yok. Testlerde
//  ve önizlemelerde bellekte store ile kurulur.
//
//  Yaşam döngüsü (`oneApp` çağırır): `onLaunch` (Tier 2), `onForeground`,
//  `onBackground`, `onDayChange`. Kayıt kancaları (girdi, check-in, ritüel)
//  yazıyla tamamlama, rozet, analitik, widget ve bildirim penceresini
//  besler; ekranlar bunları ayrıca çağırmaz.
//

import SwiftUI
import CoreData

final class AppEnvironment {
    let clock: AppClock
    let content: ContentRepository
    let profile: ProfileStore
    let journal: JournalStore
    let mood: MoodStore
    let day: DayStore
    let library: LibraryStore
    let exposure: ExposureStore
    let quotes: LiveQuoteEngine
    let prompts: LivePromptEngine
    let echoes: EchoEngine
    let recommendations: RecommendationEngine
    let badges: BadgeEngine
    let insights: InsightsEngine
    let search: SearchIndex
    let notifications: ONE2NotificationScheduler
    let widget: WidgetBridge
    let widgetSource: WidgetSnapshotSource
    let exporter: DataExporter
    let analytics: EventTracking
    let legacy: LegacyMomentStore
    /// `DailySong` yazım emniyet ağı; ortam yaşadıkça kurulu kalır.
    private let legacyWriteGuard: LegacyWriteGuard?
    /// Cihaz başına durum (son aktif gün, son bilinen seri).
    private let local: KeyValueBacking

    private enum Key {
        static let lastActiveDay = "one2.lastActiveDay"
        static let lastStreak = "one2.lastStreak"
    }

    init(context: NSManagedObjectContext, clock: AppClock = SystemClock(), guardLegacyWrites: Bool = true,
         content: ContentRepository? = nil, profile: ProfileStore? = nil,
         analytics: EventTracking = AppAnalyticsTracker(),
         cloud: KeyValueBacking = NSUbiquitousKeyValueStore.default,
         local: KeyValueBacking = UserDefaults(suiteName: WidgetDataWriter.appGroupID) ?? .standard,
         notificationScheduling: NotificationScheduling = OrchestratorNotificationScheduling(),
         widget: WidgetBridge? = nil) {
        self.clock = clock
        self.analytics = analytics
        self.local = local
        self.content = content ?? ContentRepository(clock: clock)
        self.profile = profile ?? ProfileStore(cloud: cloud, local: local)
        journal = JournalStore(context: context, clock: clock)
        mood = MoodStore(context: context, clock: clock)
        day = DayStore(context: context, clock: clock)
        library = LibraryStore(context: context, clock: clock)
        exposure = ExposureStore(context: context, clock: clock)
        let mood = self.mood
        // Premium: EntitlementStore gelene kadar kapalı (ADR §8).
        quotes = LiveQuoteEngine(content: self.content, exposure: exposure, profile: self.profile, clock: clock,
                                 cloud: cloud, local: local,
                                 moodScore: { [clock] in (try? mood.logs(on: clock.today))?.last?.score })
        prompts = LivePromptEngine(content: self.content, exposure: exposure, journal: journal,
                                   profile: self.profile, clock: clock, local: local)
        echoes = EchoEngine(content: self.content, exposure: exposure, profile: self.profile, clock: clock, mood: mood)
        recommendations = RecommendationEngine(content: self.content, prompts: prompts, journal: journal, day: day,
                                               mood: mood, profile: self.profile, clock: clock)
        badges = BadgeEngine(content: self.content, journal: journal, day: day, library: library, profile: self.profile)
        insights = InsightsEngine(context: context, mood: mood, journal: journal, day: day, exposure: exposure,
                                  content: self.content, profile: self.profile, clock: clock)
        search = SearchIndex(context: context)
        notifications = ONE2NotificationScheduler(quotes: quotes, prompts: prompts, content: self.content, day: day,
                                                  profile: self.profile, clock: clock,
                                                  scheduling: notificationScheduling, local: local)
        self.widget = widget ?? WidgetBridge(backing: local)
        widgetSource = WidgetSnapshotSource(quotes: quotes, prompts: prompts, content: self.content, day: day,
                                            mood: mood, exposure: exposure, profile: self.profile, clock: clock)
        legacy = LegacyMomentStore(context: context, calendar: clock.calendar)
        exporter = DataExporter(context: context, journal: journal, mood: mood, day: day, library: library,
                                exposure: exposure, legacy: legacy, content: self.content, clock: clock)
        if guardLegacyWrites, let coordinator = context.persistentStoreCoordinator {
            legacyWriteGuard = LegacyWriteGuard(coordinator: coordinator)
        } else {
            legacyWriteGuard = nil
        }
        // Her kayıttan sonra: E8 yazıyla tamamlama, E9 rozet, widget ve bildirim penceresi.
        quotes.onPoolLow = { [analytics] mode, remaining in
            analytics.track(.contentPoolLow(mode: mode.key, remaining: remaining))
        }
        journal.didSave = { [day, weak badges, weak self, analytics] entry in
            analytics.track(.entrySaved(kind: entry.kind, words: entry.wordCount, source: entry.sourceContext))
            if (try? day.recordWriting(entry)) == true {
                analytics.track(.dayCompleted(by: .writing, backfilled: entry.isBackfilled))
            }
            for award in (try? badges?.evaluateAfterSave()) ?? [] {
                analytics.track(.badgeAwarded(badgeID: award.badge.id, announced: award.announce))
            }
            Task { @MainActor in await self?.refreshSurfaces() }
        }
        mood.didSave = { [weak self, analytics] checkIn in
            analytics.track(.checkInDone(score: checkIn.score, emotionCount: checkIn.emotionIDs.count,
                                         causeCount: checkIn.causeIDs.count))
            Task { @MainActor in await self?.refreshSurfaces() }
        }
        day.didComplete = { [weak badges, weak self, analytics, clock] card, completion, newlyComplete in
            analytics.track(.ritualDone(kind: card))
            if newlyComplete {
                let backfilled = completion.day < clock.today
                analytics.track(.dayCompleted(by: .ritual, backfilled: backfilled))
                if backfilled { analytics.track(.backfillUsed(daysBack: completion.day.days(to: clock.today))) }
            }
            for award in (try? badges?.evaluateAfterSave()) ?? [] {
                analytics.track(.badgeAwarded(badgeID: award.badge.id, announced: award.announce))
            }
            Task { @MainActor in await self?.refreshSurfaces() }
        }
    }

    // MARK: - Yaşam döngüsü

    /// Tier 2: arama metni onarımı, sessiz rozet değerlendirmesi, kırılan
    /// seri olayı, günde bir içerik kontrolü, widget ve bildirim penceresi.
    func onLaunch() async {
        _ = try? search.rebuildMissing()
        for award in (try? badges.evaluateOnLaunch()) ?? [] {
            analytics.track(.badgeAwarded(badgeID: award.badge.id, announced: false))
        }
        trackStreakBreakIfNeeded()
        quotes.startSession()
        local.set(clock.today.string, forKey: Key.lastActiveDay)
        await refreshContent()
        await refreshSurfaces()
    }

    /// Ön plana dönüş: yeni söz oturumu; gün değiştiyse yüzeyler tazelenir.
    /// Bildirim penceresi "bugün açıldı" bilgisiyle yeniden kurulur (E13).
    func onForeground() async {
        quotes.startSession()
        if local.object(forKey: Key.lastActiveDay) as? String != clock.today.string {
            await onDayChange()
        } else {
            await notifications.rebuild(openedToday: true)
        }
    }

    /// Arka plana geçiş: birikmiş görülmeler yazılır (E3), hızlı geçilen
    /// kartlar kuyruğa döner (E2.2).
    func onBackground() {
        try? exposure.flush()
        quotes.endSession()
    }

    /// Gece yarısı ya da gün değişmiş olarak ön plana dönüş.
    func onDayChange() async {
        local.set(clock.today.string, forKey: Key.lastActiveDay)
        trackStreakBreakIfNeeded()
        await refreshSurfaces()
    }

    /// Son bilinen seri > 0 iken seri sıfırlandıysa `one2_streak_broken`.
    private func trackStreakBreakIfNeeded() {
        let mode = profile.profile.ritualMode
        guard let state = try? day.streakState(mode: mode, visible: profile.profile.streakVisible) else { return }
        let last = local.object(forKey: Key.lastStreak) as? Int ?? 0
        if last > 0 && state.count == 0 { analytics.track(.streakBroken(length: last)) }
        local.set(state.count, forKey: Key.lastStreak)
    }

    /// Widget (`w2_*`) ve bildirim penceresi (E13, E14). Her kayıt, gün
    /// değişimi ve içerik güncellemesinde çağrılır.
    func refreshSurfaces() async {
        widget.write(await widgetSource.snapshot())
        await notifications.rebuild()
    }

    /// Tier 2: günde bir uzak içerik kontrolü (ADR §5) ve içerik sağlığı olayları (E17).
    func refreshContent() async {
        let result = await content.refreshIfNeeded()
        if let reason = ONE2Event.updateFailureReason(result) { analytics.track(.contentUpdateFailed(reason: reason)) }
        let today = clock.today
        if ThemeCalendar.isNextWeekMissing(catalog: content.catalog, today: today) {
            analytics.track(.themeMissingNextWeek(week: ISOWeek(containing: today).adding(weeks: 1).description))
        }
        if case .updated = result { await refreshSurfaces() }
    }

    /// Uygulamanın gerçek store'u.
    static func live(_ persistence: PersistenceController = .shared) -> AppEnvironment {
        AppEnvironment(context: persistence.container.viewContext)
    }
}

private struct AppEnvironmentKey: EnvironmentKey {
    static let defaultValue: AppEnvironment? = nil
}

extension EnvironmentValues {
    var one2: AppEnvironment? {
        get { self[AppEnvironmentKey.self] }
        set { self[AppEnvironmentKey.self] = newValue }
    }
}
