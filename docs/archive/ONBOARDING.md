# ONE - Onboarding Deneyimi

## 🎯 Amaç

İlk kez giriş yapan kullanıcılara:
- Uygulamanın felsefesini tanıtmak
- Wabi-Sabi yaklaşımını açıklamak
- Takvim iznini nazikçe istemek
- Baskı yapmadan bilgilendirmek

## 📱 Sayfa Yapısı

### Sayfa 1: Hoş Geldin
**Görsel**: Minimalist daire animasyonu
**İçerik**:
- "ONE" başlık
- "Her gün bir şarkı" alt başlık
- "Kaydır" yönlendirmesi

**Animasyon**:
- Daire scale: 0 → 1 (0.6s)
- Metin fade in: 0 → 1 (0.6s, 0.3s delay)

### Sayfa 2: Felsefe
**Görsel**: Wabi-Sabi alıntısı + özellikler
**İçerik**:
- "Mükemmellik değil, özgünlük" alıntısı
- 3 temel özellik:
  - 🎵 Günde sadece bir şarkı
  - 📅 Boş günler kınanmaz
  - ❤️ Streak yok, baskı yok
- 侘寂 (Wabi-Sabi) karakteri

**Animasyon**:
- Tüm içerik fade in: 0 → 1 (0.8s, 0.2s delay)

### Sayfa 3: Takvim İzni
**Görsel**: Takvim ikonu + açıklama
**İçerik**:
- "Anılarını sakla" başlık
- "Günlük şarkılarını takvimine ekleyebiliriz. İstersen." açıklama
- "Takvime ekle" butonu
- "Şimdilik atlayacağım" linki
- "Sonradan ayarlardan değiştirebilirsin" notu

**Animasyon**:
- İçerik fade in: 0 → 1 (0.8s, 0.2s delay)
- Buton tıklanınca loading state

## 🎨 Tasarım Prensipleri

### 1. Minimal ve Temiz
- Fazla bilgi yok
- Sadece gerekli olanlar
- Bol beyaz alan

### 2. Nazik ve Saygılı
- Baskı yapmayan dil
- "İstersen" ifadesi
- Atlama seçeneği her zaman var

### 3. Wabi-Sabi Ruhu
- Mükemmellik aranmıyor
- Doğallık ön planda
- Huzur veren

### 4. Şeffaf ve Dürüst
- İzin neden isteniyor açık
- Sonradan değiştirilebilir
- Zorunlu değil

## 🔄 Kullanıcı Akışı

```
Uygulama Açılır
       ↓
Onboarding Tamamlandı mı?
    ↙        ↘
  Evet       Hayır
    ↓          ↓
Splash    Onboarding
Screen    Sayfa 1
    ↓          ↓
  Ana      Sayfa 2
  App         ↓
           Sayfa 3
              ↓
         İzin İste?
        ↙        ↘
     Evet       Hayır
       ↓          ↓
    İzin      Direkt
    Ver       Geç
       ↓          ↓
    Splash    Splash
    Screen    Screen
       ↓          ↓
     Ana App   Ana App
```

## 💾 Veri Saklama

### UserDefaults
```swift
UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
```

### Kontrol
```swift
let hasCompleted = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
```

### Sıfırlama (Test için)
```swift
UserDefaults.standard.removeObject(forKey: "hasCompletedOnboarding")
```

## 🎭 Animasyon Detayları

### Sayfa Geçişleri
```swift
TabView(selection: $currentPage)
    .tabViewStyle(.page(indexDisplayMode: .always))
```

### Fade In
```swift
.opacity(opacity)
.onAppear {
    withAnimation(.easeIn(duration: 0.5)) {
        opacity = 1
    }
}
```

### Scale Animation
```swift
.scaleEffect(circleScale)
.onAppear {
    withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
        circleScale = 1
    }
}
```

## 📐 Boyutlar

### Sayfa 1
```
Circle Outer: 100x100
Circle Inner: 50x50
Title: 52pt
Subtitle: 14pt
```

