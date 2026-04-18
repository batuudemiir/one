# CloudKit Production Deployment Rehberi

## Sorun
TestFlight'ta "Error saving record in record users in production scheme" hatası alıyorsunuz.

## Neden?
CloudKit'te iki environment var:
- **Development**: Xcode'dan çalıştırırken kullanılır, schema otomatik oluşturulur
- **Production**: TestFlight ve App Store'da kullanılır, schema manuel deploy edilmelidir

TestFlight Production environment kullanır ama schema henüz deploy edilmemiş.

## Çözüm: Schema'yı Production'a Deploy Edin

### Adım 1: CloudKit Dashboard'a Gidin
1. [CloudKit Dashboard](https://icloud.developer.apple.com/dashboard) adresine gidin
2. Apple Developer hesabınızla giriş yapın
3. Container'ınızı seçin: `iCloud.com.batu.ones`

### Adım 2: Development Schema'sını Kontrol Edin
1. Sol menüden **Schema** sekmesine tıklayın
2. Üstteki environment seçiciden **Development** seçin
3. Şu record type'ların olduğundan emin olun:
   - **Users** (userID, displayName, inviteCode, avatarColor, isPublic, createdDate)
   - **DailyShare** (userID, date, songName, artistName, genre, moodWord, moodColor, vb.)
   - **FriendRequest** (fromUserID, toUserID, status, createdDate)

### Adım 3: Schema'yı Production'a Deploy Edin

#### 3.1. Deployment Sayfasına Gidin
1. Sol menüden **Deployment** sekmesine tıklayın
2. **Deploy Schema Changes** butonuna tıklayın

#### 3.2. Deploy Edilecek Değişiklikleri Seçin
1. Tüm record type'ları seçin:
   - ☑️ Users
   - ☑️ DailyShare
   - ☑️ FriendRequest
2. Tüm field'ları ve index'leri seçin
3. **Deploy to Production** butonuna tıklayın

#### 3.3. Onaylayın
1. Uyarı mesajını okuyun
2. "I understand" checkbox'ını işaretleyin
3. **Deploy** butonuna tıklayın

### Adım 4: Deployment'ı Doğrulayın
1. Deployment tamamlanana kadar bekleyin (birkaç dakika sürebilir)
2. **Schema** sekmesine geri dönün
3. Environment seçiciden **Production** seçin
4. Record type'ların Production'da da göründüğünü kontrol edin

### Adım 5: Uygulamayı Test Edin
1. TestFlight'tan uygulamayı açın
2. Ayarlar > Profil'e gidin
3. İsim ve renk seçip kaydedin
4. Artık hata almamalısınız!

## Önemli Notlar

### Production Deployment Kuralları
- ⚠️ Production'a deploy edilen schema geri alınamaz
- ⚠️ Mevcut field'ları silemezsiniz (sadece yeni ekleyebilirsiniz)
- ⚠️ Field type'larını değiştiremezsiniz
- ✅ Yeni field'lar ekleyebilirsiniz
- ✅ Index'ler ekleyebilir/silebilirsiniz

### İlk Deployment Checklist
Deployment yapmadan önce kontrol edin:
- [ ] Tüm record type'lar Development'ta test edildi
- [ ] Field isimleri doğru (typo yok)
- [ ] Field type'ları doğru (String, Int64, Date, vb.)
- [ ] Gerekli index'ler eklendi
- [ ] Security roles ayarlandı (Public Read/Write)

### Deployment Sonrası
- Development'ta yeni field eklerseniz, Production'a tekrar deploy etmelisiniz
- Her major değişiklik için yeni deployment gerekir
- Minor değişiklikler (index ekleme/silme) daha kolay deploy edilir

## Alternatif: Development Environment Kullanın (Geçici)

Eğer hemen Production'a deploy edemiyorsanız, geçici olarak Development environment kullanabilirsiniz:

### Xcode'da Development Environment Zorla
```swift
// CloudKitManager.swift içinde
private init() {
    #if DEBUG
    container = CKContainer(identifier: "iCloud.com.batu.ones")
    #else
    // Force development environment for testing
    let config = CKContainer.Options()
    config.useZoneWideSharingForDevelopment = true
    container = CKContainer(identifier: "iCloud.com.batu.ones")
    #endif
    
    privateDatabase = container.privateCloudDatabase
    publicDatabase = container.publicCloudDatabase
    
    checkCloudKitAvailability()
}
```

⚠️ **DİKKAT**: Bu sadece test içindir, production'da kullanmayın!

## Sık Karşılaşılan Hatalar

### "Unknown item" Hatası
- **Neden**: Field Production'da yok
- **Çözüm**: Schema'yı deploy edin

### "Permission Failure" Hatası
- **Neden**: Security roles yanlış ayarlanmış
- **Çözüm**: CloudKit Dashboard > Security Roles > Public Read/Write

### "Zone Not Found" Hatası
- **Neden**: Custom zone kullanılıyor ama Production'da yok
- **Çözüm**: Default zone kullanın veya custom zone'u deploy edin

## Yardım

Sorun devam ederse:
1. Console loglarını kontrol edin (detaylı hata mesajları var)
2. CloudKit Dashboard'da Production schema'sını kontrol edin
3. TestFlight'tan uygulamayı sil ve yeniden yükle
4. iCloud hesabınızdan çıkıp tekrar girin

## Kaynaklar
- [CloudKit Dashboard](https://icloud.developer.apple.com/dashboard)
- [Apple CloudKit Documentation](https://developer.apple.com/documentation/cloudkit)
- [CloudKit Best Practices](https://developer.apple.com/videos/play/wwdc2021/10086/)
