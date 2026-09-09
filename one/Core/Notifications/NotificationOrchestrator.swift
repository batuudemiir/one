//
//  NotificationOrchestrator.swift
//  one
//
//  Merkezi bildirim politika motoru. `UNUserNotificationCenter`'a tek geçit.
//  Tüm schedule/cancel çağrıları buradan geçer; quiet hours, daily cap,
//  weekly proactive cap, dedup ve iOS 64 pending limiti uygulanır.
//
//  NotificationManager artık bu sınıfın üzerinde ince bir shim.
//

import Foundation
import UserNotifications
import UIKit

extension UserDefaults {
    /// Bildirim ana anahtarı. **Yazılmamışsa açık kabul edilir.**
    ///
    /// Eskiden her okuma `bool(forKey:)` idi; hiç dokunulmamış ayar için
    /// `false` dönüyordu, yani kullanıcı hiçbir zaman kapatmadığı halde
    /// Orchestrator her kind'ı "master off" ile düşürüyordu. Komşu ayarlar
    /// (`weeklySummaryEnabled`) zaten
    /// `object(...) == nil ? true` ile açık geliyordu — bu onlarla hizalıyor.
    ///
    /// Açıkça `false` yazılmış olan (kullanıcının kapattığı) durum korunur.
    var oneNotificationsEnabled: Bool {
        object(forKey: "notificationsEnabled") as? Bool ?? true
    }
}

final class NotificationOrchestrator: NSObject {

    static let shared = NotificationOrchestrator()

    // MARK: - Settings (AppStorage-compatible keys)

    private enum Key {
        static let quietHoursEnabled          = "quietHoursEnabled"
        static let quietHoursStart            = "quietHoursStart"
        static let quietHoursEnd              = "quietHoursEnd"
        static let dailyNotificationCap       = "dailyNotificationCap"
        static let weeklyProactiveCap         = "weeklyProactiveCap"
        static let notificationsSentToday     = "notificationsSentToday"
        static let proactiveSentThisWeek      = "proactiveSentThisWeek"
        static let dedupDayKey                = "notificationDedupDayKey"
        static let dedupWeekKey               = "notificationDedupWeekKey"
        static let milestonesCelebrated       = "milestonesCelebrated"
    }

    private let center = UNUserNotificationCenter.current()
    private var defaults: UserDefaults { UserDefaults(suiteName: "group.com.batudemir.ones") ?? .standard }

    // Max iOS pending limit is 64. Leave headroom for urgent schedules.
    private let pendingSoftLimit = 56

    private override init() {
        super.init()
    }

    // MARK: - Boot

    /// oneApp onAppear'dan çağrılır. Mevcut davranışı bozmayacak şekilde
    /// shim'lenmiş NotificationManager fonksiyonlarını sarar.
    func bootOnLaunch() {
        rollDailyWindowIfNeeded()
        rollWeeklyWindowIfNeeded()
        purgeRetiredSchedules()
        SundayReflectionScheduler.rescheduleAll()
        MonthlyPortraitScheduler.rescheduleAll()
    }

    /// v4 — kaldırılan serilerin cihazda **zaten kurulmuş** istekleri.
    /// Kod silinince pending istekler silinmez: `echo_ready_saturday`,
    /// `weekly_summary` ve `daily_reminder` tekrarlayan trigger'la kuruluydu,
    /// win-back/nurture ise 30 güne kadar ileri tarihliydi. Güncelleyen
    /// kullanıcı aksi halde v3 metnini almaya devam ederdi — ve `repeats:
    /// true` olanlarda süresiz. Her boot'ta çalışır — idempotent ve ucuz.
    private static let retiredIdentifiers = [
        "winback_3d", "winback_7d", "winback_14d", "winback_30d",
        "nurture_d1", "nurture_d2", "nurture_d3", "nurture_d4_circle",
        "echo_ready_saturday",   // Cumartesi 10:00 — Pazar yansımasıyla çakışıyordu
        "weekly_summary",        // Pazar 18:00 — ikinci haftalık motor
        "monthEndSummary",       // ayın son günü 20:00 — ikinci aylık motor
        "daily_reminder"         // orchestrator'ın kendi tekrarlayan isteği
    ]

    private func purgeRetiredSchedules() {
        center.removePendingNotificationRequests(
            withIdentifiers: Self.retiredIdentifiers
        )
    }

