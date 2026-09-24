# Production Troubleshooting Rehberi

## Sorun 1: "Böyle Bir Kullanıcı Bulunamadı"

### Olası Nedenler
1. **CloudKit schema Production'a deploy edilmemiş** (En yaygın)
2. Arkadaşın henüz profil oluşturmamış
3. Arkadaşın uygulamayı açmamış
4. Yanlış davet kodu girilmiş

### Çözüm Adımları

#### 1. CloudKit Schema'yı Deploy Edin
Bu **en önemli** adım! TestFlight Production environment kullanır.

```
1. https://icloud.developer.apple.com/dashboard
2. Container: iCloud.com.batu.ones
3. Deployment > Deploy Schema Changes
4. Tüm record type'ları seç (Users, DailyShare, FriendRequest)
5. Deploy to Production
```

Detaylı rehber: `CLOUDKIT_PRODUCTION_DEPLOYMENT.md`

#### 2. Her İki Kullanıcı da Profil Oluşturmalı
```
1. Uygulamayı aç
2. Ayarlar (sağ üst dişli ikonu)
3. Profil bölümüne tıkla
4. İsim gir, renk seç
5. Kaydet
6. Davet kodunu not et
```

#### 3. Console Loglarını Kontrol Edin
Xcode'da uygulamayı çalıştırıp Console'u açın:

**Başarılı kullanıcı oluşturma:**
```
✅ User initialized with code: ABC123
🔍 Searching for user with invite code: XYZ789
📊 Found 1 user(s) with code XYZ789
✅ User found: Arkadaş İsmi (ID: _xxxxx)
```

**Kullanıcı bulunamadı:**
```
🔍 Searching for user with invite code: XYZ789
📊 Found 0 user(s) with code XYZ789
❌ No user found with code: XYZ789
💡 Tip: Make sure both users are using the same app version
```

#### 4. CloudKit Dashboard'da Kontrol Edin
```
1. CloudKit Dashboard > Data
2. Environment: Production seç
3. Database: Public seç
4. Record Type: Users seç
5. Kullanıcıların kayıtlı olup olmadığını kontrol et
```

---

## Sorun 2: "Öneriler Yüklenemedi"

### Olası Nedenler
1. Müzik servisi bağlı değil
2. Spotify/Apple Music API hatası
3. İnternet bağlantısı yok
4. Rate limit aşıldı

### Çözüm Adımları

#### 1. Müzik Servisi Bağlantısını Kontrol Edin
```
1. Ayarlar > Müzik Servisleri
2. Spotify veya Apple Music'in "Bağlı" olduğunu kontrol et
3. Bağlı değilse, bağlan
```

#### 2. En Az 3 Şarkı Seçin
Kişiselleştirilmiş öneriler için en az 3 şarkı gerekli:
```
1. Bugün sekmesine git
2. 3 farklı günde şarkı seç
3. Öneriler otomatik güncellenecek
```

#### 3. Console Loglarını Kontrol Edin

**Başarılı öneriler:**
```
✅ Fetching personalized recommendations (history: 5 songs)
🎵 Using Spotify for recommendations
✅ Fetched 8 recommendations
```

**Hata durumları:**
```
❌ Recommendation error: Not authenticated
→ Çözüm: Müzik servisine bağlan

❌ Spotify API hatası: Rate limit exceeded
→ Çözüm: Birkaç dakika bekle

❌ Network error
→ Çözüm: İnternet bağlantısını kontrol et
```

#### 4. Cache'i Temizle
```
1. Ayarlar'a git
2. Uygulamayı kapat
3. Uygulamayı tekrar aç
4. Öneriler yeniden yüklenecek
```

---

## Genel Debug Adımları

### 1. Xcode Console'u Kullanın
En detaylı bilgi Console'da:
```
1. Xcode'da projeyi aç
2. Cihazı seç (TestFlight değil, direkt Xcode'dan çalıştır)
3. Run (Cmd+R)
4. Console'u aç (Cmd+Shift+Y)
5. Logları oku
```

### 2. TestFlight vs Xcode
- **TestFlight**: Production environment, daha az log
- **Xcode**: Development environment, detaylı log

**Önemli**: TestFlight'ta çalışmıyorsa, Xcode'dan test edin!

### 3. Her İki Kullanıcı da Aynı Versiyonu Kullanmalı
```
- İkisi de TestFlight VEYA
- İkisi de Xcode
- Karışık kullanmayın!
```

---

## Hızlı Kontrol Listesi

### Arkadaş Ekleme
- [ ] CloudKit schema Production'a deploy edildi
- [ ] Her iki kullanıcı da profil oluşturdu
- [ ] Her iki kullanıcı da davet kodunu görebiliyor
- [ ] Her iki kullanıcı da aynı versiyonu kullanıyor
- [ ] İnternet bağlantısı var

### Öneriler
- [ ] Spotify veya Apple Music bağlı
- [ ] En az 3 şarkı seçildi
- [ ] İnternet bağlantısı var
- [ ] Rate limit aşılmadı (çok sık yenileme yapılmadı)

---

## Sık Karşılaşılan Hatalar

### "Error saving record in production scheme"
**Neden**: Schema Production'a deploy edilmemiş
**Çözüm**: `CLOUDKIT_PRODUCTION_DEPLOYMENT.md` rehberini takip et

### "User not found"
**Neden**: Arkadaş profil oluşturmamış veya schema deploy edilmemiş
**Çözüm**: Her iki kullanıcı da profil oluşturmalı

### "Not authenticated"
**Neden**: Müzik servisi bağlı değil
**Çözüm**: Ayarlar > Müzik Servisleri > Bağlan

### "Rate limit exceeded"
**Neden**: Spotify API limiti aşıldı
**Çözüm**: 5-10 dakika bekle

### "Network error"
**Neden**: İnternet bağlantısı yok
**Çözüm**: WiFi/4G kontrol et

---

## İletişim ve Destek

Sorun devam ederse:
1. Console loglarını kaydet
2. Hangi adımları denediğini not et
3. Ekran görüntüsü al
4. CloudKit Dashboard'da Production schema'sını kontrol et

## Kaynaklar
- `CLOUDKIT_PRODUCTION_DEPLOYMENT.md` - Schema deployment
- `TESTFLIGHT_CLOUDKIT_ISSUE.md` - Environment sorunları
- `SIMULATOR_ICLOUD_SETUP.md` - Simülatör kurulumu
