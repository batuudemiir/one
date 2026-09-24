# Sözler ve düşünürler — içerik modeli ve söz motoru v2

Sürüm 1.0 · 24 Eylül 2026 · Sahibi: motor oturumu (`one2/faz1`)
Bu belge 04'teki E1 (şema), E2 (söz motoru) ve E18 (üretim hattı) bölümlerini **genişletir**. Çelişkide bu belge (08) geçerli.

---

## 1. Karar: Sözler yalnız düşünürlerin kaynaklı sözleridir

- Sözler akışında yalnız `kind = quote` gösterilir: filozofların, düşünürlerin ve psikologların, **sahibinin adıyla** birlikte gösterilen sözleri.
- `affirmation`, `proverb`, `reflection` şemada kalır (eski ID'ler bozulmasın), ama akış modlarına girmez. Olumlama türü gerekiyorsa yankı motorunda (E6) kullanılır.
- Her söz bir **düşünüre** (`Thinker`) bağlıdır. Serbest metin `author` alanı kalkar; yerine `authorID` gelir.
- Kaynağı doğrulanmamış söz yayına girmez.

## 2. Gösterim (Stoic'teki gibi)

Kart düzeni:

```
Kendini tanımak, bilgeliğin başlangıcıdır.

— Aristoteles
```

- Söz tırnaksız, `quote` stilinde. Altında boş satır, sonra **"— {displayName}"** (`body-sm`, `ink-muted`; fotoğraflı arka planda beyaz %80).
- Eser adı kartta yazmaz. Adın yanındaki küçük "kaynak" işareti → sheet: eser, bölüm/sayfa, çeviri bilgisi, düşünür sayfasına bağlantı.
- Paylaşım görselinde de aynı düzen: söz + "— Ad" + küçük wordmark.
- Ad yazımı Türkçe yerleşik biçimde: Epiktetos, Marcus Aurelius, Konfüçyüs, Lao Tzu, Farabi, İbn Sina, Mevlana, Kierkegaard. `displayName` tek kaynaktır; UX adı kendisi biçimlendirmez.

Motor bu satırı hazır verir: `Quote.attribution` → `"Aristoteles"` (UX başına "— " ekler).

## 3. İçerik modeli (şema v2)

### 3.1 `catalogs/thinkers.tr.json` (yeni)

| Alan | Tip | Not |
|---|---|---|
| `id` | String | `th_seneca`, ASCII, kalıcı, asla yeniden kullanılmaz |
| `displayName` | String | Kartta görünen ad ("Marcus Aurelius") |
| `shortName` | String | Dar alanlar için ("Aurelius" değil; genelde aynı ad) |
| `aliases` | [String] | Arama için ("Marcus", "Aurelius", "Markus Aurelius") |
| `kind` | enum | `philosopher`, `psychologist`, `thinker`, `mystic`, `writer` |
| `birthYear`, `deathYear` | Int? | MÖ için negatif; yaşıyorsa `deathYear` yok |
| `eraDisplay` | String | "MS 4 – 65", "1905 – 1997" |
| `pathIDs` | [String] | 1–2 düşünce yolu (§3.3) |
| `coreIdea` | String | Tek cümle, ≤ 120 karakter |
| `bioShort` | String | 3–4 cümle, ≤ 420 karakter |
| `portraitAsset` | String? | ONE illüstrasyonu (fotoğraf yok) |
| `rights` | enum | Doğrulayıcı hesaplar: `publicDomain` / `protected` (§5) |
| `active`, `addedIn`, `lang` | | E1 |

### 3.2 `quotes.tr.json` (v2 alanları)

| Alan | Değişiklik |
|---|---|
| `authorID` | **Yeni, `quote` için zorunlu.** thinkers kataloğunda olmalı |
| `author` | Kaldırıldı; loader v1 dosyalarını okurken ada göre `authorID`'ye eşler |
| `source` | Nesne oldu: `{ work, locator, translation, translator?, verifiedBy, verifiedAt }` |
| `source.work` | Eser adı, Türkçe yerleşik adıyla ("Ahlak Mektupları") |
| `source.locator` | Mektup/bölüm/paragraf/sayfa ("Mektup 1, 1") |
| `source.translation` | `original` · `oneTranslation` · `publicDomainTranslation` |
| `verified` | Bool; `false` ise yayın yok |
| `paraphrase` | Bool; eserdeki cümlenin kısaltılmış veya yaygın biçimi ise `true` ve kaynak sheet'inde "uyarlama" yazar |
| `tones` | **Yeni.** Eski "ses" yolları buraya taşındı: `sakin`, `cesur`, `sefkatli`, `uretken`, `derin` |
| `paths` | Artık düşünce yolu; varsayılan düşünürün `pathIDs`'i, gerekirse öğe bazında daraltılır |
| `reflectionPromptIDs` | `quote` için **en az 1 zorunlu** (söze özel soru) |
| Diğerleri | `themes`, `emotionFit`, `moodFit`, `timeOfDay`, `length`, `premium`, `active`, `addedIn`, `lang` aynı |

`manifest.schemaVersion` = 2. Loader v1 ve v2'yi okur. v1'deki kişi adları eşleme tablosuyla `authorID`'ye çevrilir; eşleşmeyen `quote` öğesi pasifleşir ve log'a yazılır.

### 3.3 `catalogs/paths.tr.json` (yeniden)

Eski yollar (`filozof`, `sakin`, `cesur`, `sefkatli`, `uretken`) `tones`'a taşınır. Yollar artık düşünce gelenekleri:

| ID | Başlık | Premium |
|---|---|---|
| `stoacilar` | Stoacılar | Hayır (varsayılan ücretsiz yol) |
| `antik_yunan` | Antik Yunan | Evet |
| `varoluscular` | Varoluşçular | Evet |
| `dogu_bilgeligi` | Doğu bilgeliği | Evet |
| `islam_anadolu` | İslam ve Anadolu düşüncesi | Evet |
| `psikologlar` | Psikologlar | Evet |
| `modern_dusunce` | Modern düşünce | Evet |

Ücretsiz kullanıcı: "Sana özel" + **onboarding'de seçtiği ilk yol** (seçmediyse `stoacilar`). "Sana özel" modu ücretsiz kullanıcıda yalnız açık yolundan ve tüm yollardan karışık bir **tanıtım payından** beslenir (§4.4).

### 3.4 Başlangıç düşünür listesi (içerik ekibi yıllarla birlikte doldurur)

- **Stoacılar:** Seneca, Epiktetos, Marcus Aurelius, Zenon, Musonius Rufus
- **Antik Yunan:** Platon (Sokrates sözleri yalnız Platon/Ksenophon eserlerinden, düşünür = Sokrates, kaynak = eser), Aristoteles, Epikuros, Herakleitos, Diogenes
- **Varoluşçular:** Kierkegaard, Nietzsche, Dostoyevski, Camus*, Sartre*, Simone de Beauvoir*
- **Doğu bilgeliği:** Lao Tzu, Konfüçyüs, Buda (Dhammapada), Zhuangzi, Tagore
- **İslam ve Anadolu düşüncesi:** Mevlana, Yunus Emre, Farabi, İbn Sina, Gazali, İbn Arabi, İbn Haldun, Hacı Bektaş Veli, Şems-i Tebrizi
- **Psikologlar:** William James, Sigmund Freud, Alfred Adler, Karen Horney, Carl Jung*, Viktor Frankl*, Erich Fromm*, Carl Rogers*, Abraham Maslow*, Rollo May*
- **Modern düşünce:** Montaigne, Pascal, Spinoza, Kant, Schopenhauer, Goethe, Emerson, Thoreau, Simone Weil, Wittgenstein, Bertrand Russell*

`*` = telif koruması muhtemelen sürüyor (§5). İlk sürüm hedefi: 45–60 düşünür, düşünür başına 15–30 söz. Relaunch'ta en az 800 söz; motor 1.500+ için tasarlanır.

## 4. Söz motoru v2

### 4.1 Değişmeyenler
E2.2 tekrarsızlık garantisi, döngü 2 ve 60 gün kuralı, yazılan sözün 90 gün sonra geri dönmesi, günün sözünün deterministik ve KVS'de paylaşılması, kalıcı kuyruk, `onSeen`/`onSkipped` görünürlük sözleşmesi.

### 4.2 Yeni modlar

```swift
enum QuoteFeedMode: Hashable {
    case forYou
    case path(PathID)
    case thinker(ThinkerID)      // yeni: düşünür sayfası ve "Bu hafta onunla"
    case theme(String)
    case favorites
    case written
}
```

- `thinker(id)`: yalnız o düşünürün sözleri, görülmemişler önce, sonra döngü 2. Tükenince "Bu düşünürün hepsini gördün." + benzer düşünürler.
- **Bu hafta onunla** (`focusThinker(id, days: 7)`): 7 gün boyunca "Sana özel" kuyruğunda her 4 kartın 1'i bu düşünürden; günün sözü bu haftada en az 2 kez ondan. `UserProfileStore`'da `profile.focusThinker = {id, until}`.

### 4.3 Puanlama v2 ("Sana özel")

| Bileşen | Ağırlık | Nasıl |
|---|---|---|
| Yol uyumu | 0,20 | Seçili yollarla kesişim |
| **Düşünür yakınlığı** | 0,15 | §4.5 skoru, 0–1'e ölçeklenmiş |
| Haftalık tema | 0,10 | Ortak tema |
| Ruh hali ve ton | 0,15 | Son skor `moodFit` içinde mi; skor ≤ 2 ise `sefkatli`/`sakin` tonu artı, `cesur`/`uretken` eksi |
| Günün saati | 0,05 | `timeOfDay` |
| İlgi (tema) | 0,10 | Beğenilen/yazılan sözlerin temaları (90 gün) |
| **Yenilik** | 0,15 | Düşünür kullanıcıya hiç gösterilmediyse 1, son 7 günde gösterildiyse 0 |
| Rastgelelik | 0,10 | `SeededRandom(userSalt, dayKey)` |

Ağırlıklar yapılandırmada; test fixture'ında sabit.

### 4.4 Çeşitlilik kısıtları (puandan sonra)
- Aynı düşünür 8 kart içinde en fazla 1 kez; günde en fazla 2 kez (thinker modu hariç).
- Aynı yol en fazla 3 kez arka arkaya; kullanıcının 2+ yolu varsa her 10 kartta en az 2 farklı yol.
- **Keşif payı:** her 10 kartta 1 kart, kullanıcının seçmediği bir yoldan ve hiç görmediği bir düşünürden. Ücretsiz kullanıcıda bu kart premium yoldan gelebilir; kilitli değildir (tanıtım). Tanıtım kartı günde en fazla 2.
- Her 5 kartta en az 1 kısa söz (< 60 karakter).
- Aynı tema en fazla 2 kez arka arkaya.

### 4.5 Düşünür yakınlığı (öğrenen kısım)
- Olay puanları: beğen +1 · yaz +3 · paylaş +2 · uzun bakış (≥ 4 sn) +0,5 · hızlı geçiş −0,3 · beğeniyi geri al −1.
- Üstel azalma: yarı ömür 30 gün. Skor [−3, +10] aralığında sınırlanır.
- `ContentExposure`'dan hesaplanır; ayrı entity yok. Önbellek: bellekte, gün değişiminde ve `record` çağrısında güncellenir.
- Skor ≤ −2 olan düşünür 30 gün boyunca "Sana özel"de yalnız keşif payına girebilir.

### 4.6 Günün sözü v2
- Havuz: kullanıcının açık yollarındaki görülmemiş sözler. Dünkü günün sözünün düşünürü bugün seçilmez.
- Sabah bildirimi ve widget aynı sözü kullanır. `focusThinker` varsa §4.2'deki kural.
- Deterministik ve KVS paylaşımlı; kural değişmedi.

### 4.7 API eklemeleri

```swift
struct Thinker: Identifiable, Hashable, Sendable {
    let id: ThinkerID; let displayName: String; let shortName: String; let aliases: [String]
    let kind: ThinkerKind; let eraDisplay: String; let pathIDs: [PathID]
    let coreIdea: String; let bioShort: String; let portraitAsset: String?; let rights: RightsStatus
}
protocol ThinkerCatalog {
    func thinker(_ id: ThinkerID) -> Thinker?
    func thinkers(in path: PathID) -> [Thinker]
    func similar(to id: ThinkerID, limit: Int) -> [Thinker]   // ortak yol + ortak tema yoğunluğu
}
extension QuoteEngine {
    func focusThinker(_ id: ThinkerID, days: Int) async
    func thinkerProgress(_ id: ThinkerID) async -> (seen: Int, total: Int, written: Int)
    func affinity(for id: ThinkerID) async -> Double
}
// Quote'a eklenen: authorID, attribution (displayName), sourceRef, verified, paraphrase, tones
```

### 4.8 Arama (E11)
Düşünür `displayName` + `aliases` + eser adları indekse girer. "seneca" → düşünür sonucu önce, sonra sözleri. Türkçe büyük/küçük harf ve aksan duyarsız (i/İ, ı/I doğru katlanır).

### 4.9 Analitik (E17)
`quote_seen` ve `quote_action` olaylarına `authorID`, `pathID` eklenir. `content_pool_low` yol **ve** düşünür bazında atılır. Yeni: `thinker_opened`, `thinker_focus_started`.

## 5. Kaynak, çeviri ve telif kuralları (doğrulayıcı uygular)

Bu bölüm hukuki görüş değildir; `protected` düşünürler yayına girmeden önce hukuki kontrolden geçmelidir.

- `rights` hesabı: `deathYear` + 70 < bu yıl → `publicDomain`. Yaşayan ya da daha yakın tarihte ölen → `protected`. Doğum/ölüm yılı yoksa `protected` sayılır.
- `publicDomain` düşünür: eserden serbestçe alıntı. **Ama** Türkçe çeviri telifli olabilir: `source.translation` yalnız `oneTranslation` ya da `publicDomainTranslation` olabilir. Yayınevi çevirisi kopyalanmaz.
- `protected` düşünür: yalnız kısa alıntı. Metin ≤ 160 karakter, düşünür başına en fazla 12 aktif söz, `source.work` + `source.locator` zorunlu, `legalReviewed: true` olmadan `active` olamaz. Bu düşünürler premium yolda olsa da hepsinin toplamı katalogun %20'sini aşamaz.
- `verified: true` için birincil kaynak ve konum (sayfa/bölüm) şart. İkincil kaynaktan gelen söz yayına girmez.
- **Yanlış atıf listesi** `tools/content/misattributions.tsv`: yaygın yanlış atıflar (ör. "Delilik, aynı şeyi yapıp farklı sonuç beklemektir" → Einstein değil; "Gel, ne olursan ol yine gel" → Mevlana'nın eserlerinde yok). Doğrulayıcı normalize metinle karşılaştırır, eşleşme = hata.
- Doğrulayıcı ayrıca: düşünür `active` değilse sözü hata; `authorID` bilinmiyorsa hata; `quote` için `reflectionPromptIDs` boşsa hata; aynı düşünürde trigram Jaccard > 0,80 olan iki söz hata (aynı sözün iki çevirisi).

## 6. Üretim hattı (Görkem için)

- İki sayfa: `thinkers` ve `quotes` (Google Sheets → CSV → `build_content.py`).
- `quotes.csv` sütunları: `id` (boş = yeni) · `text` · `authorID` · `work` · `locator` · `translation` · `translator` · `verified` (E/H) · `verifiedBy` · `paraphrase` (E/H) · `themes` (`;` ile) · `tones` · `paths` (boş = düşünürden) · `emotionFit` · `moodFit` · `timeOfDay` · `reflectionQuestion` (serbest metin; build soru havuzunda `p_` ID'si üretir ve bağlar) · `premium` · `active` · `note`.
- `thinkers.csv` sütunları: `id` · `displayName` · `shortName` · `aliases` · `kind` · `birthYear` · `deathYear` · `eraDisplay` · `paths` · `coreIdea` · `bioShort` · `portraitFile` · `active`.
- Build raporu: yol ve düşünür başına aktif söz sayısı, `protected` oranı, soru bağlanmamış söz, hedefe kalan.

## 7. Uygulama adımları (motor oturumu)

| # | İş | Test |
|---|---|---|
| S1 | Şema v2: `Thinker`, `SourceRef`, `authorID`, `tones`, yeni `paths`; loader v1+v2; v1 ad → ID eşleme | v1 dosyası, v2 dosyası, eşleşmeyen yazar |
| S2 | `ThinkerCatalog` + bundle'a örnek `thinkers.tr.json` (mevcut 5 düşünür + listeden 10 yer tutucu, PLACEHOLDER notuyla) | `similar` sıralaması |
| S3 | Akış filtresi: modlarda yalnız `quote`; `thinker(id)` modu; premium yol kapısı (ilk seçilen yol ücretsiz) | ücretsiz / premium kuyruk içerikleri |
| S4 | Puanlama v2 + düşünür yakınlığı + çeşitlilik ve keşif payı | 1.000 kart simülasyonu: tekrar 0, 8'lik pencerede aynı düşünür ≤ 1, keşif payı oranı %10 ± 2, skor ≤ 2'de ton dağılımı |
| S5 | `focusThinker`, `thinkerProgress`; günün sözü v2 | art arda iki gün aynı düşünür yok; odak haftası oranı |
| S6 | Arama indeksi: düşünür ve alias | "SENECA", "ibn sina", "İbn Sînâ" |
| S7 | Doğrulayıcı v2 (§5) + `misattributions.tsv` + CSV şablonları + 10 örnek satır | her kural için bir kırmızı test |
| S8 | E17 alanları; `UX_istekleri.md`'ye ThinkerViewData eşlemesi notu | olay yükü şeması |

Her adım ayrı commit, sonunda rapor, dur.
