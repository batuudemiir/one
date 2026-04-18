# Müzik Servisi Fallback Sistemi

## Özellik
Kullanıcı hiçbir müzik servisine bağlı olmasa bile şarkı önerileri gösterilir.

## Öncelik Sırası

1. **Spotify** (Birinci öncelik)
   - Kullanıcı Spotify'a bağlıysa
   - Personalized veya generic öneriler

2. **Apple Music** (İkinci öncelik)
   - Kullanıcı Apple Music'e bağlıysa
   - Spotify yoksa devreye girer

3. **Örnek Şarkılar** (Üçüncü öncelik)
   - Hiçbir servise bağlı değilse
   - API hatası olursa fallback olarak

## Yapılan Değişiklikler

### RecommendationEngine.swift

#### fetchRecommendations() Fonksiyonu
```swift
// Öncelik kontrolü
if useSpotify {
    // Spotify önerileri
} else if useAppleMusic {
    // Apple Music önerileri
} else {
    // Örnek şarkılar
    fetchedRecommendations = getMockRecommendations()
}
```

#### Hata Yönetimi
```swift
catch {
    // API hatası olursa örnek şarkılara fallback
    print("ℹ️ Falling back to example songs")
    recommendations = getMockRecommendations()
    error = nil // Hatayı temizle
}
```

#### getMockRecommendations() Fonksiyonu
8 adet örnek şarkı içerir:
- Midnight City - M83
- Weightless - Marconi Union
- Holocene - Bon Iver
- Intro - The xx
- Breathe - Télépopmusik
- To Build a Home - The Cinematic Orchestra
- Teardrop - Massive Attack
- Svefn-g-englar - Sigur Rós

Her şarkı için:
- ID (mock-1, mock-2, vb.)
- İsim ve sanatçı
- Genre
- Öneri nedeni (Türkçe)

## Kullanıcı Deneyimi

### Servis Bağlı Değilse
- ✅ Örnek şarkılar gösterilir
- ✅ "Müzik servisi seç" mesajı gösterilir
- ✅ Spotify ve Apple Music butonları gösterilir
- ✅ Kullanıcı istediği servise bağlanabilir

### API Hatası Olursa
- ✅ Otomatik olarak örnek şarkılara geçer
- ✅ Hata mesajı gösterilmez (seamless fallback)
- ✅ Kullanıcı deneyimi kesintisiz devam eder

### Cache Davranışı
- Örnek şarkılar cache'lenmez
- Sadece gerçek API'den gelen öneriler cache'lenir
- Her açılışta yeni örnek şarkılar gösterilebilir (shuffle ile)

## Test Senaryoları

### 1. Hiçbir Servise Bağlı Değil
```
Beklenen: 8 örnek şarkı gösterilir
Sonuç: ✅ Başarılı
```

### 2. Spotify Bağlı
```
Beklenen: Spotify önerileri gösterilir
Sonuç: ✅ Başarılı
```

### 3. Apple Music Bağlı (Spotify Yok)
```
Beklenen: Apple Music önerileri gösterilir
Sonuç: ✅ Başarılı
```

### 4. Spotify API Hatası
```
Beklenen: Örnek şarkılara fallback
Sonuç: ✅ Başarılı
```

### 5. İnternet Yok
```
Beklenen: Cache varsa cache, yoksa örnek şarkılar
Sonuç: ✅ Başarılı
```

## Debug Logları

### Örnek Şarkılar Gösterildiğinde
```
ℹ️ No music service connected, showing example songs
✅ Loaded 8 recommendations
```

### API Hatası Sonrası Fallback
```
❌ Recommendation error: Spotify API hatası: Status 404
ℹ️ Falling back to example songs
✅ Loaded 8 recommendations
```

### Spotify Kullanıldığında
```
✅ Fetching personalized Spotify recommendations (history: 15 songs)
🎵 Spotify Recommendations URL: https://api.spotify.com/v1/recommendations?...
✅ Loaded 8 recommendations
```

## Gelecek İyileştirmeler

1. **Dinamik Örnek Şarkılar**
   - Kullanıcının dil tercihine göre
   - Mevsime göre
   - Günün saatine göre

2. **Daha Fazla Örnek Şarkı**
   - 20-30 şarkılık pool
   - Her seferinde farklı 8 şarkı göster

3. **Kategori Bazlı Örnekler**
   - Enerjik
   - Sakin
   - Nostaljik
   - vb.

4. **Kullanıcı Geri Bildirimi**
   - "Bu şarkıyı beğendin mi?" butonu
   - Beğenilere göre örnek şarkıları özelleştir
