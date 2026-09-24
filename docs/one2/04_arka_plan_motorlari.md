# ONE 2.0 — Arka Plan Motorları ve Altyapı

Tarih: 23 Eylül 2026 · Durum: Onaylandı (açık kararlar sonda kapatıldı)
Bağlam: ADR-001 (kabul edildi), 02_veri_modeli.md v0.2, MIGRATION.md, ONE 2.0 Design System (claude.ai artifact).
Amaç: Arayüz yazılmadan önce kurulması gereken bütün UI'siz sistemleri tek yerde toplamak. Her ekran bu motorları çağırır; ekranların kendisi karar vermez.

## 0. Ortak ilkeler

| İlke | Kural |
|---|---|
| Yer | `one/ONE2/Engines/<Motor>/`. İçerik tipleri `one/ONE2/Content/`, kalıcı veri `one/ONE2/Data/` (ADR §2) |
| Saflık | Motorun karar veren çekirdeği saf fonksiyondur: girdi (katalog + kullanıcı geçmişi + `AppClock` + tohum) → çıktı. Core Data, ağ ve UI çekirdeğe girmez; bir `Store` katmanı besler |
| Determinizm | Rastgelelik yalnız enjekte edilen `SeededRandom` ile. Aynı kullanıcı, aynı gün, aynı girdi = aynı sonuç (cihazlar arası tutarlılık ve test) |
| Zaman | Her tarih `AppClock` + `dayKey` üzerinden (ADR §4) |
| Test | Her motor için Swift Testing; sınır durumlar tabloda "Test" sütununda |
| Gizlilik | Her şey cihazda. Sunucu yok; içerik yalnız indirilir, kullanıcı verisi hiçbir yere gönderilmez |
| Yapay zekâ | Yok (Faz 7). Tüm "kişisel" davranış kural + ağırlık + içerik etiketiyle |
| İçerik | Stoic'ten metin, alıntı seçkisi, mentor karakteri kopyalanmaz |

## 1. Motor ve sistem envanteri

