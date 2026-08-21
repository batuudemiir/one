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
