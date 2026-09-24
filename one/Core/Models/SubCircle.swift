//
//  SubCircle.swift
//  one
//
//  Alt-çevre: kullanıcının arkadaşlarını isimli gruplara ayırması
//  ("Yakınlar", "İş", "Müzik"). Tek sahipli, özel; yalnız sahibi görür ve
//  düzenler. Üyeler mevcut arkadaşlardan seçilir — rastgele kişi yok.
//
//  Üyelik ayrı kayıt değil, `memberIDs` listesinde tutulur (bu ölçekte en
//  basit; friendIDs de benzer şekilde saklanıyor). Çevre filtreleme
//  tamamen istemci tarafında — yeni CloudKit sorgusu gerektirmez.
//

import Foundation
import CloudKit

struct SubCircle: Identifiable, Equatable {
    /// CloudKit recordName.
    let id: String
    /// Grubu oluşturan kullanıcı — tek sahip.
    let ownerID: String
    var name: String
    /// Çip/başlık rengi (hex). Mood renklerinden biri.
    var colorHex: String
    /// İsteğe bağlı tek emoji (başlıkta gösterilir).
    var emoji: String
    /// Gruptaki arkadaşların userID'leri.
    var memberIDs: [String]
    let createdAt: Date

    static let recordType     = "SubCircle"
    static let maxNameLength  = 24
    static let maxMembers     = 100

    init(
        id: String,
        ownerID: String,
        name: String,
        colorHex: String,
        emoji: String,
        memberIDs: [String],
        createdAt: Date
    ) {
        self.id         = id
        self.ownerID    = ownerID
        self.name       = name
        self.colorHex   = colorHex
        self.emoji      = emoji
        self.memberIDs  = memberIDs
        self.createdAt  = createdAt
    }

    /// CloudKit kaydından çözer. `ownerID` + `name` zorunlu; diğerleri
    /// makul varsayılanlarla düşer (şema kısmen eskiyse kırılmaz).
    init?(record: CKRecord) {
        guard let ownerID = record["ownerID"] as? String,
              let name    = record["name"]    as? String
        else { return nil }
        self.id         = record.recordID.recordName
        self.ownerID    = ownerID
        self.name       = name
        self.colorHex   = record["colorHex"]  as? String   ?? "#5B8DEF"
        self.emoji      = record["emoji"]     as? String   ?? ""
        self.memberIDs  = record["memberIDs"] as? [String]  ?? []
        self.createdAt  = record["createdAt"] as? Date ?? record.creationDate ?? Date()
    }

    /// Bir arkadaş bu gruba dahil mi?
    func contains(_ userID: String) -> Bool { memberIDs.contains(userID) }
}
