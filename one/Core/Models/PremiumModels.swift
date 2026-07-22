//
//  PremiumModels.swift
//  one
//
//  ONE+ Premium subscription models
//

import Foundation

// MARK: - Purchase State

enum PurchaseState: Equatable, Sendable {
    case idle
    case purchasing
    case success
    case error(String)

    static func == (lhs: PurchaseState, rhs: PurchaseState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle), (.purchasing, .purchasing), (.success, .success):
            return true
        case (.error(let a), .error(let b)):
            return a == b
        default:
            return false
        }
    }
}

// MARK: - Premium Feature

enum PremiumFeature: String, CaseIterable {
    case multipleEntries = "multipleEntries"
    case weeklyPlaylist = "weeklyPlaylist"
    case circleFeed = "circleFeed"
    case monthlySummary = "monthlySummary"
    case premiumWidgets = "premiumWidgets"

    var displayName: String {
        switch self {
        case .multipleEntries:
            return NSLocalizedString("premium.feature.multipleEntries", comment: "")
        case .weeklyPlaylist:
            return NSLocalizedString("premium.feature.weeklyPlaylist", comment: "")
        case .circleFeed:
            return NSLocalizedString("premium.feature.circleFeed", comment: "")
        case .monthlySummary:
            return NSLocalizedString("premium.feature.monthlySummary", comment: "")
        case .premiumWidgets:
            return NSLocalizedString("premium.feature.premiumWidgets", comment: "")
        }
    }

    var icon: String {
        switch self {
        case .multipleEntries: return "plus.square.on.square"
        case .weeklyPlaylist: return "music.note.list"
        case .circleFeed: return "person.2.circle"
        case .monthlySummary: return "calendar.badge.clock"
        case .premiumWidgets: return "rectangle.3.group"
        }
    }

    var descriptionText: String {
        switch self {
        case .multipleEntries:
            return NSLocalizedString("premium.feature.multipleEntries.desc", comment: "")
        case .weeklyPlaylist:
            return NSLocalizedString("premium.feature.weeklyPlaylist.desc", comment: "")
        case .circleFeed:
            return NSLocalizedString("premium.feature.circleFeed.desc", comment: "")
        case .monthlySummary:
            return NSLocalizedString("premium.feature.monthlySummary.desc", comment: "")
        case .premiumWidgets:
            return NSLocalizedString("premium.feature.premiumWidgets.desc", comment: "")
        }
    }
}
