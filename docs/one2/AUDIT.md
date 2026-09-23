# ONE 2.0 — v3 Kod Tabanı Denetimi

Tarih: 23 Eylül 2026 · Faz 0, iş kalemi 2 · Salt okuma (ürün dosyası değiştirilmedi)
Kapsam: `~/Desktop/one/one` (git: `origin = github.com/batuudemiir/one`, aktif dal `tek-odak-faz1-2`)
Yollar repo köküne göredir. Kodda doğrudan görülmeyen her çıkarım **(tahmin)** diye işaretlidir.

## 0. Özet: ilk okunacak bulgular

| # | Bulgu | Etki | Kaynak |
|---|---|---|---|
| 1 | Gerçek bundle ID **`com.batu.ones`**. Faz 0 planında yazan `com.batudemir.ones` yanlış. App Group ve StoreKit ürünleri ise `com.batudemir.*` önekini kullanıyor. Aynı projede iki önek var. | Plan ve ADR'de düzeltilmeli. Bundle ID değişirse CloudKit verisi, Keychain ve App Store kaydı kopar. | `ones.xcodeproj/project.pbxproj` (app Debug/Release), `one/one.entitlements`, `ONEPlus.storekit` |
| 2 | Core Data modelinde **tek entity** var: `DailySong`, 28 alan, ilişki yok. `02_veri_modeli.md`'deki "Moment" bir Swift struct'ı ve `DailySong`'dan türetiliyor. | Taşıma işi yalnız bu entity'yi kapsar. Taşıma (MIGRATION) çok basitleşir. | `one/one.xcdatamodeld`, `one/Core/Models/Moment.swift` |
| 3 | Core Data store'u **App Group'ta değil**, varsayılan Application Support'ta. Widget, Core Data'yı hiç okumuyor; App Group UserDefaults'taki anahtarları okuyor. | Widget'ın ONE 2.0 verisine erişmesi için ya store App Group'a taşınır ya da UserDefaults köprüsü korunur. | `one/Core/Managers/Persistence.swift`, `one/Core/Utilities/WidgetDataWriter.swift`, `MoodWidget/MoodWidget.swift` |
| 4 | `CLAUDE.md`, `tooling/ui_guard.sh` ve `tooling/voice_guard.py` şu an **seri, rozet, geriye dönük giriş ve ölçme dilini yasaklıyor**. ONE 2.0 veri modeli ise tam olarak bunları istiyor (streak, BadgeAward, isBackfilled, scale5). | Kurallar güncellenmezse her ajan ve guard ONE 2.0 kodunu reddeder. Faz 1'den önce yeniden yazılmalı. | `CLAUDE.md` ("Duruş" ve "Kopya kuralları" bölümleri) |
| 5 | `tooling/appusers.json`, `dailyshare.json` ve `friendships.json` **git'te izleniyor**. İçlerinde üretim CloudKit public DB kayıtları var (recordName, profil fotoğrafı URL'leri, görünen adlar (tahmin)). | Gizlilik ve KVKK riski. Repo public ise acil (görünürlük doğrulanamadı; `gh` yüklü değil). | `git ls-files tooling` |
| 6 | Sosyal katman (Çevre) CloudKit **public DB** üzerinde 9 record type ve 5 query subscription kullanıyor. | ONE 2.0'ın Stoic benzeri tek kullanıcılı yapısında Çevre'nin kalıp kalmayacağı kararı açık. Kalmasa bile canlı kullanıcıların abonelikleri ve public kayıtları temizlenmeli. | `one/Core/Managers/CloudKit*.swift` |

## 1. Proje yapısı

| Öğe | Değer | Kaynak / not |
|---|---|---|
| Proje | `ones.xcodeproj` (workspace yok, yalnız gömülü `project.xcworkspace`). `objectVersion = 77`, klasörler `PBXFileSystemSynchronizedRootGroup` ile otomatik senkron (Xcode 16+). | `ones.xcodeproj/project.pbxproj` |
| Şemalar | `ones`, `MoodWidgetExtension`, `OneActivityExtensionExtension` | `ones.xcodeproj/xcshareddata/xcschemes/` |
| Ekip | `DEVELOPMENT_TEAM = T4L7QU56YY`, otomatik imzalama | pbxproj |
| Kaynak boyutu | Uygulama target'ında 193 Swift dosyası, yaklaşık 45 bin satır | `one/` |

| Target | Tür | Bundle ID | Ürün adı | MARKETING / BUILD | Min iOS | Entitlements |
|---|---|---|---|---|---|---|
| `one` | Uygulama | `com.batu.ones` | `OneDailyBatuhan.app`, görünen ad "One Mood" | 3 / 8 | 17.0 | `one/one.entitlements` |
| `MoodWidgetExtension` | App extension (WidgetKit) | `com.batu.ones.MoodWidget` | `MoodWidgetExtension.appex` | 2.5 / 40 | 17.0 | `MoodWidgetExtension.entitlements` |
| `OneActivityExtensionExtension` | App extension (Live Activity) | `com.batu.ones.OneActivityExtension` | `OneActivityExtensionExtension.appex` | 2.5 / 40 | `$(RECOMMENDED_IPHONEOS_DEPLOYMENT_TARGET)` | yok |
| `oneTests` | Birim testi | `com.batu..oneTests` (çift nokta) | `oneTests.xctest` | 1.0 / 1 | 17.0 | yok |
| `oneUITests` | UI testi | `com.batu..oneUITests` (çift nokta) | `oneUITests.xctest` | 1.0 / 1 | proje varsayılanı (17.0) | yok |

