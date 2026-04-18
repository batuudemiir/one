//
//  PremiumManager.swift
//  one
//
//  Premium sistemi şimdilik devre dışı — tüm kullanıcılar temel özelliklere erişebilir.
//

import SwiftUI
import Combine
import WidgetKit

@MainActor
class PremiumManager: NSObject, ObservableObject {

    static let shared = PremiumManager()

    // MARK: - Constants

    /// Premium sistemi şimdilik kapalı.
    static let premiumEnabled = false

    // MARK: - Published State (stub — always false)

    @Published var isPremium: Bool = false
    @Published var purchaseState: PurchaseState = .idle
    @Published var expirationDate: Date? = nil
    @Published var subscriptionType: String = ""

    // MARK: - Configure (stub)

    static func configure() {
        // Premium sistemi devre dışı — RevenueCat başlatılmıyor.
    }

    // MARK: - Init

    private override init() {
        super.init()
    }

    // MARK: - Stub Methods

    func refreshCustomerInfo() async { }
    func loadOfferings() async { }
    func restorePurchases() async { }
    func handleCustomerInfoUpdate(_ info: Any) { }

    // MARK: - Feature Access (always allowed for non-premium features)

    func hasAccess(to feature: PremiumFeature) -> Bool { false }
}

