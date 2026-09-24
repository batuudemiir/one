# UX-11 — View data ↔ motor eşlemesi

Tarih: 24 Eylül 2026 · Motor oturumu hazırladı (05 › UX-11 öncesi).
Kaynak: `one2/ux` › `Features/Shared/ViewData/*` (UX-3/UX-4) ve `one2/faz1` motorları.
Adaptörler `Features/Shared/Adapters/` altında, birim testli (05 › UX-11). Bu tablo her view data alanının hangi motor API'sinden geldiğini ve dönüşüm kuralını söyler. Tüm servisler `AppEnvironment`'ta (`@Environment(\.one2)`).

## Adlar

UX view data ile motor aynı modülde. Çakışmayı önlemek için motor tipleri farklı adlandı:

| UX (ekran sözleşmesi) | Motor |
|---|---|
| `InsightState<V>` (`ready`, `insufficient(required:current:)`, `locked`) | `InsightResult<V>` (`ready`, `insufficient(needed:have:)`); `locked` adaptörde `InsightAccess` / `EntitlementStore` ile |
| `WritingStats` | `WritingSummary` |
| `ChangePair` | `AnswerChangePair` (girdi ID'leri; `HistoryItem`'e adaptör çevirir) |

`needed` eşiğin kendisidir (kalan değil) → `required = needed`, `current = have`.

## Ortak

| View data | Motor | Not |
|---|---|---|
| `EmotionItem(id, name, family)` | `content.catalog.emotions` (`EmotionDefinition.id/label/family`) | ID'ler aynı (`huzur.sakin`); `family` ham değeri `ONE2EmotionFamily(rawValue:)` |
| `RitualSlot` | `RitualCard` / `MoodCheckIn.slot` | `daily/morning/evening` bire bir |
| `Loadable` | — | Adaptör: motor `throws` → `.failed(message:)` |

## Bugün (`TodayData`)

| Alan | Motor | Dönüşüm |
|---|---|---|
| `week: WeekStripData` | `day.completions(from:through:)` + `ISOWeek(containing:)` | `DayCompletion.status(in: profile.ritualMode)`: `.full→.done`, `.half→.half`, `.none→.none`; `WeekStripData.week(containing:today:completions:)` |
| `streak: StreakData` | `day.streakState(mode:visible:)` | `count→current`, `longest`, `isVisible`, `atRisk→isAtRisk` |
| `checkIns[].summary: CheckInSummary` | `mood.logs(on: today)` + `echoes.echo(for: MoodCheckIn)` | `slot` = `MoodCheckIn.slot`; dilim başına son check-in; `echo` saklı (`echoID`), yoksa seçilip saklanır; `emotions` katalogdan; `causes` = `catalog.causes` etiketleri |
| `checkIns` kart kümesi | `profile.profile.ritualMode` | `.daily` → [daily]; `.morningEvening` → [morning, evening] |
| `practices: [PracticeTileData]` | `library.practices()` + `catalog.guided` | `contentRef` `guided:<id>` → başlık; ikon adaptörde. Boşsa varsayılan: sabah/akşam rehberi (ürün kararı, UX) |
| `theme: ThemeCardData` | `ThemeCalendar.theme(for:catalog:firstSeen:salt:)`, `prompts.dailyPrompt(for:)`, `journal.entries(on:)` | `day = today.isoWeekday`, `unlockedDays = day`, `promptID = PromptSuggestion.ref` (`theme:2026-w39:d3`), `isWritten` = bugün o `contentRef`'li girdi var mı, `firstLine` = girdinin ilk satırı |
| Günlük önerisi (+ menü) | `recommendations.dailySuggestion()` | `DailySuggestion` dalları |

Kayıt: check-in `mood.log(... linkedTo:)` → `day.markCompleted(slot)`; kancalar analitiği, rozeti, widget'ı ve bildirimleri kendisi tazeler (`AppEnvironment`).

## Sözler (`QuoteCardData`, `QuoteFeedModeData`)

| Alan | Motor | Dönüşüm |
|---|---|---|
| Akış | `quotes.nextBatch(mode:count:)`; oturum `startSession/endSession` (yaşam döngüsü çağırır) | `QuoteFeedModeData` → `QuoteFeedMode` (`.path(id,…)` → `.path(id)`, `.kind(.thought)` → `.kind(.reflection)`) |
| `kind` | `Quote.kind` | `reflection → thought`, diğerleri aynı |
| `source` | `Quote.author`, `Quote.source` | "Yazar, Eser"; olumlama/düşünce için boş |
| `writtenCount`, `isLiked` | `exposure.snapshot(.quote)[id]` | `writtenCount`, `liked` |
| `background` | — | Adaptör: tür/tema → `emo-*` token ya da foto seti (tasarım kararı) |
| `path(isLocked:)` | `quotes.isAccessible(.path(id))` | `!isAccessible` |
| Görüldü | `quotes.markSeen(id, dwell:)` | ≥ %60 görünür ve ≥ 1,2 sn (ekran ölçer) |
| Beğen/paylaş/yaz | `quotes.record(.liked/.unliked/.shared/.wroteAbout(entryID), for:)` | |
| Günün sözü | `quotes.dailyQuote(for: today)` | |
| Boş durum | `quotes.remainingUnseen(mode:)` = 0 ve `nextBatch` boş | "Tümünü gördün" |
| Söze yazı sorusu | `prompts.reflectionPrompt(for:compare:)` | |
| Geri dönen söz | `quotes.resurfacingCandidate(on:)` | "Bu söze … yazmıştın" |