| Build ayarı | Değer | Not |
|---|---|---|
| `SWIFT_VERSION` | 5.0 (tüm target'lar) | Swift 6 dil modu kapalı |
| `SWIFT_DEFAULT_ACTOR_ISOLATION` | `MainActor` (yalnız app target'ı) | Tip denetimini etkiler. Extension'larda yok. |
| `SWIFT_APPROACHABLE_CONCURRENCY` | YES | Tüm target'lar |
| `SWIFT_UPCOMING_FEATURE_MEMBER_IMPORT_VISIBILITY` | YES | Eksik `import` derleme hatası verir |
| Secrets | App target'ı `one/Secrets.xcconfig`'ten miras alıyor (gitignore'da). Tanımlı tek anahtar `TICKETMASTER_API_KEY`, kodda kullanılmıyor. `SPOTIFY_CLIENT_ID` **tanımlı değil**. | `one/Secrets.xcconfig.template`, `one/Info.plist` |
| Info.plist | Hem dosya (`one/Info.plist`) hem `INFOPLIST_KEY_*` kullanılıyor. `NSAppleMusicUsageDescription` iki yerde farklı metinle geçiyor. | pbxproj ve `one/Info.plist` |
| Aygıt | iPhone + iPad (`1,2`). iPhone yalnız portrait. | pbxproj |
| Fontlar | Archivo ExtraBold Expanded, Caveat Brush, DM Sans (5 kesim) | `one/Info.plist` `UIAppFonts`, `one/Resources/Fonts/` |
| Yerelleştirme | 9 dil: de, en, es, fr, ja, ko, ru, tr, zh-Hans. Widget ve Live Activity için de ayrı `.lproj` klasörleri var. | `one/*.lproj`, `MoodWidget/*.lproj`, `OneActivityExtension/*.lproj` |
| Sürüm tutarsızlığı | App 3 (build 8), extension'lar 2.5 (build 40) | App Store Connect extension sürümünün app sürümüyle eşleşmesini ister (uyarı veya red) (tahmin) |
| Ölü dosyalar | `MoodWidget/CircleWidget.swift` (yer tutucu, `DEVELOPMENT_ASSET_PATHS`'te). `OneActivityExtension/AppIntent.swift`, `OneActivityExtension.swift`, `OneActivityExtensionControl.swift` (1'er satır, boş). | Dosya başlıkları |

## 2. Bağımlılıklar

| Paket | Sürüm | Kural | Kullanan target | Kullanım yeri |
|---|---|---|---|---|
| `posthog-ios` (PostHog) | 3.58.3 (rev `cf61559`) | upToNextMajor ≥ 3.0.0 | yalnız `one` | `one/Core/Utilities/Analytics/PostHogAnalyticsService.swift`. `one/oneApp.swift`'te Tier 3 açılışta, `#if canImport(PostHog)` koşuluyla kaydediliyor. API anahtarı kaynak kodunda sabit (public "phc_" proje anahtarı). |

Başka SPM, CocoaPods veya Carthage bağımlılığı yok. Kullanılan Apple framework'leri: CoreData, CloudKit, MusicKit, WidgetKit, ActivityKit, AppIntents, LocalAuthentication, AuthenticationServices, StoreKit (yalnız `AppStore.requestReview`), BackgroundTasks, MetricKit, Contacts, AVFoundation (kamera). Bir `.metal` shader var: `one/UI/DesignSystem/Shaders/SaveRipple.metal`.

## 3. Entitlements ve capability'ler

| Capability | Değer | Target | Kaynak / not |
|---|---|---|---|
| iCloud / CloudKit | Container `iCloud.com.batu.ones`, servis: CloudKit | app | `one/one.entitlements`. Kodda aynı ID iki yerde sabit: `one/Core/Managers/Persistence.swift`, `one/Core/Managers/CloudKitManager.swift` |
| iCloud KVS | `$(TeamIdentifierPrefix)$(CFBundleIdentifier)` | app | Tek kullanım: `one/Features/Profile/ProfileViewModel.swift` (iCloud kullanılabilirlik kontrolü) |
| App Groups | `group.com.batudemir.ones` | app + MoodWidget | Live Activity extension'ında **yok** |
| Push | `aps-environment = production` | app | CloudKit query subscription'ları için |
| Background modes | `remote-notification`, `processing` | app | `one/Info.plist`. BG görev ID'si: `com.batu.ones.midnightReset` |
| Sign in with Apple | `Default` | app | `one/Core/Managers/AppleSignInService.swift` |
| Associated Domains | `applinks:one.forvibe.app`, ayrıca `associated-domains.mdm-managed = true` | app | Beklenen yollar: `/invite?code=…`, `/event/mood…` (`one/oneApp.swift`). `mdm-managed` bayrağının neden açık olduğu belirsiz; büyük olasılıkla gereksiz (tahmin). |
| Live Activities | `NSSupportsLiveActivities = true` | app | Kod bayrağı `Features.liveActivitiesEnabled = false` (`one/Core/Experiments/Features.swift`) |
| HealthKit | **Yok** | — | Entitlement yok, kodda `HealthKit` import'u yok. ONE 2.0'daki `healthKitSampleID` alanı sıfırdan kurulacak. |
| MusicKit | Entitlement dosyasında yok. MusicKit portalda App ID servisi olarak açılır (tahmin: açık, çünkü katalog araması kullanılıyor). | app | `MusicCatalogSearchRequest` ve `MusicCatalogChartsRequest` çağrıları |
| Keychain | `keychain-access-groups` yok, varsayılan grup kullanılıyor | app | Servisler: `com.batu.ones` (`one/Core/Utilities/KeychainHelper.swift`, `hasCompletedOnboarding` ve `hasCreatedProfile` bayrakları), `com.batu.ones.spotify` (Spotify token'ları) |
| URL scheme | `ones` | app | `one/Info.plist` `CFBundleURLTypes` (adı `com.one.spotify`) |
| Sorgulanabilir şemalar | spotify, instagram, instagram-stories, tiktok, snssdk1180, snssdk1233 | app | `LSApplicationQueriesSchemes` |
| İzin metinleri | Apple Music, Kamera, Kişiler, Face ID, Fotoğraf (okuma ve ekleme), Takvim (yalnız build ayarında) | app | `one/Info.plist` ve pbxproj |
| Privacy manifest | Tracking yok. Toplanan veri: ad, foto/video, ses, diğer kullanıcı içeriği, kullanıcı ID. API gerekçeleri: UserDefaults CA92.1, FileTimestamp C617.1 | app | `one/PrivacyInfo.xcprivacy` |

## 4. Persistence

### 4.1 Core Data modeli

| Öğe | Değer | Kaynak |
|---|---|---|
| Model | `one.xcdatamodeld`, sürümler: `one.xcdatamodel` ve `one 2.xcdatamodel` (güncel: `one 2`) | `one/one.xcdatamodeld/.xccurrentversion` |
| Sürüm farkı | İki sürümün `contents` dosyası **birebir aynı** (`diff` boş). İkinci sürüm şema değişikliği taşımıyor. | — |
| `usedWithCloudKit` | YES | — |
| Codegen | `class` (otomatik; elle yazılmış `NSManagedObject` alt sınıfı yok) | — |
| Entity sayısı | 1: `DailySong`. İlişki yok, fetched property yok, constraint yok, index yok. | — |

**`DailySong` alanları.** Tümü `optional="YES"`. Scalar Bool ve Int için varsayılan değer var.

| Alan | Tip | Varsayılan | v3'teki anlam (koddan) |
|---|---|---|---|
| `id` | UUID | — | Kayıt kimliği. Boşsa `Moment.derivedID(date, entryIndex)` türetiliyor. |
| `date` | Date | — | Günün başlangıcı: `Calendar.current.startOfDay`, **yerel saat dilimiyle** |
| `createdAt` | Date | — | Anın gerçek zamanı. v3'te "saat saat" gösterim bununla yapılıyor. |
| `entryIndex` | Integer 16 | 0 | Aynı gün içindeki sıra (v3, günde çoklu an) |
| `moodColorHex` | String | — | **Asıl mood verisi.** V3Mood hex'i, eski ONEMood hex'i ya da serbest renk seçicideki herhangi bir hex. Pas günü için `#9E9E9E`. |
| `moodWord` | String | — | Mood etiketi (V3Mood) |
| `moodLabel` | String | — | v2 etiketi. Etiket göçü haritası: `DailyEntry.moodLabelMigrationMap` |
| `moodIsDark` | Boolean | NO | v2 kontrast bayrağı |
| `feeling`, `feelingLabel` | String | — | v2 `FeelingType` (15 case) |
| `dailyNote` | String | — | Serbest not |
| `songName`, `artistName`, `genre`, `artworkURL`, `platform`, `spotifyURL` | String | — | Şarkı (Apple Music katalogundan ya da Spotify'dan) |
| `emoji` | String | — | v2 kalıntısı (tahmin: v3'te yazılmıyor) |
| `photoData` | Binary, harici depolama | — | Foto. CloudKit'te CKAsset olarak gider (tahmin, `allowsExternalBinaryDataStorage` davranışı). |
| `photoURL` | String | — | Eski foto referansı |
| `weatherIcon`, `weatherDesc` | String | — | v2 kalıntısı; kodda yazan yer bulunmadı (tahmin) |
| `shareWithCircle`, `isSharedWithCircle` | Boolean | NO | Kapsam (`MomentScope.friends` / `.private`). İki alan aynı değeri tutuyor. |
| `shareExpiresAt`, `sharedAt` | Date | — | Çevre paylaşım zamanları |
| `viewCount` | Integer 16 | 0 | Çevre görüntülenme sayısı |
| `passed` | Boolean | NO | "Pas geçilen gün" satırı |

**Swift katmanı:** `Moment` (struct) KVC ile `DailySong`'dan okunuyor. `Day` bir günün `Moment` listesini tutuyor. `DailyEntry` ve `FeelingType` v2'den kalma ama 7–8 dosya hâlâ kullanıyor (`one/Core/Models/Moment.swift`, `one/Core/Models/DailyEntry.swift`). Mood kataloğu için iki enum var: `V3Mood` (9 case, güncel) ve `ONEMood` (12 case, eski). Aralarında hem hex köprüsü hem anlamsal köprü var (`one/UI/DesignSystem/V3Mood.swift`, `one/UI/DesignSystem/ONEMood.swift`).

### 4.2 Container kurulumu

| Öğe | Değer | Kaynak |
|---|---|---|
| Container | `NSPersistentCloudKitContainer(name: "one")`, tek store description | `one/Core/Managers/Persistence.swift` |
| CloudKit | `containerIdentifier: "iCloud.com.batu.ones"`, **private DB** (varsayılan scope) | aynı dosya |
| Store konumu | Varsayılan (`NSPersistentContainer.defaultDirectoryURL()`, uygulamanın Application Support klasörü, `one.sqlite`) (tahmin: URL elle atanmadığı için). **App Group değil.** | aynı dosya |
| Seçenekler | Remote change bildirimi açık, history tracking açık, otomatik lightweight migration açık, `FileProtection.completeUntilFirstUserAuthentication` | aynı dosya |
| Yükleme | Asenkron. `isReady` yayınlanıyor. Açılış bütçesi 20 ms uyarısı var. | aynı dosya |
| Merge | viewContext: `NSMergeByPropertyObjectTrumpMergePolicy`. Uzlaştırma context'i: `StoreTrump`. | aynı dosya |
| Bozuk store kurtarma | Store açılamazsa `destroyPersistentStore` çağrılıp store yeniden yükleniyor; veri CloudKit'ten yeniden iniyor. İkinci başarısızlıkta `fatalError`. | `recoverFromUnopenableStore` |
| History budama | Açılışta 7 günden eski history siliniyor | `schedulePersistentHistoryPurge` |
| Çoklu cihaz uzlaştırma | Remote change debounce ediliyor; `MomentDeduplicator` çift pas satırlarını ve çift kayıtları temizliyor; ardından `.momentsDidChangeRemotely` yayınlanıyor. | `one/Core/Managers/MomentDeduplicator.swift` |
| Yazma yolu | `insertNewMoment` (her zaman yeni satır ekler), `savePassedDay`. Yan etkiler (widget, bildirim, Live Activity) `MomentWriter` içinde. | `Persistence.swift`, `one/Core/Intents/MomentWriter.swift` |
| `@FetchRequest` | Hiçbir ekranda kullanılmıyor. Ekranlar diziye kopyalıyor ve bildirimle tazeliyor. | `Persistence.swift` içindeki yorum |

### 4.3 CloudKit şeması: üretim durumu

| Veritabanı | Record type | Durum (koddan çıkarım) |
|---|---|---|
| Private (Core Data aynalaması) | `CD_DailySong` (tahmin: NSPersistentCloudKitContainer adlandırma kuralı) | Uygulama App Store'da ve CloudKit'e bağlı. Şemanın üretimde deploy edilmiş olması gerekir, yoksa sync hiç çalışmazdı (tahmin). Kodda `initializeCloudKitSchema` çağrısı yok; şema development ortamında otomatik oluşup Dashboard'dan deploy edilmiş (tahmin). |
| Public | `AppUser`, `Friendship`, `DailyShare`, `EmojiReaction`, `Resonance`, `SubCircle`, `UserBlock`, `ContentReport` | Kod üretim şemasına göre savunmacı yazılmış. "Schema not deployed to Production" hataları yakalanıyor (`CloudKitManager.swift`). `Friendship`'e yalnız 3 alan yazılıyor, çünkü diğer alanlar üretimde olmayabilir (`CloudKitFriendshipService.swift` başlığı). `tooling/*.json`'daki dökümler, üretimde `AppUser`, `DailyShare` ve `Friendship` verisi olduğunu gösteriyor. |
| Public: subscription'lar | `friend-request-notification-v6`, `friend-daily-share-notification-v6`, `friend-accept-notification-v6`, `emoji-reaction-notification-v4`, `comment-notification-v1` | `one/Core/Managers/CloudKitNotificationService.swift` |
| Doküman | `docs/CLOUDKIT_PRODUCTION_DEPLOYMENT.md` eski adları anlatıyor (`Users`, `FriendRequest`); koddaki adlarla uyuşmuyor. | — |

Kesin durum için CloudKit Dashboard'da Production → Schema sayfası elle kontrol edilmeli.

## 5. Servisler

| Servis | Durum | Dosyalar | Notlar |
|---|---|---|---|
| Apple Music / MusicKit | Aktif | `one/Features/Today/TodayViewModel.swift` (`search`, charts), `one/Core/Managers/SongRecommendationEngine.swift`, `one/Features/Today/V3/V3SongPicker.swift`, `one/Features/Today/SongPreviewPlayer.swift`, Profil ayarları | Yalnız katalog araması, chart ve önizleme var. `ApplicationMusicPlayer` kullanılmıyor. Yetki: `MusicAuthorization`. |
| Spotify OAuth | Kodu var, fiilen **kapalı** | `one/Core/Managers/SpotifyManager.swift`, `one/Features/Profile/SettingsDetailScreens.swift` | PKCE akışı, redirect `ones://spotify-callback`. Token'lar Keychain'de (`com.batu.ones.spotify`). `SpotifyClientID`, Info.plist'te `$(SPOTIFY_CLIENT_ID)` değişkenine bağlı ama bu anahtar xcconfig'te yok, yani client ID boş ve özellik kendini kapatıyor. |
| Bildirimler (yerel) | Aktif | `one/Core/Notifications/NotificationOrchestrator.swift`, `NotificationPolicy.swift`, `NotificationMessageBuilder.swift`, `SundayReflectionScheduler.swift`, `MonthlyPortraitScheduler.swift`, `one/Features/Today/V3/V3ReminderScheduler.swift`, `one/Core/Utilities/NotificationManager.swift` | Bekleyen istek ID'leri: `v3_daily_reminder_<y-m-d>`, `sunday_reflection_1/2`, `monthly_portrait_1/2`, `app_update_available`. Emekli ID'ler her açılışta temizleniyor (`retiredIdentifiers`). Politika, bastırma ve deduplikasyon orchestrator'da. Ayarlar App Group UserDefaults'ta. |
| Bildirimler (uzak) | Aktif | `one/Core/Managers/CloudKitNotificationService.swift` | CloudKit query subscription'ları (bkz. 4.3). Kategoriler `one/oneApp.swift`'te: `FRIEND_REQUEST`, `WEEKLY_SUMMARY`, `FRIEND_SHARED`, `MOOD_RESONANCE`, `APP_UPDATE`. Eylemler: `ACCEPT_FRIEND`, `DECLINE_FRIEND`, `OPEN_ECHO`, `OPEN_CIRCLE`. |
| Uygulama kilidi | Aktif, **yalnız cihaz kimlik doğrulaması** | `one/Core/Managers/AppLockManager.swift`, `one/Features/Onboarding/AppLockView.swift` | `LAContext.deviceOwnerAuthentication` kullanılıyor (Face ID, Touch ID ya da cihaz şifresi). Uygulamaya özel PIN yok. Geri dönüşlerde 20 sn tolerans var. Bayrak `UserDefaults.standard`'da tutuluyor. Veri şifrelenmiyor, kilit yalnız arayüzde. |
| Veri dışa aktarma | Aktif | `one/Core/Utilities/ArchiveExporter.swift` | Tek JSON dosyası (`ONE-arsiv-YYYY-MM-DD.json`), İngilizce ve sabit alan adları, geçici dizine yazılıp paylaşım sayfasıyla veriliyor. Foto verisi dahil değil, yalnız `hasPhoto` bayrağı var. Testi: `oneTests/ArchiveExporterTests.swift`. |
| Widget | Aktif | `MoodWidget/MoodWidget.swift`, `one/Core/Utilities/WidgetDataWriter.swift` | Tek widget, kind `"MoodWidget"`, `StaticConfiguration`. Aileler: accessory inline, circular, rectangular ve system small, medium, large. Veri, App Group UserDefaults'taki `widget_*` anahtarlarından okunuyor (bugün, dün, arkadaş paylaşımları). Deep link: `ones://today`. |
| Live Activity | Kodu var, bayrakla **kapalı** | `OneActivityExtension/OneActivityExtensionLiveActivity.swift`, `ActivityAttributes.swift`, `one/Core/Managers/LiveActivityManager.swift` | `DailySongActivityAttributes` ve `FriendShareActivityAttributes`. `pushType: nil`, güncellemeler yerel. Açılışta `endAllActivities()` çağrılıyor. |
| App Intents / Kısayollar | Aktif | `one/Core/Intents/SaveMomentIntent.swift`, `ONEAppShortcuts.swift`, `V3Mood+AppEntity.swift`, `MomentWriter.swift` | `SaveMomentIntent` ("An kaydet"), `OpenMomentEntryIntent`, `TodayMoodQueryIntent`. Kullanıcıların Kısayollar'da kurduğu akışlar bu intent adlarına bağlı. |
| Analytics | Aktif (PostHog) | `one/Core/Utilities/Analytics/*` | `AnalyticsService` protokolü, `AppAnalytics` dağıtıcısı, `ConsoleAnalyticsService` ve `PostHogAnalyticsService`. `AnalyticsEvent`'te 102 case var. `identify` CloudKit kullanıcı ID'siyle yapılıyor. |
| Crash / performans | Kısmi | `one/Core/Utilities/Analytics/CrashReporter.swift`, `one/Core/Managers/LaunchMetricsCollector.swift`, `ONELaunchSignpost.swift` | `CrashReporter` varsayılan olarak no-op; Sentry takılmamış. MetricKit (`MXMetricManager`) açılış metriklerini topluyor. |
| Deep link | Aktif | `one/oneApp.swift` (`onOpenURL`, `onContinueUserActivity`), `one/Core/Managers/LaunchIntent.swift` | `ones://spotify-callback`, `ones://today` (Çevre sekmesi + mood seçici), `ones://add-friend?code=`, `ones://entry`, `ones://circle`, `ones://archive`, `ones://echo`, `ones://profile`. Universal link: `https://one.forvibe.app/invite?code=`, `/event/mood`. Sekme anahtarları `PrimaryTab` rawValue'ları (`@SceneStorage` sözleşmesi). |
| StoreKit (abonelik) | **Kod yok** | `ONEPlus.storekit` (yalnız yerel test dosyası) | Ürünler: `com.batudemir.ones.oneplus.monthly` (29.99), `…yearly` (199.99). Kodda `Product` veya `Transaction` kullanımı yok. Yalnız `AppStore.requestReview` var (`one/Core/Managers/AppReviewManager.swift`). ONE 2.0 premium'u sıfırdan yazılacak. |
| Sign in with Apple | Aktif | `one/Core/Managers/AppleSignInService.swift`, `one/Features/Onboarding/AppleSignInGateView.swift` | Çevre profili için |
| Arka plan görevi | Aktif | `one/Core/Managers/MidnightResetManager.swift` | `com.batu.ones.midnightReset`: Çevre foto paylaşımının gece sıfırlanması |
| Diğer | — | `one/Core/Experiments/Experiment.swift` (5 yerel A/B anahtarı, `exp_*`), `one/Core/Experiments/Features.swift` (derleme bayrakları), `one/Core/Managers/LanguageManager.swift` (uygulama içi dil, 20 dosyada), `one/Core/Utilities/AppUpdateChecker.swift`, `one/Core/Managers/NetworkMonitor.swift` | — |

## 6. Tasarım sistemi

### 6.1 Token envanteri

| Grup | Token'lar | Kaynak |
|---|---|---|
| Renk (adaptive) | `kor` #FF3B1F (marka, temadan bağımsız), `korText`, `ink`, `paper`, `surface`, `wash`, `hairline`, `dashed`, `mutedText`, `faintText`, `ghostText` | `one/UI/DesignSystem/V3Tokens.swift` |
| Renk (sabit koyu) | `darkGround`, `darkText`, `darkMuted`, `darkWash`, `darkHairline` | aynı dosya |
| Renk (dışa aktarma) | `V3Tokens.Export.*`: `paper`, `surface`, `ink`, `muted`, `faint`, `hairline`, `kor`, `ground`, `onDark`, `onDarkMuted` | aynı dosya |
| Renk (durum) | `success` #4CAF82, `info` #5B8DEF, `danger` #E84040, `dangerGround`, `warning` #FB6F3B | aynı dosya |
| Mood renkleri | `V3Mood` 9 renk: atesli #FF3B1F, coskulu #FF8A00, gergin #8B2FD6, mutlu #FFC300, enerjik #C8F135, odakli #2B4CF0, huzurlu #00B58C, huzunlu #5C6BC0, yorgun #6E7482. Her biri `ink`, `label`, `meaning` ve desen içeriyor. Eski `ONEMood`: 12 renk, 6 dosyada hâlâ geçiyor. | `V3Mood.swift`, `ONEMood.swift`, `V3MoodPattern.swift` |
| Harici marka | `ExternalBrand.spotify`, `appleMusic`, `instagram`, `instagramGradient` | `ExternalBrand.swift` |
| Spacing | `spacingXS` 4 · `SM` 8 · `MD` 12 · `LG` 16 · `XL` 20 · `XL2` 24 · `XL3` 32 · `XL4` 40 · `XL5` 48. `channel` 24, `barInset` 20, `minTouchTarget` 44 | `V3Tokens.swift` |
| Radius | `radiusMicro` 2, `Swatch` 6, `Chip` 8, `Mosaic` 9, `Inner` 12, `Card` 16, `Panel` 20, `Tile` 24, `Hero` 32, `Canvas` 52, `Capsule` 999 | `V3Tokens.swift` |
| Bileşen ölçüleri | `momentCanvasAspect` 4:5, `momentColorCanvasHeight` 200, `momentChipWidth` 66 vb. | `V3Tokens.swift` |
| Tipografi (font fabrikası) | `V3Typography.display` / `displayFixed` (Archivo), `sans` / `sansFixed` (DM Sans), `hand` (Caveat Brush), `mono` / `monoFixed`. Dynamic Type üst sınırı: 20 pt altında ×1.8, 32 pt altında ×1.5. | `one/UI/DesignSystem/V3Typography.swift` |
| Tipografi (roller) | `displayXXL`, `XL`, `Hero`, `LG`, `MD`, `LgAlt`, `SM`, `XS` · `bodyXL` … `bodyMicro` (Medium ve Semibold varyantlarıyla) · `monoBase`, `monoSM`, `monoLabel`, `monoMicro` · ekran rolleri `oneScreenTitle`, `onePageTitle`, `oneSectionTitle`, `oneCardTitle`, `oneEyebrow` | `ONETypography.swift`, `View+ONE.swift` |
| İkon | `iconXS`, `iconSM`, `iconMD`, `iconLG` | `ONEIcon.swift` |
| Motion | Süreler: `durationMicro` 0.15, `Short` 0.25, `Medium` 0.35, `Long` 0.55, `MoodBg` 1.4, `Pulse` 2.0, `Breathe` 3.5. Eğriler: `easing`, `easingPress`, `easingChip`, `easingColor`, `easingSaved` (hepsi cubic 0.2, 0.9, 0.25, 1.0). Yaylar: `micro`, `cardSpring`, `panelSpring`, `screenTransition`, `moodTransition`, `tabSwitch`, `dragSnapBack`, `dragDismiss`. Ayrıca `staggerDelay` ve `buttonPressScale` 0.96. | `ONEAnimation.swift` (42 dosyada kullanılıyor) |
| Haptik | `songSaved`, `saveRitual(mood:)`, `moodSelected`, `feelingSelected`, `tabSwitch`, `friendConnected`, `dayReset`, `error`, `photoCapture`, `pick`, `toggle` | `ONEHaptics.swift` (40 dosya) |
| Elevation | `ONEElevation` + `.elevation(_:)` | `ONEElevation.swift` |

**ONETokens:** Kodda **0 kullanım** kaldı. Adı yalnız iki yorumda geçiyor (`V3Tokens.swift`, `one/Core/Utilities/ONEConfig.swift`). `V3Tokens` 82 dosyada, `V3Typography` 29 dosyada kullanılıyor. Kalan borç `tooling/ui_guard_baseline.txt`'te: `system_font=23`, `raw_screen_padding=40`, `hardcoded_tr=54`, `adhoc_card=18`, `raw_type_scale=38`, `system_nav=9`, `white_on_color=7`.

### 6.2 Yeniden kullanılabilir SwiftUI bileşenleri

| Bileşen | Dosya | Ne yapar |
|---|---|---|
| `V3TopBar`, `V3TopBarLeading`, `V3TopBarStyle`, `V3TopBarIconButton`, `V3TopBarIconGround` | `one/UI/Components/V3TopBar.swift` | Tüm ekranların başlık çubuğu |
| `SubScreen`, `SubScreenNavBar`, `SettingsGroup`, `SettingsRow`, `SettingsToggleRow`, `SettingsUnavailableRow`, `SegmentedControl`, `StatRow`, `InsightCard`, `FilterChip`, `SubScreenState` | `one/UI/Components/SubScreenChrome.swift` | Alt ekran kabuğu ve ayar satırları |
| `V3Sheet`, `V3SheetScreen`, `V3SheetAction`, `V3SheetStack`, `.v3Sheet(detents:)` | `one/UI/Components/V3Sheet.swift` | Modal kabuğu |
| `V3PrimaryButton`, `V3OutlineButton` | `one/Features/Today/V3/V3SharedViews.swift` | Birincil ve ikincil buton (yanlış klasörde duruyor) |
| `ONEPressableButtonStyle` (`.onePressable`), `ONEToggleStyle` (`.one`) | `ONEButtonStyle.swift`, `ONEToggleStyle.swift` | Buton ve toggle stilleri |
| `.oneCardBackground`, `.oneScreen`, `.oneScreenBody`, `.oneScreenGround` | `one/UI/DesignSystem/View+ONE.swift` | Kart zemini ve ekran kenar payı |
| `BottomNavigation`, `PrimaryTab` | `one/UI/Components/BottomNavigation.swift`, `PrimaryTab.swift` | 4 sekmeli alt gezinme |
| `V3Loading`, `V3LoadingRole`, `SerenitySkeleton` | `V3Loading.swift`, `CachedAsyncImage.swift` | Yükleniyor durumları |
| `ONEErrorView`, `ONEToastView`, `ONEToastOverlay`, `V3OfflineBanner` | `one/UI/Components/` | Hata, toast ve çevrimdışı durumları |
| `CachedAsyncImage`, `ImageCache` | `one/UI/Components/` | Görsel önbelleği |
| `V3MomentCard`, `DayFill`, `V3MoodPattern` / `.moodPattern`, `MoodArtworkOverlay` | `one/UI/Components/V3MomentCard.swift`, `one/UI/DesignSystem/` | Renk ve an gösterimi |
| `V3AvatarView`, `V3AvatarPicker`, `V3PersonAvatar` | `one/UI/DesignSystem/V3Avatar.swift` | Avatar |
| `V3HandText`, `OneMascotView`, `ONEAppMark`, `ONEBrand` | `one/UI/Components/`, `one/UI/DesignSystem/` | Marka öğeleri |
| `LiquidGlassContainer`, `ONEGlassFill` | `one/UI/Components/LiquidGlass.swift` | Cam yüzey (Reduce Transparency'de düz zemine düşer) |
| `ScrollHidesTabBar` | `one/UI/Components/ScrollHidesTabBar.swift` | Kaydırınca sekme çubuğunu gizleme |
| `SaveRipple.metal` | `one/UI/DesignSystem/Shaders/` | Kaydetme dalga efekti |

## 7. Yeniden kullanım kararları

TAŞI = olduğu gibi kullan · UYARLA = değiştirerek kullan · BIRAK = yeniden yaz ya da at

| Bileşen / servis | Karar | Gerekçe |
|---|---|---|
| Xcode projesi, target yapısı, senkron klasörler | UYARLA | Aynı proje ve bundle ID korunacak. Extension sürümleri app sürümüne eşitlenmeli, test bundle ID'lerindeki çift nokta düzeltilmeli, boş dosyalar silinmeli. |
| `PersistenceController` (kurtarma, history budama, remote change debounce, açılış bütçesi) | UYARLA | Altyapı sağlam. Entity'ye özel yardımcılar (`savePassedDay`, `insertNewMoment`, `fetchDailySong*`) dışarı alınmalı; gerekirse store App Group'a taşınmalı. |
| `DailySong` entity | BIRAK (şema olarak) | ONE 2.0 modeli tamamen farklı. Entity salt okunur kaynak olarak kalmalı; silinirse taşıma yapılamaz (bkz. Riskler). |
| `Moment`, `Day` struct'ları | UYARLA | Seçenek B'deki `legacyMoment` görünümü için doğrudan kullanılabilir. |
| `DailyEntry`, `FeelingType`, `ONEMood` | BIRAK | v2 kalıntıları. Yalnız taşıma kodu okumalı. |
| `MomentDeduplicator` | BIRAK (fikrini koru) | Mantığı `DailySong`'a özel. `dayKey` tabanlı `DayRecord` birleştirmesi için aynı desen yeniden yazılacak. |
| `MomentWriter` (yan etki merkezi) | UYARLA | Tek yazma noktası ve yüzey tazeleme deseni doğru; hedef tipler değişecek. |
| `ArchiveExporter` | UYARLA | Sabit İngilizce anahtarlı JSON yaklaşımı korunmalı; şema `Entry`, `MoodLog` ve `DayRecord`'a genişletilmeli. |
| `AppLockManager` | UYARLA | LAContext, tolerans ve yaşam döngüsü hazır. PIN ve veri şifreleme kararı (açık soru) sonrası genişletilecek. |
| `KeychainHelper` | TAŞI | Küçük ve genel amaçlı |
| `SpotifyManager` | BIRAK | Client ID tanımlı olmadığı için fiilen ölü; ONE 2.0 günlük odaklı. Şarkı eki MusicKit ile yeterli (tahmin). |
| MusicKit arama (`TodayViewModel.search`, `SongRecommendationEngine`, `SongPreviewPlayer`) | UYARLA | `Media(type: song)` için gerekli. Arama `TodayViewModel`'den bağımsız bir servise çıkarılmalı. |
| `NotificationOrchestrator`, `NotificationPolicy`, `NotificationMessageBuilder` | UYARLA | Politika, bastırma ve analitik altyapısı iyi. Sabah ve akşam hatırlatıcıları ile ritüel modları için yeni türler eklenecek. Mevcut ID'ler emekli listesine alınmalı. |
| `V3ReminderScheduler`, `SundayReflectionScheduler`, `MonthlyPortraitScheduler` | BIRAK | v3 ritüellerine özel. ID'leri `retiredIdentifiers`'a eklenmeli. |
| CloudKit sosyal katmanı (`CloudKitManager` + 10 extension/servis, `Features/Circle`, `PublicProfile`, `Comments`) | BIRAK (karar bekliyor) | Stoic modelinde sosyal katman yok. Tutulursa ayrı modül olmalı. Tutulmazsa subscription temizliği şart. |
| `WidgetDataWriter` + `MoodWidget` | UYARLA | App Group köprüsü çalışıyor. Anahtar şeması ve görünüm ONE 2.0 için yeniden tasarlanmalı. Widget `kind`'ı korunursa kullanıcının ana ekranındaki widget kaybolmaz (tahmin). |
| Live Activity extension | BIRAK | Bayrakla kapalı, v3 özelliği. Target silinebilir ya da ONE 2.0'da yeniden değerlendirilebilir. |
| App Intents (`SaveMomentIntent` vb.) | UYARLA | Kısayol sözleşmesi korunmalı; `MoodLog(source: shortcut)` yazmalı. |
| `AppAnalytics` + PostHog | TAŞI | Protokol soyutlaması temiz. Olay kataloğu (`AnalyticsEvent`, 102 case) BIRAK, yeniden yazılacak. |
| `CrashReporter`, `LaunchMetricsCollector`, `ONELaunchSignpost`, `ONELogger` | TAŞI | Genel altyapı |
| `LaunchIntent` + deep link yönlendirme | UYARLA | Desen doğru. Host'lar ve sekmeler ONE 2.0 navigasyonuna göre değişecek; `ones://today` gibi widget linkleri korunmalı. |
| `Experiment` / `Features` | TAŞI | Küçük ve genel |
| `LanguageManager` + 9 dil `.lproj` | UYARLA | Altyapı kalır. İçerik anahtarları büyük ölçüde yeniden yazılacak. |
| `AppleSignInService` | BIRAK (karar bekliyor) | Yalnız Çevre için var |
| `AppReviewManager` | TAŞI | Genel |
| `V3Tokens` (renk, spacing, radius), `V3Typography`, `ONETypography`, `ONEIcon`, `ONEAnimation`, `ONEHaptics`, `ONEElevation` | TAŞI | Olgun ve kontrast testli. ONE 2.0 görsel dili değişse bile token *yapısı* korunur, değerler değişir (tahmin). |
| `V3Mood` (9 renk) | UYARLA | ONE 2.0 `score 1–5` + `emotionIDs` kullanıyor. Renkler duygu kataloğunun görsel katmanı olabilir; eşleme kararı gerekiyor. |
| Kabuk bileşenleri (`V3TopBar`, `SubScreen`, `V3Sheet*`, `BottomNavigation`, butonlar, stiller, `oneCardBackground`) | TAŞI | Ekran sözleşmesinin temeli. `V3PrimaryButton` ve `V3OutlineButton` `UI/Components`'e taşınmalı. |
| Durum bileşenleri (`V3Loading`, `ONEErrorView`, `ONEToast*`, `V3OfflineBanner`, `CachedAsyncImage`) | TAŞI | Genel |
| An ve renk görselleri (`V3MomentCard`, `DayFill`, `V3MoodPattern`, `MoodArtworkOverlay`, `ONEColorPickerView`) | UYARLA | Legacy arşiv görünümü ve mood görselleştirmesi için |
| Feature ekranları (`Features/Today`, `Archive`, `Echo`, `MonthlySummary`, `Profile`, `Share`, `Camera`, `Onboarding`) | BIRAK | Ürün akışı tamamen değişiyor. `Camera` ve `Share/V3StoryComposer` parçaları ileride `Media` için yeniden değerlendirilebilir. |
| `tooling/ui_guard.sh`, `font_guard.py`, `verify_colors.sh` | UYARLA | Mekanizma değerli; kurallar ONE 2.0'a göre yeniden ayarlanmalı. |
| `tooling/voice_guard.py` | UYARLA | Seri ve ölçme yasakları ONE 2.0 ile çelişiyor. |
| `tooling/*.json` dökümleri, `fetch_dailyshare.py` | BIRAK | Repodan çıkarılmalı (bkz. Riskler) |

## 8. Testler ve CI

| Öğe | Durum | Kaynak |
|---|---|---|
| Birim testleri | 15 dosya, yaklaşık 2.950 satır, **Swift Testing** (`@Test`, 176 test). XCTest kullanılmıyor. | `oneTests/` |
| Kapsanan alanlar | Persistence CRUD, ay sorguları ve kapsam (`PersistenceControllerTests`, in-memory store) · renk hex dönüşümü · kontrast/WCAG (`ContrastTests`) · mood eksiksizliği · bildirim politikası ve mesaj üretimi · dışa aktarma · aylık özet · Echo verisi · `DailyEntry` · `AppError` / `ErrorHandler` · `PinnedSong` · Today modelleri | `oneTests/*.swift` |
| Kapsanmayan alanlar | CloudKit (public ve private), `MomentDeduplicator`, remote change uzlaştırma, `AppLockManager`, `SpotifyManager`, MusicKit, widget ve App Group yazımı, deep link yönlendirme, App Intents, migration | — |
| UI testleri | 3 dosya, 7 test. `MoodLogSmokeTests` (4 test) ve şablon testleri. | `oneUITests/` |
| Test planı | `tooling/One - Günlük Mood.xctestplan` artık var olmayan `One - Günlük Mood.xcodeproj` yoluna işaret ediyor; **bozuk**. | dosya içeriği |
| CI | **Yok.** GitHub Actions workflow'u, Xcode Cloud `ci_scripts` ya da fastlane bulunamadı. Üst klasörde yalnız `.github/pull_request_template.md` var. | `../.github/` |
| Yerel guard'lar | `tooling/ui_guard.sh` (yalnız azalan eşikler), `voice_guard.py`, `font_guard.py`, `dead_keys.py`, `verify_colors.sh`, `.swiftlint.yml`. Build phase'e bağlı değiller (pbxproj'de shell script phase yok). | `tooling/`, pbxproj |
| Kapsama gözlemi | Saf mantık (renk, politika, biçimlendirme) iyi test edilmiş. Veri bütünlüğünün en riskli olduğu yerler (sync, uzlaştırma, taşıma) test dışında. ONE 2.0 taşıma kodu yazılmadan önce gerçek bir v3 SQLite store'undan fixture alınıp test edilmeli. | — |

## 9. Riskler

| # | Risk | Olasılık / etki | Kaynak | Önlem |
|---|---|---|---|---|
| R1 | **Bundle ID karışıklığı.** Plan `com.batudemir.ones` diyor, gerçek ID `com.batu.ones`. Yanlışlıkla değiştirilirse App Store kaydı, CloudKit container erişimi, Keychain (Spotify token'ı, onboarding bayrakları) ve KVS kopar. | Orta / çok yüksek | pbxproj, `one/one.entitlements` | `00_faz0_plan.md` düzeltilmeli. ADR'de ID'ler sabitlenmeli: `com.batu.ones`, `iCloud.com.batu.ones`, `group.com.batudemir.ones`. |
| R2 | **CloudKit şeması geri alınamaz.** Üretime deploy edilen record type ve alanlar silinemez, tipleri değiştirilemez. `CD_DailySong` sonsuza kadar kalır. Yeni entity'ler development'ta oluşup deploy edilmeden yayınlanırsa üretimde sync sessizce durur. | Yüksek / yüksek | `Persistence.swift`, `CLOUDKIT_PRODUCTION_DEPLOYMENT.md` | Yeni model *eklemeli* olmalı: `DailySong` model sürümünde kalsın. Yayın kontrol listesine "Dashboard → Deploy Schema Changes" adımı eklenmeli. Development'ta `initializeCloudKitSchema` ile şema üretilmeli. |
| R3 | **Model sürümü.** `one 2.xcdatamodel`, `one.xcdatamodel`'in birebir kopyası. ONE 2.0 entity'leri yeni sürüme (`one 3`) eklenirse lightweight migration çalışır. Ama mevcut sürümler düzenlenir, entity yeniden adlandırılır ya da silinirse store açılmaz ve `recoverFromUnopenableStore` yerel store'u **siler** (veri CloudKit'ten geri iner, ama CloudKit kapalı kullanıcıda veri kaybolur). | Orta / çok yüksek | `Persistence.swift` `recoverFromUnopenableStore` | Yalnız yeni sürüm ekle; `DailySong`'a dokunma. iCloud'u kapalı kullanıcı için kurtarma yolu, store silinmeden önce yedek almalı. |
| R4 | **Gün kayması.** v3 `date` alanı, yazıldığı andaki yerel saat dilimine göre `startOfDay` olarak saklanıyor. `dayKey` bu alandan türetilirse, farklı saat diliminde girilen kayıtlar bir gün kayabilir. | Orta / orta | `Persistence.swift` `insertNewMoment` | Taşımada `dayKey`, `createdAt` + o anki saat diliminden değil, `date` bileşenlerinden (yerel takvim) türetilmeli ve test edilmeli. Saat dilimi bilgisi saklanmadığı için tam doğruluk mümkün değil (tahmin). |
| R5 | **Store App Group'ta değil.** ONE 2.0 widget'ı Core Data'dan okumak isterse store'un taşınması gerekir. Taşıma sırasında CloudKit mirroring metadata'sı bozulursa tam yeniden indirme ya da çift kayıt olur. | Orta / yüksek | `Persistence.swift` | Tercihen UserDefaults köprüsünü koru. Taşınacaksa `replacePersistentStore` ile tek seferlik, test edilmiş bir göç yapılmalı. |
| R6 | **Widget kimliği.** Widget kind'ı `"MoodWidget"`, App Group anahtarları `widget_*`. Kind değişirse kullanıcıların ana ekranındaki widget'lar boşa düşer (tahmin). Live Activity extension'ında App Group yok. | Orta / orta | `MoodWidget/MoodWidget.swift`, `WidgetDataWriter.swift` | Kind korunmalı ya da bilinçli değiştirilmeli. Anahtar şemasına sürüm eklenmeli. |
| R7 | **Bildirim kimlikleri.** `v3_daily_reminder_*` (prefix), `sunday_reflection_1/2`, `monthly_portrait_1/2`, `app_update_available` cihazlarda beklemede. Kod silinirse bu istekler v3 metniyle çalmaya devam eder. `repeats: true` olanlar süresiz. | Yüksek / orta | `NotificationOrchestrator.swift` `retiredIdentifiers`, zamanlayıcılar | Hepsi ONE 2.0'ın ilk açılışta çalışan temizlik listesine eklenmeli; prefix için `getPendingNotificationRequests` ile filtrelenmeli. |
| R8 | **CloudKit subscription'ları.** Public DB'de kullanıcı başına 5 query subscription var. Çevre kaldırılırsa sunucu arkadaş olaylarında push göndermeye devam eder; kategoriler kaybolursa bildirim yanlış açılır. | Yüksek (Çevre kalkarsa) / orta | `CloudKitNotificationService.swift` | Bir geçiş sürümünde `CKModifySubscriptionsOperation` ile silinmeli. Public kayıtlar (AppUser vb.) için silme ya da anonimleştirme politikası belirlenmeli. |
| R9 | **Veri anlamı.** `moodColorHex` serbest renk içerebiliyor (renk seçici). V3Mood'a eşlenmeyen kayıtlar var; `closest(toHex:)` RGB yakınlığına göre tahmin ediyor. 1–5 skora eşleme (Seçenek A) keyfi olur. | Kesin / orta | `V3Mood.swift` | Seçenek B'yi destekliyor: renk ve not olduğu gibi `legacyMoment` olarak korunur. |
| R10 | **Pas günleri.** `passed = true` satırları gerçek kayıt değil. Taşımada `Entry`'ye çevrilirse streak ve istatistikleri şişirir. | Kesin / düşük | `savePassedDay` | Taşıma bunları atlamalı ya da ayrı işaretlemeli. |
| R11 | **Foto verisi.** `photoData` harici ikili depolamada ve CloudKit'te asset. Büyük arşivlerde taşıma sırasında bellek ve süre sorunu olur. Dışa aktarma fotoları kapsamıyor. | Orta / orta | model, `ArchiveExporter.swift` | Taşıma arka plan context'inde, batch'ler halinde; asset'ler referansla (kopyalamadan) bağlanmalı (tahmin). |
| R12 | **Kurallar çelişkisi.** `CLAUDE.md`, ui_guard ve voice_guard ONE 2.0'ın temel özelliklerini (streak, rozet, backfill, skor) yasaklıyor. | Kesin / yüksek (süreç) | `CLAUDE.md`, `tooling/` | Faz 1'den önce `CLAUDE.md` ONE 2.0 için yeniden yazılmalı; eski dosya `docs/archive`'e alınmalı. |
| R13 | **Kullanıcı verisi repoda.** Üretim public DB dökümleri git'te izleniyor. | Kesin / yüksek (repo public ise) | `tooling/appusers.json`, `dailyshare.json`, `friendships.json` | Repo görünürlüğü doğrulanmalı. Dosyalar `.gitignore`'a alınmalı; public ise geçmişten de temizlenmeli (Batuhan'ın kararı). |
| R14 | **Kısayollar ve deep link'ler.** Kullanıcıların kurduğu Kısayollar `SaveMomentIntent` tipine; widget ve paylaşılan davet linkleri `ones://…` ve `one.forvibe.app/invite` adreslerine bağlı. Tip ya da host kaldırılırsa sessizce kırılırlar. | Orta / düşük | `one/Core/Intents/`, `one/oneApp.swift` | Intent tipleri en az bir sürüm boyunca uyumluluk için tutulmalı; eski host'lar yeni ekranlara yönlendirilmeli. |
| R15 | **`@SceneStorage` sekme anahtarları.** `PrimaryTab` rawValue'ları (`entry`, `archive`, `circle`, `profile`) kayıtlı durumu geri yüklüyor. Yeni sekme yapısında eski değer tanınmayan bir sekmeye düşebilir. | Düşük / düşük | `one/UI/Components/PrimaryTab.swift` | Tanınmayan değer için varsayılan sekmeye düşülmeli. |
| R16 | **Sürüm ve imza düzensizlikleri.** Extension'lar 2.5 (build 40), app 3 (build 8). Test bundle ID'lerinde çift nokta var. Test planı bozuk. CI yok. | Kesin / düşük–orta | pbxproj, `tooling/*.xctestplan` | Faz 1 başında düzeltilmeli; en azından `xcodebuild test` çalıştıran minimal bir CI kurulmalı. |
| R17 | **Spotify bağımlılığı.** Spotify'dan gelmiş `spotifyURL` ve `platform = "Spotify"` kayıtları var. Keychain'de eski token kalabilir. | Düşük / düşük | `SpotifyManager.swift` | Taşımada yalnız metin olarak korunmalı; Keychain öğesi temizlenmeli. |