    // MARK: - Public: Quiet Hours

    var quietHours: QuietHours {
        let enabled = defaults.object(forKey: Key.quietHoursEnabled) as? Bool ?? true
        guard enabled else { return QuietHours(start: 0, end: 0) }
        // v4 sessiz saatler 22–09. Fallback tek kaynaktan (QuietHours.default)
        // okunur; burada tekrar yazılan sayı politika değişince sessizce
        // eskiyordu.
        let start = defaults.object(forKey: Key.quietHoursStart) as? Int ?? QuietHours.default.start
        let end   = defaults.object(forKey: Key.quietHoursEnd)   as? Int ?? QuietHours.default.end
        return QuietHours(start: start, end: end)
    }

    var dailyCap: Int {
        let v = defaults.integer(forKey: Key.dailyNotificationCap)
        return v == 0 ? 1 : v
    }

    var weeklyProactiveCap: Int {
        // v4: uygulamanın kendi inisiyatifiyle konuşma bütçesi haftada 2.
        // Günlük ritüel kullanıcının açıkça istediği bir şey olduğu için
        // bu bütçeye dahil değildir (bkz. decide()).
        let v = defaults.integer(forKey: Key.weeklyProactiveCap)
        return v == 0 ? 2 : v
    }

    // MARK: - Decision

    /// Bir kind için scheduled fireDate göz önünde bulundurularak karar ver.
    func decide(for kind: NotificationKind, at fireDate: Date) -> ScheduleDecision {
        guard defaults.oneNotificationsEnabled else {
            return .drop(reason: "master off")
        }

        rollDailyWindowIfNeeded()
        rollWeeklyWindowIfNeeded()

        // Dedup — aynı kind bugün schedule/gönderilmiş. Reactive sosyal
        // event'ler (friend_shared, friend_reaction, friend_request,
        // mood_resonance, circle_activity) dedup'tan muaf; gün içinde
        // birden fazla arkadaştan bildirim gelebilmeli.
        let sentToday = Set(defaults.stringArray(forKey: Key.notificationsSentToday) ?? [])
        let dedupable: Bool = {
            switch kind {
            case .friendShared, .friendReaction, .friendRequest,
                 .friendAccepted, .moodResonance, .circleActivity,
                 .commentReceived, .commentReply, .commentMention, .commentBatch:
                return false
            default:
                return true
            }
        }()
        if dedupable && sentToday.contains(kind.rawValue) {
            return .drop(reason: "dedup")
        }

        // Daily cap — critical ve reactive sosyal event'ler bypass eder;
        // proactive/low-priority kind'lar cap'e tabidir.
        let capExempt = kind.priority >= .high || !dedupable
        if !capExempt && sentToday.count >= dailyCap {
            return .drop(reason: "daily cap")
        }

        // Weekly proactive cap. Günlük ritüel kullanıcının kendi kurduğu
        // bir randevu — bütçeden düşmez.
        if kind.isProactive && kind != .dailyReminder {
            let sentWeek = defaults.integer(forKey: Key.proactiveSentThisWeek)
            if sentWeek >= weeklyProactiveCap {
                return .drop(reason: "weekly cap")
            }
        }

        // Quiet hours — critical bypass, aksi halde aktif pencereye ertele.
        if kind.priority < .critical && quietHours.contains(fireDate) {
            return .deferTo(quietHours.nextActiveWindow(after: fireDate))
        }

        return .allow
    }

    // MARK: - Schedule / Cancel

