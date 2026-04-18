# Arşiv Takvimi Açıklaması

## 📅 Takvim Düzeni

### Hafta Başlangıcı
- Türkiye standardına göre hafta **Pazartesi** ile başlar
- Sıralama: Pzt, Sal, Çar, Per, Cum, Cmt, Paz

### Offset Hesaplaması
```swift
// iOS weekday değerleri:
// 1 = Pazar
// 2 = Pazartesi
// 3 = Salı
// 4 = Çarşamba
// 5 = Perşembe
// 6 = Cuma
// 7 = Cumartesi

// Bizim offset (Pazartesi = 0):
// Pazartesi = 0 boş hücre
// Salı = 1 boş hücre
// Çarşamba = 2 boş hücre
// Perşembe = 3 boş hücre
// Cuma = 4 boş hücre
// Cumartesi = 5 boş hücre
// Pazar = 6 boş hücre
```

### Örnek: Şubat 2026
```
Pzt Sal Çar Per Cum Cmt Paz
                          1   2
  3   4   5   6   7   8   9
 10  11  12  13  14  15  16
 17  18  19  20  21  22  23
 24  25  26  27  28
```

Şubat 2026'nın 1'i Pazar olduğu için:
- Offset = 6 (6 boş hücre)
- İlk satırda 6 boş + 2 gün (1-2)
- Toplam 28 gün

## 🎨 Görsel Gösterim

### Renk Kodları
- **Dolu Kutular**: Mood rengi ile dolu
- **Boş Kutular**: Kesik çizgi çerçeve
- **Bugün**: Siyah kalın çerçeve
- **Gün Numaraları**: Her kutunun sol üst köşesinde

### Gün Numarası Renkleri
- Dolu günler: Mood'a göre (açık/koyu)
- Boş günler: Gri (#BFBDB5)
- Bugün: Siyah (bold)

## 🔄 Dinamik Güncelleme

### Veri Yükleme
```swift
vm.loadArchiveData(context: viewContext)
```

### Tarih Normalizasyonu
- Tüm tarihler günün başlangıcına normalize edilir
- Saat bilgisi göz ardı edilir
- Karşılaştırmalar doğru çalışır

### Bugün Kontrolü
```swift
calendar.isDateInToday(date)
```

## 📱 Kullanıcı Etkileşimi

### Tıklanabilir Günler
1. **Dolu Günler**: Detay popup açılır
2. **Bugün (seçilmişse)**: Detay popup açılır
3. **Boş Günler**: Hiçbir şey olmaz

### Detay Popup İçeriği
- Şarkı adı ve sanatçı
- Mood rengi ve kelimesi
- Günlük not (varsa)
- Platform bilgisi
- Tarih (Türkçe format)
- Emoji

## 🐛 Düzeltilen Sorunlar

### Önceki Sorun
- İlk 5 gün görünmüyordu
- Offset hesaplaması yanlıştı
- `calendar.firstWeekday` varsayılan değeri kullanılıyordu

### Çözüm
```swift
// Eski (yanlış):
let offset = (firstWeekday - calendar.firstWeekday + 7) % 7

// Yeni (doğru):
let offset = (firstWeekday == 1) ? 6 : (firstWeekday - 2)
```

### Eklenen Özellikler
- Hafta günü başlıkları (Pzt, Sal, ...)
- Daha net görsel düzen
- Doğru offset hesaplaması

## 📊 Test Senaryoları

### Test 1: Şubat 2026
- 1 Şubat = Pazar
- Offset = 6
- Toplam gün = 28
- ✅ Tüm günler görünüyor

### Test 2: Mart 2026
- 1 Mart = Pazar
- Offset = 6
- Toplam gün = 31
- ✅ Tüm günler görünüyor

### Test 3: Nisan 2026
- 1 Nisan = Çarşamba
- Offset = 2
- Toplam gün = 30
- ✅ Tüm günler görünüyor

## 🎯 Sonuç

Arşiv takvimi artık:
- ✅ Tüm günleri gösteriyor
- ✅ Türkiye standardına uygun (Pazartesi başlangıç)
- ✅ Hafta günü başlıkları var
- ✅ Doğru offset hesaplaması
- ✅ Dinamik ay desteği
- ✅ Responsive tasarım
