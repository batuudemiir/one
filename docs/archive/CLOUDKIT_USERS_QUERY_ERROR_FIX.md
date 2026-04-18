# CloudKit "Can't query system types" Hatası Çözümü

## Hata Mesajı
```
❌ Failed to load user: Can't query system types
```

## Neden Oluşur?

Bu hata genellikle şu durumlarda oluşur:
1. CloudKit'te "Users" record type'ı henüz oluşturulmamış
2. "Users" record type'ı var ama field'lar queryable olarak işaretlenmemiş
3. Schema Development'ta var ama Production'a deploy edilmemiş
4. Kullanıcı henüz profil oluşturmamış (bu normal bir durum)

## Çözüm Adımları

### 1. CloudKit Dashboard Kontrolü

https://icloud.developer.apple.com/dashboard adresine git:

1. **Container Seçimi**
   - `iCloud.com.batu.ones` container'ını seç
   - Ortam: Development (test için) veya Production

2. **Record Types Kontrolü**
   - Schema > Record Types
   - "Users" record type'ının var olduğunu kontrol et
   - Yoksa oluştur

3. **Users Record Type Field'ları**
   ```
   Field Name       | Type   | Queryable | Sortable
   ----------------|--------|-----------|----------
   userID          | String | ✓         | ✓
   displayName     | String | ✓         | ✓
   username        | String | ✓         | ✓
   inviteCode      | String | ✓         | ✓
   avatarColor     | String | -         | -
   isPublic        | Int64  | ✓         | -
   createdDate     | Date   | ✓         | ✓
   ```

4. **Index Kontrolü**
   - Schema > Indexes
   - Her queryable field için index olmalı:
     - `userID` - QUERYABLE
     - `displayName` - QUERYABLE
     - `username` - QUERYABLE
     - `inviteCode` - QUERYABLE
     - `isPublic` - QUERYABLE
     - `createdDate` - QUERYABLE, SORTABLE

5. **Schema Deployment**
   - Deployment sekmesine git
   - "Deploy Schema Changes" butonuna tıkla
   - Development → Production deploy et

### 2. Kod Tarafında İyileştirme

`loadCurrentUser()` fonksiyonu artık bu hatayı daha iyi handle ediyor:

```swift
case .failure(let error):
    let nsError = error as NSError
    if nsError.domain == CKErrorDomain && nsError.code == 12 {
        print("ℹ️ User profile not found (this is normal for new users)")
    } else {
        print("❌ Failed to load user: \(error.localizedDescription)")
    }
```

### 3. Test Senaryoları

#### Senaryo 1: Yeni Kullanıcı (İlk Açılış)
- Hata: Normal (kullanıcı henüz profil oluşturmamış)
- Beklenen: "ℹ️ User profile not found"
- Aksiyon: Profil oluşturma ekranı gösterilmeli

#### Senaryo 2: Mevcut Kullanıcı
- Hata: Olmamalı
- Beklenen: "✅ Loaded existing user"
- Aksiyon: Ana ekrana geçilmeli

#### Senaryo 3: Schema Hatası
- Hata: "Can't query system types"
- Beklenen: Schema düzeltilmeli
- Aksiyon: Yukarıdaki adımları takip et

## Hata Kodları

CloudKit Error Codes:
- **12**: Invalid Arguments (genellikle query problemi)
- **26**: Schema not deployed to production
- **404**: Record not found (normal durum)

## Debug Checklist

- [ ] CloudKit Dashboard'da "Users" record type var mı?
- [ ] Tüm field'lar doğru type'da mı?
- [ ] userID, username, inviteCode QUERYABLE mı?
- [ ] Index'ler oluşturulmuş mu?
- [ ] Schema Production'a deploy edilmiş mi?
- [ ] iCloud hesabı aktif mi?
- [ ] Container ID doğru mu? (`iCloud.com.batu.ones`)

## Önemli Notlar

1. **"Users" bizim custom record type'ımız**, Apple'ın sistem tipi değil
2. Bu hata yeni kullanıcılar için **normal bir durum**
3. Profil oluşturulduktan sonra hata gitmeli
4. Development ve Production ortamları ayrı schema'lara sahip
5. Schema değişikliklerini mutlaka Production'a deploy et

## İlgili Dosyalar

- `one/one/CloudKitManager.swift` - loadCurrentUser() fonksiyonu
- `one/one/ContentView.swift` - checkProfileStatus() fonksiyonu
- `one/one/ProfileView.swift` - Profil oluşturma ekranı
