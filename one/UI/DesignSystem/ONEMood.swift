//
//  ONEMood.swift
//  one
//
//  Design System - Mood System
//

import SwiftUI

enum ONEMood: String, Codable, CaseIterable, Identifiable {
    case atesli    // tutkulu  - red
    case isikli    // mutlu    - yellow
    case enerjik   // enerjik  - orange
    case taze      // doğal    - lime
    case sakin     // huzurlu  - green
    case nostaljik // heyecanlı - coral
    case ozgur     // sakin    - teal
    case derin     // stabil   - blue
    case uzgun     // üzgün    - indigo
    case stresli   // stresli  - stress orange-red
    case yorgun    // yorgun   - slate grey
    case sinirli   // sinirli  - dark crimson

    var id: String { rawValue }

    var color: Color {
        switch self {
        case .atesli:    return ONETokens.moodTutkulu
        case .isikli:    return ONETokens.moodYellow
        case .enerjik:   return ONETokens.moodOrange
        case .taze:      return ONETokens.moodLime
        case .sakin:     return ONETokens.moodHuzurlu
        case .nostaljik: return ONETokens.moodExcited
        case .ozgur:     return ONETokens.moodTeal
        case .derin:     return ONETokens.moodStabil
        case .uzgun:     return ONETokens.moodIndigo
        case .stresli:   return ONETokens.moodStress
        case .yorgun:    return ONETokens.moodSlate
        case .sinirli:   return ONETokens.moodAngry
        }
    }

    var pastelColor: Color {
        switch self {
        case .atesli:    return ONETokens.moodPastelRed
        case .isikli:    return ONETokens.moodPastelYellow
        case .enerjik:   return ONETokens.moodPastelOrange
        case .taze:      return ONETokens.moodPastelMint
        case .sakin:     return ONETokens.moodPastelGreen
        case .nostaljik: return ONETokens.moodPastelRose
        case .ozgur:     return ONETokens.moodPastelBlue
        case .derin:     return ONETokens.moodPastelIndigo
        case .uzgun:     return ONETokens.moodPastelLavender
        case .stresli:   return ONETokens.moodPastelStress
        case .yorgun:    return ONETokens.moodPastelSlate
        case .sinirli:   return ONETokens.moodPastelAngry
        }
    }

    func atmosphereGradient(startPoint: UnitPoint = .topLeading,
                            endPoint: UnitPoint = .bottomTrailing) -> LinearGradient {
        LinearGradient(
            stops: [
                .init(color: pastelColor.opacity(0.18), location: 0.0),
                .init(color: pastelColor.opacity(0.06), location: 0.55),
                .init(color: .clear,                    location: 1.0)
            ],
            startPoint: startPoint,
            endPoint: endPoint
        )
    }

    var hex: String {
        switch self {
        case .atesli:    return "#E53935"
        case .isikli:    return "#FDD835"
        case .enerjik:   return "#FB6F3B"
        case .taze:      return "#4CAF50"
        case .sakin:     return "#26A69A"
        case .nostaljik: return "#EC407A"
        case .ozgur:     return "#42A5F5"
        case .derin:     return "#3F51B5"
        case .uzgun:     return "#78909C"
        case .stresli:   return "#FF7043"
        case .yorgun:    return "#90A4AE"
        case .sinirli:   return "#B71C1C"
        }
    }

    var label: String {
        switch self {
        case .atesli:    return "tutkulu"
        case .isikli:    return "mutlu"
        case .enerjik:   return "enerjik"
        case .taze:      return "doğal"
        case .sakin:     return "huzurlu"
        case .nostaljik: return "heyecanlı"
        case .ozgur:     return "sakin"
        case .derin:     return "stabil"
        case .uzgun:     return "üzgün"
        case .stresli:   return "stresli"
        case .yorgun:    return "yorgun"
        case .sinirli:   return "sinirli"
        }
    }

