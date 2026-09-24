# ONE 2.0 — UX Oturumu Promptları (paralel Claude Code oturumu)

Tarih: 23 Eylül 2026
Amaç: Motorlar (04, Prompt 5) bir oturumda yazılırken, ikinci bir Claude Code oturumu tasarım sistemini ve ekranları SwiftUI'da kurar. İki oturum birbirinin dosyasına dokunmaz; bağlantı en sonda yapılır (UX-11).

Kaynaklar (UX oturumunun okuyacakları):
- `docs/one2/design-system/` — marka kitabı (`README.md`), token'lar (`tokens.json`), bileşen kuralları (`components/*.md`), HTML referans önizlemeleri (`components/*.preview.html`), referans ekranlar (`components/Screen*.preview.html`), Stoic ekran görüntüleri (`ref/stoic-*.png`, yalnız yapı referansı).
- `docs/one2/ADR-001.md`, `04_arka_plan_motorlari.md` (motor API'leri, yalnız okumak için), `02_veri_modeli.md`.

---

## Sahiplik sınırları (iki oturum için bağlayıcı)

| Alan | Motor oturumu | UX oturumu |
|---|---|---|
| `one/ONE2/Content/`, `Engines/`, `Data/`, Core Data modeli | Yazar | Dokunmaz |
| `one/ONE2/Core/` | Yazar | Dokunmaz |
| `one/ONE2/App/AppEnvironment.swift` | Yazar | Dokunmaz |
| `one/ONE2/App/ONE2RootView.swift`, `Router.swift` (Route/SheetRoute case'leri) | Dokunmaz | Yazar |
| `one/ONE2/DesignSystem/` | Dokunmaz | Yazar |
| `one/ONE2/Features/` | Dokunmaz | Yazar |
| `one/ONE2/Resources/Fonts/`, Info.plist `UIAppFonts` | Dokunmaz | Yazar |
| `docs/one2/design-system/`, `CLAUDE.md` tasarım bölümü | Dokunmaz | Yazar |
| `oneTests/` | Kendi motor testleri | Kendi token/görünüm testleri, ayrı dosyalar |

Veri sözleşmesi: UX oturumu ekranları motor tiplerine değil, kendi düz **view data** struct'larına (`Features/Shared/ViewData/`) ve **fixture**'lara (`Features/Shared/Fixtures/`) göre kurar. Motor tipleri ile view data arasındaki eşleme UX-11'de, iki oturum bittikten sonra yazılır.

---

## UX-0 — Kurulum (UX oturumunun ilk mesajı)

Terminalde, Claude Code'u açmadan önce:

```bash
cd ~/Desktop/one/one
git worktree add ../one-ux -b one2/ux one2/faz1
cd ../one-ux
claude
```

Prompt:

```
Bu oturum ONE 2.0'ın UX (SwiftUI arayüz) oturumu. Aynı anda başka bir Claude Code oturumu, ayrı bir worktree'de (one2/faz1 dalı) motorları ve veri katmanını yazıyor. Biz one2/ux dalındayız.

Önce şunları oku ve bana 15 satırlık bir anlayış özeti ver, kod yazma:
- docs/one2/05_ux_promptlari.md (bu dosya; özellikle "Sahiplik sınırları")
- docs/one2/design-system/README.md ve tokens.json
- docs/one2/design-system/components/*.md (hepsi)
- docs/one2/design-system/components/Screen*.preview.html (5 referans ekran)
- docs/one2/design-system/ref/stoic-*.png (yalnız yapı referansı; içerik, maskot, logo, metin kopyalanmaz)
- docs/one2/ADR-001.md §2, §4, §7, §9
- docs/one2/04_arka_plan_motorlari.md (yalnız E2.5, E4, E5, E6, E8, E10 API'leri; biz bunları çağırmayacağız, view data'yı buna uygun tasarlayacağız)
- one/ONE2/App/ altındaki dosyalar ve CLAUDE.md

Özetinde şunlar olsun: ekran anatomisi, 5 sekme, token aileleri, tipografi rolleri, hangi dosyalara dokunabileceğin, hangilerine dokunamayacağın, view data yaklaşımı. Belirsiz gördüğün her şeyi soru olarak listele.

Kalıcı kurallar (bu oturum boyunca):
- Sahiplik tablosunun dışındaki dosyalara dokunma. Bir değişiklik gerekiyorsa dur ve sor.
- ADR §7'deki "V3Tokens TAŞI" kararı ONE 2.0 için geçersiz: yeni design system docs/one2/design-system/. Yeni kod yalnız ONE2Tokens kullanır; V3Tokens yalnız legacy "ONE 1" kartlarında.
- Hardcoded renk/boyut yok; her değer token'dan. Renkler UIColor dynamic provider ile (gece/gün + Increased Contrast).
- Her Button label'ına .contentShape(Rectangle()); işlevsiz kontrol yok; 44pt dokunma hedefi.
- Yeni SPM bağımlılığı yok. Grafikler için Apple'ın Swift Charts'ı serbest.
- Her bileşen ve ekran için #Preview: gece + gün + Dynamic Type accessibility3.
- Türkçe kopya: "sen" dili, emoji yok, en fazla bir ünlem; başlıklar küçük harf ve noktasız.
- Her adım ayrı commit; adım sonunda kısa rapor (ne yapıldı, ekran görüntüsü alınabildiyse simülatörden, açık kalan) ve dur.
```

---

## UX-1 — Token katmanı ve fontlar

```
UX-1: ONE2 token katmanını kur.

1. Fontlar: Plus Jakarta Sans (500/600/700), Literata (400, 400 italik; opsz destekli variable varsa onu), IBM Plex Mono (500). Hepsi OFL. Resmi kaynaklardan (Google Fonts GitHub repoları) indir, lisans dosyalarıyla birlikte one/ONE2/Resources/Fonts/ altına koy, Info.plist UIAppFonts'a ekle. İndiremiyorsan dur ve bana hangi dosyaları koymam gerektiğini söyle.
2. one/ONE2/DesignSystem/Tokens/:
   - ONE2Color.swift: tokens.json'daki 47 rengin hepsi, adlarıyla (ground, surface, raised, glass, line, lineStrong, ink, inkMuted, inkFaint, primary, onPrimary, brand, brandSoft, onBrand, onBrandSoft, focus, sabah, aksam, success, warning, danger, score1…5, onScore1…5, emo*, onEmo*). Tema: gece (koyu) ve gün (açık) UIColor dynamic provider ile. Increased Contrast açıkken: line → lineStrong, inkFaint → inkMuted (README Erişilebilirlik).
   - ONE2Type.swift: tokens.json type.groups'taki her stil (screenTitle, greeting, title, titleSm, headline, body, bodySm, callout, caption, prompt, journal, quote, affirmation, label, time, numeralLg). UIFontMetrics ile Dynamic Type; 24pt üstü stiller en fazla ×1.25, diğerleri serbest. label büyük harf + tracking 0.2em; time tracking 0.08em ve tabular rakam. Türkçe büyük harf için uppercased(with: Locale(identifier: "tr")).
   - ONE2Space.swift (4…56), ONE2Radius.swift (sm 12, md 18, lg 28, xl 36, pill), ONE2Shadow.swift (float, temaya göre), ONE2Motion.swift (tek eğri cubic 0.2/0.8/0.2/1; press 0.12, chip 0.18, screen 0.28, seal 0.32; Reduce Motion'da opaklık), ONE2Haptics.swift (selection, soft, success; mevcut ONEHaptics deseniyle).
3. Testler (oneTests/ONE2TokenTests.swift): README'de listelenen her metin çifti için iki temada kontrast ≥ 4.5 (mevcut ContrastTests yardımcılarını kullan), line-strong'un ground/surface üstünde ≥ 3, tokens.json'daki her rengin Swift'te karşılığı olduğunu doğrulayan test (JSON'u test bundle'ından oku).
4. DesignSystemGallery önizleme ekranı (yalnız DEBUG): tüm renkler, tüm tipografi stilleri, iki temada.
5. CLAUDE.md'nin tasarım bölümünü ONE 2.0 için güncelle: kaynak docs/one2/design-system/, ONE2Tokens kullanımı, V3Tokens yalnız legacy.

Commit, rapor, dur.
```

---

## UX-2 — Temel bileşenler

```
UX-2: one/ONE2/DesignSystem/Components/ altında temel bileşenleri yaz. Her biri için docs/one2/design-system/components/<Ad>.md kurallarını ve <Ad>.preview.html ölçülerini birebir izle.

- ONE2Pill (ikon + metin, 48pt, raised) ve ONE2RoundButton (48pt, raised, ikon)
- ONE2ButtonStyle: primary / secondary / text / danger / disabled; 52pt (kart içinde 48 varyantı), pill, basışta scale 0.97, Reduce Motion'da basış animasyonu yok
- ONE2Card (surface, radius lg, opsiyonel line çerçeve) ve ONE2OutlineCard (ground + line çerçeve)
- ONE2Glass: .ultraThinMaterial + glass tint + line iç kenar; Reduce Transparency'de raised düz zemin
- ScoreDisc (60pt ve küçük 20pt varyant, rakamlı, score renkleri, seçili halka) ve MoodPill (dolu ve çerçeveli varyant)
- EmotionChip (8 aile, seçili/seçilmemiş) ve CauseTag (çerçeveli, seçili brand-soft)
- SectionHeader (title + sağda "Tümünü gör ›" ya da ikon butonu)
- ONE2Label (mono label), TimeStamp (mono time)
- Skeleton (raised çubuklar, shimmer yok; hafif opaklık nefesi, Reduce Motion'da sabit), OfflineBanner, EmptyStateCard, ErrorLine
- SF Symbols eşlemesi: ONE2Icon enum (tab ikonları README İkonografi: sun.max, quote.opening, safari, book, chart.bar; diğerleri: flame, person.crop.circle, magnifyingglass, line.3.horizontal.decrease, chevron.down, chevron.right, plus, square.and.arrow.up, heart, paintbrush, play, slider.horizontal.3, lock, checkmark, textformat, photo, mic, music.note, tag, wifi.slash, leaf, moon)

Her bileşen: erişilebilirlik etiketi, .isSelected trait (seçilebilirlerde), 44pt hedef, #Preview (gece, gün, AX3). Bileşen başına bir dosya.

Commit, rapor, dur.
```

---

## UX-3 — Uygulama kabuğu, gezinme, view data

```
UX-3: Uygulama kabuğunu ONE 2.0 ekran diline çevir.

1. Features/Shared/ViewData/: ekranların ihtiyaç duyduğu düz struct'lar (Equatable, Sendable). En az: WeekDayState (pzt…paz, tarih, durum: done/half/gap/today/future), CheckInSummary (skor, etiket, duygular, yankı cümlesi), PracticeItem, ThemeCardData (ad, gün indeksi, soru, yazıldı mı), QuoteCardData (id, metin, kaynak, tür, arka plan, yazılma sayısı, beğenildi mi), FeaturedData, ContentCardData (tür, kategori, başlık, açıklama, kilit, rozet), HistoryDay + HistoryItem (türler: checkin, journal, quoteReflection, photo), TrendSeries, EmotionShare, StreakData, BadgeData, PlanData.
2. Features/Shared/Fixtures/: gerçekçi Türkçe örnek veriler (placeholder olduğu belli olsun), boş/az/çok veri varyantları.
3. ONE2RootView: sistem tab bar'ı gizle; alta yüzen cam TabBar (5 sekme: Bugün, Sözler, Keşfet, Yolculuk, Eğilimler; seçili sekme ground hap) ve üstünde yüzen + butonu (72×56 primary hap). İçerik cam altından kayar; her sekmenin scroll içeriğine dock yüksekliği kadar alt inset. Sekme değişiminde selection haptiği.
4. Router: Route ve SheetRoute'a yeni ekranlar (checkIn, journalEditor(context), quoteReflection(quoteID), plusMenu, paywall(source), profile, settings, themeList, contentDetail, dayDetail). Mevcut DeepLink testleri geçmeli; yeni case'ler için test ekle.
5. ScreenScaffold: üst çubuk slotları (sol/orta/sağ), büyük küçük-harf başlık (screenTitle, sol hizalı, Bugün'de yok), içerik, dock inseti, pull-to-refresh opsiyonu.
6. Plus sheet: Boş sayfa, Mood check-in, Günlük önerisi, Şablonlar, Kütüphane (sheet, radius xl, liste satırları). Şimdilik fixture'a ve boş hedef ekranlara bağlı.
7. Beş sekmenin iskelet ekranları: başlık + "yakında" değil, gerçek yerleşimde skeleton durumunda.

Commit, rapor (gece/gün iki simülatör ekran görüntüsü), dur.
```

---

## UX-4 — Bugün ekranı

```
UX-4: Features/Today/ — Bugün ekranını ScreenBugun.preview.html'e birebir kur (fixture verisiyle).

Sıra: TopBar (solda seri hapı: flame + brand renkli mono sayı; ortada greeting "iyi akşamlar"/"günaydın"/"iyi günler" saate göre; sağda profil yuvarlağı) → WeekStrip → CheckInCard → "Pratiklerin" + PracticeTile ızgarası (2 sütun, son karo "+ Ekle") → "Haftalık tema" + WeeklyThemeCard → dock boşluğu.

Durumlar (her biri #Preview):
- Check-in yok: kart içinde "Şu an nasılsın?" + ScoreScale; bir skora dokununca check-in akışını açar (UX-5).
- Check-in var: yankı cümlesi (affirmation, italik serif, ink-muted) + MoodPill.
- Sabah+akşam modu: iki kart yatay sayfalı (page indicator yok; kenardan bir sonraki kartın 16pt'si görünür).
- WeekStrip: done/half/gap/today/future; gap güne dokununca "Dün boş kaldı. İstersen şimdi doldurabilirsin." sheet'i (7 gün sınırı; daha eski günde bu satır yok).
- Tema yazıldı: "Devam et" + ilk satır önizleme.
- Seri gizli (profil ayarı): seri hapı yok.
- Yükleniyor, çevrimdışı.

Etkileşim: WeekStrip yatay kaydırma önceki haftalar; güne dokununca Bugün o günü gösterir ("Bugüne dön" hapı çıkar). PracticeTile uzun basma: sırala/kaldır menüsü.

Commit, rapor, dur.
```

---

## UX-5 — Check-in akışı

```
UX-5: Features/Checkin/ — tam ekran check-in akışı (fullScreenCover), 4 adım, üstte ince ilerleme çizgileri ve kapatma.

1. Skor: "Şu an nasılsın?" (title) + ScoreScale 1–5 (rakam + etiket: Çok zor, Zor, İdare, İyi, Çok iyi). Seçimle selection haptiği ve 300 ms sonra otomatik ileri.
2. Duygular: "Hangi duygular?" label + EmotionChip akışı (aile sırasıyla, sarılarak), "Atla" ve "Devam". En fazla seçim sınırı yok; 3'ten sonra ipucu yok.
3. Nedenler: "Ne etkiliyor?" + CauseTag + "+ Ekle" (inline alan).
4. Not (isteğe bağlı): tek satırdan büyüyen serif alan, "Kaydet".
Kapanış: yankı cümlesi ekranı (affirmation, ortada) 2 sn veya dokunuşla kapanır; ilk check-in'de "Bugün başladı." Seal varyantı.

Launch check-in: uygulama açılışında (profil ayarı açıksa, günde ilk açılışta ve bildirim/widget/deep link ile açılmadıysa) bu akış skor adımıyla açılır; kapatılabilir. Bu mantık için şimdilik ONE2RootView'da bir flag ve fixture kullan; gerçek kural motor oturumunda.

Erişilebilirlik: her adım başlığı ilk odak; skorlar "4, İyi"; VoiceOver'da otomatik ileri yerine "Devam" butonu görünür.

Commit, rapor, dur.
```

---

## UX-6 — Yazma: editör, söze yazı, kapanış

```
UX-6: Features/Journal/ — JournalEditor, QuoteReflection, Seal.

JournalEditor (tam ekran, ground zemin):
- Üstte mono bağlam etiketi (HAFTALIK TEMA · YAVAŞLIK / SÖZE YAZI / BOŞ SAYFA) ve "Bitti" (text buton).
- Soru varsa prompt stili (serif 22) ink; boş sayfada soru yok, yer tutucu "Yaz…" serif ink-faint.
- Gövde journal stili (serif 18/29), satır genişliği ~65 karakter (iPad'de ortalı sütun), imleç brand.
- Klavyenin üstüne yapışan araç hapı (raised): Biçim (kalın/italik/başlık/liste menüsü, markdown olarak saklanır), Foto (PhotosPicker), Ses (şimdilik devre dışı değil: kayıt UI'si ve fixture; işlevsiz kontrol olmasın diye ses kaydını AVAudioRecorder ile gerçekten kaydet ve Media view data'sına ekle), Şarkı (MusicKit arama sheet'i; mevcut v3 arama kodunu Features dışından çağırma, basit bir SongSearchSheet yaz, gerçek arama UX-11'de bağlanır), Etiket (CauseTag sheet) + sağda mono kelime sayısı.
- Otomatik kayıt göstergesi yok; çıkışta kaybolmaz (şimdilik bellekte, UX-11'de JournalStore).

QuoteReflection: JournalEditor üzerine üstte raised söz künyesi (serif italik söz + mono kaynak; kaydırınca tek satıra küçülür), dönen soru (sağda küçük "başka soru" dokunuşu), en altta varsa "Geçen sefer (12 Eyl): …" soluk satır → dokununca önceki yazı sheet'i.

Seal: "Bitti" → 96pt brand disk + tik (0.9→1.0 + opaklık, 320 ms, .soft haptik), "bugün kapandı." (ya da bağlama göre "yazın kaydedildi."), serif italik özet (kelime sayısı, tür), altında WeekStrip ve bugünün hücresinin tike dönmesi; rozet kazanıldıysa tek satır. 2 sn sonra ya da dokunuşla kapanır. Konfeti, ses yok.

Commit, rapor, dur.
```

---

## UX-7 — Sözler

```
UX-7: Features/Quotes/ — Sözler sekmesi (ScreenSozler.preview.html).

- Üst çubuk: solda mod hapı "Sana özel ⌄" (menü: Sana özel, yollar, türler: Olumlama/Söz/Atasözü/Düşünce, Beğendiklerin, Yazdıkların; premium yollar kilitli ikonlu ve paywall açar); sağda fırça (arka plan seçici sheet: fotoğraf seti yer tutucu + düz renk + kullanıcı fotoğrafı), oynat (slayt modu: 6 sn'de bir sonraki, ekran açık kalır), ara.
- İçerik: dikey sayfalı tam ekran QuoteCard (radius xl; ScrollView + .scrollTargetBehavior(.paging)); kart ekranın dock üstüne kadar.
- Kart: tür ikonu, quote stili beyaz metin (arka plan üzerinde okunurluk için alt/üst karartma degradesi, kontrast ≥ 4.5 garanti), mono kaynak, "Bu söze 2 kez yazdın" rozeti (varsa), alt çubuk: paylaş (ImageRenderer ile 1080×1920 görsel + ShareLink), "Bunun hakkında yaz" (QuoteReflection açar), kalp (beğeni + selection haptiği).
- ÖNEMLİ, motor sözleşmesi: her kart için görünürlük ölçümü yap. Kart ≥%60 görünür ve ≥1,2 sn kaldıysa onSeen(id, dwell) geri çağrısı; hızlı geçilen kart için onSkipped(id). Bu iki çağrıyı QuotesViewModel'de bir protokol (QuoteFeedActions) üzerinden dışarı ver; şimdilik fixture uygulaması log basar. Birim testi: görünürlük ölçer mantığı saf fonksiyon olarak test edilir.
- Kuyruk bitince fixture'dan yenisi (sayfalama); mod tükendiyse EmptyState: "Bu yolun hepsini gördün." + diğer yollar.
- Günün sözü kartı Bugün'de değil, Sözler'in ilk kartıdır (bugün ilk açılışta).

Commit, rapor, dur.
```

---

## UX-8 — Keşfet

```
UX-8: Features/Explore/ — Keşfet (ScreenKesfet.preview.html).

- Üst: sağda ara; başlık "keşfet".
- FeaturedCard (iki sütun, sol görsel alanı yer tutucu çizim, sağda tarih, başlık, açıklama, "Başla ›").
- Satırlar (yatay kaydırılan, SectionHeader'lı): Sana özel, Haftalık temalar (geçmiş temalar), Rehberli günlükler, Sabah, Akşam, Duygu check-in'i, Söz koleksiyonları.
- ContentCard: kemer görsel (tür rengine göre sabah/aksam/raised), kilit, mono rozet (YENİ/ÖNE ÇIKAN), kategori, başlık, 2 satır açıklama, "···" menü (favorilere ekle, paylaş).
- İçerik detayı: rehberli günlük tanıtım sayfası (başlık, adım sayısı, süre, "Başla") → rehberli akış (adım adım JournalEditor varyantı, üstte ilerleme).
- Kilitli içerik → PaywallView(source: "explore").
- Arama: tüm içerik + sözler, sonuçlar türe göre gruplu.

Commit, rapor, dur.
```

---

## UX-9 — Yolculuk ve Eğilimler

```
UX-9: Features/Journey/ ve Features/Insights/.

Yolculuk (ScreenYolculuk.preview.html):
- Üst: sağda dönem hapı (Günler/Haftalar/Aylar/Yıllar), filtre (tür, etiket, skor, sözler), ara. Başlık "yolculuk".
- Günler: gün başlığı ("Bugün, 23 Eyl ›", "Dün", "21 Eyl Pazartesi") + HistoryCard'lar: check-in (çerçeveli MoodPill + duygular), günlük (ilk 3 satır serif), söze yazı (sol çizgili söz alıntısı + cevap), fotoğraf anısı (tam genişlik görsel, mono saat), legacy "ONE 1" kartı (V3Mood rengiyle; LegacyMomentStore view data'sı fixture).
- Haftalar/Aylar: takvim ızgarası, gün hücresinde skor rengi noktası ve yazı işareti; aya dokununca o ayın listesi. Yıllar: 12 ay mini ızgara.
- Girdi detayı: tam metin, medya, etiketler, soru/söz künyesi, düzenle, sil (onay sheet'i), "Aynı soruya diğer cevapların" bölümü (değişim çifti).
- Boş durum: "İlk sayfa bugün yazılacak." + Yaz.

Eğilimler (ScreenEgilimler.preview.html):
- Üst: dönem hapı (14 gün/30 gün/Aylar/Yıllar). Başlık "eğilimler", altında label "GENEL İÇGÖRÜLER".
- Kartlar: Mood çizgisi (Swift Charts; score renkli noktalar, bugünkü nokta halkalı, mono eksen), Duygu dağılımı (yatay çubuklar, emo renkleri, mono yüzde), Etiket ilişkisi ("Uyku etiketli günlerde ortalama 2,8"), Yazma istatistikleri (girdi, kelime, en uzun seri — numeralLg), Geçen yıl bugün, Değişim çiftleri.
- Veri yetersiz: kart "Henüz erken — 5 check-in daha" durumu; hiç veri yoksa çerçeveli kart + ScoreScale.
- Premium kilitli kartlar bulanık değil: başlık + kısa açıklama + "ONE+ ile aç".

Commit, rapor, dur.
```

---

## UX-10 — Onboarding, Paywall, Profil ve Ayarlar

```
UX-10: Features/Onboarding/, Features/Paywall/, Features/Profile/.

Onboarding (ilk açılış, 6–8 ekran, geri dönülebilir):
1. Karşılama: wordmark + tek cümle ("Her gün biraz yaz, zamanla kendini oku.") + "Başla".
2. Odak alanları (çoklu seçim, chip): kaygı, odak, minnet, uyku, ilişkiler, özgüven, yas, yaratıcılık.
3. Söz yolları (en az 1): Filozof, Sakin, Cesur, Şefkatli, Üretken — her birinde bir örnek söz.
4. Ritüel modu: Günde bir kez / Sabah ve akşam + saat seçiciler.
5. Bildirim izni ön ekranı (kendi ekranımız, sonra sistem izni).
6. İlk check-in (UX-5 akışı, gömülü).
7. Paywall (atlanabilir, "Ücretsiz devam et" görünür).
8. İlk yazı daveti: haftanın tema sorusu → JournalEditor → Seal. Onboarding burada biter.
Ad sorusu isteğe bağlı (selamlama için).

Paywall: üstte tek cümle değer vaadi + 3 madde; PlanCard'lar (yıllık seçili, deneme etiketi), "Denemeyi başlat", ücretin ne zaman çekileceği satırı, Geri yükle, koşullar/gizlilik linkleri. StoreKit bağlantısı UX-11'de; şimdilik PlanData fixture.

Profil: ad, seri ve rozet özeti, Rozetler (3'lü ızgara), ONE+ durumu. Ayarlar: ritüel modu ve saatleri, bildirim türleri (tek tek), seri görünürlüğü, açılış check-in'i, yazılan sözlerin geri dönmesi, tema (sistem/gece/gün), uygulama kilidi (Face ID), dışa aktarma (JSON / Markdown), iCloud durumu, destek, sürüm.

Commit, rapor, dur.
```

---

## UX-11 — Bağlama (iki oturum da bitince, tek oturumda)

```
UX-11: one2/ux dalını one2/faz1'e birleştir (çakışma varsa sahiplik tablosuna göre çöz, emin olmadığında sor). Sonra her ekran modelini motorlara bağla:

- Features/*/…ViewModel'ler AppEnvironment'tan motorları alır; motor tiplerini ViewData'ya eşleyen adaptörler Features/Shared/Adapters/ altında, her biri birim testli.
- QuoteFeedActions → QuoteEngine.markSeen / record; günün sözü, kuyruk, mod tükenmesi.
- Check-in → MoodStore + EchoEngine; Bugün → DayCompletion/Streak, ThemeCalendar, PromptEngine; + menü → RecommendationEngine.
- Editör → JournalStore (+ ExposureStore wroteAbout); Seal → BadgeEngine.
- Yolculuk → JournalStore/MoodStore/LegacyMomentStore + SearchIndex; Eğilimler → InsightsEngine.
- Paywall → EntitlementStore / StoreKit 2; Ayarlar → UserProfileStore, NotificationOrchestrator.
- Fixtures yalnız #Preview ve testlerde kalır.

Uçtan uca elle test senaryosu yaz (docs/one2/QA_senaryolari.md): ilk kurulum → onboarding → ilk check-in → ilk yazı → Sözler'de 30 kart (tekrar yok) → söze yazı → ertesi gün seri → bir gün boş bırak → doldur → Eğilimler.
```

---

## Paralel çalışma notları

- İki oturumu aynı anda açık tut; motor oturumu `~/Desktop/one/one` (one2/faz1), UX oturumu `~/Desktop/one/one-ux` (one2/ux).
- Xcode'da aynı anda yalnız bir worktree'yi aç (DerivedData karışmasın); simülatör testleri sırayla.
- Model (xcdatamodeld) değişikliği yalnız motor oturumunda. UX oturumu bir alana ihtiyaç duyarsa isteği `docs/one2/UX_istekleri.md`'ye yazar, motor oturumuna sen iletirsin.
- Günde bir kez UX dalına faz1'i rebase et (UX-3 sonrası Router testleri çakışabilir).
