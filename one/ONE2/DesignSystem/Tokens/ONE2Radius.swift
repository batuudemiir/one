//
//  ONE2Radius.swift
//  ONE 2.0
//
//  Köşe yarıçapları (tokens.json › radius). Köşeler `.continuous`.
//

import SwiftUI

enum ONE2Radius {
    /// Etiket, küçük kuyu.
    static let sm: CGFloat = 12
    /// Hafta şeridinde bugün çerçevesi, ikon kuyusu.
    static let md: CGFloat = 18
    /// Tüm kartlar.
    static let lg: CGFloat = 28
    /// Tam ekran söz kartı, sheet.
    static let xl: CGFloat = 36
    /// Hap kontroller. Şekil olarak `Capsule()` tercih et; bu değer
    /// yalnız yarıçap isteyen API'ler için.
    static let pill: CGFloat = 999

    static func shape(_ radius: CGFloat) -> RoundedRectangle {
        RoundedRectangle(cornerRadius: radius, style: .continuous)
    }
}
