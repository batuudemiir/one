# v4 duruşu — kalan kod işi

*9 Eylül 2026. Bildirim mimarisi ve marka sesi zaten uygulanmış
(`e70f464` ve öncesi). Bu dosya **duruş** katmanının kodda kalan karşılığı.*

Duruş ve dört ilke: `CLAUDE.md` → "Duruş".
Bağlam: `~/Desktop/one/ONE_v4_Marka_Platformu.md`.

Sıra öncelik sırasıdır. Her madde bağımsız commit.

---

## 1 — What's New'daki iki ihlal · CANLI, kullanıcı görüyor

`one/UI/WhatsNewView.swift` + `notif`/`whatsNew` katalog anahtarları.

### 1a. Kilometre taşları kartı

```
whatsNew.milestones.title = "Kilometre taşları"
whatsNew.milestones.body  = "Neyi açtığını ve sırada ne olduğunu\nprofilinden görebilirsin."
```

İki ayrı sorun:

- **Duruş ihlali.** Kilitli–açık ödül sistemi ilke 2'yi çiğniyor ve
  `CLAUDE.md` → Yapılmayacaklar listesinde. Ölü `milestones.*` anahtarları
  arasında `milestones.streakThreshold = "%d günlük seri"` bile duruyor —
  seri motoru sökülmüşken.
- **Var olmayan özellik.** Profilde milestone ekranı yok; kodda sadece
  `WhatsNewView` referansı var. Kart olmayan bir şeyi tanıtıyor.

**Yap:** kartı `WhatsNewView`'dan kaldır. `whatsNew.milestones.*` ve
`milestones.*` anahtarlarını dokuz dilden sil.

### 1b. Haftalık hedef kartı

```
whatsNew.weekly.title = "Haftalık ritim"
whatsNew.weekly.body  = "Hedef her gün değil, haftada dört gün.\nKaçırdığın günü sonradan doldurabilirsin."
```

Üç sorun:

- **"Hedef"** bir ölçüm — ilke 2.
- **"Kaçırdığın günü doldur"** boş günü bir borç gibi sunuyor — ilke 3.
- **Yalan.** Kod geriye dönük girişe zaten izin vermiyor:
  `V3DayDetailView` CTA'yı yalnız `isToday` iken render ediyor. Kart
  olmayan bir davranışı vaat ediyor.

**Karar: geriye dönük giriş yok, olmayacak.** Boşluk kalıcıdır; arşiv
doğru olduğu için değerli, tamamlandığı için değil.

**Yap:** kartı `WhatsNewView`'dan tamamen kaldır, `whatsNew.weekly.*`
anahtarlarını dokuz dilden sil. Yerine yeni kart koyma — söylenecek bir
şey yok.

`archive.dayEmpty.past = "O gün boş."` doğru davranışın hâli hazırdaki
karşılığı. Dokunma.

---

## 2 — Yankı'daki sıralama dili

`one/Features/Echo/EchoV3Sections.swift`

| Anahtar | Şu an | Sorun | v4 |
|---|---|---|---|
| `echo.stat.mostActiveDay` | En aktif gün | "En aktif" bir sıralama ve bir başarı ölçüsü | `En çok an bırakılan gün` → daha iyisi: `Yoğun gün` |
| `echo.section.summary` | Kısa özet | "Özet" yorum vaat eder | `Sayılar` |
| `echo.section.topTracks` | EN ÇOK DİNLENENLER | Sıralama dili | `TEKRAR EDENLER` |

`echo.factualLine` (`%1$d an · en sık %2$@`) doğru kalıp — olgu, yorum yok.
Yeni satır eklerken bunu örnek al.

`echo.stat.totalMoments` ("Toplam an") ve `echo.stat.silentDays`
("Sessiz gün") kalır: ikisi de olgu, ölçüm değil. Özellikle "Sessiz gün"
ilke 3'ün iyi bir uygulaması — boşluğu isimlendiriyor, suçlamıyor.

---

## 3 — Dışa aktarmayı birinci sınıf yap · ilke 4

Şu an iki rakip anahtar var ve ikisi de ayarların dibinde:

