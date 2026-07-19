//
//  ONEMood+RitualExtensions.swift
//  one
//

import SwiftUI

extension ONEMood {
    var subtitle: String {
        switch self {
        case .atesli:    return "ateşli · kırmızı bir gün"
        case .enerjik:   return "enerjik · turuncu bir gün"
        case .isikli:    return "ışıklı · sarı bir gün"
        case .taze:      return "taze · yeşil bir gün"
        case .sakin:     return "sakin · mint bir gün"
        case .nostaljik: return "nostaljik · mercan bir gün"
        case .ozgur:     return "özgür · mavi bir gün"
        case .derin:     return "derin · indigo bir gün"
        case .uzgun:     return "üzgün · gri bir gün"
        case .yorgun:    return "yorgun · slate bir gün"
        case .stresli:   return "stresli · turuncu-kırmızı bir gün"
        case .sinirli:   return "sinirli · koyu kızıl bir gün"
        }
    }

    var suggestedFeelings: [String] {
        switch self {
        case .atesli:    return ["ateşli", "yoğun", "kararlı", "yanan"]
        case .enerjik:   return ["enerjik", "hızlı", "diri", "uçan"]
        case .isikli:    return ["ışıklı", "neşeli", "aydınlık", "hafif"]
        case .taze:      return ["taze", "doğal", "açık", "dingin"]
        case .sakin:     return ["sakin", "huzurlu", "yumuşak", "akıcı"]
        case .nostaljik: return ["nostaljik", "dolu", "hatırayla", "sıcak"]
        case .ozgur:     return ["özgür", "rahat", "geniş", "açık hava"]
        case .derin:     return ["derin", "sağlam", "oturmuş", "dengeli"]
        case .uzgun:     return ["üzgün", "ağır", "uzak", "boş"]
        case .yorgun:    return ["yorgun", "bitkin", "tükenmiş", "yavaş"]
        case .stresli:   return ["stresli", "gergin", "sıkışmış", "hızlanan"]
        case .sinirli:   return ["sinirli", "kızgın", "patlak", "kabaran"]
        }
    }

    var chipTextColor: Color {
        switch self {
        case .atesli:    return Color(hex: "#7A1F1F")
        case .enerjik:   return Color(hex: "#8A3F1F")
        case .isikli:    return Color(hex: "#7A6300")
        case .taze:      return Color(hex: "#1F5A24")
        case .sakin:     return Color(hex: "#0F5A52")
        case .nostaljik: return Color(hex: "#7A1F3F")
        case .ozgur:     return Color(hex: "#1F4F7A")
        case .derin:     return Color(hex: "#1F2A6E")
        case .uzgun:     return Color(hex: "#3A4750")
        case .yorgun:    return Color(hex: "#42505A")
        case .stresli:   return Color(hex: "#8A3220")
        case .sinirli:   return Color(hex: "#5A0F0F")
        }
    }
}
