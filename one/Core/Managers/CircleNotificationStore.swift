//
//  CircleNotificationStore.swift
//  one
//
//  Çevre bildirimlerini UserDefaults'a persist eden singleton store.
//  CloudKitNotificationService push aldığında buraya yazar;
//  FriendRequestsView "Bildirimler" sekmesinde buradan okur.
//

import Foundation
import Combine

@MainActor
final class CircleNotificationStore: ObservableObject {

    static let shared = CircleNotificationStore()

    // MARK: - Constants

    private let userDefaultsKey = "circleNotifications_v1"
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

    /// FriendRequestsView'de gösterilecek bildirimler.
    /// .friendRequest tipini hariç tutar; bunlar live CloudKit'ten çekiliyor.
    var displayable: [CircleNotification] {
        notifications.filter { $0.type != .friendRequest }
    }

    // MARK: - Persistence

    private func persist() {
        guard let data = try? JSONEncoder().encode(notifications) else { return }
        UserDefaults.standard.set(data, forKey: userDefaultsKey)
    }

    private func load() {
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
