//
//  String+DisplayName.swift
//  one
//
//  Görünen ad biçimlendirmesi.
//

import Foundation

extension String {
    /// Tam addan yalnız ilk adı ayırır: "Batuhan Demir" → "Batuhan".
    ///
    /// An ekranlarında soyad kimlik kartı bilgisi gibi duruyor ve başlığı
    /// gereksiz uzatıyor; kişiye adıyla hitap etmek daha yakın. Profil,
    /// arkadaş listesi ve arama sonuçlarında tam ad durmaya devam ediyor —
    /// orada kişiyi ayırt etmek gerekiyor.
    ///
    /// Boş ada ya da yalnız boşluktan oluşan bir ada karşı dayanıklı: bölünecek
    /// bir şey yoksa girdi olduğu gibi döner (`components(separatedBy:).first`
    /// tek başına baştaki boşlukta boş string döndürüyordu).
    var firstNameOnly: String {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        guard let first = trimmed.split(separator: " ").first else { return self }
        return String(first)
    }
}
