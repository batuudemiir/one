# 🌍 ÇEVRE (CIRCLE) ÖZELLİĞİ - Detaylı Dokümantasyon

## Genel Bakış

Çevre özelliği, ONE kullanıcılarının günlük müzik seçimlerini arkadaşlarıyla paylaşmasını sağlayan minimal ve gizlilik odaklı bir sosyal özelliktir. Wabi-sabi felsefesine uygun olarak, karşılaştırma ve rekabet yerine bağlantı ve farkındalık odaklıdır.

## Temel Prensipler

### Wabi-Sabi Uyumu
- **Baskı Yok**: Bildirim, streak, zorunluluk yok
- **Organik Keşif**: Kullanıcı istediğinde kontrol eder
- **Boş Günler Normal**: Seçim yapmamak da bir seçimdir
- **Minimal Görünüm**: Dikkat dağıtmayan, temiz tasarım
- **Anlık Bağlantı**: Sadece bugünü göster, geçmişi karşılaştırma

### Gizlilik İlkeleri
- Varsayılan: Paylaşım KAPALI
- Kullanıcı kontrolü: Her zaman iptal edilebilir
- Seçici paylaşım: Günlük bazda kontrol
- Şeffaflık: Kim ne gördü, açık
- Apple CloudKit: End-to-end şifreleme

## Özellik Detayları

### 1. Arkadaş Sistemi

#### Arkadaş Ekleme Yöntemleri

**A. Davet Kodu**
- Her kullanıcıya benzersiz 6 haneli kod
- Format: ABC123 (3 harf + 3 rakam)
- Kod girişi ile anında ekleme
- Karşı taraf onayı gerekli

**B. QR Kod**
- Kişisel QR kod üretimi
- Kamera ile tarama
- Yüz yüze ekleme için ideal
- Otomatik davet gönderimi

**C. Kişiler Entegrasyonu**
- iCloud hesabı olan kişileri bul
- ONE kullanan arkadaşları öner
- İsteğe bağlı (izin gerekli)
- Gizlilik odaklı

#### Arkadaşlık Durumları
```
pending     → Davet gönderildi, onay bekleniyor
accepted    → Arkadaşlık aktif
blocked     → Kullanıcı engelledi
removed     → Arkadaşlık sonlandırıldı
```

### 2. Çevre Görünümü

#### Ana Ekran Yapısı
```
┌─────────────────────────────────┐
│  Bugün Çevren                   │
│  ─────────────                  │
│  3 arkadaşın seçim yaptı        │
│                                 │
│  ┌───┐ Ayşe Yılmaz             │
│  │ A │ 🟢 Sakin                │
│  └───┘ "Weightless"            │
│        Marconi Union           │
│        "huzur buldum"          │
│        2 saat önce             │
│                                 │
│  ┌───┐ Mehmet Kaya             │
│  │ M │ 🔴 Ateşli               │
│  └───┘ "Lose Yourself"         │
│        Eminem                  │
│        "motivasyon"            │
│        5 saat önce             │
│                                 │
│  ┌───┐ Zeynep Demir            │
│  │ Z │ ⚪ Henüz seçmedi        │
│  └───┘ "Bugün sessiz..."      │
│                                 │
│  ┌─────────────────────────┐   │
│  │  + Arkadaş Ekle         │   │
│  └─────────────────────────┘   │
│                                 │
│  [Haftalık Özet]                │
└─────────────────────────────────┘
```

#### Kart Detayları
Her arkadaş kartı şunları içerir:
- Avatar (baş harf + renk)
- İsim
- Mood emoji ve kelimesi
- Şarkı adı ve sanatçı
- Günlük not (varsa)
- Seçim zamanı (göreceli)
- Tıklanabilir (şarkıyı aç)

#### Boş Durum
```
🌍

Henüz çevren yok

Arkadaşlarını ekle ve onların
günlük müzik seçimlerini gör.

[Arkadaş Ekle]
```

### 3. Arkadaş Ekleme Ekranı

```
┌─────────────────────────────────┐
│  ← Arkadaş Ekle                 │
│                                 │
│  Senin Kodun                    │
│  ┌─────────────────────────┐   │
│  │      ABC123             │   │
│  │  [QR Kod Göster]        │   │
│  └─────────────────────────┘   │
│                                 │
│  Arkadaş Ekle                   │
│  ┌─────────────────────────┐   │
│  │  Davet Kodu Gir         │   │
│  └─────────────────────────┘   │
│  ┌─────────────────────────┐   │
│  │  QR Kod Tara            │   │
│  └─────────────────────────┘   │
│  ┌─────────────────────────┐   │
│  │  Kişilerden Seç         │   │
│  └─────────────────────────┘   │
│                                 │
│  Arkadaşların (5)               │
│  ┌───┐ Ayşe Yılmaz             │
│  │ A │ Aktif                   │
│  └───┘ [Kaldır]                │
│                                 │
│  Bekleyen Davetler (2)          │
│  ┌───┐ Can Öztürk              │
│  │ C │ Gönderildi              │
│  └───┘ [İptal]                 │
└─────────────────────────────────┘
```

