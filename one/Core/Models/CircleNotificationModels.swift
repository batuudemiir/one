//
//  CircleNotificationModels.swift
//  one
//
//  Çevre bildirimleri için veri modeli — arkadaşlık, paylaşım, yorum, rezonans
//

import Foundation

// MARK: - Type

enum CircleNotificationType: String, Codable {
    case friendRequest   = "friendRequest"
    case friendAccepted  = "friendAccepted"
    case friendShare     = "friendShare"
    case emojiReaction   = "emojiReaction"    // v2.5'te deprecated — legacy kayıtlar için tutuluyor
    case comment         = "comment"           // v2.5 — yorum
    case moodResonance   = "moodResonance"     // v2.7 — çevre yankısı (aynı mood renk)
    case resonance       = "resonance"         // v2.7 — rezonans gönderildi
    case outgoingRequest = "outgoingRequest"   // v2.7 — giden arkadaşlık isteği
}

// MARK: - Sort Priority

extension CircleNotificationType {
    /// Aktivite akışında sıralama önceliği — yüksek değer = üstte
    var sortPriority: Int {
        switch self {
        case .friendRequest:   return 100
        case .friendAccepted:  return 90
        case .comment:         return 80
        case .resonance:       return 70
        case .moodResonance:   return 60
        case .friendShare:     return 50
        case .emojiReaction:   return 40
        case .outgoingRequest: return 30
        }
    }
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
    let moodColorHex: String?
    let shareRecordName: String?
    let requestRecordName: String?
    let requestStatus: String?

    init(
        id: String,
        type: CircleNotificationType,
        title: String,
        body: String,
        date: Date = Date(),
        isRead: Bool = false,
        relatedUserID: String? = nil,
        emoji: String? = nil,
        moodColorHex: String? = nil,
        shareRecordName: String? = nil,
        requestRecordName: String? = nil,
        requestStatus: String? = nil
    ) {
        self.id = id
        self.type = type
        self.title = title
        self.body = body
        self.date = date
        self.isRead = isRead
        self.relatedUserID = relatedUserID
        self.emoji = emoji
        self.moodColorHex = moodColorHex
        self.shareRecordName = shareRecordName
        self.requestRecordName = requestRecordName
        self.requestStatus = requestStatus
    }
}
