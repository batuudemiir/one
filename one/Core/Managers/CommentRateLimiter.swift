//
//  CommentRateLimiter.swift
//  one
//
//  v2.5 — Yorum spam / flood önlemi. Tamamen local; CloudKit'e istek
//  göndermeden önce `check()` ile karar verilir, başarılı gönderim sonrası
//  `record()` ile timestamp kaydedilir.
//
//  Kurallar (ONE için dengeli):
//    - İki yorum arasında min 3 saniye
//    - Dakikada en fazla 5 yorum
//    - Saatte en fazla 30 yorum
//    - Günde en fazla 120 yorum
//
//  Timestamp'ler App Group UserDefaults'da ring buffer (son 200) olarak
//  tutulur — limit'ler son N saniyeye bakarak hesaplanır.
//
//  NOT: Bu rate limiter tamamen client-side'dır. Jailbreak veya UserDefaults
//  temizleme ile bypass edilebilir. Yüksek hacimli spam için server-side
//  (CloudKit Functions veya proxy) enforcement gereklidir.
//

import Foundation
import Combine

enum RateLimitDecision: Equatable {
    case allow
    case deny(reason: String, retryAfter: TimeInterval)

    var isAllowed: Bool {
        if case .allow = self { return true }
        return false
    }
}

final class CommentRateLimiter {
    static let shared = CommentRateLimiter()

    // MARK: Config
    private let minInterval: TimeInterval = 3
    private let perMinuteLimit: Int = 5
    private let perHourLimit: Int = 30
    private let perDayLimit: Int = 120
    private let bufferSize: Int = 200

    // MARK: Storage
    private let defaultsKey = "comment_rate_limiter_timestamps"
    private let defaults: UserDefaults

    private init() {
        // App Group — extension'lar ve ana app aynı limitte olsun
        self.defaults = UserDefaults(suiteName: "group.com.batudemir.ones") ?? .standard
    }

    // MARK: Public API

    /// Yorum göndermeden önce çağır. `.deny` dönerse UI'da retryAfter süresi boyunca beklet.
    func check(now: Date = Date()) -> RateLimitDecision {
        let timestamps = loadTimestamps()

        // 1. Min interval
        if let last = timestamps.last {
            let gap = now.timeIntervalSince(last)
            if gap < minInterval {
                return .deny(reason: "Biraz yavaşla — 3 saniye ara ver.", retryAfter: minInterval - gap)
            }
        }

        // 2. Per-minute
        let lastMinute = timestamps.filter { now.timeIntervalSince($0) < 60 }
        if lastMinute.count >= perMinuteLimit {
            let oldestInWindow = lastMinute.first ?? now
            let retry = max(1, 60 - now.timeIntervalSince(oldestInWindow))
            return .deny(reason: "Dakikada en fazla \(perMinuteLimit) yorum yazabilirsin.", retryAfter: retry)
        }

        // 3. Per-hour
        let lastHour = timestamps.filter { now.timeIntervalSince($0) < 3600 }
        if lastHour.count >= perHourLimit {
            let oldestInWindow = lastHour.first ?? now
            let retry = max(60, 3600 - now.timeIntervalSince(oldestInWindow))
            return .deny(reason: "Saatte en fazla \(perHourLimit) yorum.", retryAfter: retry)
        }

        // 4. Per-day
        let lastDay = timestamps.filter { now.timeIntervalSince($0) < 86400 }
        if lastDay.count >= perDayLimit {
            let oldestInWindow = lastDay.first ?? now
            let retry = max(600, 86400 - now.timeIntervalSince(oldestInWindow))
            return .deny(reason: "Günlük yorum limitine ulaştın.", retryAfter: retry)
        }

        return .allow
    }

    /// Başarılı gönderim sonrası çağır.
    func record(now: Date = Date()) {
        var timestamps = loadTimestamps()
        timestamps.append(now)
        // Ring buffer + 24h'ten eskileri at
        let cutoff = now.addingTimeInterval(-86400)
        timestamps = timestamps.filter { $0 >= cutoff }
        if timestamps.count > bufferSize {
            timestamps = Array(timestamps.suffix(bufferSize))
        }
        saveTimestamps(timestamps)
    }

    /// Debug / hesap silme sonrası sıfırla.
    func reset() {
        defaults.removeObject(forKey: defaultsKey)
    }

    // MARK: Storage helpers

    private func loadTimestamps() -> [Date] {
        guard let raw = defaults.array(forKey: defaultsKey) as? [TimeInterval] else { return [] }
        return raw.map { Date(timeIntervalSince1970: $0) }.sorted()
    }

    private func saveTimestamps(_ dates: [Date]) {
        let raw = dates.map { $0.timeIntervalSince1970 }
        defaults.set(raw, forKey: defaultsKey)
    }
}
