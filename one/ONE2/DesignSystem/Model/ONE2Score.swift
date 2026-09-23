//
//  ONE2Score.swift
//  ONE 2.0
//
//  1–5 mood skoru: etiket ve renk. Skor her zaman rakam + renk + etiketle
//  anlatılır; yüz ifadesi yok. Skor 3'ün tam etiketi "İdare eder";
//  "İdare" yalnız kompakt skor diskinin altında.
//

import SwiftUI

enum ONE2Score {
    static let range = 1...5

    static func label(_ score: Int, compact: Bool = false) -> String {
        switch score {
        case 1: return one2String("one2.score.1")
        case 2: return one2String("one2.score.2")
        case 3: return one2String(compact ? "one2.score.3.compact" : "one2.score.3")
        case 4: return one2String("one2.score.4")
        default: return one2String("one2.score.5")
        }
    }

    /// VoiceOver: "4, İyi".
    static func accessibilityLabel(_ score: Int) -> String {
        "\(score), \(label(score))"
    }

    static func fill(_ score: Int) -> Color { ONE2Color.score(score).fill }
    static func onFill(_ score: Int) -> Color { ONE2Color.score(score).on }
}
