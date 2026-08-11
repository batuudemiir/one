import SwiftUI

/// v3 9-mood palette (3×3 — rows = energy, columns = direction).
///
/// Ayrı bir enum tuttum çünkü mevcut `ONEMood` 12 case ve farklı hex'lerle
/// Archive/Echo/Monthly Summary'ye bağlı. v3 renk seçici bu daralmış paleti
/// kullanıyor; kayıt anında `ONEMood`'a köprüleniyor (bkz. `bridgedMood`).
enum V3Mood: String, CaseIterable, Identifiable {
    case atesli
    case coskulu
    case gergin
    case mutlu
    case enerjik
    case odakli
    case huzurlu
    case huzunlu
    case yorgun

    var id: String { rawValue }

    var label: String {
        switch self {
        case .atesli:  return "Ateşli"
        case .coskulu: return "Coşkulu"
        case .gergin:  return "Gergin"
        case .mutlu:   return "Mutlu"
        case .enerjik: return "Enerjik"
        case .odakli:  return "Odaklı"
        case .huzurlu: return "Huzurlu"
        case .huzunlu: return "Hüzünlü"
        case .yorgun:  return "Yorgun"
        }
    }

    /// Full-saturation renk (kart zemini).
    var color: Color {
        switch self {
        case .atesli:  return Color(hex: "#FF3B1F")
        case .coskulu: return Color(hex: "#FF8A00")
        case .gergin:  return Color(hex: "#8B2FD6")
        case .mutlu:   return Color(hex: "#FFC300")
        case .enerjik: return Color(hex: "#C8F135")
        case .odakli:  return Color(hex: "#2B4CF0")
        case .huzurlu: return Color(hex: "#00B58C")
        case .huzunlu: return Color(hex: "#5C6BC0")
        case .yorgun:  return Color(hex: "#6E7482")
        }
    }

    /// Zemin üstünde okunan mürekkep rengi. Sarı/lime üstünde beyaz yasak.
    var ink: Color {
        switch self {
        case .atesli:  return Color(hex: "#FFF1EE")
        case .coskulu: return Color(hex: "#1A0C00")
        case .gergin:  return Color(hex: "#F6ECFF")
        case .mutlu:   return Color(hex: "#1A1200")
        case .enerjik: return Color(hex: "#141A00")
        case .odakli:  return Color(hex: "#EAEEFF")
        case .huzurlu: return Color(hex: "#04170F")
        case .huzunlu: return Color(hex: "#EDEFFA")
        case .yorgun:  return Color(hex: "#F2F3F5")
        }
    }

    /// sRGB roundtrip Color→UIColor→hex hafif kayması olabildiği için
    /// hex'i sabit string olarak dönüyorum. `fromHex` bu sabitle karşılaştırıyor.
    var hex: String {
        switch self {
        case .atesli:  return "#FF3B1F"
        case .coskulu: return "#FF8A00"
        case .gergin:  return "#8B2FD6"
        case .mutlu:   return "#FFC300"
        case .enerjik: return "#C8F135"
        case .odakli:  return "#2B4CF0"
        case .huzurlu: return "#00B58C"
        case .huzunlu: return "#5C6BC0"
        case .yorgun:  return "#6E7482"
        }
    }

    /// Accusative-ish form used by the "curious" reminder tone (`Dün maviydin.`).
    var accusativePastTense: String {
        switch self {
        case .atesli:  return "ateşliydin"
        case .coskulu: return "coşkuluydun"
        case .gergin:  return "gergindin"
        case .mutlu:   return "mutluydun"
        case .enerjik: return "enerjiktin"
        case .odakli:  return "odaklıydın"
        case .huzurlu: return "huzurluydun"
        case .huzunlu: return "hüzünlüydün"
        case .yorgun:  return "yorgundun"
        }
    }

    /// v3 seçiminden mevcut `ONEMood`'a köprü. Var olan veri katmanı (Archive,
    /// Echo vb.) hâlâ `ONEMood` kullanıyor — hex bazlı en yakın eşleşmeyi
    /// üretmek yerine anlamsal eşleştirme yaptım.
    var bridgedMood: ONEMood {
        switch self {
        case .atesli:  return .atesli
        case .coskulu: return .nostaljik   // coşku ≈ heyecanlı taşma
        case .gergin:  return .stresli
        case .mutlu:   return .isikli
        case .enerjik: return .enerjik
        case .odakli:  return .derin       // odaklı ≈ stabil
        case .huzurlu: return .sakin
        case .huzunlu: return .uzgun
        case .yorgun:  return .yorgun
        }
    }

    /// Kayıtlı hex'ten (`DailySong.moodColorHex`) v3 mood'a en yakın eşleşme.
    /// Home ekranındaki "son yedi gün" şeridi için kullanılır.
    static func fromHex(_ hex: String) -> V3Mood? {
        let normalized = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted).uppercased()
        for mood in V3Mood.allCases {
            if mood.hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted).uppercased() == normalized {
                return mood
            }
        }
        // v2 hex fallback — legacy kayıtlar da v3 palette'ine düşsün.
        if let legacy = ONEMood(hex: hex) {
            return V3Mood.allCases.first { $0.bridgedMood == legacy }
        }
        return nil
    }

    /// `fromHex` tablosu tutmadığında **en yakın** v3 rengine düşer (RGB
    /// mesafesi). İstatistik yüzeyleri (renk dağılımı, "en sık", aylık özet)
    /// bunu kullanır — hiçbir kayıt "?" kovasında kaybolmaz.
    ///
    /// Tam eşleşme gerektiğinde (renk seçici, an akışı) `fromHex` kullanılır;
    /// bu yalnız okuma/özet tarafı içindir.
    static func closest(toHex hex: String) -> V3Mood? {
        if let exact = fromHex(hex) { return exact }
        guard let target = rgb(hex) else { return nil }
        return V3Mood.allCases.min { a, b in
            distance(rgb(a.hex) ?? (0, 0, 0), target) < distance(rgb(b.hex) ?? (0, 0, 0), target)
        }
    }

    private static func rgb(_ hex: String) -> (Double, Double, Double)? {
        var s = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        if s.count == 3 { s = s.map { "\($0)\($0)" }.joined() }
        guard s.count == 6, let value = UInt32(s, radix: 16) else { return nil }
        return (
            Double((value >> 16) & 0xFF),
            Double((value >> 8) & 0xFF),
            Double(value & 0xFF)
        )
    }

    private static func distance(_ a: (Double, Double, Double), _ b: (Double, Double, Double)) -> Double {
        let dr = a.0 - b.0, dg = a.1 - b.1, db = a.2 - b.2
        return dr * dr + dg * dg + db * db
    }
}
