//
//  QuotesFixture.swift
//  ONE 2.0
//
//  ÖRNEK VERİ. Sözler ONE'ın kendi seçkisi olacak; buradakiler yer
//  tutucu (atasözleri ve bu fixture için yazılmış cümleler). Stoic'in
//  seçkisinden alıntı yok.
//

import Foundation

nonisolated enum QuotesFixture {

    static let many: [QuoteCardData] = [
        QuoteCardData(id: "fx_q_001", text: "Acele eden, aynı yolu iki kez yürür.", source: "Atasözü",
                      kind: .proverb, background: .photo("fx_bg_dusk"), writtenCount: 2, isLiked: true),
        QuoteCardData(id: "fx_q_002", text: "Bugün küçük bir adım atmam yeterli.", source: "Olumlama",
                      kind: .affirmation, background: .token("emo-huzur"), writtenCount: 0, isLiked: false),
        QuoteCardData(id: "fx_q_003", text: "Damlaya damlaya göl olur.", source: "Atasözü",
                      kind: .proverb, background: .photo("fx_bg_sea"), writtenCount: 1, isLiked: false),
        QuoteCardData(id: "fx_q_004", text: "Yorgunluk da bir bilgi; ne söylediğini dinle.", source: "Düşünce",
                      kind: .thought, background: .token("score-1"), writtenCount: 0, isLiked: false),
        QuoteCardData(id: "fx_q_005", text: "Bildiğini yapmak, bilmediğini sormaktan kolay değildir.", source: "Söz · örnek",
                      kind: .quote, background: .photo("fx_bg_forest"), writtenCount: 0, isLiked: true),
    ]

    static let few: [QuoteCardData] = Array(many.prefix(2))

    static let empty: [QuoteCardData] = []

    static let modes: [QuoteFeedModeData] = [
        .forYou,
        .path(id: "fx_path_sakin", title: "Sakin", isLocked: false),
        .path(id: "fx_path_cesur", title: "Cesur", isLocked: true),
        .path(id: "fx_path_filozof", title: "Filozof", isLocked: true),
        .kind(.affirmation), .kind(.quote), .kind(.proverb), .kind(.thought),
        .favorites, .written,
    ]
}
