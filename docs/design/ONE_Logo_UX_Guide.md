# ONE - Logo & UX Tasarım Kılavuzu

## 🎯 Marka Kimliği

**ONE** - Her gün bir şarkı, her gün bir renk, her gün bir his.

### Tasarım Felsefesi: Wabi-Sabi Minimalizm
- **Mükemmellik değil, özgünlük**
- Sadelik, doğallık, geçicilik
- Az ama öz, anlamlı etkileşimler
- Organik formlar ve yumuşak geçişler

---

## 🎨 Logo Konseptleri

### Konsept 1: Minimalist Nokta (Önerilen)
```
     ●
    ONE
```

**Görsel Açıklama:**
- Tek bir nokta (●) - "ONE" kavramının en saf hali
- Nokta, bir günü, bir anı, bir nefesi temsil eder
- Altında italik "ONE" yazısı (Fraunces Light Italic)

**Teknik Özellikler:**
- Nokta: 8-12px çap, #111112
- Tipografi: Fraunces Light Italic, 42-48pt
- Tracking: -1 (sıkı harf aralığı)
- Renk: #111112 (neredeyse siyah)

**Kullanım Alanları:**
- App icon (1024x1024): Büyük nokta + "ONE" text
- Watermark: Sadece nokta veya "ONE" text
- Loading states: Pulse animasyonlu nokta

---

### Konsept 2: Nefes Alan Daire
```
    ◯ ◯ ◯
      ●
    ONE
```

**Görsel Açıklama:**
- Merkezdeki solid daire etrafında 2-3 konsantrik çember
- "Nefes alma" animasyonu - genişleyip daralan halkalar
- Organik, canlı, meditatif his

**Teknik Özellikler:**
- İç daire: 40px, solid #111112
- Dış halkalar: 60-80-100px, stroke 1px, opacity 0.1-0.15
- Animasyon: 2s ease-in-out, infinite loop

**Kullanım Alanları:**
- Splash screen (mevcut)
- Loading indicator
- Onay/başarı animasyonları

---

### Konsept 3: Tipografik Logo
```
    ONE
```

**Görsel Açıklama:**
- Sadece "ONE" kelimesi, büyük ve cesur
- Fraunces font ailesi ile serif detaylar
- İtalik vurgu ile dinamizm

**Varyasyonlar:**
- **Light Italic**: Zarif, minimal (ana kullanım)
- **Regular**: Daha güçlü, vurgulu başlıklar için
- **Bold**: Çok nadir, özel durumlar

