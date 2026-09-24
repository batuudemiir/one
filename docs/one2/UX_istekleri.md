# UX istekleri (motor tarafından sağlanacaklar)

UX oturumunun ekranları motor tiplerini değil view data'yı görür
(`one/ONE2/Features/Shared/ViewData/`). Bu dosya, UX-11 bağlamasında
motorun doldurması gerekenleri listeler. Kaynak: `06_giris_akislari.md`.

Durum işaretleri: **Var** (motorda hazır, yalnız eşleme) · **Kısmen** ·
**Yok** (yazılacak) · **Karar gerekli**.

## 1. Akış şablonlarının seed'i

| İstek | View data | Durum |
|---|---|---|
| Dört akışın adım listesi (`FlowKind` → `[FlowStepViewData]`), kalıcı adım ID'leri (`daily.question`, `evening.intention` …) | `FlowViewData.steps` | Yok. Fixture'daki sıra (`FlowFixtures.steps`) seed olarak alınabilir |
| Kişiselleştirme: adım kapatma ve sıralama (Profil › Günlük akışı, UX-10) | `FlowStepViewData.isEnabled`, sıra | Yok. Kullanıcı tercihi `UserProfileStore`'a; skor adımı kapatılamaz |
| Yalnız skor zorunlu; diğer her adım `optional` | `optional` | Kural; seed bunu korumalı |
| Sabahta duygular varsayılan kapalı ek adım | `isEnabled = false` | Seed |
| Akşam: sabah yapılmadıysa `intentionReview` yok; bugün pratik yoksa `practices` yok | adım listesi | Yok. `DayStore.completion(on:)` + `LibraryStore.practices()` |

## 2. Günün sorusu ve dönen havuz

| İstek | View data | Durum |
|---|---|---|
| Günlük check-in yazı adımı: günün sorusu | `daily.question.prompt` | Kısmen: `PromptEngine.dailyPrompt(for:)` (haftalık tema günü) ya da `freePrompt`; hangisinin öncelikli olduğu **karar gerekli** |
| Yazı adımlarının soruları dönen havuzdan (sabit olanlar: score, sleep, focus, intentionReview) | `prompt` | Kısmen: `ritualPrompts(.morning/.evening)` var; mood ve günlük akış havuzları yok. Fixture metinleri (`one2.flow.prompt.*`) varsayılan olarak kalabilir |
| Söz adımı: günün sözü | `FlowQuoteViewData` | Var: `QuoteEngine.dailyQuote(for:)` |

## 3. Önceki cevap

| İstek | View data | Durum |
|---|---|---|
| Aynı soruya önceki cevabın ilk 2 satırı ("Geçen sefer şöyle yazmıştın") | `previousAnswer` | Kısmen: `JournalStore.entries(kind:contentRef:)` + `contentRef` eşleşmesi; ilk iki satırı ekran keser |

## 4. Odak listesi

| İstek | View data | Durum |
|---|---|---|
| Sabit 8 seçenek + "Kendi kelimen" | `focus.options` | Sabit (Localizable `one2.focus.*`) |
| Seçilen odak: sabah kartı özeti, akşam niyet adımının başlığı (`Sabah '{odak}' demiştin`) | `RitualCardState.done.summary`, `evening.intention.title` | Var: `DayStore.setFocus` / `focus(on:)` |

## 5. Taslak saklama

| İstek | View data | Durum |
|---|---|---|
| Her adım bitince akışın taslağı; kapatıp açınca kaldığı adımdan devam | `FlowProgress` (Codable) | Yok. Öneri: cihazda, `flow.<kind>.<dayKey>` anahtarıyla (App Group UserDefaults); CloudKit'e gerek yok |
| Bugün kartının "Devam et · 3/6" durumu taslaktan | `RitualCardState.inProgress` | Yok (taslak saklamaya bağlı) |

## 6. Taşınan maddeler

| İstek | View data | Durum |
|---|---|---|
| Akşam kapanışı: sabahın `list3` maddelerinden işaretlenmeyenler | `FlowClosingViewData.carryOver` | Yok. Maddelerin "yapıldı" işareti için veri yok: **karar gerekli** (akşam adımında işaretleme mi, `todo` cevap türü mü) |
| "Taşı" → ertesi sabah `list3` önceden dolu | `FlowResult.carryOver` | Yok. Öneri: `EntryAnswer(kind: .todo)` ya da cihazda anahtar |

## 7. Bugün ekranı

