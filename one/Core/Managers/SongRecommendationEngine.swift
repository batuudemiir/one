//
//  SongRecommendationEngine.swift
//  one
//
//  Şarkı seçicide (V3SongPicker) query boşken kullanıcıya kişiselleştirilmiş
//  şarkı önerileri sunar. İki katman:
//
//    1) MOOD — seçili mood'a göre keyword-tabanlı MusicKit araması.
//       Her mood için birden fazla keyword tanımlı; her yüklemede rastgele
//       biri seçilir → aynı mood tekrar açılınca farklı şarkılar gelir.
//    2) TREND — MusicCatalogChartsRequest ile bugün çalan popülerler,
//       shuffle edilip mood katmanıyla dedupe edilir.
//
//  Kişiselleştirmenin özü: kullanıcının **daha önce seçtiği** şarkılar
//  (`DailySong` tablosu) her katmandan hariç tutulur → aynı öneri iki kere
//  gelmez. İleride Katman 1 olarak past-picks similarSongs eklenebilir.
//

import Foundation
import Combine
import CoreData
import MusicKit

@MainActor
final class SongRecommendationEngine: ObservableObject {
    struct Section: Identifiable {
        let id: String
        let title: String
        let songs: [SongResult]
    }

    @Published private(set) var sections: [Section] = []
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String? = nil

    /// Aynı mood için tekrar fetch atmamak — refresh() ile bypass edilir.
    private var lastLoadedMood: V3Mood? = nil
    private var loadTask: Task<Void, Never>? = nil

    /// Son önerilerde geçen sanatçılar — sonraki refresh'te bu sanatçıları
    /// arka sıraya iterek çeşitlilik sağlıyoruz. Uygulama boyunca in-memory
    /// tutuluyor; kalıcı olması gerekmiyor (her açılışta taze başlayabilir).
    private var recentArtists: [String] = []
    private static let recentArtistsCap = 25

    // MARK: - Public

    func load(mood: V3Mood, context: NSManagedObjectContext) {
        // Aynı mood zaten yüklüyse yeniden çekme.
        if mood == lastLoadedMood, !sections.isEmpty { return }
        cancel()
        loadTask = Task { await performLoad(mood: mood, context: context) }
    }

    func refresh(mood: V3Mood, context: NSManagedObjectContext) {
        cancel()
        lastLoadedMood = nil
        sections = []
        loadTask = Task { await performLoad(mood: mood, context: context) }
    }

    func cancel() {
        loadTask?.cancel()
        loadTask = nil
    }

    // MARK: - Core

    private func performLoad(mood: V3Mood, context: NSManagedObjectContext) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        let status = MusicAuthorization.currentStatus == .authorized
            ? MusicAuthorization.currentStatus
            : await MusicAuthorization.request()

        guard status == .authorized else {
            errorMessage = NSLocalizedString("search.appleMusicPermission", comment: "")
            sections = []
            return
        }

        var excluded = fetchLoggedKeys(context: context)
        var usedArtists = Set<String>()
        var result: [Section] = []

        // Katman 1 — MOOD
        if let moodSongs = await fetchMoodSongs(mood: mood, exclude: &excluded, usedArtists: &usedArtists), !moodSongs.isEmpty {
            result.append(Section(
                id: "mood",
                title: moodSectionTitle(for: mood),
                songs: moodSongs
            ))
        }

        // Katman 2 — TREND
        if let trending = await fetchTrending(exclude: &excluded, usedArtists: &usedArtists), !trending.isEmpty {
            result.append(Section(
                id: "trending",
                title: "BUGÜN NE ÇALIYOR",
                songs: trending
            ))
        }

        if Task.isCancelled { return }
        sections = result
        lastLoadedMood = mood
        rememberArtists(usedArtists)

