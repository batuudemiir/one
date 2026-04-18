# Spotify Öneri Sistemi Debug Rehberi

## Sorun
Spotify bağlı olmasına rağmen örnek şarkılar gösteriliyor.

## Olası Nedenler

### 1. Token Süresi Dolmuş
Spotify access token'ları 1 saat sonra expire olur. Token keychain'de var ama artık geçersiz.

**Kontrol:**
```
Xcode Console'da şu logları arayın:
🎵 Music Service Status:
   Spotify authenticated: true
   Spotify has token: true
   
Sonra:
❌ Recommendation error: Spotify API hatası: Status 401
```

**Çözüm:**
- Spotify'dan çıkış yapıp tekrar giriş yapın
- Veya token refresh mekanizması ekleyin

### 2. Geçersiz Genre Parametreleri
Kullanıcının genre'ları Spotify'ın kabul ettiği formatta değil.

**Kontrol:**
```
🎵 Spotify Recommendations URL: https://api.spotify.com/v1/recommendations?seed_genres=...

❌ Spotify API Error Response: {"error": {"status": 404, "message": "..."}}
```

**Çözüm:**
- `mapToSpotifyGenre()` fonksiyonu zaten eklendi
- Fallback genre'lar kullanılıyor

### 3. Boş Seed Parametreleri
Ne genre ne de artist ID'si çözümlenemedi.

**Kontrol:**
```
📊 Taste Profile:
   Total entries: 5
   Top genres: 
   Top artists: 
```

**Çözüm:**
- Fallback genre'lar otomatik ekleniyor
- Kod zaten bu durumu handle ediyor

### 4. Rate Limit
Çok fazla istek yapıldı.

**Kontrol:**
```
❌ Recommendation error: Spotify API hatası: Rate limit exceeded
```

**Çözüm:**
- Birkaç dakika bekleyin
- Cache mekanizması kullanın

## Debug Adımları

### 1. Xcode Console'u Açın
Cmd + Shift + Y

### 2. Önerileri Yenileyin
Uygulamada "Yenile" butonuna tıklayın

### 3. Logları İnceleyin

#### Başarılı Spotify İsteği
```
🎵 Music Service Status:
   Spotify authenticated: true
   Spotify has token: true
   Apple Music authorized: false

📊 Taste Profile:
   Total entries: 10
   Top genres: indie, rock, electronic
   Top artists: Bon Iver, The xx, M83

✅ Fetching personalized Spotify recommendations (history: 10 songs)
🎵 Spotify Recommendations URL: https://api.spotify.com/v1/recommendations?seed_genres=indie,rock,electronic&limit=16&target_valence=0.70&target_energy=0.60
✅ Loaded 8 recommendations
```

#### Başarısız İstek (Token Expired)
```
🎵 Music Service Status:
   Spotify authenticated: true
   Spotify has token: true
   Apple Music authorized: false

✅ Fetching generic Spotify recommendations
🎵 Spotify Recommendations URL: https://api.spotify.com/v1/recommendations?seed_genres=indie,alternative,pop&limit=16&target_valence=0.50&target_energy=0.50
❌ Spotify API Error Response: {"error": {"status": 401, "message": "The access token expired"}}
❌ Recommendation error: Spotify API hatası: Status 401
ℹ️ Falling back to example songs
✅ Loaded 8 recommendations
```

#### Başarısız İstek (Invalid Genre)
```
🎵 Spotify Recommendations URL: https://api.spotify.com/v1/recommendations?seed_genres=invalid-genre&limit=16
❌ Spotify API Error Response: {"error": {"status": 404, "message": "Invalid genre"}}
❌ Recommendation error: Spotify API hatası: Status 404
ℹ️ Falling back to example songs
✅ Loaded 8 recommendations
```

## Çözümler

### Token Expired (401)
```swift
// SpotifyManager.swift'e eklenecek
func refreshTokenIfNeeded() async {
    guard let expirationDate = tokenExpirationDate else { return }
    
    if Date() >= expirationDate {
        // Token expired, need to re-authenticate
        await MainActor.run {
            isAuthenticated = false
            accessToken = nil
        }
    }
}
```

### Manuel Test
1. Ayarlar > Spotify > Bağlantıyı Kes
2. Tekrar Spotify'a bağlan
3. Önerileri yenile
4. Logları kontrol et

### Cache Temizle
```swift
// RecommendationEngine'de
func clearCache() {
    cache.clearCache()
    recommendations = []
}
```

## Beklenen Davranış

### Spotify Bağlı ve Token Geçerli
- ✅ Spotify API'den öneriler gelir
- ✅ Personalized veya generic
- ✅ 8 şarkı gösterilir

### Spotify Bağlı ama Token Geçersiz
- ⚠️ API 401 hatası döner
- ✅ Otomatik olarak örnek şarkılara geçer
- ℹ️ Kullanıcı tekrar giriş yapmalı

### Spotify Bağlı ama API Hatası
- ⚠️ API 404/500 hatası döner
- ✅ Otomatik olarak örnek şarkılara geçer
- ℹ️ Seamless fallback

## Geliştirme Önerileri

### 1. Token Refresh Mekanizması
```swift
// Refresh token kullanarak otomatik yenileme
func refreshAccessToken() async throws {
    // Spotify refresh token endpoint'i kullan
}
```

### 2. Token Expiration Kontrolü
```swift
var isTokenValid: Bool {
    guard let expirationDate = tokenExpirationDate else { return false }
    return Date() < expirationDate
}
```

### 3. Daha İyi Hata Mesajları
```swift
if case .notAuthenticated = error {
    // "Token süresi doldu, tekrar giriş yap" mesajı göster
}
```

### 4. Otomatik Yeniden Deneme
```swift
// 401 hatası alınırsa otomatik re-authenticate
if httpResponse.statusCode == 401 {
    await SpotifyManager.shared.authenticate()
    // Retry request
}
```