### 4. Haftalık Özet

```
┌─────────────────────────────────┐
│  Bu Hafta Çevren                │
│  ─────────────                  │
│                                 │
│  En Popüler Mood                │
│  🟢 Sakin (12 seçim)            │
│                                 │
│  Ortak Şarkılar                 │
│  🎵 "Bohemian Rhapsody"         │
│     Sen, Ayşe, Mehmet           │
│                                 │
│  🎵 "Imagine"                   │
│     Sen, Zeynep                 │
│                                 │
│  Çevre Uyumu                    │
│  ████████░░ 78%                 │
│  Bu hafta çevrenle uyumlusun    │
│                                 │
│  Rozetler                       │
│  🌱 İlk Arkadaş                 │
│  🌳 Ortak Şarkı                 │
└─────────────────────────────────┘
```

### 5. Ayarlar ve Gizlilik

```
┌─────────────────────────────────┐
│  Çevre Ayarları                 │
│                                 │
│  Paylaşım                       │
│  ├─ Paylaşımı Etkinleştir [✓]  │
│  ├─ Varsayılan Davranış         │
│  │   ○ Her Gün Paylaş          │
│  │   ● Her Gün Sor             │
│  │   ○ Hiçbir Zaman            │
│  ├─ Notları Paylaş [✓]          │
│  └─ Albüm Kapaklarını Göster[✓]│
│                                 │
│  Bildirimler                    │
│  ├─ Arkadaş Daveti [ ]          │
│  ├─ Ortak Şarkı [ ]             │
│  └─ Haftalık Özet [ ]           │
│                                 │
│  Gizlilik                       │
│  ├─ Profil Görünürlüğü          │
│  │   ● Sadece Arkadaşlar       │
│  │   ○ Herkese Açık            │
│  ├─ Geçmiş Paylaşımlar          │
│  │   [Tümünü Gizle]            │
│  └─ Hesabı Sil                  │
│      [Çevre'den Ayrıl]          │
└─────────────────────────────────┘
```

## Kullanıcı Akışları

### Akış 1: İlk Kurulum
1. Çevre sekmesine tıkla
2. "Çevre'ye Hoş Geldin" ekranı
3. Gizlilik açıklaması
4. "Başla" butonu
5. CloudKit izni iste
6. Profil oluştur (otomatik)
7. Davet kodu üret
8. "Arkadaş Ekle" ekranına yönlendir

### Akış 2: Arkadaş Ekleme (Davet Kodu)
1. "Arkadaş Ekle" butonu
2. "Davet Kodu Gir" seç
3. 6 haneli kod gir
4. Kullanıcı bulundu → Önizleme
5. "Davet Gönder" butonu
6. Karşı tarafa bildirim (opsiyonel)
7. Onay bekle
8. Onaylandı → Çevre'ye eklendi

### Akış 3: Günlük Paylaşım
1. Bugün şarkı seç (normal akış)
2. Mood seç
3. Not ekle
4. Kaydet butonuna bas
5. "Çevrenle paylaş?" popup
6. Evet/Hayır/Her Zaman Sor
7. Paylaşıldı → CloudKit'e sync
8. Arkadaşların feed'inde görünür

### Akış 4: Arkadaş Seçimini Görüntüleme
1. Çevre sekmesine git
2. Arkadaş kartını gör
3. Karta tıkla
4. Detay ekranı açılır:
   - Şarkı bilgileri
   - Mood açıklaması
   - Not (varsa)
   - "Spotify'da Aç" butonu
   - "Apple Music'te Aç" butonu
5. Şarkıyı dinle (dış uygulama)

## Teknik Özellikler

### Veri Senkronizasyonu

#### Senkronizasyon Stratejisi
- **Yerel Öncelik**: Core Data her zaman kaynak
- **Seçici Sync**: Sadece `isSharedWithCircle=true` kayıtlar
- **Pull-to-Refresh**: Kullanıcı tetiklemeli güncelleme
- **Çakışma Yönetimi**: Son yazma kazanır (last-write-wins)
- **Offline Destek**: Yerel veri her zaman erişilebilir

#### Sync Zamanlaması
```
Uygulama Açılışı → Arka plan sync (sessiz)
Pull-to-Refresh → Anında sync (gösterge ile)
Yeni Paylaşım   → Anında upload
Her 30 dakika   → Otomatik kontrol (arka planda)
```

### Performans Optimizasyonu

#### Veri Yükleme
- Sadece bugünün verileri varsayılan
- Haftalık özet: Lazy loading
- Avatar resimleri: Cache
- Albüm kapakları: Opsiyonel yükleme

#### Bant Genişliği
- Minimal veri transferi
- Delta sync (sadece değişiklikler)
- Resim sıkıştırma
- Batch operations

### Güvenlik

