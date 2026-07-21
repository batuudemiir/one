//
//  SongPreviewPlayer.swift
//  one
//

import AVFoundation
import Combine
import MediaPlayer
import SwiftUI

@MainActor
final class SongPreviewPlayer: ObservableObject {
    static let shared = SongPreviewPlayer()

    @Published var playingID: UUID?
    @Published var loadingID: UUID?
    private var player: AVPlayer?
    private var endObserver: Any?
    private var currentSong: SongResult?
    private var previewTask: Task<Void, Never>?

    // MARK: - Public

    func toggle(_ song: SongResult) {
        if playingID == song.id || loadingID == song.id {
            stop()
            return
        }
        stop()
        previewTask = Task { await fetchAndPlay(song) }
    }

    func stop() {
        previewTask?.cancel()
        previewTask = nil
        player?.pause()
        if let obs = endObserver {
            NotificationCenter.default.removeObserver(obs)
            endObserver = nil
        }
        player = nil
        currentSong = nil
        clearNowPlaying()
        withAnimation(.easeOut(duration: 0.15)) {
            playingID = nil
            loadingID = nil
        }
    }

    // MARK: - Fetch + Play

    private func fetchAndPlay(_ song: SongResult) async {
        guard !Task.isCancelled else { return }
        currentSong = song

        // 1. Use MusicKit URL if available
        if let url = song.previewURL {
            guard !Task.isCancelled else { return }
            startPlayback(id: song.id, url: url)
            return
        }

        // 2. iTunes Search API fallback — no auth required
        withAnimation(.easeOut(duration: 0.15)) { loadingID = song.id }

        let term = "\(song.name) \(song.artist)"
            .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let urlString = "https://itunes.apple.com/search?term=\(term)&entity=song&limit=5&country=tr"
        guard let apiURL = URL(string: urlString) else {
            withAnimation { loadingID = nil }
            return
        }

        do {
            let (data, _) = try await URLSession.shared.data(from: apiURL)
            let response = try JSONDecoder().decode(ITunesSearchResponse.self, from: data)

            let nameLower = song.name.lowercased()
            let artistLower = song.artist.lowercased()
            let match = response.results.first {
                $0.trackName.lowercased().contains(nameLower) ||
                $0.artistName.lowercased().contains(artistLower)
            }

            guard let previewStr = match?.previewUrl,
                  let previewURL = URL(string: previewStr) else {
                withAnimation { loadingID = nil }
                return
            }
            guard !Task.isCancelled else {
                withAnimation { loadingID = nil }
                return
            }
            startPlayback(id: song.id, url: previewURL)
        } catch {
            withAnimation { loadingID = nil }
        }
    }

    // MARK: - Playback

    private func startPlayback(id: UUID, url: URL) {
        player?.pause()
        if let obs = endObserver { NotificationCenter.default.removeObserver(obs); endObserver = nil }

        // setActive(_:) main thread'de UI donmasına yol açabiliyor (AVAudioSession_iOS.mm:978).
        // Oturum kurulumunu arka plana alıyoruz; AVPlayer.play() zaten oturum
        // aktifleşene kadar sessizce bekliyor.
        Task.detached(priority: .userInitiated) {
            let session = AVAudioSession.sharedInstance()
            try? session.setCategory(.playback, mode: .default)
            try? session.setActive(true)
        }

        let item = AVPlayerItem(url: url)
        let newPlayer = AVPlayer(playerItem: item)
        newPlayer.play()
        player = newPlayer

        withAnimation(.easeOut(duration: 0.15)) {
            loadingID = nil
            playingID = id
        }

        updateNowPlaying()
        registerRemoteCommands()

        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: item,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in self?.stop() }
        }
    }

    // MARK: - Now Playing / Remote Control

    private func updateNowPlaying() {
        guard let song = currentSong else { return }
        var info: [String: Any] = [
            MPMediaItemPropertyTitle: song.name,
            MPMediaItemPropertyArtist: song.artist,
            MPNowPlayingInfoPropertyIsLiveStream: false,
            MPNowPlayingInfoPropertyPlaybackRate: 1.0
        ]
        if let asset = player?.currentItem?.asset {
            Task {
                if let duration = try? await asset.load(.duration).seconds, !duration.isNaN {
                    info[MPMediaItemPropertyPlaybackDuration] = duration
                    MPNowPlayingInfoCenter.default().nowPlayingInfo = info
                }
            }
        }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info

        // Load artwork asynchronously if available
        let artURL = currentSong?.artworkURLString.flatMap { URL(string: $0) }
                  ?? currentSong?.coverURL
        if let artURL {
            Task {
                if let (data, _) = try? await URLSession.shared.data(from: artURL),
                   let uiImage = UIImage(data: data) {
                    let artwork = MPMediaItemArtwork(boundsSize: CGSize(width: 300, height: 300)) { _ in uiImage }
                    var updated = MPNowPlayingInfoCenter.default().nowPlayingInfo ?? [:]
                    updated[MPMediaItemPropertyArtwork] = artwork
                    MPNowPlayingInfoCenter.default().nowPlayingInfo = updated
                }
            }
        }
    }

    private func clearNowPlaying() {
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
    }

    private func registerRemoteCommands() {
        let cc = MPRemoteCommandCenter.shared()
        cc.pauseCommand.isEnabled = true
        cc.playCommand.isEnabled = true
        cc.stopCommand.isEnabled = true
        cc.pauseCommand.removeTarget(nil)
        cc.playCommand.removeTarget(nil)
        cc.stopCommand.removeTarget(nil)

        cc.pauseCommand.addTarget { [weak self] _ in
            self?.player?.pause()
            return .success
        }
        cc.playCommand.addTarget { [weak self] _ in
            self?.player?.play()
            return .success
        }
        cc.stopCommand.addTarget { [weak self] _ in
            Task { @MainActor [weak self] in self?.stop() }
            return .success
        }
    }
}

// MARK: - iTunes API models

private struct ITunesSearchResponse: Decodable {
    let results: [ITunesTrack]
}

private struct ITunesTrack: Decodable {
    let trackName: String
    let artistName: String
    let previewUrl: String?
}

// MARK: - Waveform animation

struct AudioWaveform: View {
    @State private var phase = false
    private let heights: [[CGFloat]] = [[5, 12, 8], [10, 6, 13], [7, 13, 5]]

    var body: some View {
        HStack(spacing: 2.5) {
            ForEach(0..<3, id: \.self) { i in
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(ONETokens.oneVoid)
                    .frame(width: 2.5, height: phase ? heights[1][i] : heights[0][i])
                    .animation(
                        .easeInOut(duration: 0.38)
                            .repeatForever(autoreverses: true)
                            .delay(Double(i) * 0.13),
                        value: phase
                    )
            }
        }
        .frame(width: 14, height: 14)
        .onAppear { phase = true }
    }
}
