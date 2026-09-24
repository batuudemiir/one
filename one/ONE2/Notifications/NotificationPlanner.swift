//
//  NotificationPlanner.swift
//  ONE 2.0
//
//  Bildirim içerik planlayıcı (04_arka_plan_motorlari.md › E13). Motor
//  `NotificationOrchestrator` (ADR-001 §6); burası yalnız hangi gün hangi
//  metnin gideceğine karar verir.
//
//  | Tür                | Metin                                                  | Varsayılan |
//  |--------------------|--------------------------------------------------------|------------|
//  | morningRitual      | Günün sözünün ilk cümlesi ya da dönen ritüel cümlesi    | Açık       |
//  | eveningRitual      | "Günü kapatma vakti." + o günün tema sorusu            | Açık       |
//  | weeklyTheme        | Pazartesi: tema adı + ilk soru                         | Açık       |
//  | contentSuggestion  | Karşılaştırma adayı ya da geri dönen söz               | Kapalı     |
//  | streakReminder     | Seri risk altındaysa, akşam saatinden 2 saat sonra     | Kapalı     |
//
//  - 7 günlük kayan pencere; içerik ya da profil değişince yeniden kurulur.
//    Bütçe: 7 + 7 + 1 + 1 + 1 ≤ 17 bekleyen istek (ADR tavanı 20).
//  - Aynı gün uygulama açıldıysa o günün sabah hatırlatması, ritüel
//    yapıldıysa o günün hatırlatması kurulmaz.
//  - Kimlik: `one2.<kind>.<yyyy-MM-dd>`; `one2.` önekiyle toplu iptal.
//

import Foundation

struct PlannedNotification: Hashable {
    let kind: NotificationKind
    let identifier: String
    let day: DayKey
    /// Yerel saat.
    let hour: Int
    let minute: Int
    let title: String
    let body: String

    var categoryIdentifier: String { "ONE2_\(kind.rawValue.uppercased())" }
}

/// Planlayıcıya verilen metinler (yerelleştirilmiş); test için enjekte edilir.
nonisolated struct NotificationCopy: Sendable {
    var morningTitle: String
    var morningFallbacks: [String]
    var eveningTitle: String
    var eveningBody: String
    var weeklyThemeTitle: @Sendable (String) -> String
    var streakTitle: String
    var streakBody: @Sendable (Int) -> String
    var comparisonTitle: String
    var resurfaceTitle: String

    static var localized: NotificationCopy {
        func L(_ key: String) -> String { NSLocalizedString(key, comment: "ONE 2.0 notification copy") }
        let theme = L("notif.one2.weeklyTheme.title"), streak = L("notif.one2.streak.body")
        return NotificationCopy(
            morningTitle: L("notif.one2.morning.title"),
            morningFallbacks: (1...3).map { L("notif.one2.morning.fallback.\($0)") },
            eveningTitle: L("notif.one2.evening.title"),
            eveningBody: L("notif.one2.evening.body"),
            weeklyThemeTitle: { String(format: theme, $0) },
            streakTitle: L("notif.one2.streak.title"),
            streakBody: { String(format: streak, $0) },
            comparisonTitle: L("notif.one2.comparison.title"),
            resurfaceTitle: L("notif.one2.resurface.title")
        )
    }
}

nonisolated enum ContentSuggestionText: Hashable, Sendable {
    case comparison(prompt: String)
    case resurface(quote: String)
}

struct NotificationPlanInput {
    var today: DayKey
    /// Bugünün şu anki yerel saati ve dakikası (geçmiş saatler kurulmaz).
    var nowHour: Int
    var nowMinute: Int
    var profile: UserProfile
    var enabled: Set<NotificationKind> = NotificationPlanner.defaultEnabled
    /// Pencere günlerinin sözü (bugün KVS'deki, sonrası deterministik seçim).
    var dailyQuotes: [DayKey: String] = [:]
    /// Pencere günlerinin tema sorusu.
    var themePrompts: [DayKey: String] = [:]
    /// Pencerede başlayan haftanın teması: pazartesi günü → (ad, ilk soru).
    var weekStarts: [DayKey: (title: String, firstPrompt: String)] = [:]
    var openedToday = false
    var morningDoneToday = false
    var eveningDoneToday = false
    var streak: StreakState?
    var suggestion: ContentSuggestionText?
}

