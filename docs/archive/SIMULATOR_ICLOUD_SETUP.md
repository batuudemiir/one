# Simülatörde iCloud ve CloudKit Kurulumu

## Sorun
Simülatörde "iCloud erişimi gerekli" hatası alıyorsanız, aşağıdaki adımları takip edin.

## Çözüm Adımları

### 1. Simülatörde iCloud Hesabı Ekleyin
1. Simülatörü açın
2. **Settings (Ayarlar)** > **Apple ID** (en üstte)
3. iCloud hesabınızla giriş yapın
4. **iCloud** > **iCloud Drive**'ı açın

### 2. CloudKit Container'ı Kontrol Edin
1. Xcode'da projeyi açın
2. **Signing & Capabilities** sekmesine gidin
3. **iCloud** capability'sinin ekli olduğundan emin olun
4. **CloudKit** ve **iCloud Documents** seçili olmalı
5. Container: `iCloud.com.batu.ones` olmalı

### 3. Simülatörü Sıfırlayın (Gerekirse)
```bash
# Tüm simülatörleri sıfırla
xcrun simctl erase all

# Veya sadece belirli bir simülatörü
xcrun simctl erase "iPhone 15"
```

### 4. Uygulamayı Temiz Kurulum
1. Xcode'da: **Product** > **Clean Build Folder** (Cmd+Shift+K)
2. Simülatörden uygulamayı silin
3. Yeniden derleyin ve çalıştırın

### 5. Debug Loglarını Kontrol Edin
Uygulamayı çalıştırdığınızda Console'da şu logları göreceksiniz:

```
🔵 CloudKit Account Status Check:
   Status: 0 (Available)
   Available: true
   ✅ No errors
   ✅ User Record ID: _xxxxxxxxxxxxx
```

Eğer farklı bir durum görüyorsanız:
- **Status: 1 (No Account)** → iCloud hesabı eklenmemiş
- **Status: 2 (Restricted)** → iCloud kısıtlamaları var
- **Status: 3 (Could Not Determine)** → Ağ sorunu veya geçici hata

### 6. Gerçek Cihazda Test Edin
Simülatörde sorun devam ederse, gerçek cihazda test edin:
1. iPhone'unuzu Mac'e bağlayın
2. Xcode'da cihazı seçin
3. Uygulamayı çalıştırın

## Yeni Özellikler

### Tekrar Dene Butonu
Artık "iCloud erişimi gerekli" ekranında **Tekrar Dene** butonu var. Bu buton:
- CloudKit durumunu yeniden kontrol eder
- iCloud hesabı ekledikten sonra uygulamayı yeniden başlatmadan denemenizi sağlar

### Debug Bilgisi
Debug modunda (Xcode'dan çalıştırırken) ekranda CloudKit durumu hakkında bilgi gösterilir.

## Sık Karşılaşılan Sorunlar

### "Could not fetch user record" Hatası
- iCloud hesabı var ama CloudKit container'a erişim yok
- Çözüm: Signing & Capabilities'i kontrol edin

### Telefonda Çalışıyor, Simülatörde Çalışmıyor
- Normal bir durum, simülatör bazen CloudKit'i düzgün simüle edemiyor
- Çözüm: Gerçek cihazda test edin

### "Temporarily Unavailable" Durumu
- Apple sunucularında geçici sorun olabilir
- Çözüm: Birkaç dakika bekleyip tekrar deneyin

## Notlar
- Simülatör her zaman gerçek cihaz gibi davranmayabilir
- Production testleri için mutlaka gerçek cihaz kullanın
- CloudKit Dashboard'da container'ın Development environment'ının aktif olduğundan emin olun
