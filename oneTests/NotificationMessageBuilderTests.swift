//
//  NotificationMessageBuilderTests.swift
//  oneTests
//
//  Bildirim metninin **sesini** test eder, kelimesini değil: metin dokuz
//  dilde katalogdan geliyor, o yüzden burada aranan şey kalıp — başlık kişi
//  mi, gövde olgu mu, aynı tohum aynı metni mi veriyor.
//

import Testing
import Foundation
@testable import OneDailyBatuhan

struct NotificationMessageBuilderTests {

    // MARK: - Determinizm

    /// Aynı tohum aynı mesajı vermeli: bildirim planlanırken bir kez, teslim
    /// analitiğinde bir kez üretiliyor. İkisi ayrışırsa hangi varyantın
    /// gönderildiğini kimse bilemez.
    @Test("Aynı tohum aynı varyantı seçer")
    func deterministicVariant() {
        let ctx = MessageContext(kind: .dailyReminder, now: fixedDate(hour: 20))
        let a = NotificationMessageBuilder.build(ctx, seed: 4242)
        let b = NotificationMessageBuilder.build(ctx, seed: 4242)
        #expect(a.title == b.title)
        #expect(a.body == b.body)
        #expect(a.variant == b.variant)
    }

    @Test("dailySeed gün değişince değişir")
    func dailySeedChangesPerDay() {
        let today = fixedDate(hour: 9)
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today)!
        #expect(NotificationMessageBuilder.dailySeed(for: today)
                != NotificationMessageBuilder.dailySeed(for: tomorrow))
    }

    /// Negatif tohum çökertmemeli: `abs(Int.min)` taşar, `%` negatif indeks
    /// üretir. Varyant dizisi indekslendiği için ikisi de çökme demek.
    @Test("Uç tohumlar geçerli varyant üretir")
    func extremeSeedsStayInRange() {
        for seed in [Int.min + 1, -1, 0, Int.max] {
            let msg = NotificationMessageBuilder.build(
                MessageContext(kind: .weeklySummary, now: fixedDate(hour: 11)),
                seed: seed
            )
            #expect(!msg.title.isEmpty)
            #expect(!msg.body.isEmpty)
            #expect(msg.variant >= 0)
        }
    }

    // MARK: - Sosyal: başlık kişi, gövde olay

    @Test("Sosyal bildirimde başlık kişinin adı")
    func socialTitleIsPerson() {
        for kind in [NotificationKind.friendShared, .friendRequest,
                     .friendAccepted, .friendReaction, .circleActivity] {
            let msg = NotificationMessageBuilder.social(kind, friendName: "Deniz")
            #expect(msg.title == "Deniz", "\(kind) başlığı kişi olmalı: \(msg.title)")
            #expect(!msg.body.isEmpty)
        }
    }

    @Test("Çok kişi olunca başlık kişi + sayı")
    func socialTitleWithOthers() {
        let msg = NotificationMessageBuilder.social(.circleActivity,
                                                    friendName: "Deniz",
                                                    friendCount: 3)
        #expect(msg.title.contains("Deniz"))
        #expect(msg.title.contains("2"))        // "Deniz ve 2 kişi"
    }

    @Test("Ad yoksa yedek ad kullanılır, boş başlık olmaz")
    func socialFallbackName() {
        let msg = NotificationMessageBuilder.social(.friendRequest, friendName: nil)
        #expect(!msg.title.isEmpty)
    }

    // MARK: - Ses kuralları

    /// v4: bildirimde soru bir talep, ünlem bir yalvarma. Katalog tarafını
    /// voice_guard denetliyor; burada **üretilen** metin denetleniyor —
    /// birleştirme sırasında girmediğinden emin olmak için.
    @Test("Üretilen metinde ünlem ve soru işareti yok")
    func noPleadingPunctuation() {
        var produced: [String] = []
        for kind in NotificationKind.allCases {
            let msg = NotificationMessageBuilder.social(kind, friendName: "Deniz",
                                                        moodLabel: "huzurlu", emoji: "🔥")
            produced.append(msg.title)
            produced.append(msg.body)
        }
        for tone in [NotificationMessageBuilder.DailyTone.quiet, .plain, .recall] {
            let msg = NotificationMessageBuilder.dailyReminder(
                tone: tone, yesterdayMoodLabel: "huzurlu", now: fixedDate(hour: 20)
            )
            produced.append(msg.title)
            produced.append(msg.body)
        }
        for text in produced {
            #expect(!text.contains("!"), "ünlem: \(text)")
            #expect(!text.contains("?"), "soru: \(text)")
        }
    }

    // MARK: - Günlük ritüel tonları

    @Test("Üç ton da boş olmayan metin verir")
    func everyToneProducesText() {
        for tone in [NotificationMessageBuilder.DailyTone.quiet, .plain, .recall] {
            let msg = NotificationMessageBuilder.dailyReminder(
                tone: tone, yesterdayMoodLabel: nil, now: fixedDate(hour: 9)
            )
            #expect(!msg.title.isEmpty)
            #expect(!msg.body.isEmpty)
        }
    }

    /// `recall` tonu dünkü moodu anar; mood yoksa `plain`'e düşmeli —
    /// "Dün ." gibi yarım bir cümle çıkmamalı.
    @Test("Dün bağlamlı ton mood yoksa düz metne düşer")
    func recallFallsBackWithoutMood() {
        let now = fixedDate(hour: 20)
        let recall = NotificationMessageBuilder.dailyReminder(
            tone: .recall, yesterdayMoodLabel: nil, now: now, seed: 7
        )
        let plain = NotificationMessageBuilder.dailyReminder(
            tone: .plain, yesterdayMoodLabel: nil, now: now, seed: 7
        )
        #expect(recall.body == plain.body)
    }

    @Test("Dün bağlamlı ton mood'u gövdeye koyar")
    func recallCarriesMood() {
        let msg = NotificationMessageBuilder.dailyReminder(
            tone: .recall, yesterdayMoodLabel: "huzurlu", now: fixedDate(hour: 20)
        )
        #expect(msg.body.contains("huzurlu"))
    }

    // MARK: - Helper

    private func fixedDate(hour: Int) -> Date {
        var comps = DateComponents()
        comps.year = 2026; comps.month = 9; comps.day = 8   // Salı
        comps.hour = hour
        return Calendar.current.date(from: comps)!
    }
}
