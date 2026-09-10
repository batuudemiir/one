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

## Duruş

**ONE seni anlamaya çalışmaz. Kaydı tutar.** Kategori mood tracker değil,
**renk günlüğü**. Aşağıdaki dördü pazarlama cümlesi değil, kod kararıdır —
bir PR bunlardan birini çiğniyorsa reddedilir.

1. **Analiz değil, gösterim.** Yankı ve portreler düzenler, yorumlamaz.
   İzin verilen: "21 girişte 3 kez pazartesi Yorgun." Yasak: tavsiye,
   teşhis, skor, sıralama, ortalamanın altı/üstü dili, duygu çıkarımı,
   not özetleme.
2. **Ölçme yok.** Hedef, ilerleme çubuğu, "iyi hafta / kötü hafta", seri,
   rozet, seviye, kilitli-açık ödül yok. Renk dağılımı bir istatistik
   değil, bir palet.
3. **Boşluk kalıcıdır.** Girilmemiş gün bir eksik değil, bir veri — ve
   **sonradan doldurulamaz.** Geriye dönük giriş yok: `V3DayDetailView`
   CTA'yı yalnız `isToday` iken render eder. Bu bir eksiklik değil, bir
   karar: arşiv doğru olduğu için değerli, tamamlandığı için değil.
   "Kaçırdın", "doldur", "telafi et", "freeze" dili yok. Pas geçildi
   (`#9E9E9E`) sistemin parçası.
4. **Arşivin sahibi kullanıcıdır.** Dışa aktarma birinci sınıf bir
   özellik, gizli bir ayar değil.

Kaynak: `~/Desktop/one/ONE_v4_Marka_Platformu.md`

---

## Sekiz madde

Bir ekran ancak sekizini de karşılarsa "bitti" sayılır.

### 1. Kabuk paylaşılır

| Yüzey | Kabuk |
|---|---|
| Kök sekme | `V3TopBar(style: .root)` — `PrimaryTab.screenTitle` + eylem + `topBarProgress` |
| Alt ekran | `SubScreen` (chevron ile geri) |
| Modal | `V3SheetScreen` (dairesel `xmark` ile kapat) |
| Tam kanamalı / foto üstü | `V3TopBar` + `V3TopBarIconButton(ground: .media)` |

Üst çubukta **marka işareti yoktur.** O yuva ekranın adına ait: kök sekmede
`style: .root` başlığı (Archivo 20, her zaman görünür), alt ekranda geri/kapat
düğmesi + 17pt sans başlık. Yanındaki `context` mono etiketi bağlamı söyler
(tarih, ay). Her kökün sağında **o ekrana ait tek bir eylem** durur —
An: hatırlatma · Arşiv: Yankı · Çevre: istekler + bildirimler · Profil: ayarlar.

**Çıkış her zaman SOL yuvada.** Geri de kapat da orada — `V3TopBarLeading`
başka yer sunmuyor. Foto/vizör üstünde `leadingGround: .media` geçilir; bir
dönem beş ekran kapat düğmesini sağa kaçırmıştı ve tek sebebi bu parametrenin
olmamasıydı. Sağ yuva **eylem** yuvası, çıkış değil.

**Hiçbir ekran kendi çubuğunu çizmez.** `HStack { başlık; Spacer(); kapat }`
yazma — beş ekran öyle yazılmıştı ve beş ayrı başlık puntosu (10 mono / 16 /
22 / 24 / ortalanmış mono) ortaya çıkmıştı. Ekranın çubuğu tek satırlık bir
`V3TopBar` çağrısıdır; başlığın altına açıklama gerekiyorsa o **gövdenin**
işidir.

Ekran adları `screen.*` anahtarlarında ve **cümle düzenindedir**. `nav.*`
anahtarları alt gezinme dilidir (küçük harf) ve çubukta kullanılmaz;
`share.title` gibi all-caps ölçülmüş göz-kaşı dizeleri de kullanılmaz.

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

Ses: **az konuşan kurator** (marka sesi v4). Nadiren konuşur; konuştuğunda bir
olguyu bildirir, yorumu kullanıcıya bırakır. Denetleyici:
`tooling/voice_guard.py` — eşiksiz, font denetimi gibi ikili.

- **Emoji yok.** Duygu sinyali renk noktasıdır. Durum işareti (✓) muaf.
- **Ünlem yok.** Ünlem yalvarmadır.
- **Soru işareti yalnız kullanıcının başlattığı akışta** ("Şu an nasılsın?",
  onay diyalogları). Bildirimde asla — bildirimde soru bir taleptir.