enum NotificationPlanner {
    static let windowDays = 7
    static let prefix = "one2."
    static let defaultEnabled: Set<NotificationKind> = [.morningRitual, .eveningRitual, .weeklyTheme]
    static let suggestionHour = 13
    static let streakDelayMinutes = 120

    static func identifier(_ kind: NotificationKind, _ day: DayKey) -> String {
        "\(prefix)\(kind.rawValue).\(day.string)"
    }

    static func plan(_ input: NotificationPlanInput, copy: NotificationCopy) -> [PlannedNotification] {
        var out: [PlannedNotification] = []
        let p = input.profile
        func isFuture(_ day: DayKey, _ h: Int, _ m: Int) -> Bool {
            day > input.today || (h, m) > (input.nowHour, input.nowMinute)
        }
        func add(_ kind: NotificationKind, _ day: DayKey, _ h: Int, _ m: Int, _ title: String, _ body: String) {
            guard input.enabled.contains(kind), isFuture(day, h, m) else { return }
            out.append(PlannedNotification(kind: kind, identifier: identifier(kind, day), day: day,
                                           hour: h, minute: m, title: title, body: body))
        }

        for offset in 0..<windowDays {
            let day = input.today.adding(days: offset)
            let isToday = offset == 0

            if !(isToday && (input.openedToday || input.morningDoneToday)) {
                let body = input.dailyQuotes[day].map(firstSentence)
                    ?? copy.morningFallbacks[abs(day.day + day.month) % max(1, copy.morningFallbacks.count)]
                add(.morningRitual, day, p.morningTime.hour, p.morningTime.minute, copy.morningTitle, body)
            }
            if !(isToday && input.eveningDoneToday) {
                add(.eveningRitual, day, p.eveningTime.hour, p.eveningTime.minute, copy.eveningTitle,
                    input.themePrompts[day] ?? copy.eveningBody)
            }
            if let week = input.weekStarts[day], day.isoWeekday == 1 {
                add(.weeklyTheme, day, p.morningTime.hour, p.morningTime.minute,
                    copy.weeklyThemeTitle(week.title), week.firstPrompt)
            }
        }

        if let streak = input.streak, streak.atRisk, streak.isVisible, !input.eveningDoneToday {
            let total = p.eveningTime.minutesSinceMidnight + streakDelayMinutes
            let minutes = min(total, 23 * 60 + 30)
            add(.streakReminder, input.today, minutes / 60, minutes % 60, copy.streakTitle, copy.streakBody(streak.count))
        }

        if let suggestion = input.suggestion {
            let day = isFuture(input.today, suggestionHour, 0) ? input.today : input.today.adding(days: 1)
            switch suggestion {
            case .comparison(let prompt): add(.contentSuggestion, day, suggestionHour, 0, copy.comparisonTitle, prompt)
            case .resurface(let quote): add(.contentSuggestion, day, suggestionHour, 0, copy.resurfaceTitle, quote)
            }
        }
        return out.sorted { ($0.day, $0.hour, $0.minute, $0.identifier) < ($1.day, $1.hour, $1.minute, $1.identifier) }
    }

    /// Sözün ilk cümlesi (bildirim gövdesi kısa kalsın).
    static func firstSentence(_ text: String) -> String {
        let terminators: Set<Character> = [".", "?", "!", ";", "…"]
        guard let i = text.firstIndex(where: terminators.contains) else { return text }
        let sentence = text[...i].trimmingCharacters(in: .whitespaces)
        return sentence.count >= 12 ? sentence : text
    }
}
