# ONE — Ekran Sözleşmesi

Bu dosya ONE'ın SwiftUI ekranları için bağlayıcı kuralları taşır. Tasarım
dilinin kaynağı `ui-ux-pro-max` skill'i; burada olan şey o dilin **kodda nasıl
zorlandığı**.

Denetleyici: `tooling/ui_guard.sh`. Eşikler `tooling/ui_guard_baseline.txt`
içinde ve **yalnız azalır** — bir faz bitince `--update` ile mandal bir kademe
sıkılır, bir daha gevşemez.

```bash
tooling/ui_guard.sh          # denetle
tooling/ui_guard.sh --report # dosya kırılımıyla göster
tooling/ui_guard.sh --update # eşikleri bugünkü sayıya çek (faz sonunda)
```

---

## Sekiz madde

Bir ekran ancak sekizini de karşılarsa "bitti" sayılır.

### 1. Kabuk paylaşılır

| Yüzey | Kabuk |
|---|---|
| Kök sekme | `V3TopBar` — bağlam etiketi + kaydırınca beliren başlık + `topBarProgress` |
| Alt ekran | `SubScreen` (chevron ile geri) |
| Modal | `V3SheetScreen` (dairesel `xmark` ile kapat) |
| Tam kanamalı / foto üstü | `V3TopBar` + `V3TopBarIconButton(ground: .media)` |

Sistem `navigationTitle` / `navigationBarTitleDisplayMode` / `ToolbarItem`
**kullanılmaz.** `NavigationStack` yalnız **yığın** için serbest (sekme içi
push); başlık çubuğunu her seviyede yukarıdaki kabuklar çizer. Sheet içinde
push gerekiyorsa `V3SheetStack` — `.toolbar(.hidden)` zaten içinde.

Sheet sunumu **içerik ekranının kararıdır**, çağrı yerinin değil: yüksekliği
ekran bilir. `.v3Sheet(detents:)` içerik view'ının gövdesine yazılır. Çağrı
yerinde de yazılırsa dıştaki kazanır ve ekranın kendi kararını sessizce ezer.

### 2. Kenar hattı tek sayıdır

Gövdenin yatay payı `oneScreenBody()` (= `V3Tokens.channel`, 24pt). Elle
`.padding(.horizontal, 24)` bile yazma — token'ı okumayan bir sayı, sonraki
kişi için ölçek dışı bir sayıdır.

Üst çubuk satırları `V3Tokens.barInset` kullanır (`channel - 4`): dairesel
düğmeler 44pt dokunma hedefi içinde 36pt çiziliyor, bu pay o 4pt'yi geri
verip glifin görünen kenarını kanal hattına oturtuyor.

Kart **içi** paylar boşluk ölçeğinden: `spacingXS/SM/MD/LG/XL/XL2/XL3/XL4/XL5`.

### 3. Tipografi rol adıyla çağrılır

`displayLG()`, `onePageTitle()`, `bodyMD()`, `bodySM()`, `monoLabel()`,
`oneEyebrow()` — rol adı, punto değil.

- `.font(.system(size:))` **yalnız** `Image(systemName:)` ikonlarında serbest.
  Metinde geçmez.
- Ham `V3Typography.sans(13.5)` geçmez; rol karşılığı yoksa önce
  `ONETypography`'ye rol olarak eklenir.
- **İstisna — dışa aktarılan yüzeyler:** poster, story kartı, davet kartı,
  widget, Live Activity. Oralar sabit piksel tuvale çiziliyor ve dışarı
  gidiyor; Dynamic Type orada erişilebilirlik değil bozulma. Kullan:
  `displayFixed` / `sansFixed` / `monoFixed` / `handFixed` ve
  `V3Tokens.Export` paleti (adaptive token değil — yoksa koyu temadaki
  kullanıcı koyu poster paylaşır).

### 4. Kart tek yerden gelir

`.oneCardBackground(radius:)` (`View+ONE.swift`). Elle `RoundedRectangle`
zemini + `strokeBorder` yazma. Yarıçap `V3Tokens.radius*` ölçeğinden:
`radiusChip 8 · radiusCard 16 · radiusPanel 20 · radiusTile 24 · radiusHero 32
· radiusCanvas 52 · radiusCapsule`. Mozaik için `radiusMosaic` / `radiusMicro`.

### 5. Dokunulabilir her şey geri bildirir

- Buton stili: `.buttonStyle(.onePressable)`. `.plain` **yok** — dokunma
  geri bildirimini tamamen kaldırıyor.
- Birincil eylem: `V3PrimaryButton`. İkincil: `V3OutlineButton`. Elle kapsül
  çizme.
