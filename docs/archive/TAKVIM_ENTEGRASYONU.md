# iOS Takvim Entegrasyonu

## 📅 Genel Bakış

ONE uygulaması, günlük şarkı seçimlerinizi iOS Takvim uygulamasına otomatik olarak kaydeder. Bu sayede:
- Takvim uygulamasından günlük şarkılarınızı görebilirsiniz
- Diğer cihazlarınızda (iCloud senkronizasyonu ile) erişebilirsiniz
- Hatırlatıcılar ve bildirimler ayarlayabilirsiniz
- Müzik geçmişinizi takvim görünümünde takip edebilirsiniz

## 🔐 İzinler

### Gerekli İzin
- **Takvim Erişimi**: Etkinlik oluşturmak ve güncellemek için

### İzin İsteme
İlk şarkı kaydında uygulama otomatik olarak takvim izni isteyecektir:
```
"Günlük şarkı seçimlerinizi takviminize kaydetmek için izin gereklidir."
```

### İzin Yönetimi
- İzin verilmezse: Şarkılar sadece ONE uygulamasında saklanır
- İzin verilirse: Şarkılar hem ONE'da hem Takvim'de saklanır
- İzni sonradan değiştirmek için: Ayarlar > ONE > Takvim

## 🎵 Etkinlik Formatı

### Başlık
```
🎵 [Şarkı Adı]
```

Örnek: `🎵 Last Last`

### Notlar
```
Sanatçı: [Sanatçı Adı]
Ruh Hali: [Mood Kelimesi]
Not: [Kullanıcı Notu] (varsa)

ONE ile kaydedildi
```

Örnek:
```
Sanatçı: Burna Boy
Ruh Hali: Ateşli
Not: Harika bir gün

ONE ile kaydedildi
```

### Tarih ve Süre
- **Tür**: Tüm gün etkinliği
- **Başlangıç**: Seçilen günün 00:00
- **Bitiş**: Seçilen günün 23:59
- **Tekrar**: Yok

## 🔄 Senkronizasyon

### Otomatik Senkronizasyon
Şarkı kaydedildiğinde:
1. Core Data'ya kaydedilir
2. Takvim izni kontrol edilir
3. İzin varsa takvime eklenir
4. Başarı mesajı gösterilir

### Güncelleme
Aynı gün için yeni şarkı seçilirse:
1. Mevcut etkinlik bulunur
2. Bilgiler güncellenir
3. Eski etkinlik silinmez, güncellenir

### Silme
Şarkı silinirse (gelecek özellik):
1. Core Data'dan silinir
2. Takvim etkinliği de silinir

## 📱 Kullanım Senaryoları

### Senaryo 1: İlk Kullanım
1. Şarkı seç ve kaydet
2. Takvim izni iste
3. İzin ver
4. Etkinlik oluşturuldu ✅

### Senaryo 2: İzin Verilmedi
1. Şarkı seç ve kaydet
2. Takvim izni iste
3. İzin verme
4. Sadece ONE'da kaydedildi ⚠️

### Senaryo 3: Güncelleme
1. Bugün için şarkı seçilmiş
2. Yeni şarkı seç
3. Takvim etkinliği güncellendi ✅

### Senaryo 4: Geçmiş Günler
1. Arşivden eski bir gün seç
2. Şarkı değiştir (gelecek özellik)
3. Takvim etkinliği güncellendi ✅

## 🎨 Takvim Görünümü

### iOS Takvim Uygulamasında
```
┌─────────────────────────┐
│ 23 Şubat 2026          │
├─────────────────────────┤
│ 🎵 Last Last           │
│ Tüm gün                │
│                         │
│ Sanatçı: Burna Boy     │
│ Ruh Hali: Ateşli       │
│ Not: Harika bir gün    │
│                         │
│ ONE ile kaydedildi     │
└─────────────────────────┘
```

### Ay Görünümü
```
Şubat 2026
Pzt Sal Çar Per Cum Cmt Paz
                          1
  2   3   4   5   6   7   8
  9  10  11  12  13  14  15
 16  17  18  19  20  21  22
 23  24  25  26  27  28
 🎵  🎵  🎵  🎵  🎵  🎵  🎵
```

