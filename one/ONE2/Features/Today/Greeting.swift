//
//  Greeting.swift
//  ONE 2.0
//
//  Bugün'ün selamlaması saate göre: 05–12 "günaydın", 12–18 "iyi günler",
//  diğer saatler "iyi akşamlar". Küçük harf, noktasız.
//

import Foundation

nonisolated enum Greeting: Equatable, Sendable {
    case morning, day, evening

    static func at(_ date: Date, calendar: Calendar) -> Greeting {
        switch calendar.component(.hour, from: date) {
        case 5..<12:  return .morning
        case 12..<18: return .day
        default:      return .evening
        }
    }

    var text: String {
        switch self {
        case .morning: return one2String("one2.greeting.morning")
        case .day:     return one2String("one2.greeting.day")
        case .evening: return one2String("one2.greeting.evening")
        }
    }
}
