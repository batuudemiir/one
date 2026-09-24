# UX oturumundan motor oturumuna istekler

UX oturumu model ya da içerik değişikliği yapmaz; ihtiyaçlarını buraya yazar,
Batuhan motor oturumuna iletir (05_ux_promptlari.md, Paralel çalışma notları).

---

## 1. Duygu kataloğu → `emotions.tr.json` (UX-3, 23 Eylül 2026)

Kaynak: `one/ONE2/Features/Shared/Fixtures/EmotionCatalogFixture.swift`.
ID'ler kalıcı: `<aile>.<ad>`, küçük harf, ASCII. Aile ID'leri tokens.json
`emo-*` adlarıyla aynı. Sıra, check-in'deki gösterim sırasıdır.

| Aile | ID | Ad |
|---|---|---|
| nese | `nese.minnettar` | Minnettar |
| nese | `nese.sevincli` | Sevinçli |
| nese | `nese.umutlu` | Umutlu |
| nese | `nese.keyifli` | Keyifli |
| nese | `nese.gururlu` | Gururlu |
| huzur | `huzur.sakin` | Sakin |
| huzur | `huzur.rahat` | Rahat |
| huzur | `huzur.dingin` | Dingin |
| huzur | `huzur.guvende` | Güvende |
| huzur | `huzur.hafiflemis` | Hafiflemiş |
| enerji | `enerji.heyecanli` | Heyecanlı |
| enerji | `enerji.motive` | Motive |
| enerji | `enerji.merakli` | Meraklı |
| enerji | `enerji.canli` | Canlı |
| enerji | `enerji.odakli` | Odaklı |
| sevgi | `sevgi.sefkatli` | Şefkatli |
| sevgi | `sevgi.bagli` | Bağlı |
| sevgi | `sevgi.sevilmis` | Sevilmiş |
| sevgi | `sevgi.ozlemli` | Özlemli |
| sevgi | `sevgi.yakin` | Yakın |
| kaygi | `kaygi.kaygili` | Kaygılı |
| kaygi | `kaygi.gergin` | Gergin |
| kaygi | `kaygi.huzursuz` | Huzursuz |
| kaygi | `kaygi.tedirgin` | Tedirgin |
| kaygi | `kaygi.bunalmis` | Bunalmış |
| huzun | `huzun.huzunlu` | Hüzünlü |
| huzun | `huzun.yalniz` | Yalnız |
| huzun | `huzun.kirgin` | Kırgın |
| huzun | `huzun.eksik` | Eksik |
| ofke | `ofke.ofkeli` | Öfkeli |
| ofke | `ofke.sinirli` | Sinirli |
| ofke | `ofke.bikkin` | Bıkkın |
| ofke | `ofke.sabirsiz` | Sabırsız |
| yorgun | `yorgun.yorgun` | Yorgun |
| yorgun | `yorgun.uykulu` | Uykulu |
| yorgun | `yorgun.tukenmis` | Tükenmiş |
| yorgun | `yorgun.durgun` | Durgun |
| yorgun | `yorgun.isteksiz` | İsteksiz |

Toplam 38 duygu (her ailede 4–5).

## 2. İçgörü eşikleri (UX-3, bilgi)

View data her içgörü kartı için `InsightState.insufficient(required:current:)`
taşır (E10 eşikleri: çizgi 3, ortalama 7, dağılım 5, etiket ilişkisi 21).
E10'un `InsightState.insufficient(needed:)` dönüşü UX-11'deki adaptörde bu
iki değere çevrilecek; motorun `needed`'ı **eşik** mi **kalan** mı döndürdüğü
netleşirse adaptör ona göre yazılır.
