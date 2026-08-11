# ONE — PostHog Analiz Dashboard Blueprint

Bu dosya, PostHog'da (EU sunucusu, `eu.posthog.com`) kurulacak **tam kapsamlı ürün
sağlığı dashboard'unun** birebir tarifidir. Her tile için: insight tipi, event(ler),
filtre, breakdown, dönüşüm penceresi ve görselleştirme yazılı. Sırayla tıklayarak
kurabilirsin.

> **Kapsam notu:** Bu dashboard yalnızca **davranışsal event**'leri ölçer. Kullanıcının
> girdiği ham içerik (not metni, foto, şarkı adı) PostHog'a **gitmez** — her kullanıcının
> private CloudKit'inde kalır. Buradaki mood değerleri kısa `rawValue`'lardır, PII değildir.

---

## 0) Kurulum temeli

1. PostHog → sol menü **Dashboards → New dashboard** → ad: **"ONE — Ürün Sağlığı"**.
2. Her tile için: **New insight** → tip seç (Trends / Funnel / Retention) → aşağıdaki
   tarifi uygula → **Save & add to dashboard**.
3. Dashboard üstünde global **date range** ve **breakdown** filtreleri tüm tile'lara işler.
4. Her event'e otomatik `days_since_install` property'si ekleniyor
   (bkz. `PostHogAnalyticsService.track`) — aktivasyon/segment filtrelerinde kullan.

**Önce şu 8 tile'ı kur (Core 8 — en kritik):** T1, T2, T3, T4, T7, T11, T17, T24.
Gerisi zenginleştirme.

---

## 1) Event durumu (kaynak: kod taraması, 2026-08-04)

**CANLI (34)** — dashboard bunları kullanır:
`onboarding_started`, `onboarding_step_viewed`, `onboarding_mood_picked`,
`onboarding_first_color_picked`, `onboarding_music_connected`, `onboarding_notif_soft_ask`,
`onboarding_completed`, `mood_picked_before_label`, `mood_label_revealed`, `mood_selected`,
`song_searched`, `song_selected`, `photo_added`, `note_added`, `entry_saved`,
`entry_backfilled`, `pass_button_tapped`, `week_rhythm_completed`, `streak_freeze_consumed`,
`notif_permission_prompted`, `notif_permission_result`, `smart_notification_scheduled`,
`platform_selected`, `circle_opened`, `friend_request_sent`, `friend_request_accepted`,
`friend_share_viewed`, `first_entry_invite_hook_shown`, `first_entry_invite_hook_action`,
`discover_opened`, `recommendation_tapped`, `event_tapped`, `badge_unlocked`,
`launch_metric_report`.

**ÖLÜ (18)** — kodda tanımlı ama tetiklenmiyor; dashboard'a KOYMA (boş çıkar):
`friend_invite_sent`, `mutual_disclosure_blur_shown`, `mutual_disclosure_blur_converted`,
`weekly_color_story_viewed`, `weekly_color_story_shared`, `story_card_shared`,
`monthly_poster_shared`, `entry_milestone_reached`, `milestone_card_shared`,
`retro_entry_added`, `playlist_opened`, `user_blocked`, `user_unblocked`,
`comment_created`, `comment_edited`, `comment_deleted`, `comment_reported`,
`comment_author_profile_opened`. → Bölüm 9'a bak.

---

## 2) Bölüm A — Kuzey Yıldızı & Özet (üst satır, büyük sayılar)

### T1 — Günlük aktif giriş (DAU-entry) ⭐
- **Tip:** Trends · **Event:** `mood_selected` · **Ölçüm:** Unique users
- **Aralık:** Son 30 gün · **Görsel:** Line
- **Neden:** `mood_selected` her kayıtta (legacy + v3 şarkısız, ikisi de) tetiklenir →
  gerçek günlük aktif giriş sayısı. (`entry_saved` v3 şarkısız yolu kaçırıyor, bkz. Bölüm 8.)

### T2 — Toplam giriş hacmi ⭐
- **Tip:** Trends · **Event:** `mood_selected` · **Ölçüm:** Total count · Line

### T3 — D1 / D7 retention ⭐
- **Tip:** Retention · **Cohortizing event:** `onboarding_completed`
- **Returning event:** `mood_selected` · **Period:** Daily · **Görsel:** Retention table
- **Neden:** Kuzey yıldızı. "Onboarding'i bitiren ertesi gün geri gelip giriş yapıyor mu?"

### T4 — Aktivasyon oranı (ilk 3 günde ≥2 giriş) ⭐
- **Tip:** Funnel · **Adım 1:** `onboarding_completed` · **Adım 2:** `entry_saved`
  filtre `entry_index = 2` · **Conversion window:** 3 gün
- **Not:** `entry_saved` v3 şarkısız yolu saymadığı için bu bir alt-sınırdır; Bölüm 8
  düzeltilirse netleşir.

---

