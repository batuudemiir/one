# ONE 2.0 — Premium his: niyet kuralları

Kaynak: leo (@leomeethewoo), "Make your product videos look expensive
(Apple Framework)", 25 Eylül 2026. Makale ürün videosu hakkında; buradaki
kurallar onu hem uygulama içi harekete hem tanıtım videolarına uyarlıyor.
Değerler `design-system/README.md` ile aynı; çelişirse README kazanır.

## Tez

Pahalı görünüm eklenen efektten gelmez, **her tercihin bilinçli
görünmesinden** gelir. İzleyici tek tek kararları tartmaz, tutarlılığı
sezer ve bunu kalite diye okur. Ucuzluk rastgelelikten doğar: fazla efekt,
alakasız ses, uymayan müzik.

İkinci fikir: premium his bir **aidiyet** duygusudur. ONE'ın videosu yeni
biriyle tanıştırmaktan çok, zaten yazan birine "bu senin defterin"
dedirtmeli.

Bu yüzden ONE için iki soru her karardan önce sorulur:

1. Bu tercih bir kurala dayanıyor mu, yoksa o an öyle mi oldu?
2. Bunu çıkarsak ne kaybolur? Cevap "hiçbir şey" ise çıkar.

## 1. Marka kuralları (sabit, her üründe aynı)

Makale "kendine üç renk koy" diyor. ONE'da bu seçim yapıldı:

| Rol | Token | Nerede |
|---|---|---|
| Zemin | `ground` (gece saf siyah, gün kırık beyaz) | Her karenin arka planı |
| Eylem | `primary` açık hap + `on-primary` | Ekran başına tek birincil eylem |
| Vurgu | `brand` (mürekkep mavisi) | Mühür, seri sayısı, odak. **Ekran başına bir yer** |

`sabah` ve `aksam` yalnız ritüel kemerinde; mood skoru ve duygu renkleri
yalnız veriyi gösterirken. Bunların dışında renk yok.

- **Yazı:** Plus Jakarta Sans arayüz, Literata yazının kendisi, IBM Plex
  Mono sayı ve saat. Dördüncü yüz yok.
- **İkon:** SF Symbols `regular`. Emoji ve yüz ifadesi yok.
- **Ses:** uygulamada ses yok (README › Hareket). Tanıtım videosunda müzik
  ve ses tasarımı aşağıdaki kurallarla.

**Ucuzlatan şeyler (yapılmaz):** konfeti, parıltı, alev, zıplayan panel,
doğrusal hareket, ekranda birden çok `brand`, renkli birincil buton,
"Harika!" gibi abartı, dikkat çekmek için titreşim, videoda hype müzik
ve efekt sesi yağmuru.

## 2. Tasarım: önce kare, sonra hareket

Makale sırayı koyuyor: iyi tasarım yoksa animasyon kurtarmaz. ONE'da
her ekran ve her video karesi şu dört kuraldan geçer:

| Kural | Uygulamada | Videoda |
|---|---|---|
| **Bir kare, bir fikir** | Akışta her adımda tek soru; ekran başına tek birincil eylem | Her çekim tek cümle, tek eylem |
| **Nefes payı** | Bölümler arası `space-8`, kart içi `space-4`–`space-6` | Ana nesnenin çevresi en az kadrajın üçte biri boş |
| **Ana nesne merkezde** | Soru, skor ölçeği, mühür ekranın optik ortasında | Telefon ya da kart kadrajın ortasında |
| **Zemin geri çekilir** | `ground` → `surface` → `raised`; gölge yalnız dock'ta | Düz `ground`; doku, gradyan, bulanık fotoğraf yok |

Yeni bir ekran ya da video önce Figma'da kare kare çizilir. Hareket, kareler
onaylandıktan sonra eklenir.

## 3. Hareket

Kod: `ONEAnimation.One2` (`one/UI/DesignSystem/ONEAnimation+One2.swift`).

**Tek eğri:** `cubic-bezier(0.2, 0.8, 0.2, 1)`. Hızlı çıkar, yavaş oturur.
Doğrusal hareket yok.

| Olay | Süre | Hareket | Token |
|---|---|---|---|
| Basış | 120ms | `scale(0.97)` | `press`, `pressScale` |
| Çip, seçim | 180ms | dolgu ve halka | `chip` |
| Ekran ve adım geçişi | 280ms | kayma + opaklık | `screen` |
| Skor seçiminden sonra | 300ms bekle | sonra adım geçişi | `stepAdvanceDelay` |
| Mühür | 320ms, tek sefer | 0.9 → 1.0 + opaklık | `seal`, `one2SealEntrance` |

