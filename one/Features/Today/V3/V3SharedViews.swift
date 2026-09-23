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

/// Tek satırlık bağlam etiketi. Tek kullanıcısı `V3ReminderView`.
///
/// Sağında `V3AppMark` duruyordu; kalktı. Marka işareti uygulamanın içinde
/// her ekranın tepesinde tekrar edilecek bir şey değil — o yuva ekranın
/// bağlamına ait. An akışı bu başlığı hiç kullanmıyor artık: onun çubuğu
/// `V3EntryContainer`'daki `V3TopBar`.
struct V3Header: View {
    let dateLabel: String
    var body: some View {
        HStack(alignment: .center) {
            Text(dateLabel)
                .v3MicroLabel(1.4)
                .foregroundColor(V3Tokens.mutedText)
            Spacer(minLength: 0)
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
                RoundedRectangle(cornerRadius: V3Tokens.radiusMicro, style: .continuous)
                    .fill(i <= activeThrough ? V3Tokens.ink : V3Tokens.hairline)
                    .frame(height: 3)
            }
        }
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
                .bodySMMedium()
                .foregroundColor(V3Tokens.mutedText)
                .padding(.vertical, 9)
                .padding(.leading, V3Tokens.spacingMD)
                .padding(.trailing, V3Tokens.spacingLG)
                .background(
                    Capsule(style: .continuous)
                        .stroke(V3Tokens.hairline, lineWidth: 1)
                )
        }
        .buttonStyle(.onePressable)
    }
}

// MARK: - Date helpers

enum V3DateFormatter {
    /// e.g. `28 TEMMUZ · SALI`
    static func headerLabel(for date: Date = Date()) -> String {
        let f = ONEFormatters.dayMonthWeekday
        return f.string(from: date).uppercased(with: LanguageManager.shared.currentLocale)
    }
}
