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
        MoodOption(key: "atesli",    color: ONETokens.oneRed,     label: NSLocalizedString("mood.atesli",    comment: "")),
        MoodOption(key: "enerjik",   color: ONETokens.moodOrange, label: NSLocalizedString("mood.enerjik",   comment: "")),
        MoodOption(key: "isikli",    color: ONETokens.moodYellow, label: NSLocalizedString("mood.isikli",    comment: "")),
        MoodOption(key: "taze",      color: ONETokens.moodLime,   label: NSLocalizedString("mood.taze",      comment: "")),
        MoodOption(key: "sakin",     color: ONETokens.oneGreen,   label: NSLocalizedString("mood.sakin",     comment: "")),
        MoodOption(key: "ozgur",     color: ONETokens.moodTeal,   label: NSLocalizedString("mood.ozgur",     comment: "")),
        MoodOption(key: "derin",     color: ONETokens.oneBlue,    label: NSLocalizedString("mood.derin",     comment: "")),
        MoodOption(key: "nostaljik", color: ONETokens.moodIndigo, label: NSLocalizedString("mood.nostaljik", comment: "")),
        MoodOption(key: "gizemli",   color: ONETokens.moodPurple, label: NSLocalizedString("mood.gizemli",   comment: "")),
        MoodOption(key: "hassas",    color: ONETokens.moodRose,   label: NSLocalizedString("mood.hassas",    comment: "")),
        MoodOption(key: "bos",       color: ONETokens.moodDark,   label: NSLocalizedString("mood.bos",       comment: "")),
        MoodOption(key: "temiz",     color: ONETokens.oneIvory,   label: NSLocalizedString("mood.temiz",     comment: "")),
    ]
}

// MARK: - Feeling Option
struct FeelingOption: Identifiable {
    let id = UUID()
    let type: FeelingType
    let label: String

    static let all: [FeelingOption] = [
        FeelingOption(type: .calm,     label: NSLocalizedString("feeling.calm",     comment: "")),
        FeelingOption(type: .happy,    label: NSLocalizedString("feeling.happy",    comment: "")),
        FeelingOption(type: .sad,      label: NSLocalizedString("feeling.sad",      comment: "")),
        FeelingOption(type: .anxious,  label: NSLocalizedString("feeling.anxious",  comment: "")),
        FeelingOption(type: .excited,  label: NSLocalizedString("feeling.excited",  comment: "")),
        FeelingOption(type: .tired,    label: NSLocalizedString("feeling.tired",    comment: "")),
        FeelingOption(type: .angry,    label: NSLocalizedString("feeling.angry",    comment: "")),
        FeelingOption(type: .peaceful, label: NSLocalizedString("feeling.peaceful", comment: "")),
    ]
}

// ONEToggleStyle now provided by DesignSystem/ONEToggleStyle.swift