#### CloudKit Güvenliği
- Private Database kullanımı
- CKShare ile seçici paylaşım
- Apple ID doğrulaması
- End-to-end şifreleme

#### Veri Koruması
- Keychain: Kullanıcı token'ları
- Core Data: Encryption at rest
- Network: TLS/SSL
- Validation: Server-side

## Rozetler Sistemi

### Mevcut Rozetler

#### 🌱 İlk Arkadaş
- **Koşul**: İlk arkadaşını ekle
- **Mesaj**: "Çevren oluşmaya başladı!"

#### 🌿 Beş Arkadaş
- **Koşul**: 5 arkadaş ekle
- **Mesaj**: "Çevren genişliyor!"

#### 🌳 Ortak Şarkı
- **Koşul**: Bir arkadaşınla aynı şarkıyı seç
- **Mesaj**: "Müzik ruhu birleştiriyor!"

#### 🌍 Çevre Uyumu
- **Koşul**: 7 gün üst üste benzer mood
- **Mesaj**: "Çevrenle uyum içindesin!"

#### 🎵 Yankı Arkadaşı
- **Koşul**: Bir arkadaşınla aynı şarkıyı farklı günlerde seç
- **Mesaj**: "Ortak yankılarınız var!"

#### 🌙 Sessizlik Dostu
- **Koşul**: Aynı gün hiç seçim yapmayan arkadaş
- **Mesaj**: "Sessizliği birlikte yaşadınız"

### Rozet Görünümü
```
┌─────────────────────────────────┐
│  Rozetlerin                     │
│                                 │
│  🌱 İlk Arkadaş                 │
│  23 Şubat 2026                  │
│                                 │
│  🌳 Ortak Şarkı                 │
│  25 Şubat 2026                  │
│  Ayşe ile "Imagine"             │
│                                 │
│  🔒 Beş Arkadaş                 │
│  3 arkadaş daha ekle            │
│                                 │
│  🔒 Çevre Uyumu                 │
│  5 gün daha benzer mood seç     │
└─────────────────────────────────┘
```

## Çevresel Sürdürülebilirlik

### Green Features (Opsiyonel)

#### Yerel Müzik Teşviki
- Streaming yerine yerel dosya seçimi
- "Yerel Müzik" rozeti
- Karbon ayak izi bilinci mesajları

#### Dijital Detoks
- Haftalık "Sessizlik Günü" önerisi
- Müzik seçmeme teşviki
- Farkındalık mesajları

#### Ortak Bilinç
- 3+ kişi aynı şarkıyı seçerse özel mesaj
- "Kolektif Enerji" rozeti
- Çevre uyumu vurgusu

## Hata Durumları

### Ağ Hataları
```
"Bağlantı kurulamadı"
Çevren şu anda güncellenemiyor.
Yerel veriler gösteriliyor.

[Tekrar Dene]
```

### CloudKit Hataları
```
"Senkronizasyon başarısız"
Paylaşımın kaydedildi ama
arkadaşlarına henüz ulaşmadı.

[Tekrar Dene] [Daha Sonra]
```

### İzin Hataları
```
"iCloud erişimi gerekli"
Çevre özelliği için iCloud
hesabınızla giriş yapmalısınız.

[Ayarlar'a Git] [İptal]
```

## Gelecek Özellikler

### Faz 2 (v1.1)
- [ ] Grup oluşturma (max 10 kişi)
- [ ] Haftalık playlist (ortak şarkılar)
- [ ] Mood istatistikleri (grafik)
- [ ] Export özelliği (CSV)

### Faz 3 (v1.2)
- [ ] Apple Watch desteği
- [ ] Widget (bugün çevren)
- [ ] Siri kısayolları
- [ ] SharePlay entegrasyonu

### Faz 4 (v2.0)
- [ ] Aylık özet raporu
- [ ] Yıllık "Wrapped" benzeri
- [ ] Çevre playlist'leri
- [ ] Kolaboratif özellikler

## Metrikler ve Analitik

### Takip Edilecek Metrikler
- Aktif kullanıcı sayısı
- Ortalama arkadaş sayısı
- Günlük paylaşım oranı
- Haftalık aktiflik
- Rozet kazanma oranları
- Ortak şarkı sıklığı

### Başarı Kriterleri
- %30+ kullanıcı en az 1 arkadaş ekler
- %50+ paylaşım oranı (aktif kullanıcılar)
- %20+ haftalık geri dönüş
- 4.5+ App Store puanı

## Sonuç

Çevre özelliği, ONE'ın wabi-sabi felsefesini sosyal bir boyuta taşır. Rekabet ve karşılaştırma yerine bağlantı ve farkındalık odaklı bu özellik, kullanıcıların müzik seçimlerini anlamlı bir şekilde paylaşmasını sağlar.

Minimal tasarım, güçlü gizlilik kontrolleri ve organik keşif, ONE'ın temel değerlerini korurken sosyal bir deneyim sunar.
