//
//  StreakEngine.swift
//  one
//
//  B1 — Retention planı: streak + soft streak (freeze).
//
//  Soft streak felsefesi: Daylio'nun acımasız "tek gün kaçırırsan sıfır"
//  modeli ONE'ın soft aesthetic'ine uygun değil. Onun yerine kullanıcıya
//  haftada 1 freeze günü hediye ederiz — kaçırılan tek bir gün streak'i
//  kırmaz, freeze otomatik olarak köprü kurar.
//
//  Kurallar:
//  - Tek bir 7-günlük rolling pencere içinde en fazla 1 freeze kullanılabilir.
//  - Freeze tüketildiğinde kaçırılan tarih kalıcı olarak kaydedilir
//    (UserDefaults). Bir daha aynı tarih için freeze yeniden tüketilmez —
//    streak tekrar hesaplanırken sadece doğrulama yapılır.
//  - Kullanıcı bugün entry yaparsa, dünü kaçırmış olsa bile freeze
//    devreye girip streak korunur.
//

import Foundation

struct StreakComputation {
    /// Effective streak count, including freeze-bridged days.
    let count: Int
    /// Dates that were bridged by a freeze in this computation
    /// (subset of the persisted set; useful for UI signaling).
    let frozenDates: Set<Date>
    /// Dates whose freeze was consumed during *this* call (vs already
    /// persisted from a prior computation). Empty unless a brand-new
    /// freeze just kicked in — perfect signal for one-shot toast UI.
    let newlyConsumedFreezes: Set<Date>
    /// Whether the user currently has a fresh freeze available.
    let freezeAvailable: Bool
    /// Most recently consumed freeze date, if any (for "freeze used" UI).
    let lastFreezeUsed: Date?
}

enum StreakEngine {
    /// Canonical milestone list shared across the app (scheduler, view model, UI).
    static let milestones: [Int] = [3, 7, 14, 30, 50, 100, 200, 365]

    private static let freezeUsedDatesKey = "streakFreezeUsedDates"
    /// Rolling window in days during which only 1 freeze may be active.
    private static let freezeWindowDays: Int = 7

    // MARK: - Public API

    /// Computes the soft streak for `today`, applying freeze bridging where
    /// appropriate. Mutates persisted freeze state when a new freeze is
    /// consumed (idempotent for already-bridged dates).
    ///
    /// - Parameters:
    ///   - filledDates: Dates (start-of-day) that have a real entry.
    ///   - today: The reference day (already start-of-day).
    ///   - includeToday: If true, today counts as filled even if not yet
    ///     in `filledDates` (e.g. immediately after save).
    static func compute(
        filledDates: Set<Date>,
        today: Date,
        includeToday: Bool
    ) -> StreakComputation {
        let calendar = Calendar.current
        let initialFreezes = loadUsedFreezes()
        var usedFreezes = initialFreezes
        var frozen: Set<Date> = []
        var lastFreeze: Date? = nil

        // Streak baseline.
        var streak = 0
        if includeToday || filledDates.contains(today) {
            streak = 1
        } else if usedFreezes.contains(today) {
            streak = 1
            frozen.insert(today)
            lastFreeze = today
        } else {
            // Today is not filled and not frozen → streak ends at 0.
            return StreakComputation(
                count: 0,
                frozenDates: [],
                newlyConsumedFreezes: [],
                freezeAvailable: !hasFreezeInRollingWindow(usedFreezes, anchoredAt: today, calendar: calendar),
                lastFreezeUsed: usedFreezes.max()
            )
        }

        // Walk back day-by-day. Cap at 400 to guard against pathological inputs or DST loops.
        var cursor = calendar.date(byAdding: .day, value: -1, to: today) ?? today
        var iterations = 0
        while iterations < 400 {
            iterations += 1
            if filledDates.contains(cursor) {
                streak += 1
            } else if usedFreezes.contains(cursor) {
                // Already bridged in a prior computation.
                streak += 1
                frozen.insert(cursor)
                lastFreeze = lastFreeze ?? cursor
            } else if canConsumeFreeze(at: cursor, usedFreezes: usedFreezes, calendar: calendar) {
                // Bridge this missing day with a freshly consumed freeze.
                usedFreezes.insert(cursor)
                frozen.insert(cursor)
                lastFreeze = lastFreeze ?? cursor
                streak += 1
            } else {
                break
            }
            guard let prev = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = prev
        }

        // Persist if we consumed a new freeze.
        let newlyConsumed = usedFreezes.subtracting(initialFreezes)
        if !newlyConsumed.isEmpty {
            saveUsedFreezes(usedFreezes)
        }

        let available = !hasFreezeInRollingWindow(usedFreezes, anchoredAt: today, calendar: calendar)
        return StreakComputation(
            count: streak,
            frozenDates: frozen,
            newlyConsumedFreezes: newlyConsumed,
            freezeAvailable: available,
            lastFreezeUsed: usedFreezes.max()
        )
    }

    /// Reports whether the user currently has a fresh freeze available
    /// (no consumption — pure read).
    static func isFreezeAvailable(today: Date = Date()) -> Bool {
        let calendar = Calendar.current
        let dayStart = calendar.startOfDay(for: today)
        let used = loadUsedFreezes()
        return !hasFreezeInRollingWindow(used, anchoredAt: dayStart, calendar: calendar)
    }

    // MARK: - Internal

    private static func canConsumeFreeze(
        at date: Date,
        usedFreezes: Set<Date>,
        calendar: Calendar
    ) -> Bool {
        // Disallow freezes for tomorrow / future.
        let today = calendar.startOfDay(for: Date())
        guard date <= today else { return false }
        // 7-day rolling window centered on the missed day.
        return !hasFreezeInRollingWindow(usedFreezes, anchoredAt: date, calendar: calendar)
    }

    private static func hasFreezeInRollingWindow(
        _ usedFreezes: Set<Date>,
        anchoredAt date: Date,
        calendar: Calendar
    ) -> Bool {
        let lower = calendar.date(byAdding: .day, value: -(freezeWindowDays - 1), to: date) ?? date
        let upper = calendar.date(byAdding: .day, value: (freezeWindowDays - 1), to: date) ?? date
        return usedFreezes.contains { $0 >= lower && $0 <= upper }
    }

    // MARK: - Persistence

    private static func loadUsedFreezes() -> Set<Date> {
        let defaults = UserDefaults.standard
        guard let raw = defaults.array(forKey: freezeUsedDatesKey) as? [Double] else { return [] }
        return Set(raw.map { Date(timeIntervalSince1970: $0) })
    }

    private static func saveUsedFreezes(_ dates: Set<Date>) {
        let raw = dates.map { $0.timeIntervalSince1970 }
        UserDefaults.standard.set(raw, forKey: freezeUsedDatesKey)
    }

    #if DEBUG
    /// Test/debug helper — resets persisted freeze state. Never call from production code.
    static func resetFreezesForTesting() {
        UserDefaults.standard.removeObject(forKey: freezeUsedDatesKey)
    }
    #endif
}
