//
//  ResurfaceViewData.swift
//  ONE 2.0
//
//  Geri dönüş kartı (07 §5.11): Bugün'de hafta şeridinin altında, günde en
//  fazla bir. Mono etiket, eski metnin ilk iki satırı, eylemler: `Tekrar yaz`
//  (karşılaştırma modu) · `Oku` · × (bugün için gizle).
//

import Foundation

nonisolated enum ResurfaceKind: Hashable, Sendable {
    /// Bir yıl önce bugün yazılan girdi ("BİR YIL ÖNCE BUGÜN").
    case yearAgo
    /// Karşılaştırma adayı soru, en az 30 gün önce cevaplandı ("30 GÜN ÖNCE").
    case questionAgain(daysAgo: Int)
    /// 90 günü dolmuş, yazılmış söz.
    case quoteReturn(daysAgo: Int)
}

nonisolated struct ResurfaceCardData: Identifiable, Equatable, Sendable {
    let id: String
    let kind: ResurfaceKind
    /// "Oku" → girdi detayı.
    let entryID: UUID
    let writtenAt: Date
    /// Eski metnin başı; kart iki satırda keser.
    let excerpt: String
    /// "Tekrar yaz" hedefi: soru ya da söz (karşılaştırma modu).
    let promptID: String?
    let quoteID: String?
}
