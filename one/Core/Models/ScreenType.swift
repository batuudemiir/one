//
//  ScreenType.swift
//  one
//
//  App navigation state types
//

import SwiftUI

// MARK: - App State Context
enum ScreenType {
    case today
    case confirm
    case done
    case archive
    case profile
    case circle
    case echo
    case discover
    // legacy — kept for internal song-search flow within confirm
    case search
}

// MARK: - Mock Data
let mockSongs: [Song] = [
    Song(name: "Last Last", artist: "Burna Boy", genre: "Afrobeats", emoji: "🌍", grad: [ONETokens.moodOrange, Color(hex: "#E8501A")], shadow: ONETokens.moodOrange.opacity(0.45)),
    Song(name: "Ye", artist: "Burna Boy", genre: "Afrobeats", emoji: "🔥", grad: [Color(hex: "#FF6B35"), Color(hex: "#CC3300")], shadow: Color(hex: "#FF6B35").opacity(0.45)),
    Song(name: "Strobe", artist: "deadmau5", genre: "Electronic", emoji: "🌐", grad: [ONETokens.oneBlue, Color(hex: "#2244CC")], shadow: ONETokens.oneBlue.opacity(0.45)),
    Song(name: "Midnight City", artist: "M83", genre: "Synth-pop", emoji: "🌆", grad: [ONETokens.moodPurple, Color(hex: "#5533AA")], shadow: ONETokens.moodPurple.opacity(0.45)),
    Song(name: "Redbone", artist: "Childish Gambino", genre: "Soul", emoji: "🎷", grad: [ONETokens.oneGreen, Color(hex: "#0A7A30")], shadow: ONETokens.oneGreen.opacity(0.45)),
    Song(name: "Blinding Lights", artist: "The Weeknd", genre: "Synth-pop", emoji: "💡", grad: [Color(hex: "#E8334A"), Color(hex: "#AA1020")], shadow: Color(hex: "#E8334A").opacity(0.45)),
    Song(name: "HUMBLE.", artist: "Kendrick Lamar", genre: "Hip-Hop", emoji: "👑", grad: [ONETokens.moodYellow, Color(hex: "#CC8800")], shadow: ONETokens.moodYellow.opacity(0.45)),
    Song(name: "Teardrop", artist: "Massive Attack", genre: "Trip-Hop", emoji: "💧", grad: [ONETokens.moodSlate, Color(hex: "#334455")], shadow: ONETokens.moodSlate.opacity(0.45))
]

let mockArchive: [Color?] = [
    ONETokens.oneRed, ONETokens.oneBlue, ONETokens.oneGreen, ONETokens.oneRed, ONETokens.moodYellow, ONETokens.moodPurple, nil,
    ONETokens.moodOrange, ONETokens.moodSlate, ONETokens.moodDark, nil, ONETokens.oneBlue, ONETokens.oneGreen, ONETokens.moodOrange,
    ONETokens.moodPurple, nil, ONETokens.oneRed, ONETokens.moodOrange, ONETokens.moodYellow, ONETokens.oneBlue
]
