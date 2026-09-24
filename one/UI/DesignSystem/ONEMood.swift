//
//  ONEMood.swift
//  one
//
//  **Legacy mood — yalnızca göç/okuma katmanı.**
//
//  v3'ün tek mood kaynağı `V3Mood` (9 duygu). Bu enum bir seçici değil:
//  arşivdeki eski kayıtların `moodColorHex` değerlerini çözebilmek için
//  duruyor. `V3Mood.fromHex` onu bir fallback olarak kullanıyor — v1/v2
//  doygun renkleri, pastel varyantları ve ara sürümlerin hex'leri hâlâ
//  kullanıcıların arşivinde.
//
//  Sunum üyeleri (`color`, `pastelColor`, `label`, `meaning`, `icon`,
//  `isDark`, `waveHeight`, `gradientStops`) kaldırıldı. Hepsi `V3Mood`'da
//  var ve iki tablo tutmak paletlerin birbirinden kaymasının sebebiydi:
//  doygun renk değişiyor, pastel geride kalıyordu.
//
//  Buraya yeni üye ekleme. Bir mood'un görünen bir özelliği gerekiyorsa
//  `V3Mood`'a ekle.
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
}

// MARK: - Legacy hex çözümü

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
