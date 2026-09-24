# Test Modu Kullanımı

## ✅ Test Modu Aktif

`PremiumManager.swift` dosyasında test modu aktif edildi:

```swift
static let isTestMode = true  // ✅ Test için açık
```

## 🎯 Nasıl Çalışır?

### Test Modunda:
1. **"Abone Ol" butonuna tıkla**
2. **0.5 saniye bekle** (UX için)
3. **Premium otomatik aktif olur** ✨
4. **Tüm premium özellikler açılır**

### Normal Modda (Production):
1. "Abone Ol" butonuna tıkla
2. StoreKit satın alma dialog'u açılır
3. Gerçek satın alma işlemi yapılır
4. Transaction doğrulanır
5. Premium aktif olur

## 🧪 Test Adımları

1. **Uygulamayı çalıştır** (Cmd+R)
2. **Premium özelliklerden birine dokun**:
   - Profile → Aylık Özet
   - Today → Çoklu Entry
   - Herhangi bir kilitli özellik
3. **Paywall açılır**
4. **Bir plan seç** (aylık veya yıllık)
5. **"Abone Ol" butonuna bas**
6. **0.5 saniye sonra premium aktif!** 🎉

## 🔄 Test Modunu Kapatma

Production'a göndermeden önce test modunu kapat:

```swift
// PremiumManager.swift
static let isTestMode = false  // ❌ Production için kapat
```

## 📝 Test Modu Özellikleri

### Aktif Olduğunda:
- ✅ StoreKit bypass edilir
- ✅ Gerçek satın alma yapılmaz
- ✅ Premium anında aktif olur
- ✅ Widget'a senkronize edilir
- ✅ Uygulama yeniden başlatıldığında korunur
- ✅ Console'da "TEST MODE: Premium enabled" log'u görünür

### Kapalı Olduğunda:
- ❌ Normal StoreKit akışı çalışır
- ❌ Gerçek satın alma gerekir
- ❌ Transaction doğrulaması yapılır

## 🎨 Test Senaryoları

### Senaryo 1: İlk Satın Alma
```
1. Uygulama başlat
2. Premium özelliğe dokun
3. Paywall açılır
4. Yıllık planı seç
5. "Abone Ol" bas
6. ✅ Premium aktif
```

### Senaryo 2: Premium Özelliklere Erişim
```
1. Premium aktif olduktan sonra
2. Today → Yeni entry ekle
3. ✅ Çoklu entry ekleyebilirsin
4. ✅ Entry sayacı görünür
5. ✅ Sayfa göstergesi çalışır
```

### Senaryo 3: Aylık Özet
```
1. Profile'a git
2. Aylık Özet kartına dokun
3. ✅ Direkt açılır (kilit yok)
```

### Senaryo 4: Premium Badge
```
1. Profile'a git
2. ✅ "ONE+" badge görünür
3. Badge'e dokun
4. ✅ Premium durumu gösterilir
```

## 🐛 Debug

### Console Log'ları
Test modunda göreceğin log'lar:
```
[ONE] [GENERAL] TEST MODE: Premium enabled
[ONE] [GENERAL] TEST MODE: Premium status: true
```

### Premium Durumu Kontrol
```swift
print("Premium: \(PremiumManager.shared.isPremium)")
// Test modunda: true
```

### Widget Kontrolü
```swift
let defaults = UserDefaults(suiteName: "group.com.batudemir.ones")
print("Widget Premium: \(defaults?.bool(forKey: "widget_isPremium") ?? false)")
// Test modunda: true
```

## ⚠️ Önemli Notlar

1. **Production'a göndermeden önce test modunu kapat!**
2. Test modu sadece development için
3. TestFlight'ta test modunu kapalı tut
4. App Store'da kesinlikle kapalı olmalı

## 🚀 Production Hazırlığı

Production'a göndermeden önce:

```swift
// ❌ Test modunu kapat
static let isTestMode = false

// ✅ StoreKit Configuration kaldır
// ✅ App Store Connect'te ürünleri oluştur
// ✅ TestFlight'ta gerçek satın alma testi yap
```

## 💡 İpuçları

- Test modunda ürün yükleme hala çalışır (ama kullanılmaz)
- Paywall UI'ı normal görünür
- Tek fark: Satın alma anında gerçekleşir
- Premium durumu UserDefaults'a kaydedilir
- Uygulama yeniden başlatıldığında premium kalır

## 🎉 Başarı!

Test modu aktif! Artık "Abone Ol" butonuna tıklayınca premium özellikler direkt açılacak. İyi testler! 🚀