| İstek | View data | Durum |
|---|---|---|
| Seri sayısı; profil ayarı kapalıysa gizli | `TodayViewData.streak` | Var: `DayStore.streakState(mode:visible:)` |
| Hafta: done / half / gap / today / future + 7 gün doldurma | `WeekDayViewData` | Var: `WeekStripModel` + `WeekStripAdapter` (bağlandı) |
| Ritüel modu (günlük / sabah+akşam) | `RitualLayout` | Var: `UserProfile.ritualMode` |
| Kart durumu: tamam → yankı + MoodPill + özet | `RitualCardState.done` | Kısmen: yankı `EchoEngine`, skor `MoodStore`; akşam özeti (tamamlanan pratik sayısı) için pratik kaydı **yok** |
| Pratiklerin: ad + SF Symbol | `PracticeTileViewData` | Kısmen: `LibraryStore.practices()` yalnız `contentRef` tutuyor; ad ve ikon içerikten (`guided/…`) çözülmeli |
| Haftalık tema: ad, gün, soru, yazıldıysa ilk satır | `WeeklyThemeViewData` | Var: `ThemeCalendar` + `JournalStore.entries(kind: .prompt, contentRef:)` |

## 8. Akış sonucu kaydı

| Adım | Kayıt | Durum |
|---|---|---|
| score + emotions + causes | `MoodStore` (source `checkIn`) | Var |
| text / list3 / quote | `Entry` (`morning` / `evening` / `dailyCheckIn` / `emotionCheckIn`), her adım bir `EntryAnswer` (`stepRef` = adım ya da soru ID'si) | Var (depo); eşleme yazılacak |
| quote cevabı | Ayrıca `quoteReflection` girdisi (`contentRef` = söz ID) + `QuoteEngine.record(.wroteAbout)` | Var (söze yazı sözleşmesi) |
| sleep (skor + saat) | `EntryAnswer(kind: .scale5, number:)`; saat için ikinci cevap ya da `MetricDefinition` | **Karar gerekli**: uyku saati için alan yok |
| focus | `DayStore.setFocus` | Var |
| intentionReview | `EntryAnswer(kind: .singleChoice)` | Var (depo) |
| practices | `EntryAnswer(kind: .multiChoice)` | Var (depo); akşam özeti bunu sayar |
| Akış bitti → gün durumu (günlük: done; sabah: half; akşam: sabah da yapıldıysa done) | `DayStore.markCompleted(.daily/.morning/.evening)` | Var |
| Geriye dönük doldurma (sheet → akış o gün için) | `JournalStore.create(_, on:)`, `markCompleted(_, on:)` | Var (7 gün kuralı `DayCompletionRules`) |
| Yankı cümlesi | `FlowClosingViewData.echo` | Var: `EchoEngine` |

## Bağlama durumu (24 Eylül 2026)

Bugün sekmesi `ONE2TodayView`'ı gerçek veriyle gösteriyor (`TodayScreen` →
`TodayLive`); akışlar `LiveFlows` ile motora yazıyor. Adaptörler:
`one/ONE2/Features/Shared/Adapters/`. Açık kararlar plana göre kapatıldı.

| Konu | Canlıda | Plandaki dayanak |
|---|---|---|
| Adım seed'i | `FlowFixtures.steps` şablonu + canlı içerik (`LiveFlows.seed`) | 06 › Akış 1–4; kişiselleştirme UX-10 |
| Günün sorusu | Haftalık temanın günü; tema yoksa serbest soru | 04 › E7 öneri sırası (tema → serbest) |
| Önceki cevap | Aynı soru metnine günlük check-in'deki son cevap | 06 › Akış 2 |
| Taslak | Cihazda, `one2.flow.draft.<akış>[.<kapsam>].<gün>` | 06 › Akış kabuğu |
| Kayıt | Mood, girdi (adım başına `EntryAnswer`), odak, söze yazı + maruz kalma, ritüel tamamlama | 02 › Entry, EntryAnswer, DayRecord |
| Uyku | Kalite `scale5` cevabı; saat `<adım>.hours` cevabının `number` alanı | 02 › EntryAnswer (`number`); yeni alan açılmadı |
| Yankı | `EchoEngine`, kart için cihazda saklanır | 04 › E6 |
| Taşınan maddeler | Akşam kapanışında sabahın öncelikleri; "Taşı" → ertesi sabahın listesi dolu gelir (`CarryOverStore`), sabah bitince silinir | 06 › Akış 4. Maddeleri gün içinde işaretleme planda yok: sorulan liste sabahın bütün öncelikleri |
| Pratikler | Karoya dokun → rehberli günlük akış kabuğunda (`GuidedFlows`, `guided` girdisi); uzun bas › Kaldır; "+ Ekle" → rehberli günlük listesi, premium kilitli (ONE+) | 06 › Bugün 4; PracticeTile.md; ADR §8. Sıralama (uzun basma) sonra |
| Haftalık tema | "Yaz" → editör (`Route.newEntry`, `prompt` girdisi, `contentRef` tema günü); yazıldıysa "Devam et" aynı girdiyi düzenler | 06 › Bugün 5; 05 › UX-6 JournalEditor |
| Geriye dönük doldurma | Günlük modda günlük check-in, sabah+akşam modunda akşam akışı, o gün için | 06 › Bugün 2; E8 7 gün |
