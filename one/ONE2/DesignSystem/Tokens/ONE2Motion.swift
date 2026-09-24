//
//  ONE2Motion.swift
//  ONE 2.0
//
//  Hareket (README "Hareket ve geri bildirim"): tek eğri
//  cubic-bezier(0.2, 0.8, 0.2, 1), dört süre. Reduce Motion açıkken
//  hareket yok, yalnız opaklık: ölçek ve kayma geçişleri `.opacity`'ye,
//  basış ölçeği 1'e düşer.
//

import SwiftUI

enum ONE2Motion {

    enum Kind: Sendable {
        /// Basış, 120 ms.
        case press
        /// Chip seçimi, 180 ms.
        case chip
        /// Ekran geçişi, 280 ms.
        case screen
        /// Mühür, 320 ms.
        case seal

        var duration: Double {
            switch self {
            case .press:  return 0.12
            case .chip:   return 0.18
            case .screen: return 0.28
            case .seal:   return 0.32
            }
        }
    }

    /// İskelet nefesi (bir yön). Dört süreden biri değil: yükleniyor
    /// durumu için yavaş, sakin bir döngü. Reduce Motion'da yok.
    static let breathDuration: Double = 1.2
    static let breathLowOpacity: Double = 0.55

    /// Basışta ölçek.
    static let pressScale: CGFloat = 0.97
    /// Mühür başlangıç ölçeği (0.9 → 1.0).
    static let sealStartScale: CGFloat = 0.9

    static func curve(_ kind: Kind) -> Animation {
        .timingCurve(0.2, 0.8, 0.2, 1, duration: kind.duration)
    }

    /// Reduce Motion'da da aynı süre; çağıran yalnız opaklığı değiştirir.
    static func animation(_ kind: Kind, reduceMotion: Bool) -> Animation {
        reduceMotion ? .linear(duration: kind.duration) : curve(kind)
    }

    /// Reduce Motion'da hareketli geçiş yerine opaklık.
    static func transition(_ moving: AnyTransition, reduceMotion: Bool) -> AnyTransition {
        reduceMotion ? .opacity : moving
    }

    /// Basış ölçeği; Reduce Motion'da 1.
    static func pressScale(isPressed: Bool, reduceMotion: Bool) -> CGFloat {
        isPressed && !reduceMotion ? pressScale : 1
    }
}
