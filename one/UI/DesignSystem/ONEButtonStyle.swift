//
//  ONEButtonStyle.swift
//  one
//
//  Design System — Universal press-feedback button style.
//
//  `.buttonStyle(.plain)` iOS'un varsayılan fade'ini bastırıyor ama yerine
//  hiçbir dokunma geri bildirimi koymuyor. `ONEPressableButtonStyle`
//  görseli değiştirmeden sadece hafif bir scale (0.96) veriyor —
//  Photos/Instagram düzeyinde tanıdık iOS hissi.
//
//  Reduce Motion: scale atlanır, sadece opacity dip verilir.
//

import SwiftUI

struct ONEPressableButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(
                (reduceMotion || !isEnabled) ? 1.0
                    : (configuration.isPressed ? ONEAnimation.buttonPressScale : 1.0)
            )
            .opacity(
                !isEnabled ? 0.55
                    : (configuration.isPressed ? 0.92 : 1.0)
            )
            .animation(
                configuration.isPressed
                    ? ONEAnimation.buttonPressAnimation
                    : ONEAnimation.buttonReleaseAnimation,
                value: configuration.isPressed
            )
    }
}

extension ButtonStyle where Self == ONEPressableButtonStyle {
    /// `.plain`'in görsel sadeliğini korur, üstüne hafif press feedback ekler.
    /// Tüm ONE buton call-site'ları için tercih edilen stil.
    static var onePressable: ONEPressableButtonStyle { .init() }
}
