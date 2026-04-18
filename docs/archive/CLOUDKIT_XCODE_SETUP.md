# 🔧 CloudKit Xcode Kurulum Rehberi (Görsel Adımlar)

## Adım 1: iCloud Capability Ekleme

### 1.1 Signing & Capabilities Sekmesi

1. Xcode'da projeyi aç
2. Sol panelden **one** projesini seç
3. **TARGETS** altından **one** target'ını seç
4. Üstteki sekmelerden **Signing & Capabilities** seç

### 1.2 iCloud Capability Ekle

1. **+ Capability** butonuna tıkla (sol üstte)
2. Açılan listeden **iCloud** seç
3. iCloud capability otomatik eklenecek

### 1.3 CloudKit'i Aktifleştir

iCloud capability eklendikten sonra:

1. **Services** bölümünde şu seçenekleri işaretle:
   - ✅ **CloudKit**
   - ⬜ Key-value storage (isteğe bağlı)
   - ⬜ iCloud Documents (gerekli değil)

## Adım 2: CloudKit Container Oluşturma

### 2.1 Container Ekleme

1. **Containers** bölümünde **+** butonuna tıkla
2. Bir dialog açılacak: "Add a new container"
3. Dialog şunu söyler:
   ```
   Xcode will create a new container if the named container
   doesn't already exist, add it to your App ID, and add the new
   container to your app's entitlements.
   ```

### 2.2 Container İsmi

Dialog'da **OK** butonuna tıkladığınızda:

**Otomatik oluşturulacak container:**
```
iCloud.com.batu.one
```

Bu, Bundle Identifier'ınıza göre otomatik oluşturulur:
- Bundle ID: `com.batu.one`
- Container: `iCloud.com.batu.one`

### 2.3 Onaylama

1. **OK** butonuna tıkla
2. Xcode otomatik olarak:
   - Container'ı oluşturur
   - App ID'ye ekler
   - Entitlements dosyasını günceller
   - CloudKit Dashboard'da container oluşturur

## Adım 3: Container Doğrulama

### 3.1 Containers Listesi

iCloud capability altında şimdi göreceksiniz:

```
Containers:
  ✅ iCloud.com.batu.one
```

### 3.2 Entitlements Dosyası Kontrolü

Xcode otomatik olarak `one.entitlements` dosyası oluşturur:

**Dosya konumu:** `one/one.entitlements`

**İçeriği:**
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.developer.icloud-container-identifiers</key>
    <array>
        <string>iCloud.com.batu.one</string>
    </array>
    <key>com.apple.developer.icloud-services</key>
    <array>
        <string>CloudKit</string>
    </array>
</dict>
</plist>
```

## Adım 4: Background Modes (Opsiyonel ama Önerilen)

### 4.1 Background Modes Ekleme

1. **+ Capability** butonuna tekrar tıkla
2. **Background Modes** seç

### 4.2 Modes Seçimi

Background Modes capability'de şunları işaretle:

- ✅ **Remote notifications** (CloudKit değişiklikleri için)
- ⬜ Background fetch (isteğe bağlı)

## Adım 5: CloudKit Dashboard Kontrolü

### 5.1 Dashboard'a Giriş

1. Tarayıcıda aç: https://icloud.developer.apple.com/dashboard
2. Apple Developer hesabınla giriş yap
3. Container'ınızı göreceksiniz: **iCloud.com.batu.one**

### 5.2 İlk Kez Açılış

Container ilk kez oluşturulduğunda:
- Development environment otomatik aktif
- Production environment boş
- Schema henüz yok

## Adım 6: CloudKitManager.swift'te Container ID Güncelleme

### 6.1 Dosyayı Aç

`one/one/CloudKitManager.swift` dosyasını aç

### 6.2 Container ID'yi Güncelle

**Değiştir:**
```swift
container = CKContainer(identifier: "iCloud.com.yourcompany.one")
```

**Şununla:**
```swift
container = CKContainer(identifier: "iCloud.com.batu.one")
```

### 6.3 Persistence.swift'te de Güncelle

`one/one/Persistence.swift` dosyasında:

**Değiştir:**
```swift
description.cloudKitContainerOptions = NSPersistentCloudKitContainerOptions(
    containerIdentifier: "iCloud.com.yourcompany.one"
)
```

**Şununla:**
```swift
description.cloudKitContainerOptions = NSPersistentCloudKitContainerOptions(
    containerIdentifier: "iCloud.com.batu.one"
)
```

## Adım 7: İlk Test

### 7.1 Build ve Run

1. Simulator seç (iPhone 15 Pro önerilir)
2. **⌘R** ile çalıştır
3. Uygulama başarıyla build olmalı

### 7.2 iCloud Kontrolü

Simulator'da:
1. **Settings** → **iCloud** aç
2. Bir Apple ID ile giriş yap
3. **iCloud Drive** açık olmalı

### 7.3 Uygulama Testi

1. ONE uygulamasını aç
2. **Çevre** sekmesine git
3. Eğer iCloud açıksa: "Henüz çevren yok" göreceksin
4. Eğer iCloud kapalıysa: "iCloud erişimi gerekli" göreceksin

## Sorun Giderme

### "No such container" Hatası

**Çözüm:**
1. Xcode'u kapat
2. `~/Library/Developer/Xcode/DerivedData` klasörünü temizle
3. Xcode'u tekrar aç
4. Clean Build Folder (⌘⇧K)
5. Rebuild (⌘B)

### Container Görünmüyor

**Çözüm:**
1. Signing & Capabilities'e git
2. iCloud capability'yi kaldır (- butonu)
3. Tekrar ekle (+ Capability → iCloud)
4. CloudKit'i işaretle
5. Container'ı tekrar ekle

### "Account not available" Hatası

**Çözüm:**
1. Simulator'da Settings → iCloud
2. Sign Out yap
3. Tekrar Sign In yap
4. iCloud Drive'ı aç
5. Uygulamayı yeniden başlat

### Entitlements Dosyası Yok

**Çözüm:**
1. File → New → File
2. **Property List** seç
3. İsim: `one.entitlements`
4. Yukarıdaki XML içeriğini yapıştır
5. Target Membership: one (✅)

## Özet Checklist

Kurulum tamamlandığında şunlar olmalı:

- [x] iCloud capability eklendi
- [x] CloudKit işaretlendi
- [x] Container oluşturuldu: `iCloud.com.batu.one`
- [x] Entitlements dosyası var
- [x] Background Modes eklendi (opsiyonel)
- [x] CloudKitManager.swift güncellendi
- [x] Persistence.swift güncellendi
- [x] Build başarılı
- [x] CloudKit Dashboard'da container görünüyor

## Sonraki Adım

Artık CloudKit Dashboard'da schema oluşturmaya hazırsınız!

👉 [CLOUDKIT_DASHBOARD_SETUP.md](./CLOUDKIT_DASHBOARD_SETUP.md) - Schema oluşturma rehberi
