//
//  EventCache.swift
//  one
//
//  Caches mood-matched event recommendations to UserDefaults.
//  Cache is keyed by (moodColorHex + moodLabel + date) and expires daily —
//  events are city/date specific so there's no value in keeping them past midnight.
//

import Foundation

class EventCache {

    private let cacheKey = "cached_mood_events_v1"
    /// Events are day-specific; expire after 24 hours to guarantee freshness at midnight.
    private let maxAge: TimeInterval = 86_400

    // MARK: - Codable container

    private struct Cached: Codable {
        let events: [MoodEvent]
        let moodKey: String   // "\(moodColorHex)_\(moodLabel)_\(city)"
        let dateKey: String   // "yyyy-MM-dd"
        let timestamp: Date

        func isValid(maxAge: TimeInterval, moodKey: String, dateKey: String) -> Bool {
            guard self.moodKey == moodKey, self.dateKey == dateKey else { return false }
            return Date().timeIntervalSince(timestamp) < maxAge
        }
    }

    // MARK: - Save

    func save(_ events: [MoodEvent], moodColorHex: String, moodLabel: String, city: String) {
        let cached = Cached(
            events: events,
            moodKey: cacheKey(hex: moodColorHex, label: moodLabel, city: city),
            dateKey: todayString(),
            timestamp: Date()
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(cached) else {
            ONELogger.error("EventCache: encode failed", category: .discovery)
            return
        }
        UserDefaults.standard.set(data, forKey: cacheKey)
        ONELogger.success("EventCache: cached \(events.count) events", category: .discovery)
    }

    // MARK: - Load

    func get(moodColorHex: String, moodLabel: String, city: String) -> [MoodEvent]? {
        guard let data = UserDefaults.standard.data(forKey: cacheKey) else { return nil }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let cached = try? decoder.decode(Cached.self, from: data) else {
            clear()
            return nil
        }

        let key  = cacheKey(hex: moodColorHex, label: moodLabel, city: city)
        let date = todayString()
        guard cached.isValid(maxAge: maxAge, moodKey: key, dateKey: date) else {
            clear()
            return nil
        }

        ONELogger.success("EventCache: loaded \(cached.events.count) events from cache", category: .discovery)
        return cached.events
    }

    // MARK: - Clear

    func clear() {
        UserDefaults.standard.removeObject(forKey: cacheKey)
        ONELogger.debug("EventCache: cleared", category: .discovery)
    }

    // MARK: - Helpers

    private func cacheKey(hex: String, label: String, city: String) -> String { "\(hex)_\(label)_\(city)" }

    private func todayString() -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: Date())
    }
}
