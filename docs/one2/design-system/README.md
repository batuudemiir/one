ONE 2.0 bir **yazma ve kendini geliştirme** uygulaması: kullanıcı her gün bir soruya, bir söze ya da kendi gününe yazar; sabah niyetini belirler, akşam günü kapatır; yazdıkları zamanla bir Yolculuk'a dönüşür ve aynı soruya, aynı söze verdiği cevaplar değişimini gösterir. Ürün sistemi ve ekran dili Stoic'in yapısını izler: koyu-öncelikli zemin, hap kontroller, büyük başlık, yuvarlak kartlar, yüzen cam tab bar. İçerik, kopya, renk vurgusu ve yazı yüzleri ONE'ındır. Eski ONE (v3) markasından yalnız isim kalır.

Sistemin fikri: **sessiz, koyu bir defter; sesi yazının kendisi.** Arayüz nötr ve geri çekilir; renk yalnız veri (mood, duygu) ve tek bir mürekkep vurgusu için kullanılır.

## Ekran anatomisi (her sekme)

1. **Üst çubuk** (`TopBar`): `raised` hap ve 48pt yuvarlak kontroller. Bugün'de solda seri hapı, ortada selamlama, sağda profil; diğer sekmelerde sağa yaslı dönem hapı + filtre + ara.
2. **Sekme başlığı**: `screen-title`, küçük harf, sol hizalı ("keşfet", "yolculuk", "eğilimler"). Bugün'de başlık yerine selamlama ("iyi akşamlar").
3. **İçerik**: `surface` kartlar, `radius-lg`, kartlar arası `space-3`, bölümler arası `space-8`. Bölüm başlığı `title` + sağda "Tümünü gör ›" veya düzenle ikonu.
4. **Yüzen dock** (`TabBar`): cam tab bar + üstünde yüzen + hapı. İçerik altından kayar; son öğe dock'un üstünde bitecek kadar alt boşluk bırakılır.

Yazmanın üç kapısı: günün sorusu (`WeeklyThemeCard`), söz (`QuoteCard` → `QuoteReflection`), boş sayfa (+). Üçü de aynı editöre (`JournalEditor`) açılır.

Referans ekranlar: `ScreenBugun`, `ScreenSozler`, `ScreenKesfet`, `ScreenYolculuk`, `ScreenEgilimler`.

## Bilgi mimarisi

