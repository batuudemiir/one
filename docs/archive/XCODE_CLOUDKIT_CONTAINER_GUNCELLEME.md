# 🔧 Xcode'da CloudKit Container Güncelleme Rehberi

## ✅ Tamamlanan Adımlar

Kod dosyalarında container ID'ler güncellendi:

1. ✅ **Persistence.swift** → `iCloud.com.batu.ones`
2. ✅ **CloudKitManager.swift** → `iCloud.com.batu.ones`

---

## 📱 Şimdi Xcode'da Yapılacaklar

### Adım 1: Xcode'da Projeyi Aç

1. Xcode'u aç
2. `one/One - Günlük Mood.xcodeproj` dosyasını aç

---

### Adım 2: Target Ayarlarına Git

1. Sol taraftaki **Project Navigator**'da en üstteki **proje ikonuna** tıkla (mavi ikon)
2. **TARGETS** bölümünde **one** seç
3. Üstteki sekmelerden **Signing & Capabilities** seç

---

### Adım 3: iCloud Capability'sini Bul

**Signing & Capabilities** sekmesinde **iCloud** bölümünü bulun.

Şöyle görünmelidir:
```
☑ iCloud
  ☑ CloudKit
  Containers:
    ☐ iCloud.com.batu.one (eski)
```

---

### Adım 4: Yeni Container Ekle

#### Seçenek A: Otomatik (Önerilen)

1. **Containers** bölümünde **+** (Add) butonuna tıkla
2. Açılan menüden **"Specify Custom Containers..."** seç
3. Açılan pencerede **+** butonuna tıkla
4. **Container Name** gir: `iCloud.com.batu.ones`
5. **OK** tıkla

#### Seçenek B: Manuel

Eğer container zaten listede görünüyorsa:
1. **iCloud.com.batu.ones** yanındaki checkbox'ı işaretle
2. **iCloud.com.batu.one** yanındaki checkbox'ı kaldır (eski container)

---

### Adım 5: Default Container Seç

1. **iCloud.com.batu.ones** yanındaki **radio button**'a tıkla (varsayılan yap)
2. Veya sağ tıklayıp **"Use as Default Container"** seç

Şöyle görünmeli:
```
☑ iCloud
  ☑ CloudKit
  Containers:
    ☑ iCloud.com.batu.ones (Default) ← Yeni
    ☐ iCloud.com.batu.one ← Eski (kaldırabilirsiniz)
```

---

### Adım 6: Eski Container'ı Kaldır (Opsiyonel)

Eğer eski container'da önemli data yoksa:

1. **iCloud.com.batu.one** yanındaki checkbox'ı kaldır
2. Veya **-** (Remove) butonuna tıkla

⚠️ **Dikkat:** Eski container'da data varsa, önce migration yapın!

---

### Adım 7: Entitlements Dosyasını Kontrol

Xcode otomatik olarak `one.entitlements` dosyasını günceller.

Kontrol etmek için:

1. **Project Navigator**'da `one.entitlements` dosyasını bul
2. Dosyayı aç
3. Şöyle görünmeli:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.developer.icloud-container-identifiers</key>
    <array>
        <string>iCloud.com.batu.ones</string>
    </array>
    <key>com.apple.developer.icloud-services</key>
    <array>
        <string>CloudKit</string>
    </array>
    <key>com.apple.developer.ubiquity-container-identifiers</key>
    <array>
        <string>iCloud.com.batu.ones</string>
    </array>
