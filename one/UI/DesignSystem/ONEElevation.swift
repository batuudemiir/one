import SwiftUI

/// Elevation system — three rungs, no mood-tinted shadows, no glow.
/// Replaces ad-hoc .shadow(…) calls across the app.
enum ONEElevation {
    /// Card resting on paper: barely lifted.
    case paperLift
    /// Sheet or modal: visibly floating.
    case sheetFloat
    /// Hero card or share preview: clearly elevated.
    case heroHover

    var color: Color {
        switch self {
        case .paperLift:  return Color.black.opacity(0.04)
        case .sheetFloat: return Color.black.opacity(0.08)
        case .heroHover:  return Color.black.opacity(0.10)
        }
    }
    var radius: CGFloat {
        switch self {
        case .paperLift:  return 8
        case .sheetFloat: return 16
        case .heroHover:  return 24
        }
    }
    var y: CGFloat {
        switch self {
        case .paperLift:  return 2
        case .sheetFloat: return 6
        case .heroHover:  return 10
        }
    }
}

extension View {
    @ViewBuilder
    func elevation(_ level: ONEElevation) -> some View {
        self.shadow(color: level.color, radius: level.radius, x: 0, y: level.y)
    }
}
