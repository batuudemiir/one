//
//  ContextPill.swift
//  one
//

import SwiftUI

/// Ritüelde şimdiye kadar seçilenlerin ekmek kırıntısı.
/// `.photo` kalktı: fotoğraf artık ritüelin adımı değil, kayıt sonrası opsiyonel.
enum PillItem {
    case mood(ONEMood)
    case song(SongResult)

    var label: String {
        switch self {
        case .mood(let m): return m.label
        case .song(let s): return s.name
        }
    }

    var swatchColor: Color? {
        guard case .mood(let m) = self else { return nil }
        return m.color
    }

    var targetStep: RitualStep {
        switch self {
        case .mood: return .mood
        case .song: return .song
        }
    }
}

struct ContextPill: View {
    let items: [PillItem]
    let onTap: (RitualStep) -> Void

    var body: some View {
        HStack(spacing: 6) {
            ForEach(Array(items.enumerated()), id: \.offset) { idx, item in
                if idx > 0 {
                    Text("·")
                        .font(.system(size: 10))
                        .foregroundStyle(ONETokens.oneMist)
                }
                Button(action: { onTap(item.targetStep) }) {
                    HStack(spacing: 4) {
                        if let color = item.swatchColor {
                            Circle().fill(color).frame(width: 8, height: 8)
                        }
                        Text(item.label)
                            .font(.custom("DMSans24pt-Medium", size: 10.5))
                            .foregroundStyle(ONETokens.oneAsh)
                            .lineLimit(1)
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Color.black.opacity(0.05))
        .clipShape(Capsule())
    }
}
