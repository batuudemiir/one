//
// NotificationMessageBuilder.swift
// one
//
// title/body üretimi. TimeOfDay + NotificationKind + son mood +
// A/B bucket girdilerine göre deterministik seçim yapar (aynı seed → aynı
// mesaj). Varyantlar arası eşit dağılım için `seed % count` kullanılır.
//

import Foundation

struct NotificationMessage {
 let title: String
 let body: String
 let variant: Int
}

struct MessageContext {
 let kind: NotificationKind
 let now: Date
 let timeOfDay: TimeOfDay
 let lastMoodLabel: String?
 let recentMoodLabels: [String] // B6 — son 3 mood (en yenisi başta)
 let friendName: String?
 let friendCount: Int
 let emoji: String?
 let commentExcerpt: String? // v2.5 — yorum önizleme (≤80 karakter, trimmed)
 let commentCount: Int // v2.5 — batch'te kaç yorum
 let abBucket: Int

 /// B6 — Hafta sonu (Cumartesi/Pazar) mı?
 var isWeekend: Bool {
 let wd = Calendar.current.component(.weekday, from: now)
 return wd == 1 || wd == 7 // 1=Pazar, 7=Cumartesi
 }

 /// B6 — Son 3 entry'de "ağır" mood dizisi var mı? (seri sayacıyla
    /// ilgisi yok — mood tonuna bakıyor.) Birikmiş yoğunluğu
 /// yumuşak bir tonda kabul eden push tetikler.
 var isHeavyMoodRun: Bool {
 let heavySet: Set<String> = [
"yorgun", "kırgın", "üzgün", "kaygılı", "stresli", "öfkeli", "boş", "bunalmış",
"tired", "anxious", "sad", "stressed", "angry", "empty", "overwhelmed"
 ]
 let normalized = recentMoodLabels.map { $0.lowercased() }
 let heavy = normalized.filter { heavySet.contains($0) }.count
 return recentMoodLabels.count >= 3 && heavy >= 3
 }

 init(
 kind: NotificationKind,
 now: Date = Date(),
 lastMoodLabel: String? = EngagementTracker.lastMoodLabel,
 recentMoodLabels: [String]? = nil,
 friendName: String? = nil,
 friendCount: Int = 1,
 emoji: String? = nil,
 commentExcerpt: String? = nil,
 commentCount: Int = 1,
 abBucket: Int = 0
 ) {
 self.kind = kind
 self.now = now
 self.timeOfDay = TimeOfDay.from(now)
 self.lastMoodLabel = lastMoodLabel
 self.recentMoodLabels = recentMoodLabels ?? EngagementTracker.recentMoodLabels(limit: 3)
 self.friendName = friendName
 self.friendCount = friendCount
 self.emoji = emoji
 self.commentExcerpt = commentExcerpt
 self.commentCount = max(1, commentCount)
 self.abBucket = abBucket
 }
}

enum NotificationMessageBuilder {

 // MARK: - Public

 static func build(_ ctx: MessageContext, seed: Int) -> NotificationMessage {
 let variants = variants(for: ctx)
 guard !variants.isEmpty else {
 return NotificationMessage(title: "ONE", body: "Seni bekliyoruz.", variant: 0)
 }
 let idx = abs(seed &+ ctx.abBucket) % variants.count
 let v = variants[idx]
 return NotificationMessage(title: v.title, body: v.body, variant: idx)
 }

 /// Convenience: date-based seed for daily reminders so ardışık günler
 /// farklı mesaj alsın.
 static func dailySeed(for date: Date = Date()) -> Int {
 let comps = Calendar.current.dateComponents([.year, .month, .day], from: date)
 return (comps.year ?? 0) * 10_000 + (comps.month ?? 0) * 100 + (comps.day ?? 0)
 }

 // MARK: - Variants

