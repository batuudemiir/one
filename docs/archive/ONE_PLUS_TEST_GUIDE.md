# ONE+ Abonelik Test Rehberi

## Test Ortamı Hazırlığı

### 1. StoreKit Configuration Dosyası
Xcode'da test için StoreKit Configuration dosyası kullanılıyor olmalı:
- Xcode'da: `Product` → `Scheme` → `Edit Scheme`
- `Run` sekmesinde `Options` → `StoreKit Configuration`
- Eğer yoksa, yeni bir `.storekit` dosyası oluştur

### 2. Test Ürünleri
Kodda tanımlı ürünler:
- **Aylık**: `com.batudemir.ones.oneplus.monthly`
- **Yıllık**: `com.batudemir.ones.oneplus.yearly`

## Test Senaryoları

### Senaryo 1: Paywall Görüntüleme
**Adımlar:**
1. Uygulamayı başlat
2. Premium özelliklerden birine tıkla:
   - Çoklu entry ekleme
   - Haftalık playlist
   - Circle feed
   - Aylık özet
   - Premium widget'lar
3. Paywall ekranının açıldığını doğrula

**Beklenen Sonuç:**
- PaywallView açılır
- Aylık ve yıllık planlar görünür
- Fiyatlar doğru gösterilir
- Premium özelliklerin listesi görünür

### Senaryo 2: Aylık Abonelik Satın Alma
**Adımlar:**
1. Paywall'da aylık plan seçeneğine tıkla
2. StoreKit test dialog'unda "Subscribe" seç
3. Satın alma işleminin tamamlanmasını bekle

**Beklenen Sonuç:**
- `PremiumManager.isPremium` = `true` olur
- Paywall kapanır
- Premium özellikler aktif hale gelir
- Widget'a premium durumu senkronize edilir

### Senaryo 3: Yıllık Abonelik Satın Alma
**Adımlar:**
1. Paywall'da yıllık plan seçeneğine tıkla
2. StoreKit test dialog'unda "Subscribe" seç
3. Satın alma işleminin tamamlanmasını bekle

**Beklenen Sonuç:**
- `PremiumManager.isPremium` = `true` olur
- Yıllık tasarruf miktarı doğru hesaplanır
- Premium badge "ONE+" gösterir

### Senaryo 4: Satın Alma İptali
**Adımlar:**
1. Paywall'da bir plan seç
2. StoreKit dialog'unda "Cancel" seç

**Beklenen Sonuç:**
- `PremiumManager.purchaseState` = `.idle` olur
- Paywall açık kalır
- Kullanıcı hala premium değil

### Senaryo 5: Satın Almaları Geri Yükleme
**Adımlar:**
1. Daha önce satın alınmış bir abonelik varsa
2. Paywall'da "Restore Purchases" butonuna tıkla

**Beklenen Sonuç:**
- Önceki abonelik geri yüklenir
- `isPremium` = `true` olur
- Başarı mesajı gösterilir

### Senaryo 6: Premium Özelliklere Erişim
**Premium kullanıcı olarak test et:**

#### 6.1 Çoklu Entry
- Today ekranında birden fazla entry ekleyebilme
- Entry sayacının gösterilmesi
- Sayfa göstergesi (dots) ile geçiş

#### 6.2 Premium Badge
- Profile'da "ONE+" badge'inin görünmesi
- Badge'e tıklandığında premium durumunun gösterilmesi

#### 6.3 Widget Senkronizasyonu
- Premium durumunun widget'a senkronize edilmesi
- Widget'ın premium özelliklerini göstermesi

### Senaryo 7: Premium Olmayan Kullanıcı
**Adımlar:**
1. Premium olmayan bir hesapla giriş yap
2. Premium özelliklere eriş

**Beklenen Sonuç:**
- `PremiumLockOverlay` gösterilir
- Paywall açılır
- Özellik kilitli kalır

## Test Kontrol Listesi

