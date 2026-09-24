# TestFlight CloudKit Environment Sorunu

## Sorun
TestFlight'ta arkadaş eklerken "Kullanıcı bulunamadı" hatası alınıyor.

## Neden?
CloudKit iki farklı environment kullanır:
- **Development**: Xcode'dan çalıştırırken kullanılır
- **Production**: TestFlight ve App Store'da kullanılır

Her environment'ın kendi veritabanı vardır ve birbirleriyle senkronize olmazlar.

## Çözüm

### Seçenek 1: Her İki Kullanıcı da TestFlight Kullanmalı
En basit çözüm: Her iki kullanıcı da TestFlight versiyonunu kullanmalı.

1. Her iki kullanıcı da TestFlight'tan uygulamayı indirsin
2. Her iki kullanıcı da uygulamayı açıp iCloud'a giriş yapsın
3. Her iki kullanıcı da bir şarkı seçsin (bu kullanıcı kaydını oluşturur)
4. Davet kodlarını paylaşıp arkadaş ekleyin

### Seçenek 2: Her İki Kullanıcı da Development Kullanmalı
Geliştirme aşamasında:

1. Her iki kullanıcı da Xcode'dan uygulamayı çalıştırmalı
2. Aynı adımları takip edin

### Seçenek 3: Production Environment'ı Aktif Edin (Önerilen)

CloudKit Dashboard'da Production environment'ı aktif etmek gerekiyor:

1. [CloudKit Dashboard](https://icloud.developer.apple.com/dashboard)'a gidin
2. `iCloud.com.batu.ones` container'ını seçin
3. **Deployment** sekmesine gidin
4. Development'taki schema'yı Production'a deploy edin:
   - **Schema** > **Deploy to Production**
   - Tüm record type'ları (Users, DailyShare, FriendRequest) seçin
   - Deploy'u onaylayın

## Debug Adımları

### 1. Kullanıcı Kaydını Kontrol Edin
Her iki kullanıcı da:
1. Uygulamayı açın
2. Çevre sekmesine gidin
3. Sağ üstteki "+" butonuna tıklayın
4. "Senin Kodun" bölümünde 6 haneli kodu görmelisiniz

Eğer kod görünmüyorsa:
- iCloud hesabınızı kontrol edin
- Uygulamayı kapatıp tekrar açın
- Bir şarkı seçmeyi deneyin (bu kullanıcı kaydını tetikler)

### 2. Console Loglarını Kontrol Edin
Xcode'da Console'u açın ve şu logları arayın:

```
🔍 Searching for user with invite code: ABC123
📊 Found 0 user(s) with code ABC123
❌ No user found with code: ABC123
💡 Tip: Make sure both users are using the same app version
```

### 3. CloudKit Dashboard'da Kontrol Edin
1. [CloudKit Dashboard](https://icloud.developer.apple.com/dashboard)'a gidin
2. Container: `iCloud.com.batu.ones`
3. **Data** > **Public Database**
4. **Users** record type'ını seçin
5. Kullanıcıların kayıtlı olup olmadığını kontrol edin

## Geçici Çözüm (Development için)

Eğer hızlıca test etmek istiyorsanız:

1. Her iki cihazda da uygulamayı Xcode'dan çalıştırın
2. Veya her iki cihazda da TestFlight kullanın
3. Karışık kullanmayın (biri Xcode, diğeri TestFlight)

## Production'a Geçiş Checklist

TestFlight ve App Store için hazır olmak için:

- [ ] CloudKit Dashboard'da Production environment aktif
- [ ] Development schema Production'a deploy edildi
- [ ] TestFlight'ta test edildi
- [ ] En az 2 kullanıcı ile arkadaş ekleme test edildi
- [ ] Günlük paylaşım test edildi
- [ ] Arkadaş listesi görüntüleme test edildi

## Notlar

- Development ve Production environment'ları tamamen ayrıdır
- Bir environment'taki veriler diğerine aktarılamaz
- TestFlight her zaman Production environment kullanır
- Xcode her zaman Development environment kullanır
- App Store Production environment kullanır

## İletişim

Sorun devam ederse:
1. Console loglarını kontrol edin
2. CloudKit Dashboard'da kullanıcı kayıtlarını kontrol edin
3. Her iki kullanıcının da aynı versiyonu kullandığından emin olun
