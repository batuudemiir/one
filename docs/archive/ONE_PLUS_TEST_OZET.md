# ONE+ Test Özeti

## 🎯 Test Edilecek Özellikler

### 1. Paywall (Satın Alma Ekranı)
**Dosya**: `one/one/Features/Premium/PaywallView.swift`

**Test Noktaları:**
- ✅ Paywall açılışı
- ✅ Aylık/Yıllık plan seçimi
- ✅ Fiyat gösterimi
- ✅ Premium özelliklerin listesi
- ✅ "Best Value" badge (yıllık plan)
- ✅ Subscribe butonu
- ✅ Restore Purchases butonu
- ✅ Kapatma (X) butonu

### 2. Premium Manager
**Dosya**: `one/one/Core/Managers/PremiumManager.swift`

**Test Noktaları:**
- ✅ Ürün yükleme (`loadProducts`)
- ✅ Satın alma (`purchase`)
- ✅ Geri yükleme (`restorePurchases`)
- ✅ Premium durum kontrolü (`checkEntitlements`)
- ✅ Widget senkronizasyonu (`syncPremiumStatusToWidget`)
- ✅ Transaction listener

### 3. Premium Özellikleri

#### 3.1 Çoklu Entry (Today)
**Dosya**: `one/one/Features/Today/TodayCompletedView.swift`
- Premium kullanıcı: Birden fazla entry ekleyebilir
- Free kullanıcı: Tek entry + teaser gösterilir
- Entry sayacı ve sayfa göstergesi (dots)

#### 3.2 Aylık Özet (Profile)
**Dosya**: `one/one/Features/Profile/ProfileView.swift`
- Premium kullanıcı: Aylık özet kartına erişebilir
- Free kullanıcı: Kart kilitli + paywall açılır

#### 3.3 Premium Badge
**Dosya**: `one/one/UI/Components/PremiumBadge.swift`
- Premium kullanıcı: "ONE+" badge gösterilir
- Free kullanıcı: Badge'e tıklanınca paywall açılır

#### 3.4 Premium Lock Overlay
**Dosya**: `one/one/UI/Components/PremiumBadge.swift`
- Kilitli içerik üzerine blur + kilit ikonu
- Tıklanınca paywall açılır

## 🧪 Test Adımları

### Adım 1: Xcode Hazırlığı
```
1. Xcode'u aç
2. Product → Scheme → Edit Scheme
3. Run → Options → StoreKit Configuration seç
4. Eğer yoksa yeni .storekit dosyası oluştur
```

### Adım 2: Test Ürünleri Ekle
StoreKit Configuration dosyasına:
```
- Aylık: com.batudemir.ones.oneplus.monthly
- Yıllık: com.batudemir.ones.oneplus.yearly
```

### Adım 3: Uygulamayı Çalıştır
```bash
# Simulator'da çalıştır
Cmd + R

# Console log'ları izle
[ONE] [GENERAL] Loaded 2 premium products
```

### Adım 4: Paywall Testi
```
1. Profile → Aylık Özet kartına dokun
2. Paywall açılır
3. Yıllık planı seç (Best Value badge görünür)
4. Subscribe butonuna bas
5. StoreKit dialog'unda Subscribe seç
6. Başarı mesajı görünür
7. Paywall kapanır
```

### Adım 5: Premium Özellik Testi
```
1. Today ekranına git
2. Yeni entry ekle
3. Premium kullanıcı: Birden fazla entry ekleyebilir
4. Entry sayacı görünür (1/2, 2/2, vb.)
5. Sayfa göstergesi (dots) ile geçiş yapılabilir
```

### Adım 6: Widget Testi
```
1. Widget ekle (Home Screen)
2. Premium durumunun widget'a yansıdığını kontrol et
3. UserDefaults kontrolü:
   let defaults = UserDefaults(suiteName: "group.com.batudemir.ones")
   print(defaults?.bool(forKey: "widget_isPremium"))
```

## 🐛 Debug Komutları

### Console'da Premium Durumu
```swift
print("Premium: \(PremiumManager.shared.isPremium)")
print("Products: \(PremiumManager.shared.products)")
print("Purchase State: \(PremiumManager.shared.purchaseState)")
```

### StoreKit Transaction Yönetimi
```
Xcode → Debug → StoreKit → Manage Transactions
- Aktif abonelikleri gör
- Test aboneliklerini iptal et
- Yenileme hızını değiştir
```

### UserDefaults Widget Kontrolü
```swift
let defaults = UserDefaults(suiteName: "group.com.batudemir.ones")
print("Widget Premium: \(defaults?.bool(forKey: "widget_isPremium") ?? false)")
```

## ✅ Test Checklist

### Paywall
- [ ] Paywall açılıyor
- [ ] Aylık plan görünüyor
- [ ] Yıllık plan görünüyor
- [ ] "Best Value" badge görünüyor
- [ ] Fiyatlar doğru
- [ ] Premium özellikler listeleniyor
- [ ] Subscribe butonu çalışıyor
- [ ] Restore butonu çalışıyor
- [ ] Kapatma butonu çalışıyor

### Satın Alma
- [ ] Aylık satın alma başarılı
- [ ] Yıllık satın alma başarılı
- [ ] İptal işlemi çalışıyor
- [ ] Hata durumları gösteriliyor
- [ ] Başarı mesajı gösteriliyor
- [ ] Loading state çalışıyor

### Premium Durumu
- [ ] `isPremium` doğru güncelleniyor
- [ ] Widget'a senkronize ediliyor
- [ ] Uygulama yeniden başlatıldığında korunuyor
- [ ] Transaction listener çalışıyor

### Premium Özellikler
- [ ] Çoklu entry çalışıyor
- [ ] Entry sayacı görünüyor
- [ ] Sayfa göstergesi çalışıyor
- [ ] Aylık özet erişilebilir
- [ ] Premium badge gösteriliyor
- [ ] Lock overlay çalışıyor

### UI/UX
- [ ] Animasyonlar düzgün
- [ ] Haptic feedback çalışıyor
- [ ] Renkler doğru
- [ ] Typography doğru
- [ ] Spacing doğru

## 🚨 Bilinen Sorunlar

### Sorun 1: Ürünler yüklenmiyor
**Çözüm**: StoreKit Configuration seçili mi kontrol et

### Sorun 2: Premium durumu güncellenmiyor
**Çözüm**: `checkEntitlements()` metodunu kontrol et

### Sorun 3: Widget'a gelmiyor
**Çözüm**: App Group ID doğru mu kontrol et

## 📱 Production Test (Sonraki Adım)

### App Store Connect
1. In-App Purchase oluştur
2. Subscription Group oluştur
3. Aylık ve yıllık planları ekle
4. Fiyatlandırma ayarla

### TestFlight
1. Build yükle
2. Sandbox test kullanıcıları oluştur
3. Test kullanıcılarıyla satın alma testi yap

## 🎉 Başarı Kriterleri

✅ Tüm checklist maddeleri tamamlandı
✅ Simulator'da sorunsuz çalışıyor
✅ Gerçek cihazda test edildi
✅ Widget senkronizasyonu çalışıyor
✅ Hata durumları ele alınıyor
✅ UI/UX akıcı

## 📝 Notlar

- StoreKit 2 kullanılıyor (modern API)
- Tüm işlemler `@MainActor` üzerinde
- Transaction verification yapılıyor
- Auto-renewable subscriptions
- App Group: `group.com.batudemir.ones`
- Product IDs: `com.batudemir.ones.oneplus.*`
