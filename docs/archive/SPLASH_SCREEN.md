# ONE - Splash Screen Tasarımı

## 🎨 Wabi-Sabi Felsefesi

Splash screen, uygulamanın Wabi-Sabi felsefesini yansıtır:
- **Sadelik**: Minimal elementler
- **Doğallık**: Yumuşak animasyonlar
- **Huzur**: Rahatlatıcı geçişler
- **Özgünlük**: Benzersiz tasarım

## 🎭 Üç Farklı Varyasyon

### 1. SplashScreen (Varsayılan)
**Konsept**: Genişleyen daireler ve kademeli metin

**Animasyon Akışı**:
```
0.0s - 0.6s: İç daire beliriyor
0.3s - 0.9s: Dış daire genişliyor
0.8s - 1.4s: "ONE" metni fade in
1.2s - 1.8s: Alt yazı fade in
2.5s: Ana uygulamaya geçiş
```

**Elementler**:
- İç daire (60x60, siyah, solid)
- Dış daire (120x120, siyah çizgi, %10 opacity)
- "ONE" başlık (48pt, italic)
- "Her gün bir şarkı" alt başlık
- Wabi-Sabi alıntısı

**Renk Paleti**:
- Arka plan: #F7F6F3 (krem)
- Ana renk: #111112 (siyah)
- İkincil: #BFBDB5 (gri)

### 2. SplashScreenMinimal
**Konsept**: Tek nokta ve isim

**Animasyon Akışı**:
```
0.0s - 2.4s: Nokta pulse (3 tekrar)
1.2s - 1.8s: "ONE" metni fade in
2.5s: Ana uygulamaya geçiş
```

**Elementler**:
- Tek nokta (8x8, pulse animasyon)
- "ONE" başlık (42pt, italic)

**Özellikler**:
- En minimal yaklaşım
- Hızlı ve zarif
- Dikkat dağıtmayan

### 3. SplashScreenBreathing
**Konsept**: Nefes alan daireler

**Animasyon Akışı**:
```
0.0s - ∞: Daireler nefes alıyor (sonsuz döngü)
0.5s - 1.3s: Metin fade in
3.0s: Ana uygulamaya geçiş
```

**Elementler**:
- 3 konsantrik daire (nefes animasyonu)
- İç daire (40x40, solid)
- "ONE" + alt başlık

**Özellikler**:
- Meditasyon hissi
- Sürekli hareket
- Rahatlatıcı ritim

## 🎬 Animasyon Detayları

### Timing Functions
```swift
.easeOut(duration: 0.6)    // Yumuşak başlangıç
.easeIn(duration: 0.6)     // Yumuşak bitiş
.easeInOut(duration: 0.5)  // Dengeli geçiş
```

### Scale Effects
```swift
scale: 0.8 → 1.0           // %80'den tam boyuta
circleScale: 0 → 1         // Sıfırdan tam boyuta
dotScale: 1.0 → 1.5        // Pulse efekti
```

### Opacity Transitions
```swift
opacity: 0 → 1             // Görünmezden görünüre
textOpacity: 0 → 1         // Metin fade in
subtitleOpacity: 0 → 1     // Alt yazı fade in
```

## 📐 Boyutlar ve Spacing

### SplashScreen
```
Outer Circle: 120x120
Inner Circle: 60x60
Title: 48pt
Subtitle: 13pt
Quote: 16pt
Bottom Padding: 60pt
```

### SplashScreenMinimal
```
Dot: 8x8
Title: 42pt
Spacing: 24pt
```

### SplashScreenBreathing
```
Inner Circle: 40x40
Outer Circles: 60-140 (3 katman)
Title: 44pt
Subtitle: 12pt
Spacing: 40pt
```

## 🎯 Kullanım

### Varsayılan Splash
```swift
struct ContentView: View {
    @State private var isActive = false
    
    var body: some View {
        if isActive {
            ONEColorPickerView()
        } else {
            SplashScreen(isActive: $isActive)
        }
    }
}
```

### Alternatif Seçim
```swift
// Minimal için
SplashScreenMinimal(isActive: $isActive)

// Breathing için
SplashScreenBreathing(isActive: $isActive)
```

## 🔧 Özelleştirme

