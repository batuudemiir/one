//
//  Badge.swift
//  one
//
//  Badge catalog + metadata
//

import Foundation

enum BadgeID: String, CaseIterable, Codable {
    case firstShare       = "first_share"
    case streak7          = "streak_7"
    case streak30         = "streak_30"
    case streak100        = "streak_100"
    case firstFriend      = "first_friend"
    case fiveFriends      = "five_friends"
    case monthlyPoster    = "monthly_poster_share"
}

struct Badge: Identifiable, Hashable {
    let id: BadgeID
    let iconSystemName: String
    let titleKey: String
    let descriptionKey: String

    var title: String { NSLocalizedString(titleKey, comment: "") }
    var description: String { NSLocalizedString(descriptionKey, comment: "") }
}

enum BadgeCatalog {
    static let all: [Badge] = [
        Badge(id: .firstShare,
              iconSystemName: "paperplane",
              titleKey: "badges.firstShare.title",
              descriptionKey: "badges.firstShare.desc"),
        Badge(id: .streak7,
              iconSystemName: "flame",
              titleKey: "badges.streak7.title",
              descriptionKey: "badges.streak7.desc"),
        Badge(id: .streak30,
              iconSystemName: "flame.fill",
              titleKey: "badges.streak30.title",
              descriptionKey: "badges.streak30.desc"),
        Badge(id: .streak100,
              iconSystemName: "star.circle.fill",
              titleKey: "badges.streak100.title",
              descriptionKey: "badges.streak100.desc"),
        Badge(id: .firstFriend,
              iconSystemName: "person.2",
              titleKey: "badges.firstFriend.title",
              descriptionKey: "badges.firstFriend.desc"),
        Badge(id: .fiveFriends,
              iconSystemName: "person.3.fill",
              titleKey: "badges.fiveFriends.title",
              descriptionKey: "badges.fiveFriends.desc"),
        Badge(id: .monthlyPoster,
              iconSystemName: "square.grid.2x2",
              titleKey: "badges.monthlyPoster.title",
              descriptionKey: "badges.monthlyPoster.desc")
    ]

    static func badge(for id: BadgeID) -> Badge {
        all.first { $0.id == id } ?? all[0]
    }
}
