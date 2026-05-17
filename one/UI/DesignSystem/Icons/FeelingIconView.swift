//
//  FeelingIconView.swift
//  One - Günlük Mood
//

import SwiftUI

struct FeelingIconView: View {
    let type: FeelingType

    var body: some View {
        Image(systemName: symbolName)
            .font(.system(size: 18, weight: .light))
            .foregroundColor(iconColor)
    }

    private var symbolName: String {
        switch type {
        case .calm:            return "water.waves"
        case .happy:           return "sparkles"
        case .sad:             return "cloud.rain"
        case .anxious:         return "wind"
        case .excited:         return "flame"
        case .tired:           return "moon.zzz"
        case .angry:           return "bolt.fill"
        case .peaceful:        return "leaf"
        case .chill:           return "snowflake"
        case .overthink:       return "brain"
        case .hype:            return "bolt.heart.fill"
        case .manifest:        return "star.fill"
        case .happierThanEver: return "sun.max.fill"
        case .dance:           return "music.note"
        case .alone:           return "moon.fill"
        }
    }

    var iconColor: Color {
        switch type {
        case .calm:            return Color(red: 0.35, green: 0.61, blue: 0.84)
        case .happy:           return Color(red: 1.00, green: 0.70, blue: 0.28)
        case .sad:             return Color(red: 0.55, green: 0.64, blue: 0.72)
        case .anxious:         return Color(red: 0.91, green: 0.57, blue: 0.35)
        case .excited:         return Color(red: 0.91, green: 0.36, blue: 0.46)
        case .tired:           return Color(red: 0.61, green: 0.56, blue: 0.77)
        case .angry:           return Color(red: 0.84, green: 0.27, blue: 0.27)
        case .peaceful:        return Color(red: 0.42, green: 0.69, blue: 0.48)
        case .chill:           return Color(red: 0.45, green: 0.78, blue: 0.92)
        case .overthink:       return Color(red: 0.60, green: 0.55, blue: 0.80)
        case .hype:            return Color(red: 1.00, green: 0.38, blue: 0.33)
        case .manifest:        return Color(red: 0.98, green: 0.78, blue: 0.26)
        case .happierThanEver: return Color(red: 1.00, green: 0.65, blue: 0.20)
        case .dance:           return Color(red: 0.85, green: 0.40, blue: 0.75)
        case .alone:           return Color(red: 0.42, green: 0.45, blue: 0.65)
        }
    }
}

// MARK: - Preview
#Preview {
    VStack(spacing: 20) {
        HStack(spacing: 15) {
            VStack {
                FeelingIconView(type: .calm)
                Text("Dingin").font(.caption)
            }
            VStack {
                FeelingIconView(type: .happy)
                Text("Neşeli").font(.caption)
            }
            VStack {
                FeelingIconView(type: .sad)
                Text("Buruk").font(.caption)
            }
            VStack {
                FeelingIconView(type: .anxious)
                Text("Tedirgin").font(.caption)
            }
        }

        HStack(spacing: 15) {
            VStack {
                FeelingIconView(type: .excited)
                Text("Coşkulu").font(.caption)
            }
            VStack {
                FeelingIconView(type: .tired)
                Text("Durgun").font(.caption)
            }
            VStack {
                FeelingIconView(type: .angry)
                Text("Asi").font(.caption)
            }
            VStack {
                FeelingIconView(type: .peaceful)
                Text("Huzurlu").font(.caption)
            }
        }
    }
    .padding()
}
