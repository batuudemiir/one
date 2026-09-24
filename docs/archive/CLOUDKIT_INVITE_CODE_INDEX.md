# CloudKit Invite Code Index Setup

## Problem
"Can't query system types" hatası alınıyor. Bu hata mesajı yanıltıcı - gerçek sorun `inviteCode` field'ının queryable olmaması olabilir.

## Çözüm

### 1. CloudKit Dashboard'a Git
https://icloud.developer.apple.com/dashboard

### 2. Container Seç
- `iCloud.com.batu.ones` container'ını seç
- Development veya Production environment'ı seç

### 3. Users Record Type'ını Kontrol Et

#### Schema > Record Types > Users
Aşağıdaki field'ların olduğundan emin ol:

| Field Name | Type | Queryable | Sortable |
|------------|------|-----------|----------|
| userID | String | ✅ Yes | No |
| displayName | String | No | No |
| inviteCode | String | ✅ Yes | No |
| avatarColor | String | No | No |
| isPublic | Int(64) | No | No |
| createdDate | Date/Time | No | No |

### 4. inviteCode Field'ını Queryable Yap

1. `Users` record type'ına tıkla
2. `inviteCode` field'ını bul
3. Field'a tıkla ve "Edit" seç
4. "Queryable" checkbox'ını işaretle
5. "Save" butonuna tıkla

### 5. Index Oluştur (Opsiyonel ama Önerilen)

Schema > Indexes > Add Index

- Record Type: `Users`
- Field Name: `inviteCode`
- Index Type: `QUERYABLE`

### 6. Schema'yı Deploy Et

Development'ta test ettikten sonra:

1. Deployment > Deploy Schema Changes
2. Production'a deploy et
3. Değişikliklerin yayınlanmasını bekle (birkaç dakika sürebilir)

## Test

Uygulamayı yeniden çalıştır ve yeni bir kullanıcı oluştur. Log'larda şu mesajları görmeli:

```
🔍 Searching for user with invite code: ABC123
ℹ️ No user found with code: ABC123 (this is normal when checking uniqueness)
Creating user with code: ABC123
✅ User created successfully with code: ABC123
```

## Not

Mevcut log'lara göre kullanıcı başarıyla oluşturulmuş:
- Invite Code: KBP398
- Display Name: ONE User
- User ID: _3c4752c1f1c80b686a4f90cbc8c1e046

Hata mesajı sadece uniqueness check sırasında çıkıyor ve işlem başarıyla tamamlanıyor.
