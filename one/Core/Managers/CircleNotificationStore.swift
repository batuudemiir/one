//
//  CircleNotificationStore.swift
//  one
//
//  Çevre bildirimlerini UserDefaults'a persist eden singleton store.
//  CloudKitNotificationService push aldığında buraya yazar;
//  CircleActivityView tek birleşik akışta buradan okur.
//

import Foundation
import Combine

@MainActor
final class CircleNotificationStore: ObservableObject {

    static let shared = CircleNotificationStore()

    // MARK: - Constants

    private let userDefaultsKey = "circleNotifications_v2"
    private let maxAgeDays: Double = 30

    // MARK: - Published State

    @Published private(set) var notifications: [CircleNotification] = []

    // MARK: - Init

    private init() { load() }

    // MARK: - Public API

    /// Yeni bir bildirim ekle. Aynı ID varsa ignore edilir.
    func add(_ notification: CircleNotification) {
        guard !notifications.contains(where: { $0.id == notification.id }) else { return }
        notifications.insert(notification, at: 0)
        prune()
        persist()
    }

    /// Belirli bir ID'ye sahip bildirimi güncelle (ör: arkadaş isteği kabul edildi).
    func update(id: String, transform: (inout CircleNotification) -> Void) {
        guard let index = notifications.firstIndex(where: { $0.id == id }) else { return }
        transform(&notifications[index])
        persist()
    }

    /// Belirli bir ID'ye sahip bildirimi kaldır.
    func remove(id: String) {
        guard notifications.contains(where: { $0.id == id }) else { return }
        notifications.removeAll { $0.id == id }
        persist()
    }

    /// Belirli bir requestRecordName'e sahip friendRequest/outgoingRequest bildirimini kaldır.
    func removeByRequestRecordName(_ recordName: String) {
        notifications.removeAll {
            $0.requestRecordName == recordName && ($0.type == .friendRequest || $0.type == .outgoingRequest)
        }
        persist()
    }

    /// "Bildirimler" sekmesi açıldığında tüm bildirimleri okundu işaretle.
    func markAllRead() {
        guard notifications.contains(where: { !$0.isRead }) else { return }
        notifications = notifications.map {
            var n = $0; n.isRead = true; return n
        }
        persist()
    }

    /// Okunmamış bildirim sayısı — CircleView badge'i için.
    var unreadCount: Int {
        notifications.filter { !$0.isRead }.count
    }

    // MARK: - Unified Feed

    /// Tek birleşik aktivite akışı — sıralama algoritması:
    /// 1. Okunmamış → okunmuş üstte
    /// 2. Aynı okunma durumunda tip önceliği (sortPriority)
    /// 3. Aynı tip ve okunma: kronolojik (yeni → eski)
    var unifiedFeed: [CircleNotification] {
        notifications.sorted { lhs, rhs in
            if lhs.isRead != rhs.isRead {
                return !lhs.isRead  // okunmamış üstte
            }
            if lhs.type.sortPriority != rhs.type.sortPriority {
                return lhs.type.sortPriority > rhs.type.sortPriority
            }
            return lhs.date > rhs.date
        }
    }

    /// Arkadaşlık isteği tipindeki bildirimler — inline aksiyon kartları için.
    var requestNotifications: [CircleNotification] {
        unifiedFeed.filter { $0.type == .friendRequest || $0.type == .outgoingRequest }
    }

    /// Arkadaşlık isteği olmayan bildirimler — aktivite akışı kartları için.
    var activityNotifications: [CircleNotification] {
        unifiedFeed.filter { $0.type != .friendRequest && $0.type != .outgoingRequest }
    }

    // MARK: - Persistence

    private func persist() {
        guard let data = try? JSONEncoder().encode(notifications) else { return }
        UserDefaults.standard.set(data, forKey: userDefaultsKey)
    }

    private func load() {
        // v1'den migration: eski key'den oku, yeni key'e yaz
        let v1Key = "circleNotifications_v1"
        if let v1Data = UserDefaults.standard.data(forKey: v1Key),
           let v1Decoded = try? JSONDecoder().decode([CircleNotification].self, from: v1Data) {
            notifications = v1Decoded
            persist()
            UserDefaults.standard.removeObject(forKey: v1Key)
            return
        }
        guard
            let data = UserDefaults.standard.data(forKey: userDefaultsKey),
            let decoded = try? JSONDecoder().decode([CircleNotification].self, from: data)
        else { return }
        notifications = decoded
    }

    private func prune() {
        let cutoff = Date().addingTimeInterval(-maxAgeDays * 86400)
        notifications = notifications.filter { $0.date > cutoff }
    }
}
