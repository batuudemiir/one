//
//  EntitlementStore.swift
//  ONE 2.0
//
//  Premium kapısı (ADR-001 §8, 04_arka_plan_motorlari.md › E15).
//
//  - Tek abonelik grubu "ONE+"; Premium ürünleri mevcut
//    `com.batudemir.ones.oneplus.monthly/yearly` (ONEPlus.storekit). AI
//    seviyesi Faz 7'de (`oneplusai.*`).
//  - Doğruluk kaynağı StoreKit 2: açılışta `Transaction.currentEntitlements`,
//    sürekli `Transaction.updates`. Sunucu yok.
//  - Hangi özelliğin kilitli olduğu `PremiumFeature` tablosunda; motorlar
//    `hasPremium`'u buradan okur.
//  - StoreKit çağrıları `StoreBackend` arkasında; testte sahte arka uç.
//

import Foundation
import Observation
import StoreKit

nonisolated enum PremiumProduct: String, CaseIterable, Sendable {
    case monthly = "com.batudemir.ones.oneplus.monthly"
    case yearly = "com.batudemir.ones.oneplus.yearly"

    static let premiumIDs = Set(allCases.map(\.rawValue))
    /// Faz 7 (AI seviyesi); henüz satılmıyor.
    static let aiIDs: Set<String> = ["com.batudemir.ones.oneplusai.monthly", "com.batudemir.ones.oneplusai.yearly"]
}

/// E15 tablosu: ücretsizde kapalı olanlar.
nonisolated enum PremiumFeature: String, CaseIterable, Sendable {
    /// Sözler: "Sana özel" + ilk yol dışındaki yollar ve tür akışları (karar 4).
    case allQuotePaths
    /// Premium işaretli içerik (söz, rehberli günlük, tema).
    case premiumContent
    /// Geçmiş temalar: ücretsizde son 4 hafta.
    case allPastThemes
    /// Eğilimler: 14 gün dışındaki dönemler, duygu/etiket ilişkisi, değişim çiftleri.
    case advancedInsights
    /// Özel şablonlar.
    case customTemplates
    /// Widget: ücretsizde yalnız günün sözü.
    case allWidgets
    /// Dışa aktarma: Markdown arşivi (JSON ücretsiz).
    case markdownExport

    /// Ücretsiz kalanlar (bilinçli): ritüel, check-in, günün sorusu, boş sayfa,
    /// söze yazı, seri ve rozetler, kilit, JSON dışa aktarma, eşitleme.
    static func isAvailable(_ feature: PremiumFeature, hasPremium: Bool) -> Bool {
        hasPremium
    }
}

nonisolated struct Entitlements: Equatable, Sendable {
    var hasPremium = false
    var hasAI = false
    /// Etkin abonelik ürünü (paywall'da "mevcut plan").
    var activeProductID: String?

    /// Etkin işlemlerin ürün ID'lerinden yetki. AI seviyesi Premium'u da kapsar.
    static func derive(from productIDs: Set<String>) -> Entitlements {
        let ai = !productIDs.isDisjoint(with: PremiumProduct.aiIDs)
        let premium = ai || !productIDs.isDisjoint(with: PremiumProduct.premiumIDs)
        let active = productIDs.intersection(PremiumProduct.premiumIDs.union(PremiumProduct.aiIDs)).sorted().first
        return Entitlements(hasPremium: premium, hasAI: ai, activeProductID: active)
    }
}

/// Paywall'ın gösterdiği ürün bilgisi (fiyat StoreKit'ten, yerelleştirilmiş).
nonisolated struct ProductInfo: Equatable, Sendable, Identifiable {
    let id: String
    let displayName: String
    let displayPrice: String
    /// `P1M`, `P1Y`.
    let period: String
    /// Ücretsiz deneme günü; yoksa nil.
    let trialDays: Int?
    let isEligibleForTrial: Bool
}

nonisolated enum PurchaseOutcome: Equatable, Sendable {
    case purchased(productID: String, isTrial: Bool)
    case pending
    case cancelled
    case failed
}

/// StoreKit 2 soyutlaması.
protocol StoreBackend: AnyObject {
    func activeProductIDs() async -> Set<String>
    func products(_ ids: Set<String>) async -> [ProductInfo]
    func purchase(_ id: String) async -> PurchaseOutcome
    func restore() async
    /// İşlem değiştiğinde (yenileme, iade, başka cihazda satın alma) tetiklenir.
    func updates() -> AsyncStream<Void>
}

