import SwiftUI

// MARK: - App mark (26 × 26 square with the "ONE" wordmark overflowing)

struct V3AppMark: View {
    var side: CGFloat = 26
    var iconRadiusRatio: CGFloat = 0.269   // 7 / 26 — handoff diyor 0.225 ama küçük ikonda 0.269 daha yakın oturuyor
    var wordmarkSize: CGFloat = 13
    var tracking: CGFloat = -0.9

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: side * iconRadiusRatio, style: .continuous)
                .fill(V3Tokens.kor)
                .frame(width: side, height: side)

            Text("ONE")
                .font(V3Typography.display(wordmarkSize, weight: .black))
                .tracking(tracking)
                .foregroundColor(V3Tokens.paper)
                .fixedSize()
                .lineLimit(1)
                .allowsHitTesting(false)
        }
        .frame(width: side, height: side)
    }
}

// MARK: - Header

struct V3Header: View {
    let dateLabel: String
    var body: some View {
        HStack(alignment: .center) {
            Text(dateLabel)
                .v3MicroLabel(1.4)
                .foregroundColor(V3Tokens.mutedText)
            Spacer(minLength: 0)
            V3AppMark()
        }
    }
}

// MARK: - Progress bar (3 segments)

struct V3ProgressBar: View {
    /// 0-based indeks: hangi adımlar aktif.
    let activeThrough: Int   // 0, 1 veya 2

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<3, id: \.self) { i in
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(i <= activeThrough ? V3Tokens.ink : V3Tokens.hairline)
                    .frame(height: 3)
            }
        }
    }
}

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
            .animation(V3Tokens.easingChip, value: isPressed)
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
                .font(V3Typography.sans(16, weight: .semibold))
                .foregroundColor(V3Tokens.ink)
                .padding(.vertical, 16)
                .padding(.horizontal, 34)
                .frame(maxWidth: isFullWidth ? .infinity : nil)
                .background(
                    Capsule(style: .continuous)
                        .stroke(V3Tokens.ink, lineWidth: 1.5)
                )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Back capsule (`← Rengi değiştir`, `← Geri`)

struct V3BackButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: {
            ONEHaptics.feelingSelected()
            action()
        }) {
            Text(title)
                .font(V3Typography.sans(14, weight: .medium))
                .foregroundColor(Color(hex: "#5A5A66"))
                .padding(.vertical, 9)
                .padding(.leading, 12)
                .padding(.trailing, 16)
                .background(
                    Capsule(style: .continuous)
                        .stroke(V3Tokens.hairline, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Date helpers

enum V3DateFormatter {
    /// e.g. `28 TEMMUZ · SALI`
    static func headerLabel(for date: Date = Date()) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "tr_TR")
        f.dateFormat = "d MMMM · EEEE"
        return f.string(from: date).uppercased(with: Locale(identifier: "tr_TR"))
    }
}
