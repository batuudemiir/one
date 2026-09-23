//
//  V3Buttons.swift
//  one
//
//  Birincil ve ikincil kapsül düğmeler. v3 `Features/Today/V3/V3SharedViews.swift`
//  içindeydi; ONE 2.0 da kullandığı için paylaşılan bileşenlere taşındı
//  (ADR-001 §7). Davranış değişmedi.
//

import SwiftUI

// MARK: - Primary capsule button (`Devam`, `Kaydet`)

struct V3PrimaryButton: View {
    let title: String
    var isEnabled: Bool = true
    var isFullWidth: Bool = false
    var horizontalPadding: CGFloat = 34
    var verticalPadding: CGFloat = 16
    var fontSize: CGFloat = 16
    let action: () -> Void

    var body: some View {
        Button(action: {
            guard isEnabled else { return }
            ONEHaptics.feelingSelected()
            action()
        }) {
            Text(title)
        }
        .contentShape(Rectangle())
        .buttonStyle(
            V3PrimaryButtonStyle(
                isEnabled: isEnabled,
                isFullWidth: isFullWidth,
                horizontalPadding: horizontalPadding,
                verticalPadding: verticalPadding,
                fontSize: fontSize
            )
        )
        .disabled(!isEnabled)
    }
}

/// Basma geri bildirimi `ButtonStyle` üzerinden.
///
/// Eskiden `@State isPressed` + `simultaneousGesture(DragGesture(minimumDistance: 0))`
/// ile yapılıyordu. O drag, sıfır mesafeden başladığı için kabuğun sayfa
/// swipe'ını ve içinde bulunduğu `ScrollView`'ın kaydırmasını da yakalıyordu.
/// `ButtonStyle.isPressed` aynı görsel sonucu verir ve sistem, kaydırma
/// başladığında basma durumunu kendisi iptal eder — `V3CardPressStyle` ile
/// aynı desen.
private struct V3PrimaryButtonStyle: ButtonStyle {
    let isEnabled: Bool
    let isFullWidth: Bool
    let horizontalPadding: CGFloat
    let verticalPadding: CGFloat
    let fontSize: CGFloat

    func makeBody(configuration: Configuration) -> some View {
        let isPressed = configuration.isPressed && isEnabled
        return configuration.label
            .font(V3Typography.sans(fontSize, weight: .semibold))
            .foregroundColor(isEnabled ? V3Tokens.paper : V3Tokens.ghostText)
            .padding(.vertical, verticalPadding)
            .padding(.horizontal, horizontalPadding)
            .frame(maxWidth: isFullWidth ? .infinity : nil)
            .background(
                Capsule(style: .continuous)
                    .fill(isEnabled ? (isPressed ? V3Tokens.kor : V3Tokens.ink) : V3Tokens.hairline)
            )
            .contentShape(Capsule(style: .continuous))
            .animation(ONEAnimation.easingChip, value: isPressed)
    }
}

// MARK: - Secondary capsule (outlined, `Baştan`)

struct V3OutlineButton: View {
    let title: String
    var isFullWidth: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: {
            ONEHaptics.feelingSelected()
            action()
        }) {
            Text(title)
                .bodyLGSemibold()
                .foregroundColor(V3Tokens.ink)
                .padding(.vertical, V3Tokens.spacingLG)
                .padding(.horizontal, 34)
                .frame(maxWidth: isFullWidth ? .infinity : nil)
                .background(
                    Capsule(style: .continuous)
                        .stroke(V3Tokens.ink, lineWidth: 1.5)
                )
        }
        .buttonStyle(.onePressable)
    }
}