 private static func variants(for ctx: MessageContext) -> [(title: String, body: String)] {
 switch ctx.kind {
 case .dailyReminder: return dailyReminderVariants(ctx)
 case .weeklySummary: return weeklySummaryVariants(ctx)
 case .monthEndSummary: return monthlyPortraitVariants(ctx)
 case .circleActivity: return circleActivityVariants(ctx)
 case .winBack3: return winBackVariants(days: 3, ctx: ctx)
 case .winBack7: return winBackVariants(days: 7, ctx: ctx)
 case .winBack14: return winBackVariants(days: 14, ctx: ctx)
 case .winBack30: return winBackVariants(days: 30, ctx: ctx)
 case .nurtureDay1: return nurtureDay1Variants(ctx)
 case .circleInviteWave: return circleInviteWaveVariants(ctx)
 case .nurtureDay2: return nurtureDay2Variants(ctx)
 case .nurtureDay3: return nurtureDay3Variants(ctx)
 case .moodResonance: return moodResonanceVariants(ctx)
 case .friendShared: return friendSharedVariants(ctx)
 case .friendReaction: return friendReactionVariants(ctx)
 case .friendRequest: return friendRequestVariants(ctx)
 case .friendAccepted: return friendAcceptedVariants(ctx)
 case .commentReceived: return commentReceivedVariants(ctx)
 case .commentReply: return commentReplyVariants(ctx)
 case .commentMention: return commentMentionVariants(ctx)
 case .commentBatch: return commentBatchVariants(ctx)
 }
 }

 // MARK: - Comment excerpt helper

 /// Yorum metnini push body için güvenli kısaltır: newline → boşluk, 80 karakter cap, "…".
 private static func excerpt(_ raw: String?, limit: Int = 80) -> String? {
 guard let raw else { return nil }
 let cleaned = raw
 .trimmingCharacters(in: .whitespacesAndNewlines)
 .replacingOccurrences(of: "\n", with: "")
 guard !cleaned.isEmpty else { return nil }
 if cleaned.count <= limit { return cleaned }
 let idx = cleaned.index(cleaned.startIndex, offsetBy: limit)
 return String(cleaned[..<idx]) + "…"
 }

 // MARK: - Comment variants (v2.5)

 private static func commentReceivedVariants(_ ctx: MessageContext) -> [(String, String)] {
 let name = ctx.friendName ?? "Biri"
 let body = excerpt(ctx.commentExcerpt).map {"\"\($0)\"" } ?? "Paylaşımına yorum bıraktı."
 return [("\(name) paylaşımına yorum bıraktı", body)]
 }

 private static func commentReplyVariants(_ ctx: MessageContext) -> [(String, String)] {
 let name = ctx.friendName ?? "Biri"
 let body = excerpt(ctx.commentExcerpt).map {"\"\($0)\"" } ?? "Yorumuna yanıt verdi."
 return [("\(name) yorumuna yanıt verdi", body)]
 }

 private static func commentMentionVariants(_ ctx: MessageContext) -> [(String, String)] {
 let name = ctx.friendName ?? "Biri"
 let body = excerpt(ctx.commentExcerpt).map {"\"\($0)\"" } ?? "Seni bir yorumda andı."
 return [("\(name) seni bir yorumda andı", body)]
 }

 private static func commentBatchVariants(_ ctx: MessageContext) -> [(String, String)] {
 let count = ctx.commentCount
 let name = ctx.friendName
 if let name, count == 2 {
 return [("\(name) ve 1 kişi daha yorum bıraktı", "Paylaşımında konuşma başladı.")]
 } else if let name, count > 2 {
 return [("\(name) ve \(count - 1) kişi daha yorum bıraktı", "Paylaşımın hareketlendi.")]
 } else {
 return [("\(count) yeni yorum", "Paylaşımında konuşma başladı.")]
 }
 }

 // MARK: - D1 — Monthly portrait (30-gün özet push)

 private static func monthlyPortraitVariants(_ ctx: MessageContext) -> [(String, String)] {
 let cal = Calendar.current
 // ctx.now ay 1'i temsil ediyor — geçen ay için kart üret.
 let prevMonth = cal.date(byAdding: .month, value: -1, to: ctx.now) ?? ctx.now
 let formatter = DateFormatter()
 formatter.dateFormat = "LLLL"
 formatter.locale = LanguageManager.shared.currentLocale
 let monthName = formatter.string(from: prevMonth).capitalized
 return [
 ("İşte senin \(monthName) ayın", "30 gün, 30 mood — aylık portrenin hazır."),
 ("\(monthName) yansıması", "Bu ayın renk paletini paylaşmaya ne dersin? "),
 ("Aylık posterin hazır", "\(monthName) ayını tek bir kartta gör.")
 ]
 }

