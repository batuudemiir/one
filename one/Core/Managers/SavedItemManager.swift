//
//  SavedItemManager.swift
//  one
//
//  Manages saving and retrieving MoodEvents and SongRecommendations to local UserDefaults.
//

import Foundation
import Combine

class SavedItemManager: ObservableObject {
    static let shared = SavedItemManager()

    @Published var savedEvents: [MoodEvent] = []
    @Published var savedSongs: [SongRecommendation] = []

    private let eventsKey = "one_saved_events"
    private let songsKey = "one_saved_songs"

    private init() {
        loadEvents()
        loadSongs()
    }

    // MARK: - Events

    func saveEvent(_ event: MoodEvent) {
        if !savedEvents.contains(where: { $0.id == event.id }) {
            savedEvents.insert(event, at: 0)
            persistEvents()
            ONELogger.success("Event saved: \(event.title)", category: .general)
        }
    }

    func removeEvent(_ eventId: String) {
        savedEvents.removeAll { $0.id == eventId }
        persistEvents()
        ONELogger.success("Event removed: \(eventId)", category: .general)
    }

    func isEventSaved(_ eventId: String) -> Bool {
        savedEvents.contains { $0.id == eventId }
    }

    private func loadEvents() {
        if let data = UserDefaults.standard.data(forKey: eventsKey),
           let events = try? JSONDecoder().decode([MoodEvent].self, from: data) {
            self.savedEvents = events
        }
    }

    private func persistEvents() {
        if let data = try? JSONEncoder().encode(savedEvents) {
            UserDefaults.standard.set(data, forKey: eventsKey)
        }
    }

    // MARK: - Songs

    func saveSong(_ song: SongRecommendation) {
        if !savedSongs.contains(where: { $0.id == song.id }) {
            savedSongs.insert(song, at: 0)
            persistSongs()
            ONELogger.success("Song saved: \(song.name)", category: .general)
        }
    }

    func removeSong(_ songId: String) {
        savedSongs.removeAll { $0.id == songId }
        persistSongs()
        ONELogger.success("Song removed: \(songId)", category: .general)
    }

    func isSongSaved(_ songId: String) -> Bool {
        savedSongs.contains { $0.id == songId }
    }

    private func loadSongs() {
        if let data = UserDefaults.standard.data(forKey: songsKey),
           let songs = try? JSONDecoder().decode([SongRecommendation].self, from: data) {
            self.savedSongs = songs
        }
    }

    private func persistSongs() {
        if let data = try? JSONEncoder().encode(savedSongs) {
            UserDefaults.standard.set(data, forKey: songsKey)
        }
    }
}
