# ADR-002 — ONE 2.0 tasarım sistemi

Tarih: 23 Eylül 2026 · Durum: kabul edildi · Etkilediği: ADR-001 §2, §4, §7

## Bağlam

ADR-001 yazıldığında ONE 2.0'ın görsel dili belli değildi; §7 v3 tasarım
sistemini (`V3Tokens`, v3 kabukları) taşıyıp token değerlerini değiştirmeyi
öngörüyordu. Sonra `docs/one2/design-system/` sıfırdan yazıldı: yeni renk,
yazı yüzü, bileşen ve ekran dili (Stoic yapısı, koyu-öncelikli, yüzen cam tab
bar). İkisi çelişiyor; **design system kazanır**. ADR-001 düzenlenmez, bu
kayıt onun ilgili maddelerini geçersiz kılar.

## Karar

| ADR-001 maddesi | Eski karar | Yeni karar |
|---|---|---|
| §2 Kod yerleşimi: `DesignSystem/` "yalnız YENİ bileşenler (tokenlar `one/UI/DesignSystem`'de kalır)" | Token'lar v3 klasöründe | Token'lar `one/ONE2/DesignSystem/Tokens/` (`ONE2Color`, `ONE2Type`, `ONE2Space`, `ONE2Radius`, `ONE2Shadow`, `ONE2Motion`, `ONE2Haptics`); bileşenler `one/ONE2/DesignSystem/Components/` |
| §2 Fontlar | Tanımsız (v3 fontları) | Plus Jakarta Sans, Literata, IBM Plex Mono; `one/ONE2/Resources/Fonts/` |
| §4 Navigasyon: kök `TabView` | Sistem tab bar'ı | `TabView` seçim durumu kalabilir ama sistem tab bar'ı gizli; alta yüzen cam `TabBar` + üstünde + hapı (`TabBar.md`) |
| §4 Navigasyon: başlık `V3TopBar` / `SubScreen` kabuklarından | v3 kabukları | ONE2 `TopBar` (hap ve 48pt yuvarlak slotlar) + `screen-title` başlık; `ScreenScaffold` |
| §7 **"TAŞI: `V3Tokens` …"** | v3 token, tipografi, ikon, animasyon, haptik, buton, kabuk ve durum bileşenleri taşınır | **Geçersiz.** Yeni kod yalnız ONE2 token ve bileşenlerini kullanır. `V3Tokens`, `V3Typography`, `ONETypography`, v3 kabukları yalnız legacy yüzeylerde ("ONE 1" kartları, eski arayüz) |
| §7 "Görsel dil değişirse token değerleri değişir; adlar ve yapı kalır" | `paper`/`ink`/`surface` adları korunur | Token adları ve yapısı `tokens.json`'dan (`ground`, `surface`, `raised`, `ink` …); v3 adlarıyla eşleme yok |
| §7 `V3Mood` | Yalnız legacy kartlarda | Değişmedi |
| §7 1–5 skor renkleri `V3Tokens`'a eklenir | `V3Tokens` | `ONE2Color.score1…5` ve `onScore1…5` |
| §7 duygu renkleri `EmotionPalette` | Ayrı palet tipi | `ONE2Color.emo*` ve `onEmo*` (8 aile) |
| §7 Yeni bileşen listesi (`MoodScalePicker`, `EmotionChipGrid`, `StreakBadge` …) | ADR adları | Adlar ve kurallar `design-system/components/*.md`'den (`ScoreScale`, `EmotionChip`, `CauseTag`, `WeekStrip`, `Seal` …). ADR'deki "üç durum, 44pt, `.contentShape(Rectangle())`" kuralı geçerli |
| §7 `ONEHaptics`, `ONEAnimation` taşınır | v3 tipleri | `ONE2Haptics` (aynı desen), `ONE2Motion` (tek eğri, 4 süre) |

## Sonuçlar

- `V3Tokens` ONE 2.0'a **taşınmaz**; relaunch sonrası v3 silinirken legacy
  kartların ihtiyaç duyduğu parçalar ayrıca değerlendirilir.
- `ONE2/**` hâlâ `one/UI/DesignSystem/*` import edebilir (ADR-001 §2
  izolasyon kuralı), ama yalnız legacy kartlar için.
- Kontrast ve token eşlemesi `oneTests/ONE2TokenTests.swift` ile korunur.
