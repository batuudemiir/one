# Instagram Story Cards - Setup Guide

## Gerekli Adımlar

### 1. Font Dosyalarını Ekle

Fraunces font family'yi projeye eklemeniz gerekiyor:

#### Adım 1: Font Dosyalarını İndir
- [Google Fonts - Fraunces](https://fonts.google.com/specimen/Fraunces) adresinden font'u indir
- Gerekli dosyalar:
  - `Fraunces-Light.ttf`
  - `Fraunces-LightItalic.ttf`
  - `Fraunces-Regular.ttf`

#### Adım 2: Xcode'a Ekle
1. Xcode'da `one` projesini aç
2. Font dosyalarını `one/one/` klasörüne sürükle
3. "Copy items if needed" seçeneğini işaretle
4. Target: "one" seçili olduğundan emin ol

#### Adım 3: Info.plist'e Ekle
Info.plist dosyasına şu satırları ekle:

```xml
<key>UIAppFonts</key>
<array>
    <string>Fraunces-Light.ttf</string>
    <string>Fraunces-LightItalic.ttf</string>
    <string>Fraunces-Regular.ttf</string>
</array>
```

**Not:** Bu adım zaten yapıldı, sadece font dosyalarını eklemeniz yeterli.

### 2. Asset Image'larını Oluştur

#### DefaultCover.png
- **Boyut:** 1080x1080 pixels
- **Format:** PNG
- **İçerik:** Minimalist gradient veya solid color background
- **Renk:** #E8E6E0 (ONE brand neutral color)
- **Konum:** `one/one/Assets.xcassets/DefaultCover.imageset/DefaultCover.png`

**Örnek Oluşturma (macOS Preview veya Photoshop):**
1. 1080x1080 piksel yeni bir image oluştur
2. Gradient fill uygula: #E8E6E0 → #D8D6D0
3. PNG olarak kaydet
4. Xcode'da Assets.xcassets/DefaultCover.imageset/ klasörüne ekle

#### ONE_Watermark.png
- **Boyut:** 240x240 pixels
- **Format:** PNG with transparency
- **İçerik:** "ONE" text veya logo
- **Renk:** White (#FFFFFF)
- **Background:** Transparent
- **Konum:** `one/one/Assets.xcassets/ONE_Watermark.imageset/ONE_Watermark.png`

**Örnek Oluşturma:**
1. 240x240 piksel yeni bir image oluştur (transparent background)
2. "ONE" text ekle (bold, white, centered)
3. PNG olarak kaydet (transparency preserve)
4. Xcode'da Assets.xcassets/ONE_Watermark.imageset/ klasörüne ekle

### 3. Build ve Test

#### Build:
```bash
cd one
xcodebuild -scheme one -sdk iphonesimulator clean build
```

#### Test Adımları:
1. Simulator'da uygulamayı çalıştır
2. Archive ekranını aç
3. Bir günlük kayıt seç (saved song)
4. "Instagram'da Paylaş" butonuna tıkla
5. Kart oluşturulmasını bekle
6. Share sheet'in açıldığını doğrula

### 4. Troubleshooting

#### Font Görünmüyor:
- Info.plist'te font isimleri doğru mu kontrol et
- Font dosyaları target'a eklenmiş mi kontrol et (File Inspector)
- Build Phases → Copy Bundle Resources'da font dosyaları var mı kontrol et

#### Asset Görünmüyor:
- Asset catalog'da image isimleri doğru mu kontrol et
- Image dosyaları gerçekten klasörde var mı kontrol et
- Clean build yap (Cmd+Shift+K)

#### Share Button Çalışmıyor:
- DailySong'un tüm gerekli field'ları var mı kontrol et
- Console'da error log'ları kontrol et
- Breakpoint koyarak debug et

#### Instagram Açılmıyor:
- Info.plist'te URL schemes eklenmiş mi kontrol et
- Instagram uygulaması simulator'da yüklü mü kontrol et
- Gerçek cihazda test et

### 5. Optional: Custom Watermark

Eğer özel bir logo kullanmak istersen:

1. Logo'yu 240x240 piksel PNG olarak hazırla (transparent background)
2. Logo beyaz renkte olmalı (story card'da 5% opacity ile gösterilecek)
3. `ONE_Watermark.png` dosyasını değiştir
4. Clean build yap

### 6. Optional: Custom Default Cover

Eğer özel bir default cover kullanmak istersen:

1. 1080x1080 piksel image hazırla
2. Minimalist ve brand'e uygun olmalı
3. `DefaultCover.png` dosyasını değiştir
4. Clean build yap

## Hızlı Test Komutu

```bash
# Build
cd one && xcodebuild -scheme one -sdk iphonesimulator clean build

# Run on simulator
open -a Simulator
xcrun simctl boot "iPhone 15"
xcrun simctl install booted one/build/Release-iphonesimulator/one.app
xcrun simctl launch booted com.one.app
```

## Checklist

- [ ] Fraunces font dosyaları eklendi
- [ ] Info.plist'te UIAppFonts eklendi
- [ ] DefaultCover.png oluşturuldu ve eklendi
- [ ] ONE_Watermark.png oluşturuldu ve eklendi
- [ ] Build başarılı
- [ ] Archive ekranı açılıyor
- [ ] Share button görünüyor
- [ ] Kart oluşturuluyor
- [ ] Share sheet açılıyor
- [ ] Instagram'a paylaşım çalışıyor
- [ ] Photo library'ye kaydetme çalışıyor

## Sonraki Adımlar

Setup tamamlandıktan sonra:

1. **Manual Testing:** Tüm user flows'u test et
2. **Edge Cases:** Eksik data ile test et
3. **Performance:** Generation time'ı ölç
4. **Visual Polish:** Gradient ve spacing'i ayarla
5. **Property Tests:** Optional testleri ekle

## Destek

Sorun yaşarsan:
1. Console log'larını kontrol et
2. Breakpoint koyarak debug et
3. `INSTAGRAM_STORY_CARDS_IMPLEMENTATION.md` dosyasını oku
4. Design document'ı kontrol et (`.kiro/specs/instagram-story-cards/design.md`)