- Her `Button` label'ında `.contentShape(Rectangle())` — dolgu yoksa boşluk
  ölü kalır, kullanıcı "bastım olmadı" der.
- Dokunma hedefi ≥ `V3Tokens.minTouchTarget` (44pt), sekmeler 56pt.

### 6. Üç durum tanımlıdır

Yükleniyor (skeleton), boş, hata. Üçü yazılmadan ekran bitmez.

Boş durum **ne yapılacağını** yazar, ne yapılamayacağını değil:
"Bir renk seç" ✓ / "Henüz seçmedin" ✗.

### 7. Renk üstündeki metin ink eşidir

Renk zemin üstünde `V3Mood.ink`. `.white` / `.black` **yok** — kullanıcının
seçtiği rastgele hex'in üstünde kontrast garantisi kalmaz.

Erişilebilirlik zorunluları: WCAG AA (gövde 4.5:1, büyük metin 3:1);
Reduce Motion → hareket kapanır, yalnız opacity kalır; Reduce Transparency →
cam yüzey düz `surface`'e düşer; Dynamic Type en büyük kademede taşma yok.

### 8. Metin çevrilebilir ve etiketlidir

- Kullanıcıya görünen her dize `NSLocalizedString`. Dokuz dil paketli:
  `de · en · es · fr · ja · ko · ru · tr · zh-Hans`. Yeni anahtar **dokuzuna
  birden** yazılır, yoksa o kullanıcı Türkçe görür.
- İkon düğmesinin `accessibilityLabel`'ı var; dekoratif öğe
  `accessibilityHidden(true)`.
- Renk tek başına anlam taşımaz — rozet/nokta gibi işaretler VoiceOver'da da
  bir karşılık taşır.

---

## Kopya kuralları

- **Emoji yok.** Duygu sinyali renk noktasıdır.
- Slogan/manifesto yok. Gizlilik vaazı yok.
- Ekran başlıkları işlevi söyler ("Hatırlatma"), duruş beyan etmez.
- Cümleler 5–12 kelime, sen dili.
- Açıklama metni yalnız o an gerekli işlevsel bilgiyi verir; yoksa hiç yazma.
- Ürün adı **Çevre**. "Frekans" reddedildi — kod prefiksleri
  (`PrimaryTab.circle`, `Features/Circle/`) `@SceneStorage` kontratı olduğu
  için değişmedi, yalnız kullanıcıya görünen metin.

## Yapılmayacaklar

- Seri (streak) sayacı, rozet, "N gün üst üste".
- Sonsuz akış, keşfet feed'i.
- Not özetleme / duygu tahmini — "sen seç" ilkesine ters.
- Sahte kontrol: hiçbir yerin okumadığı toggle. Bir kontrol varsa bir şey
  yapmalı.
- Yeni SPM dependency — eklemeden önce flag et.

---

## Derleme

Xcode `/Applications`'da **değil**; `~/Downloads/Xcode-beta.app` içinde.
`xcodebuild` doğrudan çalışmaz, `DEVELOPER_DIR` ile çağrılır. Tip denetimi:

```bash
X=~/Downloads/Xcode-beta.app/Contents/Developer
SDK="$X/Platforms/iPhoneSimulator.platform/Developer/SDKs/iPhoneSimulator.sdk"
CD=~/Library/Developer/Xcode/DerivedData/ones-elbxchtrhaemvrhhazqsxusbrttc/Build/Intermediates.noindex/ones.build/Debug-iphoneos/one.build/DerivedSources/CoreDataGenerated/one
"$X/Toolchains/XcodeDefault.xctoolchain/usr/bin/swiftc" -typecheck \
  -sdk "$SDK" -target arm64-apple-ios17.0-simulator \
  -swift-version 5 -module-name OneDailyBatuhan \
  -enable-upcoming-feature MemberImportVisibility -default-isolation MainActor \
  $(find one -name '*.swift') "$CD"/*.swift OneActivityExtension/ActivityAttributes.swift
```

`-default-isolation MainActor` şart (yoksa sahte actor hataları). Core Data
sınıfları derleme anında üretildiği için `DerivedSources`'takiler de şart.
Süre ~2 dk.

`swiftc -parse` yalnız **sözdizimi** bakar — eksik bir modifier'ı ya da
yanlış tipi yakalamaz. Doğrulama için yukarıdaki `-typecheck` kullanılır.

Birden fazla oturum aynı anda yazıyorsa derleme "input file was modified
during the build" ile düşer. Çare: ağacı bir scratch dizinine kopyalayıp
kopyayı denetlemek.
