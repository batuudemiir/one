# 🎵 MusicKit Identifier Kaydı - Apple Developer Portal

## ❌ Hata Mesajı

```
"com.batu.ones" was likely not registered as a valid client identifier.
Media API Token Service responded with status code: Not Found (404)
```

## 🔍 Sorunun Nedeni

Yeni bundle ID (`com.batu.ones`) Apple'ın MusicKit sistemine kayıtlı değil. Bu normal bir durum - her yeni bundle ID için MusicKit'i Apple Developer Portal'da aktif etmeniz gerekiyor.

---

## ✅ Çözüm - Apple Developer Portal'da MusicKit Ekle

### Adım 1: Apple Developer Portal'a Git

1. Tarayıcıda [Apple Developer Portal](https://developer.apple.com/account) aç
2. Apple ID ile giriş yap
3. **Certificates, Identifiers & Profiles** tıkla

---

### Adım 2: App ID'yi Bul ve Düzenle

1. Sol menüden **Identifiers** seç
2. Listeden **com.batu.ones** App ID'sini bul
3. Tıkla (düzenleme moduna geç)

---

### Adım 3: MusicKit Capability'sini Ekle

#### 3.1 Capabilities Bölümünü Bul

Sayfayı aşağı kaydır, **Capabilities** bölümünü bul.

#### 3.2 MusicKit'i İşaretle

Listede **MusicKit** bul ve checkbox'ı işaretle:

```
☑ MusicKit
```

#### 3.3 Kaydet

1. Sağ üstte **Save** butonuna tıkla
2. Onay ekranı gelecek:
   ```
   Modify App Capabilities
   This will modify the capabilities for App ID: com.batu.ones
   ```
3. **Confirm** tıkla

---

### Adım 4: Değişikliklerin Yayılmasını Bekle

⏱️ **Önemli:** Apple'ın sistemlerinde değişikliğin yayılması **5-30 dakika** sürebilir.

Bu süre zarfında:
- ✅ Diğer özellikleri test edebilirsiniz (Spotify, CloudKit, vb.)
- ❌ Apple Music henüz çalışmayacak

---

### Adım 5: Xcode'da Provisioning Profile'ları Yenile

MusicKit eklendikten sonra:

#### Seçenek A: Otomatik (Önerilen)

1. Xcode'u aç
2. **Signing & Capabilities** sekmesi
3. **Automatically manage signing** checkbox'ını:
   - Kaldır (uncheck)
   - Tekrar işaretle (check)
4. Xcode otomatik olarak yeni profile oluşturacak

#### Seçenek B: Manuel

1. Xcode → **Settings** (⌘,)
2. **Accounts** sekmesi
3. Apple ID'nizi seç
4. **Download Manual Profiles** butonuna tıkla

---

### Adım 6: Xcode'da MusicKit Capability Ekle

#### 6.1 Capability Ekle

1. Xcode'da projeyi aç
2. **Target: one** seç
3. **Signing & Capabilities** sekmesi
4. **+ Capability** butonuna tıkla (sol üstte)
5. Listeden **MusicKit** ara ve seç

#### 6.2 Entitlements Otomatik Güncellenir

Xcode otomatik olarak `one.entitlements` dosyasına şunu ekleyecek:

```xml
<key>com.apple.developer.music-kit</key>
<true/>
```

---

### Adım 7: Clean Build ve Test

#### 7.1 Clean Build

1. **Product** → **Clean Build Folder** (⇧⌘K)
2. **Product** → **Build** (⌘B)

#### 7.2 Uygulamayı Çalıştır

1. Simulator veya gerçek cihaz seç
2. **Product** → **Run** (⌘R)

#### 7.3 Apple Music Test

1. "Today" sekmesine git
2. Şarkı ara
3. Apple Music'ten sonuç gelmeli

---

## 🧪 Test Senaryoları

### Test 1: MusicKit Authorization

```swift
// Console'da şu mesajı görmeli:
✅ MusicKit: Authorization successful
```

Eğer hata görürseniz:
```
❌ MusicKit: Authorization failed - Not registered
```

**Çözüm:** 5-30 dakika bekleyin, Apple sistemleri güncelleniyor.

### Test 2: Apple Music Arama

1. Uygulamada "Apple Music" sekmesine git
2. Bir şarkı ara (örn: "Duman")
3. Sonuçlar gelmeli

Eğer 404 hatası alırsanız:
- Apple Developer Portal'da MusicKit eklendi mi? ✓
- 5-30 dakika beklediniz mi? ⏱️
- Provisioning profile yenilendi mi? ✓

---

## ⏱️ Bekleme Süresi

Apple'ın sistemlerinde değişiklik yayılma süreleri:

| İşlem | Süre |
|-------|------|
| App ID'ye capability ekleme | Anında |
| MusicKit API'ye kayıt | 5-30 dakika |
| Provisioning profile güncelleme | 1-5 dakika |
| Xcode'da profile indirme | Anında |

**Toplam bekleme:** ~10-30 dakika

---

## 🔄 Geçici Çözüm (Bekleme Süresinde)

MusicKit kaydı beklerken:

### Spotify'ı Kullan

1. Uygulamada "Spotify" sekmesine geç
2. Spotify ile giriş yap
3. Şarkı ara ve seç

Spotify hemen çalışacak, MusicKit kaydını beklemek zorunda değilsiniz.

### Diğer Özellikleri Test Et

- ✅ Çevre (Circle) özelliği
- ✅ Arşiv görünümü
- ✅ Fotoğraf ekleme
- ✅ Instagram story paylaşımı
- ✅ Takvim entegrasyonu

---

## 🚨 Yaygın Hatalar ve Çözümleri

### "Still getting 404 after 30 minutes"

**Çözüm:**
1. Apple Developer Portal'da MusicKit'in gerçekten işaretli olduğunu kontrol edin
2. **Save** butonuna tıkladığınızdan emin olun
3. Xcode'da provisioning profile'ları yenileyin
4. Uygulamayı tamamen kapatıp yeniden başlatın
5. Cihazı yeniden başlatın

### "MusicKit capability not showing in Xcode"

**Çözüm:**
1. Xcode'u tamamen kapatın
2. Derived Data'yı silin:
   - Xcode → Settings → Locations → Derived Data → Arrow → Klasörü sil
3. Xcode'u tekrar açın
4. Clean Build (⇧⌘K)

### "Authorization prompt not appearing"

**Çözüm:**
1. Gerçek cihazda test edin (Simulator'da çalışmayabilir)
2. Ayarlar → Gizlilik → Media & Apple Music → ONE → İzin ver
3. `Info.plist`'te `NSAppleMusicUsageDescription` var mı kontrol edin

---

## 📋 Checklist

MusicKit çalışması için:

- [ ] Apple Developer Portal'da **com.batu.ones** App ID'sine MusicKit capability eklendi
- [ ] **Save** butonuna tıklandı ve onaylandı
- [ ] 10-30 dakika beklendi (Apple sistemleri güncellendi)
- [ ] Xcode'da provisioning profile'lar yenilendi
- [ ] Xcode'da **Signing & Capabilities** → **MusicKit** eklendi
- [ ] `one.entitlements` dosyasında `com.apple.developer.music-kit` var
- [ ] Clean Build yapıldı
- [ ] Uygulama çalıştırıldı
- [ ] Apple Music arama çalışıyor

---

## 💡 Neden Bu Kadar Süre Alıyor?

Apple'ın MusicKit sistemi:
1. App ID'yi doğrular
2. Bundle ID'yi MusicKit API'ye kaydeder
3. Token servisini günceller
4. CDN'lerde değişiklikleri yayar

Bu işlemler dünya çapında birden fazla sunucuda gerçekleştiği için 5-30 dakika sürebilir.

---

## 🎯 Özet

1. ✅ Apple Developer Portal → Identifiers → com.batu.ones → MusicKit işaretle → Save
2. ⏱️ 10-30 dakika bekle
3. ✅ Xcode → Provisioning profile yenile
4. ✅ Xcode → + Capability → MusicKit ekle
5. ✅ Clean Build → Run
6. ✅ Apple Music arama çalışacak

---

## 📞 Hala Çalışmıyor mu?

Eğer 30 dakika sonra hala çalışmıyorsa:

1. **Apple Developer Forums:** [developer.apple.com/forums](https://developer.apple.com/forums)
2. **Apple Developer Support:** [developer.apple.com/contact](https://developer.apple.com/contact)
3. **Ticket aç:** "MusicKit not working for bundle ID com.batu.ones"

---

**Son Güncelleme:** 2025-02-27  
**Durum:** ⏱️ Apple Developer Portal'da MusicKit eklenmeli, 10-30 dakika beklenmeli