| # | Sistem | Ne yapar | Kullanan ekranlar | Relaunch için |
|---|---|---|---|---|
| E1 | İçerik altyapısı (`ContentRepository` + şema v1) | Katalogları yükler, doğrular, sürümler, önbelleğe alır | Hepsi | Zorunlu |
| E2 | Söz motoru (`QuoteEngine`) | Sözler akışını kurar, tekrarı önler, günün sözünü seçer | Sözler, Bugün, widget, bildirim | Zorunlu |
| E3 | Maruz kalma kaydı (`ExposureStore`) | Kullanıcının gördüğü/yazdığı/beğendiği her içeriği tutar | E2, E4, E6, E7 | Zorunlu |
| E4 | Soru motoru (`PromptEngine`) | Günün sorusu, söze yazı soruları, rehberli adımlar | Bugün, Söze yazı, Editör | Zorunlu |
| E5 | Haftalık tema takvimi (`ThemeCalendar`) | Hangi hafta hangi tema, hangi gün kilitli | Bugün, Keşfet | Zorunlu |
| E6 | Check-in yankı motoru (`EchoEngine`) | Check-in sonrası tek yargısız cümle | Bugün, Kapanış | Zorunlu |
| E7 | Öneri motoru (`RecommendationEngine`) | "Günlük önerisi", Keşfet "Sana özel" sıralaması | + menü, Keşfet | Zorunlu (basit sürüm) |
| E8 | Gün ve seri motoru (`DayCompletion` + `Streak`) | Gün tamam mı, seri kaç, geriye dönük doldurma | Bugün, Kapanış, widget | Var (Faz 1 #6), kurallar genişler |
| E9 | Rozet motoru (`BadgeEngine`) | Kural tablosuna göre rozet verir | Kapanış, Profil | Zorunlu |
| E10 | İçgörü motoru (`InsightsEngine`) | Mood serisi, duygu dağılımı, etiket ilişkisi, "geçen yıl bugün", aynı soruya cevaplar | Eğilimler, Yolculuk | Zorunlu (temel set) |
| E11 | Arama (`SearchIndex`) | Girdi metni, söz, etiket, tarih araması; Spotlight | Yolculuk, Sözler | Zorunlu (Spotlight sonra) |
| E12 | Kişiselleştirme profili (`UserProfileStore`) | Onboarding cevapları, ritüel modu, saatler, yollar | E2, E4, E7, bildirim | Zorunlu |
| E13 | Bildirim içerik planlayıcı | Orchestrator'a hangi günün hangi metni gideceği | — | Zorunlu (ADR §6 üstüne) |
| E14 | Widget veri yazıcı (`w2_*`) | Günün sözü, hafta, seri, bugünkü check-in | Widget | Zorunlu |
| E15 | Premium kapısı (`EntitlementStore` + `PremiumFeature`) | Hangi içerik/özellik kilitli | Hepsi | Var (ADR §8), liste netleşir |
| E16 | Dışa aktarma v2 | JSON + okunur Markdown arşivi | Profil | Zorunlu |
| E17 | Analitik olay kataloğu v2 | ONE 2.0 olayları, huni tanımları | — | Zorunlu |
| E18 | İçerik üretim hattı | Görkem'in içerik girdiği kaynak → doğrulayıcı → JSON → yayın | — (dış) | Zorunlu |

Bağımlılık sırası: E1 → E3 → E12 → E5 → E2, E4, E6 → E7 → E8, E9 → E10, E11 → E13, E14 → E16, E17. E18, E1 ile paralel başlar (en uzun iş içerik).

---

## E1. İçerik altyapısı ve şema v1

ADR §5 kararı geçerli: bundle + `https://one.forvibe.app/content/v1/`, manifest + SHA-256, TR önce.

**Dosyalar (v1):**

| Dosya | İçerik |
|---|---|
| `manifest.json` | `schemaVersion`, `contentVersion`, `generatedAt`, dosyalar + hash |
| `quotes.tr.json` | Söz, olumlama, atasözü, düşünce cümlesi (E2) |
| `prompts.tr.json` | Serbest günlük soruları, söze yazı soruları, check-in takip soruları (E4) |
| `themes/2026-wNN.tr.json` | Haftalık tema: ad, açıklama, 7 günlük soru (E5) |
| `themes/evergreen.tr.json` | Takvimde boşluk olursa kullanılacak yedek temalar |
| `guided/<id>.tr.json` | Rehberli günlükler: adımlar, adım tipi, soru metni |
| `echoes.tr.json` | Check-in yankı cümleleri ve koşulları (E6) |
| `catalogs/emotions.tr.json` | 38 duygu, 8 aileye bağlı (`emo-*` token'ları: `nese`, `huzur`, `enerji`, `sevgi`, `kaygi`, `huzun`, `ofke`, `yorgun`). ID `<aile>.<ad>` (`huzur.sakin`), liste UX_istekleri.md §1 |
| `catalogs/causes.tr.json` | ~20 "ne etkiliyor" etiketi |
| `catalogs/badges.tr.json` | Rozetler ve kuralları (E9) |
| `catalogs/paths.tr.json` | Söz yolları (onboarding'de seçilen "sesler"), E2 ağırlıkları |

**Kurallar:**
- Her öğenin kalıcı ID'si var ve asla yeniden kullanılmaz (`q_000123`, `p_000045`, `t_2026w40`). Silinen öğe `active: false` olur, dosyadan çıkmaz (Yolculuk'taki eski girdiler ona bağlı).
- Her öğede `addedIn` (contentVersion), `active`, `premium`, `lang` alanları.
- Uygulama içerik değişince `ContentRepository.didUpdate` yayınlar; motorlar önbelleklerini tazeler.
- Bozuk/eksik uzak dosya → bundle sürümü; hiçbir durumda boş ekran yok.

**Test:** bozuk JSON, hash uyuşmazlığı, `schemaVersion` büyük, dosya eksik, çevrimdışı ilk açılış, ID çakışması.

---

## E2. Söz motoru (`QuoteEngine`)

### E2.1 Katalog modeli

| Alan | Tip | Not |
|---|---|---|
| `id` | String | `q_000123`, kalıcı |
| `text` | String | 12–220 karakter |
| `kind` | enum | `quote` (kişiye ait söz), `affirmation` (olumlama, ONE yazar), `proverb` (atasözü/deyim), `reflection` (ONE'ın düşünce cümlesi) |
| `author` | String? | Yalnız `quote`'ta zorunlu |
| `source` | String? | Eser/kaynak. `quote` için zorunlu; doğrulanamıyorsa öğe eklenmez |
| `translation` | enum? | `original`, `oneTranslation` (ekip çevirisi), `publicDomainTranslation` |
| `license` | enum | `publicDomain`, `original`, `licensed` + `licenseNote` |
| `themes` | [String] | `yavaşlık`, `cesaret`, `minnet`, `kayıp`, `odak`… (tema sözlüğü sabit, doğrulayıcı kontrol eder) |
| `paths` | [String] | `paths.tr.json` ID'leri (ör. `filozof`, `sakin`, `cesur`, `sefkatli`, `uretken`) |
| `emotionFit` | [String] | Duygu aileleri (`nese`, `huzun`…) |
| `moodFit` | [Int] | Uygun olduğu skorlar (ör. `[1,2]` = zor günlere yumuşak söz) |
| `timeOfDay` | enum | `morning`, `day`, `evening`, `any` |
| `length` | enum | `short` (<60), `medium` (60–140), `long` (>140); doğrulayıcı hesaplar |
| `reflectionPromptIDs` | [String]? | Bu söze özel yazma soruları; yoksa genel havuz |
| `premium` | Bool | Premium içerik |
| `active`, `addedIn`, `lang` | | E1 |

### E2.2 "Aynı sözü tekrar görmeme" garantisi

**Görüldü tanımı:** Kart ekranda ≥%60 görünür şekilde ≥1,2 sn kaldıysa ya da kullanıcı kartla etkileşime girdiyse (beğen, paylaş, yaz). Hızlı kaydırıp geçilen kart "görüldü" sayılmaz ve kuyruğa geri döner.

**Kural (sırayla):**
1. Bir oturumda aynı söz iki kez gösterilmez (kesin).
2. Görülmüş söz, havuzda görülmemiş söz kaldıkça bir daha gösterilmez (kesin).
3. Bir modun (Sana özel, bir yol, bir tema) görülmemiş havuzu biterse: o mod için "döngü 2" başlar. Söz, en uzun süredir görülmeyenden başlayarak sıralanır; son 60 günde görülen hiçbir söz döngü 2'ye girmez. 60 gün kuralını sağlayacak söz kalmazsa mod "Tümünü gördün" boş durumunu gösterir ve diğer yolları önerir (tekrar yerine dürüst boş durum).
4. **Bilinçli geri dönüş (tekrar sayılmaz):** Kullanıcının yazdığı bir söz, yazıldıktan ≥90 gün sonra en fazla haftada bir kez "Bu söze 12 Haziran'da yazmıştın" etiketiyle akışa girebilir. Ayarlardan kapatılabilir. Bu, kendini geliştirme döngüsünün parçası.
5. Favoriler ve yazılan sözler kendi listelerinde her zaman görünür; akış kuralları onları etkilemez.

Garanti cihazlar arası geçerli: maruz kalma kaydı CloudKit ile senkron (E3). Yeniden kurulum sonrası da korunur.

### E2.3 Akış kurucu (kuyruk)

- Mod başına kalıcı kuyruk: önden 30 söz seçilir, sırası kaydedilir (uygulama kapanıp açılınca aynı sıradan devam). Kuyrukta 10'dan az kalınca yeniden doldurulur.
- **Aday havuzu:** `active` ∧ `lang` ∧ (premium ise yetki) ∧ görülmemiş ∧ moda uygun.
- **Puan** (her aday için, 0–1 arası bileşenler, ağırlıklar `quotes` yapılandırmasında ayarlanabilir):

| Bileşen | Ağırlık (başlangıç) | Nasıl |
|---|---|---|
| Yol uyumu | 0,30 | Kullanıcının seçtiği yollarla kesişim |
| Haftalık tema uyumu | 0,15 | Bu haftanın temasıyla ortak tema |
| Günün saati | 0,10 | `timeOfDay` şu anki dilimle eşleşiyor mu |
| Bugünkü ruh hali | 0,20 | Son check-in skoru `moodFit` içinde mi; skor ≤2 ise `affirmation` ve yumuşak temalar öne |
| İlgi sinyali | 0,15 | Beğenilen/yazılan sözlerin temaları ve türleri (son 90 gün) |
| Rastgelelik | 0,10 | `SeededRandom(userSalt, dayKey)` |

- **Çeşitlilik kısıtları** (puandan sonra, kuyruğa yerleştirirken): aynı yazar arka arkaya gelmez ve 8 kart içinde en fazla 1 kez; aynı tür en fazla 3 kez arka arkaya; her 5 kartta en az 1 kısa söz; aynı tema en fazla 2 kez arka arkaya.

### E2.4 Günün sözü

- Bugün ekranı, widget ve sabah bildirimi aynı sözü gösterir.
- Seçim deterministik: `dayKey` + kullanıcı tuzu (KVS'de saklı rastgele UUID) ile tohumlanır; havuz = "Sana özel" adayları.
- Seçilen ID `NSUbiquitousKeyValueStore`'da `quote.daily.<dayKey>` olarak yazılır: ilk seçen cihaz belirler, diğerleri okur.
- Günün sözü akışta ayrıca görüldü sayılır; akışta tekrar çıkmaz.

### E2.5 Arayüze açılan API (taslak)

```swift
protocol QuoteEngine {
    func nextBatch(mode: QuoteFeedMode, count: Int) async -> [Quote]
    func markSeen(_ id: QuoteID, dwell: Duration) async
    func record(_ action: QuoteAction, for id: QuoteID) async   // .liked, .unliked, .shared, .wroteAbout(entryID)
    func dailyQuote(for day: DayKey) async -> Quote
    func remainingUnseen(mode: QuoteFeedMode) async -> Int
    func resurfacingCandidate(on day: DayKey) async -> Quote?   // E2.2 kural 4
}
enum QuoteFeedMode: Hashable { case forYou, path(String), theme(String), kind(QuoteKind), favorites, written }
```

### E2.6 İçerik hacmi ve yıpranma

- Tüketim tahmini: aktif kullanıcı oturum başına 5–15 kart, günde 1–2 oturum. Yoğun kullanıcı ayda ~400 kart görür.
- **Relaunch: en az 800 aktif öğe (TR), sonra haftalık ekleme; motor 1.500+ öğe için tasarlanır** (karar 5). 1.500'lük dağılım önerisi: 500 kişiye ait söz (kamu malı kaynaklar, ekip çevirisi), 400 ONE olumlaması, 300 atasözü ve deyim, 300 ONE düşünce cümlesi. Sonrası ayda en az 100 yeni öğe.
- Motor `remainingUnseen < 150` olduğunda `content_pool_low` analitik olayı atar; içerik ekibi hangi yolların tükendiğini buradan görür.

**Test:** 1.000 kartlık simülasyonda sıfır tekrar; havuz bittiğinde döngü 2'nin 60 gün kuralı; iki cihaz aynı gün aynı günün sözü; hızlı kaydırılan kartın kuyruğa dönmesi; çeşitlilik kısıtları; skor ≤2 iken olumlama oranı.

---

## E3. Maruz kalma kaydı (`ExposureStore`)

Tüm içerik türleri için tek kayıt; E2, E4, E6 ve E7 okur.

**Yeni entity `ContentExposure`** (`one 3` modeline eklenir; production şeması henüz deploy edilmediği için mümkün):

| Alan | Tip | Not |
|---|---|---|
| `id` | UUID | |
| `contentID` | String | `q_…`, `p_…`, `e_…` |
| `contentKind` | String | `quote`, `prompt`, `echo`, `guided`, `theme` |
| `firstSeenAt`, `lastSeenAt` | Date | |
| `seenCount` | Int32 | |
| `liked` + `likedAt` | Bool, Date? | `likedAt`: E2.3 ilgi sinyalinin "son 90 gün" penceresi |
| `lastEntryID` | UUID? | Bu içeriğe son yazılan girdi |
| `lastWrittenAt` | Date? | E2.2 kural 4'ün "yazıldıktan ≥90 gün" koşulu; `Entry` okumadan hesaplanır |
| `writtenCount` | Int16 | |

- Mantıksal anahtar `contentID`; CloudKit tekrarını `dayKey` deduplikasyonundaki desenle birleştir (en erken `firstSeenAt`, toplam `seenCount`, `liked` OR).
- Yazma toplu yapılır: bellekte biriktir, 10 kayıtta bir ya da arka plana geçişte `context.perform` ile kaydet.
- Hacim: yoğun kullanıcıda yılda ~10 bin satır; indeks `contentID` + `contentKind`.
- Favoriler bu entity'deki `liked` ile tutulur; ayrı `Favorite` entity'si gerekmez.

**Test:** iki cihazdan gelen aynı `contentID` birleştirmesi; toplu yazma sırasında uygulamanın kapanması; 10 bin satırda aday sorgusu < 50 ms.

---

## E4. Soru motoru (`PromptEngine`)

**Havuzlar:**

| Havuz | Kullanım | Tekrar kuralı |
|---|---|---|
| Günlük soru | Haftalık temanın günü (E5) | Temaya bağlı, takvimle belirlenir |
| Serbest soru | "Günlük önerisi", boş sayfanın üstündeki isteğe bağlı soru | Görülmemiş olan önce; 90 gün içinde tekrar yok |
| Söze yazı soruları | `QuoteReflection` | Söze özel sorular önce; yoksa genel havuz (60+ soru). Aynı söze ikinci yazışta farklı soru; ama "karşılaştır" modunda bilerek aynı soru |
| Rehberli adımlar | Rehberli günlükler | Sabit sıra, tekrar kuralı yok |
| Check-in takip | Skor/duyguya göre tek isteğe bağlı soru | 14 gün içinde tekrar yok |
| Sabah/akşam ritüel soruları | Ritüel şablonları | Sabit çekirdek + dönen 1 soru |

- Seçim, E2 ile aynı puan mantığı: tema, günün saati, ruh hali, ilgi, çeşitlilik.
- **Karşılaştırma özelliği:** bir soruya ilk cevaptan ≥30 gün sonra, aynı soru "30 gün önce buna şöyle cevap vermiştin" notuyla bilerek tekrar sorulabilir (haftada en fazla 1). Kendini geliştirmenin görünür olduğu yer.

```swift
protocol PromptEngine {
    func dailyPrompt(for day: DayKey) async -> Prompt
    func freePrompt(context: PromptContext) async -> Prompt
    func reflectionPrompt(for quote: QuoteID) async -> Prompt
    func comparisonCandidate(on day: DayKey) async -> (Prompt, previous: EntryID)?
    func markShown(_ id: PromptID) async
}
```

**Test:** 90 gün tekrarsızlık; aynı söze ikinci yazışta farklı soru; karşılaştırma haftalık sınırı.

---

## E5. Haftalık tema takvimi (`ThemeCalendar`)

- Hafta ISO 8601, pazartesi başlar, cihazın yerel saat diliminde. Tema ID'si `t_2026w40`.
- Herkes aynı haftada aynı temayı görür (paylaşılabilirlik ve içerik planı için).
- Gün kilidi: temanın o haftaki geçmiş günleri ve bugünü açık, gelecek günler kilitli. Hafta ortasında katılan kullanıcı geçmiş günleri de açık görür.
- Takvimde o hafta için tema yoksa `evergreen` havuzundan, kullanıcının görmediği bir tema seçilir (E3).
- Geçmiş temalar Keşfet'te "Tüm temalar" listesinde; premium ise tamamı, değilse son 4 hafta.
- Tema en az 2 hafta önceden yayınlanır (ADR §5). Motor, gelecek haftanın teması önbellekte yoksa `theme_missing_next_week` olayı atar.

**Test:** yıl sonu hafta 53, saat dilimi değişimi, pazar gece yarısı geçişi, tema eksik haftası.

---

## E6. Check-in yankı motoru (`EchoEngine`)

Check-in sonrası Bugün kartındaki tek cümle ("Adım adım da varılır; bugün de bir adımdı.").

- Girdi: skor, duygular, nedenler, günün saati, seri durumu, son 7 günün skorları.
- `echoes.tr.json` öğesi: `id`, `text`, `conditions` (`scoreIn`, `emotionFamilyAny`, `causeAny`, `timeOfDay`, `trend: up|down|flat`, `firstCheckin`), `weight`.
- Seçim: koşulu sağlayanlar içinde ağırlıklı rastgele; 14 gün içinde gösterilen tekrar etmez; koşullu öğe yoksa genel havuz.
- Ton kuralları (doğrulayıcı da kontrol eder): yargı yok, "neşelen" yok, ünlem yok, emoji yok, sonuç vaadi yok. Düşük skora onaylayıcı cümle ("Zor bir gün olduğunu yazman da bir adım.").
- Relaunch hedefi: 150 cümle (skor bandı × günün saati × ilk check-in).

**Test:** skor 1'de hiçbir "pozitif baskı" cümlesi seçilmemesi (etiketli test seti), 14 gün tekrarsızlık.

---

## E7. Öneri motoru (`RecommendationEngine`)

İki yerde kullanılır: + menüsündeki **Günlük önerisi** ve Keşfet'teki **Sana özel** sıralaması.

- Günlük önerisi karar tablosu (ilk eşleşen):
  1. Bugünün tema sorusu yazılmadıysa → tema sorusu.
  2. Akşam 18:00 sonrası ve akşam ritüeli yapılmadıysa → akşam refleksiyonu.
  3. Son check-in skoru ≤2 → kısa rehberli günlük ("Kafandakini boşalt" türü).
  4. Karşılaştırma adayı varsa (E4) → o soru.
  5. Değilse → serbest soru (E4).
- Keşfet sıralaması: onboarding odak alanları + son 30 günde tamamlanan içerik türleri + günün saati; tamamlananlar aşağı iner; kilitli içerik ücretsiz kullanıcıda da görünür ama sıralamada ücretsizlerin arasına dengeli serpiştirilir (her 3 karttan en fazla 1 kilitli).

**Test:** karar tablosunun her dalı; kilitli içerik oranı.

---

## E8. Gün tamamlanma ve seri (genişletme)

Faz 1 #6'daki saf fonksiyonların üstüne kurallar:

| Konu | Kural |
|---|---|
| Gün tamam | Ritüel modu `daily`: günlük check-in akışı tamam. Mod `morningEvening`: ikisinden biri tamam = yarım gün (hafta şeridinde yarım), ikisi = tam. **Seri için yarım gün yeterli** |
| Alternatif tamamlama | O gün herhangi bir yazılı girdi (soru, söz, boş sayfa) ≥ 20 kelime ise gün tamam sayılır (yazma uygulaması; ritüeli atlayıp yazan kullanıcı cezalandırılmaz) |
| Geriye dönük doldurma | Son 7 gün doldurulabilir. `isBackfilled = true`, `dayKey` geçmiş gün. Doldurulan gün seriyi onarır |
| Seri | Bugünden geriye kesintisiz tamam günler. Bugün henüz tamamlanmadıysa seri dünden sayılır ve "risk altında" durumu verilir (bildirim için) |
| Kullanıcı ayarı | Seri görünürlüğü kapatılabilir; motor hesaplamaya devam eder (rozetler için) |
| v3 günleri | Seriye sayılmaz (MIGRATION kararı) |

**Test:** gece yarısı sınırı, saat dilimi değişimi, 7. gün sınırı, yarım gün, yalnız yazılı girdiyle tamamlanan gün, seri gizliyken rozet.

---

## E9. Rozet motoru (`BadgeEngine`)

- `badges.tr.json` kural tablosu; kod yalnız kural tiplerini bilir:

| Kural tipi | Örnek |
|---|---|
| `streak(n)` | 7, 30, 100 günlük seri |
| `entries(kind?, n)` | 10 söze yazı, 50 girdi |
| `words(n)` | Toplam 10.000 kelime |
| `themeComplete(n)` | Bir haftalık temanın 7 gününü yazmak |
| `bothRituals(n)` | Sabah + akşamı aynı gün n kez |
| `comparison(n)` | Aynı soruya zaman içinde n kez cevap |
| `firstOf(kind)` | İlk söze yazı, ilk rehberli günlük |

- Her kayıttan sonra ve açılışta değerlendirilir; `BadgeAward` idempotent (aynı rozet iki kez verilmez, CloudKit tekrarında dedupe).
- Geriye dönük: güncelleme sonrası eklenen rozet, geçmiş veriden hak edilmişse sessizce verilir (kapanış ekranında duyurulmaz, Profil'de görünür).
- Relaunch hedefi: 20 rozet.

---

## E10. İçgörü motoru (`InsightsEngine`)

| İçgörü | Hesap | Minimum veri |
|---|---|---|
| Mood çizgisi | Gün başına ortalama skor, dönem 14/30/90/365 gün | 3 check-in |
| Ortalama ve değişim | Dönem ortalaması, bir önceki dönemle fark | 7 check-in |
| Duygu dağılımı | Aile ve duygu frekansı, yüzde | 5 check-in |
| Etiket ilişkisi | "Uyku etiketli günlerde ortalama 2,8, diğerlerinde 3,6" — yalnız gözlem dili, en az 5 örnekli etiketler | 21 check-in |
| Yazma istatistiği | Girdi sayısı, kelime, en uzun seri, en çok yazılan tür | 1 girdi |
| Günün saati | Check-in/yazma saat dağılımı | 10 kayıt |
| Söz temaları | En çok beğenilen ve yazılan söz temaları | 5 etkileşim |
| Geçen yıl bugün / geçen ay bugün | O güne ait girdiler | 1 eşleşme |
| Değişim çiftleri | Aynı soruya/söze farklı zamanlardaki cevaplar yan yana | 2 cevap |
| Yılın özeti | Aralık'ta: yukarıdakilerin yıllık hali + en uzun yazı + en çok yazılan söz | 30 gün veri |

- Hesap Core Data'da `propertiesToFetch` + dönem filtresiyle; sonuç dönem başına bellekte önbellek, veri değişince geçersiz.
- Ay kapanışında (`BGAppRefreshTask` ya da ilk açılış) aylık özet önceden hesaplanır.
- Minimum veri yoksa ilgili kart "Henüz erken" boş durumuna düşer; motor `InsightResult.insufficient(needed:)` döner.

**Test:** 5 yıllık sentetik veride 365 günlük hesap < 200 ms; etiket ilişkisi eşiği; boş veri.

---

## E11. Arama (`SearchIndex`)

- `Entry`'ye `searchText` alanı eklenir: başlık + gövde + soru/söz snapshot + etiket adları; Türkçe yerelde küçük harf, ek olarak aksansız kopya (ş→s, ı→i…) ki "gunluk" araması "günlük"ü bulsun.
- Sorgu `searchText CONTAINS[cd]` + tarih/tür/etiket/skor filtreleri; sonuçlar tarih sırasıyla, eşleşen parça vurgulu.
- Sözler sekmesinde arama: katalogda bellek içi indeks (metin + yazar + tema).
- Spotlight (`CSSearchableIndex`) ve App Intents ile girdi arama relaunch sonrasına.

---

## E12. Kişiselleştirme profili (`UserProfileStore`)

`NSUbiquitousKeyValueStore` + App Group UserDefaults (ADR §9):

| Anahtar | Değer |
|---|---|
| `profile.name` | Selamlama için ad (isteğe bağlı) |
| `profile.focusAreas` | Onboarding odakları (ör. `kaygi`, `odak`, `minnet`, `uyku`, `iliskiler`) |
| `profile.quotePaths` | Seçilen söz yolları |
| `profile.ritualMode` | `daily` / `morningEvening` |
| `profile.morningTime`, `profile.eveningTime` | Hatırlatma saatleri |
| `profile.streakVisible` | Bool |
| `profile.resurfaceWritten` | E2.2 kural 4 açık mı |
| `profile.userSalt` | Tohum UUID (ilk açılışta) |
| `profile.contentLang` | `tr` (sonra `en`) |

Onboarding sonrası değiştirilebilir; değişiklik E2/E4/E7 kuyruklarını geçersiz kılar.

---

## E13. Bildirim içerik planlayıcı

ADR §6 motoru üstüne yalnız "ne yazacağı":

| Tür | Metin kaynağı | Varsayılan |
|---|---|---|
| `morningRitual` | Günün sözünün ilk cümlesi ya da ritüel cümlesi (dönen havuz) | Açık |
| `eveningRitual` | "Günü kapatma vakti." + bugün yapılmadıysa tema sorusu | Açık |
| `weeklyTheme` | Pazartesi: tema adı + ilk soru | Açık |
| `contentSuggestion` | Karşılaştırma adayı (E4) veya geri dönen söz (E2.2 kural 4) | Kapalı |
| `streakReminder` | Seri risk altındaysa, akşam saatinden 2 saat sonra | Kapalı (ADR kararı) |

- Metinler 7 günlük kayan pencereyle önceden hesaplanır (ADR bütçesi); içerik güncellenince pencere yeniden kurulur.
- Aynı gün uygulama zaten açıldıysa o günün hatırlatması iptal edilir.

---

## E14. Widget veri yazıcı

App Group'a `w2_*` anahtarları (ADR §9):
`w2_dailyQuote` (metin, kaynak, id) · `w2_week` (7 günün durumu) · `w2_streak` (sayı, görünürlük) · `w2_todayCheckin` (skor, etiket, yankı cümlesi) · `w2_theme` (tema adı, günün sorusu) · `w2_version`.
Tetik: her kayıt, gün değişimi, içerik güncellemesi; `WidgetCenter.reloadTimelines`. Widget gece yarısı için bir sonraki günün sözünü de önceden alır (E2.4 deterministik olduğu için hesaplanabilir).

---

## E15. Premium kapısı

`PremiumFeature` listesi (teardown sonrası kesinleşecek, taslak):

| Özellik | Ücretsiz | Premium |
|---|---|---|
| Günlük ritüel, check-in, günün sorusu, boş sayfa | Var | Var |
| Sözler akışı | Sana özel + 1 yol | Tüm yollar, tüm türler |
| Söze yazı | Var | Var |
| Rehberli günlükler | 3 temel | Tümü |
| Geçmiş temalar | Son 4 hafta | Tümü |
| Eğilimler | 14 gün mood + temel yazma istatistiği | Tüm dönemler, duygu/etiket ilişkisi, değişim çiftleri |
| Seri ve rozetler | Var | Var |
| Özel şablonlar | Yok | Var |
| Kilit (Face ID) | Var | Var |
| Widget | Günün sözü | Tümü |
| Dışa aktarma | JSON | JSON + Markdown arşivi |

Not: Stoic streak'i, sync'i ve kilidi premium yapıyor; ONE bunları ücretsiz bırakıyor. Veri güvenliği ve ritüel ücretli olmamalı (dürüstlük + App Store yorumu).

---

## E16. Dışa aktarma v2

- JSON: tüm entity'ler + içerik snapshot'ları (söz metni, soru metni) — içerik kataloğu olmadan da okunur. Mevcut `ArchiveExporter` sabit anahtar deseni korunur.
- Markdown arşivi (zip): her gün bir `.md`, fotoğraflar klasörde; başka bir günlük uygulamasına taşınabilir.
- Eski v3 kayıtları "ONE 1" bölümünde.

---

## E17. Analitik olay kataloğu v2

PostHog altyapısı korunur (ADR). Olay adları `one2_` önekiyle; metin içeriği asla gönderilmez, yalnız ID ve sayılar.

| Grup | Olaylar |
|---|---|
| Onboarding | `one2_onboarding_step`, `one2_onboarding_done` |
| Ritüel | `one2_checkin_done` (skor, duygu sayısı), `one2_ritual_done` (tür), `one2_day_completed` |
| Yazma | `one2_entry_saved` (tür, kelime aralığı, kaynak: tema/söz/boş/öneri), `one2_comparison_shown` |
| Sözler | `one2_quote_seen` (toplu, oturum başına sayı), `one2_quote_liked`, `one2_quote_write_tap`, `content_pool_low` |
| Seri/rozet | `one2_streak_broken`, `one2_backfill_used`, `one2_badge_awarded` |
| Premium | `one2_paywall_shown` (source), `one2_trial_started`, `one2_purchase` |
| Sağlık | `theme_missing_next_week`, `content_update_failed` |

Huniler: kurulum → ilk check-in → ilk yazı → 7. gün dönüş; Sözler kartı → yaz dokunuşu → kaydedilen yazı.

---

## E18. İçerik üretim hattı

- Kaynak: Google Sheets (Görkem için kolay) → dışa aktarılan CSV → `tools/content/build_content.py` → JSON + manifest → `website/content/v1/` PR'ı → birleştirilince yayın; `sync_bundled_content.sh` aynı JSON'u `one/ONE2/Content/Bundled/`'e kopyalar.
- **Doğrulayıcı kuralları (CI'da, hata = yayın yok):**
  - Şema: zorunlu alanlar, bilinen tema/yol/duygu ID'leri, uzunluk sınırları.
  - Türkçe: `İ/ı` doğru, düz tırnak yerine tipografik tırnak, çift boşluk yok, sonda boşluk yok.
  - Tekrar: normalize metinde (küçük harf, noktalama/aksan temizliği) trigram Jaccard > 0,85 olan çiftler hata.
  - Kaynak: `kind = quote` ise `author` + `source` + `license` zorunlu. Kaynağı doğrulanamayan "internette X'e atfedilen" sözler eklenmez (yanlış atıf hem hukuki hem güven riski).
  - Telif: kamu malı olmayan modern yazar yok. Kamu malı eserlerin **modern çevirileri telifli olabilir**: ya kamu malı çeviri ya ekip çevirisi (`translation = oneTranslation`).
  - Ton (E6 ve olumlamalar): ünlem, emoji, "asla/her zaman" gibi mutlak vaat, sonuç vaadi ("30 günde") listesi.
  - ID'ler: yeni ID çakışmaz, silinen ID yeniden kullanılmaz.
- Relaunch içerik hedefleri:

| İçerik | Relaunch | Sonra |
|---|---|---|
| Söz / olumlama / atasözü / düşünce | 800 (motor 1.500+ için) | haftalık, ≥ +100/ay |
| Genel söze yazı soruları | 60 | +10/ay |
| Serbest günlük soruları | 200 | +20/ay |
| Haftalık temalar | 16 (Aralık + 3 ay) + 8 evergreen | 2 hafta önden |
| Rehberli günlük | 12 | +2/ay |
| Yankı cümleleri | 150 | +20/ay |
| Duygu / neden / rozet / yol katalogları | 40 / 20 / 20 / 5 | — |

---

## Veri modeli eklemeleri (`one 3`, production deploy öncesi)

| Değişiklik | Neden |
|---|---|
| `ContentExposure` entity (E3) | Tekrarsızlık ve favoriler |
| `Entry.kind` += `quoteReflection` | Söze yazı (contentRef = söz ID) |
| `Entry.searchText` String? | Arama (E11) |
| `Entry.sourceContext` String? | `theme`, `quote`, `free`, `suggestion`, `comparison`, `guided` (analitik ve içgörü) |
| `Entry.comparedEntryID` UUID? | Karşılaştırma zinciri (E4) |
| `DayRecord.completedBy` String? | `ritual` / `writing` (E8 alternatif tamamlama) |

Hepsi opsiyonel, CloudKit uyumlu. `initializeCloudKitSchema` (Faz 1 #10) bu eklemelerden **sonra** çalıştırılmalı.

## Kararlar (Batuhan, 23 Eylül 2026)

| # | Konu | Karar |
|---|---|---|
| 1 | Geriye dönük doldurma penceresi (E8) | **Son 7 gün** |
| 2 | Yazılı girdinin günü tamamlaması (E8) | **Evet**, o gün ≥ 20 kelimelik yazılı girdi günü tamamlar |
| 3 | Yazılan sözün 90 gün sonra geri dönmesi (E2.2 kural 4) | **Varsayılan açık**, ayardan kapatılabilir (`profile.resurfaceWritten`) |
| 4 | Ücretsiz Sözler (E15) | **"Sana özel" + 1 yol**; diğer yollar premium |
| 5 | İçerik hacmi (E2.6, E18) | Relaunch'ta **en az 800 öğe**, sonra haftalık ekleme. Motor **1.500+ öğe** için tasarlanır |

---

## Claude Code — Prompt 5 (bu doküman onaylandıktan sonra)

```
docs/one2/04_arka_plan_motorlari.md, ADR-001.md, MIGRATION.md ve 02_veri_modeli.md'yi oku.

Arayüz yazmadan, 04'teki motorları sırayla uygula. Her adım ayrı commit, her motorun Swift Testing testleri aynı committe:

1. `one 3` modeline "Veri modeli eklemeleri" tablosundaki alanları ve ContentExposure entity'sini ekle (CloudKit kuralları: opsiyonel, ters ilişki, unique yok). Mevcut testler geçmeli.
2. E1: İçerik şeması v1 Swift modelleri (Codable), ContentRepository'yi bu dosyalarla genişlet; örnek bundle içeriği olarak her dosyadan 20–50 öğelik geçici Türkçe örnek üret ve `// PLACEHOLDER CONTENT` diye işaretle.
3. E3 ExposureStore (toplu yazma, dedupe).
4. E12 UserProfileStore.
5. E5 ThemeCalendar.
6. E2 QuoteEngine: katalog modeli, tekrarsızlık kuralları (E2.2), kuyruk ve puanlama (E2.3), günün sözü (E2.4), API (E2.5). 1.000 kartlık simülasyon testi dahil.
7. E4 PromptEngine, E6 EchoEngine.
8. E7 RecommendationEngine.
9. E8 kurallarının Streak/DayCompletion'a eklenmesi, E9 BadgeEngine.
10. E10 InsightsEngine (temel set), E11 SearchIndex.
11. E13 bildirim metin planlayıcı ve E14 widget yazıcı (mevcut Orchestrator ve WidgetDataWriter desenleriyle).
12. E16 dışa aktarma v2, E17 olay kataloğu.

Kurallar: çekirdek mantık saf ve AppClock + SeededRandom ile deterministik; UI yok; yeni SPM bağımlılığı yok; ADR'deki klasör ve izolasyon kuralları geçerli. Her adımın sonunda kısa bir rapor: ne yapıldı, testler, açık kalanlar. E18 için `tools/content/build_content.py` doğrulayıcısını ayrıca yaz (Python, standart kütüphane).
```
