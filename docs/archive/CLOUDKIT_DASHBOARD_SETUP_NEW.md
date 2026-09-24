# ☁️ CloudKit Dashboard Schema Kurulum Rehberi (2025 Yeni Arayüz)

## Giriş

CloudKit Dashboard'ın yeni arayüzünde Record Type'ları ve Index'leri ayrı ayrı oluşturacağız.

## Adım 1: Dashboard'a Giriş

### 1.1 Web Tarayıcıda Aç

```
https://icloud.developer.apple.com/dashboard
```

### 1.2 Giriş Yap

- Apple Developer hesabınızla giriş yapın
- Container'ınızı seçin: **iCloud.com.batu.one**

### 1.3 Development Environment

- Sol üstte **Development** seçili olmalı
- İlk önce Development'ta test edeceğiz
- Sonra Production'a deploy edeceğiz

## Adım 2: Record Types Oluşturma

### 2.1 Schema Sekmesi

1. Sol menüden **Schema** → **Record Types** tıkla
2. **Add Record Type** (+) butonuna tıkla

---

## BÖLÜM 1: User Record Type

### 2.2 User Record Type Oluştur

```
Record Type Name: Users
```

**Create** veya **Add** butonuna tıkla

### 2.3 Field'ları Ekle

User record type'ı seçili iken, **Add Field** butonuna tıkla:

#### Field 1: userID
```
Field Name: userID
Type: String
```
**Add** tıkla

#### Field 2: displayName
```
Field Name: displayName
Type: String
```
**Add** tıkla

#### Field 3: inviteCode
```
Field Name: inviteCode
Type: String
```
**Add** tıkla

#### Field 4: avatarColor
```
Field Name: avatarColor
Type: String
```
**Add** tıkla

#### Field 5: isPublic
```
Field Name: isPublic
Type: Int(64)
```
**Add** tıkla

#### Field 6: createdDate
```
Field Name: createdDate
Type: Date/Time
```
**Add** tıkla

### 2.4 User Record Type Tamamlandı ✅

Şimdi Users record type'ında 6 field olmalı.

---

## BÖLÜM 2: Friendship Record Type

### 3.1 Yeni Record Type

1. **Record Types** bölümünde **Add Record Type** (+) tıkla
2. Record Type Name: **Friendship**
3. **Create** tıkla

### 3.2 Field'ları Ekle

#### Field 1: friendshipID
```
Field Name: friendshipID
Type: String
```
**Add** tıkla

#### Field 2: user1ID
```
Field Name: user1ID
Type: String
```
**Add** tıkla

#### Field 3: user2ID
```
Field Name: user2ID
Type: String
```
**Add** tıkla

#### Field 4: status
```
Field Name: status
Type: String
```
**Add** tıkla

#### Field 5: createdDate
```
Field Name: createdDate
Type: Date/Time
```
**Add** tıkla

#### Field 6: acceptedDate
```
Field Name: acceptedDate
Type: Date/Time
```
**Add** tıkla

### 3.3 Friendship Record Type Tamamlandı ✅

Şimdi Friendship record type'ında 6 field olmalı.

---

## BÖLÜM 3: DailyShare Record Type

### 4.1 Yeni Record Type

1. **Record Types** bölümünde **Add Record Type** (+) tıkla
2. Record Type Name: **DailyShare**
3. **Create** tıkla

### 4.2 Field'ları Ekle (15 field)

#### Field 1: shareID
```
Field Name: shareID
Type: String
```

#### Field 2: userID
```
Field Name: userID
Type: String
```

#### Field 3: date
```
Field Name: date
Type: Date/Time
```

#### Field 4: songName
```
Field Name: songName
Type: String
```

#### Field 5: artistName
```
Field Name: artistName
Type: String
```

#### Field 6: genre
```
Field Name: genre
Type: String
```

#### Field 7: emoji
```
Field Name: emoji
Type: String
```

#### Field 8: albumArtURL
```
Field Name: albumArtURL
Type: String
```

#### Field 9: moodWord
```
Field Name: moodWord
Type: String
```

#### Field 10: moodColor
```
Field Name: moodColor
Type: String
```

#### Field 11: moodTheme
```
Field Name: moodTheme
Type: String
```

#### Field 12: dailyNote
```
Field Name: dailyNote
Type: String
```

#### Field 13: platform
```
Field Name: platform
Type: String
```

#### Field 14: isPublic
```
Field Name: isPublic
Type: Int(64)
```

#### Field 15: createdAt
```
Field Name: createdAt
Type: Date/Time
```

