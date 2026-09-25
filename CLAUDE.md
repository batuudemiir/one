# ONE 2.0 — Çalışma Kuralları

v3 kuralları arşivde: `docs/archive/CLAUDE_v3.md`. Ürün yönü değişti; oradaki
"Duruş" ve "Yapılmayacaklar" bölümleri artık bağlayıcı değil.

## Ürün

ONE 2.0: günlük (journal) + mood check-in + sabah/akşam ritüeli + haftalık
tema + seri (streak) ve rozetler + geriye dönük giriş + premium. Referans
sistem Stoic'in akışı; içerik ve marka bizim.
Rehberli akışlarda süre bilgisi ("2 dakika") serbest.

**Doğruluk kaynağı `docs/one2/`.** Kod ile doküman çelişirse doküman kazanır;
çelişkiyi fark edersen düzeltmeden önce söyle.

| Dosya | İçerik |
|---|---|
| `00_faz0_plan.md` | Faz planı, kilitlenen kararlar |
| `02_veri_modeli.md` | Varlıklar, alanlar, CloudKit kuralları |
| `AUDIT.md` | v3 kod tabanı envanteri ve riskler (R1–R17) |
| `MIGRATION.md`, `ADR-001.md` | Taşıma ve mimari kararları (yazıldıkça) |

## Sabit kimlikler — asla değiştirilmez

| Kimlik | Değer |
|---|---|
| Bundle ID (app) | `com.batu.ones` |
| CloudKit container | `iCloud.com.batu.ones` |
| App Group | `group.com.batudemir.ones` |
| Widget kind | `MoodWidget` |
| URL scheme | `ones` |

Önek karışıklığı (`com.batu` / `com.batudemir`) bilinçli olarak kalıyor —
"düzeltme" girişimi CloudKit verisini, Keychain'i ve widget'ları koparır.
StoreKit ürün ID'leri `com.batudemir.ones.oneplus.*` (bkz. `ONEPlus.storekit`).

## Veri kuralları

- **`DailySong` entity'sine ve mevcut model sürümlerine (`one`, `one 2`)
  dokunulmaz.** Alan ekleme, yeniden adlandırma, silme yok. Üretim CloudKit
  şemasında duruyorlar ve v3 kullanıcılarının verisi orada.
- Yeni entity'ler **yalnız yeni model sürümüne** (`one 3` ve sonrası) eklenir;
  sürüm değişikliği lightweight migration ile açılabilmeli.
- CloudKit uyumu: her alan opsiyonel ya da varsayılanlı; unique constraint
  yok; her ilişki opsiyonel ve ters ilişkili; ordered ilişki yok; büyük ikili
  veri harici depolamada (`allowsExternalBinaryDataStorage`).
- Yeni şema yayından önce Dashboard'dan Production'a deploy edilir.
  Deploy edilmiş record type/alan geri alınamaz — eklemeden önce düşün.
- Türetilen veri (seri, istatistik) saklanmaz, hesaplanır.
- `dayKey` (`yyyy-MM-dd`, yerel gün) her kayıtta var; gün hesabını elle
  `startOfDay` ile yapma, ortak yardımcıyı kullan.
- Kaldırılan bir bildirim türünün kimliği `NotificationOrchestrator`'ın
  emekli listesine eklenir — kod silmek bekleyen isteği silmez.

## Tasarım (ONE 2.0)

**Kaynak `docs/one2/design-system/`:** `README.md` (marka kitabı),
`tokens.json`, `components/*.md` (bileşen kuralları), `components/*.preview.html`
(ölçüler), `Screen*.preview.html` (referans ekranlar). Kararın kaydı
`docs/one2/ADR-002-design-system.md`: ADR-001 §7'deki "V3Tokens taşı" kararı
ONE 2.0 için geçersiz.

- **Token'lar `one/ONE2/DesignSystem/Tokens/`:** renk `ONE2Color` (47 renk,
  tokens.json adlarının camelCase hâli), tipografi `.one2Type(_:)`
  (`ONE2Type` rolleri), boşluk `ONE2Space`, ölçü `ONE2Size`, köşe
  `ONE2Radius`, gölge `.one2FloatShadow()`, hareket `ONE2Motion`, haptik
  `ONE2Haptics`. Yeni kod yalnız bunları kullanır; elle sayı ya da hex yok.
- **Renk değeri yalnız `ONE2Palette`'te** ve tokens.json ile birebir
  (`ONE2TokenTests`). Yeni renk önce tokens.json'a, sonra palete girer.
  Renkler `UIColor` dynamic provider ile: gece/gün ve Increased Contrast
  (`line` → `lineStrong`, `inkFaint` → `inkMuted`).
