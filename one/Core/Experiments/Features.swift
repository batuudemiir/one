//
//  Features.swift
//  one
//
//  v3 feature kill-switches — geriye dönük scope küçültme için.
//  Talimatta "kod silmeden kapat, sonra temizle" denilen özellikler burada.
//

import Foundation

enum Features {

    // MARK: - v3 scope removals (default OFF)

    /// SubCircles (alt-çevre / arkadaş grupları) — v3 kapsamında değil.
    /// `false` → Çevre'de grup filtresi, yönetim ve düzenleme sheet'leri
    /// gösterilmez. Mevcut CloudKit kayıtları silinmez.
    static let subCirclesEnabled: Bool = false

    /// Live Activity + Dynamic Island — şimdilik iptal. Kullanıcı deneyimi
    /// olgunlaşana kadar kapalı; `LiveActivityManager` start* çağrıları
    /// no-op olur, ama cleanup çalışmaya devam eder (geride kalan legacy
    /// aktiviteleri sonlandırmak için).
    static let liveActivitiesEnabled: Bool = false
}