Her field için **Add** butonuna tıklayın.

### 4.3 DailyShare Record Type Tamamlandı ✅

Şimdi DailyShare record type'ında 15 field olmalı.

---

## Adım 3: Indexes Oluşturma (ÖNEMLİ!)

Yeni arayüzde indexler ayrı bir bölümde oluşturuluyor.

### 3.1 Indexes Sekmesine Git

1. Sol menüden **Schema** → **Indexes** tıkla
2. **Add Index** (+) butonuna tıkla

### 3.2 Users Record Type İçin Indexler

#### Index 1: userID (Queryable)

**Add Index** dialog'unda:
```
Record Type: Users (dropdown'dan seç)
Name: userID
Type: QUERYABLE (dropdown'dan seç)
Field: userID (dropdown'dan seç)
```
**Add** butonuna tıkla

#### Index 2: inviteCode (Queryable)

**Add Index** tıkla:
```
Record Type: Users
Name: inviteCode
Type: QUERYABLE (dropdown'dan seç)
Field: inviteCode
```
**Add** butonuna tıkla

**Not:** UNIQUE seçeneği yeni arayüzde yok. Uniqueness kontrolünü kod tarafında yapacağız.

### 3.3 Friendship Record Type İçin Indexler

#### Index 3: user1ID (Queryable)

**Add Index** tıkla:
```
Record Type: Friendship
Name: user1ID
Type: QUERYABLE
Field: user1ID
```
**Add** butonuna tıkla

#### Index 4: user2ID (Queryable)

**Add Index** tıkla:
```
Record Type: Friendship
Name: user2ID
Type: QUERYABLE
Field: user2ID
```
**Add** butonuna tıkla

#### Index 5: status (Queryable)

**Add Index** tıkla:
```
Record Type: Friendship
Name: status
Type: QUERYABLE
Field: status
```
**Add** butonuna tıkla

### 3.4 DailyShare Record Type İçin Indexler

#### Index 6: userID (Queryable)

**Add Index** tıkla:
```
Record Type: DailyShare
Name: userID
Type: QUERYABLE
Field: userID
```
**Add** butonuna tıkla

#### Index 7: date (Queryable)

**Add Index** tıkla:
```
Record Type: DailyShare
Name: date
Type: QUERYABLE
Field: date
```
**Add** butonuna tıkla

#### Index 8: isPublic (Queryable)

**Add Index** tıkla:
```
Record Type: DailyShare
Name: isPublic
Type: QUERYABLE
Field: isPublic
```
**Add** butonuna tıkla

#### Index 9: createdAt (Queryable)

**Add Index** tıkla:
```
Record Type: DailyShare
Name: createdAt
Type: QUERYABLE
Field: createdAt
```
**Add** butonuna tıkla

### 3.5 Index Türleri

CloudKit Dashboard'da 3 index türü var:

