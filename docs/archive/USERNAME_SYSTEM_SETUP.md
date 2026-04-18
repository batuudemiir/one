# Benzersiz Kullanıcı Adı Sistemi

## CloudKit Schema Güncellemesi

### Users Record Type'a Yeni Alan Ekle

1. CloudKit Dashboard'a git: https://icloud.developer.apple.com/dashboard
2. `iCloud.com.batu.ones` container'ı seç
3. **Schema** > **Record Types** > **Users**
4. Yeni field ekle:
   - Field Name: `username`
   - Field Type: `String`
   - **ÖNEMLİ**: Bu alanı **QUERYABLE** ve **SORTABLE** olarak işaretle

### Index Oluştur

5. **Indexes** sekmesine git
6. Yeni index ekle:
   - Field Name: `username`
   - Index Type: `QUERYABLE`
   - Sort Order: `ASCENDING`

### Schema'yı Deploy Et

7. **Development** ortamında test et
8. Çalıştığından emin olduktan sonra:
   - **Deployment** sekmesine git
   - **Deploy to Production** butonuna tıkla
   - Değişiklikleri onayla

## Kullanıcı Adı Kuralları

- Minimum 3 karakter
- Maximum 20 karakter
- Sadece harf, rakam ve alt çizgi (_)
- Harf ile başlamalı
- Küçük harfe çevrilecek (case-insensitive)
- Boşluk yok
- Benzersiz olmalı

## Özellikler

### 1. Gerçek Zamanlı Kontrol
- Kullanıcı yazarken 0.5 saniye sonra benzersizlik kontrolü
- Debounce ile gereksiz API çağrıları önlenir

### 2. Görsel Geri Bildirim
- ✅ Yeşil: Kullanılabilir
- ❌ Kırmızı: Kullanımda veya geçersiz
- ⏳ Gri: Kontrol ediliyor

### 3. Validasyon
- Format kontrolü (harf, rakam, _)
- Uzunluk kontrolü (3-20 karakter)
- Harf ile başlama kontrolü
- Benzersizlik kontrolü

### 4. Otomatik Düzeltme
- Büyük harfler otomatik küçük harfe çevrilir
- Boşluklar otomatik temizlenir

### 5. Arkadaş Arama
- Kullanıcılar hem invite code hem username ile aranabilir
- `@username` formatı desteklenir
- Otomatik format algılama

## Kullanım Senaryoları

### Profil Oluşturma
1. Kullanıcı adını girer
2. Sistem otomatik olarak küçük harfe çevirir
3. Format validasyonu yapılır
4. 0.5 saniye sonra benzersizlik kontrolü yapılır
5. Kullanılabilirse yeşil ✓ gösterilir
6. Kaydet butonu aktif olur

### Profil Düzenleme
1. Mevcut username otomatik yüklenir
2. Değişiklik yapılmazsa "Mevcut kullanıcı adın" mesajı gösterilir
3. Değişiklik yapılırsa yeni username kontrol edilir
4. Kendi username'i hariç benzersizlik kontrolü yapılır

### Arkadaş Ekleme
1. Kullanıcı kod veya username girebilir
2. `@username` formatı otomatik algılanır
3. 6 karakterlik alfanumerik kod invite code olarak algılanır
4. Diğer durumlarda önce username, sonra invite code aranır

## Teknik Detaylar

### CloudKitManager Fonksiyonları

```swift
// Username benzersizlik kontrolü
checkUsernameAvailability(_ username: String, excludingCurrentUser: Bool, completion)

// Username validasyonu
validateUsername(_ username: String) -> (isValid: Bool, error: String?)

// Username ile kullanıcı arama
findUserByUsername(_ username: String, completion)

// Kod veya username ile arama
findUserByCodeOrUsername(_ searchText: String, completion)

// Profil güncelleme (username dahil)
updateUserProfile(displayName: String, avatarColor: String, username: String?, completion)
```

### ProfileView State'leri

```swift
@State private var username: String = ""
@State private var usernameValidationMessage: String?
@State private var isUsernameAvailable: Bool?
@State private var isCheckingUsername = false
@State private var usernameCheckTask: Task<Void, Never>?
```

## Değişiklik Yapılan Dosyalar

1. `one/one/CloudKitManager.swift`
   - `checkUsernameAvailability()` eklendi
   - `validateUsername()` eklendi
   - `findUserByUsername()` eklendi
   - `findUserByCodeOrUsername()` eklendi
   - `updateUserProfile()` güncellendi (username parametresi eklendi)

2. `one/one/ProfileView.swift`
   - Username input alanı eklendi
   - Gerçek zamanlı validasyon ve kontrol
   - Görsel geri bildirim (yeşil/kırmızı border, checkmark/xmark)
   - Debounce ile optimizasyon

3. `one/one/SettingsView.swift`
   - Username gösterimi eklendi
   - Profil kartında `@username` formatında gösterim

## Test Adımları

1. **Yeni Profil Oluşturma**
   - Uygulamayı ilk kez aç
   - İsim ve username gir
   - Username'in benzersiz olduğunu kontrol et
   - Profili kaydet

2. **Username Validasyonu**
   - 2 karakterlik username dene (hata vermeli)
   - Boşluk içeren username dene (hata vermeli)
   - Rakam ile başlayan username dene (hata vermeli)
   - Geçerli username dene (yeşil ✓ göstermeli)

3. **Benzersizlik Kontrolü**
   - Var olan bir username dene (kırmızı X göstermeli)
   - Yeni bir username dene (yeşil ✓ göstermeli)

4. **Profil Düzenleme**
   - Ayarlar > Profil'e git
   - Mevcut username gösterilmeli
   - Username değiştir
   - Kaydet

5. **Arkadaş Arama**
   - Arkadaş Ekle'ye git
   - `@username` formatında ara
   - Invite code ile ara
   - Her iki yöntemle de bulabilmeli

## Notlar

- Username CloudKit'te `String` olarak saklanır
- Tüm username'ler küçük harfe çevrilir (case-insensitive)
- Benzersizlik kontrolü PUBLIC database'de yapılır
- Index olmadan query çalışmaz, mutlaka index ekleyin
- Schema değişikliği Production'a deploy edilmeli
