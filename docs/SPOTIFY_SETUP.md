# Spotify Entegrasyonu Kurulum Rehberi

## 🎵 Spotify Developer Hesabı Oluşturma

1. [Spotify Developer Dashboard](https://developer.spotify.com/dashboard)'a gidin
2. Spotify hesabınızla giriş yapın
3. "Create an App" butonuna tıklayın
4. Uygulama bilgilerini doldurun:
   - **App Name**: ONE Music App
   - **App Description**: Günlük müzik seçimi uygulaması
   - **Redirect URI**: `one://spotify-callback`
5. "Save" butonuna tıklayın

## 🔑 Client ID'yi Uygulamaya Ekleme

1. Dashboard'da oluşturduğunuz uygulamaya tıklayın
2. "Settings" butonuna tıklayın
3. **Client ID**'yi kopyalayın
4. Xcode'da `one/one/SpotifyManager.swift` dosyasını açın
5. Şu satırı bulun:
   ```swift
   private let clientID = "YOUR_SPOTIFY_CLIENT_ID"
   ```
6. `YOUR_SPOTIFY_CLIENT_ID` yerine kopyaladığınız Client ID'yi yapıştırın:
   ```swift
   private let clientID = "abc123def456..." // Sizin Client ID'niz
   ```

## ✅ Redirect URI ve PKCE Ayarları

Spotify Developer Dashboard'da:
1. Uygulamanızın Settings sayfasına gidin
2. "Redirect URIs" bölümüne şunu ekleyin: `one://spotify-callback`
3. **ÖNEMLİ**: "Android Package Name" veya "iOS Bundle ID" bölümünü boş bırakın
4. Sayfayı aşağı kaydırın ve "Edit Settings" butonuna tıklayın
5. "Which API/SDKs are you planning to use?" bölümünde "Web API" seçeneğini işaretleyin
6. "Save" butonuna tıklayın

### PKCE Desteği
Uygulama artık PKCE (Proof Key for Code Exchange) kullanıyor. Bu sayede:
- Client Secret'a ihtiyaç yok
- Mobil uygulamalar için daha güvenli
- Spotify'ın önerdiği yöntem

## � Kullanım

1. Uygulamayı çalıştırın
2. Arama ekranında "Spotify" sekmesine tıklayın
3. "Spotify ile Giriş Yap" butonuna tıklayın
4. Tarayıcıda Spotify'a giriş yapın ve izinleri onaylayın
5. Uygulama otomatik olarak açılacak ve artık Spotify'dan arama yapabileceksiniz

## 🔒 Güvenlik Notları

- Client ID public bir bilgidir ve kodda saklanabilir
- PKCE kullanıldığı için Client Secret'a ihtiyaç yoktur
- Access token güvenli bir şekilde Keychain'de saklanır
- Token süresi dolduğunda kullanıcının tekrar giriş yapması gerekir

## ⚠️ ÖNEMLİ: Yaygın Hatalar ve Çözümleri

### "Invalid client secret" Hatası
Bu hata artık düzeltildi. Uygulama PKCE kullanıyor ve client secret gerektirmiyor.

### "response_type must be code" Hatası
1. SpotifyManager.swift dosyasında `response_type=code` kullanıldığından emin olun
2. Spotify Dashboard'da Redirect URI'nin tam olarak `one://spotify-callback` olduğunu kontrol edin
3. Dashboard'da "Edit Settings" > "Redirect URIs" > "Add" > "Save" yapın
4. Uygulamayı tamamen kapatıp yeniden başlatın

## � Sorun Giderme

### "Spotify'a giriş yapılamıyor"
- Client ID'nin doğru girildiğinden emin olun
- Redirect URI'nin Spotify Dashboard'da eklendiğinden emin olun
- Redirect URI'nin tam olarak `one://spotify-callback` olduğundan emin olun
- Uygulamayı tamamen kapatıp yeniden başlatın

### "Arama sonuç vermiyor"
- Spotify'a giriş yaptığınızdan emin olun
- İnternet bağlantınızı kontrol edin
- Uygulamayı kapatıp tekrar açmayı deneyin
- Terminal'de hata mesajlarını kontrol edin

## � Test Modu

Spotify uygulamanız "Development Mode"da ise:
- Sadece Spotify Dashboard'da eklediğiniz kullanıcılar giriş yapabilir
- Dashboard'da "Users and Access" bölümünden test kullanıcıları ekleyebilirsiniz
- Production'a geçmek için Spotify'dan onay almanız gerekir

## 🎨 Özellikler

✅ Spotify'dan şarkı arama
✅ PKCE ile güvenli authentication
✅ Albüm kapağı gösterimi
✅ Sanatçı ve şarkı bilgileri
✅ Güvenli token saklama
✅ Otomatik platform değiştirme
✅ Apple Music ile birlikte kullanım

## 📝 Notlar

- Spotify entegrasyonu sadece arama için kullanılır
- Şarkıları çalmak için Spotify Premium gerekmez
- Kullanıcılar Apple Music ve Spotify arasında kolayca geçiş yapabilir
- Her iki platform da aynı anda kullanılabilir
- PKCE sayesinde client secret'a ihtiyaç yoktur