    /// `decide()` sonucunu uygula ve UNNotificationRequest ekle.
    /// `trigger == nil` ise immediate bildirim.
    @discardableResult
    func schedule(
        kind: NotificationKind,
        identifier: String,
        trigger: UNNotificationTrigger?,
        content: UNMutableNotificationContent,
        variant: Int? = nil,
        decisionOverride: ScheduleDecision? = nil
    ) -> ScheduleDecision {
        let fireDate = Self.fireDate(for: trigger) ?? Date()
        let decision = decisionOverride ?? decide(for: kind, at: fireDate)

        switch decision {
        case .allow:
            annotate(content: content, kind: kind, variant: variant)
            let finalTrigger = trigger
            let request = UNNotificationRequest(identifier: identifier, content: content, trigger: finalTrigger)
            enforcePendingLimit { [weak self] in
                self?.center.add(request) { err in
                    if let err {
                        ONELogger.error("Orchestrator schedule failed",
                                        error: err, category: .notification)
                        return
                    }
                    self?.markSent(kind: kind)
                    NotificationAnalytics.record(
                        kind: kind, identifier: identifier,
                        type: .scheduled, variant: variant
                    )
                }
            }

        case .deferTo(let newDate):
            let deferred = Self.calendarTrigger(for: newDate)
            ONELogger.info(
                "Orchestrator deferred \(kind.rawValue) to \(newDate)",
                category: .notification
            )
            NotificationAnalytics.record(
                kind: kind, identifier: identifier,
                type: .deferred, variant: variant,
                reason: "quiet hours"
            )
            annotate(content: content, kind: kind, variant: variant)
            let request = UNNotificationRequest(identifier: identifier, content: content, trigger: deferred)
            enforcePendingLimit { [weak self] in
                self?.center.add(request) { _ in
                    self?.markSent(kind: kind)
                }
            }

        case .drop(let reason):
            let sentCount = defaults.stringArray(forKey: Key.notificationsSentToday)?.count ?? 0
            ONELogger.info(
                "Orchestrator dropped \(kind.rawValue): \(reason) (sentToday=\(sentCount), cap=\(dailyCap))",
                category: .notification
            )
            NotificationAnalytics.record(
                kind: kind, identifier: identifier,
                type: .dropped, variant: variant, reason: reason
            )
        }

        return decision
    }

    func cancel(identifiers: [String]) {
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
    }

    func cancelAll() {
        center.removeAllPendingNotificationRequests()
    }

    // MARK: - Event hooks

    /// Uygulama foreground olduğunda çağrılır.
    func onAppOpened() {
        EngagementTracker.markOpened()
    }

    /// Kullanıcı mood kaydettiğinde çağrılır.
    ///
    /// v4: burada **yeniden planlama yok.** Günlük ritüelin tek sahibi
    /// `V3ReminderScheduler` (kullanıcının seçtiği saat, gün ve ton).
    /// Orchestrator burada kendi tekrarlayan `daily_reminder`'ını kuruyordu;
    /// V3 katmanı onu birkaç satır sonra zaten siliyordu, ama silinmeden önce
    /// `markSent` sayaçları artıyordu — hiç teslim edilmemiş bir bildirim
    /// günlük tavanı doldurup gerçek olayları düşürüyordu (v4'te tavan 1).
    /// Kalan tek iş, eski sürümlerden kalmış olabilecek isteği temizlemek.
    func onSongSaved(moodLabel: String?, moodColorHex: String?) {
        EngagementTracker.markMoodSaved(label: moodLabel, colorHex: moodColorHex)
        cancel(identifiers: ["daily_reminder"])
    }

    /// Midnight reset hook. notificationsSentToday boşaltılır (zaten gün
    /// değişimi zaten `rollDailyWindowIfNeeded` ile yakalar ama explicit
    /// senkronu garantiler).
    func onMidnight() {
        rollDailyWindowIfNeeded(force: true)
    }

    // MARK: - Akıllı Bildirim Saati (v4'te kaldırıldı)
    //
    // Kullanıcının açılış medyanına bakıp hatırlatma saatini kendi başına
    // kaydıran katman kaldırıldı. İki gerekçe:
    //  · v4 ekseni — günlük ritüel kullanıcının kendisiyle kurduğu randevu.
    //    Randevunun saatini uygulamanın sessizce değiştirmesi, "uygulama bir
    //    şey istemez" kuralının en görünmez ihlaliydi.
    //  · Zaten ölü koddu: yazdığı `dailyReminderHour` anahtarını gerçek
    //    planlayıcı (`V3ReminderScheduler`, `v3ReminderMinutes`) okumuyordu;
    //    kurduğu istek de birkaç satır sonra siliniyordu.
    // Saat ayarı ekranda duruyor ve yalnız kullanıcı değiştiriyor.

    // MARK: - Windowing

    private func rollDailyWindowIfNeeded(force: Bool = false) {
        let key = Self.dayKey()
        let stored = defaults.string(forKey: Key.dedupDayKey)
        if force || stored != key {
            defaults.set(key, forKey: Key.dedupDayKey)
            defaults.removeObject(forKey: Key.notificationsSentToday)
        }
    }

