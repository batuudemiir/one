# ONE+ Hızlı Test Checklist

## Ön Hazırlık (5 dakika)

### 1. StoreKit Configuration
```
Xcode → Product → Scheme → Edit Scheme → Run → Options
StoreKit Configuration: Seçili olmalı (veya yeni oluştur)
```

### 2. Test Ürünleri Ekle
StoreKit Configuration dosyasına ekle:
- **Aylık**: `com.batudemir.ones.oneplus.monthly` (örn: ₺49.99/ay)
- **Yıllık**: `com.batudemir.ones.oneplus.yearly` (örn: ₺399.99/yıl)

## Hızlı Test Senaryoları (10 dakika)

### ✅ Test 1: Paywall Açılışı
1. Uygulamayı çalıştır
2. Premium özelliklerden birine dokun (örn: çoklu entry)
3. **Beklenen**: PaywallView açılır, planlar görünür

### ✅ Test 2: Aylık Satın Alma
1. Paywall'da aylık planı seç
2. "Subscribe" butonuna bas
3. StoreKit dialog'unda "Subscribe" seç
4. **Beklenen**: 
   - Başarı mesajı görünür
   - Paywall kapanır
   - Premium özellikler aktif

### ✅ Test 3: Yıllık Satın Alma
1. Paywall'da yıllık planı seç
2. "Subscribe" butonuna bas
3. StoreKit dialog'unda "Subscribe" seç
4. **Beklenen**: 
   - "Best Value" badge'i görünür
   - Satın alma başarılı
   - Premium aktif

### ✅ Test 4: İptal
1. Bir plan seç
2. "Subscribe" butonuna bas
3. StoreKit dialog'unda "Cancel" seç
4. **Beklenen**: 
   - Paywall açık kalır
   - Premium aktif olmaz

### ✅ Test 5: Restore
1. Daha önce satın alma yap
2. Uygulamayı kapat/aç
3. Paywall'da "Restore Purchases" bas
4. **Beklenen**: Premium durumu geri yüklenir

## Debug Kontrolleri

### Console Log'ları İzle
```
[ONE] [GENERAL] Loaded 2 premium products
[ONE] [GENERAL] Purchase successful: com.batudemir.ones.oneplus.monthly
[ONE] [GENERAL] Premium status: true
```

### Breakpoint Noktaları
- `PremiumManager.purchase(_:)` - Satın alma başlangıcı
- `PremiumManager.checkEntitlements()` - Premium durum kontrolü
- `PaywallView.purchaseSelected()` - UI satın alma akışı

## Hızlı Sorun Giderme

### Ürünler yüklenmiyor?
```bash
# Xcode'u yeniden başlat
# StoreKit Configuration'ı kontrol et
# Product ID'leri doğrula
```

### Premium durumu güncellenmiyor?
```swift
// PremiumManager.swift içinde kontrol et:
print("isPremium: \(premiumManager.isPremium)")
print("Products: \(premiumManager.products.count)")
```

### Widget'a gelmiyor?
```swift
// UserDefaults kontrolü
let defaults = UserDefaults(suiteName: "group.com.batudemir.ones")
print("Widget premium: \(defaults?.bool(forKey: "widget_isPremium") ?? false)")
```

## Başarı Kriterleri

- [x] Paywall açılıyor
- [x] Planlar görünüyor
- [x] Satın alma çalışıyor
- [x] Premium durumu güncelleniyor
- [x] Restore çalışıyor
- [x] Hata durumları ele alınıyor

## Sonraki Adımlar

1. ✅ Simulator'da test et
2. ✅ Gerçek cihazda test et
3. 📱 TestFlight'ta test et (sandbox kullanıcılarla)
4. 🚀 Production'a gönder

## Notlar

- Simulator'da StoreKit 2 tam çalışır
- Gerçek satın alma yapılmaz (test modu)
- Production için App Store Connect'te ürünler oluşturulmalı
