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

final class AppEnvironment {
    let clock: AppClock
    let content: ContentRepository
    let journal: JournalStore
    let mood: MoodStore
    let day: DayStore
    let library: LibraryStore
    let exposure: ExposureStore
    let legacy: LegacyMomentStore
    /// `DailySong` yazım emniyet ağı; ortam yaşadıkça kurulu kalır.
    private let legacyWriteGuard: LegacyWriteGuard?

    init(context: NSManagedObjectContext, clock: AppClock = SystemClock(), guardLegacyWrites: Bool = true,
         content: ContentRepository? = nil) {
        self.clock = clock
        self.content = content ?? ContentRepository(clock: clock)
        journal = JournalStore(context: context, clock: clock)
        mood = MoodStore(context: context, clock: clock)
        day = DayStore(context: context, clock: clock)
        library = LibraryStore(context: context, clock: clock)
        exposure = ExposureStore(context: context, clock: clock)
        legacy = LegacyMomentStore(context: context, calendar: clock.calendar)
        if guardLegacyWrites, let coordinator = context.persistentStoreCoordinator {
            legacyWriteGuard = LegacyWriteGuard(coordinator: coordinator)
        } else {
            legacyWriteGuard = nil
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