- **Ritim sabit değil.** Seçim anları kısa (120–180ms), geçişler orta
  (280ms), kapanış en ağır (320ms + bekleme). Akış hızlanıp yavaşlar ve
  kapanışta durur.
- **Kesme yerine bağ.** Adımlar arası geçiş aynı yönden akar: ileri sağdan,
  geri soldan. Sheet alttan gelir, alta gider. Bir öğe iki ekranda
  varsa (seri hapı, mühür) yerinden kopmadan taşınır. Sert kesme yalnız
  sekme değişiminde.
- **Zıplama yok.** Overshoot yalnız jestin hız taşıdığı yerde
  (`dragSnapBack`).
- **Reduce Motion:** yalnız opaklık, `reducedFade`.

## 4. Dokunuş (haptik)

Makalenin ses tasarımı kuralı uygulamada haptiğe karşılık geliyor: her
titreşim bir şey söylemeli, söylemiyorsa çıkar.

| An | Haptik |
|---|---|
| Skor, duygu, çip seçimi | `ONEHaptics.pick()` (selection) |
| Kapanış mührü | `ONEHaptics.one2Seal()`: tek, yumuşak |
| Hata | `ONEHaptics.error()` |
| Diğer her şey | Yok |

- Bir etkileşimde en fazla bir haptik. v3'teki dört adımlı kayıt dizisi
  ONE 2.0'a taşınmaz.
- Basış, kaydırma, sekme değişimi, sayfa açılışı sessiz.
- Haptik görsel olayla aynı karede çalar; önce ya da sonra değil.

## 5. Tanıtım filmi (web ve sosyal medya)

Makalenin çerçevesi en doğrudan burada uygulanır. Hedef: 30 saniye,
16:9 (site) ve 9:16 (sosyal) iki kesim, aynı kareler.

### Kurgu

| # | Süre | Kare | Ekrandaki cümle |
|---|---|---|---|
| 1 | 0–3s | Siyah zemin, ortada "ONE" wordmark belirir | — |
| 2 | 3–7s | Telefon merkezde, sabah ekranı; niyet satırı yazılır | Sabah niyetini koy. |
| 3 | 7–11s | Günün sorusu kartı büyüyerek editöre açılır, Literata metin akar | Her gün bir soru. Cevap senin. |
| 4 | 11–15s | Skor ölçeği; 4 seçilir, duygu çipi dolar | Nasıl olduğunu sen adlandır. |
| 5 | 15–19s | Söz kartı dikey kayar, "Bunun hakkında yaz" | Bir söz, bir sayfa. |
| 6 | 19–24s | Yolculuk: aynı soruya aylar arayla iki cevap yan yana | Aynı soru, farklı zamanlar. |
| 7 | 24–28s | Akşam: "Günü kapat", mühür iner, hafta şeridinde gün tike döner | Akşam günü kapat. |
| 8 | 28–30s | Siyah zemin, wordmark ve App Store rozeti | ONE |

- Her kare tek fikir; cümleler 5–12 kelime, sen dili, emoji ve ünlem yok.
- Geçişler **ortak öğe** üzerinden: 2→3 kart büyüyüp editör olur, 3→4
  editörün alt çubuğu ölçeğe dönüşür, 6→7 hafta şeridi kaymadan kalır.
  Düz kesme yalnız 1→2 ve 7→8'de, müziğin vuruşuyla.
- **Ritim:** 2–5 hızlanır (4 saniye), 6 yavaşlar (5 saniye, karşılaştırma
  okunmalı), 7 filmin tek durağıdır: mühürden sonra 1 saniye hiçbir şey
  hareket etmez.
- Uygulama görüntüleri gerçek ekranlardan alınır; içerik ONE'ın kendi
  soru, söz ve temalarıdır (Stoic metni, görseli ya da maskotu yok).
- Renk yalnız marka kurallarından: `ground`, `primary`, `brand`; mood
  renkleri yalnız 4. karede veri olarak.

Uygulama: `Marketing/ONE2Film/` (kaynak, iki kesim ve yeniden üretme
adımları).

### Müzik

| BPM | His | ONE için |
|---|---|---|
| 60–80 | Sinematik, köklü | **Akşam ve lansman filmi.** Piyano ya da yaylı, tek enstrüman öne |
| 90–110 | Akıcı, zahmetsiz | **Sabah ve özellik kesitleri.** Yumuşak elektronik, akustik gitar |
| 115–123 | Kinetik, sofistike | Kullanılmaz: defterin sesi değil |
| 124+ | Hype | Kullanılmaz |

