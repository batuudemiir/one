# ONE v2.5 — Yorum Sistemi & Bildirim Genişlemesi

## Context

v2.5 ile ONE, mood-takip uygulamasından **hafif sosyal ağ**a bir adım daha yaklaşıyor. İki ana değişim:

1. **Emoji reaction → Yorum (Comment)**: 5 sabit emoji (🤍 🌊 ✨ 🫶 🔥) çevreden kalkar; yerine 280 karakterlik **yorum** gelir. Yorum, ONE'ın şimdiye kadarki en "konuşma" yoğun primitifi olacak.
2. **Yorumcu profili → Takip isteği**: Yoruma tıklayan her kullanıcı, yorumu yazan kişinin hafif **public profile**ını görebilir ve oradan takip (arkadaşlık) isteği gönderebilir. Bu, friend request'e yeni bir "keşif" yolu açar — şu ana kadar tek yol davet koduydu.

Bu iki değişim birlikte retention'ı çevre-derinleştirme (engagement per post) + network büyümesi (daha fazla organik friend request) üzerinden artırır. Ama aynı zamanda **UGC (user-generated content)** kapısını açtığı için moderasyon, engelleme, rapor altyapısı zorunlu hale gelir (App Store reddi riski).

Kullanıcı tercihleri: yorum odaklı, takip isteği CTA'lı, kapsamlı plan — Claude "söylemediklerini" de ekleyecek.

---

## 1. Ürün kapsamı

