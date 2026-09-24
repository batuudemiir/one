# Production Schema Deployment - Profil Persist Sorunu Çözümü

## Sorun
- Profil oluşturuluyor ama kaydedilmiyor
- Uygulamadan çıkıp girince tekrar profil oluşturma ekranı geliyor
- Log'da "User created successfully" var ama "hasCreatedProfile flag set to true" yok

## Neden Oluyor?

1. **Gerçek telefon Production ortamına bağlanıyor**
2. **Schema sadece Development'ta var**
3. **Production'da schema olmadığı için:**
   - `updateUserProfile()` başarısız oluyor
   - `hasCreatedProfile` flag'i set edilmiyor
   - Profil persist olmuyor

## Çözüm: Schema'yı Production'a Deploy Et

### Adım 1: CloudKit Dashboard'a Git
https://icloud.developer.apple.com/dashboard

### Adım 2: Container Seç
- `iCloud.com.batu.ones`
- Environment: **Development** (şimdilik)

### Adım 3: Schema'yı Kontrol Et
1. Schema > Record Types > Users
2. Tüm field'ların olduğunu kontrol et:
   - userID (STRING, Queryable)
   - displayName (STRING, Queryable)
   - username (STRING, Queryable)
   - inviteCode (STRING, Queryable)
   - avatarColor (STRING)
   - isPublic (INT64)
   - createdDate (DATE/TIME)

### Adım 4: Indexes Kontrol Et
1. Schema > Indexes
2. Şu index'lerin olduğunu kontrol et:
   - userID - QUERYABLE
   - username - QUERYABLE
   - inviteCode - QUERYABLE

### Adım 5: Production'a Deploy Et
1. Sol menüden **Deployment** sekmesine git
2. **"Deploy Schema Changes..."** butonuna tıkla
3. Source: **Development**
4. Target: **Production**
5. **"Deploy"** butonuna tıkla
6. Değişiklikleri onayla

### Adım 6: Deployment'ı Bekle
- Deployment 5-10 dakika sürebilir
- Status: "Deploying..." → "Deployed"

### Adım 7: Production'da Kontrol Et
1. Environment: **Production** seç
2. Schema > Record Types > Users
3. Tüm field'ların geldiğini kontrol et

### Adım 8: Uygulamayı Test Et
1. Telefondaki uygulamayı sil
2. Xcode'dan yeniden yükle
3. Profil oluştur
4. Uygulamadan çık
5. Tekrar aç
6. **Profil oluşturma ekranı gelmemeli!**

## Beklenen Log Çıktısı (Başarılı)

```
🔵 Saving profile...
   Display Name: Batuhan
   Username: batu
   Avatar Color: #E84040
   Current User exists: false
➕ Creating new user profile
✅ User created successfully with code: RJH856
🎨 Updating avatar color and username
🔄 Updating user profile:
   Display Name: Batuhan
   Avatar Color: #E84040
   Username: batu
✅ User profile updated successfully
✅ Profile updated successfully
✅ hasCreatedProfile flag set to true  ← BU SATIR ÖNEMLİ!
```

## Deployment Sonrası Test

### Test 1: Profil Oluşturma
1. Uygulamayı aç
2. Profil oluştur
3. Log'da "hasCreatedProfile flag set to true" görmeli

### Test 2: Persistence
1. Uygulamayı kapat (swipe up)
2. Tekrar aç
3. Ana ekrana gitmeli (profil oluşturma ekranı gelmemeli)

### Test 3: CloudKit Records
1. CloudKit Dashboard > Production
2. Data > Records > Users
3. Query Records
4. Profilini görmeli

## Önemli Notlar

1. **Development vs Production:**
   - Xcode Simulator: Development
   - Gerçek Cihaz (Xcode'dan): Development (debug mode)
   - Gerçek Cihaz (normal): Production
   - TestFlight: Production
   - App Store: Production

2. **Schema Deployment:**
   - Development'ta test et
   - Production'a deploy et
   - Geri alınamaz (dikkatli ol)

3. **Duplicate Records:**
   - Deployment öncesi oluşan record'lar Production'da olmayacak
   - Bu normal, yeni profil oluştur

## Troubleshooting

### Hala Profil Persist Olmuyor
1. Log'da "hasCreatedProfile flag set to true" var mı?
   - Yoksa: `updateUserProfile()` başarısız oluyor
   - Varsa: `loadCurrentUser()` çalışmıyor

2. CloudKit Dashboard'da record var mı?
   - Yoksa: Save işlemi başarısız
   - Varsa: Load işlemi başarısız

### "Can't query system types" Hatası Devam Ediyor
- Schema Production'a deploy edilmemiş
- 10 dakika bekle, tekrar dene
- Deployment status'ü kontrol et

### Record'lar Görünmüyor
- Environment: Production seçili mi?
- Query Records butonuna tıkladın mı?
- FIELDS dropdown: "All" seçili mi?
