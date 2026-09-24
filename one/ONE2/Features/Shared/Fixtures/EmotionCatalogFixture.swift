//
//  EmotionCatalogFixture.swift
//  ONE 2.0
//
//  ÖRNEK VERİ. Duygu kataloğu: 8 aile × 4–6 duygu. ID'ler kalıcı
//  (`<aile>.<ad>`, küçük harf, ASCII) ve içerik paketindeki
//  `emotions.tr.json`'a taşınacak (docs/one2/UX_istekleri.md). Adları
//  kullanıcı seçer; teşhis koyan ad yok.
//

import Foundation

nonisolated enum EmotionCatalogFixture {

    static let all: [EmotionItem] = [
        // Neşe
        item("nese.minnettar", "Minnettar", .nese),
        item("nese.sevincli", "Sevinçli", .nese),
        item("nese.umutlu", "Umutlu", .nese),
        item("nese.keyifli", "Keyifli", .nese),
        item("nese.gururlu", "Gururlu", .nese),
        // Huzur
        item("huzur.sakin", "Sakin", .huzur),
        item("huzur.rahat", "Rahat", .huzur),
        item("huzur.dingin", "Dingin", .huzur),
        item("huzur.guvende", "Güvende", .huzur),
        item("huzur.hafiflemis", "Hafiflemiş", .huzur),
        // Enerji
        item("enerji.heyecanli", "Heyecanlı", .enerji),
        item("enerji.motive", "Motive", .enerji),
        item("enerji.merakli", "Meraklı", .enerji),
        item("enerji.canli", "Canlı", .enerji),
        item("enerji.odakli", "Odaklı", .enerji),
        // Sevgi
        item("sevgi.sefkatli", "Şefkatli", .sevgi),
        item("sevgi.bagli", "Bağlı", .sevgi),
        item("sevgi.sevilmis", "Sevilmiş", .sevgi),
        item("sevgi.ozlemli", "Özlemli", .sevgi),
        item("sevgi.yakin", "Yakın", .sevgi),
        // Kaygı
        item("kaygi.kaygili", "Kaygılı", .kaygi),
        item("kaygi.gergin", "Gergin", .kaygi),
        item("kaygi.huzursuz", "Huzursuz", .kaygi),
        item("kaygi.tedirgin", "Tedirgin", .kaygi),
        item("kaygi.bunalmis", "Bunalmış", .kaygi),
        // Hüzün
        item("huzun.huzunlu", "Hüzünlü", .huzun),
        item("huzun.yalniz", "Yalnız", .huzun),
        item("huzun.kirgin", "Kırgın", .huzun),
        item("huzun.eksik", "Eksik", .huzun),
        // Öfke
        item("ofke.ofkeli", "Öfkeli", .ofke),
        item("ofke.sinirli", "Sinirli", .ofke),
        item("ofke.bikkin", "Bıkkın", .ofke),
        item("ofke.sabirsiz", "Sabırsız", .ofke),
        // Yorgunluk
        item("yorgun.yorgun", "Yorgun", .yorgun),
        item("yorgun.uykulu", "Uykulu", .yorgun),
        item("yorgun.tukenmis", "Tükenmiş", .yorgun),
        item("yorgun.durgun", "Durgun", .yorgun),
        item("yorgun.isteksiz", "İsteksiz", .yorgun),
    ]

    static func emotion(_ id: String) -> EmotionItem {
        all.first { $0.id == id } ?? all[0]
    }

    private static func item(_ id: String, _ name: String, _ family: ONE2EmotionFamily) -> EmotionItem {
        EmotionItem(id: id, name: name, family: family)
    }
}