### Satın Alma Akışı
- [ ] Ürünler başarıyla yükleniyor
- [ ] Fiyatlar doğru gösteriliyor
- [ ] Aylık satın alma çalışıyor
- [ ] Yıllık satın alma çalışıyor
- [ ] İptal işlemi doğru çalışıyor
- [ ] Geri yükleme çalışıyor

### Premium Durum Yönetimi
- [ ] `isPremium` doğru güncelleniyor
- [ ] App Group'a senkronize ediliyor
- [ ] Widget premium durumunu alıyor
- [ ] Uygulama yeniden başlatıldığında durum korunuyor

### UI/UX
- [ ] Paywall tasarımı doğru
- [ ] Premium badge gösteriliyor
- [ ] Lock overlay çalışıyor
- [ ] Animasyonlar düzgün
- [ ] Hata mesajları anlaşılır

### Hata Durumları
- [ ] Ağ hatası durumunda uygun mesaj
- [ ] Doğrulama hatası durumunda uygun mesaj
- [ ] Ürün yüklenemezse uygun mesaj
- [ ] Throttle durumunda uygun davranış

## Debug İpuçları

### Console Log'ları
Premium işlemler için log kategorisi: `.general`
```swift
ONELogger.success("Purchase successful", category: .general)
ONELogger.error("Purchase failed", error: error, category: .general)
```

### UserDefaults Kontrolü
Widget premium durumu:
```swift
let defaults = UserDefaults(suiteName: "group.com.batudemir.ones")
print(defaults?.bool(forKey: "widget_isPremium") ?? false)
```

### StoreKit Test Durumları
Xcode'da: `Debug` → `StoreKit` → `Manage Transactions`
- Aktif abonelikleri görüntüle
- Test aboneliklerini iptal et
- Yenileme hızını değiştir

## Bilinen Sorunlar ve Çözümler

### Sorun: Ürünler yüklenmiyor
**Çözüm:**
- StoreKit Configuration dosyasının seçili olduğunu kontrol et
- Product ID'lerin doğru olduğunu kontrol et
- Xcode'u yeniden başlat

### Sorun: Premium durumu widget'a gelmiyor
**Çözüm:**
- App Group ID'nin doğru olduğunu kontrol et: `group.com.batudemir.ones`
- Widget'ı yeniden yükle
- `syncPremiumStatusToWidget()` metodunun çağrıldığını kontrol et

### Sorun: Transaction listener çalışmıyor
**Çözüm:**
- `listenForTransactions()` metodunun init'te çağrıldığını kontrol et
- Main actor isolation'ın doğru olduğunu kontrol et

## Production Test (TestFlight)

### App Store Connect Hazırlığı
1. **In-App Purchase Oluştur:**
   - App Store Connect → My Apps → ONE
   - Features → In-App Purchases
   - Aylık ve yıllık abonelik grupları oluştur

2. **Subscription Group:**
   - Yeni bir subscription group oluştur
   - Her iki planı da gruba ekle

3. **TestFlight:**
   - Internal testing için build yükle
   - Sandbox test kullanıcıları oluştur
   - Test kullanıcılarıyla satın alma testi yap

### Sandbox Test Kullanıcıları
- App Store Connect → Users and Access → Sandbox Testers
- Test için özel Apple ID'ler oluştur
- Gerçek ödeme yapılmaz

## Başarı Kriterleri

✅ Tüm satın alma akışları sorunsuz çalışıyor
✅ Premium durumu doğru yönetiliyor
✅ Widget senkronizasyonu çalışıyor
✅ Hata durumları düzgün ele alınıyor
✅ UI/UX akıcı ve anlaşılır
✅ Production'da (TestFlight) test edildi

## Notlar

- StoreKit 2 kullanılıyor (modern API)
- Tüm işlemler `@MainActor` üzerinde
- Transaction verification yapılıyor
- Auto-renewable subscriptions kullanılıyor
