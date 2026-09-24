# 🚀 Çevre Özelliği - Hızlı Başlangıç Rehberi

## 📋 Özet

Bu rehber, Çevre (Circle) özelliğini ONE uygulamasına entegre etmek için gereken minimum adımları içerir.

## ✅ Ön Kontrol Listesi

Başlamadan önce şunlara sahip olduğunuzdan emin olun:

- [ ] Ücretli Apple Developer hesabı
- [ ] Xcode 14.0+
- [ ] macOS Ventura veya üzeri
- [ ] ONE projesinin çalışan bir kopyası
- [ ] CloudKit Dashboard erişimi

## 🎯 5 Adımda Kurulum

### Adım 1: Xcode Capabilities (5 dakika)

```bash
# Xcode'da:
1. Target seç: "one"
2. Signing & Capabilities sekmesi
3. "+ Capability" → "iCloud"
4. ✅ CloudKit işaretle
5. Container: iCloud.com.yourcompany.one
```

### Adım 2: Dosyaları Ekle (2 dakika)

Aşağıdaki dosyalar zaten oluşturuldu, projeye ekleyin:

```
one/one/
├── CloudKitManager.swift      ✅ Oluşturuldu
├── CircleView.swift           ✅ Oluşturuldu
└── AddFriendView.swift        ✅ Oluşturuldu
```

**Xcode'da:**
1. File → Add Files to "one"
2. Yukarıdaki 3 dosyayı seç
3. "Copy items if needed" işaretle
4. "Add" tıkla

### Adım 3: Core Data Güncelle (10 dakika)

`one.xcdatamodeld` dosyasını aç ve şu entity'leri ekle:

**User Entity:**
```
Attributes:
- userID: String
- displayName: String
- inviteCode: String
- avatarColor: String
- isPublic: Boolean
- createdDate: Date
```

**Friendship Entity:**
```
Attributes:
- friendshipID: UUID
- user1ID: String
- user2ID: String
- status: String
- createdDate: Date
- acceptedDate: Date (Optional)
```

**DailyEntry'ye ekle:**
```
Attributes:
- isSharedWithCircle: Boolean (default: false)
- viewCount: Integer 16 (default: 0)
- sharedAt: Date (Optional)
```

### Adım 4: Persistence.swift Güncelle (5 dakika)

`one/one/Persistence.swift` dosyasını aç ve değiştir:

```swift
// Değiştir:
let container: NSPersistentContainer

// Şununla:
let container: NSPersistentCloudKitContainer

// init içinde ekle:
guard let description = container.persistentStoreDescriptions.first else {
    fatalError("Failed to retrieve persistent store description")
}

description.cloudKitContainerOptions = NSPersistentCloudKitContainerOptions(
    containerIdentifier: "iCloud.com.yourcompany.one"
)

description.setOption(true as NSNumber, 
                    forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
```

### Adım 5: ContentView'e Ekle (2 dakika)

`one/one/ContentView.swift` dosyasında TabView'e ekle:

```swift
TabView(selection: $selectedTab) {
    // ... mevcut sekmeler
    
    CircleView()
        .tabItem {
            Label("Çevre", systemImage: "person.3.fill")
        }
        .tag(3) // veya uygun bir tag numarası
}
```

## 🧪 İlk Test (5 dakika)

1. Xcode'da projeyi build et (⌘B)
2. Simulator'da çalıştır (⌘R)
3. "Çevre" sekmesine git
4. "iCloud erişimi gerekli" mesajını görmelisin
5. Simulator'da Settings → iCloud → iCloud Drive aç
6. Uygulamayı yeniden başlat
7. "Henüz çevren yok" ekranını görmelisin ✅

## 📱 İki Cihazda Test

### Cihaz 1:
1. Farklı iCloud hesabı ile giriş yap
2. Uygulamayı aç
3. Çevre → Arkadaş Ekle
4. Davet kodunu not et (örn: ABC123)

### Cihaz 2:
1. Başka bir iCloud hesabı ile giriş yap
2. Uygulamayı aç
3. Çevre → Arkadaş Ekle
4. Davet kodunu gir (ABC123)
5. "Davet Gönder" tıkla

### Cihaz 1:
1. Daveti onayla (yakında eklenecek)
2. Bugün bir şarkı seç
3. "Çevrenle paylaş?" → Evet

### Cihaz 2:
1. Çevre sekmesine git
2. Pull-to-refresh
3. Arkadaşının seçimini gör ✅

## 🐛 Sorun Giderme

### "CloudKit not available"
```
Çözüm: Settings → iCloud → iCloud Drive açık olmalı
```

### "Container not found"
```
Çözüm: 
1. Xcode → Signing & Capabilities kontrol et
2. Container ID doğru mu?
3. Clean Build Folder (⌘⇧K)
```

### "Schema not found"
```
Çözüm:
1. CloudKit Dashboard'a git
2. Schema'yı Development'a deploy et
```

### Build hatası
```
Çözüm:
1. File → Packages → Reset Package Caches
2. Clean Build Folder (⌘⇧K)
3. Rebuild (⌘B)
```

## 📚 Sonraki Adımlar

Temel kurulum tamamlandı! Şimdi:

1. **Detaylı Özellikler**: [CEVRE_FEATURE.md](./CEVRE_FEATURE.md)
2. **Teknik Detaylar**: [CLOUDKIT_SETUP.md](./CLOUDKIT_SETUP.md)
3. **Uygulama Planı**: [IMPLEMENTATION_ROADMAP.md](./IMPLEMENTATION_ROADMAP.md)
4. **Gizlilik**: [PRIVACY_POLICY.md](./PRIVACY_POLICY.md)

## 🎨 Özelleştirme

### Renkleri Değiştir
`CircleView.swift` içinde:
```swift
Color(hex: "#F7F6F3") // Arka plan
Color.black // Vurgular
```

### Tab İkonunu Değiştir
`ContentView.swift` içinde:
```swift
systemImage: "person.3.fill" // İstediğin ikonu kullan
```

### Davet Kodu Formatı
`CloudKitManager.swift` içinde:
```swift
func generateInviteCode() -> String {
    // 3 harf + 3 rakam (ABC123)
    // İstediğin formatı kullanabilirsin
}
```

## ✨ Bonus: Hızlı Demo

Test için mock data ekle:

```swift
// CircleView.swift içinde
#if DEBUG
.onAppear {
    // Mock data ekle
    createMockShares()
}

func createMockShares() {
    // Test için sahte arkadaş paylaşımları
}
#endif
```

## 🎉 Tamamlandı!

Çevre özelliği artık çalışıyor! Sorularınız için:
- GitHub Issues
- E-posta: dev@oneapp.com
- Dokümantasyon: Yukarıdaki linkler

---

**Toplam Süre:** ~30 dakika  
**Zorluk:** Orta  
**Gerekli Bilgi:** SwiftUI, Core Data, CloudKit temelleri
