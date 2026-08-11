import SwiftUI

/// ONE v3 app mark — a flat Kor square with the wordmark overflowing its edges.
///
/// Draw it, don't ship a bitmap: the mark is type, so it stays crisp at any size
/// and there is only one place to change if the geometry ever moves.
///
///     ONEAppMark(side: 26)                       // in-app header
///     ONEAppMark(side: 34)                       // notification icon
///     ONEAppMark(side: 76, inverted: true)       // on a Kor ground
///
public struct ONEAppMark: View {
    public let side: CGFloat
    /// `true` = bone square with a Kor wordmark. Only for Kor grounds and print.
    public let inverted: Bool

    public init(side: CGFloat, inverted: Bool = false) {
        self.side = side
        self.inverted = inverted
    }

    private var ground: Color { inverted ? ONEBrand.bone : ONEBrand.kor }
    private var letters: Color { inverted ? ONEBrand.kor : ONEBrand.bone }

    /// v3: `fontSize = side * 0.30`. "ONE" ≈ 2.6 × fontSize wide → sits inside the square.
    private var fontSize: CGFloat { side * ONEBrand.wordmarkFontRatio }

    public var body: some View {
        Text("ONE")
            .font(ONEBrand.display(fontSize))
            .tracking(fontSize * ONEBrand.tracking)
            .foregroundStyle(letters)
            .lineLimit(1)
            .fixedSize()                      // let the glyphs exceed the frame
            .frame(width: side, height: side)
            .background(ground)
            .clipShape(
                RoundedRectangle(
                    cornerRadius: side * ONEBrand.cornerRadiusRatio,
                    style: .continuous
                )
            )
            .accessibilityLabel("ONE")
    }
}

/// Horizontal lockup: mark + gap + ink/bone wordmark.
/// Kor is never used for the wordmark — Kor is a ground, not a text colour.
public struct ONELockup: View {
    public let markSide: CGFloat
    public let onDark: Bool

    public init(markSide: CGFloat = 44, onDark: Bool = false) {
        self.markSide = markSide
        self.onDark = onDark
    }

    public var body: some View {
        HStack(spacing: markSide * ONEBrand.lockupGapRatio) {
            ONEAppMark(side: markSide)
            Text("ONE")
                .font(ONEBrand.display(markSide * 0.98))
                .tracking(markSide * 0.98 * ONEBrand.tracking)
                .foregroundStyle(onDark ? ONEBrand.bone : ONEBrand.ink)
                .lineLimit(1)
        }
        .accessibilityElement()
        .accessibilityLabel("ONE")
    }
}

/// Splash / brand-moment mark. Breathes once per 3.5s; still under Reduce Motion.
public struct ONEBreathingMark: View {
    public let side: CGFloat
    @State private var breathing = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(side: CGFloat = 120) { self.side = side }

    public var body: some View {
        ONEAppMark(side: side)
            .scaleEffect(reduceMotion ? 1 : (breathing ? 0.97 : 1))
            .opacity(breathing ? 0.86 : 1)
            .animation(
                .timingCurve(0.22, 1, 0.36, 1, duration: 3.5).repeatForever(autoreverses: true),
                value: breathing
            )
            .onAppear { breathing = true }
    }
}

#Preview {
    VStack(spacing: 32) {
        HStack(alignment: .bottom, spacing: 20) {
            ONEAppMark(side: 120)
            ONEAppMark(side: 60)
            ONEAppMark(side: 40)
            ONEAppMark(side: 24)
        }
        ONELockup(markSide: 54)
        ONEAppMark(side: 76, inverted: true)
            .padding(28)
            .background(ONEBrand.kor)
    }
    .padding(40)
    .background(ONEBrand.bone)
}
