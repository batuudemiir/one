# ONE 2.0 — UX spesifikasyonu (ana belge)

Sürüm 1.0 · 24 Eylül 2026 · Sahibi: UX oturumu (`one2/ux`)

Bu belge uygulamanın **tüm** kullanıcı deneyimini tanımlar. Öncelik sırası:

1. Görsel değerler (renk, yazı, boşluk, köşe, hareket): `docs/one2/design-system/README.md` + `tokens.json`. Her zaman kazanır.
2. Ekranlar, akışlar, durumlar, kopya, erişilebilirlik: **bu belge (07)**. 05'teki ekran tariflerinin yerine geçer.
3. Sahiplik, oturum kuralları, commit düzeni: `05_ux_promptlari.md` (değişmedi).
4. Motor davranışı ve veri: `04_arka_plan_motorlari.md`. UX motor mantığı yazmaz; ihtiyacını `UX_istekleri.md`'ye yazar.

Marka adı henüz kesin değil (aday: "loop"). Kodda ve kopyada ad tek yerden gelir: `AppBrand.name` (şimdilik "ONE"). Hiçbir metne ad elle yazılmaz.

---

## 1. Ürün özü

Kullanıcı her gün bir soruya, bir düşünürün sözüne ya da kendi gününe yazar. Sabah niyetini kurar, akşam günü kapatır. Yazdıkları zamanla bir Yolculuk'a dönüşür; aynı soruya ya da söze aylar sonra verdiği cevaplar değişimini gösterir.

**Ana fikir:** aynı soru, farklı sen.
**İçerik:** filozofların, psikologların ve düşünürlerin kaynaklı sözleri, her birine eşlenmiş bir yazma sorusu.
**Yapı:** Stoic'in ekran sistemi. **Ses ve içerik:** ONE'ın.

## 2. UX ilkeleri (her karar bunlarla test edilir)

