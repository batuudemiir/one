//
//  NowPlayingManager.swift
//  one
//
//  Apple Music (MusicKit) ve Spotify'dan anlık çalan şarkıyı birleşik sunar.
//  Önce Apple Music'e bakar, bağlı ve çalıyorsa onu döndürür.
//  Apple Music yoksa Spotify'a düşer.
//

import Foundation
import MusicKit
import Combine
import SwiftUI

// MARK: - Unified Now Playing Track

struct NowPlayingTrack: Equatable {
    let id: String
    let name: String
    let artist: String
    let albumName: String
    let artworkURL: URL?
    let spotifyURL: URL?
    let source: NowPlayingSource
}

enum NowPlayingSource {
    case appleMusic
    case spotify
}

// MARK: - Manager

final class NowPlayingManager: ObservableObject {

    static let shared = NowPlayingManager()

    @Published var currentTrack: NowPlayingTrack? = nil
    @Published var isLoading = false

    private var pollingTask: Task<Void, Never>? = nil
    private var appleMusicObserver: AnyCancellable? = nil
    private var unchangedCount = 0

    private init() {
        Task { @MainActor in
            self.observeAppleMusicState()
        }
    }

    // MARK: - Public

    func startPolling() {
        pollingTask?.cancel()
        unchangedCount = 0
        pollingTask = Task { @MainActor in
            while !Task.isCancelled {
                let oldTrack = self.currentTrack
                await self.refresh()
                // Adaptive backoff: if track hasn't changed, slow down polling
                if self.currentTrack == oldTrack {
                    self.unchangedCount += 1
                } else {
                    self.unchangedCount = 0
                }
                let interval: UInt64 = switch self.unchangedCount {
                case 0...2:  15_000_000_000  // 15s — active change
                case 3...5:  30_000_000_000  // 30s — slowing
                default:     60_000_000_000  // 60s — idle
                }
                try? await Task.sleep(nanoseconds: interval)
            }
        }
    }

    func stopPolling() {
        pollingTask?.cancel()
        pollingTask = nil
    }

    @MainActor
    func refresh() async {
        isLoading = true
        defer { isLoading = false }

        // 1. Apple Music — yetkili ve çalıyor mu?
        if MusicAuthorization.currentStatus == .authorized {
            if let track = await fetchAppleMusicNowPlaying() {
                currentTrack = track
                return
            }
        }

        // 2. Spotify fallback
        if SpotifyManager.shared.isAuthenticated {
            let track = await fetchSpotifyNowPlaying()
            currentTrack = track
        } else {
            currentTrack = nil
        }
    }

    // MARK: - Apple Music

    @MainActor
    private func observeAppleMusicState() {
        // Use MusicKit's built-in state observation instead of non-standard notification
        appleMusicObserver = SystemMusicPlayer.shared.state.objectWillChange
            .debounce(for: .seconds(1), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in
                Task { @MainActor in
                    self?.unchangedCount = 0
                    await self?.refresh()
                }
            }
    }

    @MainActor
    private func fetchAppleMusicNowPlaying() async -> NowPlayingTrack? {
        let player = SystemMusicPlayer.shared
        guard player.state.playbackStatus == .playing,
              let entry = player.queue.currentEntry else {
            return nil
        }

        switch entry.item {
        case .song(let song):
            // Artwork URL'i al
            var artworkURL: URL? = nil
            if let artwork = song.artwork {
                artworkURL = artwork.url(width: 300, height: 300)
            }

            return NowPlayingTrack(
                id: song.id.rawValue,
                name: song.title,
                artist: song.artistName,
                albumName: song.albumTitle ?? "",
                artworkURL: artworkURL,
                spotifyURL: nil,
                source: .appleMusic
            )
        default:
            return nil
        }
    }

    // MARK: - Spotify

    private func fetchSpotifyNowPlaying() async -> NowPlayingTrack? {
        await withCheckedContinuation { continuation in
            SpotifyManager.shared.getNowPlaying { track in
                guard let track else {
                    continuation.resume(returning: nil)
                    return
                }
                let unified = NowPlayingTrack(
                    id: track.id,
                    name: track.name,
                    artist: track.artist,
                    albumName: track.albumName,
                    artworkURL: track.artworkURL,
                    spotifyURL: track.spotifyURL,
                    source: .spotify
                )
                continuation.resume(returning: unified)
            }
        }
    }
}