## Keşfet (`ExploreData`)

| Alan | Motor | Dönüşüm |
|---|---|---|
| Sıralama | `recommendations.exploreRanking()` | `RankedExploreItem.isLocked` → `ContentCardData.isLocked` |
| `featured: FeaturedData` | `ThemeCalendar.theme(for: today, …)` | `start/end` = `ThemeWeek.firstDay/lastDay`; `isLocked` = tema premium ∧ !premium |
| `badge .new` | `catalog.isNew(item)` | |
| `steps`, `minutes` | `GuidedJournal.steps.count`, `durationMinutes` | |
| `tone` | `GuidedJournal.timeOfDay` | `morning→sabah`, `evening→aksam`, diğer → `neutral` |
| Geçmiş temalar | `ThemeCalendar.pastThemes(catalog:today:hasPremium:)` | |

## Yolculuk (`HistoryDay`, `HistoryItem`)

| Alan | Motor | Dönüşüm |
|---|---|---|
| Günler | `journey.days(from:through:)` / `journey.month(containing:)` | `JourneyDay` → `HistoryDay` |
| `.checkIn` | `JourneyItem.checkIn(MoodCheckIn)` | Bugün'deki `CheckInSummary` adaptörü |
| `.journal(title, excerpt, wordCount)` | `JourneyItem.entry` | başlık: `title ?? contentSnapshot ?? "Boş sayfa"` |
| `.quoteReflection` | `.entry` (`kind == .quoteReflection`) | `contentRef` = söz ID → katalog metni |
| `.photo(asset)` | `JourneyItem.photo(JourneyPhoto)` | ikili veri `Media` (tembel yükleme) |
| `.legacy(v3Mood, note, song)` | `JourneyItem.legacy(LegacyMoment)` | `V3Mood.fromHex(moodColorHex)?.rawValue` (tahmin yok); foto `legacy.photo(for:)` |
| Arama | `search.search(_:filter:)` | `EntrySearchResult.snippet/highlights` |
| Geçen yıl/ay bugün | `insights.onThisDay()` | |

## Eğilimler (`InsightsData`)

| Alan | Motor | Dönüşüm |
|---|---|---|
| `period` | `.days14 → .days14`, `.days30 → .days30`, `.months → monthlySeries()`, `.years → yearlySeries()` | Aylar/Yıllar noktası: ayın/yılın ilk günü |
| `checkInCount` | `insights.checkInCount(_:)` | |
| `moodLine` | `insights.moodLine(_:)` | `MoodPoint.average → TrendPoint.score`, `isToday` adaptörde |
| `average` | `insights.averageChange(_:)` | `delta` aynı |
| `distribution` | `insights.emotionDistribution(_:)` `.families` | `Share.id → ONE2EmotionFamily`, `ratio → share` |
| `tagRelations` | `insights.causeRelations(_:)` | `causeID` → katalog etiketi |
| `writing` | `insights.writing()` → `WritingSummary` | |
| `changePairs` | `insights.changePairs()` → `AnswerChangePair` | girdi ID'leri → `HistoryItem` |
| `.locked` | `InsightAccess.moodPeriodAvailable`, `InsightAccess.premiumOnly`, `entitlements.hasPremium` | |

## Profil, Ayarlar, Paywall

| Alan | Motor | Dönüşüm |
|---|---|---|
| `BadgeData` | `badges.overview()` → `BadgeStatus` | `value` = hedef (`"7"`), `earnedAt`, `remaining` |
| Ayarlar | `profile.update { … }` (`ProfileStore`, dokümanda `UserProfileStore`) | ritüel modu, saatler, yollar, seri görünürlüğü, söz geri dönüşü |
| Bildirim türleri | `notifications.enabledKinds` | varsayılan: sabah, akşam, haftalık tema açık |
| `PlanData` | `entitlements.products` → `ProductInfo` | `displayPrice`, `period`, `trialDays` ("7 gün ücretsiz"), yıllık önerilen |
| Satın al / Geri yükle | `entitlements.purchase(_:)`, `entitlements.restore()` | `PurchaseOutcome` |
| Dışa aktarma | `exporter.write(.json / .markdown, hasPremium:)` | Markdown premium |

## Yaşam döngüsü (kabuk)

`oneApp` zaten çağırıyor: `onLaunch` (Tier 2), `onForeground`/`onBackground` (scenePhase), `onDayChange` (gece yarısı). İçerik güncellemesi `ContentRepository.didUpdate` yayınlar; ekran modelleri dinleyip yeniden yükler.
