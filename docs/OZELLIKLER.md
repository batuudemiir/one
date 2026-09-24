# ONE Uygulaması — Özellikler Özeti

**Slogan:** *Hisset. Keşfet. Paylaş.*

ONE; günlük müziğini, ruh halini ve fotoğrafını kaydettiğin, arşivine dönüp baktığın ve çevrendeki arkadaşların bugünkü paylaşımlarını gördüğün sosyal bir mood uygulamasıdır.

## Çekirdek Vaatler

- **Hisset** — bugünün şarkısını seç, mood'unu ve kısa notunu bırak
- **Keşfet** — mood'una göre etkinlik önerileri ve yeni müzik akışlarını gör
- **Paylaş** — fotoğrafını, şarkını ve bugünkü halini çevrende paylaş

---

## 🎵 Temel Özellikler

### Günlük Şarkı Seçimi
- Her gün bir şarkı seç
- Seçim yaptıktan sonra o gün değiştirilemez (anı dondurma)
- Ertesi gün taze seçim hakkı

### Platform Desteği

**Apple Music**
- MusicKit entegrasyonu, gerçek zamanlı arama
- Albüm kapakları, ilk açılışta izin

**Spotify**
- OAuth 2.0, token Keychain'de
- Spotify Web API, universal link callback (`ones://spotify-callback`)

### Mood ve Feeling Sistemi
- 8 mood rengi ve kelimesi (Ateşli, Enerjik, Işıklı, Sakin, Derin, Gizemli, Boş, Temiz)
- Her mood için özel renk, açık/koyu tema desteği
- İsteğe bağlı kısa günlük not
- İsteğe bağlı fotoğraf

### Günlük Kart
- Mood + Şarkı + Fotoğraf + Not
- Otomatik takvim entegrasyonu (EventKit)
- Live Activity + Widget gösterimi

---

## 🌍 Çevre (Circle) — Sosyal Paylaşım

- Davet kodu (`ones://add-friend?code=XXXXXX`) veya universal link (`one.forvibe.app/invite?code=XXXXXX`)
- Kişiler entegrasyonu ile davet
- Günlük paylaşımlar: arkadaşların bugünkü mood + şarkı + fotoğrafı
- Mood Resonance: arkadaşın seninle aynı mood seçtiğinde bildirim
- Arkadaş kaldırma, engelleme
- Tam gizlilik kontrolü (paylaşım toggle'ı gün bazında)
- CloudKit (iCloud) üzerinden güvenli senkronizasyon

---

## 🔍 Keşfet (Discover) — Mood Bazlı Öneriler

- Bugünkü mood'a göre **etkinlik** önerileri (Ticketmaster entegrasyonu, şehir filtreli)
- Haftalık kişisel **müzik çalma listesi** (Apple Music & Spotify kaynaklı)
- Mood Explorer: her mood için derinleştirilmiş içerik
- Öneri önbelleği, offline desteği

---

## 📅 Arşiv

- Aylık ve yıllık takvim görünümü
- Dolu günler mood rengiyle, boş günler kesik çizgiyle
- Gün detayı: şarkı, sanatçı, mood, not, fotoğraf, platform
- Türkçe tarih formatı, 9 dil lokalizasyonu

---

## 🔄 Yankı (Echo) — Pattern Analizi

- Tekrar eden şarkılar ve sanatçılar
- Frekans yüzdesi, zaman çizgisi
- En çok seçilen insight kartı
- Aylık özet paylaşılabilir poster kartı (Instagram Story, paylaşım sheet)

---

## 📸 Paylaşım

- Instagram Story kartları (mood + şarkı + fotoğraf)
- Aylık özet posteri (Top Tracks, Mood Map, Cover)
- Universal share sheet, QR davet kodu ile viral çekirdek

---

## 🔔 Bildirimler

Push notification kategorileri:
- `FRIEND_REQUEST` — arkadaşlık isteği (Kabul / Reddet aksiyonlu)
- `STREAK_WARNING` — streak tehlikede hatırlatıcısı
- `WEEKLY_SUMMARY` — haftalık Yankı özeti
- `DISCOVERY_REMINDER` — Keşfet hatırlatıcısı
- `FRIEND_SHARED` — arkadaş paylaşım yaptı
- `MOOD_RESONANCE` — arkadaşla aynı mood rezonansı

Akıllı günlük hatırlatıcı kullanıcının geçmiş kayıt saatine göre optimize edilir.

---

## 💾 Veri ve Gizlilik

### Yerel
- Core Data (`one.xcdatamodeld`) — `DailyEntry` entity
- Bir gün bir entry (TodayViewModel enforced)

### Bulut
- CloudKit public + private DB
- Spotify token Keychain'de
- Onboarding + profile flag'ler Keychain'de (reinstall survive)

### Gizlilik
- Kamera, rehber, takvim izinleri açıkça istenir (Info.plist açıklamalı)
- Paylaşım tamamen opt-in, kişi bazlı kontrol
- Hesap silme + veri export (Profil → Ayarlar)

---

## 🎨 Tasarım Sistemi

- `ONETokens` — renkler, spacing, corner radii
- `ONETypography` — DMSans tabanlı ölçekler (display / mono)
- `ONEAnimation` — tutarlı animasyon süreleri ve eğrileri
- `ONEMood` — 8 mood rengi ve metadatası
- Dark mode desteği, 9 dil lokalizasyonu (tr, en, de, fr, es, ru, ja, ko, zh-Hans)

---

## 📱 Platform Genişlemeleri

- **MoodWidget** — Home screen widget (bugünkü mood gösterimi)
- **Live Activity** — Dynamic Island + Lock Screen
- Universal links (`one.forvibe.app`)
- Deep links (`ones://`)

---

## 🚀 Yol Haritası

**Yakın dönem:**
- CloudKit production deploy
- Spotify Extended Quota onayı
- TestFlight beta → App Store yayını
- Analytics + crash reporting altyapısı

**v2:**
- Yıllık özet (Echo)
- Rozet sistemi
- Apple Watch companion
- Taste profile export (JSON/PDF)

Detay için: [IMPLEMENTATION_ROADMAP.md](IMPLEMENTATION_ROADMAP.md), [CEVRE_FEATURE.md](CEVRE_FEATURE.md)
