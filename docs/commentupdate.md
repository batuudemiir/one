# ONE v2.5 — Comment System Implementation Guide
**Multi-perspective: Mimari · UI · Güvenlik**
**Tarih:** 2026-05-09

---

## BÖLÜM 1 — MİMARİ PLAN (Planner Perspektifi)

### 1.1 CloudKit Schema Deploy Sırası

**Sıra önemli — önce Development, sonra Production:**

1. `Comment` record type oluştur → indeksler: `shareRecordName+createdAt` (desc), `authorUserID+createdAt` (desc), `shareOwnerID+createdAt` (desc), `moderationStatus`
2. `Block` record type → indeksler: `blockerUserID`, `blockedUserID`
3. `Report` record type → indeksler: `targetRecordName`, `reporterUserID`
4. `Friendship` record'a `source: String` field ekle (default `"invite_code"`, existing record'lar için migration script)
5. Development'ta test → Production'a push → aynı build slot'ta v2.5 client yayınla

**Kritik:** `Comment` record type'ında `moderationStatus` field'ı `queryable` olmalı — subscription predicate bu field'ı kullanıyor.

---

### 1.2 Yeni Servis Dosyaları

#### `CloudKitCommentService.swift`
```
Path: one/Core/Managers/CloudKitCommentService.swift

func postComment(shareRecordName: String, shareOwnerID: String, body: String) async throws -> Comment
func fetchComments(shareRecordName: String, cursor: CKQueryOperation.Cursor?) async throws -> ([Comment], CKQueryOperation.Cursor?)
func editComment(commentID: String, newBody: String) async throws -> Comment
func deleteComment(commentID: String) async throws
func deleteComment(commentID: String, asOwnerOf shareRecordName: String) async throws  // post sahibi başkasının yorumunu siler
func fetchCommentCount(shareRecordName: String) async throws -> Int
```

#### `CloudKitBlockService.swift`
```
Path: one/Core/Managers/CloudKitBlockService.swift

func blockUser(blockedUserID: String) async throws
func unblockUser(blockedUserID: String) async throws
func fetchBlockedUserIDs() async throws -> [String]
func isBlocked(userID: String) async throws -> Bool
```

#### `CloudKitReportService.swift`
```
Path: one/Core/Managers/CloudKitReportService.swift

func reportContent(targetType: ReportTargetType, targetRecordName: String, reason: ReportReason, note: String?) async throws
func incrementReportCount(commentID: String) async throws -> Int  // dönen sayı >= 3 ise client hidden set eder
```

#### `CommentRateLimiter.swift`
```
Path: one/Core/Managers/CommentRateLimiter.swift

func canPost() -> Bool
func recordPost()
func secondsUntilNextAllowed() -> Int  // UI için countdown
// State: UserDefaults'ta [timestamp] array, per-minute ve per-hour window kontrolü
```

---

### 1.3 CloudKitManager God-Object'ten Ayrılma Stratejisi

**Kırmadan böl — facade pattern:**

1. `CloudKitManager.swift`'e yeni servisler için lazy property ekle:
   ```swift
   lazy var commentService = CloudKitCommentService(container: container)
   lazy var blockService = CloudKitBlockService(container: container)
   lazy var reportService = CloudKitReportService(container: container)
   ```
2. View'lar ve ViewModel'lar `CloudKitManager.shared.commentService.postComment(...)` üzerinden erişir
3. Eski `CloudKitManager` metodları dokunulmaz — breaking change yok
4. v2.6'da `CloudKitManager` facade'a indirgenir

---

### 1.4 Notification Subscription

**`CloudKitNotificationService.swift`'e eklenecek:**

```
subID: "comment-notification-v1"
predicate: shareOwnerID == currentUserID AND moderationStatus == "active"
firesOn: .recordCreation
desiredKeys: ["shareRecordName", "authorUserID", "body"]
collapseIDKey: "shareRecordName"   // APNs seviyesinde birleştirme
```