```
profile.exportData  = "Verilerimi Dışa Aktar"
settings.exportData = "veriyi dışa aktar"     ← küçük harf, casing kuralı ihlali
```

**Yap:**
- Tek anahtara indir. Etiket cümle düzeni: `Arşivi dışa aktar`.
- Profil'de gizli bir satır olmaktan çıkar — Ayarlar'ın üst grubuna al.
- Yanına tek satır olgu: `Tüm kayıtların, tek dosyada.` Gizlilik vaazı yok.

---

## 4 — Küçük harf başlıklar · casing kuralı

`CLAUDE.md` → Kopya kuralları: "Küçük harfle başlayan başlık yok."
`voice_guard.py` bunu denetlemiyor. Canlı ihlaller:

```
echoes.title            = "bugüne gelenler"
echoes.reactors         = "karşılık verenler"
echoes.replyPlaceholder = "yanıt"
echoes.empty            = "henüz karşılık yok. gün ilerledikçe belirebilir."
echoes.ephemeralNote    = "gelen karşılıklar arşivlenmez — anlık kalır"
echoes.someone          = "biri"
settings.exportData     = "veriyi dışa aktar"
```

**Yap:** başlık ve etiketleri cümle düzenine çevir (placeholder metinleri
küçük kalabilir — onlar başlık değil). Sonra `voice_guard.py`'ye casing
denetimi ekle: canlı bir anahtarın değeri küçük harfle başlıyorsa ve
anahtar `*.placeholder` / `*.hint` değilse hata ver.

---

## 5 — Ölü anahtar temizliği · 923 / 1627

Türkçe katalogdaki anahtarların **%57'si kodda çağrılmıyor.** Dokuz dilde
aynı ölü kütle duruyor. `voice_guard.py` ölü anahtarları bilerek atlıyor —
doğru karar, ama borç birikiyor: ölü anahtarlar arasında `milestones.*`,
`today.title = "Bugünün şarkısını seç"`, `onboarding.slogan`,
`echo.stats.streakDays = "gün seri"` gibi v4'ün reddettiği metinler var.
Bir gün biri bunları yeniden bağlarsa ses geri geliyor.

Öncelikli olarak silinecek ölü gruplar — hepsi v4'ün reddettiği
mekanikleri anlatıyor ve biri yeniden bağlarsa ürün geri geliyor:

```
milestones.*                  kilitli–açık ödül sistemi
comeback.*                    "istersen doldur", "bugünü işaretle"
onboarding.notif.freezeHint   "serin sıfırlanmaz — haftada bir freeze hediye"
echo.stats.streakDays         "gün seri"
today.title                   "Bugünün şarkısını seç"
onboarding.slogan             "Hisset. Keşfet. Paylaş."
```

**Yap:**
1. `tooling/dead_keys.py` yaz — canlı/ölü ayrımını `voice_guard.py` ile
   aynı yöntemle çıkarsın, tek kaynak olsun.
2. Ölüleri dokuz dilden sil. Xcode'un `NSLocalizedString` dışı
   çağrılarını (String Catalog, storyboard, `LocalizedStringKey`
   literal'ları) kaçırmadığından emin ol — silmeden önce `--dry-run`
   çıktısını gözden geçir.
3. Silme commit'ini ayrı at ki geri alması kolay olsun.

---

## 6 — "Sana özel" vaadi

```
song.preparingSuggestions = "Sana özel öneriler hazırlanıyor"
```

"Sana özel", uygulamanın kullanıcıyı çözümlediğini ima ediyor. Şarkı
önerisi bir kolaylık; kişilik okuması değil.

**Yap:** `Öneriler hazırlanıyor.`

---

## Bitince

- `tooling/ui_guard.sh` ve `python3 tooling/voice_guard.py` temiz geçmeli.
- Katalog metni değiştiyse ve anahtar `notif.push.*` ise
  `CloudKitNotificationService.currentSubVersion` artırılmalı.
- `CLAUDE.md` → Duruş bölümünü değiştirmen gerekirse önce sor: o bölüm
  marka platformundan türetildi, kod tarafında serbestçe değiştirilmez.
