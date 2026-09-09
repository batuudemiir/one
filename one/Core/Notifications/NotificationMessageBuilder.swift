//
//  NotificationMessageBuilder.swift
//  one
//
//  title/body üretimi. TimeOfDay + NotificationKind + son mood +
//  A/B bucket girdilerine göre deterministik seçim yapar (aynı seed → aynı
//  mesaj). Varyantlar arası eşit dağılım için `seed % count` kullanılır.
//
//  v4 marka sesi — "az konuşan kurator". Bağlayıcı kurallar:
//  · Uygulama bir şey istemez; bir olguyu bildirir.
//  · Kullanıcının duygusu yorumlanmaz, adlandırılmaz, teşhis edilmez.
//  · Süre vaadi ("10 saniye"), alışkanlık dili, FOMO ve özlem dili yok.
//  · Sosyal bildirimde özne insandır: başlık kişi, gövde olay (Apple HIG).
//  · Soru işareti ve ünlem talep sinyalidir — kullanılmaz.
//  · Uygulama kendini özne yapmaz: "ONE seni bekliyor" yasak.
//
//  Metin **katalogdan** gelir (`notif.*` anahtarları, dokuz dil). Burada
//  kelime birleştirilmez: her dil tam cümleyi kendi dilbilgisiyle kurar —
//  "Dün " + mood ya da isim + " ve N kişi" yalnız Türkçe'de çalışıyordu.
//  Gün ve ay adları `LanguageManager.shared.currentLocale` ile biçimleniyor.
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
    let recentMoodLabels: [String]
    let friendName: String?
    let friendCount: Int
    let emoji: String?
    let commentExcerpt: String? // v2.5 — yorum önizleme (≤80 karakter, trimmed)
    let commentCount: Int       // v2.5 — batch'te kaç yorum
    let abBucket: Int

    /// Gün adı ("Salı", "Cumartesi"). Bildirimin bağlamını takvim verir,
    /// uygulama değil — nötr, talepsiz bir çerçeve.
    var weekdayName: String {
        let f = DateFormatter()
        f.locale = LanguageManager.shared.currentLocale
        f.dateFormat = "EEEE"
        return f.string(from: now).localizedCapitalized
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

    // MARK: - Katalog

    /// Bildirim metni katalog anahtarı. `Bundle.setLanguage` (LanguageManager)
    /// ana bundle'ı takas ettiği için uygulama içi dil seçimi burada da geçerli.
    private static func L(_ key: String) -> String {
        NSLocalizedString(key, comment: "notification copy")
    }

    /// Biçimli karşılık. Çok argümanlı anahtarlar konumlu (`%1$@`) yazılır:
    /// sıralama dile göre değişiyor.
    private static func Lf(_ key: String, _ args: CVarArg...) -> String {
        String(format: NSLocalizedString(key, comment: "notification copy"),
               arguments: args)
    }

    /// "%1$@ ve %2$d kişi" — çevre, rezonans ve yorum yığını ortak kullanır.
    private static func peopleTitle(_ name: String, _ others: Int) -> String {
        Lf("notif.people.andOthers", name, others)
    }

    // MARK: - Public

    static func build(_ ctx: MessageContext, seed: Int) -> NotificationMessage {
        let variants = variants(for: ctx)
        guard !variants.isEmpty else {
            return NotificationMessage(title: "ONE", body: L("notif.fallback.body"), variant: 0)
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

    /// Sosyal olaylar için tek satırlık giriş. Çağrı yerleri (CloudKit push
    /// handler'ları, rezonans servisi, çevre özeti) kendi metnini yazmaz —
    /// v4 sesinin tek kaynağı burasıdır.
    ///
    /// Başlık kişidir, gövde olaydır (Apple HIG başlık/gövde ayrımı).
    static func social(
        _ kind: NotificationKind,
        friendName: String? = nil,
        friendCount: Int = 1,
        moodLabel: String? = nil,
        emoji: String? = nil,
        now: Date = Date()
    ) -> NotificationMessage {
        build(
            MessageContext(
                kind: kind,
                now: now,
                lastMoodLabel: moodLabel,
                friendName: friendName,
                friendCount: friendCount,
                emoji: emoji
            ),
            seed: 0
        )
    }

    // MARK: - Günlük ritüel

    /// Kullanıcının hatırlatma ayarındaki ton. Üçü de aynı kurala uyar —
    /// olguyu bildirir, bir şey istemez, duyguyu adlandırmaz. Fark yalnızca
    /// ne kadar bağlam taşıdıklarıdır.
    enum DailyTone {
        case quiet    // yalnız gün + durum
        case plain    // günün saatine göre çerçeve
        case recall   // dünkü kaydı olgu olarak anar
    }

    /// Günlük ritüelin metni. Ritüeli kullanıcı kurar (saatini kendisi seçer),
    /// bu yüzden haftalık proaktif bütçeye girmez; ama sesi bildirimin geri
    /// kalanıyla aynıdır.
    static func dailyReminder(
        tone: DailyTone,
        yesterdayMoodLabel: String? = nil,
        now: Date = Date(),
        seed: Int? = nil
    ) -> NotificationMessage {
        let ctx = MessageContext(
            kind: .dailyReminder,
            now: now,
            lastMoodLabel: (tone == .recall) ? yesterdayMoodLabel : nil
        )
        let day = ctx.weekdayName
        let chosenSeed = seed ?? dailySeed(for: now)

        let variants: [(title: String, body: String)]
        switch tone {
        case .quiet:
            // Tek cümle, tek olgu. Gün adı bağlamı zaten veriyor.
            variants = [(day, L("notif.daily.empty"))]

        case .plain:
            variants = dailyReminderVariants(ctx)

        case .recall:
            if let mood = yesterdayMoodLabel, !mood.isEmpty {
                // Çerçeve fire saatinden gelir: hatırlatması 09:00 olan
                // kullanıcıya "Salı akşamı" demek, uydurma bir bağlamdır.
                let frame: String
                switch ctx.timeOfDay {
                case .morning: frame = Lf("notif.day.morning", day)
                case .noon:    frame = Lf("notif.day.noon", day)
                case .evening: frame = Lf("notif.day.evening", day)
                case .night:   frame = L("notif.day.night")
                }
                let recallBody = Lf("notif.daily.yesterday", mood)
                variants = [(day, recallBody), (frame, recallBody)]
            } else {
                variants = dailyReminderVariants(ctx)
            }
        }

        guard !variants.isEmpty else {
            return NotificationMessage(title: day, body: L("notif.daily.empty"), variant: 0)
        }
        let idx = abs(chosenSeed) % variants.count
        return NotificationMessage(title: variants[idx].title, body: variants[idx].body, variant: idx)
    }

    // MARK: - Variants

    private static func variants(for ctx: MessageContext) -> [(title: String, body: String)] {
        switch ctx.kind {
        case .dailyReminder:    return dailyReminderVariants(ctx)
        case .weeklySummary:    return weeklySummaryVariants(ctx)
        case .monthEndSummary:  return monthlyPortraitVariants(ctx)
        case .circleActivity:   return circleActivityVariants(ctx)
        case .moodResonance:    return moodResonanceVariants(ctx)
        case .friendShared:     return friendSharedVariants(ctx)
        case .friendReaction:   return friendReactionVariants(ctx)
        case .friendRequest:    return friendRequestVariants(ctx)
        case .friendAccepted:   return friendAcceptedVariants(ctx)
        case .commentReceived:  return commentReceivedVariants(ctx)
        case .commentReply:     return commentReplyVariants(ctx)
        case .commentMention:   return commentMentionVariants(ctx)
        case .commentBatch:     return commentBatchVariants(ctx)
        }
    }

    // MARK: - Comment excerpt helper

    /// Yorum metnini push body için güvenli kısaltır: newline → boşluk, 80 karakter cap, "…".
    private static func excerpt(_ raw: String?, limit: Int = 80) -> String? {
        guard let raw else { return nil }
        let cleaned = raw
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\n", with: " ")
        guard !cleaned.isEmpty else { return nil }
        if cleaned.count <= limit { return cleaned }
        let idx = cleaned.index(cleaned.startIndex, offsetBy: limit)
        return String(cleaned[..<idx]) + "…"
    }

    // MARK: - Comment variants (v2.5)
    //
    // Başlık olayı, gövde yorumun kendisini taşır. Uygulama yorum hakkında
    // yorum yapmaz — "konuşma başladı", "hareketlendi" gibi coşku dili yok.

    private static func commentReceivedVariants(_ ctx: MessageContext) -> [(String, String)] {
        let name = ctx.friendName ?? L("notif.someone")
        let body = excerpt(ctx.commentExcerpt).map { "\"\($0)\"" } ?? L("notif.comment.received.body")
        return [(Lf("notif.comment.received.title", name), body)]
    }

    private static func commentReplyVariants(_ ctx: MessageContext) -> [(String, String)] {
        let name = ctx.friendName ?? L("notif.someone")
        let body = excerpt(ctx.commentExcerpt).map { "\"\($0)\"" } ?? L("notif.comment.reply.body")
        return [(Lf("notif.comment.reply.title", name), body)]
    }

    private static func commentMentionVariants(_ ctx: MessageContext) -> [(String, String)] {
        let name = ctx.friendName ?? L("notif.someone")
        let body = excerpt(ctx.commentExcerpt).map { "\"\($0)\"" } ?? L("notif.comment.mention.body")
        return [(Lf("notif.comment.mention.title", name), body)]
    }

    private static func commentBatchVariants(_ ctx: MessageContext) -> [(String, String)] {
        let count = ctx.commentCount
        if let name = ctx.friendName, count > 1 {
            return [(peopleTitle(name, count - 1), L("notif.comment.received.body"))]
        } else {
            return [(Lf("notif.comment.batch.title", count), L("notif.comment.batch.body"))]
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
        let monthName = formatter.string(from: prevMonth).localizedCapitalized
        return [
            (monthName, L("notif.monthly.ready")),
            (Lf("notif.monthly.closed.title", monthName), L("notif.monthly.closed.body")),
            (L("notif.monthly.generic.title"), Lf("notif.monthly.generic.body", monthName))
        ]
    }

    // MARK: - C2 — Sunday Reflection (weekly summary push)

    private static func weeklySummaryVariants(_ ctx: MessageContext) -> [(String, String)] {
        var variants: [(String, String)] = [
            (L("notif.weekly.thisWeek.title"), L("notif.weekly.thisWeek.body")),
            (L("notif.weekly.palette.title"), L("notif.weekly.palette.body"))
        ]
        if let mood = ctx.lastMoodLabel {
            variants.append((L("notif.weekly.dominant.title"), Lf("notif.weekly.dominant.body", mood)))
        }
        variants.append((L("notif.weekly.sunday.title"), L("notif.weekly.sunday.body")))
        return variants
    }

    // MARK: - Daily reminder (TimeOfDay-aware)
    //
    // Tek görevi: bugünün arşivde boş olduğunu bildirmek. Motivasyon,
    // alışkanlık, süre vaadi ve ruh hali yorumu içermez. Hafta sonu ve
    // "ağır mood serisi" özel dilleri v4'te kaldırıldı: uygulama
    // kullanıcının duygusal durumunu okumaz ve ona göre konuşmaz.

    private static func dailyReminderVariants(_ ctx: MessageContext) -> [(String, String)] {
        let day = ctx.weekdayName
        let mood = ctx.lastMoodLabel

        switch ctx.timeOfDay {
        case .morning:
            var v: [(String, String)] = [
                (Lf("notif.day.morning", day), L("notif.daily.emptyStanding")),
                (day, L("notif.daily.noColorYet"))
            ]
            if let mood { v.append((day, Lf("notif.daily.yesterday", mood))) }
            return v

        case .noon:
            var v: [(String, String)] = [
                (Lf("notif.day.noon", day), L("notif.daily.stillEmpty")),
                (day, L("notif.daily.noColorYet"))
            ]
            if let mood { v.append((day, Lf("notif.daily.yesterday", mood))) }
            return v

        case .evening:
            var v: [(String, String)] = [
                (Lf("notif.day.evening", day), L("notif.daily.stillEmpty")),
                (day, L("notif.daily.beforeClose"))
            ]
            if let mood { v.append((Lf("notif.day.evening", day), Lf("notif.daily.yesterday", mood))) }
            return v

        case .night:
            return [
                (L("notif.day.night"), L("notif.daily.colorless")),
                (day, L("notif.daily.stillNotPicked"))
            ]
        }
    }

    // MARK: - Circle
    //
    // Özne insan. Uygulama "bir bak", "hareketli" gibi yorum eklemez.

    private static func circleActivityVariants(_ ctx: MessageContext) -> [(String, String)] {
        let friend = ctx.friendName ?? L("notif.aFriend")
        if ctx.friendCount <= 1 {
            return [(friend, L("notif.circle.leftColor"))]
        } else {
            return [(peopleTitle(friend, ctx.friendCount - 1), L("notif.circle.leftColors"))]
        }
    }

    // MARK: - Mood Resonance

    private static func moodResonanceVariants(_ ctx: MessageContext) -> [(String, String)] {
        let friend = ctx.friendName ?? L("notif.someoneInCircle")
        let body = ctx.lastMoodLabel.map { Lf("notif.resonance.body", $0) }
            ?? L("notif.resonance.bodyNoMood")
        if ctx.friendCount <= 1 {
            return [(friend, body)]
        } else {
            return [(peopleTitle(friend, ctx.friendCount - 1), body)]
        }
    }

    // MARK: - Social

    private static func friendSharedVariants(_ ctx: MessageContext) -> [(String, String)] {
        let name = ctx.friendName ?? L("notif.aFriend")
        let body = ctx.lastMoodLabel.map { Lf("notif.friendShared.withMood", $0) }
            ?? L("notif.friendShared.noMood")
        return [(name, body)]
    }

    private static func friendReactionVariants(_ ctx: MessageContext) -> [(String, String)] {
        let name = ctx.friendName ?? L("notif.aFriend")
        if let emoji = ctx.emoji, !emoji.isEmpty {
            return [(name, Lf("notif.reaction.withEmoji", emoji))]
        }
        return [(name, L("notif.reaction.plain"))]
    }

    private static func friendRequestVariants(_ ctx: MessageContext) -> [(String, String)] {
        let name = ctx.friendName ?? L("notif.someone")
        return [(name, L("notif.friendRequest.body"))]
    }

    private static func friendAcceptedVariants(_ ctx: MessageContext) -> [(String, String)] {
        let name = ctx.friendName ?? L("notif.yourFriend")
        return [(name, L("notif.friendAccepted.body"))]
    }
}