**Push handler akışı:**
1. Block list kontrolü → blocked ise sessizce düş
2. displayName + mood fetch (paralel Task group)
3. `CommentNotificationBundler.enqueue(shareRecordName, authorName, body)`
4. 5 sn debounce → 1 yorum: `commentReceived`, 2+: `commentBatch`
5. `NotificationOrchestrator.schedule(...)`
6. `CircleNotificationStore.add(...)`

**`CommentNotificationBundler.swift`:**
```
Path: one/Core/Notifications/CommentNotificationBundler.swift

private var pending: [String: [PendingComment]] = [:]
private var timers: [String: Timer] = [:]
func enqueue(shareRecordName: String, authorName: String, body: String)
func flushAll()  // app background'a giderken çağrılır
```

---

### 1.5 EmojiReaction Deprecation

| Adım | Ne yapılır |
|------|-----------|
| v2.5.0 | `sendEmojiReaction`, `fetchEmojiReaction` → `@available(*, deprecated, message: "Use CommentService")` |
| v2.5.0 | Internal çağrılar kaldırılır, historical read bırakılır |
| v2.5.0 | `emoji-reaction-notification-v4` → `legacySubIDs` listesine taşınır |
| v2.5.0 | `currentSubVersion` 6 → 7 bump |
| v2.5.1 | UI'dan emoji görünümü tamamen kaldırılır |
| v2.6 | CloudKit'ten fiziksel silme script'i |

---

### 1.6 Feature Flag

```swift
// AppStorage key: "feature.comments.enabled"
// Bucket: invite code'un son karakterine göre %10 açık
// Remote override: CloudKit'te basit KV record type "FeatureFlag"
// Kapatma: AppStorage false set → tüm CommentThreadView'lar gizlenir
```

---

### 1.7 Offline Comment Queue

- Yazılan yorum `FileManager`'a `pending_comments.json` olarak kaydedilir
- `scenePhase == .active` olduğunda `CloudKitCommentService.flushPendingComments()` çağrılır
- Başarılı gönderimde queue'dan çıkar, başarısızda retry banner gösterilir
- iCloud account değişiminde queue silinir + kullanıcıya toast

---

### 1.8 Cascade Delete (Post Silinince Yorumlar)

- v2.5.0: Manuel — `CloudKitDailyShareService.deleteShare(...)` içinde `Comment` query by `shareRecordName` + batch delete
- v2.5.1: Otomatik CloudKit reference + cascade delete

---

### 1.9 Değiştirilecek Dosyalar (Tam Liste)

| Dosya | Ne değişir |
|-------|-----------|
| `CloudKitNotificationService.swift` | Comment sub eklenir, emoji sub legacy'ye alınır |
| `oneApp.swift` | `COMMENT_NOTIFICATION` category + "Yanıtla" UNTextInputNotificationAction |
| `NotificationPolicy.swift` | `commentReceived`, `commentBatch` kind'ları eklenir |
| `NotificationMessageBuilder.swift` | Yorum mesaj varyantları |
| `NotificationOrchestrator.swift` | `commentReceived` için dedup muafiyeti |
| `FriendShareDetailView.swift` | `emojiSection` → `CommentThreadView` |
| `FriendDetailView.swift` | `emojiRow` kaldırılır |
| `CloudKitDailyShareService.swift` | Emoji metodları deprecated, cascade delete eklenir |
| `CloudKitFriendshipService.swift` | `sendFriendRequest(toUserID:source:)` yeni parametre |
| `AddFriendView.swift` | `source: .inviteCode` geçişi |
| `ProfileView.swift` | "Engelli kullanıcılar" satırı (settings altında) |
| `CircleNotificationStore.swift` | `commentReceived` kind eklenir |

---

## BÖLÜM 2 — UI TASARIM KARARLARI (UI-Agent Perspektifi)

### 2.1 CommentThreadView

**Sunum:** Bottom sheet (detachedSheet modifier) — tam ekran değil. FriendShareDetailView içinde mini kart altında "N yorum" label'ına tap ile açılır.