 // MARK: - C2 — Sunday Reflection (weekly summary push)

 private static func weeklySummaryVariants(_ ctx: MessageContext) -> [(String, String)] {
 let mood = ctx.lastMoodLabel
 let hasFriends = ctx.friendName != nil || ctx.friendCount > 1
 var variants: [(String, String)] = [
 ("Haftanın renk paleti hazır", "Pazar yansımana göz at — 7 günün sesi.")
 ]
 if let m = mood {
 variants.append(("Bu haftanın baskın tonu: \(m) ", "Pazar yansımana göz at."))
 }
 if hasFriends {
 variants.append(("Çevren ne hissetti bu hafta? ", "Pazar yansımanı paylaşmak ister misin? "))
 } else {
 variants.append(("Pazar yansıması", "7 günü tek bir kartta gör — paylaşmak ister misin? "))
 }
 variants.append(("Bu haftanın sesi hazır — bir bak.", "7 günlük moodun seni bekliyor."))
 variants.append(("Bu haftan hazır", "Haftanın renk paletini keşfet."))
 return variants
 }

 // MARK: - Circle invite wave (B4) — D4 push, no friends added yet

 private static func circleInviteWaveVariants(_ ctx: MessageContext) -> [(String, String)] {
 return [
 ("ONE çevrenle daha iyi", "Bir yakını da bugün hangi rengi seçtiğini bıraksın."),
 ("Tek başına güzel, çevrenle güzel", "Bir yakını davet et — birlikte bir hafta deneyin.")
 ]
 }

 // MARK: - Nurture Day 3 — ilk haftan başladı (B3)

 /// Day-3 push'u yeni kullanıcıyı üçüncü gün geri çağırır.
    private static func nurtureDay3Variants(_ ctx: MessageContext) -> [(String, String)] {
        // Davet sayıya değil eyleme bakıyor.
        [
            ("Alışkanlık 3. günde kök salar", "Bugün de bir renk bırak."),
            ("İlk haftan seni bekliyor", "Tek bir an yeter.")
        ]
    }

 // MARK: - Nurture Day 2 — widget kurulumu (B5)

 /// Day-2 nurture push'u kullanıcıyı ana ekrana ONE widget'ı eklemeye
 /// yönlendirir. Widget kurmuş kullanıcı kapısız retention sağlar
 /// (D7'de %30+ daha yüksek dönüş hipotezi).
 private static func nurtureDay2Variants(_ ctx: MessageContext) -> [(String, String)] {
 return [
 ("Tek dokunuş kalsın", "Ana ekranına ONE widget'ı ekle, mood'unu uygulamayı açmadan bırak."),
 ("Widget'ı dene", "Bugün uygulamayı açmadan bir renk bırakmak ister misin? ")
 ]
 }

 // MARK: - Nurture Day 1 — onboarding sonrası akşam, ilk mood seçimine referans

 private static func nurtureDay1Variants(_ ctx: MessageContext) -> [(String, String)] {
 // Onboarding sırasında seçilen ilk mood'u referans al (varsa)
 // `OnboardingRecord.firstMoodHex` okunuyor.
 //
 // Eskiden burada `UserDefaults.string(forKey: "onboardingFirstMood")` vardı
 // ama o anahtarı **hiçbir yer yazmıyordu** — v3 onboarding'i seçimi
 // `v3.onboarding.firstMoodHex` altına kaydediyor. Yani bu dal hiç
 // çalışmıyor, Day-1 bildirimi her zaman jenerik metne düşüyordu.
 if let hex = OnboardingRecord.firstMoodHex,
 let firstMood = V3Mood.closest(toHex: hex) {
 return [
 ("Bugünün rengi neydi? ", "Dün '\(firstMood.label)' dedin. Bugünkü hissini de bırak."),
 ("Dünkü '\(firstMood.label)' bugün nasıl? ", "Tek bir renk, tek bir his. ONE seni bekliyor."),
 ]
 }
 return [
 ("Bugünün rengi neydi? ", "Akşam ritüelin ONE'da seni bekliyor."),
 ("İlk günün nasıl geçti? ", "Bugünkü şarkını da bırak, alışkanlık burada başlar."),
 ]
 }