- **Uygulama bir şey istemez, bir olguyu bildirir.** Emir kipi yalnız buton
  etiketinde (kullanıcının başlattığı akış).
- **Duyguyu kullanıcı adlandırır.** "Yoğunsun", "zor bir hafta", "kendine
  zaman tanı" izinsiz teşhistir. Kod da okumaz: son N girişe bakıp metin
  yumuşatan dal yok.
- **Süre vaadi yok** ("10 saniye", "tek dokunuş"). Ürün kendini pazarlıkla
  savunmaz.
- **Uygulama kendini özne yapmaz** ("ONE seni bekliyor", "seni özledik").
- **Sosyal bildirimde özne insandır**: başlık kişi, gövde olay —
  "Deniz / Bugünkü rengini bıraktı." (Apple HIG başlık/gövde ayrımı.)
- **Alışkanlık/seri/ivme dili yok.** Sayı bir olgudur: "7 gün" ✓,
  "7 gün üst üste!" ✗.
- **Boşluk bir ifadedir**, hata değil: "Bugün renksiz kaydedilecek."
- Slogan/manifesto yok. Gizlilik vaazı yok. ("Hisset. Keşfet. Paylaş."
  pazarlamada kalır, uygulamada görünmez.)
- Ekran başlıkları işlevi söyler ("Hatırlatma"), duruş beyan etmez.
- Cümleler 5–12 kelime, sen dili. Butonlar cümle düzeni ("Kaydet",
  "Devam et"), mikro etiketler mono + büyük harf, başlıklar cümle düzeni.
  Küçük harfle başlayan başlık yok.
- Açıklama metni yalnız o an gerekli işlevsel bilgiyi verir; yoksa hiç yazma.
- Ürün adı **Çevre**. "Frekans" reddedildi — kod prefiksleri
  (`PrimaryTab.circle`, `Features/Circle/`) `@SceneStorage` kontratı olduğu
  için değişmedi, yalnız kullanıcıya görünen metin.

## Bildirim mimarisi

Eksen: **olay + ritüel.** Uygulama yalnız (a) başka bir insan bir şey
yaptığında, (b) bir portre hazır olduğunda, (c) kullanıcının kendi kurduğu
günlük ritüelde konuşur. Win-back, nurture ve davet dalgası serileri v4'te
tamamen silindi (`WinBackScheduler`, `NewUserNurtureScheduler`).

| Sayı | v3 | v4 |
|---|---|---|
| Bildirim türü | 21 | 9 |
| Uygulamanın kendi başlattığı tür | 11 | 3 |
| Haftalık proaktif bütçe | 5 | 2 |
| Günlük tavan | 2 | 1 |
| Sessiz saatler | 23–08 | 22–09 |

Yorum türleri (`commentReceived/Reply/Mention/Batch`) de düştü: kalıcı yorum
sistemi sökülüp yerine efemer karşılık geldi, gelen karşılık `friendReaction`
ile bildiriliyor.

Her olayın **tek** sahibi var — ikinci bir motor aynı şeyi iki kez duyurur:

| Olay | Tek sahibi |
|---|---|
| Günlük ritüel | `V3ReminderScheduler` (saat/gün/ton kullanıcıdan) |
| Haftalık portre | `SundayReflectionScheduler` (Pazar 11:00) |
| Aylık portre | `MonthlyPortraitScheduler` (ayın 1'i 11:00) |
| Sosyal olaylar | `CloudKitNotificationService` + `MoodResonanceService` |

**Metnin tek kaynağı `NotificationMessageBuilder`.** Çağrı yeri kendi
başlığını/gövdesini yazmaz: `social(_:friendName:…)` ya da
`dailyReminder(tone:…)` çağırır. Push ile uygulama içi bildirim satırı aynı
metni paylaşır — ikisi ayrı yazıldığında ses ikiye ayrılıyordu.

Metin **katalogdan** gelir: `notif.*` anahtarları, dokuz dil. Builder içinde
`L(...)` / `Lf(...)` sarmalayıcıları kullanılır; kelime birleştirme yok, her
dil tam cümleyi kendi dilbilgisiyle kurar (`"Dün " + mood` yalnız Türkçe'de
çalışıyordu). Çok argümanlı anahtarlar konumlu yazılır: `%1$@ ve %2$d kişi`.
Gün ve ay adlarını `LanguageManager.shared.currentLocale` biçimlendirir.

CloudKit abonelik fallback'leri (`notif.push.*`) **CloudKit'te saklanır**:
kayıt anındaki dille donarlar. Metni değiştirirsen
`CloudKitNotificationService.currentSubVersion` sayısını artır, yoksa mevcut
kurulumlar eski metni almaya devam eder.

**Her istek `NotificationOrchestrator.schedule` üzerinden geçer** (sessiz
saatler, tavan, dedup, telemetri, 64 pending limiti). Doğrudan
`center.add(...)` çağıran yeni kod yazma.

Günlük ritüel haftalık proaktif bütçeden düşmez: saatini kullanıcı seçiyor,
bu bir pazarlama push'u değil kullanıcının kendisiyle kurduğu randevu.
Uygulamanın hatırlatma saatini kendi başına kaydırdığı "akıllı bildirim"
katmanı bu yüzden kaldırıldı.

Kaldırılan seriler cihazda **kurulu kalmış olabilir** — kod silmek pending
isteği silmez. `NotificationOrchestrator.purgeRetiredSchedules` her boot'ta
eski kimlikleri temizler; yeni bir tür kaldırırken kimliğini o listeye ekle.

## Yapılmayacaklar

- Seri (streak) sayacı, rozet, "N gün üst üste".
- Kilometre taşı / kilitli–açık ödül sistemi. "Beklenti de bir ödül"
  gerekçesi geçersiz: kilitli bir şey göstermek de bir ölçüm vaadidir.
- Haftalık ya da günlük hedef. Girmeyi bir kotaya bağlama.
- **Geriye dönük giriş.** Geçmiş bir güne kayıt eklenemez; bu davranışı
  gevşeten PR reddedilir.
- Seri dondurma (freeze), telafi hakkı, "kaçırdığın günü doldur" dili.
- Sıralama ve üstünlük dili: "en aktif", "en çok", "rekor".
- Sonsuz akış, keşfet feed'i.
- Not özetleme / duygu tahmini — "sen seç" ilkesine ters.
- Sahte kontrol: hiçbir yerin okumadığı toggle. Bir kontrol varsa bir şey
  yapmalı.
- Yeni SPM dependency — eklemeden önce flag et.

---

## Derleme

`xcode-select` CommandLineTools'u gösteriyor, yani `xcodebuild` doğrudan
çalışmaz — tam toolchain Xcode-beta'nın içinde. **Yolu sabit sayma**, taşınıyor
(2026-09-08'de `~/Downloads`'tan `/Applications`'a geçti); önce `ls -d
/Applications/Xcode*.app ~/Downloads/Xcode*.app` ile bak. Tip denetimi:

```bash
X=/Applications/Xcode-beta.app/Contents/Developer
SDK="$X/Platforms/iPhoneSimulator.platform/Developer/SDKs/iPhoneSimulator.sdk"
CD=$(mktemp -d)
"$X/usr/bin/momc" --sdkroot "$SDK" --module one --swift-version 5.0 \
  --action generate --swift-output-dir "$CD/src" \
  one/one.xcdatamodeld/one.xcdatamodel "$CD"
"$X/Toolchains/XcodeDefault.xctoolchain/usr/bin/swiftc" -typecheck \
  -sdk "$SDK" -target arm64-apple-ios17.0-simulator \
  -swift-version 5 -module-name OneDailyBatuhan \
  -enable-upcoming-feature MemberImportVisibility -default-isolation MainActor \
  $(find one -name '*.swift') "$CD"/*.swift OneActivityExtension/ActivityAttributes.swift
```

`-default-isolation MainActor` şart (yoksa sahte actor hataları). Core Data'nın
`DailySong` sınıfları kaynak ağacında yok, derleme anında üretiliyor — yukarıda
`momc` ile üretiliyorlar. (DerivedData'daki kopya da işe yarar ama Xcode
temizliğinde ya da disk baskısında siliniyor.) Süre ~5 dk.

Birden çok oturum aynı ağaca yazarken swiftc "input file was modified during
the build" ile düşer — önce `rsync -a one <scratch>/` ile kopyala, denetimi
kopyada koştur.

`swiftc -parse` yalnız **sözdizimi** bakar — eksik bir modifier'ı ya da
yanlış tipi yakalamaz. Doğrulama için yukarıdaki `-typecheck` kullanılır.

Birden fazla oturum aynı anda yazıyorsa derleme "input file was modified
during the build" ile düşer. Çare: ağacı bir scratch dizinine kopyalayıp
kopyayı denetlemek.