**Teknik Özellikler:**
- Font: Fraunces Light Italic
- Size: 42-72pt (context'e göre)
- Color: #111112 veya beyaz (dark mode)
- Tracking: -1 to -2

---

## 📐 Logo Kullanım Kuralları

### Boyutlar ve Oranlar
```
Minimum boyut: 24px yükseklik
Optimal boyut: 48-72px yükseklik
Maximum boyut: 120px yükseklik

Boşluk (clear space): Logo yüksekliğinin %50'si
```

### Renk Varyasyonları

**Primary (Light Mode):**
- Logo: #111112 (neredeyse siyah)
- Background: #F7F6F3 (off-white)

**Secondary (Dark Mode):**
- Logo: #FFFFFF (beyaz)
- Background: #111112 (neredeyse siyah)

**Accent (Mood Colors):**
- Logo üzerine mood color overlay (5-10% opacity)
- Dinamik, kullanıcının seçimine göre değişir

### Yasak Kullanımlar
❌ Logo'yu deforme etme (stretch/squash)
❌ Gölge veya 3D efekt ekleme
❌ Gradient veya texture ekleme
❌ Outline/stroke ekleme
❌ Çok renkli versiyonlar
❌ Düşük kontrast kombinasyonlar

---

## 🎭 App Icon Tasarımı

### Önerilen Tasarım: Minimalist Nokta
```
┌─────────────────┐
│                 │
│                 │
│       ●         │
│      ONE        │
│                 │
│                 │
└─────────────────┘
```

**Özellikler:**
- 1024x1024px (iOS standart)
- Background: #F7F6F3 (off-white)
- Merkezi nokta: 200px çap, #111112
- "ONE" text: Fraunces Light Italic, 120pt
- Minimal, tanınabilir, timeless

**Alternatif: Sadece Nokta**
```
┌─────────────────┐
│                 │
│                 │
│                 │
│       ●         │
│                 │
│                 │
│                 │
└─────────────────┘
```
- Daha minimal, daha cesur
- Nokta: 300px çap
- Hiç text yok

---

## 🖼️ Watermark Tasarımı (Instagram Story Cards)

### Önerilen: Text-Only Watermark
```
ONE
```

**Teknik Özellikler:**
- Size: 240x240px (transparent PNG)
- Font: Fraunces Light Italic, 80pt
- Color: #FFFFFF (beyaz)
- Opacity: 5% (story card'da)
- Position: Bottom right, 40px padding

**Alternatif: Nokta + Text**
```
  ●
 ONE
```
- Daha tanınabilir
- Biraz daha büyük (100pt text)

---

## 🎨 Renk Paleti

### Primary Colors
```
Background:    #F7F6F3  (Off-White, Wabi-Sabi)
Text Primary:  #111112  (Almost Black)
Text Secondary:#BFBDB5  (Warm Gray)
Accent Neutral:#E8E6E0  (Light Beige)
```

### Mood Colors (Kullanıcı Seçimleri)
```
Ateşli:   #FF6B6B  (Kırmızı)
Huzurlu:  #4ECDC4  (Turkuaz)
Melankolik:#95A3B3 (Gri-Mavi)
Neşeli:   #FFE66D  (Sarı)
Boş:      #E8E6E0  (Nötr Bej)
... (daha fazla mood color)
```

### Sistem Renkleri
```
Success:  #6BCF7F  (Yeşil)
Error:    #FF6B6B  (Kırmızı)
Warning:  #FFB84D  (Turuncu)
Info:     #4ECDC4  (Mavi)
```

---

## ✍️ Tipografi Sistemi

### Font Ailesi: Fraunces
```
Primary:   Fraunces Light Italic (ana kullanım)
Secondary: Fraunces Regular (vurgular)
Tertiary:  SF Mono / System Monospaced (detaylar)
```

### Tipografi Hiyerarşisi
```
H1 (Hero):        72pt, Fraunces Light Italic, -2 tracking
H2 (Title):       48pt, Fraunces Light Italic, -1 tracking
H3 (Subtitle):    32pt, Fraunces Regular, 0 tracking
Body Large:       18pt, Fraunces Regular, 0 tracking
Body:             16pt, System Regular, 0 tracking
Caption:          13pt, System Monospaced, +1.5 tracking
Small:            11pt, System Monospaced, +1 tracking
```

### Yazı Renkleri
```
Primary:   #111112 (ana metin)
Secondary: #BFBDB5 (yardımcı metin)
Tertiary:  #D4D2CA (placeholder, disabled)
Inverse:   #FFFFFF (dark background üzerinde)
```

---

## 🎬 Animasyon Dili

### Prensip: Organik ve Yumuşak
- Easing: `.easeInOut` (default)
- Duration: 0.3-0.6s (hızlı), 1-2s (yavaş/meditatif)
- Spring: `.spring(response: 0.5, dampingFraction: 0.7)`

### Animasyon Tipleri

**1. Nefes Alma (Breathing)**
```swift
.scaleEffect(breathe ? 1.1 : 1.0)
.animation(.easeInOut(duration: 2).repeatForever(autoreverses: true))
```
Kullanım: Splash screen, loading, meditation states

**2. Pulse (Nabız)**
```swift
.opacity(pulse ? 1.0 : 0.3)
.animation(.easeInOut(duration: 1).repeatForever(autoreverses: true))
```
Kullanım: Notifications, attention grabbers

**3. Fade In/Out**
```swift
.opacity(show ? 1.0 : 0.0)
.animation(.easeIn(duration: 0.4))
```
Kullanım: Screen transitions, content reveals

**4. Scale + Fade**
```swift
.scaleEffect(show ? 1.0 : 0.8)
.opacity(show ? 1.0 : 0.0)
.animation(.spring(response: 0.5, dampingFraction: 0.7))
```
Kullanım: Modals, confirmations, success states

**5. Slide**
```swift
.offset(y: show ? 0 : 50)
.opacity(show ? 1.0 : 0.0)
.animation(.easeOut(duration: 0.4))
```
Kullanım: List items, cards, bottom sheets

---

## 🎯 UX Prensipleri

### 1. Minimal Cognitive Load
- Her ekranda tek bir ana aksiyon
- Gereksiz seçenekler yok
- Clear visual hierarchy

### 2. Intentional Friction
- Önemli aksiyonlar (kaydetme) için onay adımı
- Hızlı değil, düşünceli etkileşim
- "Slow down to speed up"

### 3. Emotional Resonance
- Mood colors ile duygusal bağlantı
- Kişisel ve özgün içerik
- Nostalji ve anı odaklı

### 4. Wabi-Sabi Aesthetics
- Boşluk ve negatif alan
- Asimetri ve doğallık
- Mükemmel olmayan güzellik

---

## 📱 Ekran Örnekleri

### Splash Screen
```
┌─────────────────────┐
│                     │
│                     │
│        ◯ ◯ ◯        │
│          ●          │
│                     │
│        ONE          │
│                     │
│  Her gün bir şarkı  │
│                     │
│                     │
│  "Mükemmellik değil,│
│     özgünlük."      │
│                     │
└─────────────────────┘
```

### Home Screen (Bugün)
```
┌─────────────────────┐
│  Bugün nasıl bir    │
│  şarkı?             │
│                     │
│  ┌───────────────┐  │
│  │ 🔍 Ara...     │  │
│  └───────────────┘  │
│                     │
│  ┌─────────────────┐│
│  │ 🎵 Song Title   ││
│  │    Artist       ││
│  └─────────────────┘│
│  ┌─────────────────┐│
│  │ 🎵 Song Title   ││
│  │    Artist       ││
│  └─────────────────┘│
│                     │
└─────────────────────┘
```

### Confirm Screen
```
┌─────────────────────┐
│  ←                  │
│                     │
│      ◯ ◯ ◯          │
│    [Cover Art]      │
│                     │
│  Song Title         │
│  Artist Name        │
│                     │
│  Bu şarkı seni...   │
│  ┌─────┐  ┌─────┐  │
│  │Yansıt│  │Taşı │  │
│  └─────┘  └─────┘  │
│                     │
│  ● ● ● ● ● ● ●     │
│  (Mood Colors)      │
│                     │
│  ┌───────────────┐  │
│  │   Kaydet      │  │
│  └───────────────┘  │
└─────────────────────┘
```

### Archive Screen
```
┌─────────────────────┐
│  Her gün bir renk.  │
│                     │
│  ← Ocak 2024    →   │
│                     │
│  P  S  Ç  P  C  C  P│
│  ■  ■  ▢  ■  ■  ■  ▢│
│  ■  ▢  ■  ■  ▢  ■  ■│
│  ▢  ■  ■  ■  ■  ▢  ■│
│  ■  ■  ▢  ■  ■  ■  ■│
│                     │
│  (Renkli kutular =  │
│   kaydedilmiş günler)│
└─────────────────────┘
```

---

## 🎁 Bonus: Marketing Assets

### App Store Screenshots
1. **Hero Shot**: Splash screen + "Her gün bir şarkı"
2. **Feature 1**: Şarkı seçimi ekranı
3. **Feature 2**: Mood color seçimi
4. **Feature 3**: Arşiv takvimi
5. **Feature 4**: Instagram story card preview

### Taglines
- "Her gün bir şarkı, her gün bir his"
- "Müziğinle ruh halinizi eşleştirin"
- "Minimalist müzik günlüğü"
- "Wabi-Sabi ile tasarlanmış"
- "Mükemmellik değil, özgünlük"

---

## 📦 Dosya Yapısı

### Logo Assets (Oluşturulacak)
```
Assets.xcassets/
├── AppIcon.appiconset/
│   └── icon-1024.png (1024x1024)
├── ONE_Logo.imageset/
│   ├── logo@1x.png (48px)
│   ├── logo@2x.png (96px)
│   └── logo@3x.png (144px)
├── ONE_Watermark.imageset/
│   └── watermark.png (240x240, transparent)
└── ONE_Icon_Minimal.imageset/
    └── icon-minimal.png (120x120)
```

### Font Files (Mevcut)
```
Fonts/
├── Fraunces-Light.ttf
├── Fraunces-LightItalic.ttf
└── Fraunces-Regular.ttf
```

---

## 🛠️ Uygulama Önerileri

### 1. App Icon Oluşturma
**Araç:** Figma, Sketch, veya Photoshop
**Adımlar:**
1. 1024x1024px canvas oluştur
2. Background: #F7F6F3
3. Merkeze 200px çap daire (#111112)
4. Altına "ONE" text (Fraunces Light Italic, 120pt)
5. Export as PNG (no transparency)

### 2. Watermark Oluşturma
**Araç:** Figma veya Photoshop
**Adımlar:**
1. 240x240px canvas (transparent background)
2. "ONE" text (Fraunces Light Italic, 80pt, white)
3. Center align
4. Export as PNG with transparency

### 3. Logo Variations
- **Primary**: Nokta + Text (splash screen)
- **Icon Only**: Sadece nokta (loading states)
- **Text Only**: Sadece "ONE" (watermark)

---

## 📚 Referanslar

### Tasarım İlhamı
- **Wabi-Sabi**: Japon estetik felsefesi
- **Brutalist Web Design**: Minimal, functional
- **Swiss Typography**: Grid systems, clarity
- **Organic Modernism**: Natural forms, soft edges

### Benzer Uygulamalar (Referans)
- **Letterboxd**: Film günlüğü, minimal UI
- **Daylio**: Mood tracker, color-coded
- **Notion**: Clean typography, spacious layout
- **Things**: Minimal task manager, elegant

---

## ✅ Checklist

### Logo Tasarımı
- [ ] App icon tasarla (1024x1024)
- [ ] Watermark oluştur (240x240)
- [ ] Logo variations export et
- [ ] Assets.xcassets'e ekle

### Tipografi
- [x] Fraunces font ekle
- [x] Font hierarchy tanımla
- [ ] Custom font modifiers oluştur

### Renk Sistemi
- [x] Primary colors tanımla
- [x] Mood colors tanımla
- [ ] Color extension'ları test et

### Animasyonlar
- [x] Splash screen animasyonu
- [x] Breathing animation
- [ ] Transition animations
- [ ] Micro-interactions

### Dokümantasyon
- [x] Logo guide oluştur
- [x] UX principles dokümante et
- [x] Design system tanımla

---

**Son Güncelleme:** 2024
**Versiyon:** 1.0
**Tasarım:** Wabi-Sabi Minimalism

