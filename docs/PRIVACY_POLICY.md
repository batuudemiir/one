# 🔒 Gizlilik Politikası - ONE Çevre Özelliği

**Son Güncelleme:** 23 Şubat 2026

## Genel Bakış

ONE uygulaması, kullanıcılarının gizliliğini en üst düzeyde korumayı taahhüt eder. Çevre (Circle) özelliği, arkadaşlarınızla müzik seçimlerinizi paylaşmanıza olanak tanırken, verilerinizin güvenliğini ve gizliliğini korur.

## Toplanan Veriler

### Kişisel Bilgiler
- **Apple ID**: CloudKit entegrasyonu için (Apple tarafından yönetilir)
- **Görünen Ad**: Arkadaşlarınıza gösterilir (isteğe bağlı)
- **Davet Kodu**: Benzersiz 6 haneli kod (otomatik üretilir)

### Müzik Verileri
- Şarkı adı
- Sanatçı adı
- Tür
- Albüm kapağı URL'i
- Platform (Spotify/Apple Music)

### Duygusal Veriler
- Mood seçimi (8 seçenek)
- Günlük not (isteğe bağlı, max 3 kelime)
- Seçim tarihi ve saati

### Sosyal Veriler
- Arkadaş listesi
- Arkadaşlık durumu (pending/accepted/blocked)
- Paylaşım tercihleri

## Veri Kullanımı

### Birincil Kullanım
Toplanan veriler yalnızca şu amaçlarla kullanılır:
- Günlük müzik seçimlerinizi kaydetmek
- Arkadaşlarınızla seçimlerinizi paylaşmak
- Arşiv ve analiz özellikleri sunmak
- Uygulama deneyimini iyileştirmek

### Paylaşım Kontrolü
- **Varsayılan**: Paylaşım KAPALI
- **Kullanıcı Kontrolü**: Her paylaşım için onay
- **Seçici Paylaşım**: Sadece seçtiğiniz arkadaşlar
- **İptal Hakkı**: İstediğiniz zaman durdurabilirsiniz

## Veri Depolama

### Yerel Depolama (Core Data)
- Tüm verileriniz önce cihazınızda saklanır
- iOS şifreleme ile korunur
- Sadece sizin erişiminiz vardır
- iCloud yedekleme (opsiyonel)

### Bulut Depolama (CloudKit)
- Sadece paylaştığınız veriler CloudKit'e gider
- Apple'ın Private Database kullanılır
- End-to-end şifreleme
- Apple'ın güvenlik standartları

### Veri Saklama Süresi
- Aktif hesap: Süresiz
- Hesap silme: 30 gün içinde tamamen silinir
- Paylaşım durdurma: Anında CloudKit'ten kaldırılır

## Veri Paylaşımı

### Kimlerle Paylaşılır?
- **Sadece Arkadaşlarınız**: Eklediğiniz ve onayladığınız kişiler
- **Apple**: CloudKit altyapısı için (şifreli)
- **Üçüncü Taraflar**: HİÇBİR ZAMAN

### Paylaşılmayan Veriler
- Spotify/Apple Music giriş bilgileri
- Cihaz bilgileri
- Konum bilgileri
- Kişiler listesi (izin vermediğiniz sürece)
- Kullanım istatistikleri

## Üçüncü Taraf Entegrasyonlar

### Spotify
- **OAuth 2.0**: Güvenli giriş
- **Token Saklama**: Keychain (şifreli)
- **Veri Erişimi**: Sadece şarkı arama ve bilgi
- **Paylaşım**: Spotify ile veri paylaşımı YOK

### Apple Music
- **MusicKit**: Apple'ın resmi API'si
- **İzinler**: Sadece müzik kütüphanesi okuma
- **Veri**: Apple'ın gizlilik politikası geçerli

### CloudKit
- **Sağlayıcı**: Apple Inc.
- **Şifreleme**: End-to-end
- **Konum**: Apple veri merkezleri
- **Uyumluluk**: GDPR, KVKK

## Kullanıcı Hakları

### Erişim Hakkı
- Tüm verilerinizi görüntüleyebilirsiniz
- Export özelliği (CSV formatı)
- Arşiv ekranından erişim

### Düzeltme Hakkı
- Görünen adınızı değiştirebilirsiniz
- Geçmiş paylaşımları gizleyebilirsiniz
- Notları düzenleyebilirsiniz (yakında)

### Silme Hakkı
- Tek tek kayıtları silebilirsiniz
- Tüm paylaşımları durdurabilirsiniz
- Hesabınızı tamamen silebilirsiniz

