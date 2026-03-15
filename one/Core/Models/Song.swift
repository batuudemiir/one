//
//  Song.swift
//  one
//
//  Song model used throughout the app
//

import SwiftUI

// MARK: - Song Model
struct Song: Identifiable {
    let id = UUID()
    let name: String
    let artist: String
    let genre: String
    let emoji: String
    let grad: [Color]
    let shadow: Color
    var artworkURL: URL? = nil
}

// MARK: - Mood Model (Legacy persistence format)
struct Mood: Identifiable {
    let id = UUID()
    let color: Color
    let word: String
    let isDark: Bool
}