- **Fontlar** `one/ONE2/Resources/Fonts/` (OFL, lisanslar yanında): Plus
  Jakarta Sans 500/600/700, Literata 400 ve 400 italik (statik), IBM Plex
  Mono 400/500. Literata yalnız yazının kendisinde (soru, kullanıcı metni,
  söz, yankı). `label` metnini `ONE2Type.uppercased(_:)` ile büyüt (i → İ).
- `brand` ekran başına tek yerde; birincil buton renkli değil kontrastlı
  (`primary`); kartlar gölgesiz, gölge yalnız dock'ta.
- Bileşenler `one/ONE2/DesignSystem/Components/`, bileşen başına bir dosya;
  her bileşen ve ekranda `#Preview`: gece, gün ve Dynamic Type
  `.accessibility3`. Galeri: `DesignSystemGallery` (yalnız DEBUG).
- Reduce Motion: yalnız opaklık (`ONE2Motion`). Reduce Transparency:
  `glass` → `raised`.

## v3'ten korunan kod kuralları

- **Token'lar (yalnız legacy ekranlar):** `V3Tokens`, `V3Typography` /
  `ONETypography`, `ONEAnimation`, `ONEHaptics`, `oneScreenBody()` yalnız v3
  kabuğunda ve ONE 2.0'daki legacy "ONE 1" kartlarında. Yeni ONE 2.0 kodu
  yukarıdaki ONE2 token'larını kullanır.
- **Hardcoded hex yok.** v3'te yeni renk `V3Tokens`'a, ONE 2.0'da
  tokens.json + `ONE2Palette`'e girer; ikisi de dynamic provider ile. Tek
  istisna dışa aktarılan yüzeyler (`V3Tokens.Export`, `*Fixed` fontlar).
- **Her `Button` label'ına `.contentShape(Rectangle())`.** v3'te buton stili
  `.onePressable`; ONE 2.0'da ONE2 buton stilleri. `.plain` yok. Dokunma
  hedefi ≥ 44pt.
- **Önce mevcut bileşen:** ONE 2.0'da `one/ONE2/DesignSystem/Components/`.
  `V3TopBar`, `SubScreen`, `V3Sheet*`, `V3PrimaryButton` / `V3OutlineButton`,
  `.oneCardBackground`, `V3Loading`, `ONEErrorView`, `ONEToastView` yalnız
  legacy ekranlar içindir. Yeni bileşen ancak karşılığı yoksa.
- Sistem `navigationTitle` / `ToolbarItem` kullanılmaz; başlığı kabuk çizer.
- Her ekranın yükleniyor, boş ve hata durumu tanımlı.
- **Sormadan yeni SPM bağımlılığı yok.**
- **İşlevsiz kontrol yok:** hiçbir yerin okumadığı toggle/ayar eklenmez.
- Kullanıcıya görünen her dize `NSLocalizedString`; yeni anahtar dokuz dile
  birden (de · en · es · fr · ja · ko · ru · tr · zh-Hans). **Geçici istisna
  (ONE 2.0 UX işi):** yeni anahtarlar yalnız `tr` ve yanında `en` yer
  tutucusuyla girer; diğer 7 dil relaunch öncesi ayrı bir iş.
- İkon butonunda `accessibilityLabel`; dekoratif öğe `accessibilityHidden`.
  WCAG AA kontrast; Reduce Motion ve Dynamic Type desteklenir.

## Kopya

