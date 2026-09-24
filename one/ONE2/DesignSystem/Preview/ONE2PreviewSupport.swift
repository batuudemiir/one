//
//  ONE2PreviewSupport.swift
//  ONE 2.0
//
//  Yalnız DEBUG: her bileşen ve ekranın üç önizlemesi (gece, gün, AX3)
//  aynı zeminde ve kenar payıyla.
//

#if DEBUG
import SwiftUI

enum ONE2PreviewMode {
    case gece, gun, ax3
}

extension View {
    /// Bileşeni önizleme zeminine koyar: `ground`, ekran kenarı, tema, Dynamic Type.
    func one2Preview(_ mode: ONE2PreviewMode) -> some View {
        ScrollView {
            self
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(ONE2Space.gutter)
        }
        .background(ONE2Color.ground.ignoresSafeArea())
        .preferredColorScheme(mode == .gun ? .light : .dark)
        .dynamicTypeSize(mode == .ax3 ? .accessibility3 : .large)
    }
}
#endif
