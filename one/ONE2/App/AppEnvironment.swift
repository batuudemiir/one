//
//  AppEnvironment.swift
//  ONE 2.0
//
//  ONE 2.0'ın bağımlılıkları tek yerde (ADR-001 §4). Ekranlar servisleri
//  `@Environment(\.one2)` ile alır; yeni `.shared` singleton yok. Testlerde
//  ve önizlemelerde bellekte store ile kurulur.
//

import SwiftUI
import CoreData

/// Bir kaydın zincir sonucu (E8 + E9); kapanış ekranı (Seal) bunu gösterir.
nonisolated struct WritingOutcome: Hashable, Sendable {
    let entry: JournalEntry
    /// Bu kayıt günü yazıyla tamamladı (≥ 20 kelime, gün önceden kapalı değildi).
    let completedDay: Bool
    /// Kapanışta duyurulacak yeni rozetler.
    let badges: [BadgeDefinition]
}

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
    let legacy: LegacyMomentStore
    /// `DailySong` yazım emniyet ağı; ortam yaşadıkça kurulu kalır.
    private let legacyWriteGuard: LegacyWriteGuard?
    /// Arka plandan dönüşte yeni söz oturumu açmak için.
    private var isBackgrounded = false
    /// Son kaydın sonucu. `journal.create` döndüğünde hazırdır (zincir eşzamanlı).
    private(set) var lastWriting: WritingOutcome?

    init(context: NSManagedObjectContext, clock: AppClock = SystemClock(), guardLegacyWrites: Bool = true,
         content: ContentRepository? = nil, profile: ProfileStore? = nil) {
        self.clock = clock
        self.content = content ?? ContentRepository(clock: clock)
        self.profile = profile ?? ProfileStore()
        journal = JournalStore(context: context, clock: clock)
        mood = MoodStore(context: context, clock: clock)
        day = DayStore(context: context, clock: clock)
        library = LibraryStore(context: context, clock: clock)
        exposure = ExposureStore(context: context, clock: clock)
        let mood = self.mood
        // Premium: EntitlementStore gelene kadar kapalı (ADR §8).
        quotes = LiveQuoteEngine(content: self.content, exposure: exposure, profile: self.profile, clock: clock,
                                 moodScore: { [clock] in (try? mood.logs(on: clock.today))?.last?.score })
        prompts = LivePromptEngine(content: self.content, exposure: exposure, journal: journal,
                                   profile: self.profile, clock: clock)
        echoes = EchoEngine(content: self.content, exposure: exposure, profile: self.profile, clock: clock)
        recommendations = RecommendationEngine(content: self.content, prompts: prompts, journal: journal, day: day,
                                               mood: mood, profile: self.profile, clock: clock)
        badges = BadgeEngine(content: self.content, journal: journal, day: day, library: library, profile: self.profile)
        insights = InsightsEngine(context: context, mood: mood, journal: journal, day: day, exposure: exposure,
                                  content: self.content, profile: self.profile, clock: clock)
        search = SearchIndex(context: context)
        notifications = ONE2NotificationScheduler(quotes: quotes, prompts: prompts, content: self.content, day: day,
                                                  profile: self.profile, clock: clock)
        widget = WidgetBridge()
        widgetSource = WidgetSnapshotSource(quotes: quotes, prompts: prompts, content: self.content, day: day,
                                            mood: mood, exposure: exposure, profile: self.profile, clock: clock)
        legacy = LegacyMomentStore(context: context, calendar: clock.calendar)
        if guardLegacyWrites, let coordinator = context.persistentStoreCoordinator {
            legacyWriteGuard = LegacyWriteGuard(coordinator: coordinator)
        } else {
            legacyWriteGuard = nil
        }
        // Her kayıttan sonra: E8 yazıyla tamamlama, E9 rozet, widget ve bildirim penceresi.
        journal.didSave = { [day, weak badges, weak self] entry in
            let completed = (try? day.recordWriting(entry)) ?? false
            let awards = (try? badges?.evaluateAfterSave()) ?? []
            self?.lastWriting = WritingOutcome(entry: entry, completedDay: completed,
                                               badges: awards.filter(\.announce).map(\.badge))
            Task { @MainActor in await self?.refreshSurfaces() }
        }
    }

    /// Widget (`w2_*`) ve bildirim penceresi (E13, E14). Her kayıt, gün
    /// değişimi ve içerik güncellemesinde çağrılır.
    func refreshSurfaces() async {
        widget.write(await widgetSource.snapshot())
        await notifications.rebuild()
    }

    /// Oturum sınırı: arka plana geçişte söz oturumu kapanır (hızlı geçilen
    /// kartlar kuyruğa döner) ve birikmiş görülmeler yazılır (E2.2, E3);
    /// geri gelişte yeni oturum başlar.
    func handleScenePhase(_ phase: ScenePhase) {
        switch phase {
        case .background:
            quotes.endSession()
            try? exposure.flush()
            isBackgrounded = true
        case .active where isBackgrounded:
            quotes.startSession()
            isBackgrounded = false
        default:
            break
        }
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
