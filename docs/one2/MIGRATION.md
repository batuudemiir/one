# ONE 2.0 — Eski veri ve model sürümü analizi

Tarih: 23 Eylül 2026 · Faz 0, Prompt 2 · Salt okuma (ürün dosyası değiştirilmedi)
Girdiler: `AUDIT.md`, `02_veri_modeli.md` v0.2. Kodda doğrudan görülmeyen çıkarımlar **(tahmin)** diye işaretli.

## 1. Seçenek B' — somut tasarım

B': `DailySong` hiç kopyalanmaz ve değiştirilmez. ONE 2.0 onu salt okunur okur ve Yolculuk'ta "ONE 1" kartları olarak gösterir.

### 1.1 Okuma katmanı

| Parça | Karar | Gerekçe / kaynak |
|---|---|---|
| Satır → değer dönüşümü | **`Moment(from:)` olduğu gibi kullanılır** | KVC ile okuyor, `Sendable` struct üretiyor, `id` yoksa deterministik `derivedID` türetiyor, hex'i `V3Mood`'a eşliyor (`one/Core/Models/Moment.swift`) |
| Gün gruplama | **`Day` olduğu gibi kullanılır** | `moments`, `fillHexes`, `count` Yolculuk kartı için yeterli |
| `ArchiveStore` | **Kullanılmaz** | v2 tiplerine (`DailyEntry`, `MonthSummary`) bağlı, ekrana bağlı bir `ObservableObject`, ve `loadMonth` her satırı `DailyEntry`'ye çeviriyor (`one/Features/Archive/ArchiveStore.swift`) |
| Yeni tip: `LegacyMomentStore` (ad öneri) | Tek sorumluluk: tarih aralığındaki `DailySong` satırlarını background context'te okuyup `[Day]` döndürmek | `fetchMoments(for:)` yalnız tek gün okuyor (`Persistence.swift:363`); Yolculuk aralık sorgusu, `fetchBatchSize` ve `passed == NO` predicate'i istiyor |
| Predicate | `passed == NO` (NULL'ı da hariç tutmak için `passed != YES`), sıralama `date DESC, createdAt ASC` | Pas günleri gösterilmez (R10) |
| Foto | Listede yalnız `hasPhoto` bayrağı var. `photoData` kart açılınca ayrı fetch'le okunur | `Moment` şu an `photoData`'yı hemen kopyalıyor; aralık sorgusunda bu bellek demek (R11). `LegacyMomentStore` foto alanını `propertiesToFetch` dışında bırakmalı ya da foto için ayrı bir `Moment` kurucusu kullanmalı |
| Yolculuk birleştirme | `enum JourneyItem { case entry(…), legacy(Moment) }`, sıralama `(dayKey DESC, zaman DESC)` | İki kaynak `dayKey` üzerinden birleşir; `DayRecord` ile gerçek ilişki kurulmaz |
| Tazeleme | `.momentsDidChangeRemotely` bildirimi dinlenir | Başka cihazda hâlâ v3 çalışıyorsa yeni `DailySong` satırları gelmeye devam eder (bkz. 2) |
| İstatistik, seri, rozet | `LegacyMomentStore` bu hesaplara **hiç verilmez** | `02_veri_modeli.md`: v3 günleri seriye sayılmaz |
| Dışa aktarma | ONE 2.0 JSON'una ayrı bir `legacyMoments` dizisi, `ArchiveExporter`'ın mevcut alan adlarıyla | Arşiv kullanıcının; eski kayıtlar dışa aktarmadan düşmemeli |

### 1.2 `dayKey` türetme

`DailySong.date`, yazıldığı cihazın o anki saat diliminde `startOfDay` olarak saklanıyor (`Persistence.swift` `insertNewMoment`). Saat dilimi saklanmıyor.

| Yöntem | Sonuç |
|---|---|
| Şimdiki takvimle `date`'in gün bileşeni | Yazıldığı saat dilimi şimdikinden batıdaysa gün **bir geri kayar** (örn. TR'de yazılan kayıt Londra'da açılınca, 00:00+03 → önceki gün 22:00) |
| **Öneri: en yakın yerel gece yarısına yuvarla** | `date + 12 saat` alınır, şimdiki takvimde `startOfDay`. Yazma ve okuma saat dilimi farkı 12 saatten azsa doğru günü verir |
| Çapraz kontrol | Yuvarlanmış gün ile `createdAt`'in günü farklıysa `date` esas alınır (v3 arşivi de öyle gösteriyordu) |

Bu yöntem yalnız gösterim için. Saat dilimi farkı 12 saati aşan nadir durumlarda bir gün kayma kabul edilir (R4).

### 1.3 Yazma yollarının kapatılması

ONE 2.0 açıkken `DailySong` üzerindeki **tek izinli yazma, kullanıcının açık silme isteğidir**. Aşağıdaki yolların hepsi kodda bulunup doğrulandı:

| Yazma yolu | Yer | ONE 2.0'da |
|---|---|---|
| `insertNewMoment` | `one/Core/Managers/Persistence.swift`; tek çağıranı `MomentWriter.write` | Çağıran kalmaz; ONE 2.0 bayrağı açıkken DEBUG'da `assertionFailure` |
| `MomentWriter.write` | `one/Core/Intents/MomentWriter.swift`; çağıranlar `SaveMomentIntent`, `TodayViewModel+V3.swift`, `V3OnboardingView.swift` | v3 ekranlarına erişilemez. `SaveMomentIntent` **tip adıyla korunur**, gövdesi `MoodLog(source: shortcut)` yazan yeni servise yönlenir (R14) |
| `savePassedDay` | `Persistence.swift`; çağıran `TodayViewModel.swift:379` | v3 ekranıyla birlikte kalkar |
| Foto/not düzenleme, `clearToday`, `clearEntry` | `TodayViewModel.swift` (yaklaşık 395–475) | v3 ekranıyla birlikte kalkar |
| `MidnightResetManager.resetExpiredShares` | `one/Core/Managers/MidnightResetManager.swift` (BG görevi, `isSharedWithCircle` ve `shareExpiresAt` alanlarını yazıyor) | Görev iptal edilir (bkz. 6). Çevre kalırsa paylaşım durumu ONE 2.0 tarafında ayrı tutulur |
| `MomentDeduplicator.reconcile` | Remote change sonrası `Persistence.swift`; pas işaretlerini siliyor, `entryIndex` değerlerini yeniden numaralıyor | ONE 2.0'da **kapatılır**. Pas satırları zaten gösterilmiyor; `entryIndex` çakışması yalnız v3 paylaşımını etkiliyordu. v3'te kalan cihazlar kendi uzlaştırmasını yapmaya devam eder |
| `DailyEntry.toDailySong` | `one/Core/Models/DailyEntry.swift`; yalnız testlerden çağrılıyor | Testlerle birlikte kaldırılır |
| `ProfileViewModel.deleteAccount` | `NSBatchDeleteRequest` ile `DailySong` siliniyor | **Tek izinli yol**, ayrıca "ONE 1 arşivini sil" ayarı. Kullanıcı verisini silebilmeli |

**Emniyet ağı:** DEBUG'da `NSManagedObjectContextWillSave` dinlenir; ONE 2.0 bayrağı açıkken `insertedObjects` ya da `updatedObjects` içinde `DailySong` varsa `assertionFailure`. Silme serbest. Bu test de edilir (bkz. 7).

### 1.4 v3 yan etkilerinin kapatılması

| Yan etki | Tetikleyen | ONE 2.0'da |
|---|---|---|
| Widget anahtarları (`widget_*`) | `MomentWriter.refreshTodaySurfaces`; **her remote change'de** `Persistence.reconcileAfterRemoteChange` içinden de çağrılıyor | Remote change zincirinden çıkarılır. Yoksa v3 cihazından gelen her kayıt ONE 2.0 widget'ının üzerine v3 verisi yazar. Widget yeni `w2_*` anahtarlarından okur |
| Echo önbelleği (`TodayViewModel.writeCachedEchoMood`) | aynı fonksiyon | Kaldırılır |
| `NotificationOrchestrator.onSongSaved` | `MomentWriter.applySideEffects` | Çağrılmaz; ONE 2.0 kendi olaylarını tanımlar |
| `V3ReminderScheduler.reschedule` | aynı fonksiyon | Çağrılmaz; pending istekleri temizlenir (bkz. 6) |
| `todaySongSaved` bildirimi | aynı fonksiyon | Dinleyenler v3 ekranları; kalkar |
| Live Activity | `LiveActivityManager` (bayrakla kapalı) | Açılışta `endAllActivities` zaten çalışıyor; iki activity tipi için de korunur |
| Çevre paylaşımı (`CloudKitDailyShareService.shareDailySong`) | v3 kayıt akışı | Çevre kararına bağlı (bkz. 6) |

## 2. B' riskleri ve karşılaştırma

### 2.1 B' riskleri

| Risk | Etki | Önlem |
|---|---|---|
| Başka cihazda v3 çalışmaya devam ederse (iPad güncellenmemişse) yeni `DailySong` kayıtları gelir | Yolculuk'ta ONE 2.0 döneminde de "ONE 1" kartları görünür | Kabul edilebilir; kart zaten doğru gösteriliyor. İsteğe bağlı: "Diğer cihazın eski sürümde" bilgi satırı |
| Kod yanlışlıkla bir v3 yazma yolunu çalıştırırsa | Eski şemaya yeni veri girer | 1.3'teki DEBUG emniyet ağı ve test |
| Yolculuk iki kaynağı birleştirirken sayfalama zorlaşır | Performans ve karmaşıklık | Ay ay sayfalama; her ay iki sorgu (Entry/MoodLog ve DailySong) |
| Serbest hex'ler `V3Mood`'a eşlenemiyor | Kartta renk doğru, etiket boş olabilir | Renk olduğu gibi gösterilir; etiket yoksa gösterilmez (`V3Mood.closest` ile tahmin **edilmez**) |
| v3 kodu uzun süre derlemede kalır (`Moment`, `V3Mood`, `DailySong` codegen) | Derleme süresi, bakım yükü | Okuma katmanı küçük tutulur; v3 ekranları relaunch'ta silinir (ADR-001) |
| `DailySong` hiç silinmezse CloudKit'teki veri sonsuza dek kalır | Kullanıcının iCloud kotası | Kullanıcı "ONE 1 arşivini sil" ile silebilir |

### 2.2 Karşılaştırma

| | A (tam taşıma) | B (arşiv kopyası) | **B' (salt okunur)** |
|---|---|---|---|
| İş | Yüksek: eşleme, kopyalama, foto, idempotent göç, çift cihaz | Orta: kopyalama, foto, idempotent göç | **Düşük**: okuma katmanı ve yazma yollarını kapatma |
| Veri riski | Yüksek: renk → 1–5 skor eşlemesi keyfi (R9); iki cihaz aynı anda göç ederse çift kayıt; göç yarıda kalabilir | Orta: çift kayıt ve CloudKit'te iki kez veri; foto kopyası bellek ve süre riski (R11) | **En düşük**: kaynak hiç değişmiyor, geri dönülebilir |
| iCloud kotası | Foto iki kez | Foto iki kez | Değişmez |
| Kullanıcı deneyimi | Tek tip görünüm, eski kayıtlar istatistikte; ama sahte skorlar | Tek tip kayıt ama "legacy" türü; istatistik dışı | İki kart tipi ("ONE 1" etiketiyle), istatistik dışı; kullanıcı hiçbir şey kaybetmez |
| Geri dönüş | Zor | Zor | Kolay: istenirse ileride B ya da A'ya geçilebilir, çünkü kaynak duruyor |

## 3. Model sürümü `one 3`: CloudKit uyumluluk kontrolü

Genel: `one 3.xcdatamodel` yeni sürüm olarak eklenir; `DailySong` `one 2`'den **birebir** kopyalanır. `usedWithCloudKit="YES"`. Tüm entity'ler Default configuration'da. Codegen: `class` (mevcutla tutarlı). Yeni entity adları mevcut Swift tipleriyle çakışmıyor (repo tarandı).

### 3.1 Genel kurallar

| Kural | v0.2 durumu | Düzeltme |
|---|---|---|
| Her attribute opsiyonel ya da varsayılanlı | Scalar'lar varsayılanlı ✓. **UUID, Date ve String alanlar varsayılansız ve opsiyonel değil** ✗ | Model editöründe hepsi `optional`. Swift'te `awakeFromInsert` ile doldurulur ve okunurken `?? ""` ile sarmalanır. UUID ve Date için model varsayılanı anlamsız; `""` varsayılanı ise `dayKey` gibi alanlarda boş gruplara yol açar |
| Unique constraint yok | ✓ | — |
| Her ilişki opsiyonel ve ters ilişkili | Ters ilişkiler tanımlı ✓; opsiyonellik açıkça yazılmamış | Tüm ilişkilerde `optional` işaretlenir |
| Ordered ilişki yok | ✓ (`order: Int16` kullanılıyor) | — |
| Deny delete rule yok | ✓ (cascade ve nullify) | — |
| Büyük ikili veri harici depolamada | `Media.data`, `thumbnail` ✓ | Büyük değerler CloudKit'e CKAsset olarak gider (tahmin; NSPersistentCloudKitContainer büyük binary değerleri otomatik asset'e çeviriyor). Video ve ses için boyut sınırı uygulama tarafında konmalı; kullanıcının iCloud kotasından yer |