 // MARK: - Daily reminder (TimeOfDay-aware)

 private static func dailyReminderVariants(_ ctx: MessageContext) -> [(String, String)] {
 let mood = ctx.lastMoodLabel

 // B6 — Ağır mood serisi: yumuşak, dayatmasız, soft aesthetic ton
 if ctx.isHeavyMoodRun {
 return [
 ("Birkaç gündür yoğunsun", "Küçük bir nefes ve tek bir kelime — kendine zaman tanı."),
 ("Yavaş bir gün için", "Bugünkü hissini ONE'a bırak, üzerinde durma.")
 ]
 }

 // B6 — Hafta sonu özel dili
 if ctx.isWeekend {
 let day = Calendar.current.component(.weekday, from: ctx.now)
 let dayLabel = (day == 7) ? "Cumartesi" : "Pazar"
 switch ctx.timeOfDay {
 case .morning:
 return [
 ("\(dayLabel) sabahı", "Yavaş başla — bugünkü vibe ne? "),
 ("Hafta sonu vibe'ı", mood.map {"Dün \($0) — bugün hangi tona geçiyorsun? " } ?? "Bugün hangi renktesin? ")
 ]
 case .noon, .evening:
 return [
 ("\(dayLabel) keyfi", "Bugünkü mood'unu bırak, kendine zaman ayır."),
 ("Hafta sonunun rengi? ", "Tek bir kelime yeter.")
 ]
 case .night:
 return [
 ("\(dayLabel) kapanmadan", "Bugünkü hissini bırakmak hâlâ erken."),
 ]
 }
 }

 switch ctx.timeOfDay {
 case .morning:
 return [
 ("Günaydın", "Bugüne bir şarkıyla başla."),
 ("Sabah ritmi hazır mı? ", "Bugünkü mood'unu seç."),
 ("Güne bir renk ver", mood.map {"Dün \($0) hissettin — bugün nasılsın? " } ?? "Bugün hangi renktesin? ")
 ]
 case .noon:
 return [
 ("Günün ortası", "Şarkını seç, nefes al."),
 ("Öğle molası", "Bugünkü mood'unu kaydet."),
 ("Bir şarkı, bir an ⏸", mood.map {"Sabah \($0) hissettin. Şu an? " } ?? "Kendine 10 saniye ayır.")
 ]
 case .evening:
 return [
 ("Günü bir şarkıyla kapat", "Bugünkü mood'unu bırak."),
 ("Akşamın ruhu ne? ", mood.map {"Dün \($0) — bugün? " } ?? "Seçimini yap, geride bırakma."),
 ("Bugünü mühürle", "Şarkını seç, yarın güzel bakarsın.")
 ]
 case .night:
 return [
 ("Günü kapatmadan", "Bir şarkı, bir mood, 10 saniye."),
 ("Gece olmadan bırak", mood.map {"Dün '\($0)' dedin. Bugün? " } ?? "Bugünkü seçimini kaydet.")
 ]
 }
 }


 // MARK: - Circle

 private static func circleActivityVariants(_ ctx: MessageContext) -> [(String, String)] {
 let friend = ctx.friendName ?? "Bir arkadaşın"
 if ctx.friendCount <= 1 {
 return [("\(friend) bugünkü seçimini yaptı", "Çevrende neler oluyor bir bak!")]
 } else {
 let extras = ctx.friendCount - 1
 return [("\(friend) ve \(extras) kişi paylaştı", "Çevren bugün hareketli.")]
 }
 }

 // MARK: - Win-back