**Artık serbest** (v3'te yasaktı): seri ve "N gün üst üste", rozetler,
geriye dönük giriş ve "dünü tamamla" dili, skor/ölçüm (1–5, evet/hayır,
trendler), rehberli ve destekleyici dil, uygulamanın soru sorması.

**Hâlâ geçerli:**
- Emoji yok (durum işareti ✓ muaf).
- Üst üste ünlem yok (`!!`, `?!`). Tek ünlem idareli.
- Türkçe kopya **sen** diliyle, kısa: cümle 5–12 kelime.
- Butonlar cümle düzeninde, 1–3 kelimelik fiil ("Kaydet", "Devam et").
- ONE 2.0 başlıkları küçük harf ve noktasız: sekme başlığı ("keşfet",
  "yolculuk"), selamlama ("iyi akşamlar"), kapanış ("bugün kapandı"). Bölüm
  ve kart başlıkları cümle düzeninde ("Pratiklerin", "Haftalık tema").
  Başlık sonunda nokta yok.
- Ekran başına en fazla bir ünlem. Ton sakin yol arkadaşı: öğüt yerine
  soru, sonuç vaadi yok, seri kırılınca suçlama yok (README "Ses ve kopya").
- Mono `label` büyük harf ve Türkçe kurala göre ("GENEL İÇGÖRÜLER").
- Teşhis koyan dil yok ("depresyondasın"); duyguyu kullanıcı adlandırır.
- Suçlayan ya da yalvaran geri kazanım dili yok ("seni özledik").

## Stoic'ten kopyalanmaz

Sistem ve akış referans alınır; şunlar **kopyalanmaz**: prompt ve soru
metinleri, alıntı seçkisi, mentor/karakter, görseller ve illüstrasyonlar,
marka öğeleri (ad, logo, renk paleti, ikonografi). Kendi içeriğimizi yaz.

## Faz kuralları

- Faz 0 kapandı (23 Eylül 2026). `ADR-001.md` kabul edildi ve bağlayıcı:
  yeni kod `one/ONE2/`, v3 `Features/*` ve `CloudKitManager`'a erişim yok.
- Çevre ONE 2.0'da yok (ADR §10). Yeni kod sosyal katmana bağlanmaz.
- Faz 1 iş sırası: ADR-001 › "Faz 1: ilk 10 iş kalemi".
- **İki kabuk, tek build:** `ONE2Flag` DEBUG ve TestFlight'ta açık (ONE 2.0),
  App Store'da kapalı (v3). Xcode'da v3'ü görmek için launch argument
  `-ONE2Enabled NO`; ONE 2.0 Profil'inde "Eski arayüze dön" düğmesi de var
  (bir sonraki açılışta). Bayrağa bağlı v3 kodu: `oneApp.swift` açılış
  katmanları ve deep link'ler, `Persistence.reconcileAfterRemoteChange`,
  `MidnightResetManager` görev işleyicisi, `AppDelegate` CloudKit push'u.
- ONE 2.0 açıkken `DailySong`'a insert/update DEBUG'da `assertionFailure`
  verir (`LegacyWriteGuard`); silme serbest.
- **Tek klasör, tek dal (25 Eylül 2026, Batuhan):** tüm ONE 2.0 işi
  `~/Desktop/one/one` klasöründe, `one2/faz1` dalında. Ayrı worktree ya da
  proje kopyası açılmaz; paralel oturumlar aynı ağaçta dosya sahipliğiyle
  çalışır (05 › Sahiplik sınırları). Kullanıcı her şeyi tek build'de görür.
- ONE 2.0 işi `one2/*` dallarında. Gerçek kullanıcı verisi (CloudKit
  dökümleri, `tooling/*.json`) repoya girmez; repo public.

## Derleme

`xcode-select` CommandLineTools'u gösteriyor; tam toolchain Xcode içinde
(23 Eylül 2026: `/Applications/Xcode.app`, Xcode 27.0). Yolu sabit sayma,
önce `ls -d /Applications/Xcode*.app`. Tip denetimi:

```bash
X=/Applications/Xcode.app/Contents/Developer
SDK="$X/Platforms/iPhoneSimulator.platform/Developer/SDKs/iPhoneSimulator.sdk"
CD=$(mktemp -d)
"$X/usr/bin/momc" --sdkroot "$SDK" --module one --swift-version 5.0 \
  --action generate --swift-output-dir "$CD/src" \
  "one/one.xcdatamodeld/one 3.xcdatamodel" "$CD"
"$X/Toolchains/XcodeDefault.xctoolchain/usr/bin/swiftc" -typecheck \
  -sdk "$SDK" -target arm64-apple-ios17.0-simulator \
  -swift-version 5 -module-name OneDailyBatuhan \
  -enable-upcoming-feature MemberImportVisibility -default-isolation MainActor \
  $(find one -name '*.swift') "$CD"/*.swift OneActivityExtension/ActivityAttributes.swift
```

- `momc` Swift dosyalarını `--swift-output-dir`'e değil doğrudan `$CD`'ye
  yazıyor; `"$CD"/*.swift` bu yüzden doğru.
- `-default-isolation MainActor` şart. Core Data sınıfları derleme anında
  üretiliyor; yukarıda `momc` ile üretiliyor (yeni model sürümü gelince yolu
  güncelle). Süre ~5 dk.
- `swiftc -parse` yalnız sözdizimi bakar; doğrulama `-typecheck` ile.
- Birden çok oturum aynı ağaca yazıyorsa "input file was modified during the
  build" hatası gelir: ağacı `rsync -a one <scratch>/` ile kopyalayıp orada
  denetle.
