//
//  EntitlementStoreTests.swift
//  oneTests
//
//  E15 premium kapısı: yetki türetimi, özellik tablosu, satın alma ve güncelleme akışı.
//

import Testing
import Foundation
@testable import OneDailyBatuhan

/// StoreKit yerine: etkin ürünler ve satın alma sonucu elle verilir.
final class FakeStoreBackend: StoreBackend {
    var active: Set<String> = []
    var nextOutcome: PurchaseOutcome = .cancelled
    private(set) var restored = false
    private var continuation: AsyncStream<Void>.Continuation?

    func activeProductIDs() async -> Set<String> { active }

    func products(_ ids: Set<String>) async -> [ProductInfo] {
        ids.sorted().map {
            ProductInfo(id: $0, displayName: $0, displayPrice: $0.hasSuffix("yearly") ? "199,99 TL" : "29,99 TL",
                        period: $0.hasSuffix("yearly") ? "P1Y" : "P1M", trialDays: 7, isEligibleForTrial: true)
        }
    }

    func purchase(_ id: String) async -> PurchaseOutcome {
        if case .purchased = nextOutcome { active.insert(id) }
        return nextOutcome
    }

    func restore() async { restored = true }

    func updates() -> AsyncStream<Void> {
        AsyncStream { self.continuation = $0 }
    }

    /// Başka cihazda satın alma ya da iade.
    func emitUpdate() { continuation?.yield() }
}

@MainActor
struct EntitlementStoreTests {

    @Test("Yetki türetimi: Premium ürünleri, AI Premium'u kapsar, bilinmeyen ürün yetki vermez")
    func derive() {
        #expect(Entitlements.derive(from: []) == Entitlements())
        #expect(Entitlements.derive(from: [PremiumProduct.yearly.rawValue]).hasPremium)
        let ai = Entitlements.derive(from: ["com.batudemir.ones.oneplusai.monthly"])
        #expect(ai.hasPremium && ai.hasAI)
        #expect(!Entitlements.derive(from: ["com.example.other"]).hasPremium)
    }

    @Test("Özellik tablosu: ücretsizde tüm premium özellikler kapalı, premium'da açık")
    func features() {
        for f in PremiumFeature.allCases {
            #expect(!PremiumFeature.isAvailable(f, hasPremium: false))
            #expect(PremiumFeature.isAvailable(f, hasPremium: true))
        }
    }

    @Test("Başlangıç: ürünler yıllık önce, yetki okunur")
    func start() async {
        let backend = FakeStoreBackend()
        backend.active = [PremiumProduct.monthly.rawValue]
        let store = EntitlementStore(backend: backend)
        await store.start()
        #expect(store.hasPremium)
        #expect(store.entitlements.activeProductID == PremiumProduct.monthly.rawValue)
        #expect(store.products.map(\.period) == ["P1Y", "P1M"])
        #expect(store.isAvailable(.markdownExport))
    }

    @Test("Satın alma: deneme olayı, yetki tazelenir; iptal yetki vermez")
    func purchase() async {
        let backend = FakeStoreBackend(), tracker = RecordingTracker()
        let store = EntitlementStore(backend: backend, analytics: tracker)
        await store.start()
        #expect(await store.purchase(PremiumProduct.yearly.rawValue) == .cancelled)
        #expect(!store.hasPremium && tracker.events.isEmpty)

        backend.nextOutcome = .purchased(productID: PremiumProduct.yearly.rawValue, isTrial: true)
        #expect(await store.purchase(PremiumProduct.yearly.rawValue) == .purchased(productID: PremiumProduct.yearly.rawValue, isTrial: true))
        #expect(store.hasPremium)
        #expect(tracker.events == [.trialStarted(productID: PremiumProduct.yearly.rawValue)])
    }

    @Test("İşlem güncellemesi (iade) yetkiyi düşürür; geri yükleme yeniden okur")
    func updatesAndRestore() async {
        let backend = FakeStoreBackend()
        backend.active = [PremiumProduct.yearly.rawValue]
        let store = EntitlementStore(backend: backend)
        await store.start()
        #expect(store.hasPremium)
        backend.active = []
        backend.emitUpdate()
        for _ in 0..<50 where store.hasPremium { await Task.yield() }
        #expect(!store.hasPremium)
        backend.active = [PremiumProduct.monthly.rawValue]
        await store.restore()
        #expect(backend.restored && store.hasPremium)
    }

    @Test("Premium motorlara ulaşır: ücretsizde kilitli yol, premium'da açık")
    func enginesSeePremium() async {
        let backend = FakeStoreBackend()
        let r = AppEnvironmentLifecycleTests.rig(storeBackend: backend)
        r.env.profile.update { $0.quotePaths = ["stoacilar", "varoluscular"] }
        await r.env.entitlements.start()
        #expect(!r.env.quotes.isAccessible(.path("varoluscular")))
        backend.active = [PremiumProduct.yearly.rawValue]
        await r.env.entitlements.refresh()
        #expect(r.env.quotes.isAccessible(.path("varoluscular")))
    }
}