**Layout:**
```
┌─────────────────────────────────┐
│ ▬  (drag indicator)             │
│ [Mini post card — mood rengi]   │
│ ─────────────────────────────── │
│ [CommentRow]                    │
│ [CommentRow]                    │
│ [CommentRow]                    │
│ ...                             │
│ [Daha fazla göster] (50+ ise)   │
│ ─────────────────────────────── │
│ [CommentComposerView]           │
└─────────────────────────────────┘
```

**Renkler:** `oneCream` arka plan, `oneAsh` separator, mood'un `.pastelColor` mini card arka planında (saturated değil)

**Empty state:** Merkez hizalı, `ONETypography.bodyLG`, "İlk yorumu sen yap 💬", `oneAsh` renk

**Animasyon:** Yorum gönderilince CommentRow `.transition(.asymmetric(insertion: .move(edge: .bottom).combined(with: .opacity), removal: .opacity))`

---

### 2.2 CommentRowView

**Layout:**
```
[●] Ada · 2 dk önce              [⋯]
    Bu şarkı bugün tam kıvamında...
```

- Avatar: `ONEMood.avatarColor` ile dolu circle, 32pt
- displayName: `ONETypography.bodyMD`, bold
- Zaman: `ONETypography.caption`, `oneAsh`
- Body: `ONETypography.bodyMD`, tam genişlik, çok satır
- "(düzenlendi)" rozeti: `ONETypography.caption`, italik, `oneAsh`

**⋯ Menü içeriği:**
- Kendi yorumum: "Düzenle" + "Sil" (kırmızı)
- Başkasının: "Şikayet et" + "Engelle" (kırmızı)
- Post sahibi başkasının yorumunda: "Şikayet et" + "Engelle" + "Sil" (kırmızı)

**Long press:** `popoverTip` stili — küçük profil kartı preview (displayName + avatar + "Profili gör" CTA)

**Accessibility:** `accessibilityLabel("\(name), \(relativeTime): \(body)")`

---

### 2.3 CommentComposerView

```
┌─────────────────────────────────┐
│ [TextField "Yorum yaz..."]  280 │
│                          [→]   │
└─────────────────────────────────┘
```

- Background: `oneCream`, üst border `oneAsh`
- Counter: `ONETypography.monoMicro` — 260+ olunca `oneBrand` renk, 280'de kırmızı
- Gönder button: `oneBrand` dolu circle, ok icon — disabled ise `oneAsh`
- Rate limit state: TextField disabled, counter yerine "N sn sonra tekrar dene" (`oneAsh`, countdown)
- Offline error: Üstte kırmızı `oneAsh` stripe + "Bağlantı yok · Tekrar dene"

---

### 2.4 PublicProfileView

**Sunum:** NavigationLink ile push (bottom sheet değil — daha kalıcı hissettiriyor)

**Layout:**
```
[← Geri]

        [●]          ← 64pt avatar circle (mood rengi)
      Ada Yılmaz
      @adayilmaz
      ONE'a katıldı Mart 2025

  [🔥 12 gün serisi]  [📅 47 gün paylaşım]

  ┌─────────────────────────────┐
  │  Takip isteği gönder        │  ← CTA (duruma göre değişir)
  └─────────────────────────────┘

  [Son 7 gün mood grid]  ← sadece arkadaşsa

  ─────────────────────────────
  [Şikayet et]   [Engelle]
```

**CTA renk matrisi:**
- "Takip isteği gönder" → `oneBrand` dolu, `ONETypography.bodyMD` bold
- "İstek gönderildi · İptal et" → ghost button, `oneAsh` border
- "Kabul et" / "Reddet" → yan yana, Kabul `oneBrand`, Reddet ghost
- "Çevrende" badge → `oneBrandLight` arka plan, `oneBrand` metin
- "Engeli kaldır" → ghost button

**isPublic=false:** Metrikler gizlenir, "Bu kullanıcı profilini gizli tuttu" → `ONETypography.bodyMD`, `oneAsh`, italic

**7 gün mood grid:** 7 circle (28pt), her biri `.pastelColor` — arkadaş değilse görünmez

