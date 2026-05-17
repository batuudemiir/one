//
//  NotificationDebugView.swift
//  one
//
//  Debug-only bildirim paneli. Profile → Geliştirici → "Bildirim Paneli"
//  üzerinden açılır. Pending / delivered listesi, test bildirimi gönderimi,
//  son 7 gün analytics özeti.
//

import SwiftUI
import UserNotifications

#if DEBUG
struct NotificationDebugView: View {
    @State private var pending: [UNNotificationRequest] = []
    @State private var delivered: [UNNotification] = []
    @State private var analytics: [(kind: String, opened: Int, delivered: Int)] = []

    var body: some View {
        List {
            Section("Test") {
                Button("Test bildirimi gönder (5s)") { sendTestNotification() }
                Button("Tüm pending'leri iptal et", role: .destructive) {
                    UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
                    refresh()
                }
                Button("Analytics log'unu temizle", role: .destructive) {
                    NotificationAnalytics.clear()
                    refresh()
                }
            }

            Section("Analytics (son 7 gün)") {
                if analytics.isEmpty {
                    Text("Kayıt yok").foregroundStyle(.secondary)
                }
                ForEach(analytics, id: \.kind) { row in
                    HStack {
                        Text(row.kind).font(.caption)
                        Spacer()
                        Text("\(row.opened) / \(row.delivered)")
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Section("Pending (\(pending.count))") {
                if pending.isEmpty {
                    Text("Bekleyen bildirim yok").foregroundStyle(.secondary)
                }
                ForEach(pending, id: \.identifier) { req in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(req.identifier).font(.caption.bold())
                        Text(req.content.title).font(.caption2)
                        if let fire = nextFire(req) {
                            Text(fire, style: .relative)
                                .font(.caption2.monospaced())
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            Section("Delivered (\(delivered.count))") {
                if delivered.isEmpty {
                    Text("Teslim edilmiş bildirim yok").foregroundStyle(.secondary)
                }
                ForEach(delivered, id: \.request.identifier) { n in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(n.request.identifier).font(.caption.bold())
                        Text(n.request.content.title).font(.caption2)
                    }
                }
            }
        }
        .navigationTitle("Bildirim Paneli")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { refresh() }
        .refreshable { refresh() }
    }

    private func refresh() {
        UNUserNotificationCenter.current().getPendingNotificationRequests { reqs in
            DispatchQueue.main.async {
                pending = reqs.sorted { a, b in
                    (nextFire(a) ?? .distantFuture) < (nextFire(b) ?? .distantFuture)
                }
            }
        }
        UNUserNotificationCenter.current().getDeliveredNotifications { ns in
            DispatchQueue.main.async {
                delivered = ns.sorted { $0.date > $1.date }
            }
        }
        let stats = NotificationAnalytics.openRateByKind(days: 7)
        analytics = stats.map { (kind: $0.key, opened: $0.value.opened, delivered: $0.value.delivered) }
            .sorted { $0.kind < $1.kind }
    }

    private func sendTestNotification() {
        let content = UNMutableNotificationContent()
        content.title = "Test bildirimi"
        content.body  = "Orchestrator test — 5 saniye sonra geldim."
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false)
        _ = NotificationOrchestrator.shared.schedule(
            kind: .dailyReminder,
            identifier: "debug_test_\(Int(Date().timeIntervalSince1970))",
            trigger: trigger,
            content: content,
            decisionOverride: .allow
        )
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { refresh() }
    }

    private func nextFire(_ req: UNNotificationRequest) -> Date? {
        if let c = req.trigger as? UNCalendarNotificationTrigger { return c.nextTriggerDate() }
        if let t = req.trigger as? UNTimeIntervalNotificationTrigger { return t.nextTriggerDate() }
        return nil
    }
}
#endif
