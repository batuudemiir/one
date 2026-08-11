# ONE v3 — Logo seti

Marka işaretinin tüm platform ve yüzey varyantları. Bu klasörü olduğu gibi ONE projesine kopyalayabilirsin.

## Kural, tek cümlede

Düz **Kor `#FF3B1F`** kare + kareden **taşan** kemik beyazı `ONE` wordmark. Başka öğe yok: bant yok, sembol yok, gradyan yok.

| Ölçü | Değer |
|---|---|
| Wordmark genişliği | **1.22 × kare kenarı** (taşma kasıtlı) |
| Punto | **0.474 × kenar** |
| Köşe yarıçapı | **0.225 × kenar** (28px→7 · 260px→58) |
| Koruma alanı | 0.25 × kenar |
| Yatay kilit boşluğu | 0.34 × kenar · dikey kilit 0.28 × kenar |
| Tipografi | Archivo Expanded **ExtraBold (800)**, tracking **−0.035em** |
| Renkler | zemin `#FF3B1F` · harf `#FBFAF7` · wordmark metni `#14141A` (koyu zeminde `#FBFAF7`) |
| Minimum boyut | **24 pt** |

Kor bir **zemindir, metin rengi değildir**. Wordmark asla Kor ile yazılmaz (tek istisna: `wordmark/wordmark-kor-*.png`, sadece kemik zeminde 18px üstünde tek renk baskı için).

---

## Klasör haritası

```
logo/
├─ ios/
│  ├─ AppIcon-1024.png              App Store · açık
│  ├─ AppIcon-dark-1024.png         koyu zemin + Kor harf
│  ├─ AppIcon-tinted-1024.png       monokrom, sistem tint uygular
│  └─ square/AppIcon-{1024,180,167,152,120,87,80,76,60,58,40,29,20}.png
│                                   köşesiz kareler — maskeyi iOS uygular
├─ macos/AppIcon-{1024,512,256,128,64,32,16}.png
│                                   squircle, kenardan %19.5 içeride, çevresi saydam
├─ watchos/AppIcon-{1024,216,172,102,92,87,80,55,48,44,40}.png
│                                   daire kırpımlı
├─ web/
│  ├─ icon-{512,384,256,192,180,152,144,128,96,64,48,32,16}.png
│  ├─ apple-touch-icon.png          180×180, köşesiz
│  ├─ icon-180.png                  180×180, köşeli
│  ├─ maskable-512.png              PWA maskable, güvenli alan içinde
│  └─ manifest.webmanifest          hazır PWA manifesti
├─ ui/mark-{88,56,40,34,26,20}.png  ekran başlığı, bildirim, kilit ekranı
├─ wordmark/wordmark-{ink,bone,kor}-{1600,800,400}.png
│                                   saydam zemin, sıkı kırpılmış
├─ lockup/
│  ├─ horizontal-{ink,bone}-{512,256,128}.png     saydam
│  ├─ vertical-{ink,bone}-{512,256,128}.png       saydam
│  └─ horizontal-on-{light,dark,kor}-512.png      zeminli
├─ mono/mark-{black,white}.png      tek renk baskı ve watermark
├─ social/
│  ├─ avatar-square-1024.png · avatar-round-1024.png
│  ├─ og-1200x630.png · og-dark-1200x630.png      Open Graph / link önizleme
│  ├─ appstore-feature-1200x630.png
│  ├─ x-header-1500x500.png
│  ├─ linkedin-1128x191.png
│  └─ youtube-2560x1440.png
├─ splash/
│  ├─ splash-1290x2796.png · splash-dark-1290x2796.png
│  ├─ splash-2732x2732.png
│  └─ mark-{kor,inverse}-512.png
└─ ios-source/
   ├─ ONEBrand.swift                renkler + geometri sabitleri
   └─ ONEAppMark.swift              ONEAppMark / ONELockup / ONEBreathingMark
```

Toplam 94 PNG. Hepsi Archivo Expanded 800'den, `1.22` taşma ve `0.225` yarıçap oranlarıyla üretildi.

## Kullanım

### iOS app icon

`Assets.xcassets` içinde yeni bir **App Icon** seti oluştur ve üç yuvaya `ios/AppIcon-1024.png`, `ios/AppIcon-dark-1024.png`, `ios/AppIcon-tinted-1024.png` dosyalarını bırak (iOS 18 açık/koyu/tinted). Tek 1024×1024 yeterlidir — Xcode diğer boyutları üretir, köşe maskesini iOS uygular. Bu yüzden dosyalar **köşesizdir**; kendin yuvarlatma. `ios/square/` eski hedefler ve dokümantasyon için.

### Arayüzdeki işaret — bitmap değil, kod

`ios-source/` içindeki iki dosyayı projeye ekle:

```swift
ONEAppMark(side: 26)                    // ekran başlığındaki işaret
ONEAppMark(side: 34)                    // bildirim önizlemesi
ONEAppMark(side: 76, inverted: true)    // Kor zemin üzerinde
ONELockup(markSide: 54)                 // yatay kilit (ayarlar, hakkında)
ONEBreathingMark(side: 120)             // açılış ekranı
```

İşaret salt tiptir; her boyutta net kalır ve geometri tek yerde durur. `ui/mark-*.png` yalnızca kod çizimi mümkün olmayan yerler (widget, bildirim eki) için.

### Font

Archivo ExtraBold (wdth 118)'u projeye göm (Google Fonts, OFL):

1. `Archivo_ExtraBold_Expanded.ttf` dosyasını projeye ekle (Copy items if needed).
2. `Info.plist` → `UIAppFonts` dizisine dosya adını yaz.
3. PostScript adı `Archivo_ExtraBold_Expanded` olmalı; `ONEBrand.display(_:)` bu adı arar, bulamazsa `.system(weight: .black)`'e düşer.

Alternatif: SF Pro Display Heavy, tracking −0.035em. Bu durumda `1.22` oranı korunur ama harf genişlikleri değiştiği için `ONEAppMark.fontSize` içindeki `2.572` katsayısını yeniden kalibre et.

### Web

`web/manifest.webmanifest` hazır. HTML'e:

```html
<link rel="icon" href="/logo/web/icon-32.png" sizes="32x32">
<link rel="icon" href="/logo/web/icon-192.png" sizes="192x192">
<link rel="apple-touch-icon" href="/logo/web/apple-touch-icon.png">
<link rel="manifest" href="/logo/web/manifest.webmanifest">
<meta name="theme-color" content="#FF3B1F">
<meta property="og:image" content="/logo/social/og-1200x630.png">
```

---

## Yapma

- Duygu renklerinden biriyle boyama (`#C8F135`, `#FFC300`…). Onlar üründe yaşar, markada değil.
- Gradyan, doku, gölge, parlama ekleme.
- Wordmark'ı kareye sığdırma — taşma okunurluğu sağlıyor.
- Çok renkli bant/tayf kurgusu kullanma (bayrak okuması yaratır).
- Daire veya farklı köşe yarıçapı kullanma (watchOS daire kırpımı hariç).
- Wordmark'ı Kor ile yazma.
- 24 pt'nin altında kullanma.

---

## Yeniden üretim

PNG'ler Archivo ExtraBold (wdth 118)'dan, `1.22` taşma ve `0.225` yarıçap oranlarıyla üretildi. Farklı boyut gerekirse aynı oranlarla yeniden üret; mevcut PNG'yi büyütme.

Görsel katalog ve tek tek indirme: `ONE v3 Logo Paketi.dc.html`.
Tüm marka kuralları: `one-v3-design-system/logo.md`.
