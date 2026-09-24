//
//  ProfileFixture.swift
//  ONE 2.0
//
//  ÖRNEK VERİ. Rozetler ve paywall planları. Fiyatlar örnektir; gerçek
//  değerler App Store Connect'ten gelir.
//

import Foundation

nonisolated enum ProfileFixture {

    static let badges: [BadgeData] = [
        BadgeData(id: "fx_badge_first", title: "İlk sayfa", value: "1", earnedAt: FixtureClock.daysAgo(40, 21), remaining: nil),
        BadgeData(id: "fx_badge_7", title: "Bir hafta", value: "7", earnedAt: FixtureClock.daysAgo(30, 22), remaining: nil),
        BadgeData(id: "fx_badge_30", title: "Bir ay", value: "30", earnedAt: nil, remaining: 18),
        BadgeData(id: "fx_badge_theme", title: "Tam tema", value: "7/7", earnedAt: FixtureClock.daysAgo(10, 20), remaining: nil),
        BadgeData(id: "fx_badge_quote", title: "Söze yazan", value: "10", earnedAt: nil, remaining: 7),
        BadgeData(id: "fx_badge_100", title: "Yüz gün", value: "100", earnedAt: nil, remaining: 88),
    ]

    static let plans: [PlanData] = [
        PlanData(id: "com.batudemir.ones.oneplus.yearly", title: "Yıllık", price: "599,99 TL",
                 detail: "ayda 49,99 TL", trial: "7 gün ücretsiz", isRecommended: true,
                 billingNote: "Deneme 1 Ekim'de biter; iptal etmezsen o gün 599,99 TL çekilir."),
        PlanData(id: "com.batudemir.ones.oneplus.monthly", title: "Aylık", price: "89,99 TL",
                 detail: nil, trial: nil, isRecommended: false,
                 billingNote: "Her ay yenilenir; istediğin zaman iptal edebilirsin."),
    ]
}
