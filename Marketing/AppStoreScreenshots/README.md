# ONE App Store Screenshot Kit

Hazirlanan paket, `ONE` icin 6 adet App Store screenshot taslak kompozisyonu icerir.
Dosyalar vektor `svg` oldugu icin Figma, Sketch, Illustrator veya browser uzerinden kolayca duzenlenebilir.

## Paket Icerigi

- `01-gununu-tek-bir-sarkiyla-anlat.svg`
- `02-ruh-halini-renklerle-kaydet.svg`
- `03-mooduna-gore-kesfet.svg`
- `04-cevrenle-paylas.svg`
- `05-gecmisine-don-bak.svg`
- `06-aylik-ozetini-paylas.svg`

## Tasarim Yonelimi

- Yon: daha az reklam afisi, daha cok premium product marketing hissi
- Dil: `ONE`'in kendi arayuzundeki sakin, havadar ve tipografik yapiyi disariya tasiyan kompozisyon
- Kompozisyon: buyuk baslik, kisa destek metni, tek screenshot odagi, yumusak mood aksani
- Kontrast: acik sicak zeminler; sadece `04` sosyal ekraninda daha koyu bir sahne kullaniliyor
- Stil: gosteris yerine guven, sadelik ve gercek UI kalitesi on planda

## Cikis Boyutu

- Artboard: `1290 x 2796`
- Hedef: iPhone 6.9" App Store screenshot
- Ihtiyac olursa ayni oranla 1284 x 2778 veya 1242 x 2688 export alinabilir

## UI Capture Eslesmeleri

1. `01...svg`
   - Hedef ekran: `one/Features/Today/TodayCompletedView.swift`
   - Ic grafik: bugunun sarkisi + mood karti

2. `02...svg`
   - Hedef ekran: `one/Features/Today/MoodEventsSheet.swift` veya mood secim akisi
   - Ic grafik: renk secimi, mood etiketleri, secim hissi

3. `03...svg`
   - Hedef ekran: `one/Features/Discovery/DiscoverView.swift`
   - Ic grafik: muzik veya etkinlik onerileri yuklenmis state

4. `04...svg`
   - Hedef ekran: `one/Features/Circle/CircleView.swift`
   - Ic grafik: en az 3 arkadasli dolu sosyal feed

5. `05...svg`
   - Hedef ekran: `one/Features/Archive/MonthArchiveView.swift`
   - Ic grafik: takvim ve mood strip dolu state

6. `06...svg`
   - Hedef ekran: `one/Features/MonthlySummary/MonthlySummaryView.swift`
   - Ic grafik: kapak karti veya top tracks sayfasi

## Kullanim

- SVG dosyasini Figma'ya import et
- Cihaz icindeki placeholder alanina gercek uygulama ekran goruntusunu yerlestir
- Screenshot'u placeholder'dan biraz buyuk tut; sonra mask/crop ile cihaz icine oturt
- Placeholder metnini ve kesik cizgili kutuyu sil
- Basliklari gerekiyorsa TR veya EN locale icin kopyala
- PNG export al

## Yeni Stil Dili

- Basliklari daha sakin tut; UI'nin kendisi kahraman olsun
- Her karede tek screenshot kullan; kolaj mantigina kacma
- Mood renklerini sadece aksan olarak kullan; arka plani boya kovasina cevirmeyin
- Gercek cihaz capture'i yeterince iyi ise ekstra sticker, ok, not veya yapay highlight ekleme
- App Store seti, uygulamanin tasarim kalitesini abartmadan gostermeli

## Copy Seti

1. Gununu tek bir sarkiyla anlat
   - Her gun bir sarki sec, moodunu kaydet, renginle hatirla.

2. Ruh halini renklerle kaydet
   - Duygunu sec, tonunu belirle, gunune bir renk birak.

3. Mooduna gore kesfet
   - Muzik, etkinlik ve ilham dolu onerileri aninda gor.

4. Cevrenle paylas
   - Arkadaslarinin bugun ne hissettigini tek ekranda takip et.

5. Gecmisine donup bak
   - Gunlerini takvim, ritim ve renkler uzerinden yeniden yasat.

6. Aylik ozetini paylas
   - Ayinin sesini, modunu ve en cok dondugun sarkilari gor.

## Capture Notlari

- Light mode kullan
- Status bar temiz ve saat `9:41` olacak sekilde capture al
- Mumkunse gercek icerik kullan: sarki adi, sanatci, mood, arkadas feed'i
- Her ekranda tek mesaj ver; UI cok kalabalik gorunuyorsa crop yerine daha temiz state sec
- Screenshot sirasini App Store listing'de ayni sekilde koru
- Circle ve Summary ekranlarinda bos state kullanma; dolu ve hikaye anlatan capture sec
- Discovery ekraninda onerilerin gercekten dolu oldugu bir state sec; loading state kullanma
- Metinleri gereksiz buyutme; screenshot ile rekabete giren callout'lar ekleme
