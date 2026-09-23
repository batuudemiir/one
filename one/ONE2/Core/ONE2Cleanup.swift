//
//  ONE2Cleanup.swift
//  ONE 2.0
//
//  ONE 2.0 açılışında v3'ten kalan yüzeyleri kapatır (MIGRATION.md §6,
//  ADR-001 §3). Her açılışta çalışır; idempotent ve ucuz.
//
//  İki sınıf iş var:
//  - Geri alınabilir: bekleyen/teslim edilmiş v3 bildirimleri, bildirim
//    kategorileri, v3 arka plan görevi, widget'ın v3 anahtarları. Bayrak
//    kapatılırsa v3 bunları kendi açılışında yeniden kurar.
//  - Geri alınamaz: Spotify token'ları. Yalnız relaunch sürümünde
//    (`irreversibleEnabled`). CloudKit abonelik temizliği Çevre koduna bağlı
//    olduğu için ONE2 dışında, relaunch geçiş sürümünde yapılacak (ADR §10).
//

import Foundation
import UserNotifications
import BackgroundTasks
import WidgetKit
import Security

enum ONE2Cleanup {

    /// Relaunch sürümünde `true` olur. TestFlight döneminde yalnız geri
    /// alınabilir temizlik yapılır.
    static let irreversibleEnabled = false

    // MARK: - Kimlikler (v3 kaynaklarından; kopyalandı, çünkü ONE2 v3 tiplerine dokunmaz)

    /// Sabit kimlikli v3 istekleri: haftalık ve aylık portre, uygulama
    /// güncellemesi hariç (o ONE 2.0'da da var), ve bildirim motorunun zaten
    /// emekli ettiği eski seriler.
    static let retiredPendingIDs: Set<String> = [
        "sunday_reflection_1", "sunday_reflection_2",
        "monthly_portrait_1", "monthly_portrait_2",
        "winback_3d", "winback_7d", "winback_14d", "winback_30d",
        "nurture_d1", "nurture_d2", "nurture_d3", "nurture_d4_circle",
        "echo_ready_saturday", "weekly_summary", "monthEndSummary", "daily_reminder"
    ]

    /// v3 günlük hatırlatması tarih ekli kimlikler kuruyor.
    static let retiredPendingPrefixes = ["v3_daily_reminder_"]

    /// v3 bildirim kategorileri; teslim edilmiş olanları bildirim merkezinden kaldırılır.
    static let retiredCategories: Set<String> = [
        "FRIEND_REQUEST", "WEEKLY_SUMMARY", "FRIEND_SHARED", "MOOD_RESONANCE"
    ]

    static let v3BackgroundTaskID = "com.batu.ones.midnightReset"
    static let spotifyKeychainService = "com.batu.ones.spotify"

    /// Bekleyen kimliklerden silinecek olanlar.
    static func pendingToRemove(_ identifiers: [String]) -> [String] {
        identifiers.filter { id in
            retiredPendingIDs.contains(id) || retiredPendingPrefixes.contains { id.hasPrefix($0) }
        }
    }

    // MARK: - Çalıştır

    static func run(center: UNUserNotificationCenter = .current()) async {
        let pending = await center.pendingNotificationRequests().map(\.identifier)
        let stale = pendingToRemove(pending)
        if !stale.isEmpty {
            center.removePendingNotificationRequests(withIdentifiers: stale)
        }

        let delivered = await center.deliveredNotifications()
            .filter { retiredCategories.contains($0.request.content.categoryIdentifier) }
            .map(\.request.identifier)
        if !delivered.isEmpty {
            center.removeDeliveredNotifications(withIdentifiers: delivered)
        }

        // v3 kategorileri (arkadaş isteği eylemleri vb.) ONE 2.0'da yok.
        center.setNotificationCategories([])

        BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: v3BackgroundTaskID)

        // Widget `ones://today` ile açılmaya devam eder; v3 verisi gösterilmez.
        WidgetDataWriter.clear()
        WidgetCenter.shared.reloadAllTimelines()

        if irreversibleEnabled {
            deleteSpotifyTokens()
        }
    }

    private static func deleteSpotifyTokens() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: spotifyKeychainService
        ]
        SecItemDelete(query as CFDictionary)
    }
}