## 3) Bölüm B — Onboarding Funnel

### T5 — Ana onboarding funnel ⭐
- **Tip:** Funnel · **Conversion window:** 1 saat
- **Adımlar:**
  1. `onboarding_started`
  2. `onboarding_step_viewed` · filtre `step = auth`
  3. `onboarding_step_viewed` · filtre `step = mood`
  4. `onboarding_step_viewed` · filtre `step = song`
  5. `onboarding_step_viewed` · filtre `step = notif`
  6. `onboarding_completed`
- **Breakdown (son adım):** `music_platform` → platforma göre tamamlama farkı.

### T6 — Adım-adım düşüş (tüm 9 adım)
- **Tip:** Funnel · Her adım `onboarding_step_viewed` + `step` filtresi:
  `intent → trust → auth → mood → song → reward → circle → notif`, son adım
  `onboarding_completed`. · Window 1 saat.
- **Neden:** Hangi mikro-adımda damladığını nokta atışı gösterir.

### T7 — Onboarding mood dağılımı ⭐
- **Tip:** Trends · **Event:** `onboarding_mood_picked` · **Ölçüm:** Total count
- **Breakdown:** `mood` · **Görsel:** Pie / Bar
- **Neden:** Kullanıcılar ONE'a girerken hangi ruh halinde? (Tamamlamadan bağımsız.)

### T8 — Onboarding'de şarkı bağlama oranı
- **Tip:** Trends · **Event:** `onboarding_music_connected` · Breakdown `granted`
  (true/false) · Bar

### T9 — Bildirim soft-ask opt-in
- **Tip:** Trends · **Event:** `onboarding_notif_soft_ask` · Breakdown `opt_in` · Bar

### T10 — Platform seçimi (onboarding çıkışı)
- **Tip:** Trends · **Event:** `onboarding_completed` · Breakdown `music_platform` · Pie

---

## 4) Bölüm C — Aktivasyon & Alışkanlık

### T11 — Install → ilk giriş funnel ⭐
- **Tip:** Funnel · **Adım 1:** `onboarding_completed` · **Adım 2:** `mood_selected`
  · **Conversion window:** 3 gün

### T12 — Kaçıncı giriş dağılımı (derinlik)
- **Tip:** Trends · **Event:** `entry_saved` · Breakdown `entry_index` · Bar
- **Neden:** Kullanıcılar 2., 3., 5. girişe ne kadar ilerliyor.

### T13 — Haftalık ritim (4+ gün dolan hafta)
- **Tip:** Trends · **Event:** `week_rhythm_completed` · Breakdown `filled_days` · Bar

### T14 — Telafi/geri-tarihli giriş
- **Tip:** Trends · **Event:** `entry_backfilled` · Breakdown `days_ago` · Line+Bar

### T15 — "Bugün geçti" (pass) kullanımı
- **Tip:** Trends · **Event:** `pass_button_tapped` · Total count · Line

### T16 — Streak freeze devreye girme
- **Tip:** Trends · **Event:** `streak_freeze_consumed` · Total count · Line

---

## 5) Bölüm D — Günlük Giriş İçeriği

### T17 — Günlük mood dağılımı (tüm girişler) ⭐
- **Tip:** Trends · **Event:** `mood_selected` · Breakdown `mood` · Bar (veya stacked area, zaman içi)
- **Not:** `mood_selected`, `mood_label_revealed`, `onboarding_mood_picked` aynı
  ONEMood key uzayını (`atesli, isikli, enerjik, taze, sakin, nostaljik, ozgur, derin,
  uzgun, stresli, yorgun`) kullanır → breakdown'lar birbiriyle karşılaştırılabilir.

### T18 — Foto ekleme: oran + kaynak
- **Tip A (oran):** Trends · A: `photo_added` (unique users), B: `mood_selected`
  (unique users) → formül `A/B`.
- **Tip B (kaynak):** Trends · `photo_added` · Breakdown `method` (camera vs library) · Pie

### T19 — Not ekleme: oran + uzunluk
- **Tip A:** Trends · `note_added` count / `mood_selected` count (formül).
- **Tip B (uzunluk):** Trends · `note_added` · Y ekseni: property value `length`
  ortalaması; ayrıca P50/P90 için ayrı seri.

### T20 — Şarkı arama → seçim funnel
- **Tip:** Funnel · **Adım 1:** `song_searched` · **Adım 2:** `song_selected`
  · Window 1 saat · **Breakdown:** `source` (apple vs spotify)

### T21 — Giriş mikro-funnel (renk → kayıt)
- **Tip:** Funnel · Window 1 saat
  1. `mood_picked_before_label`
  2. `mood_label_revealed`
  3. `song_selected` *(opsiyonel adım)*
  4. `entry_saved`

---

## 6) Bölüm E — Bildirim İzni