### Taşınabilirlik Hakkı
- Verilerinizi export edebilirsiniz
- JSON veya CSV formatı
- Tüm kayıtlar dahil

### İtiraz Hakkı
- Paylaşımı istediğiniz zaman durdurabilirsiniz
- Arkadaşları engelleyebilirsiniz
- Çevre özelliğini devre dışı bırakabilirsiniz

## Güvenlik Önlemleri

### Teknik Güvenlik
- **Şifreleme**: AES-256 (yerel), TLS 1.3 (ağ)
- **Kimlik Doğrulama**: Apple ID (2FA destekli)
- **Token Yönetimi**: Keychain (iOS)
- **API Güvenliği**: OAuth 2.0, HTTPS

### Organizasyonel Güvenlik
- Minimal veri toplama prensibi
- Düzenli güvenlik denetimleri
- Olay müdahale planı
- Veri ihlali bildirimi (24 saat içinde)

### Kullanıcı Güvenliği
- İki faktörlü kimlik doğrulama (Apple ID)
- Davet kodu sistemi (spam önleme)
- Engelleme özelliği
- Raporlama mekanizması

## Çocukların Gizliliği

ONE uygulaması 13 yaş ve üzeri kullanıcılar içindir. 13 yaş altı çocuklardan bilerek veri toplamıyoruz. Ebeveyn onayı olmadan 13 yaş altı kullanıcıların hesapları silinir.

## Çerezler ve İzleme

ONE uygulaması:
- ❌ Çerez kullanmaz
- ❌ Reklam izleyicisi kullanmaz
- ❌ Analitik izleyicisi kullanmaz
- ❌ Üçüncü taraf SDK'ları kullanmaz
- ✅ Sadece temel uygulama fonksiyonları

## Veri İhlali Prosedürü

Veri ihlali durumunda:
1. **24 saat içinde**: Etkilenen kullanıcılara bildirim
2. **48 saat içinde**: Yetkili kurumlara bildirim
3. **7 gün içinde**: Detaylı rapor ve önlemler
4. **Şeffaflık**: Tüm süreç hakkında bilgilendirme

## Yasal Uyumluluk

### GDPR (Avrupa)
- Veri minimizasyonu
- Açık rıza
- Unutulma hakkı
- Veri taşınabilirliği

### KVKK (Türkiye)
- Aydınlatma yükümlülüğü
- Açık rıza
- Veri güvenliği
- Silme ve anonim hale getirme

### CCPA (California)
- Veri toplama bildirimi
- Opt-out hakkı
- Veri satışı yasağı (zaten yapmıyoruz)

## Değişiklikler

Bu gizlilik politikası güncellenebilir. Önemli değişiklikler:
- Uygulama içi bildirim
- E-posta bildirimi (varsa)
- 30 gün önceden duyuru
- Kabul etmeme hakkı

## İletişim

Gizlilik ile ilgili sorularınız için:

**E-posta**: privacy@oneapp.com  
**Adres**: [Şirket Adresi]  
**Veri Sorumlusu**: [İsim]  
**DPO**: [Veri Koruma Görevlisi]

## Hesap Silme

Hesabınızı silmek için:

1. Ayarlar > Çevre > Hesabı Sil
2. Onay ver
3. 30 gün içinde tüm veriler silinir
4. Geri alınamaz

Veya e-posta ile: delete@oneapp.com

## Özel Durumlar

### Yasal Zorunluluk
Sadece yasal zorunluluk durumunda (mahkeme kararı) verileriniz paylaşılabilir. Bu durumda:
- Sizi bilgilendiririz (yasal olarak mümkünse)
- Sadece talep edilen minimum veri
- Şeffaflık raporu (yıllık)

### Şirket Devri
Şirket satışı veya birleşmesi durumunda:
- 60 gün önceden bildirim
- Aynı gizlilik standartları
- Opt-out hakkı

## Onay

ONE uygulamasını kullanarak bu gizlilik politikasını kabul etmiş olursunuz. Kabul etmiyorsanız, uygulamayı kullanmayınız ve hesabınızı siliniz.

---

**Son Güncelleme:** 23 Şubat 2026  
**Versiyon:** 1.0  
**Geçerlilik:** Tüm ONE kullanıcıları

## Ek Kaynaklar

- [Apple Gizlilik Politikası](https://www.apple.com/legal/privacy/)
- [CloudKit Güvenlik](https://support.apple.com/en-us/HT202303)
- [Spotify Gizlilik](https://www.spotify.com/privacy)
- [KVKK Mevzuatı](https://kvkk.gov.tr/)