### 3.2 Entity bazında

"Opsiyonel yap" = model editöründe `optional`; Swift katmanı yine zorunlu davranır.

| Entity | Alan / ilişki | v0.2 | Sorun | Öneri |
|---|---|---|---|---|
| Entry | `id` UUID, `dayKey` String, `createdAt` / `updatedAt` Date, `kind` String | zorunlu | varsayılan yok | Opsiyonel yap |
| Entry | `wordCount` Int32 = 0, `isBackfilled` Bool = NO | ✓ | — | — |
| Entry | `mood` ↔ `MoodLog.entry` (bire bir) | inverse var | Delete rule yazılmamış. İki cihaz farklı MoodLog bağlarsa son yazan kazanır | Her iki uç **nullify** (check-in, girdi silinse de kalmalı; öneri) |
| Entry | `answers` →> EntryAnswer | cascade | ✓ | Ters uç `EntryAnswer.entry` nullify |
| Entry | `media` →> Media | cascade | ✓ | Ters uç `Media.entry` nullify |
| Entry | `tags` ↔ `Tag.entries` (çoka çok) | nullify | ✓ CloudKit'te ayrı ilişki kayıtlarıyla (`CDMR`) desteklenir (tahmin) | — |
| Entry | `template` ↔ `Template.entries` | nullify | ✓ | — |
| EntryAnswer | `id`, `kind` | zorunlu | varsayılan yok | Opsiyonel yap |
| EntryAnswer | `numberValue` + `hasNumber`, `boolValue` + `hasBool` | ✓ | Doğru desen (scalar opsiyonel yerine bayrak) | `hasNumber` ve `hasBool` için `= NO` varsayılanı açıkça yazılmalı |
| MoodLog | `id`, `dayKey`, `timestamp`, `source` | zorunlu | varsayılan yok | Opsiyonel yap |
| MoodLog | `score` Int16 = 0 (0 = yok) | ✓ | — | — |
| MoodLog | `timeZoneID` | **yok** | İlke 1 her yeni kayıtta `timeZoneID` istiyor; yalnız Entry'de var | MoodLog'a da `timeZoneID` String? ekle |
| DayRecord | `id`, `dayKey` | zorunlu | varsayılan yok; mantıksal tekillik kodla | Opsiyonel yap; dedupe kuralı (en erken `*CompletedAt` kazanır) yazılı |
| DayRecord | `timeZoneID` | yok | Gün kaymasında hangi dilimle tamamlandığı bilinmez | Öneri: ekle |
| Tag | `id`, `name`, `createdAt` | zorunlu | varsayılan yok | Opsiyonel yap. Aynı adlı etiket iki cihazda oluşursa çift kalır → ada göre dedupe ya da kabul |
| Media | `id`, `type` | zorunlu | varsayılan yok | Opsiyonel yap |
| Media | `durationSec` Double = 0, `order` Int16 = 0 | ✓ | — | — |
| Template | `id`, `name`, `createdAt`; `isFavorite` | zorunlu; Bool'un varsayılanı yok | — | Opsiyonel yap; `isFavorite = NO` |
| TemplateItem | `id`, `kind`; `order` Int16 | zorunlu | varsayılan yok | Opsiyonel yap; `order = 0`; `template` ilişkisi opsiyonel ve nullify |
| MetricDefinition | `id`, `name`, `kind`; `isActive`, `order` | Bool ve Int varsayılanı yazılmamış | — | Opsiyonel yap; `isActive = YES`, `order = 0` |
| BadgeAward | `id`, `badgeID`, `earnedAt` | zorunlu | varsayılan yok | Opsiyonel yap; `badgeID` dedupe kodla |
| Practice | `id`, `contentRef`, `addedAt`; `order` | zorunlu | varsayılan yok | Opsiyonel yap; `order = 0` |

