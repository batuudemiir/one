//
//  ONE2Event.swift
//  ONE 2.0
//
//  Analitik olay kataloğu v2 (04_arka_plan_motorlari.md › E17). PostHog
//  altyapısı korunur: olaylar `AnalyticsEvent.one2(_:)` üzerinden mevcut
//  `AppAnalytics` dağıtıcısına gider.
//
//  Kural: metin içeriği **asla** gönderilmez. Özellikler yalnız kimlik
//  (içerik ID'si, rozet ID'si), sayı, aralık ya da sabit küme değerleri.
//  Kelime sayısı bile tam değil aralık olarak gider.
//

import Foundation

nonisolated enum ONE2Event: Equatable, Sendable {
    // Onboarding
    case onboardingStep(step: String)
    case onboardingDone(focusCount: Int, pathCount: Int, ritualMode: RitualMode)
    // Ritüel
    case checkInDone(score: Int, emotionCount: Int, causeCount: Int)
    case ritualDone(kind: RitualCard)
    case dayCompleted(by: DayCompletionSource, backfilled: Bool)
    // Yazma
    case entrySaved(kind: EntryKind, words: Int, source: EntrySource?)
    case comparisonShown(promptRef: String)
    // Sözler
    case quoteSeen(count: Int, mode: String)
    case quoteLiked(quoteID: String)
    case quoteWriteTap(quoteID: String)
    case contentPoolLow(mode: String, remaining: Int)
    // Seri / rozet
    case streakBroken(length: Int)
    case backfillUsed(daysBack: Int)
    case badgeAwarded(badgeID: String, announced: Bool)
    // Premium
    case paywallShown(source: String)
    case trialStarted(productID: String)
    case purchase(productID: String)
    // Sağlık
    case themeMissingNextWeek(week: String)
    case contentUpdateFailed(reason: String)

    var name: String {
        switch self {
        case .onboardingStep: return "one2_onboarding_step"
        case .onboardingDone: return "one2_onboarding_done"
        case .checkInDone: return "one2_checkin_done"
        case .ritualDone: return "one2_ritual_done"
        case .dayCompleted: return "one2_day_completed"
        case .entrySaved: return "one2_entry_saved"
        case .comparisonShown: return "one2_comparison_shown"
        case .quoteSeen: return "one2_quote_seen"
        case .quoteLiked: return "one2_quote_liked"
        case .quoteWriteTap: return "one2_quote_write_tap"
        case .contentPoolLow: return "content_pool_low"
        case .streakBroken: return "one2_streak_broken"
        case .backfillUsed: return "one2_backfill_used"
        case .badgeAwarded: return "one2_badge_awarded"
        case .paywallShown: return "one2_paywall_shown"
        case .trialStarted: return "one2_trial_started"
        case .purchase: return "one2_purchase"
        case .themeMissingNextWeek: return "theme_missing_next_week"
        case .contentUpdateFailed: return "content_update_failed"
        }
    }

    /// Yalnız ID, sayı, aralık ve sabit küme değerleri.
    var properties: [String: Sendable] {
        switch self {
        case .onboardingStep(let step): return ["step": step]
        case .onboardingDone(let focus, let paths, let mode):
            return ["focus_count": focus, "path_count": paths, "ritual_mode": mode.rawValue]
        case .checkInDone(let score, let emotions, let causes):
            return ["score": score, "emotion_count": emotions, "cause_count": causes]
        case .ritualDone(let kind): return ["kind": kind.rawValue]
        case .dayCompleted(let by, let backfilled): return ["by": by.rawValue, "backfilled": backfilled]
        case .entrySaved(let kind, let words, let source):
            return ["kind": kind.rawValue, "word_range": Self.wordRange(words), "source": source?.rawValue ?? "none"]
        case .comparisonShown(let ref): return ["prompt_ref": ref]
        case .quoteSeen(let count, let mode): return ["count": count, "mode": mode]
        case .quoteLiked(let id): return ["quote_id": id]
        case .quoteWriteTap(let id): return ["quote_id": id]
        case .contentPoolLow(let mode, let remaining): return ["mode": mode, "remaining": remaining]
        case .streakBroken(let length): return ["length": length]
        case .backfillUsed(let days): return ["days_back": days]
        case .badgeAwarded(let id, let announced): return ["badge_id": id, "announced": announced]
        case .paywallShown(let source): return ["source": source]
        case .trialStarted(let product): return ["product_id": product]
        case .purchase(let product): return ["product_id": product]
        case .themeMissingNextWeek(let week): return ["week": week]
        case .contentUpdateFailed(let reason): return ["reason": reason]
        }
    }

    /// Kelime sayısı aralığı; tam sayı gönderilmez.
    static func wordRange(_ words: Int) -> String {
        switch words {
        case ..<1: return "0"
        case ..<20: return "1-19"
        case ..<50: return "20-49"
        case ..<100: return "50-99"
        case ..<250: return "100-249"
        default: return "250+"
        }
    }

    /// `ContentUpdateResult` → hata olayı nedeni (metin değil, sabit küme).
    static func updateFailureReason(_ result: ContentUpdateResult) -> String? {
        switch result {
        case .failed: return "network"
        case .rejected(let error):
            switch error {
            case .missingManifest: return "missing_manifest"
            case .unsupportedSchema: return "unsupported_schema"
            case .missingFile: return "missing_file"
            case .hashMismatch: return "hash_mismatch"
            case .corrupt: return "corrupt"
            case .duplicateIDs: return "duplicate_ids"
            }
        case .updated, .upToDate, .skipped: return nil
        }
    }
}

/// Huni tanımları (dashboard için sözleşme).
nonisolated enum ONE2Funnels {
    /// Kurulum → ilk check-in → ilk yazı → 7. gün dönüş (dönüş PostHog tarafında hesaplanır).
    static let activation = ["one2_onboarding_done", "one2_checkin_done", "one2_entry_saved"]
    /// Sözler kartı → yaz dokunuşu → kaydedilen yazı (`source = quote`).
    static let quoteToWriting = ["one2_quote_seen", "one2_quote_write_tap", "one2_entry_saved"]
}

/// ONE 2.0'ın analitik girişi; `AppAnalytics.shared` protokol arkasında (ADR §4).
protocol EventTracking: AnyObject {
    func track(_ event: ONE2Event)
}

final class AppAnalyticsTracker: EventTracking {
    func track(_ event: ONE2Event) {
        AppAnalytics.shared.track(.one2(event))
    }
}

/// Testler ve önizlemeler için.
final class RecordingTracker: EventTracking {
    private(set) var events: [ONE2Event] = []
    func track(_ event: ONE2Event) { events.append(event) }
}
