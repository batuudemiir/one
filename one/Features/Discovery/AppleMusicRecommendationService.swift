//
//  AppleMusicRecommendationService.swift
//  one
//
//  Apple Music öneri servisi — MusicKit tabanlı, kişiselleştirilmiş.
//  Öncelik sırası:
//    1. MusicPersonalRecommendationsRequest (Apple Music ML, iOS 16+)
//    2. Kaydedilen şarkı adlarıyla catalog araması
//    3. Sevilen sanatçılarla arama
//    4. Genre pool araması
//    5. Generic fallback
//

import Foundation
import MusicKit

class AppleMusicRecommendationService {

    // MARK: - Personalized (profile-aware)

    func getRecommendations(profile: TasteProfile, limit: Int = 20) async throws -> [SongRecommendation] {
        let status = await MusicAuthorization.request()
        guard status == .authorized else { throw RecommendationError.notAuthenticated }

        var pool: [SongRecommendation] = []

        // Strategy 1: Apple Music kişisel öneriler (en güçlü — kullanıcının AM geçmişini kullanır)
        if #available(iOS 16, *) {
            let personal = (try? await fetchPersonalRecommendations(limit: limit)) ?? []
            pool.append(contentsOf: personal)
        }

        // Strategy 2: Kaydedilen şarkı adlarıyla catalog araması
        if pool.count < limit * 2 && !profile.topSongs.isEmpty {
            let byName = (try? await searchBySongTerms(songs: profile.topSongs, limit: limit)) ?? []
            pool.append(contentsOf: byName)
        }

        // Strategy 3: Sevilen sanatçılar
        if pool.count < limit * 2 && !profile.topArtists.isEmpty {
            let byArtist = (try? await searchByArtists(
                artists: Array(profile.topArtists.shuffled().prefix(3)), limit: limit
            )) ?? []
            pool.append(contentsOf: byArtist)
        }

        // Strategy 4: Genre genişliği
        if pool.count < limit * 2 && !profile.weightedGenres.isEmpty {
            var seen = Set<String>()
            let genres = profile.weightedGenres.shuffled().filter { seen.insert($0).inserted }
            let byGenre = (try? await searchByGenres(
                genres: Array(genres.prefix(3)), limit: limit
            )) ?? []
            pool.append(contentsOf: byGenre)
        }

        // Strategy 5: Generic dolgu
        if pool.count < limit {
            let generic = (try? await getGenericRecommendations(limit: limit)) ?? []
            pool.append(contentsOf: generic)
        }

