# Instagram Paylaşım Sorun Giderme

## Mevcut Durum

ShareManager doğru implement edilmiş:
- ✅ UIActivityViewController kullanılıyor
- ✅ Image optimization yapılıyor (max 1080x1920)
- ✅ Info.plist'te URL schemes var

## Olası Sorunlar ve Çözümler

### 1. Instagram Yüklü Değil
**Belirti**: Paylaş menüsünde Instagram görünmüyor

**Çözüm**: Cihazda Instagram yüklü olmalı
```swift
ShareManager.shared.isInstagramInstalled() // kontrol et
```

### 2. URL Scheme Sorunu
**Kontrol Et**: Info.plist > LSApplicationQueriesSchemes
```xml
<key>LSApplicationQueriesSchemes</key>
<array>
    <string>instagram</string>
    <string>instagram-stories</string>
</array>
```

### 3. Image Format Sorunu
**Sorun**: Instagram bazı image formatlarını kabul etmiyor

**Çözüm**: PNG veya JPEG olmalı, optimize edilmeli
```swift
// ShareManager zaten optimize ediyor
let optimizedImage = ... // max 1920px
```

### 4. UIActivityViewController Görünmüyor
**Sorun**: Present edilmiyor veya hemen kapanıyor

**Kontrol Et**:
- ViewController doğru mu?
- Main thread'de mi çalışıyor?
- iPad için popover ayarları yapılmış mı?

### 5. Instagram Stories API Kullanımı
**Not**: Şu anda UIActivityViewController kullanıyoruz (genel paylaşım)

**Alternatif**: Instagram Stories API'sini direkt kullan
```swift
// Instagram Stories'e direkt paylaşım
let urlScheme = "instagram-stories://share"
// Background image + sticker layer
```

## Debug Adımları

### 1. Console Log Kontrol
```
✅ Share successful - Başarılı
❌ Share error: ... - Hata detayı
ℹ️ Share cancelled - Kullanıcı iptal etti
```

### 2. Instagram Yüklü mü?
```swift
if ShareManager.shared.isInstagramInstalled() {
    print("✅ Instagram yüklü")
} else {
    print("❌ Instagram yüklü değil")
}
```

### 3. Image Boyutu Kontrol
```swift
print("Image size: \(image.size)")
// Optimal: 1080x1920 (9:16 aspect ratio)
```

### 4. ViewController Kontrol
```swift
guard let root = UIApplication.shared.windows.first?.rootViewController else {
    print("❌ Root ViewController bulunamadı")
    return
}
```

## Önerilen İyileştirmeler

### 1. Instagram Stories API Kullan
Daha iyi entegrasyon için direkt Instagram Stories API:

```swift
func shareToInstagramStories(backgroundImage: UIImage, stickerImage: UIImage?) {
    guard let urlScheme = URL(string: "instagram-stories://share") else {
        return
    }
    
    guard UIApplication.shared.canOpenURL(urlScheme) else {
        // Instagram yüklü değil
        return
    }
    
    // Background image
    guard let imageData = backgroundImage.pngData() else { return }
    let pasteboardItems: [[String: Any]] = [
        [
            "com.instagram.sharedSticker.backgroundImage": imageData
        ]
    ]
    
    let pasteboardOptions = [
        UIPasteboard.OptionsKey.expirationDate: Date().addingTimeInterval(60 * 5)
    ]
    
    UIPasteboard.general.setItems(pasteboardItems, options: pasteboardOptions)
    UIApplication.shared.open(urlScheme)
}
```

### 2. Hata Mesajları İyileştir
Kullanıcıya daha açık feedback:

```swift
if !ShareManager.shared.isInstagramInstalled() {
    // Alert göster: "Instagram yüklü değil"
}
```

### 3. Loading State
Paylaşım sırasında loading göster:
```swift
@State private var isSharing = false

if isSharing {
    ProgressView()
}
```

## Test Senaryoları

### Senaryo 1: Instagram Yüklü
1. Paylaş butonuna tıkla
2. UIActivityViewController açılmalı
3. Instagram seçeneği görünmeli
4. Instagram'a tıkla
5. Instagram açılmalı ve story oluşturma ekranı gelmeli

### Senaryo 2: Instagram Yüklü Değil
1. Paylaş butonuna tıkla
2. UIActivityViewController açılmalı
3. Instagram seçeneği görünmemeli
4. Diğer paylaşım seçenekleri çalışmalı (Mesajlar, Mail, vb.)

### Senaryo 3: Kullanıcı İptal Eder
1. Paylaş butonuna tıkla
2. UIActivityViewController açılmalı
3. İptal'e tıkla
4. Sheet kapanmalı, hata göstermemeli

## Şu Anki Sorun Nedir?

Lütfen şunları kontrol et:
1. Console'da ne hatası var?
2. Instagram yüklü mü?
3. Paylaş menüsü açılıyor mu?
4. Instagram seçeneği görünüyor mu?
5. Instagram'a tıklayınca ne oluyor?

Bu bilgilere göre spesifik çözüm önerebilirim.
