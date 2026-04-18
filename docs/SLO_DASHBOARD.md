# ONE — SLO / Sağlık Paneli

Ürün yayına çıktıktan sonra haftalık olarak bakılması gereken ölçüler. Kaynaklar: Sentry (crash), PostHog (product analytics), App Store Connect (rating + install).

## Hedefler (SLO)

| Metrik | Hedef | Kaynak | Sıklık |
|---|---|---|---|
| Crash-free oturumlar | ≥ %99.5 | Sentry | Günlük |
| Crash-free kullanıcılar | ≥ %99.8 | Sentry | Haftalık |
| Onboarding tamamlama | ≥ %65 | PostHog funnel: `onboarding_started` → `onboarding_completed` | Haftalık |
| İlk gün kayıt (D0) | ≥ %55 | PostHog: `onboarding_completed` → `entry_saved` aynı gün | Haftalık |
| 7-gün retention | ≥ %35 | PostHog cohort | Haftalık |
| 30-gün retention | ≥ %15 | PostHog cohort | Aylık |
| Davet kabul oranı | ≥ %25 | PostHog: `friend_invite_sent` → `friend_request_accepted` | Haftalık |
| App Store rating | ≥ 4.5 | App Store Connect | Haftalık |
| P50 render süresi (Today) | ≤ 300 ms | Sentry Performance | Haftalık |

## Funnel'lar (PostHog)

**Onboarding**
1. `onboarding_started`
2. `platform_selected`
3. `onboarding_completed`

**İlk kayıt**
1. `onboarding_completed`
2. `song_searched` veya `song_selected`
3. `mood_selected`
4. `entry_saved`

**Circle büyümesi**
1. `circle_opened`
2. `friend_invite_sent`
3. `friend_request_accepted` (başka kullanıcıda)

**Keşfet etkileşimi**
1. `discover_opened`
2. `recommendation_tapped`

## Alarmlar

Eşik altına düşerse Slack / e-posta bildirimi:

- Crash-free < %99 (24 saat içinde)
- Yeni crash grubu > 10 kullanıcıyı etkiliyor (Sentry)
- Onboarding tamamlama < %50 (7 günlük)
- Günlük aktif kullanıcı haftaya göre > %20 düşüş

## Haftalık ritüel (Pazartesi 30 dk)

1. Sentry → yeni crash grupları, bir önceki haftaya göre regresyon var mı?
2. PostHog → tüm funnel'lar, drop-off noktaları
3. Retention cohort → 7-gün / 30-gün trendi
4. App Store Connect → yeni review'lar, yıldız ortalaması
5. Badge unlock dağılımı (`badge_unlocked` event) → erişilemez olan var mı?
6. Sprint backlog güncelle: 1 hijyen + 1 feature + 1 ölçüm işi

## Sprint ritmi

2 haftalık iterasyon. Her sprint sonunda:
- Build'i TestFlight'a at
- Release note'u `Docs/ONE_Release_Notes.md` altına ekle
- Bir sonraki sprintin SLO alarm listesini gözden geçir

## Aylık otomatik rapor

Cron job veya Sentry/PostHog'un e-posta aboneliği — her ayın 1'inde:
- Önceki ay crash-free oranı
- DAU/MAU ve oranı
- En çok tetiklenen 5 event
- Yeni badge unlock sayıları (7 rozet için breakdown)
- App Store rating değişimi
