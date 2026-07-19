//  MoodHeadlineCopy.swift
//  one

import Foundation

struct MoodHeadlineCopy {
    let headline: String
    let description: String
}

enum MoodHeadlines {
    static func copy(for mood: String) -> MoodHeadlineCopy {
        switch canonicalMoodLabel(mood) {
        case "Ateşli":
            return MoodHeadlineCopy(
                headline: "Şehir taşkın\nakşamlar için.",
                description: "Enerji zirvedeyken şehir de seninle aynı frekansta."
            )
        case "Coşkulu":
            return MoodHeadlineCopy(
                headline: "Bu gece\nsahne senin.",
                description: "Coşkunla örtüşen, seni ritme çekecek öneriler."
            )
        case "Mutlu":
            return MoodHeadlineCopy(
                headline: "Güzel günler\niçin güzel yerler.",
                description: "Bugünkü iyiliği dışarıda da hisset."
            )
        case "Doğal":
            return MoodHeadlineCopy(
                headline: "Şehirde bir\nnefes yeri bulduk.",
                description: "Doğanla uyumlu, sade ve gerçek öneriler."
            )
        case "Huzurlu":
            return MoodHeadlineCopy(
                headline: "Yavaş bir\nakşam için.",
                description: "Huzurunu bozmadan keşfedebileceğin köşeler."
            )
        case "Özgür":
            return MoodHeadlineCopy(
                headline: "Sınır yok,\nsadece şehir.",
                description: "Özgür hissin için rotasız ama dolu bir akşam."
            )
        case "Derin":
            return MoodHeadlineCopy(
                headline: "İçine dönerken\nşehre de aç.",
                description: "Düşüncelerin için alan açan, sessiz ama güçlü öneriler."
            )
        case "Nostaljik":
            return MoodHeadlineCopy(
                headline: "Geçmişin sesi\nbugün burada.",
                description: "Özlemin için şehrin hafızasından seçtiklerimiz."
            )
        case "Gizemli":
            return MoodHeadlineCopy(
                headline: "Karanlık köşeler,\nparlak anlar.",
                description: "Şehrin bilinmeyeni keşfetmek için doğru gece."
            )
        case "Hassas":
            return MoodHeadlineCopy(
                headline: "Kendine nazik\nbir akşam.",
                description: "Kırılgan anlar için yumuşak, güvenli öneriler."
            )
        case "Sessiz":
            return MoodHeadlineCopy(
                headline: "Gürültüden uzak,\nhissin içinde.",
                description: "Sessizliğine saygı duyan, dingin seçenekler."
            )
        default:
            return MoodHeadlineCopy(
                headline: "Bugün şehir\nseni bekliyor.",
                description: "Hissinle örtüşen öneriler burada."
            )
        }
    }
}
