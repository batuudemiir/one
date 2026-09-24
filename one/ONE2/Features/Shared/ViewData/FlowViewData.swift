//
//  FlowViewData.swift
//  ONE 2.0
//
//  Giriş akışları (07 §5.2): mood check-in, günlük check-in, sabah
//  hazırlığı, akşam değerlendirmesi. Adımlar veriyle tanımlanır; ekran adım
//  sırasını ya da metnini sabit kodlamaz. Her adım bitince taslak kaydedilir
//  (`FlowDraftData`); kapatınca kart "Devam et · n/m" olur.
//

import Foundation

nonisolated enum FlowKind: String, CaseIterable, Hashable, Sendable {
    /// Akış 1: ~30 sn; açılışta, + menüsünde, widget'ta.
    case moodCheckIn
    /// Akış 2: günlük mod, ~2 dk.
    case dailyCheckIn
    /// Akış 3: sabah hazırlığı, ~2 dk.
    case morning
    /// Akış 4: akşam değerlendirmesi, ~3 dk.
    case evening
}

/// 07 §5.2 adım türleri.
nonisolated enum FlowStepKind: String, CaseIterable, Hashable, Sendable {
    case score, emotions, causes, sleep, focus, text, list3, quote, practices, intentionReview
}

/// Seçenekli adımların öğesi (neden etiketi, odak, uyku süresi).
nonisolated struct FlowOptionData: Identifiable, Hashable, Sendable {
    let id: String
    let title: String
    /// "+ Ekle" / "+ Kendi kelimen" satırı.
    var isCustomEntry = false
}

/// Aynı soruya daha önceki cevap ("Geçen sefer şöyle yazmıştın: …").
nonisolated struct PreviousAnswerData: Equatable, Sendable {
    let date: Date
    let text: String
}

/// Akış adımı. 07 §5.2: `{ id, kind, title, prompt?, optional, options? }`;
/// türe özgü ek alanlar isteğe bağlı.
nonisolated struct FlowStepViewData: Identifiable, Equatable, Sendable {
    let id: String
    let kind: FlowStepKind
    /// Adım başlığı (`title`).
    let title: String
    /// Soru metni (Literata `prompt`); yoksa yalnız başlık.
    let prompt: String?
    /// `true`: "Atla" görünür. `score` hiçbir zaman isteğe bağlı değil.
    let optional: Bool
    let options: [FlowOptionData]?
    /// `text`: aynı soruya önceki cevap.
    var previous: PreviousAnswerData? = nil
    /// `quote`: günün sözü (küçük QuoteCard).
    var quote: QuoteCardData? = nil
    /// `practices`: bugünkü pratikler (Bugün'deki işaretlerle senkron).
    var practices: [PracticeTileData]? = nil
    /// `emotions`: duygu kataloğu, aile sırasıyla (E1 katalog).
    var emotions: [EmotionItem]? = nil
}

/// Adım cevabı. Taslakta adım kimliğiyle saklanır.
nonisolated enum FlowAnswerData: Equatable, Sendable {
    case score(Int)
    /// Duygu ID'leri (`<aile>.<ad>`).
    case emotions([String])
    case causes([String])
    /// Uyku 1–5 + isteğe bağlı süre (saat, 0,5 adım).
    case sleep(score: Int, hours: Double?)
    case focus(String)
    case text(String)
    /// En fazla üç madde; boşlar atılır.
    case list3([String])
    /// Pratik ID → bugün yapıldı mı.
    case practices([String: Bool])
    case intentionReview(IntentionOutcome)
}

/// Akşam "Sabah '{odak}' demiştin. Nasıl gitti?"
nonisolated enum IntentionOutcome: String, CaseIterable, Hashable, Sendable {
    case kept, partly, notKept
}

/// Yarıda bırakılan akış. Gece yarısı geçerse o güne kaydedilir.
nonisolated struct FlowDraftData: Equatable, Sendable {
    let day: DayKey
    /// Kaldığı adımın sırası (0'dan); kartta "Devam et · (n+1)/m".
    let stepIndex: Int
    let answers: [String: FlowAnswerData]
    let updatedAt: Date
}

/// Akış sonu (07 §5.2, §5.5).
nonisolated enum FlowClosingKind: Equatable, Sendable {
    /// Akış 1: mühürsüz yankı ekranı; ilk check-in'de `seal(.firstDay)`.
    case echo
    case seal(SealKind)
}

/// Mühür metni (07 §8 Kapanış): "bugün kapandı." · "gün hazır." ·
/// "yazın kaydedildi." · ilk gün "Bugün başladı."
nonisolated enum SealKind: String, Hashable, Sendable {
    case dayClosed, dayReady, entrySaved, firstDay
    /// Sabah akışı yarım mühür.
    var isHalf: Bool { self == .dayReady }
}

/// Bir akışın tamamı.
nonisolated struct FlowViewData: Identifiable, Equatable, Sendable {
    let id: String
    let kind: FlowKind
    let day: DayKey
    let steps: [FlowStepViewData]
    let closing: FlowClosingKind
    /// Kart ve başlangıç için mono süre ("2 dk").
    let minutes: Int
    /// Varsa akış bu adımdan devam eder.
    let draft: FlowDraftData?
    /// Kapanışta tek cümle yankı (E6); motor kayıttan sonra üretir.
    var echo: String? = nil
    /// Akşam: sabah `list3`'te işaretlenmemiş maddeler ("Yarına taşıyayım mı?").
    var carryOver: [String] = []

    var startIndex: Int { min(draft?.stepIndex ?? 0, max(steps.count - 1, 0)) }
}
