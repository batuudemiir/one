//
//  CircleNotificationModels.swift
//  one
//
//  Çevre bildirimleri için veri modeli — arkadaşlık kabul, paylaşım, emoji reaksiyonu
//

import Foundation

// MARK: - Type

enum CircleNotificationType: String, Codable {
    case friendRequest   = "friendRequest"
    case friendAccepted  = "friendAccepted"
    case friendShare     = "friendShare"
    case emojiReaction   = "emojiReaction"
}

// MARK: - Model

struct CircleNotification: Codable, Identifiable {
    /// Deterministic ID — aynı push iki kez işlenirse duplike oluşmaz
    let id: String
    let type: CircleNotificationType
    let title: String
    let body: String
    let date: Date
    var isRead: Bool
    let relatedUserID: String?
    let emoji: String?
}
