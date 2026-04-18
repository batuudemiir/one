# ☁️ CloudKit Dashboard Schema Kurulum Rehberi

## Giriş

CloudKit Dashboard'da Record Type'ları ve field'ları manuel olarak oluşturacağız.

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

## Adım 2: User Record Type Oluşturma

### 2.1 Schema Sekmesi

1. Sol menüden **Schema** sekmesine tıkla
2. **Record Types** bölümünü bul
3. **+** (Add Record Type) butonuna tıkla

### 2.2 Record Type İsmi

```
Record Type Name: User
```

**Create** butonuna tıkla

### 2.3 Field'ları Ekle

User record type'ı seçili iken, **Add Field** butonuna tıkla:

#### Field 1: userID
```
Field Name: userID
Type: String
```

Field eklerken veya sonrasında:
- **Index** seçeneğini bul
- **Queryable** seç (dropdown'dan)
- **Add** veya **Save** tıkla

#### Field 2: displayName
```
Field Name: displayName
Type: String
Index: None (varsayılan)
```
**Add** tıkla

#### Field 3: inviteCode
```
Field Name: inviteCode
Type: String
Index: Unique (önemli!)
```

**Not:** Unique seçeneği, her davet kodunun benzersiz olmasını sağlar.

**Add** tıkla

#### Field 4: avatarColor
```
Field Name: avatarColor
Type: String
Index: None
```
**Add** tıkla

#### Field 5: isPublic
```
Field Name: isPublic
Type: Int(64)
Index: None
```
**Add** tıkla

#### Field 6: createdDate
```
Field Name: createdDate
Type: Date/Time
Index: None
```
**Add** tıkla

### 2.4 User Record Type Tamamlandı

Şimdi User record type'ında 6 field olmalı:
- userID (String, Index: Queryable)
- displayName (String, Index: None)
- inviteCode (String, Index: Unique)
- avatarColor (String, Index: None)
- isPublic (Int64, Index: None)
- createdDate (Date/Time, Index: None)

**Not:** Index ayarları field oluştururken veya sonradan düzenleyerek yapılabilir.

## Adım 3: Friendship Record Type Oluşturma

### 3.1 Yeni Record Type

1. **Record Types** bölümünde **+** tıkla
2. Record Type Name: **Friendship**
3. **Create** tıkla

### 3.2 Field'ları Ekle

#### Field 1: friendshipID
```
Field Name: friendshipID
Type: String
Index: None
```
**Add** tıkla

#### Field 2: user1ID
```
Field Name: user1ID
Type: String
Index: Queryable
```
**Add** tıkla

#### Field 3: user2ID
```
Field Name: user2ID
Type: String
Index: Queryable
```
**Add** tıkla

#### Field 4: status
```
Field Name: status
Type: String
Index: Queryable
```
**Add** tıkla

#### Field 5: createdDate
```
Field Name: createdDate
Type: Date/Time
Index: None
```
**Add** tıkla

#### Field 6: acceptedDate
```
Field Name: acceptedDate
Type: Date/Time
Index: None
```
**Add** tıkla

### 3.3 Friendship Record Type Tamamlandı

Şimdi Friendship record type'ında 6 field olmalı:
- friendshipID (String, Index: None)
- user1ID (String, Index: Queryable)
- user2ID (String, Index: Queryable)
- status (String, Index: Queryable)
- createdDate (Date/Time, Index: None)
- acceptedDate (Date/Time, Index: None)

## Adım 4: DailyShare Record Type Oluşturma

### 4.1 Yeni Record Type

1. **Record Types** bölümünde **+** tıkla
2. Record Type Name: **DailyShare**
3. **Create** tıkla

### 4.2 Field'ları Ekle (14 field)

#### Field 1: shareID
```
Field Name: shareID
Type: String
Index: None
```
**Add** tıkla

#### Field 2: userID
```
Field Name: userID
Type: String
Index: Queryable
```
**Add** tıkla

#### Field 3: date
```
Field Name: date
Type: Date/Time
Index: Queryable
```
**Add** tıkla

#### Field 4: songName
```
Field Name: songName
Type: String
```
**Add** tıkla

#### Field 5: artistName
```
Field Name: artistName
Type: String
```
**Add** tıkla

#### Field 6: genre
```
Field Name: genre
Type: String
```
**Add** tıkla

#### Field 7: emoji
```
Field Name: emoji
Type: String
```
**Add** tıkla

#### Field 8: albumArtURL
```
Field Name: albumArtURL
Type: String
```
**Add** tıkla

#### Field 9: moodWord
```
Field Name: moodWord
Type: String
```
**Add** tıkla

#### Field 10: moodColor
```
Field Name: moodColor
Type: String
```
**Add** tıkla

#### Field 11: moodTheme
```
Field Name: moodTheme
Type: String
```
**Add** tıkla

#### Field 12: dailyNote
```
Field Name: dailyNote
Type: String
```
**Add** tıkla

#### Field 13: platform
```
Field Name: platform
Type: String
```
**Add** tıkla

#### Field 14: isPublic
```
Field Name: isPublic
Type: Int(64)
Index: Queryable
```
**Add** tıkla

#### Field 15: createdAt
```
Field Name: createdAt
Type: Date/Time
Index: Queryable
```
**Add** tıkla

### 4.3 DailyShare Record Type Tamamlandı

Şimdi DailyShare record type'ında 15 field olmalı:
- shareID (String, Index: None)
- userID (String, Index: Queryable)
- date (Date/Time, Index: Queryable)
- songName (String, Index: None)
- artistName (String, Index: None)
- genre (String, Index: None)
- emoji (String, Index: None)
- albumArtURL (String, Index: None)
- moodWord (String, Index: None)
- moodColor (String, Index: None)
- moodTheme (String, Index: None)
- dailyNote (String, Index: None)
- platform (String, Index: None)
- isPublic (Int64, Index: Queryable)
- createdAt (Date/Time, Index: Queryable)

## Adım 5: Security Roles (Opsiyonel)

### 5.1 Security Sekmesi

1. Sol menüden **Security Roles** sekmesine tıkla
2. Her record type için varsayılan güvenlik ayarları:

```
World: No Access
Authenticated: Read Own, Write Own
Creator: Full Access
```

Bu ayarlar bizim için uygun, değiştirmeye gerek yok.

## Adım 6: Index Ayarları Özeti

CloudKit Dashboard'da field eklerken **Index** seçenekleri:

### Index Türleri
- **None**: Index yok (varsayılan)
- **Queryable**: Arama yapılabilir
- **Unique**: Benzersiz değer (otomatik queryable)
- **Sortable**: Sıralanabilir (eski arayüzde, yeni arayüzde queryable yeterli)

### Bizim Kullandığımız Indexler

**User:**
- userID → Queryable
- inviteCode → Unique (önemli!)

**Friendship:**
- user1ID → Queryable
- user2ID → Queryable
- status → Queryable

**DailyShare:**
- userID → Queryable
- date → Queryable
- isPublic → Queryable
- createdAt → Queryable

**Not:** Index ayarları field oluştururken veya sonradan düzenleyerek yapılabilir. Field'a tıklayıp "Edit" seçeneğinden Index değiştirilebilir.

## Adım 7: Schema'yı Kaydet

1. Sağ üstte **Save** butonuna tıkla
2. Değişiklikler kaydedilecek
3. Development environment'ta artık kullanıma hazır

## Adım 8: İlk Test (Development)

### 8.1 Xcode'da Test

1. Xcode'da projeyi çalıştır
2. Simulator'da iCloud'a giriş yap
3. Çevre sekmesine git
4. "Arkadaş Ekle" butonuna tıkla

### 8.2 Dashboard'da Kontrol

1. CloudKit Dashboard'a dön
2. **Data** sekmesine tıkla
3. **User** record type'ını seç
4. Eğer uygulama çalıştıysa, bir User kaydı göreceksin

## Adım 9: Production'a Deploy (Sonra)

⚠️ **ÖNEMLİ:** Production'a deploy etmeden önce Development'ta iyice test edin!

### 9.1 Ne Zaman Deploy Edilmeli?

- Tüm testler başarılı
- Schema değişiklikleri kesinleşti
- Beta test tamamlandı
- App Store'a göndermeye hazırsınız

### 9.2 Deploy İşlemi

1. Dashboard'da sağ üstte **Deploy Schema Changes** butonu
2. **Deploy to Production** seç
3. Değişiklikleri gözden geçir
4. **Deploy** tıkla

⚠️ **UYARI:** Production'a deploy edildikten sonra:
- Field silemezsiniz
- Field type değiştiremezsiniz
- Sadece yeni field ekleyebilirsiniz

## Özet Checklist

Schema kurulumu tamamlandığında:

- [x] User record type oluşturuldu (6 field)
- [x] Friendship record type oluşturuldu (6 field)
- [x] DailyShare record type oluşturuldu (15 field)
- [x] Queryable field'lar işaretlendi
- [x] Unique constraint eklendi (inviteCode)
- [x] Schema kaydedildi
- [x] Development'ta test edildi

## Sonraki Adım

Artık kod yazmaya hazırsınız!

👉 [CIRCLE_QUICK_START.md](./CIRCLE_QUICK_START.md) - Hızlı başlangıç rehberi

## Sorun Giderme

### Field Eklenmiyor

**Çözüm:**
- Sayfayı yenile (F5)
- Farklı tarayıcı dene (Safari önerilir)
- Cache temizle

### "Schema is locked" Hatası

**Çözüm:**
- Production'da değişiklik yapmaya çalışıyorsunuz
- Development'a geçin
- Veya yeni field ekleyin (silme/değiştirme yapılamaz)

### Record Type Görünmüyor

**Çözüm:**
- Save butonuna bastınız mı?
- Development environment seçili mi?
- Sayfayı yenileyin

## Yardımcı Linkler

- [CloudKit Dashboard](https://icloud.developer.apple.com/dashboard)
- [CloudKit Documentation](https://developer.apple.com/documentation/cloudkit)
- [Schema Design Guide](https://developer.apple.com/library/archive/documentation/DataManagement/Conceptual/CloudKitQuickStart/DesigningYourCloudKitDatabase/DesigningYourCloudKitDatabase.html)
