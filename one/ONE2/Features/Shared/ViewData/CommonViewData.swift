//
//  CommonViewData.swift
//  ONE 2.0
//
//  Ekranların ortak düz tipleri. View data motor tiplerini içermez
//  (05_ux_promptlari.md, Veri sözleşmesi); motor → view data eşlemesi
//  UX-11'de `Features/Shared/Adapters/` altında yazılır.
//

import Foundation

/// Ritüel yuvası (E8: `daily` ya da `morningEvening`).
nonisolated enum RitualSlot: String, Hashable, Sendable {
    case daily, morning, evening
}

/// Duygu kataloğu öğesi. `id` kalıcı: `<aile>.<ad>` ("nese.minnettar").
nonisolated struct EmotionItem: Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let family: ONE2EmotionFamily
}

/// Yüklenen her ekran verisinin üç hâli (README Durumlar).
nonisolated enum Loadable<Value: Sendable & Equatable>: Equatable, Sendable {
    case loading
    case loaded(Value)
    case failed(message: String)
}
