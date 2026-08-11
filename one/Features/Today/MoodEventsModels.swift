//
//  MoodEventsModels.swift
//  one
//
//  Mood event domain types + mood label canonicalization + Ticketmaster DTOs.
//  Extracted from MoodEventsSheet.swift in Faz 3.1 (2026-04-26).
//

import SwiftUI
import Foundation

// MARK: - Mood Label Canonicalization

/// Maps user-entered mood labels (variants, typos, ASCII) to canonical Turkish labels.
/// Used by recommendation engines, UI matchers, and mock data switches.
func canonicalMoodLabel(_ moodLabel: String) -> String {
    switch moodLabel.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
    case "atesli", "tutkulu", "ateş", "ates":
        return "Ateşli"
    case "enerjik", "coşkulu", "coskulu", "heyecanli", "heyecanlı", "canli", "canlı", "enerji":
        return "Coşkulu"
    case "isikli", "ışıklı", "mutlu", "neşeli", "ışık", "isik":
        return "Mutlu"
    case "taze", "doğal", "dogal":
        return "Doğal"
    case "sakin", "huzurlu", "dingin", "huzur":
        return "Huzurlu"
    case "ozgur", "özgür":
        return "Özgür"
    case "derin":
        return "Derin"
    case "nostaljik", "özlem", "ozlem":
        return "Nostaljik"
    case "gizemli", "büyü", "buyu", "loş", "los":
        return "Gizemli"
    case "hassas", "kırılgan", "kirilgan":
        return "Hassas"
    case "bos", "boş", "sessiz", "boşluk", "bosluk":
        return "Sessiz"
    case "temiz", "sade", "notr", "nötr":
        return "Nötr"
    default:
        return moodLabel
    }
}

// MARK: - Event Category

enum EventCategory: String, CaseIterable, Identifiable, Codable {
    case aktivite = "Aktivite"
    case konser   = "Konser"
    case spor     = "Spor"
    case sinema   = "Sinema"
    case tiyatro  = "Tiyatro"
    case sergi    = "Sergi"

    var id: String { rawValue }

    var accentColor: Color {
        switch self {
        case .aktivite: return ONETokens.categoryActivity
        case .konser:  return ONEBrand.kor
        case .spor:    return ONETokens.moodOrange
        case .sinema:  return ONETokens.moodYellow
        case .tiyatro: return ONETokens.moodPurple
        case .sergi:   return ONETokens.oneBlue
        }
    }
}

enum RecommendationKind: String, Equatable, Codable {
    case microActivity
    case liveEvent
    case artistConcert
    case similarConcert
}

// MARK: - Mood Event Model

struct MoodEvent: Identifiable, Codable {
    let id: String
    let category: EventCategory
    let title: String
    let venue: String
    let city: String
    let timing: String
    let price: String
    let matchPercent: Int
    let sourceURL: URL?
    let kind: RecommendationKind
    let reason: String?
    let sourceLabel: String?
    /// true → event is from a nearby-city API fallback, not the user's preferred city
    let isNearbyCity: Bool
    /// true → sourceURL is a Biletix category search page (never 404s)
    ///         false / nil → direct event page (can 404 for minor cities)
    let isFallbackURL: Bool
    /// Parsed event date from Ticketmaster localDate — used for timeline date box UI.
    let eventDate: Date?
    /// Number of attendees going to this event (nil when unavailable).
    let attendeeCount: Int?
    /// Distance from user's location to the venue in kilometres (nil when unavailable).
    let distanceKm: Double?

    init(
        id: String = UUID().uuidString,
        category: EventCategory,
        title: String,
        venue: String,
        city: String,
        timing: String,
        price: String,
        matchPercent: Int,
        sourceURL: URL? = nil,
        kind: RecommendationKind = .liveEvent,
        reason: String? = nil,
        sourceLabel: String? = nil,
        isNearbyCity: Bool = false,
        isFallbackURL: Bool = false,
        eventDate: Date? = nil,
        attendeeCount: Int? = nil,
        distanceKm: Double? = nil
    ) {
        self.id = id
        self.category = category
        self.title = title
        self.venue = venue
        self.city = city
        self.timing = timing
        self.price = price
        self.matchPercent = matchPercent
        self.sourceURL = sourceURL
        self.kind = kind
        self.reason = reason
        self.sourceLabel = sourceLabel
        self.isNearbyCity = isNearbyCity
        self.isFallbackURL = isFallbackURL
        self.eventDate = eventDate
        self.attendeeCount = attendeeCount
        self.distanceKm = distanceKm
    }
}

// MARK: - Ticketmaster API DTOs

struct TMResponse: Decodable {
    let _embedded: TMEmbedded?
}
struct TMEmbedded: Decodable {
    let events: [TMEvent]?
}
struct TMEvent: Decodable {
    let id: String
    let name: String
    let url: String?
    let dates: TMDates?
    let classifications: [TMClassification]?
    let priceRanges: [TMPriceRange]?
    let _embedded: TMEventEmbedded?
}
struct TMDates: Decodable {
    let start: TMStart?
}
struct TMStart: Decodable {
    let localDate: String?
    let localTime: String?
}
struct TMClassification: Decodable {
    let segment: TMSegment?
    let genre: TMSegment?
    let subGenre: TMSegment?
}
struct TMSegment: Decodable {
    let name: String?
}
struct TMPriceRange: Decodable {
    let min: Double?
    let max: Double?
    let currency: String?
}
struct TMEventEmbedded: Decodable {
    let venues: [TMVenue]?
}
struct TMVenue: Decodable {
    let name: String?
    let city: TMCity?
    let location: TMLocation?
}

struct TMLocation: Decodable {
    let longitude: String?
    let latitude: String?
}
struct TMCity: Decodable {
    let name: String?
}