### T22 — İzin prompt → sonuç funnel
- **Tip:** Funnel · **Adım 1:** `notif_permission_prompted` · **Adım 2:**
  `notif_permission_result` filtre `granted = true` · Window 1 gün

### T23 — Akıllı bildirim saati dağılımı
- **Tip:** Trends · **Event:** `smart_notification_scheduled` · Breakdown `hour` · Bar
- **Neden:** Kişiselleştirilmiş hatırlatma en çok hangi saate kilitleniyor.

---

## 7) Bölüm F — Sosyal / Çevre

### T24 — Davet kancası funnel ⭐
- **Tip:** Funnel · **Conversion window:** 7 gün
  1. `first_entry_invite_hook_shown`
  2. `first_entry_invite_hook_action` · filtre `action = invite`
  3. `friend_request_sent`
  4. `friend_request_accepted`
- **Neden:** Viral döngünün sağlığı. Kabul (`accepted`) zamana yayıldığı için 7 gün.

### T25 — Çevre etkileşimi
- **Tip:** Trends (çoklu seri) · `circle_opened`, `friend_share_viewed`,
  `friend_request_sent`, `friend_request_accepted` · Line

---

## 8) Bölüm G — Keşfet & Rozetler

### T26 — Keşfet etkileşimi
- **Tip:** Trends (çoklu seri) · `discover_opened`, `recommendation_tapped`, `event_tapped`
- **Breakdown fikri:** `recommendation_tapped` → `source`; `event_tapped` → `category`.

### T27 — Rozet açılımları
- **Tip:** Trends · **Event:** `badge_unlocked` · Breakdown `badge_id` · Bar

---

## 9) Bölüm H — Performans (teknik)

### T28 — Uygulama açılış süresi
- **Tip:** Trends · **Event:** `launch_metric_report` · Y: property `p50_ms` ve `p95_ms`
  ortalaması (iki seri) · Breakdown `is_resume` (cold vs warm) · Line
- **Neden:** MetricKit histogram özeti; regresyon erken yakalanır.

---

## 10) Kurulacak Cohort'lar (Persons → Cohorts)

- **Aktive kullanıcılar:** `entry_saved` yapmış AND `entry_index >= 2` AND
  `days_since_install <= 3`.
- **Onboarding tamamlayanlar:** `onboarding_completed` performed.
- **Sessiz kullanıcılar (dormant):** `onboarding_completed` var, son 7 günde
  `mood_selected` yok → win-back hedefi.

---

## 11) Bilinen boşluklar / dikkat

1. **`entry_saved`, v3 şarkısız çoklu-an yolunu saymıyor.** Sadece legacy + şarkılı
   kayıtta tetikleniyor (`TodayViewModel.saveEntry`). Bu yüzden **toplam giriş hacmi için
   `mood_selected` kullan** (her iki yolda da tetikleniyor). `entry_saved` yalnızca
   `has_photo` / `has_note` / `entry_index` kırılımları için güvenilir.
   → İstenirse `saveV3Entry` şarkısız koluna da `entry_saved` eklenip tutarlı hale getirilebilir.
2. **Mood key uzayı:** Tüm mood event'leri `bridgedMood.rawValue` / `MoodOption.key`
   (ONEMood uzayı) yayınlar. V3Mood.rawValue (`mutlu, coskulu…`) DEĞİL. Breakdown'larda
   `atesli, isikli, nostaljik…` göreceksin — bu doğru ve tutarlı.
3. **`days_since_install`** her event'te var; aktivasyon pencerelerinde filtre olarak kullan.

---

## 12) Bölüm I — ÖLÜ event'ler (Phase 2 — bağlanınca açılacak tile'lar)

Şu event'ler tanımlı ama call-site'ı yok; bağlanırsa aşağıdaki tile'lar açılır:

| Event | Açılacak tile | Nereye bağlanmalı |
|-------|---------------|-------------------|
| `story_card_shared`, `monthly_poster_shared`, `weekly_color_story_shared/viewed` | Paylaşım hunisi & yüzey dağılımı | Story/poster paylaş aksiyonları |
| `entry_milestone_reached`, `milestone_card_shared` | Milestone (100/200/365) & paylaşım | Milestone tetikleme + paylaş |
| `mutual_disclosure_blur_shown/converted` | Blur → giriş dönüşümü | Çevre blur gösterimi |
| `friend_invite_sent` | Davet yöntemi kırılımı (code/link/contact) | Davet gönderme aksiyonu |
| `retro_entry_added` | Geriye dönük giriş | Retro giriş kaydı |
| `playlist_opened` | Playlist açılma | Keşfet playlist tap |
| `comment_*`, `user_blocked/unblocked` | — | **Kaldırılan yorum özelliği** — muhtemelen silinecek (bkz. efemer tepki sistemi) |

---

_Bu dosya kod tarafındaki event envanterinden türetilmiştir. Yeni event eklendikçe
Bölüm 1 ve ilgili tile güncellenmeli._