 private static func winBackVariants(days: Int, ctx: MessageContext) -> [(String, String)] {
 // C5 — Yumuşak ton, FOMO yerine kabul. Çevre varsa"seni özledi"
 // referansı, yoksa nazik bir"küçük bir not" daveti.
 // friendCount default 1 olduğu için friendName veya >1 ile gerçek
 // sosyal sinyal teyit edilir.
 let hasFriends = ctx.friendName != nil || ctx.friendCount > 1
 switch days {
 case 3:
 if hasFriends {
 return [
 ("Çevren seni özledi", "Birkaç gündür mood yok — küçük bir not bırakır mısın? "),
 ("3 gün geçti", "Acele yok. Bugünün rengini bırakmak yeter.")
 ]
 }
 return [
 ("Birkaç gün ara verdin", "İstediğinde tek bir kelime yeter — bugün nasılsın? "),
 ("Yavaş bir dönüş için", "Bugünkü hissini ONE'a bırakmak ister misin? ")
 ]
 case 7:
 if hasFriends {
 return [
 ("Çevren bu hafta seni andı", "Bir şarkı, bir mood — kısa bir geri dönüş yeter."),
 ("Bir hafta sessizdin", "Çevrende neler oldu görmek ister misin? ")
 ]
 }
 return [
 ("Bir haftadır sessiz", "Tek bir kelime: bugün nasılsın? "),
 ("Bugüne küçük bir başlangıç", "10 saniye yeter — mood'unu bırak.")
 ]
 case 14:
 return [
 ("İki hafta oldu", "Yumuşak bir dönüş için: tek bir mood yeter."),
 ("14 gün, 14 farklı renk olabilirdi", "Bugünkü tonun ne? ")
 ]
 case 30:
 return [
 ("Bir aydır birikenler var", "Geri dönüş ağır olmasın — tek kelime yeter."),
 ("30 gün geçti", hasFriends ? "Çevren senin payını saklı tutuyor." : "Tekrar başlamak için bugün güzel bir gün.")
 ]
 default:
 return [("Seni özledik", "Geri dönmek istediğinde, ONE seni bekliyor.")]
 }
 }

 // MARK: - Mood Resonance

 private static func moodResonanceVariants(_ ctx: MessageContext) -> [(String, String)] {
 let mood = ctx.lastMoodLabel ?? "aynı mood"
 let friend = ctx.friendName ?? "Çevren"
 if ctx.friendCount <= 1 {
 return [("\(friend) da \(mood) hissediyor", "Çevrende yankı var.")]
 } else if ctx.friendCount == 2 {
 return [("\(friend) ve 1 kişi daha \(mood) ", "Çevren bugün seninle aynı frekansta.")]
 } else {
 return [("\(friend) ve \(ctx.friendCount - 1) kişi daha \(mood) ", "Çevren bugün seninle aynı frekansta.")]
 }
 }

 // MARK: - Social

 private static func friendSharedVariants(_ ctx: MessageContext) -> [(String, String)] {
 let name = ctx.friendName ?? "Bir arkadaşın"
 let moodPart = ctx.lastMoodLabel.map {"\($0) hissediyor — dinlemek ister misin? " }
 ?? "Dinlemek ister misin? "
 return [("\(name) bugünkü şarkısını paylaştı", moodPart)]
 }

 private static func friendReactionVariants(_ ctx: MessageContext) -> [(String, String)] {
 let name = ctx.friendName ?? "Bir arkadaşın"
 let emoji = ctx.emoji ?? ""
 return [("\(name) paylaşımına \(emoji) bıraktı", "Çevrende yankı buluyorsun.")]
 }

 private static func friendRequestVariants(_ ctx: MessageContext) -> [(String, String)] {
 let name = ctx.friendName ?? "Biri"
 return [("\(name) seni çevresine eklemek istiyor", "Kabul et veya incele.")]
 }

 private static func friendAcceptedVariants(_ ctx: MessageContext) -> [(String, String)] {
 let name = ctx.friendName ?? "Arkadaşın"
 return [("\(name) artık çevrende", "İlk paylaşımını görmeye hazır mısın? ")]
 }
}