- Bir filmde tek parça. Kesmeler vuruşa oturur; müzik kareyi sürmez,
  karenin ritmine eşlik eder.
- Vokal ve sözlü parça yok; ekrandaki cümleyle yarışır.
- Aynı tür film (ör. her özellik kesiti) hep aynı müzik ailesinden seçilir.

### Ses tasarımı

İzinli ses aileleri, filmde toplam en fazla üç:

1. Klavye ya da kalem: yazma anında, çok düşük.
2. Mühür: kapanışta tek, yumuşak, kuru bir vuruş.
3. Sayfa ya da kart: ortak öğe geçişlerinde hafif bir hışırtı.

Whoosh, çın, zil, kalabalık alkış yok. Son turda film baştan dinlenir ve
her ses için sorulur: yüksek mi, yersiz mi, anlamaya ya da izlemeye katkısı
var mı? Katkısı yoksa silinir.

## 6. App Store önizleme videosu

Apple kuralı: önizleme yalnız uygulamanın kendi ekran kaydını gösterir.
Cihaz çerçevesi, el ve dışarıdan çekim yok. 15–30 saniye. Ölçü ve biçimi
yüklemeden önce App Store Connect'teki güncel listeden doğrula.

Premium his burada kurgudan ve içerikten gelir:

- Tanıtım filmindeki 2–7. kareler, gerçek ekran kaydı olarak aynı sırayla.
- Kayıt temiz bir demo hesabıyla alınır: dolu hafta şeridi, anlamlı seri,
  ONE'ın kendi içeriği. Gerçek kullanıcı verisi kullanılmaz (repo public;
  kayıtlar da repoya girmez).
- Gece teması; saat 9:41, tam pil, bildirim yok.
- Metin katmanı tanıtım filmiyle aynı cümleler, Plus Jakarta Sans.
- Müzik 60–80 BPM; ses aileleri yukarıdaki üçüyle sınırlı.
- Dokuz dilin her biri için kendi kaydı ve cümleleri; yerelleştirilmemiş
  metinli video yüklenmez.

## 7. Üretim sırası

1. **Kurallar:** bu doküman ve README. Yeni bir renk, yüz, müzik türü
   gerekiyorsa önce burada karar verilir.
2. **Kareler:** Figma'da kare kare storyboard. Her kare dört tasarım
   kuralından geçer.
3. **Hareket:** tek eğri, tablodaki süreler, ortak öğe geçişleri.
4. **Müzik:** önce BPM, sonra tür.
5. **Ses:** en fazla üç aile.
6. **Çıkarma turu:** baştan izle, her efekti, sesi ve kareyi "çıkarsak ne
   kaybolur" sorusundan geçir.

## 8. Kontrol listesi

- [ ] Her karede tek fikir, tek birincil eylem.
- [ ] Ekranda `brand` en fazla bir yerde.
- [ ] Ana nesne merkezde, çevresinde nefes payı var.
- [ ] Doğrusal hareket yok; tüm hareket tek eğride.
- [ ] Zıplama yalnız jestte.
- [ ] Etkileşim başına en fazla bir haptik.
- [ ] Reduce Motion'da yalnız opaklık.
- [ ] Videoda tek müzik, 60–110 BPM, vokalsiz.
- [ ] En fazla üç ses ailesi; çıkarma turu yapıldı.
- [ ] Kopya: sen dili, 5–12 kelime, emoji ve ünlem yok, sonuç vaadi yok.
- [ ] Stoic'e ait metin, görsel, renk ya da karakter yok.

## Açık kararlar

Kod ile tasarım dokümanı arasında fark var. Doküman kazanır ama v3 kabuğu
App Store'da bu token'ları kullandığı için değişiklik karar bekliyor:

| Konu | Doküman | Kod (v3) |
|---|---|---|
| Eğri | `cubic-bezier(0.2, 0.8, 0.2, 1)` | `ONEAnimation.easing*`: `(0.2, 0.9, 0.25, 1)` |
| Basış ölçeği | 0.97 | `buttonPressScale` 0.96 (`.onePressable`) |
| Ekran geçişi | 280ms eğri | `screenTransition` spring, response 0.44 |
| "Tek eğri" | Tek eğri | `ONEAnimation` yorumu: eğri + spring birlikte |

Şimdilik ONE 2.0 bileşenleri `ONEAnimation.One2`'yi okur, v3 değerleri
yerinde kalır. Seçenekler: (a) `.onePressable`'ı ONE2 bayrağına göre
0.97'ye çevirmek, (b) v3 relaunch'ta silinince `One2` değerlerini ana
token'lara taşımak.