### Süre Değiştirme
```swift
// Daha hızlı (2 saniye)
DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
    withAnimation(.easeInOut(duration: 0.5)) {
        isActive = true
    }
}

// Daha yavaş (4 saniye)
DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
    withAnimation(.easeInOut(duration: 0.5)) {
        isActive = true
    }
}
```

### Renk Değiştirme
```swift
// Koyu tema
Color(hex: "#1A1A1A")  // Arka plan
Color(hex: "#F7F6F3")  // Metin

// Renkli varyasyon
Color(hex: "#E84040")  // Kırmızı
Color(hex: "#5B8DEF")  // Mavi
```

### Animasyon Hızı
```swift
// Daha hızlı
.easeOut(duration: 0.3)

// Daha yavaş
.easeOut(duration: 1.2)
```

## 💡 Tasarım Prensipleri

### 1. Minimal Elementler
- Sadece gerekli olanlar
- Fazla detay yok
- Temiz ve net

### 2. Yumuşak Geçişler
- Ani hareketler yok
- Doğal akış
- Göze hoş gelen

### 3. Anlamlı Animasyon
- Her hareketin bir amacı var
- Dikkat dağıtmayan
- Kullanıcıyı hazırlayan

### 4. Wabi-Sabi Ruhu
- Mükemmellik aranmıyor
- Doğallık ön planda
- Huzur veren

## 🎨 Tipografi

### Font Kullanımı
```swift
// Başlık
.font(.custom("Fraunces-LightItalic", size: 48))
.italic()

// Alt başlık
.font(.system(size: 13, weight: .regular, design: .monospaced))

// Alıntı
.font(.custom("Fraunces-LightItalic", size: 16))
.italic()
```

### Tracking (Harf Aralığı)
```swift
.tracking(-1)    // Başlık için (daha sıkı)
.tracking(1.5)   // Alt başlık için (daha geniş)
```

## 🌟 Önerilen Kullanım

### İlk Açılış
- **SplashScreen**: Tam deneyim
- Kullanıcıyı karşılama
- Marka kimliği oluşturma

### Sonraki Açılışlar
- **SplashScreenMinimal**: Hızlı geçiş
- Kullanıcıyı bekletmeme
- Hafızada tutma

### Özel Durumlar
- **SplashScreenBreathing**: Meditasyon modu
- Rahatlatıcı deneyim
- Özel günler

## 📱 Platform Uyumluluğu

### iOS Versiyonları
- iOS 16.0+
- SwiftUI native
- Tüm cihazlar

### Cihaz Boyutları
- iPhone (tüm modeller)
- iPad (optimize edilmiş)
- Responsive tasarım

## 🐛 Sorun Giderme

### Animasyon Çalışmıyor
```swift
// onAppear içinde kontrol et
.onAppear {
    print("Splash screen appeared")
    startAnimation()
}
```

### Geçiş Olmuyorsa
```swift
// isActive binding'i kontrol et
@State private var isActive = false
```

### Font Görünmüyorsa
```swift
// Fallback font ekle
.font(.custom("Fraunces-LightItalic", size: 48))
.font(.system(size: 48, weight: .light, design: .serif)) // Fallback
```

## 🎯 Gelecek Geliştirmeler

### Planlanan
- [ ] Haptic feedback
- [ ] Ses efekti (opsiyonel)
- [ ] Karanlık mod desteği
- [ ] Özelleştirilebilir süre
- [ ] Animasyon seçimi ayarı

### Değerlendiriliyor
- [ ] Paralaks efekti
- [ ] Parçacık animasyonu
- [ ] Gradient geçişler
- [ ] 3D transform

## 💭 Felsefe

> "İlk izlenim önemlidir, ama acele etmek gerekmez. 
> Splash screen, kullanıcıyı karşılayan sessiz bir selamdır."

Wabi-Sabi felsefesinde:
- Mükemmellik yerine özgünlük
- Karmaşıklık yerine sadelik
- Hız yerine huzur

ONE splash screen'i bu değerleri yansıtır.

---

**Not**: Varsayılan olarak `SplashScreen` kullanılır. Diğer varyasyonlar `ContentView.swift` içinde değiştirilebilir.