---

### 2.5 ReportSheet

**Sunum:** `.sheet` half-height

**Layout:**
```
Şikayet Et
─────────────────
○ Spam
○ Taciz
○ Nefret söylemi
○ Kendine zarar verme
○ Diğer
─────────────────
[Not ekle (isteğe bağlı)]  ← 500 char max
─────────────────
[Gönder]  [İptal]
```

- Başlık: `ONETypography.titleMD`
- Seçenekler: radio-style, `oneBrand` selected state
- Not: `TextEditor`, `oneAsh` border, subtle placeholder
- Gönder: `oneBrand` — seçim yapılmadan disabled

---

### 2.6 FriendShareDetailView Güncellemesi

**Mevcut:** `emojiSection` (5 emoji buton)
**Yeni:**
```swift
// "N yorum" sayaç (tap → CommentThreadView)
HStack {
    Image(systemName: "bubble.left")
        .foregroundStyle(ONETokens.oneAsh)
    Text("\(commentCount) yorum")
        .font(ONETypography.bodyMD)
        .foregroundStyle(ONETokens.oneAsh)
}
.onTapGesture { showCommentThread = true }
.sheet(isPresented: $showCommentThread) {
    CommentThreadView(shareRecordName: share.recordName)
}
```

---

### 2.7 Intro Banner

**Tek seferlik, `commentsIntroBannerDismissed: Bool` UserDefaults ile:**

```
┌─────────────────────────────────┐
│ 💬 Artık çevrende yorum         │
│    yapabilirsin — emojiler       │
│    tarih oldu.           [✕]    │
└─────────────────────────────────┘
```

- `oneBrandLight` arka plan, `oneBrand` border (1pt)
- `ONETypography.bodyMD`, sol hizalı
- Dismiss: ✕ button sağ üst, `oneAsh`
- Animasyon: `.transition(.move(edge: .top).combined(with: .opacity))`

---

## BÖLÜM 3 — GÜVENLİK & MODERASYON (Security Perspektifi)

### 3.1 App Store Guideline 1.2 — Eksik Gereklilikler

| Gereklilik | Durum | Aksiyon |
|-----------|-------|---------|
| Objectionable content filtering | ⚠️ Sadece client-side | Yeterli — App Store için kabul edilebilir başlangıç |
| Block user | ✅ Block sistemi planlandı | `CloudKitBlockService` implement edilmeli |
| Report system | ✅ Report sistemi planlandı | `CloudKitReportService` implement edilmeli |
| Published EULA | ❌ Eksik | `docs/USER_CONTENT_POLICY.md` oluşturulmalı |
| Act on reports within 24h | ⚠️ Manuel review | CloudKit dashboard üzerinden başlangıçta yönetilir |
| No tolerance statement | ❌ Eksik | Privacy Policy güncellenmeli |

**Zorunlu dokümanlar:**
- `docs/USER_CONTENT_POLICY.md` — Apple'ın dil kullanımıyla zero tolerance beyanı, 24 saat yanıt SLA
- `docs/PRIVACY_POLICY.md` — yorum verisi nasıl saklanıyor, ne kadar tutuluyor, cascade delete garantisi

---

### 3.2 CloudKit Güvenlik Rolleri

**Kritik:** CloudKit public database'de record security roles doğru ayarlanmazsa herkes herkesin yorumunu editleyebilir.

```
Comment record permissions:
- Creator: read + write + delete (kendi yorumu)
- Authenticated users: read only (active moderationStatus)
- World: NO ACCESS

Block record permissions:
- Creator only: read + write + delete

Report record permissions:
- Creator: write only (raporu gördüremez)
- Admin (Dashboard): full access
```

**`authorUserID` validation:** Server-side yoksa client `authorUserID`'yi manipüle edebilir. CloudKit'te `creatorUserRecordID` ile çapraz kontrol yapılmalı — `postComment`'te `authorUserID` field'ına güvenilmemeli, `CKRecord.creatorUserRecordID` canonical kullanılmalı.

