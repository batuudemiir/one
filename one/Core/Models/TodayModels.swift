//
//  TodayModels.swift
//  One - Günlük Mood
//

import SwiftUI
import PhotosUI

// MARK: - Today State
enum TodayState {
    case empty
    case completed
}

// MARK: - Song Result (for search)
struct SongResult: Identifiable, Codable {
    let id: UUID
    let name: String
    let artist: String
    let genre: String
    let coverURL: URL?
    let spotifyURL: URL?
    let artworkURLString: String?
    var previewURL: URL? = nil
}

// MARK: - Mood Option
struct MoodOption: Identifiable {
    let id = UUID()
    let key: String       // matches ONEMood rawValue
    let color: Color
    let label: String     // elemental name (ateş, ışık, …)
    let meaning: String   // feeling word (tutkulu, mutlu, …)

    /// 8 moods — v2.5 palette (4 columns × 2 rows)
    // NOT: Lokalizasyon iptal — mood etiketleri cihaz dilinden bağımsız her zaman Türkçe.
    // Sebep: en.lproj'da label çevrildi ama meaning çevrilmedi → İngilizce cihazda
    // "FIRE / tutkulu" gibi karışık görünüyordu. TR-first ICP için sabitlendi.
    static let all: [MoodOption] = [
        MoodOption(key: "atesli",    color: ONETokens.moodTutkulu, label: "tutkulu",   meaning: "içim yanıyor"),
        MoodOption(key: "isikli",    color: ONETokens.moodYellow,  label: "mutlu",     meaning: "içimden parlıyor"),
        MoodOption(key: "enerjik",   color: ONETokens.moodOrange,  label: "enerjik",   meaning: "taşıp duruyor"),
        MoodOption(key: "taze",      color: ONETokens.moodLime,    label: "doğal",     meaning: "yeni başlıyor"),
        MoodOption(key: "sakin",     color: ONETokens.moodHuzurlu, label: "huzurlu",   meaning: "her şey yolunda"),
        MoodOption(key: "nostaljik", color: ONETokens.moodExcited, label: "heyecanlı", meaning: "coşkuyla doluyum"),
        MoodOption(key: "ozgur",     color: ONETokens.moodTeal,    label: "sakin",     meaning: "hafif, dingin"),
        MoodOption(key: "derin",     color: ONETokens.moodStabil,  label: "stabil",    meaning: "dengede, sabit"),
        MoodOption(key: "uzgun",     color: ONETokens.moodIndigo,  label: "üzgün",     meaning: "içim sıkışmış"),
        MoodOption(key: "stresli",   color: ONETokens.moodStress,  label: "stresli",   meaning: "altında eziliyorum"),
        MoodOption(key: "yorgun",    color: ONETokens.moodSlate,   label: "yorgun",    meaning: "bitkin, tükenmişim"),
        MoodOption(key: "sinirli",   color: ONETokens.moodAngry,   label: "sinirli",   meaning: "içimde fırtına var"),
    ]
}

// MARK: - Feeling Option
struct FeelingOption: Identifiable {
    let id = UUID()
    let type: FeelingType
    let label: String

    /// v2.5 — 8 yeni feeling seçeneği
    static let all: [FeelingOption] = [
        FeelingOption(type: .chill,           label: "Chill"),
        FeelingOption(type: .overthink,       label: "Overthink"),
        FeelingOption(type: .hype,            label: "Hype"),
        FeelingOption(type: .manifest,        label: "Manifest"),
        FeelingOption(type: .happierThanEver, label: "Happier than ever"),
        FeelingOption(type: .sad,             label: "Sad"),
        FeelingOption(type: .dance,           label: "Dance"),
        FeelingOption(type: .alone,           label: "Alone"),
    ]
}

// ONEToggleStyle now provided by DesignSystem/ONEToggleStyle.swift