@Observable
final class EntitlementStore {
    private(set) var entitlements = Entitlements()
    private(set) var products: [ProductInfo] = []

    var hasPremium: Bool { entitlements.hasPremium }
    var hasAI: Bool { entitlements.hasAI }

    @ObservationIgnored private let backend: StoreBackend
    @ObservationIgnored private let analytics: EventTracking?
    @ObservationIgnored private var listener: Task<Void, Never>?

    init(backend: StoreBackend = StoreKitBackend(), analytics: EventTracking? = nil) {
        self.backend = backend
        self.analytics = analytics
    }

    deinit { listener?.cancel() }

    /// Açılışta: yetkiyi ve ürünleri yükler, işlem akışını dinlemeye başlar.
    func start() async {
        if listener == nil {
            let stream = backend.updates()
            listener = Task { [weak self] in
                for await _ in stream { await self?.refresh() }
            }
        }
        await refresh()
        products = await backend.products(PremiumProduct.premiumIDs)
            .sorted { ($0.period == "P1Y" ? 0 : 1, $0.id) < ($1.period == "P1Y" ? 0 : 1, $1.id) }
    }

    func refresh() async {
        entitlements = Entitlements.derive(from: await backend.activeProductIDs())
    }

    func isAvailable(_ feature: PremiumFeature) -> Bool {
        PremiumFeature.isAvailable(feature, hasPremium: hasPremium)
    }

    @discardableResult
    func purchase(_ productID: String) async -> PurchaseOutcome {
        let outcome = await backend.purchase(productID)
        if case .purchased(let id, let isTrial) = outcome {
            analytics?.track(isTrial ? .trialStarted(productID: id) : .purchase(productID: id))
            await refresh()
        }
        return outcome
    }

    /// "Geri yükle": App Store ile eşitler, yetkiyi yeniden okur.
    func restore() async {
        await backend.restore()
        await refresh()
    }
}

// MARK: - StoreKit 2

final class StoreKitBackend: StoreBackend {

    func activeProductIDs() async -> Set<String> {
        var ids: Set<String> = []
        for await result in Transaction.currentEntitlements {
            guard case .verified(let t) = result, t.revocationDate == nil else { continue }
            if let expiry = t.expirationDate, expiry < Date() { continue }
            ids.insert(t.productID)
        }
        return ids
    }

    func products(_ ids: Set<String>) async -> [ProductInfo] {
        guard let products = try? await Product.products(for: ids) else { return [] }
        var out: [ProductInfo] = []
        for p in products {
            let offer = p.subscription?.introductoryOffer
            let trialDays = offer.flatMap { $0.paymentMode == .freeTrial ? Self.days($0.period) : nil }
            let eligible = await p.subscription?.isEligibleForIntroOffer ?? false
            out.append(ProductInfo(id: p.id, displayName: p.displayName, displayPrice: p.displayPrice,
                                   period: p.subscription.map { Self.iso($0.subscriptionPeriod) } ?? "",
                                   trialDays: trialDays, isEligibleForTrial: eligible))
        }
        return out
    }

    func purchase(_ id: String) async -> PurchaseOutcome {
        guard let product = try? await Product.products(for: [id]).first else { return .failed }
        do {
            switch try await product.purchase() {
            case .success(let verification):
                guard case .verified(let t) = verification else { return .failed }
                await t.finish()
                // Gruptaki tek tanıtım teklifi ücretsiz deneme (ONEPlus.storekit);
                // `offer` iOS 17.2+, `offerType` 17.0'da da var.
                return .purchased(productID: t.productID, isTrial: t.offerType == .introductory)
            case .pending: return .pending
            case .userCancelled: return .cancelled
            @unknown default: return .failed
            }
        } catch {
            return .failed
        }
    }

    func restore() async {
        try? await AppStore.sync()
    }

    func updates() -> AsyncStream<Void> {
        AsyncStream { continuation in
            let task = Task {
                for await result in Transaction.updates {
                    if case .verified(let t) = result { await t.finish() }
                    continuation.yield()
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    private static func iso(_ p: Product.SubscriptionPeriod) -> String {
        switch p.unit {
        case .day: return "P\(p.value)D"
        case .week: return "P\(p.value)W"
        case .month: return "P\(p.value)M"
        case .year: return "P\(p.value)Y"
        @unknown default: return ""
        }
    }

    private static func days(_ p: Product.SubscriptionPeriod) -> Int {
        switch p.unit {
        case .day: return p.value
        case .week: return p.value * 7
        case .month: return p.value * 30
        case .year: return p.value * 365
        @unknown default: return 0
        }
    }
}
