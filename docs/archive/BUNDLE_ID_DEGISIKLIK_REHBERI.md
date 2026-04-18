# 📦 Bundle ID Değişikliği Sonrası Yapılması Gerekenler

## Mevcut Durum

**Eski Bundle ID:** `com.batu.one` (veya başka bir ID)  
**Yeni Bundle ID:** `com.batu.ones`

Bundle ID değişikliği App Connect sorununu çözdü. Şimdi tüm servisleri yeni Bundle ID ile güncellemeliyiz.

---

## 🎯 Yapılması Gerekenler - Özet Checklist

### Apple Developer Portal
- [ ] 1. App ID güncelle/yeniden oluştur
- [ ] 2. Provisioning Profile'ları yeniden oluştur
- [ ] 3. Capabilities'i yeniden yapılandır

### CloudKit
- [ ] 4. CloudKit Container ID'yi güncelle
- [ ] 5. Mevcut record'ları migrate et (opsiyonel)
- [ ] 6. Xcode'da iCloud container'ı güncelle

### MusicKit / Apple Music
- [ ] 7. MusicKit identifier'ı güncelle
- [ ] 8. Media Player izinlerini kontrol et

### Spotify
- [ ] 9. Redirect URI'yi güncelle
- [ ] 10. Bundle ID'yi Spotify Dashboard'da güncelle

### Xcode Proje Ayarları
- [ ] 11. Info.plist'i güncelle
- [ ] 12. Entitlements dosyasını güncelle
- [ ] 13. Background Task identifier'larını güncelle

### Test ve Deployment
- [ ] 14. Tüm özellikleri test et
- [ ] 15. TestFlight'a yükle
- [ ] 16. App Store Connect'te bundle ID'yi onayla

---

## 📋 Detaylı Adımlar

## 1. Apple Developer Portal - App ID

### 1.1 Yeni App ID Oluştur

