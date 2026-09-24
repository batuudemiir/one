//
//  LaunchCheckIn.swift
//  ONE 2.0
//
//  Açılış check-in'i (07 §5.2): Profil'de açıksa, günün ilk açılışında,
//  uygulama bildirim/widget/derin bağlantıyla açılmadıysa Akış 1 açılır.
//  Sabah+akşam modunda 05–14 arası açılışta check-in açılmaz; sabah kartı
//  öne gelir. "Günün ilk açılışı" ve ayarın kendisi motordan (UX_istekleri §3).
//

import Foundation

nonisolated enum LaunchCheckIn {
    static func shouldOpen(
        isEnabled: Bool,
        isFirstOpenToday: Bool,
        openedViaLink: Bool,
        mode: RitualModeData,
        hour: Int
    ) -> Bool {
        guard isEnabled, isFirstOpenToday, !openedViaLink else { return false }
        if mode == .morningEvening, (5..<14).contains(hour) { return false }
        return true
    }
}
