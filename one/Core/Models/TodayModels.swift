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
struct SongResult: Identifiable {
    let id: UUID
    let name: String
    let artist: String
    let genre: String
    let coverURL: URL?
    let spotifyURL: URL?
    let artworkURLString: String?
}

// MARK: - Mood Option
struct MoodOption: Identifiable {
    let id = UUID()
    let key: String       // matches ONEMood rawValue
    let color: Color
    let label: String

    /// 12 moods arranged by color-psychology spectrum (4 columns × 3 rows)
    /// Row 1 — warm:    Ateşli · Coşkulu · Mutlu  · Taze
    /// Row 2 — cool:    Huzurlu · Özgür  · Derin  · Nostaljik
    /// Row 3 — deep:    Gizemli · Hassas · Sessiz · Sade
    static let all: [MoodOption] = [
        MoodOption(key: "atesli",    color: ONETokens.oneRed,     label: "Ateşli"),
        MoodOption(key: "enerjik",   color: ONETokens.moodOrange, label: "Coşkulu"),
        MoodOption(key: "isikli",    color: ONETokens.moodYellow, label: "Mutlu"),
        MoodOption(key: "taze",      color: ONETokens.moodLime,   label: "Doğal"),
        MoodOption(key: "sakin",     color: ONETokens.oneGreen,   label: "Huzurlu"),
        MoodOption(key: "ozgur",     color: ONETokens.moodTeal,   label: "Özgür"),
        MoodOption(key: "derin",     color: ONETokens.oneBlue,    label: "Derin"),
        MoodOption(key: "nostaljik", color: ONETokens.moodIndigo, label: "Nostaljik"),
        MoodOption(key: "gizemli",   color: ONETokens.moodPurple, label: "Gizemli"),
        MoodOption(key: "hassas",    color: ONETokens.moodRose,   label: "Hassas"),
        MoodOption(key: "bos",       color: ONETokens.moodDark,   label: "Sessiz"),
        MoodOption(key: "temiz",     color: ONETokens.oneIvory,   label: "Nötr"),
    ]
}

// MARK: - Feeling Option
struct FeelingOption: Identifiable {
    let id = UUID()
    let type: FeelingType
    let label: String

    static let all: [FeelingOption] = [
        FeelingOption(type: .calm,     label: "Dingin"),
        FeelingOption(type: .happy,    label: "Neşeli"),
        FeelingOption(type: .sad,      label: "Buruk"),
        FeelingOption(type: .anxious,  label: "Tedirgin"),
        FeelingOption(type: .excited,  label: "Coşkulu"),
        FeelingOption(type: .tired,    label: "Durgun"),
        FeelingOption(type: .angry,    label: "Asi"),
        FeelingOption(type: .peaceful, label: "Huzurlu"),
    ]
}

// ONEToggleStyle now provided by DesignSystem/ONEToggleStyle.swift