        if result.isEmpty {
            errorMessage = "Şu an öneri yüklenemedi."
        }
    }

    // MARK: - Katmanlar

    private func fetchMoodSongs(mood: V3Mood, exclude: inout Set<String>, usedArtists: inout Set<String>) async -> [SongResult]? {
        let candidates = Self.moodKeywords[mood] ?? ["mood music"]
        // Aynı sanatçı monopolünü kırmak için tek keyword yerine 3 farklı
        // keyword'ün sonuçlarını **birleştirip** karıştırıyoruz. Tek keyword
        // ("lofi study" gibi) sıklıkla aynı sanatçıdan 6 şarkı döndürüyordu.
        let picked = Array(candidates.shuffled().prefix(3))
        var pool: [MusicKit.Song] = []

        await withTaskGroup(of: [MusicKit.Song].self) { group in
            for term in picked {
                group.addTask {
                    do {
                        var request = MusicCatalogSearchRequest(term: term, types: [MusicKit.Song.self])
                        request.limit = 25
                        let response = try await request.response()
                        return Array(response.songs)
                    } catch {
                        return []
                    }
                }
            }
            for await songs in group { pool.append(contentsOf: songs) }
        }

        guard !pool.isEmpty else { return nil }
        return topDeduped(
            from: pool.shuffled(),
            exclude: &exclude,
            usedArtists: &usedArtists,
            count: 6,
            maxPerArtist: 1,
            demoteRecentArtists: true
        )
    }

    private func fetchTrending(exclude: inout Set<String>, usedArtists: inout Set<String>) async -> [SongResult]? {
        do {
            var request = MusicCatalogChartsRequest(genre: nil, types: [MusicKit.Song.self])
            request.limit = 40
            let response = try await request.response()
            let items = response.songCharts.first?.items.map { $0 } ?? []
            return topDeduped(
                from: items.shuffled(),
                exclude: &exclude,
                usedArtists: &usedArtists,
                count: 6,
                maxPerArtist: 1,
                demoteRecentArtists: false
            )
        } catch {
            return nil
        }
    }

    // MARK: - Helpers

    /// Şarkıları filtrelerken üç kural uyguluyor:
    ///  - `exclude`: geçmişte kayıtlı olan title|artist kombosunu at
    ///  - `maxPerArtist`: aynı sanatçıdan en fazla bir kez
    ///  - `demoteRecentArtists`: son önerilerde geçen sanatçılar önce
    ///     "geçici olarak atlanır"; kota dolmazsa ikinci geçişte alınırlar
    private func topDeduped(
        from source: [MusicKit.Song],
        exclude: inout Set<String>,
        usedArtists: inout Set<String>,
        count: Int,
        maxPerArtist: Int,
        demoteRecentArtists: Bool
    ) -> [SongResult] {
        var out: [SongResult] = []
        var artistCounts: [String: Int] = [:]
        let recent = Set(recentArtists)

        func take(_ s: MusicKit.Song) -> Bool {
            let key = "\(s.title)|\(s.artistName)"
            let artistKey = s.artistName.lowercased()
            guard !exclude.contains(key) else { return false }
            guard (artistCounts[artistKey] ?? 0) < maxPerArtist else { return false }
            exclude.insert(key)
            usedArtists.insert(artistKey)
            artistCounts[artistKey, default: 0] += 1
            out.append(SongResult(
                id: UUID(),
                name: s.title,
                artist: s.artistName,
                genre: s.genreNames.first ?? "Müzik",
                coverURL: s.artwork?.url(width: 200, height: 200),
                spotifyURL: nil,
                artworkURLString: s.artwork?.url(width: 600, height: 600)?.absoluteString,
                previewURL: s.previewAssets?.first?.url
            ))
            return out.count == count
        }

        // 1. geçiş: son önerilenler dışında kalan sanatçılar
        for s in source where !(demoteRecentArtists && recent.contains(s.artistName.lowercased())) {
            if take(s) { return out }
        }
        // 2. geçiş: kota dolmadıysa "recent" sanatçıları da al
        if demoteRecentArtists && out.count < count {
            for s in source where recent.contains(s.artistName.lowercased()) {
                if take(s) { return out }
            }
        }
        return out
    }

    private func rememberArtists(_ artists: Set<String>) {
        // Yeni sanatçıları listenin başına al, sonda taşanları at.
        var merged = Array(artists) + recentArtists.filter { !artists.contains($0) }
        if merged.count > Self.recentArtistsCap {
            merged = Array(merged.prefix(Self.recentArtistsCap))
        }
        recentArtists = merged
    }

    private func fetchLoggedKeys(context: NSManagedObjectContext) -> Set<String> {
        let req: NSFetchRequest<DailySong> = DailySong.fetchRequest()
        guard let items = try? context.fetch(req) else { return [] }
        return Set(items.compactMap { item -> String? in
            guard let t = item.songName, let a = item.artistName else { return nil }
            return "\(t)|\(a)"
        })
    }

    private func moodSectionTitle(for mood: V3Mood) -> String {
        "\(mood.label.uppercased()) BİR AN"
    }

    // MARK: - Mood → keyword tablosu
    //
    // Her mood için 4-5 farklı keyword; rastgele biri seçilir → tekrar tekrar
    // aynı arama sonucu gelmez. Türkçe kelime kullanmıyoruz çünkü MusicKit
    // katalog araması İngilizce genre/mood etiketleriyle daha stabil dönüyor.

    private static let moodKeywords: [V3Mood: [String]] = [
        .atesli:  ["hype workout", "adrenaline pump", "power hour", "gym motivation", "rage beat"],
        .coskulu: ["feel good hits", "party anthems", "celebration", "dance floor", "summer bops"],
        .gergin:  ["dark cinematic", "tense electronic", "anxious mood", "thriller score"],
        .mutlu:   ["happy pop", "sunny day", "uplifting indie", "smile playlist", "morning cheer"],
        .enerjik: ["upbeat energy", "run playlist", "electronic dance", "high tempo"],
        .odakli:  ["deep focus", "lofi study", "concentration flow", "ambient work", "instrumental focus"],
        .huzurlu: ["chill acoustic", "peaceful piano", "sunday morning", "calm indie", "quiet coffee"],
        .huzunlu: ["melancholic indie", "sad songs", "rainy day", "heartbreak playlist", "blue mood"],
        .yorgun:  ["wind down", "sleep ambient", "quiet night", "soft lullaby", "late evening"]
    ]
}
