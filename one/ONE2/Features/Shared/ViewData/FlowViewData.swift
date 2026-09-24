//
//  FlowViewData.swift
//  ONE 2.0
//
//  Giriş akışlarının view data'sı (06_giris_akislari.md). Ekranlar motor
//  tiplerini değil bunları görür; adımlar veriyle gelir, ekran sabit
//  kodlamaz. Motor bağlaması (UX-11) bu tipleri doldurur.
//

import Foundation

nonisolated enum FlowKind: String, CaseIterable, Hashable, Sendable, Codable, Identifiable {
    case moodCheckIn, daily, morning, evening
    /// Rehberli günlük (pratik karosu); adımları içerikten gelir.
    case guided
    var id: String { rawValue }

    /// Günün ritüelleri ve check-in (06'daki dört akış).
    static let rituals: [FlowKind] = [.moodCheckIn, .daily, .morning, .evening]
}

nonisolated enum FlowStepKind: String, CaseIterable, Hashable, Sendable, Codable {
    case score, emotions, causes, sleep, focus, text, list3, quote, practices, intentionReview

    /// Süre tahmini (06 › Kurallar): yazı adımları 30 sn, diğerleri 10 sn.
    var estimatedSeconds: Int {
        switch self {
        case .text, .list3, .quote: return 30
        default: return 10
        }
    }
}

/// Seçenek: skor etiketi, duygu, neden, odak, pratik, niyet sonucu.
nonisolated struct FlowOptionViewData: Hashable, Sendable, Codable, Identifiable {
    let id: String
    let label: String
    /// Duygu ailesi (`nese`, `huzur`…) ya da SF Symbol (pratik).
    var group: String?

    init(id: String, label: String, group: String? = nil) {
        self.id = id; self.label = label; self.group = group
    }
}

nonisolated struct FlowQuoteViewData: Hashable, Sendable, Codable {
    let id: String
    let text: String
    var attribution: String?
}

nonisolated struct FlowStepViewData: Hashable, Sendable, Codable, Identifiable {
    let id: String
    let kind: FlowStepKind
    /// `title` rolü (sans 24/30).
    let title: String
    /// Soru metni, serif `prompt`.
    var prompt: String?
    var optional: Bool
    var options: [FlowOptionViewData]?
    /// "Geçen sefer şöyle yazmıştın" kutusu (günün sorusu).
    var previousAnswer: String?
    /// `quote` adımının sözü.
    var quote: FlowQuoteViewData?
    /// `false`: varsayılan kapalı ek adım (sabahta duygular); önceki adımdan
    /// tek dokunuşla açılır.
    var isEnabled: Bool

    init(id: String, kind: FlowStepKind, title: String, prompt: String? = nil, optional: Bool,
         options: [FlowOptionViewData]? = nil, previousAnswer: String? = nil,
         quote: FlowQuoteViewData? = nil, isEnabled: Bool = true) {
        self.id = id; self.kind = kind; self.title = title; self.prompt = prompt; self.optional = optional
        self.options = options; self.previousAnswer = previousAnswer; self.quote = quote; self.isEnabled = isEnabled
    }
}

/// Bir adımın cevabı.
nonisolated enum FlowAnswer: Hashable, Sendable, Codable {
    case score(Int)
    /// Duygu / neden ID'leri.
    case choices([String])
    /// Uyku kalitesi 1–5 (0 = seçilmedi) ve isteğe bağlı saat (4–12, 0,5 adım).
    case sleep(score: Int, hours: Double?)
    /// Odak seçeneği ID'si ya da kendi kelimesi (`custom` true).
    case focus(String, custom: Bool)
    case text(String)
    case list([String])
    /// Tamamlanan pratik ID'leri.
    case practices([String])
    /// Niyet sonucu seçeneği ID'si.
    case intention(String)

    /// Adımı "yapılmış" sayar mı (boş metin, boş liste cevap değildir).
    var isMeaningful: Bool {
        switch self {
        case .score, .intention: return true
        case .sleep(let score, let hours): return score > 0 || hours != nil
        case .choices(let ids), .practices(let ids): return !ids.isEmpty
        case .focus(let value, _): return !value.trimmingCharacters(in: .whitespaces).isEmpty
        case .text(let value): return !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .list(let items): return items.contains { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        }
    }
}

/// Yarım kalan akışın taslağı: kapatıp açınca kaldığı adımdan devam eder.
nonisolated struct FlowProgress: Hashable, Sendable, Codable {
    let flow: FlowKind
    var stepIndex: Int = 0
    /// Adım ID'si → cevap.
    var answers: [String: FlowAnswer] = [:]
    /// Kullanıcının açtığı ek adımlar.
    var enabledSteps: Set<String> = []
    /// Kullanıcının eklediği seçenekler (neden etiketi), adım ID'sine göre.
    var addedOptions: [String: [FlowOptionViewData]] = [:]

    init(flow: FlowKind, stepIndex: Int = 0, answers: [String: FlowAnswer] = [:]) {
        self.flow = flow; self.stepIndex = stepIndex; self.answers = answers
    }
}

nonisolated enum FlowSeal: String, Hashable, Sendable, Codable {
    /// Mühürsüz: yalnız yankı, 2 sn ya da dokunuşla kapanır (mood check-in).
    case none
    /// Yarım mühür: gün "half" (sabah).
    case half
    /// Tam mühür: gün "done".
    case full
    /// Tam mühür, günü kapatmaz: "Yazın kaydedildi." (rehberli günlük).
    case saved
}

nonisolated struct FlowClosingViewData: Hashable, Sendable {
    let seal: FlowSeal
    /// Yankı cümlesi (affirmation).
    let echo: String
    /// Kapanıştan sonraki hafta; bugünün hücresi tike döner.
    var week: [WeekDayViewData] = []
    /// Akşam: sabah maddelerinden işaretlenmeyenler ("Yarına taşıyayım mı?").
    var carryOver: [String] = []
}

nonisolated struct FlowViewData: Hashable, Sendable {
    let kind: FlowKind
    let steps: [FlowStepViewData]
    let closing: FlowClosingViewData
}

/// Tamamlanan akışın sonucu; motor bağlaması kaydeder.
/// Uyku saati seçicisinin aralığı (06 › Akış 3).
nonisolated enum SleepHours {
    static let range: ClosedRange<Double> = 4...12
    static let step = 0.5
    static let initial = 7.0

    static func adjusted(_ hours: Double, by delta: Double) -> Double {
        min(range.upperBound, max(range.lowerBound, hours + delta))
    }
}

nonisolated struct FlowResult: Hashable, Sendable {
    let flow: FlowKind
    let answers: [String: FlowAnswer]
    /// Akşam kapanışında "Taşı" (true) / "Bırak" (false); soru yoksa nil.
    var carryOver: Bool?
}

nonisolated enum FlowDuration {
    static func seconds(_ steps: [FlowStepViewData]) -> Int {
        steps.filter(\.isEnabled).map(\.kind.estimatedSeconds).reduce(0, +)
    }

    /// "40 sn", "2 dk" (dakika yukarı yuvarlanır).
    static func label(_ steps: [FlowStepViewData]) -> String {
        let total = seconds(steps)
        if total < 60 {
            return String.localizedStringWithFormat(NSLocalizedString("one2.duration.seconds", comment: "Duration in seconds, mono"), total)
        }
        return String.localizedStringWithFormat(NSLocalizedString("one2.duration.minutes", comment: "Duration in minutes, mono"),
                                                (total + 59) / 60)
    }
}
