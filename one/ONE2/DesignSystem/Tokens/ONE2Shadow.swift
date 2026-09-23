//
//  ONE2Shadow.swift
//  ONE 2.0
//
//  Tek gölge: `shadow-float` (tokens.json › shadow), yalnız yüzen dock ve
//  + hapında. Kartlar gölgesiz; ayrım zemin tonuyla.
//  CSS `0 10px 30px`: y 10, bulanıklık 30 → SwiftUI yarıçapı 15.
//

import SwiftUI
import UIKit

enum ONE2Shadow {
    static let floatY: CGFloat = 10
    static let floatRadius: CGFloat = 15

    /// gece rgba(0,0,0,0.6) · gün rgba(17,17,19,0.14)
    static let floatColor = Color(UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(red: 0, green: 0, blue: 0, alpha: 0.6)
            : UIColor(red: 17 / 255, green: 17 / 255, blue: 19 / 255, alpha: 0.14)
    })
}

extension View {
    /// Yüzen yüzey gölgesi (TabBar, + hapı).
    func one2FloatShadow() -> some View {
        shadow(color: ONE2Shadow.floatColor, radius: ONE2Shadow.floatRadius, x: 0, y: ONE2Shadow.floatY)
    }
}