## 🔧 Teknik Detaylar

### EventKit Framework
```swift
import EventKit

let eventStore = EKEventStore()
```

### İzin İsteme
```swift
let granted = try await eventStore.requestAccess(to: .event)
```

### Etkinlik Oluşturma
```swift
let event = EKEvent(eventStore: eventStore)
event.title = "🎵 \(songName)"
event.isAllDay = true
event.startDate = startOfDay
event.endDate = endOfDay
try eventStore.save(event, span: .thisEvent)
```

### Etkinlik Bulma
```swift
let predicate = eventStore.predicateForEvents(
    withStart: startOfDay,
    end: endOfDay,
    calendars: nil
)
let events = eventStore.events(matching: predicate)
```

## 🌐 iCloud Senkronizasyonu

### Otomatik Senkronizasyon
Takvim etkinlikleri iCloud ile otomatik senkronize edilir:
- iPhone → iPad
- iPhone → Mac
- iPhone → Apple Watch

### Gereksinimler
- iCloud hesabı aktif
- Takvim senkronizasyonu açık
- İnternet bağlantısı

## 🐛 Sorun Giderme

### Etkinlik Görünmüyor
1. Takvim izni verilmiş mi? → Ayarlar > ONE > Takvim
2. iCloud senkronizasyonu açık mı? → Ayarlar > [İsim] > iCloud > Takvim
3. Doğru takvim seçili mi? → Takvim uygulaması > Takvimler

### Etkinlik Çoğaldı
- ONE her gün için sadece bir etkinlik oluşturur
- Çoğalma varsa manuel silme gerekebilir
- "ONE ile kaydedildi" notuna sahip etkinlikleri arayın

### İzin Değiştirme
1. Ayarlar > ONE
2. Takvim > Aç/Kapat
3. Uygulamayı yeniden başlat

## 📊 Veri Akışı

```
Kullanıcı Şarkı Seçer
        ↓
Core Data'ya Kaydet
        ↓
Takvim İzni Var mı?
    ↙        ↘
  Evet       Hayır
    ↓          ↓
Takvime    Sadece
Ekle       ONE'da
    ↓          ↓
Başarı    Uyarı
Mesajı    Mesajı
```

## 🎯 Gelecek Özellikler

### Planlanan
- [ ] Takvim senkronizasyonu açma/kapama ayarı
- [ ] Farklı takvim seçimi
- [ ] Hatırlatıcı ekleme
- [ ] Renk kodlama (mood'a göre)
- [ ] Toplu import/export
- [ ] Geçmiş günleri düzenleme

### Değerlendiriliyor
- [ ] Widget'ta takvim entegrasyonu
- [ ] Siri kısayolları
- [ ] Apple Watch senkronizasyonu

## 💡 İpuçları

1. **Düzenli Kullanım**: Her gün şarkı seç, takvimin dolsun
2. **iCloud Yedekleme**: Takvim verilerini iCloud'da yedekle
3. **Farklı Cihazlar**: Tüm Apple cihazlarında erişim
4. **Arama**: Takvim uygulamasında şarkı adı ile ara
5. **Paylaşım**: Takvim etkinliklerini arkadaşlarınla paylaş

## 🔒 Gizlilik

- Takvim verileri sadece cihazınızda ve iCloud'unuzda
- ONE sunucularına gönderilmez
- Üçüncü parti erişim yok
- İstediğin zaman silebilirsin

## 📞 Destek

Takvim entegrasyonu ile ilgili sorun yaşarsan:
1. Ayarlar > ONE > Takvim iznini kontrol et
2. Uygulamayı yeniden başlat
3. iOS güncellemelerini kontrol et
4. Gerekirse uygulamayı yeniden yükle

---

**Not**: Takvim entegrasyonu opsiyoneldir. İzin vermezsen şarkılar sadece ONE uygulamasında saklanır.
uygulamanın girişine wabi-sabi felsefesine uygun bir giriş ekranı ekleyelim minimalist animasyonlu