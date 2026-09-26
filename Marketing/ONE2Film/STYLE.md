# ONE 2.0 film stili

İlk tanıtım filminde (`ONE2_film_*.mp4`) onaylanan dil. Her yeni film bu
kurallarla yapılır. Üst kurallar: `docs/one2/06_premium_his.md` (niyet,
hareket, müzik) ve `docs/one2/design-system/README.md` (renk, yazı, bileşen).

## Tek cümlelik özet

Siyah zemin, tek bir çizgi, kelime kelime yükselen yazı. Her kare tek bir
fikir taşır. Hareket tek bir eğriyle akar ve kapanışta durur.

## Biçim

| | |
|---|---|
| Süre | 30 sn = 72 BPM'de 36 vuruş. Sahne sınırları vuruşa denk gelir |
| Kare | 30 fps. Ekran filmleri 1080×1920 (9:16); genel film ayrıca 1920×1080 |
| Zemin | `ground` (#000). Doku, gradyan, fotoğraf yok |
| Güvenli alan | Başlık 1590, alt cümle 1672 (9:16). Alttaki %15 sosyal medya arayüzüne kalır |

## Tek çizgi

Filmi 3u kalınlığında tek bir çizgi taşır. Sahneler arasında kesme yerine bu
çizgi biçim değiştirir (`morph`, 0.6–0.9 sn):

- Açılışta başlığın altında ufuk yayı olur.
- Ekran filmlerinde ekranın çerçevesi olur ve kamerayla birlikte hareket eder.
- Kapanışta wordmark'ın altındaki yay olur.

Rengi `ink`. Çerçeve olduğunda `line-strong`'a döner. Yalnız mühür anında
`brand` olur.

## Yazı hareketi

- **Başlık:** Plus Jakarta Sans 700, 60px. Kelimeler 70ms arayla, 28px
  aşağıdan, 550ms'de yükselir. Çıkışta hepsi birlikte 280ms'de söner ve
  14px yukarı kayar.
- **Alt cümle:** Sans 500, 36px, `ink-muted`. Başlıktan 350ms sonra gelir.
- **Kullanıcının yazısı:** Literata, harf harf yazılır (16–20 harf/sn),
  imleç `brand` renginde. Her harf sessiz bir tuş sesi.
- **Etiket:** IBM Plex Mono 500, 22px, 0.2em aralık, büyük harf,
  `ink-faint` ("SABAH · 07:12", "BUGÜN").
- **Açılış sözcüğü:** Sans 800, 150px, tek kelime ve nokta ("Bugün.").
- **Wordmark:** "ONE", Sans 800, 210px, harf harf yükselir.

## Hareket

- Tek eğri: `cubic-bezier(0.2, 0.8, 0.2, 1)`. Sabit hızlı hareket yok,
  zıplama yok.
- Basış: 0.97, 120ms iniş, 180ms dönüş. Seçimden sonra 300ms bekleme.
- Kamera: odak noktasına 0.95 sn'de yaklaşır (ölçek 1.6 → 2.3–2.55). Odak
  dışındaki bloklar %16'ya söner. Dock yakınlaşmada tamamen kaybolur.
- Ritim: açılış ve kurulum hızlı, odak sahneleri orta hızda, kapanış yavaş.
  Filmin tek durağı tamamlanma anıdır; ondan sonra bir süre hiçbir şey
  kıpırdamaz.

## İllüstrasyon

Çizgi sanatı; kalınlık 2.2–3u, uçlar yuvarlak. Kendi başına dekor değil,
bir işlevi gösterir:

- Güneş `sabah`: ışınlar döner ve nefes alır.
- Ay `aksam`: salınır, yanında yıldızlar yanıp söner.
- Irmak `ink-faint`: dalga çizgileri akar.
- Mühür `brand`: 0.9 → 1.0, tik çizilir.
- Tik: `pathLength=1` çizim, 300ms.

Renk kuralı: bir karede `brand` en fazla bir yerde. `sabah` ve `aksam`
yalnız ritüel işaretlerinde. Skor ve duygu renkleri yalnız veri olarak.

## Kopya: ONE'a uyarlanmış Apple dili

Apple'ın ürün kopyasından alınanlar: tek büyük fikir, kısa ve kesik
cümleler, üçleme, simetri ve tekrar, "sen" odağı, önce fayda sonra özellik.
ONE'ın sesinden alınanlar: abartısız, yargısız, olgu söyleyen.

Kalıp: her sahnede **başlık + alt cümle**.

- **Başlık** bir iddiadır: 2–5 kelime, çoğu zaman simetrik ya da iki kesik
  cümle ("Sabahı aç. Akşamı kapat.", "Haftan, bir bakışta.", "Boş sayfa
  yok.").
- **Alt cümle** özelliği söyler: 5–12 kelime, sen dili ("Boş kalan günü
  sonradan da yazabilirsin.").
- **Kapanıştan önce üçleme gelir**, her parça kendi vuruşunda ("Bir soru.
  Bir cevap. Bir gün.").

Kullanılmaz:
- Sıfat yağmuru ve süperlatif: "mükemmel", "en iyi", "devrim".
- Sonuç vaadi: "hayatını değiştir".
- Uygulamayı özne yapmak: "ONE seni bekliyor".
- Emoji, üst üste ünlem, üç nokta.
- Stoic'e ait metin, görsel ya da karakter.

Uygulama içi metinler (kart cümleleri, sorular, yankılar) repodaki
içerikten alınır: `one/ONE2/Content/Bundled/*.tr.json` ve bileşen kartları.

## Ekran filmi iskeleti (9:16, 36 vuruş)

| Vuruş | Bölüm | İçerik |
|---|---|---|
| 0–4 | Açılış | Ekranın adı ("Bugün."), altında ufuk yayı ve tek cümlelik vaat |
| 4–9 | Kurulum | Yay ekran çerçevesine döner, bloklar sırayla yerine oturur |
| 9–29 | Dört odak | Her biri 5 vuruş: kamera bir bloğa yaklaşır, bir etkileşim gösterilir, başlık ve alt cümle |
| 29–33 | Toparlama | Kamera geri çekilir, üçleme vuruşlarda gelir |
| 33–36 | Kapanış | Çerçeve yaya döner, "ONE", "App Store'da", ekran etiketi |

## Ses

- Müzik: 72 BPM, Re majör, piyano benzeri ton ve pad. Akorlar sahne
  sınırlarında değişir. Tamamlanma anında gerilim çözülür (sus4 → D).
  Partisyon her filmin `screens/<ad>.score.json` dosyasındadır.
- Ses efekti en fazla üç aile, hepsi kısık: `key` (dokunuş, harf), `paper`
  (kart ya da kurulum geçişi), `seal` (tamamlanma, filmde bir kez).
- Yayın için müzik lisanslı bir parçayla değiştirilir: 60–80 BPM, vokalsiz.

## Seri

| # | Ekran | Durum |
|---|---|---|
| 1 | Bugün | `screens/bugun.html` |
| 2 | Sözler | — |
| 3 | Keşfet | — |
| 4 | Yolculuk | — |
| 5 | Eğilimler | — |

## Kontrol

- [ ] Her karede tek fikir; `brand` en fazla bir yerde.
- [ ] Sahne sınırları vuruşta; tamamlanma anında müzik çözülüyor.
- [ ] Başlık 2–5 kelime, alt cümle 5–12 kelime, sen dili.
- [ ] Uygulama metinleri repodaki içerikten alınmış.
- [ ] Başlıklar dimmed UI'nin üstünde okunuyor (perde açık).
- [ ] `--snap` ile açılış, her odak ve kapanış kareleri kontrol edildi.