- Sekmeler: **Bugün · Sözler · Keşfet · Yolculuk · Eğilimler**. Profil Bugün'ün sağ üstünde.
- **+** sheet'i: Boş sayfa, Mood check-in, Günlük önerisi, Şablonlar, Kütüphane.
- Bugün: hafta şeridi → check-in kartı → Pratiklerin → Haftalık tema.
- Sözler: tam ekran söz kartları, dikey kaydırma. Her söz bir yazma başlangıcıdır: "Bunun hakkında yaz" → `QuoteReflection`. Aynı söze yazılanlar birikir ve karşılaştırılır.
- Keşfet: öne çıkan → içerik satırları (Günlükler, Sabah, Akşam, Duygu check-in'i).
- Yolculuk: gün başlıkları altında girdi kartları; dönem Günler/Haftalar/Aylar/Yıllar.
- Eğilimler: "GENEL İÇGÖRÜLER" altında mood çizgisi, duygu dağılımı, en sık etiketler.

## Ses ve kopya

- "Sen" dili, küçük harf başlıklar, kısa. Buton 1–3 kelime fiil.
- Ton: sakin yol arkadaşı; soru sorar, yargılamaz, abartmaz. "Harika iş!" değil "bugün kapandı."
- Kendini geliştirme dili serbest ama vaaz yok: öğüt vermek yerine uygulatan soru sor ("Bu hafta bunu nasıl uygularsın?"), sonuç vaat etme ("30 günde değişeceksin" yok).
- Check-in yankısı tek cümle, yargısız: "Adım adım da varılır; bugün de bir adımdı."
- Seri kırılınca suçlama yok: "Dün boş kaldı. İstersen şimdi doldurabilirsin."
- Emoji yok; ekran başına en fazla bir ünlem.
- Türkçe büyük harfte `i → İ` ("GENEL İÇGÖRÜLER").

## Renk

- **İki tema:** `gece` (varsayılan, saf siyah zemin) ve `gun` (kırık beyaz). Uygulama sistem ayarını izler; tasarım gece-önce yapılır, gün eşit özenle.
- **Nötrler:** `ground` zemin; `surface` kart; `raised` hap, kuyu, kart içi öğe; `glass` yüzen yüzey; `line` dekoratif kenar (check-in kartı çerçevesi); `line-strong` anlamlı kenar (bugün kutusu, seçilmemiş etiket). Metin: `ink`, `ink-muted`, `ink-faint`.
- **Eylem:** birincil buton renkli değil, kontrastlı: `primary` açık hap + `on-primary` koyu metin (gece), tersi (gün).
- **Tek vurgu:** `brand` (mürekkep mavisi) yalnız seri sayısı, mühür, rozet halkası, seçili etiket (`brand-soft`), odak halkası ve imleçtir. Ekranda bir yerde görünür.
- **Ritüel:** `sabah` ve `aksam` yalnız içerik kemeri ve ritüel işaretleri içindir; metin rengi değildir.
- **Mood skoru 1–5:** `score-1` gece mavisi → `score-3` gri → `score-5` amber (renk körlüğünde güvenli). Her zaman rakamla; dolgu üstünde `on-score-N`.
- **Duygu aileleri:** `emo-nese`, `emo-huzur`, `emo-enerji`, `emo-sevgi`, `emo-kaygi`, `emo-huzun`, `emo-ofke`, `emo-yorgun`; dolgu üstünde `on-emo-*`.
- **Durum:** `success`, `warning`, `danger` yalnız metin/ikon, her zaman bir kelimeyle.
- Tüm metin çiftleri iki temada 4.5:1+; `line-strong` `ground` ve `surface` üstünde 3:1+ (`raised` üstünde değil: orada kenar kullanma).

## Tipografi

- **Plus Jakarta Sans** (Google Fonts, Türkçe tam): başlıklar ve tüm arayüz. `screen-title` 44/48 700, `greeting` 28/34, `title` 24/30, `title-sm` 20/26, `headline` 17/24 600, `body` 16/24 500, `body-sm`, `callout`, `caption`.
- **Literata** (serif): yalnız yazının kendisi — soru (`prompt`), kullanıcı metni (`journal`), söz (`quote`), check-in yankısı (`affirmation`, italik). Arayüz ile yazıyı ayıran tek şey bu yüz değişimidir.
- **IBM Plex Mono**: saat (`time`, sağ üstte), geniş aralıklı bölüm etiketi ve rozet yazısı (`label`, 0.2em, büyük harf), büyük sayı (`numeral-lg`).
- iOS'ta üç yüz de gömülür ve `UIFontMetrics` ile Dynamic Type'a bağlanır; `screen-title` en fazla ×1.25 büyür.

## Boşluk, köşe, yüzey

- Ekran kenarı `space-4`; kart iç dolgusu `space-4`–`space-6`; kartlar arası `space-3`; bölümler arası `space-8`.
- Köşeler cömert: kartlar `radius-lg` (28), söz kartı `radius-xl` (36), bugün kutusu `radius-md` (18), her kontrol `radius-pill`.
- Kartlar gölgesiz; ayrım zemin tonuyla (`ground` → `surface` → `raised`). Gölge yalnız dock'ta (`shadow-float`).
- Dokunma hedefi en az 44pt; hap ve yuvarlaklar 48pt, skor diskleri 60pt.

## Hareket ve geri bildirim

- Tek eğri `cubic-bezier(0.2, 0.8, 0.2, 1)`. Basış 120ms `scale(0.97)`; chip 180ms; ekran geçişi 280ms; mühür 320ms.
- Kapanış: mühür 0.9 → 1.0 + opaklık, `.soft` haptik, hafta şeridinde günün tike dönmesi. Konfeti, parıltı, ses yok.
- Dock kaydırmada yerinde kalır; içerik cam altından geçer. Reduce Motion: yalnız opaklık. Reduce Transparency: `glass` → `raised`.

## İkonografi

- SF Symbols, `regular`; tab bar ikonları 24pt: Bugün `sun.max`, Sözler `quote.opening`, Keşfet `safari`, Yolculuk `book`, Eğilimler `chart.bar`. Önizlemelerdeki çizimler yer tutucudur.
- Seçili sekme ikon değiştirmez; `ground` hap içine alınır.
- İçerik görselleri (öne çıkan çizimler, kemer içleri) ONE'ın kendi illüstrasyonlarıdır; Stoic'in kuş maskotu ve çizimleri kullanılmaz.
- Emoji ve mood yüz ifadesi yok; skor rakam + renk + etiketle anlatılır.

## Logo

- Wordmark: Plus Jakarta Sans 700, "ONE". Çizilmiş logo dosyası henüz yok; tipografik set kullanılır.
- İkon yönü: `ground` (siyah) kare üstünde `primary` "ONE" ve altında `sabah` ince ufuk yayı; tinted/koyu iOS varyantında tek renk.

## Durumlar (her ekran için)

- **Yükleniyor:** `raised` iskelet çubukları, gerçek yerleşimde.
- **Boş:** çerçeveli kart + tek soru + tek eylem (Eğilimler boşken doğrudan `ScoreScale`).
- **Hata:** `danger` kelime + ne yapılacağı.
- **Çevrimdışı:** üstte `raised` hap şerit + `warning` ikon.

## Erişilebilirlik

- Increased Contrast: `line` → `line-strong`, `ink-faint` → `ink-muted`.
- Çok satırlı kartlar tek öğe okunur ("Mood check-in, 11:39, 5, Çok iyi, Minnettar").
- Seçili durum `.isSelected`; skor "4, İyi".
- En büyük Dynamic Type'ta hiçbir metin kırpılmaz; karolar tek sütuna düşer.

## Yapma

- Stoic'in metinleri, alıntı seçkisi, mentor karakterleri, kuş maskotu, logosu veya fotoğrafları.
- Başlık sonunda nokta ("keşfet.") — Stoic'in imzası; ONE başlıkları noktasızdır.
- Eski ONE: kor kırmızısı, Archivo, dokuz renkli mood paleti.
- Birincil butonu renkli yapmak; bir ekranda `brand`'i birden çok yerde kullanmak; konfeti, alev emojisi, neumorfizm.