### 1.1 Yorum (Comment)
- Her DailyShare'e arkadaşlar yorum bırakabilir.
- 280 karakter limit (Twitter standardı, mobile'da ekran için optimal).
- Düz metin (emoji ✅, URL ❌ ilk sürümde — phishing riskini azaltır).
- Yorum **silme**: kendi yorumum + paylaşım sahibi başkasının yorumunu silebilir.
- Yorum **düzenleme**: yalnızca kendi yorumum, 5 dakika içinde, "(düzenlendi)" rozetiyle.
- **Thread / reply**: v2.5.0'da **flat liste** (reply yok). v2.5.1 fast-follow'da 1-seviye reply.
- **Rate limit**: 5 yorum/dakika, 30 yorum/saat (client-side throttle + server sanity).

### 1.2 Public profile (yorumcu profili)
- Yorumun yanındaki avatar/ad'a tap → `PublicProfileView`.
- Gösterilen alanlar: displayName, username, avatarColor, streak (varsa), toplam paylaşım gün sayısı, "ONE'a katıldı {ay}" metadatası.
- **AppUser.isPublic=false** kullanıcılar için: isim + avatar + "Bu kullanıcı profilini gizli tuttu" mesajı. Takip isteği yine gönderilebilir (gelen taraf kabul ederse görünür olur).
- **CTA matrisi**:
  - Hiç ilişki yok → "Takip isteği gönder" button
  - Pending outgoing → "İstek gönderildi · İptal et"
  - Pending incoming → "Kabul et" / "Reddet"
  - Arkadaş → "Çevrende" badge + "Çevreden çıkar" menü
  - Engellediysem → "Engeli kaldır"
  - O beni engellediyse → profil görünmez, `PublicProfileView` bile açılmaz (sessiz bloklama)
- **Report** ve **Block** butonları profile altında (critical for App Store).

### 1.3 Yorum tabanlı friend request akışı
- Şu ana kadar tek yol: 6 haneli invite code.
- v2.5 ile: bir arkadaşının paylaşımına gelen yorumda başkasının profilini görüp istek gönderebilirsin → **sosyal kanıt + keşif**.
- Bu akış "ortak arkadaş" networkü kurar; Friendship record'a yeni `source: String` alanı eklenir (`invite_code`, `comment_profile`, `mood_resonance`, `search`).

---

## 2. Veri modeli (CloudKit)

### 2.1 Yeni record type — `Comment`
| Alan | Tip | Queryable | Açıklama |
|---|---|---|---|
| `shareRecordName` | String | ✅ | DailyShare.recordName — yorumun bağlı olduğu post |
| `shareOwnerID` | String | ✅ | Post sahibinin userID'si — bildirim filtresi için |
| `authorUserID` | String | ✅ | Yorumcu |
| `body` | String | — | ≤280 char |
| `createdAt` | Date | ✅ (sort) | |
| `editedAt` | Date? | — | Edit göstergesi |
| `parentCommentID` | String? | ✅ | v2.5.1 reply için placeholder |
| `moderationStatus` | String | ✅ | "active" / "hidden" / "removed" |
| `reportCount` | Int64 | — | 3+ → otomatik `hidden` |

**İndeksler**: `shareRecordName` + `createdAt` desc (thread fetch), `authorUserID` + `createdAt` desc (kullanıcının yorumları), `shareOwnerID` + `createdAt` desc (bildirim subscription).

### 2.2 Yeni record type — `Block`
| Alan | Tip | Açıklama |
|---|---|---|
| `blockerUserID` | String | Engelleyen |
| `blockedUserID` | String | Engellenen |
| `createdAt` | Date | |

Queryable: `blockerUserID`, `blockedUserID`. Unique constraint: (blocker, blocked) çifti.

### 2.3 Yeni record type — `Report`
| Alan | Tip | Açıklama |
|---|---|---|
| `targetType` | String | "Comment" / "DailyShare" / "User" |
| `targetRecordName` | String | Hedef ID |
| `reporterUserID` | String | |
| `reason` | String | enum: spam / harassment / hate / selfHarm / other |
| `note` | String? | ≤500 char |
| `createdAt` | Date | |

Rapor Apple moderasyon gerekliliği için zorunlu. 3+ rapor gelen Comment `moderationStatus = hidden` olur (client-side hesaplanmaz; privateDatabase üzerinden trusted bir CloudFunction yok → şimdilik threshold client-side sanity check + manual review queue).

### 2.4 Friendship record'a ekleme
- `source: String` — nereden geldi. Default "invite_code".

### 2.5 AppUser record'a ekleme (opsiyonel, v2.5.1)
- `commentNotificationsEnabled: Int64` (0/1, default 1) — gelecekte user-level opt-out

### 2.6 EmojiReaction migration
- Record type **silinmez** (v2.4 client'ları kırılmasın, read-only görünebilir).
- v2.5'te **create/update kapatılır**, yalnızca historical read.
- Subscription `emoji-reaction-notification-v4` → `legacySubIDs` listesine eklenir → subVersion v7 bump → otomatik temizlenir.
- v2.6'da fiziksel toplu silme job'u (manuel script).

---

## 3. Mimari — dosya düzeni

**Yeni dosyalar**:

| Path | Sorumluluk |
|---|---|
| `one/one/Core/Managers/CloudKitCommentService.swift` | Comment CRUD + subscriptions |
| `one/one/Core/Managers/CloudKitBlockService.swift` | Block / unblock / listesi |
| `one/one/Core/Managers/CloudKitReportService.swift` | Report create + threshold |
| `one/one/Core/Managers/CommentRateLimiter.swift` | 5/dk, 30/saat client throttle |
| `one/one/Core/Models/Comment.swift` | Model + CKRecord mapping |
| `one/one/Core/Models/PublicUserProfile.swift` | Hafif profil modeli |
| `one/one/Features/Comments/CommentThreadView.swift` | Yorum listesi + input |
| `one/one/Features/Comments/CommentRowView.swift` | Tek yorum satırı, author tap → profile |
| `one/one/Features/Comments/CommentComposerView.swift` | Alt input (280 counter, rate-limit UI) |
| `one/one/Features/Profile/PublicProfileView.swift` | Başkasının profili + CTA matrisi |
| `one/one/Features/Profile/ReportSheet.swift` | Şikayet formu |
| `one/one/Core/Notifications/CommentNotificationBundler.swift` | Çoklu yorum coalescing |

**Düzenlenecek dosyalar**:

- [CloudKitNotificationService.swift](one/one/Core/Managers/CloudKitNotificationService.swift) — EmojiReaction sub'ı legacy'ye al, Comment subscription ekle (`comment-notification-v1`), push handler yaz.
- [oneApp.swift](one/one/oneApp.swift) `setupNotificationCategories()` — `COMMENT_NOTIFICATION` kategori + "Yanıtla" (text input action) + "Açıp oku" action.
- [NotificationPolicy.swift](one/one/Core/Notifications/NotificationPolicy.swift) — Yeni kind'lar.
- [NotificationMessageBuilder.swift](one/one/Core/Notifications/NotificationMessageBuilder.swift) — Yorum mesaj varyantları.
- [NotificationOrchestrator.swift](one/one/Core/Notifications/NotificationOrchestrator.swift) — Dedup muafiyeti `commentReceived` için (farklı yorumcu farklı bildirim).
- [FriendShareDetailView.swift](one/one/Features/Circle/FriendShareDetailView.swift) — `emojiSection` yerine `CommentThreadView`.
- [FriendDetailView.swift](one/one/Features/Circle/FriendDetailView.swift) — `emojiRow` çıkar.
- [CloudKitDailyShareService.swift](one/one/Core/Managers/CloudKitDailyShareService.swift) — `sendEmojiReaction`, `fetchEmojiReaction`, `fetchReceivedEmojiReactions` → `@available(*, deprecated)` işaretle, internal çağrıları kaldır.
- [CloudKitFriendshipService.swift](one/one/Core/Managers/CloudKitFriendshipService.swift) — `sendFriendRequest(toUserID:source:)` yeni parametre.
- [AddFriendView.swift](one/one/Features/Circle/AddFriendView.swift) — `source: .inviteCode` geçişi.
- [ProfileView.swift](one/one/Features/Profile/ProfileView.swift) — `Engelli kullanıcılar` satırı (settings altında).
- [CircleNotificationStore.swift](one/one/Core/Managers/CircleNotificationStore.swift) — `commentReceived` type'ı CircleNotification.Kind'a ekle.
- [AppDelegate notification categories] — COMMENT_NOTIFICATION + "REPLY" UNTextInputNotificationAction (push'tan yorum yanıtlama — deep engagement).

---

## 4. Bildirim kinds & mesajlar

### 4.1 Yeni NotificationKind'lar

```swift
case commentReceived    // paylaşımıma yorum geldi
case commentReply       // yorumuma cevap (v2.5.1)
case commentMention     // @me yorumlandı (v2.5.1)
case commentBatch       // çoklu yorum bundle
case followRequestFromComment  // yorum üzerinden friend request — `.friendRequest` kind reuse + source field
```

### 4.2 Mesaj varyantları (MessageBuilder)

| kind | örnek title | örnek body |
|---|---|---|
| `commentReceived` | "**Ada** yorum yaptı 💬" | "\"Bu şarkı bugün tam kıvamında...\"" (yorumun ilk 80 char'ı) |
| `commentBatch` | "**Ada, Mert** ve 2 kişi daha yorum yaptı 💬" | "Bugünkü paylaşımın konuşuluyor." |
| `commentReply` | "**Mert** yorumuna cevap verdi" | "\"Katılıyorum, özellikle köprü kısmı...\"" |

**Kişiselleştirme kuralları** (plan v1'den taşınan):
- Ad **title**'ın ilk kelimesinde veya `**bold**` gibi vurgulu yerde.
- Birden fazla yorumcu → bundler "A, B ve N kişi daha" (`CommentNotificationBundler`, 5 dakika pencere).
- Body = yorumun literal metni (80 char'dan sonra "…"). Kendi yorumunun body'ye sığması, görsel olarak inline preview.
- `userInfo["commentID"]`, `userInfo["shareRecordName"]`, `userInfo["authorUserID"]` deep-link için.
- Rich attachment: post'un mood rengi (mevcut `RichAttachmentFactory`).

### 4.3 Notification actions (AppDelegate)
```
COMMENT_NOTIFICATION:
  - REPLY_ACTION (UNTextInputNotificationAction, foreground=false, direct post)
  - OPEN_COMMENTS (foreground)
```
"Yanıtla" push'tan direkt comment create → en güçlü re-engagement kolu (WhatsApp/Instagram pattern).

### 4.4 Politika kararları
- `commentReceived` priority `.high` (arkadaş reactive event gibi). Dedup **kapalı** (birden fazla yorum ayrı bildirim gibi görünebilir ama bundler 5dk içinde birleştirir).
- Quiet hours **erteler**, critical değil.
- Daily cap'e sayılmaz (reactive social).
- Weekly proactive cap'i tetiklemez (reactive).

---

## 5. Subscription & push handler

### 5.1 Comment subscription (CloudKitNotificationService)
```swift
subID = "comment-notification-v1"
predicate = shareOwnerID == currentUserID AND moderationStatus == "active"
options = [.firesOnRecordCreation]
info.desiredKeys = ["shareRecordName", "authorUserID", "body"]
info.alertBody = "Paylaşımına yeni yorum geldi 💬"  // generic fallback
info.collapseIDKey = "shareRecordName"  // aynı post'a gelen yorumlar APNs seviyesinde birleşir
```

### 5.2 Handler
```swift
handleCommentPush(notification:) {
  // 1. sender block list kontrolü — blocked ise sessizce düş
  // 2. displayName + mood fetch (paralel)
  // 3. CommentNotificationBundler.enqueue(shareRecordName, authorName, body)
  // 4. bundler debounce (5 sn) sonra:
  //    - 1 yorum → commentReceived
  //    - 2+ yorum → commentBatch
  // 5. Orchestrator.schedule(...)
  // 6. CircleNotificationStore.add(...) + refresh notification
}
```

### 5.3 Bundler
- In-memory dictionary `[shareRecordName: [PendingComment]]`
- 5 sn debounce timer per share
- Timer ateşlediğinde tek bildirim üretir, pending'leri flush eder
- Uygulama background'a giderken `flushAll()` çağrılır

---

## 6. UI değişiklikleri (kritik ekranlar)

### 6.1 FriendShareDetailView / FriendDetailView
- `emojiSection` / `emojiRow` kaldırılır.
- Yerine: `CommentThreadView(shareRecordName:)` embed edilir.
- Card altında "**\(n) yorum**" sayaç → tap → full thread.

### 6.2 CommentThreadView
```
[Paylaşım özeti — mini card]
────
[CommentRow] Ada · 2 dk önce                [⋯]
  "Bu şarkı bugün tam kıvamında"
  [yanıtla · beğen (v2.5.1)]
────
[CommentRow] Mert · 4 dk önce
  ...
────
[CommentComposerView — bottom sheet]
```
- Pull-to-refresh + CloudKit push subscription ile canlı.
- 50 yorum sonrası "Daha fazla göster" (pagination).
- Empty state: "İlk yorumu sen yap 💬".

### 6.3 CommentRowView
- Avatar (renk circle) + displayName + "· \(rel time)" + `⋯` menu.
- Author avatar/ad tap → `PublicProfileView(userID:)`.
- Uzun basma → preview sheet (profil kartı mini).
- Menü: Kendi yorumumsa "Düzenle" + "Sil"; başkasının yorumuysa "Şikayet et" + "Engelle".
- Paylaşım sahibi ek olarak başkasının yorumunu silebilir ("Sil" gösterilir).

### 6.4 CommentComposerView
- Text editor + 280 counter + Gönder button.
- Rate-limit aşılmışsa "\(n) sn sonra tekrar dene" disabled state.
- Offline handling: posted to CloudKit, failure'da "tekrar dene" banner.

### 6.5 PublicProfileView
- Avatar (hex renk), displayName, @username.
- Streak + toplam gün metrikleri (isPublic=true ise).
- "ONE'a katıldı" tarihi.
- CTA button (matris §1.2).
- `⋯` menu: "Şikayet et", "Engelle".
- Arkadaşsa son 7 günün mini mood grid'i (görsel derinlik).

---

## 7. Moderasyon & güvenlik (App Store için zorunlu)

### 7.1 Apple gerekliliği
Apple Guideline **1.2** (UGC): şu özellikler olmadan reject edilir —
1. **User-flagged objectionable content filtreleme** → Report sistemi ✅
2. **Block user** → Block sistemi ✅
3. **Publish EULA** → "No tolerance for objectionable content" — PrivacyPolicy + Terms güncellemesi
4. **Act on reports within 24h** → admin backoffice gerekir (out of scope; manual via CloudKit dashboard başlangıçta)

### 7.2 Client-side tedbirler
- **Profanity filter**: basit Türkçe/İngilizce blacklist (~200 kelime), match olunca post engellenir + toast.
- **Spam detection**: aynı body'i 2+ kez gönderirse throttle.
- **Auto-hide threshold**: `reportCount >= 3` → `moderationStatus = "hidden"`, thread'de "Bu yorum şikayet edildiği için gizlendi" placeholder.
- **Self-report edilemez**: kendi yorumunu şikayet etme UI'da yok.

### 7.3 Privacy policy + EULA güncelleme
- `docs/PRIVACY_POLICY.md` → yorum verisi nasıl saklanıyor, ne kadar tutuluyor.
- Yeni: `docs/USER_CONTENT_POLICY.md` — topluluk kuralları (zero tolerance, 24 saat response SLA, Apple'ın dil kullanımıyla).

---

## 8. Bildirim analytics ek event'leri

- `comment_notification_received` (kind: single/batch, size)
- `comment_notification_opened` (reply action vs tap)
- `comment_push_reply_submitted` (direct reply başarılı)
- `profile_viewed_from_comment` (source=comment, targetUserID)
- `follow_request_sent_from_profile` (source=comment_profile)
- `comment_posted` (length bucket, has_emoji)
- `comment_reported` (reason)
- `comment_deleted` (by_author vs by_share_owner)

Retention impact ölçüm:
- DAU'da yorum gören ve yorum alan kullanıcıların D7 retention'ı kontrole göre.
- Comment → friend request conversion (profile view → request gönderim oranı).

---

## 9. Migrasyon & rollout

### 9.1 Feature flag
- `feature.comments.enabled` — AppStorage + CloudKit remote override (basit KV record type).
- İlk %10 user'a açık gradual rollout (invite code'un son karakterine göre bucket) — hata durumunda feature flag ile kapatılabilir.

### 9.2 Legacy emoji görünümü
- v2.5.0: emoji oluşturma kapalı. Eski emojiler `FriendShareDetailView`'de küçük "arşiv" rozetiyle görünür kalır (v2.4 kullanıcılarıyla continuity için).
- v2.5.1: emoji görünümü tamamen kaldırılır.
- v2.6: CloudKit EmojiReaction record'ları fiziksel silinir (migration script).

### 9.3 In-app banner
- İlk açılışta tek seferlik: "Artık çevrende yorum yapabilirsin 💬 — emojiler tarih oldu." (dismissible) → `commentsIntroBannerDismissed: Bool`.

### 9.4 CloudKit schema deploy sırası
1. Schema'ya `Comment`, `Block`, `Report` record type'ları ekle (Development).
2. İndeksleri oluştur.
3. Production'a push.
4. v2.5 client'ın minimum OS versiyonu ile aynı deploy slot'ta yayınla.

### 9.5 Subscription version bump
- `CloudKitNotificationService.currentSubVersion` 6 → 7.
- Legacy list'e `emoji-reaction-notification-v4` eklenir.
- `comment-notification-v1` yeni sub.

---

## 10. Edge case'ler (söylenmeyenler)

1. **Post sahibi kendi post'una yorum yazarsa bildirim gönderilmez** (kendine bildirim spam'i).
2. **Engellenen kullanıcının yorumu görünmez** (two-way: hem blocker hem blocked için) — client-side filter + server query `NOT IN blocklist` değil, sadece client filter yeterli (CKQuery AND NOT support zayıf).
3. **Yorum yaparken offline** → local queue, online'da sırayla gönder (`NSUbiquitousKeyValueStore` veya FileManager).
4. **Paylaşım silinirse yorumlar ne olur?** → Cascade silme (`shareRecordName`'e dayalı background cleanup). v2.5.0'da manuel, v2.5.1'de otomatik.
5. **@mention autocomplete** (v2.5.1): `@` yazınca friend listesinden suggestion. Mention edilene ekstra bildirim.
6. **Push reply başarısız olursa?** → "Yanıt gönderilemedi, uygulamayı aç" local notification. UserDefaults'ta pending mesaj olarak sakla.
7. **Rate-limit override for paylaşım sahibi** — kendi post'una sınırsız cevap yazabilir (tartışma moderasyonu için).
8. **Edit window sonrası edit girişimi** → UI'da "Edit" kaybolur.
9. **Çok uzun yorum zinciri** → virtualized list (LazyVStack ile SwiftUI'da hazır).
10. **Profil gizli ama yorumu görünür** → yorum gösterilir ama avatar'a tap → "Profil gizli" toast. Friend request yine gönderilebilir.
11. **ICloud account change** → pending yorum draft'ı silinir, kullanıcıya toast.
12. **Notification banner'da Türkçe uzun yorum truncation** → ilk 80 char + "…" (body limit iOS'ta dinamik ama güvenli kesim).
13. **Karakter limiti aşım**: inline hata, Gönder disabled.
14. **Yasaklı kelime listesi false-positive**: "öldüm gülmekten" → dil bağlamı olmadığı için basic blacklist'i çok katı tutmayalım; sadece ciddi hate speech + profanity.
15. **Comment count caching**: post card'ında görünen "n yorum" sayacı → UserDefaults cache, refresh midnight.
16. **Push 'REPLY' action karakter limiti**: iOS UNTextInputNotificationAction body 280 char'ı destekler, sorun yok.
17. **Screenshot endişesi**: yorum public alanda sayılır, "bu gizli" hissi verilmesin — UI'da clarity.

---

## 11. Aşamalama

### v2.5.0 (ilk sürüm)
- Comment CRUD + subscription + push
- Flat thread (no replies)
- PublicProfileView + friend request CTA
- Block + Report
- Notification Orchestrator'a yeni kind'lar
- EmojiReaction kapatma (görünmez + create kapalı)
- CommentNotificationBundler
- Push reply action
- Feature flag

### v2.5.1 (fast-follow, 2-3 hafta sonra)
- Reply thread (1-seviye)
- @mention autocomplete
- Comment like (lightweight heart per comment)
- Edit history göster ("eskisini gör")
- Emoji görünüm tamamen kaldır

### v2.6
- Moderasyon dashboard (admin web / CloudKit dashboard flow formalize)
- Push notification preferences granular (comment toggle ProfileView'de)
- Comment search (kendi yorumlarım içinde)
- EmojiReaction fiziksel silme

---

## 12. Kritik dosyalar özeti

**Yeni**: CloudKitCommentService · CloudKitBlockService · CloudKitReportService · CommentRateLimiter · Comment · PublicUserProfile · CommentThreadView · CommentRowView · CommentComposerView · PublicProfileView · ReportSheet · CommentNotificationBundler

**Düzenlenecek**: CloudKitNotificationService · CloudKitDailyShareService · CloudKitFriendshipService · NotificationPolicy · NotificationMessageBuilder · NotificationOrchestrator · FriendShareDetailView · FriendDetailView · AddFriendView · ProfileView · CircleNotificationStore · oneApp (AppDelegate setupNotificationCategories) · PRIVACY_POLICY.md · yeni USER_CONTENT_POLICY.md

---

## 13. Doğrulama

1. **Simulator multi-user**: 2 simulator + 2 iCloud hesap → kullanıcı A paylaşım yapar, B yorum yazar → A'ya bildirim, A push'tan reply → B'ye reply bildirimi.
2. **Bundler test**: 3 kullanıcı 4 saniye içinde yorum → tek "3 kişi yorum yaptı" bildirimi.
3. **Block**: A B'yi engelle → A thread'de B'nin yorumunu göremez, B yorum yaparsa A'ya bildirim gitmez.
4. **Report flood**: 3 farklı kullanıcı bir yorumu rapor → status "hidden" → thread'de gizlendi placeholder.
5. **PublicProfileView CTA matrisi**: 5 durumu tek tek test (hiç ilişki / pending out / pending in / friend / blocked).
6. **Rate limiter**: 6 yorum arka arkaya gönder → 6.sı disabled + cooldown timer.
7. **Quiet hours**: gece 02:00 yorum geldi → 08:00'a ertelendi (Orchestrator log).
8. **Offline comment**: airplane mode'da yaz → online'da otomatik post.
9. **Push reply**: lock screen'den "Yanıtla" → comment eklendi, karşı tarafa bildirim gitti.
10. **Schema migration**: v2.4 build'i hala çalışıyor mu (emoji section gri değilse tolere edilir).