    private func rollWeeklyWindowIfNeeded() {
        let key = Self.weekKey()
        let stored = defaults.string(forKey: Key.dedupWeekKey)
        if stored != key {
            defaults.set(key, forKey: Key.dedupWeekKey)
            defaults.set(0, forKey: Key.proactiveSentThisWeek)
        }
    }

    private func markSent(kind: NotificationKind) {
        var sent = defaults.stringArray(forKey: Key.notificationsSentToday) ?? []
        if !sent.contains(kind.rawValue) { sent.append(kind.rawValue) }
        defaults.set(sent, forKey: Key.notificationsSentToday)
        if kind.isProactive {
            let cur = defaults.integer(forKey: Key.proactiveSentThisWeek)
            defaults.set(cur + 1, forKey: Key.proactiveSentThisWeek)
        }
    }

    private func annotate(
        content: UNMutableNotificationContent,
        kind: NotificationKind,
        variant: Int?
    ) {
        if !kind.categoryIdentifier.isEmpty {
            content.categoryIdentifier = kind.categoryIdentifier
        }
        var info = content.userInfo
        info["kind"] = kind.rawValue
        if let variant { info["variant"] = variant }
        info["scheduledAt"] = ISO8601DateFormatter().string(from: Date())
        content.userInfo = info
    }

    // MARK: - Pending limit enforcement

    private func enforcePendingLimit(then addRequest: @escaping () -> Void) {
        center.getPendingNotificationRequests { [weak self] requests in
            guard let self else { addRequest(); return }
            if requests.count < self.pendingSoftLimit {
                addRequest()
                return
            }

            // En düşük priority + en uzak fireDate olanı at.
            let victim = requests.min { a, b in
                let pa = Self.inferKind(from: a)?.priority.rawValue ?? 0
                let pb = Self.inferKind(from: b)?.priority.rawValue ?? 0
                if pa != pb { return pa < pb }
                let fa = Self.fireDate(for: a.trigger) ?? .distantFuture
                let fb = Self.fireDate(for: b.trigger) ?? .distantFuture
                return fa > fb
            }
            if let id = victim?.identifier {
                self.center.removePendingNotificationRequests(withIdentifiers: [id])
                ONELogger.warning(
                    "Pending limit hit — dropping \(id)",
                    category: .notification
                )
            }
            addRequest()
        }
    }

    // MARK: - Helpers

    private static func dayKey(_ date: Date = Date()) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: date)
    }

    private static func weekKey(_ date: Date = Date()) -> String {
        let cal = Calendar(identifier: .iso8601)
        let comps = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        return "\(comps.yearForWeekOfYear ?? 0)-W\(comps.weekOfYear ?? 0)"
    }

    private static func fireDate(for trigger: UNNotificationTrigger?) -> Date? {
        if let c = trigger as? UNCalendarNotificationTrigger {
            return c.nextTriggerDate()
        }
        if let t = trigger as? UNTimeIntervalNotificationTrigger {
            return t.nextTriggerDate()
        }
        return nil
    }

    private static func calendarTrigger(for date: Date) -> UNCalendarNotificationTrigger {
        let comps = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute], from: date
        )
        return UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
    }

    private static func inferKind(from request: UNNotificationRequest) -> NotificationKind? {
        if let raw = request.content.userInfo["kind"] as? String,
           let kind = NotificationKind(rawValue: raw) {
            return kind
        }
        return nil
    }
}

// MARK: - Delivery/Open tracking
// Hook edilir: NotificationManager.UNUserNotificationCenterDelegate
// implementasyonu Orchestrator'a forward eder.
extension NotificationOrchestrator {
    func recordDelivered(_ notification: UNNotification) {
        guard let kind = Self.inferKind(from: notification.request) else { return }
        NotificationAnalytics.record(
            kind: kind,
            identifier: notification.request.identifier,
            type: .delivered,
            variant: notification.request.content.userInfo["variant"] as? Int
        )
    }

    func recordOpened(_ response: UNNotificationResponse) {
        guard let kind = Self.inferKind(from: response.notification.request) else { return }
        let type: NotificationAnalyticsEventType =
            (response.actionIdentifier == UNNotificationDismissActionIdentifier)
            ? .dismissed
            : .opened
        NotificationAnalytics.record(
            kind: kind,
            identifier: response.notification.request.identifier,
            type: type,
            variant: response.notification.request.content.userInfo["variant"] as? Int
        )
    }

}