Ad notları: entity adları kalıcı. CloudKit tarafında `CD_` önekiyle gider, yani `type`, `data`, `order`, `kind` gibi alan adları CloudKit'in ayrılmış adlarıyla çakışmaz (tahmin). Core Data'da `description` gibi ayrılmış ad kullanılmıyor ✓.

## 4. Lightweight migration: `one 2` → `one 3`

**Neden çalışır:**

- Değişiklik yalnız **ekleme**: yeni entity'ler, yeni ilişkiler ve yeni opsiyonel alanlar. `DailySong`'un version hash'i değişmediği için Core Data inferred mapping model'i otomatik üretir.
- `Persistence.swift` zaten `NSMigratePersistentStoresAutomaticallyOption` ve `NSInferMappingModelAutomaticallyOption` açık yüklüyor.
- `one` ve `one 2` sürümleri birebir aynı; mevcut store'lar hangisiyle oluşmuş olursa olsun kaynak model bulunur.
- History tracking ve CloudKit mirroring ek entity'lerle sorunsuz çalışır; yeni record type'lar ilk export'ta oluşur (şema deploy edilmişse, bkz. 5).

**Çalışmayacağı durumlar:**

| Durum | Sonuç |
|---|---|
| `one` ya da `one 2` dosyası yerinde düzenlenirse veya silinirse | Kaynak model bulunamaz, store açılmaz. `recoverFromUnopenableStore` **yerel store'u siler**; iCloud'u kapalı kullanıcıda bu kalıcı veri kaybıdır (R3) |
| `DailySong`'a zorunlu alan eklenir, tip değişir, ad değişir | Inferred mapping başarısız → aynı silme yolu |
| Yeni entity ya da alan adı `renamingIdentifier` olmadan değiştirilirse | Yayından sonra: veri kaybı; CloudKit'te eski record type kalır |
| **Sürüm düşürme**: `one 3` ile açılmış store'u eski v3 build'i açarsa (TestFlight'ta eski build, geri çekilen sürüm) | Eski build yeni modeli tanımaz → store açılmaz → kurtarma yolu siler. **Yayın sonrası geri dönüş yok**; phased release duraklatılabilir ama eski build yeniden yayınlanmamalı |
| Model sürümünde `usedWithCloudKit` uyarıları görmezden gelinirse | `loadPersistentStores` CloudKit doğrulamasında hata verir |

**Ek önlem (öneri):** `recoverFromUnopenableStore` store'u silmeden önce `one.sqlite*` dosyalarını ve `_EXTERNAL_DATA` klasörünü `Application Support/StoreBackup-<tarih>/` altına taşımalı. Bu, ONE 2.0 yayınından önceki tek ürün kodu değişikliği olarak Faz 1'e yazılmalı.

## 5. CloudKit şema deploy adımları

| # | Adım | Nerede |
|---|---|---|
| 1 | `one 3` modeli bitince, DEBUG'da bir kez `container.initializeCloudKitSchema(options: [])` çağrılır (launch argument ya da gizli debug menüsü; açılışta her seferinde **değil**) | Xcode'dan çalışan build (Development ortamı) |
| 2 | Dashboard → `iCloud.com.batu.ones` → Development → Schema: `CD_Entry`, `CD_EntryAnswer`, `CD_MoodLog`, `CD_DayRecord`, `CD_Tag`, `CD_Media`, `CD_Template`, `CD_TemplateItem`, `CD_MetricDefinition`, `CD_BadgeAward`, `CD_Practice` ve çoka çok ilişki kaydı (`CDMR`) görünüyor mu, alan listesi modelle aynı mı | Dashboard |
| 3 | `initializeCloudKitSchema`'nın oluşturduğu örnek kayıtları Development'tan sil | Dashboard |
| 4 | Deploy Schema Changes → Production | Dashboard |
| 5 | Production → Schema: yeni tipler görünüyor mu | Dashboard |
| 6 | TestFlight build'i (Production ortamı) iki cihazda: bir cihazda Entry + MoodLog + foto'lu Media + Tag yaz, diğerinde gör; sil, silindiğini gör | Cihaz |
| 7 | Aynı TestFlight'ta v3 verisi olan bir hesapla aç: `DailySong` kayıtları Yolculuk'ta görünüyor mu, hiçbiri değişmemiş mi | Cihaz |

**Yayın öncesi kontrol listesi:**

- [ ] `one 3` son hali ile `initializeCloudKitSchema` yeniden çalıştırıldı (model her değiştiğinde)
- [ ] Production şeması deploy edildi ve Dashboard'da doğrulandı
- [ ] `one` ve `one 2` dosyaları git'te değişmemiş (`git diff --stat -- "one/one.xcdatamodeld/one.xcdatamodel" "one/one.xcdatamodeld/one 2.xcdatamodel"` boş)
- [ ] `.xccurrentversion` = `one 3`
- [ ] 7. bölümdeki fixture testleri geçti
- [ ] TestFlight'ta 6 ve 7 numaralı adımlar geçti
- [ ] Eski build'lerin TestFlight'tan süresi dolduruldu (sürüm düşürme riski)

## 6. İlk açılış temizliği

Bir kez çalışır (bayrak: App Group UserDefaults'ta `one2.cleanup.v1`), ama idempotent yazılır, yani her açılışta çalışsa da zararsızdır.

| İş | Nasıl | Kaynak |
|---|---|---|
| Bekleyen v3 bildirimleri | `removePendingNotificationRequests`: `sunday_reflection_1`, `sunday_reflection_2`, `monthly_portrait_1`, `monthly_portrait_2`, mevcut `retiredIdentifiers` listesinin tamamı; **ayrıca** `getPendingNotificationRequests` ile `v3_daily_reminder_` önekli tüm ID'ler | `NotificationOrchestrator.swift`, `SundayReflectionScheduler.swift`, `MonthlyPortraitScheduler.swift`, `V3ReminderScheduler.swift` (`idPrefix`) |
| `app_update_available` | Güncelleme bildirimi ONE 2.0'da kalıyorsa dokunulmaz; kalkıyorsa silinir | `NotificationManager.swift` |
| Teslim edilmiş v3 bildirimleri | Bildirim merkezinde duranlar `removeDeliveredNotifications` ile silinir (v3 kategorileri) | — |
| Bildirim kategorileri | `setNotificationCategories` ONE 2.0 kümesiyle çağrılır (öncekini değiştirir) | `oneApp.swift` |
| Arka plan görevi | `BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: "com.batu.ones.midnightReset")`. Geçiş sürümünde handler kayıtlı kalır ve hemen `setTaskCompleted(success: true)` der; kimlik Info.plist'ten bir sonraki sürümde çıkarılır. Handler'ı kayıtsız bekleyen bir görev çökmeye yol açabilir (tahmin) | `MidnightResetManager.swift`, `one/Info.plist` |
| Live Activity | `endAllActivities()` (mevcut, açılışta çalışıyor); `FriendShareActivityAttributes` için de | `LiveActivityManager.swift` |
| Widget | `WidgetDataWriter.clear()` ile `widget_*` ve `widget_prev_*` anahtarlarını sil, `w2_*` anahtarlarını yaz, `WidgetCenter.shared.reloadAllTimelines()`. Kind `MoodWidget` korunur | `WidgetDataWriter.swift` |
| CloudKit subscription'ları | **Çevre kalkarsa**: mevcut `removeAllSubscriptions()` (5 güncel ID + `legacySubIDs`). Çevre kalırsa dokunulmaz | `CloudKitNotificationService.swift:701` |
| Spotify | `SpotifyManager`'ı başlatmadan, doğrudan `SecItemDelete` (service `com.batu.ones.spotify`, access ve refresh token) | `SpotifyManager.swift:440` |
| Echo ve v3 UserDefaults önbellekleri | Echo mood önbelleği, `EngagementTracker` ve `NotificationAnalytics` anahtarları (App Group); `Experiment` `exp_*` anahtarları | ilgili dosyalar |
| Onboarding bayrağı | `hasCompletedOnboarding` (Keychain) v3 onboarding'ini temsil ediyor. ONE 2.0 onboarding'i için **yeni** bir bayrak kullanılır; eski bayrak "ONE 1 kullanıcısı" sinyali olarak okunur (karar gerekli) | `KeychainHelper.swift` |
| `@SceneStorage` sekmesi | Tanınmayan sekme değeri varsayılan sekmeye düşer (R15) | `PrimaryTab.swift` |

## 7. Test planı

### 7.1 Fixture'lar

| Fixture | Nasıl üretilir | Repoya girer mi |
|---|---|---|
| **F1 — Sentetik v3 store** | Test yardımcısı, derlenmiş `.momd` içindeki `one 2.mom` modelini yükler, geçici dizinde SQLite store oluşturur ve şu satırları yazar: normal an; aynı gün 3 an; `passed = true`; `id = nil`; V3Mood dışı serbest hex; eski `ONEMood` hex'i; 200 KB foto (harici depolama); başka saat diliminde `startOfDay` yazılmış `date`; `createdAt = nil`. Store kapatılır | Evet (üretici kod; sentetik veri) |
| **F2 — Gerçek v3 store** | Batuhan'ın kendi cihazından: Xcode → Devices → ONE → Download Container → `AppData/Library/Application Support/one.sqlite`, `-wal`, `-shm` ve `.one_SUPPORT/_EXTERNAL_DATA` | **Hayır.** Kişisel veri, repo public. `~/ONE-fixtures/` gibi repo dışı bir yolda tutulur; testler ortam değişkeniyle bulur, yoksa `skip` eder |

### 7.2 Testler (Swift Testing)

| # | Test | Beklenen |
|---|---|---|
| T1 | F1'i `one 3` modeliyle, `NSPersistentContainer` + otomatik migration seçenekleriyle aç | Açılır; `DailySong` satır sayısı aynı; yeni entity'ler boş |
| T2 | F2 ile aynısı | Açılır; satır sayısı, foto sayısı ve `photoData` baytları aynı |
| T3 | `one 2` ve `one 3` modellerinde `DailySong.versionHash` karşılaştır | Eşit (şemaya dokunulmadığının kanıtı) |
| T4 | `one 3` modeli için CloudKit uyumu: tüm attribute'lar opsiyonel ya da varsayılanlı; tüm ilişkiler opsiyonel ve inverse'li; ordered yok | Programatik kontrol geçer (model her değiştiğinde yakalar) |
| T5 | `LegacyMomentStore` aralık sorgusu (F1) | Pas günü yok; aynı gün 3 an sıralı; `id = nil` satırı deterministik ID ile geliyor |
| T6 | `dayKey` yuvarlama | TR'de yazılmış `date`, `Europe/London` ve `America/New_York` takvimiyle okunduğunda aynı gün; 12 saati aşan fark belgelenmiş kayma |
| T7 | Yolculuk birleştirme | Aynı `dayKey`'de Entry ve legacy kartları doğru sırada; streak ve istatistik legacy'yi saymıyor |
| T8 | Yazma emniyet ağı | ONE 2.0 bayrağı açıkken `DailySong` insert veya update içeren save DEBUG'da yakalanıyor; delete serbest |
| T9 | Foto tembel okuma | Aralık sorgusunda `photoData` fault olarak kalıyor (bellek) |
| T10 | Performans | F1'in 5.000 satırlık varyantında bir ay sorgusu < 50 ms (simülatörde; eşik öneri) |
| T11 | Dışa aktarma | ONE 2.0 JSON'unda `legacyMoments` dizisi, sayı F1'deki pas dışı satır sayısına eşit |
| T12 | Sürüm düşürme (belgeleme testi) | `one 3` ile açılmış store `one 2` modeliyle açılmaya çalışıldığında hata veriyor; bu davranış bilerek kabul edildi |

CloudKit senkronu otomatik test edilmez; 5. bölümdeki cihaz adımlarıyla elle doğrulanır.

## Öneri

**B'yi seç.** v3'ün tüm verisi tek, ilişkisiz bir `DailySong` entity'sinde duruyor ve bu entity zaten üretim CloudKit şemasında kalıcı. Kopyalamak (A, B) veri kaybettirmeden kazanç sağlamıyor: renk → skor eşlemesi keyfi, foto kopyası kotayı ikiye katlıyor, çok cihazlı göç çift kayıt riski taşıyor. B' ise kaynağa hiç dokunmadığı için en güvenli yol. Kullanıcı hiçbir şey kaybetmiyor ve istenirse ileride A ya da B'ye geçmek hâlâ mümkün. Gereken iş küçük: mevcut `Moment`/`Day` üzerine ince bir okuma katmanı, yedi yazma yolunun ve widget yan etkisinin kapatılması, `one 3`'ün salt ekleme yapan bir sürüm olarak kurulması (UUID, Date ve String alanları opsiyonel, MoodLog'a `timeZoneID`) ve yayından önce şemanın deploy edilmesi. En büyük gerçek risk taşıma değil, **store'un açılamaması**: mevcut kurtarma yolu yerel store'u yedeksiz siliyor. O yüzden Faz 1'in ilk işi, bu yola yedekleme eklemek ve T1–T4 fixture testlerini yazmak olmalı.
