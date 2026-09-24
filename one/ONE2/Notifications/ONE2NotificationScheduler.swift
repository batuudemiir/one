//
//  ONE2NotificationScheduler.swift
//  ONE 2.0
//
//  `NotificationPlanner`'ı motorlardan besler ve planı `NotificationOrchestrator`
//  üzerinden kurar (ADR-001 §6). Her yeniden kurulumda önce `one2.` önekli
//  bekleyen istekler iptal edilir, sonra 7 günlük pencere yazılır.
//
//  Tetik: açılış, ritüel/girdi kaydı, profil (saatler, mod) ve içerik
//  güncellemesi. Bütçeyi planlayıcı uyguladığı için Orchestrator'ın günlük
//  dedupe/tavan kararı atlanır (`decisionOverride: .allow`).
//

import Foundation
import UserNotifications

/// Bildirim merkezinin ince soyutlaması; testte sahte.
protocol NotificationScheduling: AnyObject {
    func pendingIdentifiers() async -> [String]
    func cancel(_ identifiers: [String])
    func add(_ notification: PlannedNotification, calendar: Calendar)
}

/// Orchestrator üzerinden gerçek zamanlama.
final class OrchestratorNotificationScheduling: NotificationScheduling {
    func pendingIdentifiers() async -> [String] {
        await UNUserNotificationCenter.current().pendingNotificationRequests().map(\.identifier)
    }

    func cancel(_ identifiers: [String]) {
        NotificationOrchestrator.shared.cancel(identifiers: identifiers)
    }

    func add(_ n: PlannedNotification, calendar: Calendar) {
        let content = UNMutableNotificationContent()
        content.title = n.title
        content.body = n.body
        content.sound = .default
        content.categoryIdentifier = n.categoryIdentifier
        var comps = DateComponents()
        comps.calendar = calendar
        comps.year = n.day.year; comps.month = n.day.month; comps.day = n.day.day
        comps.hour = n.hour; comps.minute = n.minute
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
        NotificationOrchestrator.shared.schedule(kind: n.kind, identifier: n.identifier, trigger: trigger,
                                                 content: content, decisionOverride: .allow)
    }
}

final class ONE2NotificationScheduler {
    static let enabledKey = "one2.notifications.enabled"

    private let quotes: LiveQuoteEngine
    private let prompts: LivePromptEngine
    private let content: ContentRepository
    private let day: DayStore
    private let profile: ProfileStore
    private let clock: AppClock
    private let scheduling: NotificationScheduling
    private let local: KeyValueBacking
    private let copy: NotificationCopy

    init(quotes: LiveQuoteEngine, prompts: LivePromptEngine, content: ContentRepository, day: DayStore,
         profile: ProfileStore, clock: AppClock,
         scheduling: NotificationScheduling = OrchestratorNotificationScheduling(),
         local: KeyValueBacking = UserDefaults(suiteName: "group.com.batudemir.ones") ?? .standard,
         copy: NotificationCopy = .localized) {
        self.quotes = quotes; self.prompts = prompts; self.content = content; self.day = day
        self.profile = profile; self.clock = clock; self.scheduling = scheduling; self.local = local; self.copy = copy
    }

    /// Açık türler; ayar ekranı gelene kadar varsayılanlar (E13 tablosu).
    var enabledKinds: Set<NotificationKind> {
        get {
            guard let raw = local.object(forKey: Self.enabledKey) as? [String] else { return NotificationPlanner.defaultEnabled }
            return Set(raw.compactMap(NotificationKind.init(rawValue:)))
        }
        set { local.set(newValue.map(\.rawValue).sorted(), forKey: Self.enabledKey) }
    }

    /// Planı kurar ve kurulanları döner.
    @discardableResult
    func rebuild(openedToday: Bool = true) async -> [PlannedNotification] {
        let input = await makeInput(openedToday: openedToday)
        let plan = NotificationPlanner.plan(input, copy: copy)
        let stale = await scheduling.pendingIdentifiers().filter { $0.hasPrefix(NotificationPlanner.prefix) }
        if !stale.isEmpty { scheduling.cancel(stale) }
        for n in plan { scheduling.add(n, calendar: clock.calendar) }
        return plan
    }

    func makeInput(openedToday: Bool) async -> NotificationPlanInput {
        let today = clock.today
        let p = profile.profile
        let comps = clock.calendar.dateComponents([.hour, .minute], from: clock.now)
        var input = NotificationPlanInput(today: today, nowHour: comps.hour ?? 0, nowMinute: comps.minute ?? 0,
                                          profile: p, enabled: enabledKinds, openedToday: openedToday)
        let catalog = content.catalog
        for offset in 0..<NotificationPlanner.windowDays {
            let d = today.adding(days: offset)
            input.dailyQuotes[d] = quotes.previewDailyQuote(for: d)?.text
            input.themePrompts[d] = await prompts.dailyPrompt(for: d)?.text
            if d.isoWeekday == 1, let week = ThemeCalendar.theme(for: d, catalog: catalog, salt: p.userSalt),
               let first = week.theme.prompt(forWeekday: 1) {
                input.weekStarts[d] = (week.theme.title, first)
            }
        }
        let completion = try? day.completion(on: today)
        input.morningDoneToday = completion?.morningCompletedAt != nil
        input.eveningDoneToday = p.ritualMode == .daily
            ? completion?.dailyCompletedAt != nil || completion?.completedBy == .writing
            : completion?.eveningCompletedAt != nil
        input.streak = try? day.streakState(mode: p.ritualMode, visible: p.streakVisible)
        if input.enabled.contains(.contentSuggestion) {
            if let c = await prompts.comparisonCandidate(on: today) {
                input.suggestion = .comparison(prompt: c.prompt.text)
            } else if let r = await quotes.resurfacingCandidate(on: today) {
                input.suggestion = .resurface(quote: r.quote.text)
            }
        }
        return input
    }
}
