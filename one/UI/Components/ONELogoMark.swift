//
//  ONELogoMark.swift
//  one
//

import SwiftUI

/// ONE wordmark — gradient renkli, yavaş nefes alan animasyonla.
/// Today ekranı başlık alanı için tasarlandı.
struct ONELogoMark: View {
    /// Dışarıdan mood rengi geçilirse o renge boyanır; nil ise varsayılan spektrum.
    var moodColor: Color? = nil
    var size: CGFloat = 56

    @State private var breathe = false

    private var gradientColors: [Color] {
        if let c = moodColor {
            return [c.opacity(0.75), c, c.opacity(0.85)]
        }
        return [ONETokens.moodTeal, ONETokens.moodPurple, ONETokens.moodRose]
    }

    var body: some View {
        Image("ONE_Watermark")
            .resizable()
            .scaledToFit()
            .frame(height: size)
            .foregroundStyle(
                LinearGradient(
                    colors: gradientColors,
                    startPoint: breathe ? .leading : .topLeading,
                    endPoint:   breathe ? .trailing : .bottomTrailing
                )
            )
            .opacity(breathe ? 1.0 : 0.78)
            .scaleEffect(breathe ? 1.0 : 0.97)
            .animation(
                .easeInOut(duration: 2.8).repeatForever(autoreverses: true),
                value: breathe
            )
            .onAppear { breathe = true }
    }
}