---

### 3.3 Input Validation

**Client-side (minimum):**

| Kontrol | Nerede | Detay |
|---------|-------|-------|
| Uzunluk | CommentComposerView | ≤280 char, TextField `onChange` |
| URL engeli | CloudKitCommentService | `body.contains("http") || body.contains("www")` → throw |
| Boş yorum | Composer | Send disabled if `body.trimmingCharacters.isEmpty` |
| Null byte / control chars | CloudKitCommentService | `body.unicodeScalars.filter { $0.value < 32 }` → strip |
| RTL override character | CloudKitCommentService | U+202E ve benzeri BiDi control chars → strip |

**Server-side yokluğu:** CloudKit Functions yok. Tüm validasyon client-side. Bu kabul edilebilir — bad actor kendi datasını bozabilir ama başkasının datasına yazamaz (CloudKit permission sayesinde).

---

### 3.4 Rate Limiting — Client-Only Riski

**Mevcut plan:** 5/dk, 30/saat client-side throttle (CommentRateLimiter, UserDefaults)

**Sorun:** Jailbreak cihaz veya direkt CloudKit API çağrısı ile bypass edilebilir.

**Hafifletme:**
- CloudKit kendi başına kaba kuvvet saldırılarını throttle eder (Apple seviyesinde)
- `moderationStatus` + `reportCount` sistemi spam'i ex-post gizler
- v2.5.0 için client-side yeterli. v2.6'da CloudKit Functions gelirse server-side eklenebilir

---

### 3.5 Push Reply Action Güvenliği

**Risk:** `UNTextInputNotificationAction` ile lock screen'den CloudKit'e direkt yorum yazılıyor.

**Attack surface:**
- Kullanıcı kimlik doğrulaması: CloudKit token gerektirir — anonim değil ✅
- Replay: her push unique `commentID` içermeli — duplicate kontrolü `CloudKitCommentService`'de
- Uzunluk: `UNTextInputNotificationAction` body SwiftUI'dan geçmiyor, ayrıca validate edilmeli

**Fix:** Push reply handler'da da `body.count <= 280` + control char strip + URL engeli uygulanmalı. `ContentAvailable` push'larında replay koruması için `userInfo["nonce"]` eklenebilir (v2.5.1).

---

### 3.6 Block Sistemi — Tamamlık

**İki-yönlü görünmezlik client-side filter ile:**
```swift
// Comment fetch'ten sonra:
let blockedIDs = await blockService.fetchBlockedUserIDs()
let filtered = comments.filter { !blockedIDs.contains($0.authorUserID) }
```

**Bildirim suppression:** Push handler'da block list check #1 numaralı adım (§1.4'te belirtildi) ✅

**Mevcut yorum davranışı:** A, B'yi engellerse B'nin önceki yorumları da client-side filtreyle gizlenir — CloudKit'ten silinmez (moderasyon için record kalır)

---

### 3.7 Report Sistemi — Auto-Hide Riski

**Mevcut plan:** 3+ rapor → client-side `moderationStatus = "hidden"` set eder

**Sorun:** `reportCount` field'ını kim yazıyor? Eğer her reporter client kendi `reportCount` increment'ini yazıyorsa race condition + manipulation riski var.

**Önerilen düzeltme:**
```
Report record oluşturulur (her rapor ayrı record)
Client tarafta: aynı shareRecordName'e ait Report count'u query ile say
Count >= 3 ise → Comment'in moderationStatus'unu "hidden" yap
```
Bu şekilde `Comment` record'undaki `reportCount` field'ı kaldırılabilir — gerçek sayım Report record count'undan gelir. Manipulation yapılsa bile Report record'ları CloudKit'te görünür (dashboard'dan incelenebilir).

---

### 3.8 Profanity Filter — Türkçe False Positive

**Sorun:** "öldüm gülmekten", "siktir et" (argo ama yaygın), "kahretsin" gibi ifadeler bağlam-bağımlı.