</dict>
</plist>
```

Eğer eski container hala varsa, manuel olarak silin.

---

### Adım 8: Clean Build Folder

1. Xcode menüsünden **Product** → **Clean Build Folder** (⇧⌘K)
2. Veya **Product** → **Clean Build Folder** (Shift + Command + K)

Bu, eski cache'leri temizler.

---

### Adım 9: Provisioning Profile Güncelle

1. **Signing & Capabilities** sekmesinde
2. **Automatically manage signing** işaretli olmalı
3. Eğer değilse, işaretleyin
4. Xcode otomatik olarak yeni provisioning profile oluşturacak

Veya manuel:
1. **Provisioning Profile** dropdown'ından **Download Profile** seç
2. Yeni profile'ı seç

---

### Adım 10: Build ve Test

1. Simulator veya gerçek cihaz seç
2. **Product** → **Build** (⌘B)
3. Build başarılı olmalı

Eğer hata alırsanız:
- **Product** → **Clean Build Folder** (⇧⌘K)
- Xcode'u kapatıp tekrar açın
- **Derived Data** klasörünü silin:
  - Xcode → **Settings** → **Locations** → **Derived Data** → **Arrow** tıkla → Klasörü sil

---

## 🧪 Test Etme

### Test 1: CloudKit Bağlantısı

1. Uygulamayı çalıştır
2. Xcode Console'da şu mesajı arayın:
   ```
   CloudKit: Account available
   ```

Eğer hata görürseniz:
```
CloudKit Error: Account not available
```

**Çözüm:**
- Simulator'da: **Settings** → **Apple ID** → Giriş yap
- Gerçek cihazda: **Ayarlar** → **iCloud** → iCloud Drive açık olmalı

### Test 2: Container Doğrulama

Console'da container ID'yi kontrol edin:
```swift
print("Container: \(container.containerIdentifier ?? "unknown")")
```

Çıktı:
```
Container: iCloud.com.batu.ones
```

### Test 3: Çevre Özelliği

1. Uygulamada **Çevre** sekmesine git
2. **Arkadaş Ekle** butonuna tıkla
3. Davet kodu üretilmeli (örn: ABC123)

Eğer hata alırsanız:
- CloudKit Dashboard'da schema oluşturuldu mu?
- Container ID doğru mu?

---

## 🔍 Sorun Giderme

### "Container not found" Hatası

**Çözüm:**
1. [CloudKit Dashboard](https://icloud.developer.apple.com/dashboard) aç
2. **iCloud.com.batu.ones** container'ı var mı kontrol et
3. Yoksa, **Add Container** (+) ile oluştur

### "No matching provisioning profiles found"

**Çözüm:**
1. Xcode → **Settings** → **Accounts**
2. Apple ID'nizi seç
3. **Download Manual Profiles** tıkla
4. Veya **Automatically manage signing** işaretle

### "Entitlements file not found"

**Çözüm:**
1. **Project Navigator**'da `one.entitlements` dosyasını bul
2. Yoksa, Xcode otomatik oluşturur
3. **Signing & Capabilities** → **iCloud** → Container seç
4. Xcode otomatik olarak entitlements dosyasını oluşturur

### Build Başarılı Ama CloudKit Çalışmıyor

**Çözüm:**
1. **Product** → **Clean Build Folder** (⇧⌘K)
2. Uygulamayı sil (Simulator/Cihazdan)
3. Tekrar build et ve çalıştır
4. iCloud hesabına giriş yaptığınızdan emin olun

---

## 📋 Checklist

Tamamlandığında:

- [ ] Xcode'da **Signing & Capabilities** → **iCloud** → **iCloud.com.batu.ones** seçili
- [ ] **iCloud.com.batu.ones** default container olarak işaretli
- [ ] `one.entitlements` dosyasında **iCloud.com.batu.ones** var
- [ ] Eski container (**iCloud.com.batu.one**) kaldırıldı veya işareti kaldırıldı
- [ ] **Clean Build Folder** yapıldı
- [ ] Build başarılı
- [ ] Uygulama çalışıyor
- [ ] CloudKit bağlantısı çalışıyor (Console'da kontrol)
- [ ] Çevre özelliği çalışıyor (Davet kodu üretiliyor)

---

## 🎯 Sonraki Adım

Xcode ayarları tamamlandıktan sonra:

👉 [CloudKit Dashboard'da Schema Oluşturma](./CLOUDKIT_DASHBOARD_SETUP_NEW.md)

CloudKit Dashboard'da yeni container için schema oluşturmanız gerekiyor:
- Users record type
- Friendship record type
- DailyShare record type
- Indexler

---

## 💡 İpuçları

1. **Development vs Production:**
   - İlk önce Development environment'ta test edin
   - Her şey çalıştıktan sonra Production'a deploy edin

2. **Multiple Containers:**
   - Hem eski hem yeni container'ı seçili bırakabilirsiniz
   - Kod hangi container'ı kullanacağını belirler
   - Ama karışıklık olmaması için sadece yeni container'ı kullanın

3. **Data Migration:**
   - Eski container'da data varsa, migration script yazın
   - Veya kullanıcılara yeni baştan giriş yaptırın

4. **Testing:**
   - İki farklı cihazda test edin
   - Sync çalışıyor mu kontrol edin
   - Arkadaş ekleme çalışıyor mu test edin

---

**Son Güncelleme:** 2025-02-27  
**Durum:** ✅ Kod güncellemeleri tamamlandı, Xcode ayarları bekleniyor
