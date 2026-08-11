//
//  V3GreetingHeader.swift
//  one
//
//  An sekmesinde iki tonlu selam.
//
//  Spec:
//    Günaydın, Batu      ← Archivo 44px, renk: faint
//    Bugün nasılsın?     ← Archivo 44px, renk: ink
//
//  Saat aralıkları:
//    <6  → "İyi geceler"
//    <12 → "Günaydın"
//    <18 → "İyi günler"
//    diğer → "İyi akşamlar"
//
//  Geçmiş gün doldururken gösterilmez.
//

import SwiftUI

struct V3GreetingHeader: View {
    /// Kullanıcının adı. `nil` ise sadece selam.
    let name: String?
    /// Gündüz kısmı — genellikle "Bugün nasılsın?" veya "Bir an daha?".
    let prompt: String

    init(name: String? = nil, prompt: String = "Bugün nasılsın?") {
        self.name = name
        self.prompt = prompt
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(greetingLine)
                .font(ONEBrand.display(44))
                .tracking(-1.2)
                .foregroundColor(V3Tokens.faintText)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Text(prompt)
                .font(ONEBrand.display(44))
                .tracking(-1.2)
                .foregroundColor(V3Tokens.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
    }

    // MARK: - Copy

    private var greetingLine: String {
        V3GreetingHeaderCopy.currentGreeting(name: name)
    }
}

/// Selam kopyası — sadece string. V3EntryContainer bunu ColorStepView'e greeting olarak veriyor.
enum V3GreetingHeaderCopy {
    static func currentGreeting(name: String?) -> String {
        let hour = Calendar.current.component(.hour, from: Date())
        let base: String
        switch hour {
        case ..<6:   base = "İyi geceler"
        case ..<12:  base = "Günaydın"
        case ..<18:  base = "İyi günler"
        default:     base = "İyi akşamlar"
        }
        // Spec zaten "Günaydın, Batu" diyor — selam samimi bir hitap, kimlik
        // doğrulaması değil. Çağıran `displayName`'i olduğu gibi veriyor
        // ("Batuhan Demir"); kısaltmayı burada yapıyoruz ki her çağıran
        // hatırlamak zorunda kalmasın.
        let firstName = (name ?? "").firstNameOnly
        guard !firstName.isEmpty else { return base }
        return "\(base), \(firstName)"
    }
}

#Preview {
    VStack(alignment: .leading, spacing: 32) {
        V3GreetingHeader(name: "Batu", prompt: "Bugün nasılsın?")
        V3GreetingHeader(name: nil, prompt: "Bir an daha?")
    }
    .padding(24)
    .background(V3Tokens.paper)
}
