//
//  ProfileViewData.swift
//  ONE 2.0
//
//  Profil (rozetler, E9) ve paywall planları (E15). Fiyatlar örnektir;
//  gerçek değerler App Store Connect'ten (StoreKit, UX-11).
//

import Foundation

nonisolated struct BadgeData: Identifiable, Equatable, Sendable {
    let id: String
    let title: String
    /// Diskteki mono değer ("7", "30").
    let value: String
    let earnedAt: Date?
    /// Kilitliyse kalan gün.
    let remaining: Int?

    var isEarned: Bool { earnedAt != nil }
}

nonisolated struct PlanData: Identifiable, Equatable, Sendable {
    /// StoreKit ürün ID'si (`com.batudemir.ones.oneplus.*`).
    let id: String
    let title: String
    let price: String
    /// "ayda 49,99 TL" gibi karşılaştırma satırı.
    let detail: String?
    /// "7 gün ücretsiz"; yoksa nil.
    let trial: String?
    let isRecommended: Bool
    /// Ücretin ne zaman çekileceği.
    let billingNote: String
}
