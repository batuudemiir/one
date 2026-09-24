//
//  DailyReaction.swift
//  one
//
//  Prototipin "sessiz cevaplaşma"sı: bir arkadaşın bugününe gönderilen
//  efemer karşılık. Kalıcı `Comment`'in tersine — gün bitince kaybolur,
//  sayaç yok, yalnız paylaşım sahibi görür.
//
//  Kanıtlı `EmojiReaction` kayıt tipinin üstüne kuruluyor; yeni alanlar
//  (text, toUserID, kind, colorHex) additive — CloudKit'te deploy edilince
//  eski emoji reaksiyonları da okunmaya devam eder.
//

import Foundation
import CloudKit

struct DailyReaction: Identifiable {
    /// Karşılığın türü. Prototipteki üç hazır tepki + kendi rengini gönder +
    /// tek satır yanıt.
    enum Kind: String {
        case yanindayim   // ◍ yanındayım
        case bende        // ◎ ben de öyleyim
        case iyiki        // ◠ iyi ki
        case color        // kendi rengini gönder
        case reply        // tek satır yanıt

        /// Prototipteki glif.
        var glyph: String {
            switch self {
            case .yanindayim: return "\u{25CD}"   // ◍
            case .bende:      return "\u{25CE}"   // ◎
            case .iyiki:      return "\u{25E0}"   // ◠
            case .color:      return "+"
            case .reply:      return ""
            }
        }

        /// Prototipteki Türkçe etiket.
        var label: String {
            switch self {
            case .yanindayim: return "yanındayım"
            case .bende:      return "ben de öyleyim"
            case .iyiki:      return "iyi ki"
            case .color:      return "rengini gönder"
            case .reply:      return ""
            }
        }
    }

    let id: String
    let shareRecordName: String
    /// Paylaşımın sahibi — karşılığı yalnız o görür.
    let shareOwnerID: String
    let senderUserID: String
    /// Yanıt hedefi (thread). Karşı tarafa geri yazarken dolu; sahibe
    /// gelen ilk karşılıkta nil.
    let toUserID: String?
    let kind: Kind
    /// `.reply` için tek satır gövde (≤120).
    let text: String?
    /// `.color` için gönderilen renk.
    let colorHex: String?
    let createdAt: Date

    // Join ile doldurulan gönderen bilgisi.
    var senderName: String?
    var senderColorHex: String?

    static let maxReplyLength = 120
    static let recordType = "EmojiReaction"

    /// Son 24 saat içinde mi? Efemerlik istemci tarafında bununla uygulanıyor.
    /// Prototip spec'i "24 saat sonra kaybolur" — takvim günü değil sürüş
    /// penceresi; 23:59'da gelen tepki ertesi gün 23:58'e kadar görünür.
    var isFresh: Bool {
        createdAt.addingTimeInterval(86_400) > Date()
    }
}

extension DailyReaction {
    /// CloudKit kaydından modele. Eski (yalnız emoji) kayıtlar da okunur:
    /// `kind` yoksa emoji'den çıkarılır, yoksa `.color` sayılır.
    init?(record: CKRecord) {
        guard let shareRecordName = record["shareRecordName"] as? String,
              let senderUserID = record["senderUserID"] as? String else { return nil }

        self.id = record.recordID.recordName
        self.shareRecordName = shareRecordName
        self.shareOwnerID = record["shareOwnerID"] as? String ?? ""
        self.senderUserID = senderUserID
        self.toUserID = record["toUserID"] as? String
        self.text = record["text"] as? String
        self.colorHex = record["colorHex"] as? String
        self.createdAt = record["date"] as? Date ?? record.creationDate ?? Date()

        if let raw = record["kind"] as? String, let k = Kind(rawValue: raw) {
            self.kind = k
        } else if record["text"] as? String != nil {
            self.kind = .reply
        } else {
            self.kind = .color   // eski emoji kayıtları renk/emoji karşılığı sayılır
        }

        self.senderName = nil
        self.senderColorHex = nil
    }
}