1. [Apple Developer Portal](https://developer.apple.com/account) → **Certificates, Identifiers & Profiles**
2. **Identifiers** → **+** (Add butonu)
3. **App IDs** seç → **Continue**
4. **App** seç → **Continue**

**Bilgileri Doldur:**
```
Description: ONE - Günlük Mood
Bundle ID: Explicit
App ID Prefix: [Otomatik]
Bundle ID: com.batu.ones
```

### 1.2 Capabilities Seç

Şu capabilities'i işaretle:

- ✅ **iCloud**
  - Include CloudKit support
  - Use default container
- ✅ **Push Notifications**
- ✅ **Background Modes**
- ✅ **Sign in with Apple** (eğer kullanıyorsanız)
- ✅ **Associated Domains** (eğer kullanıyorsanız)

**Continue** → **Register**

---

## 2. Provisioning Profiles

### 2.1 Development Profile

1. **Profiles** → **+** (Add butonu)
2. **iOS App Development** seç → **Continue**
3. **App ID:** `com.batu.ones` seç → **Continue**
4. **Certificates:** Development certificate'ınızı seç → **Continue**
5. **Devices:** Test cihazlarınızı seç → **Continue**
6. **Profile Name:** `ONE Development Profile`
7. **Generate** → **Download**

### 2.2 Distribution Profile (App Store)

1. **Profiles** → **+**
2. **App Store** seç → **Continue**
3. **App ID:** `com.batu.ones` seç → **Continue**
4. **Certificates:** Distribution certificate'ınızı seç → **Continue**
5. **Profile Name:** `ONE Distribution Profile`
6. **Generate** → **Download**

### 2.3 Xcode'da Profile'ları Yükle

1. İndirilen `.mobileprovision` dosyalarına çift tıkla
2. Veya Xcode → **Settings** → **Accounts** → **Download Manual Profiles**

---

## 3. CloudKit Container

### 3.1 Yeni Container Oluştur

**Seçenek A: Yeni Container (Önerilen)**

1. [CloudKit Dashboard](https://icloud.developer.apple.com/dashboard)
2. **Add Container** (+)
3. **Container Name:** `iCloud.com.batu.ones`
4. **Create**

**Seçenek B: Mevcut Container'ı Kullan**

Eğer `iCloud.com.batu.one` container'ında önemli data varsa:
- Mevcut container'ı kullanmaya devam edebilirsiniz
- Xcode'da container ID'yi manuel olarak belirtmeniz gerekir

### 3.2 Schema'yı Yeniden Oluştur

Yeni container kullanıyorsanız, schema'yı tekrar oluşturun:

**Record Types:**
- Users (6 field)
- Friendship (6 field)
- DailyShare (15 field)

**Indexes:**
- Users.userID (QUERYABLE)
- Users.inviteCode (QUERYABLE)
- Friendship.user1ID (QUERYABLE)
- Friendship.user2ID (QUERYABLE)
- Friendship.status (QUERYABLE)
- DailyShare.userID (QUERYABLE)
- DailyShare.date (QUERYABLE)
- DailyShare.isPublic (QUERYABLE)
- DailyShare.createdAt (QUERYABLE)

👉 Detaylı adımlar için: [CLOUDKIT_DASHBOARD_SETUP_NEW.md](./CLOUDKIT_DASHBOARD_SETUP_NEW.md)

### 3.3 Data Migration (Opsiyonel)

Eski container'dan yeni container'a data taşımak için:

```swift
// CloudKit Migration Script (one-time use)
func migrateCloudKitData() {
    let oldContainer = CKContainer(identifier: "iCloud.com.batu.one")
    let newContainer = CKContainer(identifier: "iCloud.com.batu.ones")
    
    // Fetch from old
    let query = CKQuery(recordType: "Users", predicate: NSPredicate(value: true))
    oldContainer.publicCloudDatabase.perform(query, inZoneWith: nil) { records, error in
        guard let records = records else { return }
        
        // Save to new
        newContainer.publicCloudDatabase.save(records) { _, error in
            if let error = error {
                print("Migration error: \(error)")
            }
        }
    }
}
```

⚠️ **Not:** Bu işlem tek seferlik yapılmalı ve dikkatli test edilmelidir.

---

## 4. Xcode - iCloud Container Güncelleme

### 4.1 Signing & Capabilities

1. Xcode'da projeyi aç
2. **Target: one** seç
3. **Signing & Capabilities** sekmesi
4. **iCloud** capability'sini bul

### 4.2 Container Seç

**Seçenek A: Default Container (Önerilen)**
```
☑ iCloud
  ☑ CloudKit
  Containers:
    ☑ iCloud.com.batu.ones (Default)
```

**Seçenek B: Custom Container**
```
☑ iCloud
  ☑ CloudKit
  ☑ Use custom containers
  Containers:
    ☑ iCloud.com.batu.one (eski data için)
    ☑ iCloud.com.batu.ones (yeni)
```

### 4.3 Persistence.swift Güncelle

Eğer custom container kullanıyorsanız:

```swift
// one/one/Persistence.swift

let containerIdentifier = "iCloud.com.batu.ones" // GÜNCELLE

description.cloudKitContainerOptions = NSPersistentCloudKitContainerOptions(
    containerIdentifier: containerIdentifier
)
```

---

## 5. MusicKit / Apple Music

### 5.1 MusicKit Identifier

MusicKit otomatik olarak Bundle ID kullanır, ekstra ayar gerekmez.

### 5.2 Info.plist Kontrol

```xml
<!-- one/one/Info.plist -->

<key>NSAppleMusicUsageDescription</key>
<string>Günlük müziğini kaydetmek için Apple Music'e erişim gereklidir.</string>
```

Bu ayar zaten mevcut, değişiklik gerekmez.

### 5.3 Test

1. Uygulamayı çalıştır
2. "Today" sekmesinde şarkı ara
3. Apple Music'ten arama yapabildiğinizi kontrol et

---

## 6. Spotify Integration

### 6.1 Spotify Developer Dashboard

1. [Spotify Developer Dashboard](https://developer.spotify.com/dashboard)
2. Uygulamanızı seç (ONE Music App)
3. **Settings** tıkla

### 6.2 Redirect URI Güncelle

**Eski:**
```
one://spotify-callback
```

**Yeni:** (Aynı kalabilir, bundle ID'den bağımsız)
```
one://spotify-callback
```

⚠️ **Not:** Redirect URI scheme'i (`one://`) bundle ID'den farklı olabilir. Değiştirmenize gerek yok.

### 6.3 Bundle ID Ekle (iOS)

Eğer Spotify Dashboard'da "iOS Bundle ID" alanı varsa:

```
Bundle ID: com.batu.ones
```

Ekleyin veya güncelleyin.

### 6.4 SpotifyManager.swift Kontrol

```swift
// one/one/SpotifyManager.swift

private let redirectURI = "one://spotify-callback" // Değişmez
private let clientID = "YOUR_SPOTIFY_CLIENT_ID" // Değişmez
```

Bu ayarlar bundle ID'den bağımsız, değişiklik gerekmez.

---

## 7. Info.plist Güncellemeleri

### 7.1 URL Schemes

```xml
<!-- one/one/Info.plist -->

<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleURLName</key>
        <string>com.batu.ones</string> <!-- GÜNCELLE -->
        <key>CFBundleURLSchemes</key>
        <array>
            <string>one</string> <!-- Değişmez -->
        </array>
    </dict>
</array>
```

### 7.2 Background Task Identifier

```xml
<key>BGTaskSchedulerPermittedIdentifiers</key>
<array>
    <string>com.batu.ones.midnightReset</string> <!-- GÜNCELLE -->
</array>
```

### 7.3 Tam Info.plist Güncellemesi


```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <!-- Background Tasks -->
    <key>BGTaskSchedulerPermittedIdentifiers</key>
    <array>
        <string>com.batu.ones.midnightReset</string>
    </array>
    
    <!-- URL Schemes -->
    <key>CFBundleURLTypes</key>
    <array>
        <dict>
            <key>CFBundleURLName</key>
            <string>com.batu.ones</string>
            <key>CFBundleURLSchemes</key>
            <array>
                <string>one</string>
            </array>
        </dict>
    </array>
    
    <!-- Query Schemes (Değişmez) -->
    <key>LSApplicationQueriesSchemes</key>
    <array>
        <string>spotify</string>
        <string>instagram</string>
        <string>instagram-stories</string>
    </array>
    
    <!-- Permissions (Değişmez) -->
    <key>NSAppleMusicUsageDescription</key>
    <string>Günlük müziğini kaydetmek için Apple Music'e erişim gereklidir.</string>
    
    <key>LSBundleContainsCoreMLmlmodelc</key>
    <false/>
    
    <!-- Background Modes (Değişmez) -->
    <key>UIBackgroundModes</key>
    <array>
        <string>remote-notification</string>
        <string>processing</string>
    </array>
</dict>
</plist>
```

---

## 8. Entitlements Dosyası

### 8.1 one.entitlements Güncelle

Xcode otomatik oluşturur, ancak kontrol edin:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <!-- iCloud Containers -->
    <key>com.apple.developer.icloud-container-identifiers</key>
    <array>
        <string>iCloud.com.batu.ones</string> <!-- GÜNCELLE -->
    </array>
    
    <!-- iCloud Services -->
    <key>com.apple.developer.icloud-services</key>
    <array>
        <string>CloudKit</string>
    </array>
    
    <!-- Ubiquity Containers -->
    <key>com.apple.developer.ubiquity-container-identifiers</key>
    <array>
        <string>iCloud.com.batu.ones</string> <!-- GÜNCELLE -->
    </array>
    
    <!-- Push Notifications -->
    <key>aps-environment</key>
    <string>development</string> <!-- Production'da: production -->
</dict>
</plist>
```

### 8.2 Dosya Konumu

```
one/one/one.entitlements
```

Eğer yoksa, Xcode otomatik oluşturacaktır.

---

## 9. Background Task Identifier Güncelleme

### 9.1 MidnightResetManager.swift

```swift
// one/one/MidnightResetManager.swift

class MidnightResetManager {
    // Background task identifier
    private let taskIdentifier = "com.batu.ones.midnightReset" // GÜNCELLE
    
    func registerBackgroundTask() {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: taskIdentifier,
            using: nil
        ) { task in
            self.handleMidnightReset(task: task as! BGProcessingTask)
        }
    }
    
    func scheduleMidnightReset() {
        let request = BGProcessingTaskRequest(identifier: taskIdentifier)
        request.earliestBeginDate = getNextMidnight()
        request.requiresNetworkConnectivity = false
        request.requiresExternalPower = false
        
        do {
            try BGTaskScheduler.shared.submit(request)
            print("✅ Midnight reset scheduled")
        } catch {
            print("❌ Could not schedule: \(error)")
        }
    }
    
    // ... rest of the code
}
```

---

## 10. CloudKitManager.swift Güncelleme

### 10.1 Container Identifier

```swift
// one/one/CloudKitManager.swift

class CloudKitManager: ObservableObject {
    static let shared = CloudKitManager()
    
    // CloudKit container
    private let container = CKContainer(identifier: "iCloud.com.batu.ones") // GÜNCELLE
    private let publicDatabase: CKDatabase
    
    init() {
        publicDatabase = container.publicCloudDatabase
        checkCloudKitAvailability()
    }
    
    // ... rest of the code
}
```

---

## 11. Test Checklist

### 11.1 Temel Özellikler

- [ ] Uygulama açılıyor
- [ ] Splash screen görünüyor
- [ ] Onboarding çalışıyor
- [ ] Ana ekran yükleniyor

### 11.2 Müzik Özellikleri

- [ ] Apple Music arama çalışıyor
- [ ] Spotify arama çalışıyor (giriş yaptıktan sonra)
- [ ] Şarkı seçimi kaydediliyor
- [ ] Albüm kapakları görünüyor

### 11.3 CloudKit / Çevre

- [ ] Kullanıcı oluşturuluyor
- [ ] Davet kodu üretiliyor
- [ ] Arkadaş ekleme çalışıyor
- [ ] Paylaşımlar görünüyor
- [ ] Sync çalışıyor (iki cihazda test)

### 11.4 Diğer Özellikler

- [ ] Arşiv görünümü çalışıyor
- [ ] Takvim entegrasyonu çalışıyor
- [ ] Fotoğraf ekleme çalışıyor
- [ ] Instagram story paylaşımı çalışıyor
- [ ] Midnight reset çalışıyor

---

## 12. Deployment

### 12.1 Archive Oluştur

1. Xcode'da **Product** → **Archive**
2. Archive tamamlandığında **Organizer** açılır
3. Archive'ı seç → **Distribute App**

### 12.2 TestFlight

1. **App Store Connect** seç → **Next**
2. **Upload** seç → **Next**
3. Otomatik signing seç → **Next**
4. **Upload**

### 12.3 App Store Connect Kontrol

1. [App Store Connect](https://appstoreconnect.apple.com)
2. **My Apps** → **ONE**
3. **App Information** sekmesi
4. **Bundle ID:** `com.batu.ones` olduğunu kontrol et

---

## 13. Sorun Giderme

### "No matching provisioning profiles found"

**Çözüm:**
1. Xcode → **Settings** → **Accounts**
2. Apple ID'nizi seç → **Download Manual Profiles**
3. Veya **Signing & Capabilities** → **Automatically manage signing** işaretle

### "CloudKit container not found"

**Çözüm:**
1. CloudKit Dashboard'da container oluşturuldu mu?
2. Xcode'da **Signing & Capabilities** → **iCloud** → Container seçili mi?
3. `CloudKitManager.swift`'te container ID doğru mu?

### "Background task not registered"

**Çözüm:**
1. `Info.plist`'te `BGTaskSchedulerPermittedIdentifiers` doğru mu?
2. `MidnightResetManager.swift`'te identifier aynı mı?
3. Uygulama başlangıcında `registerBackgroundTask()` çağrılıyor mu?

### "Spotify redirect not working"

**Çözüm:**
1. `Info.plist`'te `CFBundleURLSchemes` → `one` var mı?
2. Spotify Dashboard'da redirect URI: `one://spotify-callback` doğru mu?
3. `SpotifyManager.swift`'te `redirectURI` doğru mu?

### "Apple Music authorization failed"

**Çözüm:**
1. `Info.plist`'te `NSAppleMusicUsageDescription` var mı?
2. Simulator'da değil, gerçek cihazda test edin
3. Ayarlar → Gizlilik → Medya ve Apple Music → ONE → İzin ver

---

## 14. Önemli Notlar

### Bundle ID Değişikliği Etkileri

✅ **Değişmez:**
- Kullanıcı verileri (Core Data local)
- Keychain verileri (aynı team ID ile)
- UserDefaults

❌ **Sıfırlanır:**
- CloudKit verileri (yeni container)
- Push notification token'ları
- App Store yorumları ve puanları (yeni app gibi)

### Data Migration

Eğer kullanıcılarınız varsa:
1. Eski bundle ID ile son bir update yayınlayın
2. Update'te data export özelliği ekleyin
3. Yeni bundle ID ile yeni app yayınlayın
4. Yeni app'te data import özelliği ekleyin

### CloudKit Container Seçimi

**Yeni Container (Önerilen):**
- ✅ Temiz başlangıç
- ✅ Test verisi yok
- ❌ Eski data kaybolur

**Eski Container:**
- ✅ Data korunur
- ❌ Xcode'da manuel ayar gerekir
- ❌ Karışıklık olabilir

---

## 15. Özet - Değiştirilmesi Gerekenler

### Dosyalar

| Dosya | Değişiklik | Yeni Değer |
|-------|-----------|-----------|
| `Info.plist` | `CFBundleURLName` | `com.batu.ones` |
| `Info.plist` | `BGTaskSchedulerPermittedIdentifiers` | `com.batu.ones.midnightReset` |
| `one.entitlements` | `icloud-container-identifiers` | `iCloud.com.batu.ones` |
| `Persistence.swift` | `containerIdentifier` | `iCloud.com.batu.ones` |
| `CloudKitManager.swift` | `CKContainer(identifier:)` | `iCloud.com.batu.ones` |
| `MidnightResetManager.swift` | `taskIdentifier` | `com.batu.ones.midnightReset` |

### Apple Developer Portal

| Servis | Değişiklik |
|--------|-----------|
| App ID | Yeni oluştur: `com.batu.ones` |
| Provisioning Profiles | Yeniden oluştur (Development + Distribution) |
| CloudKit Container | Yeni oluştur: `iCloud.com.batu.ones` |

### Xcode

| Ayar | Konum | Değişiklik |
|------|-------|-----------|
| Bundle Identifier | Target → General | `com.batu.ones` |
| iCloud Container | Signing & Capabilities | `iCloud.com.batu.ones` seç |
| Provisioning Profile | Signing & Capabilities | Yeni profile'ları seç |

---

## 16. Sonraki Adımlar

1. ✅ Bu dokümandaki tüm adımları tamamlayın
2. ✅ Test checklist'i doldurun
3. ✅ TestFlight'a yükleyin
4. ✅ Beta test yapın
5. ✅ App Store'a gönderin

---

## 📞 Yardım

Sorun yaşarsanız:

1. **Xcode Console:** Hata mesajlarını kontrol edin
2. **CloudKit Dashboard:** Data sekmesinde record'ları kontrol edin
3. **Device Console:** Ayarlar → Gizlilik → Analitik ve İyileştirmeler
4. **Apple Developer Forums:** [developer.apple.com/forums](https://developer.apple.com/forums)

---

## ✅ Tamamlandı!

Bundle ID değişikliği tamamlandığında:

- [x] Yeni bundle ID: `com.batu.ones`
- [x] App ID oluşturuldu
- [x] Provisioning profiles oluşturuldu
- [x] CloudKit container güncellendi
- [x] Info.plist güncellendi
- [x] Entitlements güncellendi
- [x] Background task identifier güncellendi
- [x] CloudKitManager güncellendi
- [x] Tüm özellikler test edildi
- [x] TestFlight'a yüklendi

🎉 **Artık yeni bundle ID ile production'a hazırsınız!**

---

## 📚 İlgili Dokümanlar

- [CLOUDKIT_SETUP.md](./CLOUDKIT_SETUP.md) - CloudKit kurulum rehberi
- [CLOUDKIT_DASHBOARD_SETUP_NEW.md](./CLOUDKIT_DASHBOARD_SETUP_NEW.md) - Dashboard schema kurulumu
- [SPOTIFY_SETUP.md](./SPOTIFY_SETUP.md) - Spotify entegrasyonu
- [CIRCLE_QUICK_START.md](./CIRCLE_QUICK_START.md) - Çevre özelliği hızlı başlangıç
- [BUILD_NOTES.md](./BUILD_NOTES.md) - Build notları

---

**Son Güncelleme:** 2025-02-27  
**Versiyon:** 1.0  
**Durum:** ✅ Tamamlandı