1. **Yazı merkezde.** Her ekranın en fazla iki dokunuş uzağında bir yazma kapısı vardır. Arayüz geri çekilir; yazı Literata ile öne çıkar.
2. **Tek birincil eylem.** Her ekranda tek bir `primary` hap. İkincil eylemler metin ya da ikon.
3. **En kısa yol her zaman açık.** Her akışta zorunlu olan yalnız skor adımıdır; geri kalan her şey atlanabilir. Atlamak cezalandırılmaz, "boş kaldı" denmez.
4. **Soru sorar, öğüt vermez.** Kopya yargılamaz, sonuç vaat etmez, abartmaz.
5. **Değişimi görünür kıl.** Geçmiş cevap, uygun olduğu her yerde yeni cevabın yanında görünür (soruda, sözde, Eğilimler'de).
6. **Kaybolan veri yok.** Her yazı adımı otomatik taslak; kapatmak asla veri kaybettirmez; silme her zaman onay ister.
7. **Sakin geri bildirim.** Konfeti, ses, parıltı, alev emojisi yok. Tek kutlama: mühür.
8. **Önce erişilebilir.** AX5'te kırpılan metin yok, her kontrol 44 pt, her şey VoiceOver ile tamamlanabilir.

## 3. Bilgi mimarisi

### 3.1 Sekmeler (yüzen cam dock)

| Sekme | İkon (SF) | Rol |
|---|---|---|
| Bugün | `sun.max` | Günün ritüeli, pratikler, haftalık tema |
| Sözler | `quote.opening` | Tam ekran söz akışı, düşünürler |
| Keşfet | `safari` | Rehberli günlükler, temalar, koleksiyonlar, düşünürler |
| Yolculuk | `book` | Tüm girdiler, takvim, arama |
| Eğilimler | `chart.bar` | İçgörüler, değişim çiftleri |

- Dock'un üstünde yüzen **+** hapı → Yaz sheet'i (§5.13).
- Profil sekme değildir: Bugün'ün sağ üstündeki yuvarlak.
- Sekme değiştirince her sekmenin gezinme yığını korunur; aktif sekmeye tekrar dokunmak kökü ve en üste kaydırmayı getirir.

### 3.2 Sunum türleri (kural)

| Tür | Ne için |
|---|---|
| Push (NavigationStack) | Aynı sekmede derinleşme: girdi detayı, düşünür sayfası, içerik detayı, ayar alt sayfaları |
| Sheet (`.medium` / `.large`) | Kısa seçim ve bilgi: + menüsü, filtre, dönem, geri doldurma, arka plan seçici, onaylar |
| fullScreenCover | Odak isteyen akışlar: check-in ve ritüel akışları, editör, söze yazı, rehberli günlük, onboarding, paywall, kapanış |
| Menü (`Menu`) | 2–6 seçenekli anlık seçim: mod hapı, "···" |
| Alert | Yalnız geri alınamaz silme ve hata durumları |

fullScreenCover içinde başka bir fullScreenCover açılmaz; akış içindeki derinleşme push ya da sheet ile yapılır.

### 3.3 Derin bağlantılar

`one://today` · `one://checkin` · `one://ritual/morning` · `one://ritual/evening` · `one://write?prompt=<id>` · `one://quote/<id>` · `one://quote/<id>/reflect` · `one://thinker/<id>` · `one://explore/<contentID>` · `one://entry/<id>` · `one://journey?date=YYYY-MM-DD` · `one://insights` · `one://paywall?source=<s>` · `one://profile` · `one://resurface/<entryID>`

Bildirim, widget ve paylaşım bağlantıları bu listeden birine gider. Kilit açıksa önce kilit ekranı, sonra hedef.

---

## 4. Genel kabuk

### 4.1 Üst çubuk (`TopBar`)
- Bugün: solda seri hapı (alev ikonu yok; mono sayı brand renginde + "gün"), ortada selamlama, sağda profil yuvarlağı (ad baş harfi ya da foto).
- Diğer sekmeler: sağa yaslı kontroller (dönem hapı, filtre, ara). Başlık altında büyük `screen-title`, küçük harf, noktasız.
- Kaydırınca büyük başlık üst çubuğa küçülerek taşınır (inline, `headline`); üst çubuk `ground` rengine opaklaşır.

### 4.2 Dock
- İçerik camın altından kayar; son içerik dock + 24 pt üstünde biter.
- Klavye açıkken ve fullScreenCover'da dock görünmez.
- Seçili sekme: ikon değişmez, `ground` hap içine alınır. Etiketler her zaman görünür (caption).

### 4.3 Genel
- Ekran kenarı 16 pt; kartlar arası 12 pt; bölümler arası 32 pt.
- Bölüm başlığı: `title` + sağda "Tümünü gör ›" ya da düzenle ikonu.
- Çekerek yenileme yalnız Keşfet ve Sözler'de (içerik güncellemesi). Diğer ekranlar yerel veri; yenileme yok.
- Tema: sistemi izler; Profil'den Gece / Gün / Sistem.

---

## 5. Ekranlar

### 5.1 Bugün

**Yukarıdan aşağı:**
1. TopBar (4.1). Selamlama saate göre: 05–12 "günaydın", 12–18 "iyi günler", 18–05 "iyi akşamlar"; ad varsa ikinci satırda `ink-muted`.
2. **WeekStrip**: 7 gün; durumlar `done` (dolu disk + tik), `half` (yarım disk), `gap` (kesikli halka), `today` (`line-strong` kutu), `future` (soluk). Yatay kaydırma önceki haftalar. Güne dokununca Bugün o günü gösterir; üstte "Bugüne dön" hapı belirir.
3. **Geri dönüş kartı** (varsa, §5.11): "Bir yıl önce bugün" ya da "30 gün önce bu soruya…". Günde en fazla bir tane; kapatılabilir.
4. **Ritüel alanı** (moda göre):
   - Günlük mod: tek `CheckInCard` (Günlük check-in, §5.2 Akış 2).
   - Sabah+akşam modu: iki kart yatay sayfalı, sağdaki kartın 16 pt'si görünür. 05–14 arası sabah önde, 14 sonrası akşam önde.
   - Kart durumları: **Başlamadı** (başlık + mono süre "2 dk" + `Başla`), **Yarıda** ("Devam et · 3/6" + ilerleme çizgisi), **Tamam** (yankı cümlesi italik serif + MoodPill + tek satır özet: sabah → seçilen odak, akşam → "4/5 pratik"), **Kaçırıldı** (sabah 14:00 sonrası yapılmadıysa sönük + "Yine de yap").
5. **Pratiklerin**: `PracticeTile` 2 sütunlu ızgara (ikon kuyusu, ad, bugün yapıldıysa tik). Son karo "+ Ekle". Uzun basma: sırala / kaldır. Karoya dokunma o pratiği bugün için işaretler (selection haptiği), uzun basma değil.
6. **Haftalık tema**: `WeeklyThemeCard` — mono label "HAFTALIK TEMA · GÜN 3/7", tema adı `title`, günün sorusu Literata `prompt`, `Yaz` (primary değil, ikincil hap; ekranın primary'si ritüel kartındadır). Yazıldıysa "Devam et" + ilk satır önizleme. Geçmiş günler kartın altında 7 nokta; gelecek günler kilitli.
7. Dock boşluğu.

**Kurallar:** Günün sözü Bugün'de değil, Sözler'in ilk kartıdır. `brand` bu ekranda yalnız seri sayısında.

**Durumlar:** ilk gün (seri hapı yok, WeekStrip yalnız bugün), seri gizli, geçmiş bir gün görüntüleniyor, yükleniyor (iskelet), çevrimdışı (içerik önbellekten; üstte uyarı şeridi yalnız içerik eskiyse).

**Geri doldurma:** `gap` güne dokununca sheet: "Dün boş kaldı. İstersen şimdi doldurabilirsin." + `Check-in yap` / `Yaz`. 7 günden eski günlerde bu satır yok; yalnız o günün girdileri gösterilir.

### 5.2 Giriş akışları (ritüeller)

**Ortak kabuk:** fullScreenCover; üstte adım sayısı kadar ince ilerleme çizgisi; solda kapat (×), sağda "Atla" (yalnız isteğe bağlı adımda). Adım başlığı `title`; soru metni Literata `prompt`. Adımlar veriyle tanımlanır (`FlowStepViewData { id, kind, title, prompt?, optional, options? }`; kind: `score, emotions, causes, sleep, focus, text, list3, quote, practices, intentionReview`). Ekran adımları sabit kodlamaz.
- Her adım bitince taslak kaydedilir. Kapatınca uyarı yok; kart "Devam et · n/m" olur. Gece yarısı geçerse yarım akış o güne kaydedilir.
- Yazı alanı tek satırdan büyür; klavye açıkken alt buton klavyenin üstünde kalır.
- Geri kaydırma (soldan) önceki adım.

**Akış 1 — Mood check-in (~30 sn; açılışta, + menüsünde, widget'ta)**
1. `score` "Şu an nasılsın?" — ScoreScale 1–5 (Çok zor · Zor · İdare eder · İyi · Çok iyi). Seçimden 300 ms sonra otomatik ileri.
2. `emotions` "Hangi duygular?" — 8 aile, 38 duygu, aile sırasıyla sarılarak. Sınırsız seçim. İsteğe bağlı.
3. `causes` "Ne etkiliyor?" — CauseTag (İş, Okul, Aile, İlişki, Arkadaşlar, Uyku, Sağlık, Spor, Hava, Para, Kendim) + "+ Ekle". İsteğe bağlı.
4. `text` "Eklemek istediğin bir şey var mı?" — İsteğe bağlı.
→ Yankı ekranı (mühürsüz): affirmation ortada, 2 sn ya da dokunuşla kapanır. İlk check-in'de "Bugün başladı." ve mühür.

**Akış 2 — Günlük check-in (tek mod, ~2 dk)**
1. `score` "Bugün nasılsın?" 2. `emotions` 3. `causes` 4. `text` günün sorusu (motordan); önceki cevap varsa altında `raised` kutu: "Geçen sefer şöyle yazmıştın: …" (2 satır, dokununca tamamı sheet'te). 5. `list3` "Bugün neye minnettarsın?" (isteğe bağlı)
→ Kapanış (§5.5). Gün `done`.

**Akış 3 — Sabah hazırlığı (~2 dk)**
1. `sleep` "Nasıl uyudun?" 1–5 (Çok kötü · Kötü · İdare eder · İyi · Çok iyi) + isteğe bağlı süre (4–12 sa, 0,5 adım).
2. `score` "Güne nasıl başlıyorsun?" (duygular bu akışta varsayılan kapalı; kişiselleştirmeden açılır).
3. `focus` "Bugün neye odaklanıyorsun?" tek seçim: Sakinlik · Sabır · Disiplin · Cesaret · Nezaket · Minnet · Odak · Kendine iyi davran · + Kendi kelimen.
4. `quote` günün sözü (küçük QuoteCard) + "Bu söz bugün sana ne söylüyor?" (isteğe bağlı; yazılırsa aynı zamanda söze yazı olarak kaydedilir).
5. `list3` "Bugünün en önemli bir, iki, üç şeyi?"
6. `text` "Bugün seni ne zorlayabilir, nasıl karşılarsın?" (isteğe bağlı)
→ Kapanış: yarım mühür + "gün hazır." Gün `half`; akşam da yapılırsa `done`.

**Akış 4 — Akşam değerlendirmesi (~3 dk)**
1. `score` "Günün nasıldı?" + `emotions` + `causes` (ikisi isteğe bağlı).
2. `intentionReview` "Sabah '{odak}' demiştin. Nasıl gitti?" — Tuttum · Yarım · Olmadı. Sabah yapılmadıysa adım yok.
3. `practices` bugünkü pratikler; toggle listesi, Bugün'deki işaretlerle senkron.
4. `text` "Bugün iyi giden bir şey?"
5. `text` "Tekrar yaşasan neyi farklı yapardın?"
6. `list3` "Neye minnettarsın?" (isteğe bağlı)
7. `text` "Eklemek istediğin bir şey?" (isteğe bağlı)
→ Kapanış: tam mühür + yankı. Sabah `list3`'te işaretlenmemiş maddeler varsa tek satır: "Yarına taşıyayım mı?" `Taşı` / `Bırak`.

**Açılış check-in'i:** Profil'de açıksa, günün ilk açılışında, uygulama bildirim/widget/derin bağlantıyla açılmadıysa Akış 1 açılır. Sabah+akşam modunda 05–14 arası açılışta Akış 1 yerine sabah kartı öne gelir; check-in otomatik açılmaz.

**Kişiselleştirme** (Profil › Günlük akışı): her akışın adımları aç/kapat ve sırala; `score` kapatılamaz. Sorular dönen havuzdan gelir; sabit olanlar yalnız `score`, `sleep`, `focus`, `intentionReview`.

### 5.3 Yazma editörü (`JournalEditor`)
- fullScreenCover, `ground` zemin. Üstte mono bağlam etiketi (BOŞ SAYFA / HAFTALIK TEMA · YAVAŞLIK / SÖZE YAZI / REHBERLİ · 2/5) ve sağda `Bitti`.
- Soru varsa `prompt` (Literata 22); boş sayfada soru yok, yer tutucu "Yaz…". Boş sayfanın üstünde isteğe bağlı küçük bağlantı: "Bir soru ister misin?" → serbest soru (E4) yerleşir, "başka soru" ile değişir.
- Gövde `journal` (Literata 18/29), satır ~65 karakter; iPad'de ortalı sütun. İmleç `brand`.
- Klavye üstü araç hapı: Biçim (kalın, italik, başlık, liste; markdown saklanır) · Foto · Ses kaydı · Şarkı · Etiket · sağda mono kelime sayısı.
- Otomatik kayıt her 2 sn ve çıkışta; kayıt göstergesi yok.
- `Bitti` → kapanış (§5.5). Hiç yazı yoksa `Bitti` yerine `Kapat`, girdi oluşmaz.
- Geçmiş bir girdiyi düzenleme: aynı editör, üstte mono tarih; kapanış ekranı yok, yalnız "kaydedildi" hafif bildirimi.

### 5.4 Söze yazı (`QuoteReflection`) ve karşılaştırma
- Editör + üstte `raised` söz künyesi: söz (Literata italik), mono "DÜŞÜNÜR · ESER" (dokununca düşünür sayfası sheet'i). Kaydırınca künye tek satıra küçülür.
- Soru: söze özel soru, sağda "başka soru" (dönen).
- Aynı söze daha önce yazıldıysa en altta soluk satır: "Geçen sefer (12 Eyl): …" → dokununca önceki yazı sheet'i.
- **Karşılaştırma modu** (motor adayı ya da geri dönen söz): editör iki bölmeli değil; üstte katlanır "O zaman" kutusu (önceki cevap, tarih), altında "Şimdi". Kapanıştan sonra **Değişim kartı**: iki cevabın ilk cümleleri yan yana, arada geçen süre ("214 gün sonra"). Paylaşılabilir (§5.12).

### 5.5 Kapanış (`Seal`)
- `brand` disk + tik: 0.9 → 1.0 + opaklık, 320 ms, `.soft` haptik.
- Metin bağlama göre: "bugün kapandı." · "gün hazır." · "yazın kaydedildi." Altında Literata italik yankı ya da özet (kelime sayısı).
- Altında WeekStrip; bugünün hücresi tike döner (animasyonlu).
- Rozet kazanıldıysa tek satır + rozet; dokununca rozet sheet'i.
- Seri kilometre taşında (7, 30, 100, 365) tek satır "30. gün." Başka kutlama yok.
- 2,5 sn sonra ya da dokunuşla kapanır. VoiceOver açıksa kendiliğinden kapanmaz; `Kapat` görünür.

### 5.6 Sözler
- Üst çubuk: solda mod hapı "Sana özel ⌄" (menü: Sana özel · Yollar ›  · Düşünürler › · Beğendiklerin · Yazdıkların). Premium yollar kilit ikonlu; seçilince paywall. Sağda fırça (arka plan), oynat (slayt modu, 6 sn), ara.
- Dikey sayfalı tam ekran `QuoteCard` (radius xl), dock'un üstünde biter.
- Kart: söz (`quote`, tırnaksız; arka plana göre ink ya da beyaz; okunurluk için degrade, ≥ 4.5:1), altında boş satır ve **"— {attribution}"** (`body-sm`, `ink-muted`; Stoic'teki gibi yalnız ad, eser kartta yok; ayrıntı 08 §2), adın yanında küçük kaynak işareti → kaynak sheet'i (eser, bölüm/sayfa, çeviri, "uyarlama" notu, düşünür sayfası bağlantısı), varsa "Bu söze 2 kez yazdın". Alt eylemler: paylaş · **Bunun hakkında yaz** (birincil) · kalp.
- Düşünür adına dokunma → düşünür sayfası (push).
- Görünürlük ölçümü: kart ≥ %60 görünür ve ≥ 1,2 sn → `onSeen(id, dwell)`; daha hızlı geçilen → `onSkipped(id)`.
- İlk kart her gün günün sözüdür (mono "GÜNÜN SÖZÜ" etiketi).
- Yol tükendiyse: "Bu yolun hepsini gördün." + diğer yollar + "Yazdıkların" önerisi.
- Arka plan seçici sheet: düz renkler (ground, surface, sabah, aksam tonları), ONE illüstrasyon seti, kullanıcı fotoğrafı.

### 5.7 Düşünür sayfası
- Push; üstte ONE illüstrasyonu (fotoğraf yok), ad `screen-title` değil `title`, mono dönem ve yol ("MS 4–65 · STOACILAR").
- "Ana fikri" tek cümle (Literata). Kısa biyografi (3–4 cümle, "Devamı" ile açılır).
- Eylemler: `Bu hafta onunla` (Sözler'i bu düşünürün modunda açar, 7 gün sürer) · takip et (kalp).
- Bölümler: Sözleri (liste, her satır → söze yazı), Senin yazdıkların (bu düşünürün sözlerine yazılanlar), Benzer düşünürler.
- Premium yol düşünürü ücretsiz kullanıcıda: sayfa açık, ilk 3 söz açık, gerisi "ONE+ ile aç".

### 5.8 Keşfet
- Başlık "keşfet", sağda ara.
- **Öne çıkan** kart (FeaturedCard). Satırlar (yatay): Sana özel · Haftalık temalar · Rehberli günlükler · Sabah · Akşam · Duygu check-in'i · **Düşünürler** (yuvarlak illüstrasyonlar) · **Yollar** (Stoacılar, Varoluşçular, Antik Yunan, Doğu bilgeliği, İslam ve Anadolu düşüncesi, Psikologlar, Modern düşünce).
- `ContentCard`: kemer görsel, kilit, mono rozet (YENİ / ÖNE ÇIKAN), kategori, başlık, 2 satır açıklama, "···".
- İçerik detayı: başlık, adım sayısı, süre, açıklama, `Başla` → rehberli akış (editör varyantı, üstte ilerleme, adımlar arası geri).
- Kilitli içerik ücretsiz kullanıcıya da görünür; dokununca paywall (`source: explore`). Sıralamada her 3 karttan en fazla 1'i kilitli.
- Arama: içerik, söz, düşünür; sonuçlar türe göre gruplu, son aramalar.

### 5.9 Yolculuk
- Başlık "yolculuk"; sağda dönem hapı (Günler · Haftalar · Aylar · Yıllar), filtre, ara.
- **Günler:** gün başlığı ("Bugün, 24 Eyl ›", "Dün", "21 Eyl Pazartesi") + `HistoryCard`'lar: check-in (MoodPill + duygular), ritüel (sabah/akşam kemerli, odak + ilk cevap), günlük (ilk 3 satır serif), söze yazı (sol çizgili söz + cevap), fotoğraf, legacy ONE 1 kartı.
- **Haftalar/Aylar:** takvim ızgarası; gün hücresinde skor rengi noktası ve yazı işareti. **Yıllar:** 12 mini ay.
- Filtre sheet'i: tür, etiket, skor, düşünür, yalnız fotoğraflılar.
- Arama: tam metin, vurgulu sonuç satırları, tarih.
- **Girdi detayı** (push): tam metin, medya, etiketler, soru/söz künyesi, düzenle, paylaş (§5.12), sil (onay). Altta "Aynı soruya diğer cevapların" (değişim çifti).
- Boş durum: "İlk sayfa bugün yazılacak." + `Yaz`.

### 5.10 Eğilimler
- Başlık "eğilimler", altında label "GENEL İÇGÖRÜLER"; dönem hapı (14 gün · 30 gün · Aylar · Yıllar).
- Kartlar: Mood çizgisi (score renkli noktalar, bugün halkalı) · Uyku ve mood (sabah akışından) · Duygu dağılımı (yatay çubuklar) · Etiket ilişkisi ("Uyku etiketli günlerde ortalama 2,8") · Odak takibi (sabah odağı × akşam "Tuttum" oranı) · Yazma istatistikleri (girdi, kelime, en uzun seri) · Geçen yıl bugün · **Değişim çiftleri**.
- Her kart kendi eşiğini taşır: yetersizse "Henüz erken — 5 check-in daha". Hiç veri yoksa ekranın tamamı çerçeveli kart + ScoreScale.
- Premium kilitli kartlar bulanık değil: başlık + tek cümle + "ONE+ ile aç".
- Karta dokunma → detay (push): daha büyük grafik, açıklama, ilgili girdiler.

### 5.11 Geri dönüş kartı (markanın imza anı)
- Kaynaklar: bir yıl önce bugün yazılan girdi; karşılaştırma adayı soru (≥30 gün); 90 günü dolmuş yazılmış söz.
- Bugün'de hafta şeridinin altında, günde en fazla bir. Mono etiket ("BİR YIL ÖNCE BUGÜN" / "30 GÜN ÖNCE"), eski metnin ilk 2 satırı (Literata), eylemler: `Tekrar yaz` (karşılaştırma modu) · `Oku` · × (bugün için gizle).
- Profil ayarından kapatılabilir.

### 5.12 Paylaşım kartı
- Kaynaklar: söz, söze yazı, değişim kartı, yıl sonu.
- Önizleme sheet'i: 1080×1920 ve 1080×1080 seçimi; arka plan seçici; kişisel metin **varsayılan gizli**, "Yazımı da ekle" anahtarı; alt köşede küçük wordmark.
- Hedefler: Instagram hikâyesi (varsa doğrudan), sistem paylaşımı, görseli kaydet.

### 5.13 + (Yaz) sheet'i
- `.medium` sheet, liste: **Boş sayfa** · **Mood check-in** · **Günlük önerisi** (E7'nin seçtiği tek öğe; alt satırda ne olduğu) · **Şablonlar** (premium: özel şablon) · **Kütüphane** (rehberli günlükler).
- Sabah+akşam modunda en üste bağlama göre "Sabah hazırlığı" ya da "Akşam değerlendirmesi" eklenir.

### 5.14 Onboarding (ilk açılış, ~2 dk, geri dönülebilir)
1. Karşılama: wordmark + "Her gün biraz yaz, zamanla kendini oku." + `Başla`.
2. Ad (isteğe bağlı): "Sana nasıl seslenelim?"
3. Odak alanları (çoklu): Kaygı · Odak · Minnet · Uyku · İlişkiler · Özgüven · Yas · Yaratıcılık · Anlam.
4. **Düşünce yolları** (en az 1): Stoacılar · Varoluşçular · Antik Yunan · Doğu bilgeliği · İslam ve Anadolu düşüncesi · Psikologlar · Modern düşünce. Her kartta bir örnek söz ve düşünür adı.
5. Ritüel modu: Günde bir kez / Sabah ve akşam + saat seçiciler.
6. Bildirim izni ön ekranı (kendi ekranımız; "Şimdi değil" eşit görünür), sonra sistem izni.
7. İlk check-in (Akış 1, gömülü).
8. Paywall (atlanabilir; "Ücretsiz devam et" açıkça görünür).
9. İlk yazı: haftanın tema sorusu → editör → mühür "Bugün başladı." Onboarding biter, Bugün açılır.
- Mevcut ONE (v3) kullanıcısı: 1. ekran yerine "ONE yenilendi." karşılaması + eski anlarının Yolculuk'ta durduğu bilgisi; ONE+ abonelerine paywall gösterilmez.

### 5.15 Paywall
- Üstte tek cümle değer vaadi ("Tüm düşünürler, tüm yollar, tüm içgörüler.") + 3 madde (ikonlu, kısa).
- `PlanCard`'lar: yıllık (seçili, deneme etiketi, aylık karşılığı), aylık. `Denemeyi başlat` (primary). Altında ücretin ne zaman çekileceği tek satır.
- Geri yükle · Koşullar · Gizlilik. Kapat (×) her zaman görünür, gecikmesiz.
- `source` parametresi her açılışta taşınır (onboarding, sozler_yol, dusunur, kesfet, egilimler, sablon, widget).

### 5.16 Profil ve Ayarlar
- Profil (push): ad, seri ve toplam gün, Rozetler (3'lü ızgara, kazanılmamışlar soluk + koşul), ONE+ durumu, "Yılın yazısı" (Aralık'ta).
- Ayarlar grupları:
  - **Günlük akış:** ritüel modu, saatler, akışların adımları (§5.2), açılış check-in'i.
  - **Bildirimler:** tür tür (sabah, akşam, haftalık tema, geri dönüş, seri hatırlatma).
  - **İçerik:** düşünce yolları, yazılan sözlerin geri dönmesi, geri dönüş kartı.
  - **Görünüm:** tema, seri görünürlüğü, uygulama ikonu (varsayılan / açık / tinted).
  - **Gizlilik:** uygulama kilidi (Face ID / parola), paylaşımlarda yazıyı varsayılan gizle.
  - **Veri:** iCloud durumu, dışa aktar (JSON / Markdown), tüm veriyi sil (iki adımlı onay).
  - **Destek:** SSS, geri bildirim, puan ver, sürüm.

### 5.17 İzin ve sistem ekranları
- Bildirim, fotoğraf, mikrofon ve Face ID izinleri: önce kendi tek ekranımız (ne işe yaradığı tek cümle), sonra sistem diyaloğu. Reddedilince tekrar sorulmaz; ilgili ayarda "Ayarlar'da aç" bağlantısı.
- Kilit ekranı: `ground` zemin, wordmark, `Kilidi aç`. Arka plana geçince 1 dk sonra kilitlenir (ayarlanabilir: hemen / 1 dk / 5 dk).

### 5.18 Widget ve kilit ekranı
- Küçük: günün sözü (ücretsiz). Orta: söz + hafta şeridi. Büyük: hafta + bugünkü check-in + tema sorusu. Kilit ekranı: seri (inline), skor (circular), günün sözü (rectangular).
- Dokunma hedefleri derin bağlantılar (§3.3); check-in widget'ı Akış 1'i açar.
- Premium widget'lar ücretsiz kullanıcıda eklenebilir ama "ONE+ ile aç" gösterir.

### 5.19 Yıl sonu: "Yılın yazısı"
- 15 Aralık'tan itibaren Profil'de ve Bugün'de kart. Dikey sayfalı 6–8 kart: yazılan gün sayısı, kelime, en çok yazılan düşünür, en sık duygu, değişim çifti, yılın ilk ve son cümlesi (izinle). Her kart paylaşılabilir (§5.12).

---

## 6. Durum matrisi (her ekran için önizleme zorunlu)

| Durum | Görünüm |
|---|---|
| Yükleniyor | Gerçek yerleşimde `raised` iskelet; 300 ms'den kısa yüklemelerde iskelet gösterilmez |
| Boş | Çerçeveli kart + tek soru + tek eylem |
| Kısmi | Eşik altı kartlar "Henüz erken — n daha" |
| Hata | `danger` tek kelime + ne yapılacağı + `Tekrar dene` |
| Çevrimdışı | İçerik önbellekten; yalnız yeni içerik gerekiyorsa üstte `raised` şerit + `warning` ikon |
| Premium kilitli | İçerik görünür, eylem kilitli; bulanıklık yok |
| iCloud kapalı | Profil › Veri'de bilgi satırı; akışlar etkilenmez |

---

## 7. Etkileşim, hareket, haptik

| An | Hareket | Haptik |
|---|---|---|
| Buton/kart basışı | scale 0.97, 120 ms | yok |
| Skor seçimi | chip dolgusu 180 ms | selection |
| Duygu/etiket seçimi | 180 ms | selection |
| Adım geçişi | yatay kayma + opaklık, 280 ms | yok |
| Pratik işaretleme | tik çizimi 180 ms | light |
| Kalp | ölçek 1 → 1.15 → 1 | selection |
| Mühür | 0.9 → 1.0 + opaklık, 320 ms | soft |
| Silme onayı | — | warning |
| Hata | — | error |

Tek eğri `cubic-bezier(0.2, 0.8, 0.2, 1)`. Reduce Motion: yalnız opaklık. Reduce Transparency: `glass` → `raised`.

---

## 8. Kopya

**Kurallar:** "sen" dili · başlıklar küçük harf, noktasız · buton 1–3 kelime fiil · emoji yok · ekran başına en fazla bir ünlem · Türkçe büyük harfte i → İ · suçlama yok · sonuç vaadi yok.

**Mikro kopya kütüphanesi (başlangıç):**

| Yer | Metin |
|---|---|
| Birincil butonlar | Başla · Yaz · Devam et · Kaydet · Bitti · Tekrar yaz |
| Atla | Atla |
| Boş Yolculuk | İlk sayfa bugün yazılacak. |
| Kaçırılan gün | Dün boş kaldı. İstersen şimdi doldurabilirsin. |
| Yol bitti | Bu yolun hepsini gördün. |
| Eşik altı | Henüz erken — {n} check-in daha. |
| Kapanış | bugün kapandı. · gün hazır. · yazın kaydedildi. |
| İlk gün | Bugün başladı. |
| Geri dönüş | Bir yıl önce bugün şunu yazmıştın. |
| Karşılaştırma | {n} gün önce buna şöyle cevap vermiştin. |
| Silme onayı | Bu girdi silinsin mi? Geri alınamaz. · Sil · Vazgeç |
| Hata | Kaydedilemedi. Bağlantını kontrol edip tekrar dene. |
| Kilit | {AppBrand.name} kilitli · Kilidi aç |
| Seri hapı | {n} gün |
| Ritüel kartı | Günlük check-in · Sabah hazırlığı · Akşam değerlendirmesi · {n} dk · Başla · Devam et · {n}/{m} · Yine de yap |
| Akşam özeti | {n}/{m} pratik |
| Geçmiş gün | Bugüne dön · Bu güne kayıt yok. |
| Geri doldurma eylemleri | Check-in yap · Yaz |
| Haftalık tema etiketi | HAFTALIK TEMA · GÜN {n}/7 |
| Geri dönüş etiketi | BİR YIL ÖNCE BUGÜN · {n} GÜN ÖNCE · Oku · Bugün için gizle |
| Yükleme hatası | Yüklenemedi. Birkaç saniye sonra tekrar dene. · Tekrar dene |
| Pratik (VoiceOver) | bugün yapıldı |

Tüm metinler `Localizable` (tr); en yer tutucu. Yeni metin bu tabloya eklenir.

---

## 9. Erişilebilirlik

- Dynamic Type xSmall–AX5; `screen-title` ×1.25 ile sınırlı; AX3+ ızgaralar tek sütuna düşer.
- VoiceOver: çok satırlı kartlar tek öğe ("Mood check-in, 11:39, 4, İyi, Minnettar"); skor "4, İyi"; seçili durum `.isSelected`; otomatik ileri yerine "Devam" butonu; mühür kendiliğinden kapanmaz.
- Her akış adımında ilk odak başlık.
- Increased Contrast: `line` → `line-strong`, `ink-faint` → `ink-muted`.
- Renk tek başına anlam taşımaz: skor her zaman rakam + etiket, duygu her zaman ad.
- Sözler kartında degrade kontrastı en kötü fotoğrafta bile 4.5:1 (test fixture'ı: beyaz fotoğraf).
- Klavye ve Switch Control ile her akış tamamlanabilir.

---

## 10. Premium kapıları (UX tarafı)

| Yer | Ücretsiz | Kilitliyken görünüm |
|---|---|---|
| Sözler | Sana özel + 1 yol | Mod menüsünde kilit ikonu → paywall |
| Düşünür sayfası | Açık yol düşünürleri tam; diğerlerinde ilk 3 söz | "ONE+ ile aç" satırı |
| Rehberli günlükler | 3 temel | Kartta kilit, detay sayfası açık, `Başla` paywall |
| Geçmiş temalar | Son 4 hafta | Listede kilit |
| Eğilimler | 14 gün mood + temel yazma | Kart başlığı + tek cümle + "ONE+ ile aç" |
| Şablonlar | Yok | + menüsünde kilit |
| Widget | Günün sözü | Widget içinde "ONE+ ile aç" |
| Dışa aktarma | JSON | Markdown seçeneği kilitli |

Ritüeller, check-in, yazma, söze yazı, seri, rozet, kilit, iCloud **her zaman ücretsiz**.

---

## 11. Bildirimler (UX metni ve hedef)

| Tür | Örnek metin | Açılan yer |
|---|---|---|
| Sabah | Günün sözünün ilk cümlesi | `one://ritual/morning` ya da `one://quote/<id>` |
| Akşam | "Günü kapatma vakti." | `one://ritual/evening` |
| Haftalık tema | "Bu haftanın teması: Yavaşlık." | `one://today` |
| Geri dönüş | "Bir yıl önce bugün bir şey yazmıştın." | `one://resurface/<id>` |
| Seri (kapalı varsayılan) | "Bugün henüz yazmadın. İstersen bir satır yeter." | `one://checkin` |

Uygulama o gün açıldıysa günün hatırlatması gönderilmez. Bildirim metinleri de §8 kurallarına uyar.

---

## 12. Ölçüm (view model eylemleri; motor E17 ile bağlanır)

UX, her önemli eylemi view model'de adlandırılmış bir aksiyon olarak açar; olay adları E17'de. Marka için izlenecekler: `flow_started/completed/abandoned(step)`, `quote_seen`, `quote_reflect_started`, `resurface_shown/opened`, `share_opened/completed(kind)`, `comparison_completed`, `paywall_shown(source)`.

---

## 13. Uygulama sırası ve kabul

Mevcut UX-1…UX-3 çalışmasının üstüne:

| Adım | Kapsam | Kabul |
|---|---|---|
| UX-3.5 | Temizlik: " 2" kopyaları, ViewData'nın 07'ye uyumu | Derleme temiz, kopya dosya yok |
| UX-4 | Bugün (§5.1) + geri dönüş kartı (§5.11) | Tüm durum önizlemeleri |
| UX-5 | Akış kabuğu + 4 akış (§5.2) | Her adım gece/gün/AX3; taslak devam senaryosu |
| UX-6 | Editör, söze yazı, karşılaştırma, kapanış (§5.3–5.5) | Değişim kartı önizlemesi |
| UX-7 | Sözler + düşünür sayfası (§5.6–5.7) | Görünürlük ölçer birim testi |
| UX-8 | Keşfet (§5.8) | Kilitli oranı fixture'da ≤ 1/3 |
| UX-9 | Yolculuk + Eğilimler (§5.9–5.10) | Eşik durumları |
| UX-10 | Onboarding, paywall, profil, ayarlar, izinler, kilit (§5.14–5.17) | v3 kullanıcı varyantı |
| UX-10.5 | Paylaşım kartı, widget, yıl sonu (§5.12, 5.18, 5.19) | 1080×1920 çıktı |
| UX-11 | Motorla bağlama (05) | QA senaryoları |

Her adım: fixture ile, gece + gün + AX3 önizleme, ayrı commit, sonunda rapor ve dur.
