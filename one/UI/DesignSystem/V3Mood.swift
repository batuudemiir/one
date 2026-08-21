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

    /// Duygunun kullanıcıya görünen adı.
    ///
    /// Bu dokuz kelime uygulamanın **semantik yükünün tamamı** — renk ızgarası,
    /// arşiv, dağılım, çevre kartı, bildirim, hepsi bunu gösteriyor. Uzun süre
    /// koda gömülü Türkçe'ydi: uygulama 9 dile çevriliydi ama Almanca bir
    /// kullanıcı renk seçerken "Hüzünlü" görüyordu. Artık katalogdan geliyor.
    var label: String {
        NSLocalizedString("mood.v3.\(rawValue).label", comment: "v3 mood name")
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

    /// Duygunun tek cümlelik anlamı — VoiceOver değeri ve alt başlık.
    ///
    /// Eskiden çağıranlar `bridgedMood.meaning` diyordu, yani anlam legacy
    /// 12-mood tablosundan **kayıplı köprü üzerinden** geliyordu: renk
    /// seçicide "odaklı"nın ekran okuyucu değeri `derin`in anlamıydı
    /// ("dengede, sabit"), "coşkulu"nunki `nostaljik`inki. Dokuz duygunun
    /// artık kendi cümlesi var.
    var meaning: String {
        NSLocalizedString("mood.v3.\(rawValue).meaning", comment: "v3 mood meaning")
    }

    /// Doygun rengin yumuşatılmış hali — hale, mesh gradyan, atmosfer.
    ///
    /// `ONEMood.pastelColor`'ın v3 karşılığı. Orada her mood için elle
    /// seçilmiş ikinci bir hex tablosu vardı; burada tek kaynaktan türüyor
    /// çünkü iki tablo tutmak tam da 12-mood tarafındaki kaymanın sebebiydi:
    /// doygun renk değişince pastel geride kalıyordu.
    ///
    /// Beyaza doğru karıştırma yerine düşük opaklık kullanılıyor ki koyu
    /// temada da doğru yönde açılsın — pastel sabitler koyu zeminde
    /// "solmuş" değil "kirli" görünüyordu.
    var pastelColor: Color { color.opacity(0.42) }

    /// Zemin üstünde okunan mürekkep rengi. Sarı/lime üstünde beyaz yasak.
    var ink: Color { Color(hex: inkHex) }

    /// `ink`'in hex karşılığı — tek kaynak.
    ///
    /// `ink` doğrudan `Color(hex:)` döndürüyordu ve değeri testten okumanın
    /// yolu yoktu; `Color` → hex roundtrip'i sRGB'de hafif kayıyor. Kontrast
    /// testinin ölçtüğü şey token'ın **değeri** olmalı, SwiftUI'nin renk
    /// çözümü değil — `hex` alanı da aynı sebeple sabit string.
    var inkHex: String {
        switch self {
        case .atesli:  return "#FFF1EE"
        case .coskulu: return "#1A0C00"
        case .gergin:  return "#F6ECFF"
        case .mutlu:   return "#1A1200"
        case .enerjik: return "#141A00"
        case .odakli:  return "#EAEEFF"
        case .huzurlu: return "#04170F"
        case .huzunlu: return "#EDEFFA"
        case .yorgun:  return "#F2F3F5"
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

    /// "Meraklı" hatırlatma tonunun dünü anan cümlesi — **tam cümle**.
    ///
    /// Eskiden `accusativePastTense` vardı ve çağıran taraf `"Dün \(x)."` diye
    /// birleştiriyordu. Bu Türkçe'ye özgü bir çekim ekiydi ("ateşliydin") ve
    /// başka hiçbir dile taşınamıyordu; İngilizce'de yüklem başa, Japonca'da
    /// cümle sonuna geliyor. Kelime birleştirmek yerine dil başına tam cümle
    /// tutuluyor — çevirmen cümleyi kendi dilbilgisine göre kurabiliyor.
    var yesterdayRecallSentence: String {
        NSLocalizedString("reminder.curious.yesterday.\(rawValue)",
                          comment: "Curious reminder: what the user felt yesterday")
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