### Sayfa 2
```
Quote: 28pt
Features: 14pt
Wabi-Sabi: 32pt
```

### Sayfa 3
```
Icon Circle: 100x100
Icon: 40pt
Title: 32pt
Description: 14pt
Button: 15pt
```

## 🎨 Renk Paleti

```swift
Background: #F7F6F3 (krem)
Primary: #111112 (siyah)
Secondary: #BFBDB5 (gri)
Button: #111112 (siyah)
Button Text: #FFFFFF (beyaz)
```

## 🔧 Özelleştirme

### Sayfa Ekleme
```swift
// Page 4: New Feature
NewFeaturePage()
    .tag(3)
```

### Süre Değiştirme
```swift
// Daha hızlı geçiş
DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
    completeOnboarding()
}
```

### İzin Atlama
```swift
// İzin sayfasını tamamen kaldır
// Sadece Sayfa 1 ve 2'yi göster
```

## 📱 Platform Uyumluluğu

### iOS Versiyonları
- iOS 16.0+
- iOS 17.0+ (takvim API)
- SwiftUI native

### Cihaz Boyutları
- iPhone (tüm modeller)
- iPad (optimize edilmiş)
- Responsive tasarım

## 🐛 Sorun Giderme

### Onboarding Tekrar Göster
```swift
// Test için
UserDefaults.standard.removeObject(forKey: "hasCompletedOnboarding")
```

### İzin Durumu Kontrol
```swift
CalendarManager.shared.checkAuthorizationStatus()
print("Calendar authorized: \(CalendarManager.shared.isAuthorized)")
```

### Animasyon Çalışmıyor
```swift
// Delay'leri kontrol et
.onAppear {
    print("Page appeared")
    // Animasyon kodları
}
```

## 💡 İpuçları

### Kullanıcı Deneyimi
1. **Hızlı Geçiş**: Kullanıcı isterse hızlıca atlayabilmeli
2. **Bilgilendirici**: Ne yapacağını bilmeli
3. **Baskısız**: Zorlanmamalı
4. **Şeffaf**: Neden istendiği açık olmalı

### Tasarım
1. **Minimal**: Fazla bilgi yükleme
2. **Tutarlı**: Uygulama stiliyle uyumlu
3. **Akıcı**: Yumuşak geçişler
4. **Anlamlı**: Her element bir amaca hizmet etmeli

## 🎯 Başarı Kriterleri

### Kullanıcı Anlayışı
- [ ] Uygulamanın amacını anladı
- [ ] Wabi-Sabi felsefesini kavradı
- [ ] Günlük bir şarkı konseptini öğrendi

### İzin Oranı
- [ ] Takvim izni %60+ (hedef)
- [ ] Kullanıcı zorlanmadan karar verdi
- [ ] Atlama seçeneği kullanıldı

### Deneyim
- [ ] Akıcı geçişler
- [ ] Hızlı yükleme
- [ ] Hata yok

## 📊 Metrikler

### Takip Edilecekler
```swift
// Onboarding tamamlama oranı
let completionRate = completed / total

// Takvim izni verme oranı
let permissionRate = granted / total

// Ortalama süre
let avgDuration = totalTime / users
```

## 🚀 Gelecek Geliştirmeler

### Planlanan
- [ ] Animasyonlu özellik gösterimi
- [ ] Video tanıtım (opsiyonel)
- [ ] Kişiselleştirme seçenekleri
- [ ] Dil seçimi

### Değerlendiriliyor
- [ ] İnteraktif tutorial
- [ ] Örnek şarkı seçimi
- [ ] Mood tanıtımı
- [ ] Arşiv önizlemesi

## 💭 Felsefe

> "İlk izlenim önemlidir, ama acele etmek gerekmez.
> Onboarding, kullanıcıyı karşılayan nazik bir davettir."

Wabi-Sabi onboarding:
- Mükemmellik yerine özgünlük
- Karmaşıklık yerine sadelik
- Baskı yerine davet

---

**Not**: Onboarding sadece ilk açılışta gösterilir. UserDefaults ile kontrol edilir.