        return deduped(pool, limit: limit)
    }

    // MARK: - Generic (no history)

    func getGenericRecommendations(limit: Int = 20) async throws -> [SongRecommendation] {
        let status = await MusicAuthorization.request()
        guard status == .authorized else { throw RecommendationError.notAuthenticated }

        // iOS 16+: kişisel öneri dene (yeni kullanıcı bile AM geçmişi olabilir)
        if #available(iOS 16, *) {
            let personal = (try? await fetchPersonalRecommendations(limit: limit)) ?? []
            if !personal.isEmpty { return personal }
        }

        let genres = ["indie", "alternative", "pop", "rock", "electronic", "chill",
                      "soul", "r-n-b", "hip-hop", "jazz"].shuffled().prefix(4)
        var pool: [SongRecommendation] = []
        for genre in genres {
            let recs = (try? await searchByGenres(genres: [String(genre)], limit: limit / 2)) ?? []
            pool.append(contentsOf: recs)
            if pool.count >= limit * 2 { break }
        }
        return deduped(pool, limit: limit)
    }

    // MARK: - Apple Music Personal Recommendations (iOS 16+)

    @available(iOS 16, *)
    private func fetchPersonalRecommendations(limit: Int) async throws -> [SongRecommendation] {
        let request = MusicPersonalRecommendationsRequest()
        let response = try await request.response()

        // Recommendation'lardan album'leri çek
        let albums = response.recommendations
            .flatMap { $0.items }
            .compactMap { item -> MusicKit.Album? in
                if case .album(let a) = item { return a }
                return nil
            }
            .prefix(8)

        guard !albums.isEmpty else { return [] }

        // Album track'lerini eş zamanlı yükle
        var songs: [SongRecommendation] = []
        await withTaskGroup(of: [SongRecommendation].self) { group in
            for album in albums {
                group.addTask {
                    guard let detailed = try? await album.with([.tracks]),
                          let tracks = detailed.tracks else { return [] }
                    return tracks.prefix(4).map { song in
                        SongRecommendation(
                            id: song.id.rawValue,
                            name: song.title,
                            artist: song.artistName,
                            coverURL: song.artwork?.url(width: 300, height: 300),
                            spotifyURL: "https://music.apple.com/song/\(song.id.rawValue)",
                            genre: nil,
                            recommendationReason: nil,
                            source: .appleMusic
                        )
                    }
                }
            }
            for await batch in group { songs.append(contentsOf: batch) }
        }

        ONELogger.success("MusicPersonalRecommendations: \(songs.count) şarkı", category: .discovery)
        return songs.shuffled()
    }

    // MARK: - Search by Saved Song Names

    private func searchBySongTerms(songs: [SavedSong], limit: Int) async throws -> [SongRecommendation] {
        var results: [SongRecommendation] = []
        for song in songs.prefix(5) {
            do {
                var req = MusicCatalogSearchRequest(
                    term: "\(song.name) \(song.artist)",
                    types: [MusicKit.Song.self]
                )
                req.limit = 5
                let resp = try await req.response()
                let recs = resp.songs.map { s in
                    SongRecommendation(
                        id: s.id.rawValue,
                        name: s.title,
                        artist: s.artistName,
                        coverURL: s.artwork?.url(width: 300, height: 300),
                        spotifyURL: "https://music.apple.com/song/\(s.id.rawValue)",
                        genre: song.genre,
                        recommendationReason: nil,
                        source: .appleMusic
                    )
                }
                results.append(contentsOf: recs)
            } catch is CancellationError { throw CancellationError() }
            catch { continue }
        }
        return results.shuffled()
    }

    // MARK: - Search by Artists

    private func searchByArtists(artists: [String], limit: Int) async throws -> [SongRecommendation] {
        var pool: [SongRecommendation] = []
        for artistName in artists {
            do {
                var req = MusicCatalogSearchRequest(term: artistName, types: [MusicKit.Song.self])
                req.limit = max(6, limit)
                let resp = try await req.response()
                pool.append(contentsOf: resp.songs.map { song in
                    SongRecommendation(
                        id: song.id.rawValue,
                        name: song.title,
                        artist: song.artistName,
                        coverURL: song.artwork?.url(width: 300, height: 300),
                        spotifyURL: "https://music.apple.com/song/\(song.id.rawValue)",
                        genre: nil,
                        recommendationReason: nil,
                        source: .appleMusic
                    )
                })
            } catch is CancellationError { throw CancellationError() }
            catch { ONELogger.warning("Artist arama başarısız: \(artistName)", category: .discovery) }
        }
        return pool
    }

    // MARK: - Search by Genres

    private func searchByGenres(genres: [String], limit: Int) async throws -> [SongRecommendation] {
        var pool: [SongRecommendation] = []
        for genre in genres {
            do {
                var req = MusicCatalogSearchRequest(term: genre, types: [MusicKit.Song.self])
                req.limit = limit
                let resp = try await req.response()
                pool.append(contentsOf: resp.songs.map { song in
                    SongRecommendation(
                        id: song.id.rawValue,
                        name: song.title,
                        artist: song.artistName,
                        coverURL: song.artwork?.url(width: 300, height: 300),
                        spotifyURL: "https://music.apple.com/song/\(song.id.rawValue)",
                        genre: genre,
                        recommendationReason: nil,
                        source: .appleMusic
                    )
                })
            } catch is CancellationError { throw CancellationError() }
            catch { ONELogger.warning("Genre arama başarısız: \(genre)", category: .discovery) }
        }
        return pool
    }

    // MARK: - Dedup Helper

    private func deduped(_ pool: [SongRecommendation], limit: Int) -> [SongRecommendation] {
        var seen = Set<String>()
        let unique = pool.filter { seen.insert($0.id).inserted }
        return Array(unique.shuffled().prefix(limit))
    }
}