**Strateji:**
- Blacklist'i yalnızca ciddi hate speech + slur'larla kısıtlı tut (~50 kelime)
- Threshold: exact match değil, `lowercased().contains()` + Levenshtein distance 1 (basit bypass önlemi)
- False positive olursa kullanıcıya "Bu yorum gönderilemedi" generic mesaj — neden belirtme (gaming önlemi)
- v2.6'da Apple'ın `NaturalLanguage` framework + MLModel ile context-aware filtering

---

### 3.9 KVKK / GDPR — Veri Saklama

- Kullanıcı hesabını silerse → tüm `Comment` record'ları `authorUserID` query ile cascade delete
- `Block` ve `Report` record'ları: 90 gün sakla (moderasyon audit için), sonra sil
- `body` field'ı kişisel veri sayılır → Privacy Policy'de belirtilmeli
- CloudKit'in veri bölgesi: Apple'ın EU data center'ları — KVKK için yeterli

---

### 3.10 Analytics — PII Riski

**Şüpheli event'ler:**
- `comment_posted(length_bucket, has_emoji)` → ✅ güvenli, PII yok
- `profile_viewed_from_comment(source, targetUserID)` → ⚠️ `targetUserID` loglanıyor — internal user ID, PII sayılabilir
- `comment_reported(reason)` → ✅ güvenli

**Fix:** `targetUserID` yerine `targetUserIDHash` (SHA256, ilk 8 char) logla — analytics için yeterli, PII değil.

---

## BÖLÜM 4 — UYGULAMA SIRASI

### Sprint 1 (v2.5.0 — Core)
1. CloudKit schema deploy (Development)
2. `Comment`, `Block`, `Report` model dosyaları
3. `CloudKitCommentService` + `CloudKitBlockService` + `CloudKitReportService`
4. `CommentRateLimiter`
5. `CommentThreadView` + `CommentRowView` + `CommentComposerView`
6. `FriendShareDetailView` — emoji → yorum geçişi
7. Notification subscription + `CommentNotificationBundler`
8. `NotificationPolicy` + `NotificationMessageBuilder` güncellemeleri
9. Push reply action (AppDelegate)
10. Feature flag (%10 bucket)
11. Production schema deploy + release

### Sprint 2 (v2.5.1 — Polish)
- `PublicProfileView` + friend request CTA matrisi
- `ReportSheet`
- Reply thread (1-seviye)
- @mention autocomplete
- Emoji UI tamamen kaldır
- `USER_CONTENT_POLICY.md` + Privacy Policy güncelleme

### Sprint 3 (v2.6)
- Moderasyon dashboard (CloudKit dashboard flow)
- EmojiReaction fiziksel silme script'i
- Push notification granular preferences
- Context-aware profanity filter (NaturalLanguage)

---

## BÖLÜM 5 — KRİTİK DOSYALAR ÖZETİ

**Yeni (12 dosya):**
`CloudKitCommentService` · `CloudKitBlockService` · `CloudKitReportService` · `CommentRateLimiter` · `Comment` · `Block` · `Report` · `PublicUserProfile` · `CommentThreadView` · `CommentRowView` · `CommentComposerView` · `CommentNotificationBundler`

**Güvenlik öncelikli (Sprint 0 — release öncesi):**
- `Info.plist` → Spotify client ID xcconfig'e taşı **(CRITICAL)**
- `Secrets.xcconfig` → proje dışına taşı, Ticketmaster key rotate et **(CRITICAL)**

**Düzenlenecek (13 dosya):**
`CloudKitNotificationService` · `CloudKitDailyShareService` · `CloudKitFriendshipService` · `NotificationPolicy` · `NotificationMessageBuilder` · `NotificationOrchestrator` · `FriendShareDetailView` · `FriendDetailView` · `AddFriendView` · `ProfileView` · `CircleNotificationStore` · `oneApp` · `PublicProfileView (mevcut varsa)`

**Yeni dokümanlar:**
`docs/USER_CONTENT_POLICY.md` · `docs/PRIVACY_POLICY.md` (güncelleme)