- **QUERYABLE**: Arama yapılabilir (en yaygın) ✅
- **SORTABLE**: Sıralanabilir (tarih/sayı field'ları için)
- **SEARCHABLE**: Tam metin araması (text field'ları için)

**Not:** UNIQUE seçeneği yeni arayüzde kaldırılmış. Uniqueness kontrolü kod tarafında yapılmalı.

## Adım 4: Schema'yı Kaydet

1. Tüm değişiklikler otomatik kaydedilir
2. Veya sağ üstte **Save** butonu varsa tıkla
3. Development environment'ta artık kullanıma hazır

## Adım 5: Özet Kontrol

### Record Types (3 adet)
- ✅ Users (6 field)
- ✅ Friendship (6 field)
- ✅ DailyShare (15 field)

### Indexes (9 adet)
- ✅ Users.userID (QUERYABLE)
- ✅ Users.inviteCode (QUERYABLE)
- ✅ Friendship.user1ID (QUERYABLE)
- ✅ Friendship.user2ID (QUERYABLE)
- ✅ Friendship.status (QUERYABLE)
- ✅ DailyShare.userID (QUERYABLE)
- ✅ DailyShare.date (QUERYABLE)
- ✅ DailyShare.isPublic (QUERYABLE)
- ✅ DailyShare.createdAt (QUERYABLE)

## Adım 6: İlk Test (Development)

### 6.1 Xcode'da Test

1. Xcode'da projeyi çalıştır (⌘R)
2. Simulator'da iCloud'a giriş yap
3. Çevre sekmesine git
4. "Arkadaş Ekle" butonuna tıkla

### 6.2 Dashboard'da Kontrol

1. CloudKit Dashboard'a dön
2. **Data** → **Records** sekmesine tıkla
3. **Users** record type'ını seç
4. Eğer uygulama çalıştıysa, bir User kaydı göreceksin

## Adım 7: Production'a Deploy (Sonra)

⚠️ **ÖNEMLİ:** Production'a deploy etmeden önce Development'ta iyice test edin!

### 7.1 Ne Zaman Deploy Edilmeli?

- Tüm testler başarılı
- Schema değişiklikleri kesinleşti
- Beta test tamamlandı
- App Store'a göndermeye hazırsınız

### 7.2 Deploy İşlemi

1. Dashboard'da sağ üstte **Deploy Schema Changes** butonu
2. **Deploy to Production** seç
3. Değişiklikleri gözden geçir
4. **Deploy** tıkla

⚠️ **UYARI:** Production'a deploy edildikten sonra:
- Field silemezsiniz
- Field type değiştiremezsiniz
- Index silemezsiniz
- Sadece yeni field/index ekleyebilirsiniz

## Sorun Giderme

### "This field is required" Hatası

**Çözüm:**
- Add Index dialog'unda tüm alanları doldurduğunuzdan emin olun
- Record Type seçili mi?
- Field seçili mi?
- Type seçili mi?

### Index Eklenmiyor

**Çözüm:**
- Sayfayı yenile (F5)
- Farklı tarayıcı dene (Safari önerilir)
- Cache temizle
- Birkaç saniye bekle, otomatik kaydediliyor olabilir

### Record Type Görünmüyor

**Çözüm:**
- Development environment seçili mi?
- Sayfayı yenileyin
- Container doğru mu? (iCloud.com.batu.one)

### Field Eklerken Hata

**Çözüm:**
- Field name benzersiz olmalı
- Type seçilmeli
- Özel karakterler kullanmayın

## Özet Checklist

Schema kurulumu tamamlandığında:

- [x] Users record type oluşturuldu (6 field)
- [x] Friendship record type oluşturuldu (6 field)
- [x] DailyShare record type oluşturuldu (15 field)
- [x] 9 index oluşturuldu (Indexes sekmesinde)
- [x] inviteCode UNIQUE olarak işaretlendi
- [x] Schema kaydedildi
- [x] Development'ta test edildi

## Sonraki Adım

Artık kod yazmaya hazırsınız!

👉 [CIRCLE_QUICK_START.md](./CIRCLE_QUICK_START.md) - Hızlı başlangıç rehberi

## Yardımcı Linkler

- [CloudKit Dashboard](https://icloud.developer.apple.com/dashboard)
- [CloudKit Documentation](https://developer.apple.com/documentation/cloudkit)
- [Index Best Practices](https://developer.apple.com/library/archive/documentation/DataManagement/Conceptual/CloudKitQuickStart/DesigningYourCloudKitDatabase/DesigningYourCloudKitDatabase.html)

## Notlar

- Yeni arayüzde indexler **ayrı bir sekmede** oluşturuluyor
- Field eklerken index seçeneği YOK
- Önce tüm field'ları ekle, sonra Indexes sekmesinden indexleri oluştur
- Her index için ayrı "Add Index" yapılmalı
- UNIQUE index otomatik olarak QUERYABLE'dır


---

## ⚠️ Önemli Not: UNIQUE Index

CloudKit Dashboard'ın yeni arayüzünde **UNIQUE** index seçeneği kaldırılmış.

### Çözüm

inviteCode için uniqueness kontrolü **kod tarafında** yapılıyor:

```swift
// CloudKitManager.swift içinde
private func isInviteCodeUnique(_ code: String, completion: @escaping (Bool) -> Void) {
    findUserByInviteCode(code) { result in
        switch result {
        case .success:
            completion(false) // Code exists
        case .failure:
            completion(true)  // Code is unique
        }
    }
}
```

### Nasıl Çalışıyor?

1. Yeni kullanıcı oluşturulurken davet kodu üretilir
2. Kod CloudKit'te aranır
3. Eğer bulunursa, yeni kod üretilir (max 5 deneme)
4. Benzersiz kod bulunana kadar tekrar eder

Bu yaklaşım:
- ✅ Güvenli (çakışma olmaz)
- ✅ Otomatik (kullanıcı müdahalesi gerektirmez)
- ✅ Performanslı (nadiren tekrar eder)

### Index Ayarları

inviteCode için sadece **QUERYABLE** index yeterli:
```
Record Type: Users
Name: inviteCode
Type: QUERYABLE
Field: inviteCode
```

Bu sayede kod arama yapılabilir ve uniqueness kontrolü çalışır.