    var meaning: String {
        switch self {
        case .atesli:    return "içim yanıyor"
        case .isikli:    return "içimden parlıyor"
        case .enerjik:   return "taşıp duruyor"
        case .taze:      return "yeni başlıyor"
        case .sakin:     return "her şey yolunda"
        case .nostaljik: return "coşkuyla doluyum"
        case .ozgur:     return "hafif, dingin"
        case .derin:     return "dengede, sabit"
        case .uzgun:     return "içim sıkışmış"
        case .stresli:   return "altında eziliyorum"
        case .yorgun:    return "bitkin, tükenmişim"
        case .sinirli:   return "içimde fırtına var"
        }
    }

    var icon: String {
        switch self {
        case .atesli:    return "flame.fill"
        case .isikli:    return "sun.max.fill"
        case .enerjik:   return "bolt.fill"
        case .taze:      return "leaf.fill"
        case .sakin:     return "water.waves"
        case .nostaljik: return "star.fill"
        case .ozgur:     return "wind"
        case .derin:     return "anchor"
        case .uzgun:     return "cloud.rain.fill"
        case .stresli:   return "exclamationmark.triangle.fill"
        case .yorgun:    return "moon.zzz.fill"
        case .sinirli:   return "bolt.trianglebadge.exclamationmark.fill"
        }
    }

    var isDark: Bool {
        switch self {
        case .isikli, .taze: return false
        default: return true
        }
    }

    var waveHeight: CGFloat {
        switch self {
        case .atesli:    return 28
        case .isikli:    return 24
        case .enerjik:   return 32
        case .taze:      return 20
        case .sakin:     return 16
        case .nostaljik: return 30
        case .ozgur:     return 22
        case .derin:     return 18
        case .uzgun:     return 14
        case .stresli:   return 26
        case .yorgun:    return 10
        case .sinirli:   return 34
        }
    }

    var gradientStops: [Color] {
        let darkBase = ONETokens.oneVoid
        return [color, color.opacity(0.4), darkBase]
    }

    var gradientStart: UnitPoint { .topLeading }
    var gradientEnd: UnitPoint { .bottomTrailing }
}

extension ONEMood {
    init?(hex: String) {
        let normalized = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted).uppercased()
        switch normalized {
        // Current colors
        case "E53935": self = .atesli
        case "FDD835": self = .isikli
        case "FB6F3B": self = .enerjik
        case "4CAF50": self = .taze
        case "26A69A": self = .sakin
        case "EC407A": self = .nostaljik
        case "42A5F5": self = .ozgur
        case "3F51B5": self = .derin
        case "78909C": self = .uzgun
        case "FF7043": self = .stresli
        case "90A4AE": self = .yorgun
        case "B71C1C": self = .sinirli
        // Legacy v2 colors
        case "E84040": self = .atesli
        case "F5C842": self = .isikli
        case "FF8C42": self = .enerjik
        case "7CC874": self = .taze
        case "4CAF82": self = .sakin
        case "FF6154": self = .nostaljik
        case "3BBFCF": self = .ozgur
        case "5B8DEF": self = .derin
        case "5560B8": self = .uzgun
        case "D4572A": self = .stresli
        case "607D8B": self = .yorgun
        case "B53030": self = .sinirli
        // Legacy pastel mappings
        case "FFB5A7": self = .atesli
        case "FFF0B3": self = .isikli
        case "FFCBA4": self = .enerjik
        case "B8F0D4": self = .taze
        case "A8D5B5": self = .sakin
        case "FFB8CC": self = .nostaljik
        case "A8D4F5": self = .ozgur
        case "B8C5F0": self = .derin
        case "C5B8F0": self = .uzgun
        case "CDD5E8": self = .yorgun
        case "D4B8F0": self = .sinirli
        // Legacy v1 cases
        case "9B7FD4": self = .ozgur
        case "E8829C": self = .atesli
        case "2C2C2C": self = .derin
        case "E8E6E0": self = .sakin
        case "C97840": self = .enerjik
        default: return nil
        }
    }
}
