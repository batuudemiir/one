//
//  TicketmasterManager.swift
//  one
//
//  Ticketmaster Discovery API client (covers Biletix TR).
//  Parallel multi-category fetch with caching and nearby-city fallback.
//  Extracted from MoodEventsSheet.swift in Faz 3.1 (2026-04-26).
//

import Foundation
import CoreLocation

// MARK: - Ticketmaster API Manager & Models

class TicketmasterManager {
    static let shared = TicketmasterManager()

    private let apiKey: String
    private let baseURL = "https://app.ticketmaster.com/discovery/v2/events.json"

    var userLocation: CLLocationCoordinate2D? = nil
    private var cachedEventsByKey: [String: (events: [MoodEvent], createdAt: Date)] = [:]
    private let cacheTTL: TimeInterval = 24 * 60 * 60  // 24 saat — günde bir yenileme
    private var didLogMissingKey = false

    /// Tier-1: cities where Biletix has active event pages and direct TM→Biletix links work reliably.
    /// All other cities use the Biletix category search page URL which never returns 404.
    private let biletixTier1Cities: Set<String> = [
        "istanbul", "ankara", "izmir", "bursa", "antalya", "adana", "gaziantep"
    ]

    private init() {
        let possibleKeys = [
            "TicketmasterAPIKey",
            "TICKETMASTER_API_KEY",
            "TM_API_KEY",
            "TicketmasterKey"
        ]
        let placeholderValues: Set<String> = ["", "YOUR_TICKETMASTER_API_KEY", "YOUR_API_KEY"]

        let resolved = possibleKeys
            .compactMap { Bundle.main.object(forInfoDictionaryKey: $0) as? String }
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { !placeholderValues.contains($0) }

        self.apiKey = resolved ?? ""
    }

    // MARK: - Public

    /// Full layered fetch strategy:
    /// • Music lookups: exact artist, artist+genre blend, direct genre, mood genre keyword.
    /// • Culture lookups: arts & theatre and exhibition-style listings.
    /// • Nearby-city retry when the primary city is empty.
    /// • Falls back to city-adaptive mock data only if the API key is missing or all calls fail.
    /// Results are merged, mood-scored, deduplicated, and capped at 24.
    func fetchLiveEvents(for entry: DailyEntry, city: String) async throws -> [MoodEvent] {
        // Cache key includes today's date → auto-invalidates each day
        let todayString = ISO8601DateFormatter().string(from: Date()).prefix(10)
        let cacheKey = "\(entry.normalizedMoodLabel)|\(entry.artistName)|\(entry.genre)|\(city)|\(todayString)"
        if let cached = cachedEventsByKey[cacheKey], Date().timeIntervalSince(cached.createdAt) < cacheTTL {
            return cached.events
        }

        guard !apiKey.isEmpty else {
            if !didLogMissingKey {
                ONELogger.warning("Ticketmaster API key missing. Using mock events.", category: .general)
                didLogMissingKey = true
            }
            return cacheAndReturn([], key: cacheKey)
        }

        let e1 = (try? await fetchMusicMatches(entry: entry, city: city)) ?? []
        try? await Task.sleep(nanoseconds: 250_000_000)
        let e2 = (try? await fetchForSegment(entry: entry, city: city, category: .tiyatro, size: 6)) ?? []
        try? await Task.sleep(nanoseconds: 250_000_000)
        let e3 = (try? await fetchForSegment(entry: entry, city: city, category: .sergi, size: 6)) ?? []
        try? await Task.sleep(nanoseconds: 250_000_000)
        let e4 = (try? await fetchForSegment(entry: entry, city: city, category: .spor, size: 5)) ?? []
        var apiEvents = e1 + e2 + e3 + e4

        // If primary city returned nothing, try nearby cities before falling to mock.
        // Events from nearby cities are marked with isNearbyCity=true so the UI can
        // label them clearly (e.g. "Yakın şehir: İstanbul").
        if apiEvents.isEmpty {
            for altCity in nearbyCities(for: city) {
                try? await Task.sleep(nanoseconds: 300_000_000)
                let altMusic = (try? await fetchMusicMatches(entry: entry, city: altCity)) ?? []
                try? await Task.sleep(nanoseconds: 250_000_000)
                let altArts  = (try? await fetchForSegment(entry: entry, city: altCity, category: .tiyatro, size: 5)) ?? []
                try? await Task.sleep(nanoseconds: 250_000_000)
                let altExpo  = (try? await fetchForSegment(entry: entry, city: altCity, category: .sergi, size: 4)) ?? []
                let altEvents = altMusic + altArts + altExpo
                if !altEvents.isEmpty {
                    // Tag every event so the card layer can show "Yakın şehir: X"
                    apiEvents = altEvents.map { markNearby($0) }
                    ONELogger.info("No TM events in \(city) — showing nearby \(altCity) (\(altEvents.count) events).", category: .general)
                    break
                }
            }
        }

        // If STILL empty, recommend generic events special to that province
        if apiEvents.isEmpty {
            apiEvents = CitySpecialActivities.getSpecialEvents(for: city)
            ONELogger.info("No TM events in nearby cities either — showing CitySpecialActivities for \(city).", category: .general)
        }

        // Merge API results — sinema excluded (not on Biletix); spor/aktivite welcome
        let source = apiEvents
            .filter { $0.category != .sinema }

        let merged = deduplicateKeepingBest(source)

        let sorted = Array(
            merged
                .sorted {
                    $0.matchPercent != $1.matchPercent
                        ? $0.matchPercent > $1.matchPercent
                        : $0.timing < $1.timing
                }
                .prefix(24)
        )

        return cacheAndReturn(sorted, key: cacheKey)
    }

    func fetchEvents(for entry: DailyEntry, city: String) async throws -> [MoodEvent] {
        try await fetchLiveEvents(for: entry, city: city)
    }

    // MARK: - Private: single-segment fetch

    private struct MusicQueryProfile {
        let keyword: String
        let kind: RecommendationKind
        let sourceLabel: String
        let reason: String
        let size: Int
    }

    private func fetchMusicMatches(entry: DailyEntry, city: String) async throws -> [MoodEvent] {
        let profiles = musicProfiles(for: entry)
        guard !profiles.isEmpty else { return [] }

        return try await withThrowingTaskGroup(of: [MoodEvent].self) { group in
            for profile in profiles {
                group.addTask {
                    try await self.fetchMusicProfile(entry: entry, city: city, profile: profile, size: profile.size)
                }
            }

            var results: [MoodEvent] = []
            for try await chunk in group {
                results += chunk
            }
            return results
        }
    }

    private func fetchMusicProfile(entry: DailyEntry, city: String, profile: MusicQueryProfile, size: Int) async throws -> [MoodEvent] {
        guard var components = URLComponents(string: baseURL) else { throw URLError(.badURL) }

        let apiCity = normalizedCityForAPI(city)
        let (startDT, endDT) = requestDateWindow()
        components.queryItems = [
            URLQueryItem(name: "apikey", value: apiKey),
            URLQueryItem(name: "city", value: apiCity),
            URLQueryItem(name: "countryCode", value: "TR"),
            URLQueryItem(name: "sort", value: "date,asc"),
            URLQueryItem(name: "size", value: "\(size)"),
            URLQueryItem(name: "classificationName", value: tmSegment(for: .konser)),
            URLQueryItem(name: "keyword", value: profile.keyword),
            URLQueryItem(name: "startDateTime", value: startDT),
            URLQueryItem(name: "endDateTime", value: endDT)
        ]

        guard let url = components.url else { throw URLError(.badURL) }
        ONELogger.debug("TM fetch → \(apiCity) / Music / \(profile.keyword): \(url.absoluteString)", category: .general)

        let (data, response) = try await URLSession.shared.data(from: url)
        guard let http = response as? HTTPURLResponse else { return [] }
        guard http.statusCode == 200 else {
            let body = String(data: data, encoding: .utf8) ?? ""
            ONELogger.error("TM API \(http.statusCode) for \(apiCity)/Music: \(body.prefix(200))", category: .general)
            return []
        }

        let tmResponse = try JSONDecoder().decode(TMResponse.self, from: data)
        let events = (tmResponse._embedded?.events ?? []).compactMap { event -> MoodEvent? in
            guard event.dates?.start?.localDate != nil else { return nil }
            return buildMoodEvent(
                from: event,
                entry: entry,
                city: city,
                kind: profile.kind,
                sourceLabel: profile.sourceLabel,
                reason: profile.reason,
                keyword: profile.keyword
            )
        }

        ONELogger.info("TM \(apiCity)/Music/\(profile.keyword) → \(events.count) events", category: .general)
        return events
    }

    private func fetchForSegment(entry: DailyEntry, city: String, category: EventCategory, size: Int) async throws -> [MoodEvent] {
        guard var components = URLComponents(string: baseURL) else { throw URLError(.badURL) }

        let apiCity = normalizedCityForAPI(city)
        let (startDT, endDT) = requestDateWindow()

        components.queryItems = [
            URLQueryItem(name: "apikey",             value: apiKey),
            URLQueryItem(name: "city",               value: apiCity),   // ASCII city name
            URLQueryItem(name: "countryCode",        value: "TR"),
            // locale=tr-tr removed — TM doesn't support it and it filters out results
            URLQueryItem(name: "sort",               value: "date,asc"),
            URLQueryItem(name: "size",               value: "\(size)"),
            URLQueryItem(name: "classificationName", value: tmSegment(for: category)),
            URLQueryItem(name: "startDateTime",      value: startDT),
            URLQueryItem(name: "endDateTime",        value: endDT)
        ]

        guard let url = components.url else { throw URLError(.badURL) }
        ONELogger.debug("TM fetch → \(apiCity) / \(category.rawValue): \(url.absoluteString)", category: .general)

        let (data, response) = try await URLSession.shared.data(from: url)

        guard let http = response as? HTTPURLResponse else { return [] }
        guard http.statusCode == 200 else {
            let body = String(data: data, encoding: .utf8) ?? ""
            ONELogger.error("TM API \(http.statusCode) for \(apiCity)/\(category.rawValue): \(body.prefix(200))", category: .general)
            return []
        }

        let tmResponse = try JSONDecoder().decode(TMResponse.self, from: data)
        let events = (tmResponse._embedded?.events ?? []).compactMap { event -> MoodEvent? in
            guard event.dates?.start?.localDate != nil else { return nil }
            return buildMoodEvent(from: event, entry: entry, city: city)
        }
        ONELogger.info("TM \(apiCity)/\(category.rawValue) → \(events.count) events", category: .general)
        return events
    }

    /// Resolves the best Biletix URL for an event.
    ///
    /// Strategy:
    /// • Tier-1 cities (İstanbul, Ankara, İzmir, Bursa, Antalya, Adana, Gaziantep):
    ///   Use the direct TM event.url → goes to the specific Biletix event page.
    /// • All other cities: Use the Biletix category search page (biletix.com/arama/CITY/tr#!...)
    ///   which is always valid and never returns 404.
    ///
    /// Returns (url, isFallback) — isFallback=true means it's a search page, not a direct event page.
    private func resolvedBiletixURL(
        tmURL: String?,
        eventCity: String,
        category: EventCategory
    ) -> (url: URL?, isFallback: Bool) {
        // Only use a direct URL if it's actually a biletix.com link —
        // Ticketmaster API returns ticketmaster.com URLs that 404 on Biletix.
        if let urlStr = tmURL,
           urlStr.lowercased().contains("biletix.com"),
           let url = URL(string: urlStr) {
            return (url, false)
        }

        // Any other URL (ticketmaster.com, nil) → category search page (never 404s)
        let fallback = biletixFallbackURL(city: eventCity, category: category)
        return (fallback, true)
    }

    /// Creates a copy of a MoodEvent with isNearbyCity = true.
    private func markNearby(_ event: MoodEvent) -> MoodEvent {
        MoodEvent(
            id: event.id,
            category: event.category,
            title: event.title,
            venue: event.venue,
            city: event.city,
            timing: event.timing,
            price: event.price,
            matchPercent: max(event.matchPercent - 8, 50),
            sourceURL: event.sourceURL,
            kind: event.kind,
            reason: event.reason,
            sourceLabel: event.sourceLabel,
            isNearbyCity: true,
            isFallbackURL: event.isFallbackURL,
            eventDate: event.eventDate,
            attendeeCount: event.attendeeCount,
            distanceKm: event.distanceKm
        )
    }

    private func buildMoodEvent(
        from event: TMEvent,
        entry: DailyEntry,
        city: String,
        kind: RecommendationKind = .liveEvent,
        sourceLabel: String? = nil,
        reason: String? = nil,
        keyword: String? = nil
    ) -> MoodEvent {
        let category  = mapCategory(from: event)
        let venue     = event._embedded?.venues?.first?.name ?? "Bilinmeyen Mekan"
        let eventCity = event._embedded?.venues?.first?.city?.name ?? city
        let dateStr   = event.dates?.start?.localDate ?? ""
        let time      = event.dates?.start?.localTime
        let timing    = timingLabel(date: dateStr, time: time)

        let dateFmt = DateFormatter()
        dateFmt.dateFormat = "yyyy-MM-dd"
        let parsedDate = dateStr.isEmpty ? nil : dateFmt.date(from: dateStr)

        var distanceKm: Double? = nil
        if let userLoc = userLocation,
           let latStr = event._embedded?.venues?.first?.location?.latitude,
           let lonStr = event._embedded?.venues?.first?.location?.longitude,
           let lat = Double(latStr), let lon = Double(lonStr) {
            let venueLoc = CLLocation(latitude: lat, longitude: lon)
            let userCL = CLLocation(latitude: userLoc.latitude, longitude: userLoc.longitude)
            distanceKm = userCL.distance(from: venueLoc) / 1000.0
        }

        var priceString = "Bilet bilgisi yakında"
        if let min = event.priceRanges?.first?.min {
            let currency = event.priceRanges?.first?.currency ?? "TRY"
            priceString = currency.uppercased() == "TRY" ? "₺\(Int(min))+" : "\(currency) \(Int(min))+"
        }

        // Smart URL resolution: direct link for major cities, search page for others
        let (resolvedURL, isFallback) = resolvedBiletixURL(
            tmURL: event.url,
            eventCity: eventCity,
            category: category
        )

        return MoodEvent(
            id: event.id,
            category: category,
            title: event.name,
            venue: venue,
            city: eventCity,
            timing: timing,
            price: priceString,
            matchPercent: score(event: event, category: category, entry: entry, city: city, kind: kind, keyword: keyword),
            sourceURL: resolvedURL,
            kind: kind,
            reason: reason ?? liveReason(for: category, entry: entry, city: eventCity),
            sourceLabel: sourceLabel ?? defaultSourceLabel(for: kind, category: category),
            isNearbyCity: false,
            isFallbackURL: isFallback,
            eventDate: parsedDate,
            attendeeCount: nil,
            distanceKm: distanceKm
        )
    }

    // MARK: - Mapping helpers

    /// Maps our local category to the Ticketmaster `classificationName` segment string.
    private func tmSegment(for category: EventCategory) -> String {
        switch category {
        case .aktivite:        return "Arts & Theatre"
        case .konser:          return "Music"
        case .spor:            return "Sports"
        case .sinema:          return "Film"
        case .tiyatro, .sergi: return "Arts & Theatre"
        }
    }

    private func mapCategory(from event: TMEvent) -> EventCategory {
        let seg   = event.classifications?.first?.segment?.name?.lowercased() ?? ""
        let genre = event.classifications?.first?.genre?.name?.lowercased() ?? ""
        let text  = "\(seg) \(genre)"

        if text.contains("music") || text.contains("concert") || text.contains("fest") { return .konser }
        if text.contains("sport") || text.contains("football") || text.contains("basketball") { return .spor }
        if text.contains("film")  || text.contains("cinema") || text.contains("movie") { return .sinema }
        if text.contains("theatre") || text.contains("theater") || text.contains("comedy") { return .tiyatro }
        if text.contains("museum") || text.contains("exhibition") || text.contains("art") { return .sergi }
        return .konser
    }

    /// Mood → preferred category order (used both for parallel fetching and scoring).
    private func preferredCategories(for moodLabel: String, feelingLabel: String = "") -> [EventCategory] {
        // Feeling override — yüksek enerjili feelings için konser her zaman ilk sıraya girer
        let concertFeelings: Set<String> = ["Hype", "Dance", "Happier than ever", "Manifest"]
        if concertFeelings.contains(feelingLabel) {
            return [.konser, .tiyatro, .sergi]
        }
        let calmFeelings: Set<String> = ["Chill", "Alone", "Sad"]
        if calmFeelings.contains(feelingLabel) {
            return [.sergi, .tiyatro, .konser]
        }
        let overthinkFeelings: Set<String> = ["Overthink"]
        if overthinkFeelings.contains(feelingLabel) {
            return [.tiyatro, .sergi, .konser]
        }

        switch canonicalMoodLabel(moodLabel) {
        case "Ateşli":    return [.konser, .tiyatro, .sergi]
        case "Coşkulu":   return [.konser, .tiyatro, .sergi]
        case "Mutlu":     return [.sergi, .konser, .tiyatro]
        case "Doğal":     return [.aktivite, .sergi, .konser]
        case "Huzurlu":   return [.tiyatro, .sergi, .konser]
        case "Özgür":     return [.aktivite, .konser, .sergi]
        case "Derin":     return [.tiyatro, .sergi, .konser]
        case "Nostaljik": return [.konser, .tiyatro, .sergi]
        case "Gizemli":   return [.sergi, .tiyatro, .konser]
        case "Hassas":    return [.konser, .sergi, .tiyatro]
        case "Sessiz":    return [.sergi, .tiyatro, .konser]
        case "Nötr":      return [.aktivite, .sergi, .konser]
        default:           return [.konser, .sergi, .tiyatro]
        }
    }

    /// Returns nearby Turkish cities to use as TM query fallback when the primary city yields no events.
    private func nearbyCities(for city: String) -> [String] {
        let c = city.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
        switch c {
        case "istanbul":   return ["Bursa", "Kocaeli", "Tekirdağ"]
        case "ankara":     return ["Eskişehir", "Konya", "Kayseri"]
        case "izmir":      return ["Manisa", "Aydın", "Denizli"]
        case "bursa":      return ["Yalova", "Eskişehir", "İstanbul"]
        case "kocaeli":    return ["İstanbul", "Bursa", "Sakarya"]
        case "sakarya":    return ["Kocaeli", "İstanbul", "Bursa"]
        case "antalya":    return ["Alanya", "Muğla", "Isparta"]
        case "adana":      return ["Mersin", "Gaziantep", "Hatay"]
        case "gaziantep":  return ["Adana", "Şanlıurfa"]
        case "konya":      return ["Ankara", "Afyonkarahisar", "Isparta"]
        case "mersin":     return ["Adana", "Antalya"]
        case "diyarbakir": return ["Şanlıurfa", "Mardin"]
        default:           return ["İstanbul", "Ankara", "İzmir"]
        }
    }

    /// Genre/artist keyword — only used for music segment queries.
    private func musicKeyword(from entry: DailyEntry) -> String? {
        let genre       = entry.genre.trimmingCharacters(in: .whitespacesAndNewlines)
        let artistToken = entry.artistName.split(separator: " ").first.map(String.init) ?? ""
        let generic: Set<String> = ["müzik", "music", "song", "şarkı"]

        if genre.isEmpty || generic.contains(genre.lowercased()) {
            return artistToken.count >= 3 ? artistToken : nil
        }
        return artistToken.count >= 3 ? "\(genre) \(artistToken)" : genre
    }

    private func musicProfiles(for entry: DailyEntry) -> [MusicQueryProfile] {
        var profiles: [MusicQueryProfile] = []
        var seen = Set<String>()

        func append(keyword: String?, kind: RecommendationKind, sourceLabel: String, reason: String) {
            guard let keyword else { return }
            let normalized = normalize(keyword)
            guard normalized.count >= 3, !seen.contains(normalized) else { return }
            seen.insert(normalized)
            profiles.append(
                MusicQueryProfile(
                    keyword: keyword,
                    kind: kind,
                    sourceLabel: sourceLabel,
                    reason: reason,
                    size: kind == .artistConcert ? 8 : 6
                )
            )
        }

        let artist = entry.artistName.trimmingCharacters(in: .whitespacesAndNewlines)
        append(
            keyword: artist,
            kind: .artistConcert,
            sourceLabel: "Sanatçı eşleşmesi",
            reason: "Seçtiğin sanatçının şehirdeki konser ihtimali için öne alındı."
        )
        append(
            keyword: musicKeyword(from: entry),
            kind: .similarConcert,
            sourceLabel: "Tarz yakın",
            reason: "Seçtiğin şarkının türüyle kesişen canlı müzikler bulundu."
        )

        let genre = entry.genre.trimmingCharacters(in: .whitespacesAndNewlines)
        let genericGenres = Set(["müzik", "music", "song", "şarkı"])
        append(
            keyword: genericGenres.contains(normalize(genre)) ? nil : genre,
            kind: .similarConcert,
            sourceLabel: "Aynı tür",
            reason: "Dinlediğin türle benzer konserler şehirde tarandı."
        )
        append(
            keyword: moodGenreKeywords(for: entry.normalizedMoodLabel).first,
            kind: .similarConcert,
            sourceLabel: "Mood filtresi",
            reason: "Mood'una yaslanan canlı müzikler de listeye alındı."
        )

        return profiles
    }

    /// Genre keywords associated with each mood — used for text-matching bonus.
    private func moodGenreKeywords(for moodLabel: String) -> [String] {
        switch canonicalMoodLabel(moodLabel) {
        case "Ateşli":    return ["rock", "metal", "hard", "punk", "rap", "hip-hop"]
        case "Coşkulu":   return ["pop", "dance", "edm", "rave", "festival"]
        case "Mutlu":     return ["classical", "jazz", "symphony", "orchestra", "opera"]
        case "Doğal":      return ["folk", "indie-pop", "acoustic", "world", "afrobeat"]
        case "Huzurlu":   return ["acoustic", "folk", "ambient", "piano", "jazz"]
        case "Özgür":     return ["indie", "alternative", "world", "folk-rock", "reggae"]
        case "Derin":     return ["indie", "alternative", "blues", "singer-songwriter"]
        case "Nostaljik": return ["80s", "90s", "classic-rock", "soul", "motown"]
        case "Gizemli":   return ["jazz", "noir", "electronic", "experimental"]
        case "Hassas":    return ["classical", "chamber", "neo-classical", "piano", "strings"]
        case "Sessiz":    return ["ambient", "minimal", "post-rock", "drone"]
        case "Nötr":      return ["folk", "indie", "world"]
        default:          return []
        }
    }

    private func defaultSourceLabel(for kind: RecommendationKind, category: EventCategory) -> String? {
        switch kind {
        case .artistConcert:
            return "Sanatçı eşleşmesi"
        case .similarConcert:
            return "Tarz yakın"
        case .microActivity:
            return "Bugüne özel"
        case .liveEvent:
            return category == .konser ? "Şehirde canlı" : "Ticketmaster"
        }
    }

    private func liveReason(for category: EventCategory, entry: DailyEntry, city: String) -> String {
        switch category {
        case .konser:
            return "Bugünkü \(canonicalMoodLabel(entry.normalizedMoodLabel).lowercased()) moduna ve seçtiğin müziğe yakın bir konser."
        case .sergi:
            return "Mood'unu daha görsel ve yavaş bir rotaya taşıyabilecek şehir önerisi."
        case .tiyatro:
            return "Bugünkü ruh haline dramatik ama dengeli bir akşam planı açıyor."
        case .sinema:
            return "Şehirde kolayca planlanabilecek, bugünkü tempoya uyan bir seans."
        case .spor:
            return "Enerjini dışarı taşıyan daha hareketli bir şehir planı."
        case .aktivite:
            return "Bugüne uygun küçük bir hareket alanı açıyor."
        }
    }

    private func normalizedCityForAPI(_ city: String) -> String {
        let cityLower = city.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
        return cityLower.prefix(1).uppercased() + cityLower.dropFirst()
    }

    private func requestDateWindow() -> (String, String) {
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime]
        iso.timeZone = TimeZone(identifier: "UTC")
        let now = Date()
        let weekEnd = Calendar.current.date(byAdding: .day, value: 7, to: now) ?? now
        return (iso.string(from: now), iso.string(from: weekEnd))
    }

    private func normalize(_ text: String) -> String {
        text
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }

    private func deduplicateKeepingBest(_ events: [MoodEvent]) -> [MoodEvent] {
        var bestByID: [String: MoodEvent] = [:]

        for event in events {
            guard let current = bestByID[event.id] else {
                bestByID[event.id] = event
                continue
            }

            let eventPriority = priority(for: event.kind)
            let currentPriority = priority(for: current.kind)
            let shouldReplace = event.matchPercent > current.matchPercent
                || (event.matchPercent == current.matchPercent && eventPriority > currentPriority)

            if shouldReplace {
                bestByID[event.id] = event
            }
        }

        return Array(bestByID.values)
    }

    private func priority(for kind: RecommendationKind) -> Int {
        switch kind {
        case .artistConcert: return 4
        case .similarConcert: return 3
        case .liveEvent: return 2
        case .microActivity: return 1
        }
    }

    // MARK: - Scoring

    /// Mood-aware scoring:
    /// • Category rank vs. mood preference  → up to +30 pts
    /// • Song genre match in event text     → +8 pts
    /// • Artist name match in event text    → +6 pts
    /// • Mood genre keywords in event text  → +5 pts
    /// • City exact match                   → +3 pts
    private func score(
        event: TMEvent,
        category: EventCategory,
        entry: DailyEntry,
        city: String,
        kind: RecommendationKind = .liveEvent,
        keyword: String? = nil
    ) -> Int {
        var pts = 50

        // 1. Category alignment with mood
        let preferred = preferredCategories(for: entry.normalizedMoodLabel, feelingLabel: entry.feelingLabel)
        if let rank = preferred.firstIndex(of: category) {
            switch rank {
            case 0: pts += 30
            case 1: pts += 20
            case 2: pts += 12
            default: break
            }
        }

        let searchableText = [
            event.name,
            event.classifications?.first?.segment?.name ?? "",
            event.classifications?.first?.genre?.name ?? "",
            event.classifications?.first?.subGenre?.name ?? ""
        ]
        .joined(separator: " ")
        .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
        .lowercased()

        // 2. Song genre match
        let genreToken = normalize(entry.genre)
        if !genreToken.isEmpty, genreToken != "müzik", searchableText.contains(genreToken) {
            pts += 8
        }

        // 3. Artist name match
        let normalizedArtist = normalize(entry.artistName)
        if !normalizedArtist.isEmpty, searchableText.contains(normalizedArtist) {
            pts += 26
        }

        if let artistToken = entry.artistName.split(separator: " ").first.map({ normalize(String($0)) }),
           artistToken.count >= 3, searchableText.contains(artistToken) {
            pts += 10
        }

        // 4. Mood genre keyword match
        if moodGenreKeywords(for: entry.normalizedMoodLabel).contains(where: { searchableText.contains(normalize($0)) }) {
            pts += 5
        }

        // 5. Music query and match type bonus
        if let keyword, searchableText.contains(normalize(keyword)) {
            pts += 10
        }

        switch kind {
        case .artistConcert:
            pts += 12
        case .similarConcert:
            pts += 7
        case .liveEvent, .microActivity:
            break
        }

        // 6. City exact match
        let venueCity = normalize(event._embedded?.venues?.first?.city?.name ?? "")
        if !venueCity.isEmpty, venueCity == normalize(city) {
            pts += 3
        }

        return min(max(pts, 50), 99)
    }

    // MARK: - Utilities

    /// Converts "2026-03-11" + "21:00:00" → "Yarın · 21:00"
    /// Relative labels: Bugün / Yarın / Öbür gün / <Türkçe gün adı>
    private func timingLabel(date: String, time: String?) -> String {
        guard !date.isEmpty else { return "Tarih yakında" }

        let dateFmt = DateFormatter()
        dateFmt.dateFormat = "yyyy-MM-dd"
        dateFmt.locale = LanguageManager.shared.currentLocale

        let timeStr = time.flatMap { t -> String? in
            t.count >= 5 ? " · \(t.prefix(5))" : nil
        } ?? ""

        guard let eventDate = dateFmt.date(from: date) else {
            return "\(date)\(timeStr)"
        }

        let cal   = Calendar.current
        let today = cal.startOfDay(for: Date())
        let event = cal.startOfDay(for: eventDate)
        let diff  = cal.dateComponents([.day], from: today, to: event).day ?? 0

        switch diff {
        case 0:  return "Bugün\(timeStr)"
        case 1:  return "Yarın\(timeStr)"
        case 2:  return "Öbür gün\(timeStr)"
        default:
            let dayFmt = DateFormatter()
            dayFmt.dateFormat = "EEEE"
            dayFmt.locale = LanguageManager.shared.currentLocale
            let dayName = dayFmt.string(from: eventDate).prefix(1).uppercased()
                        + dayFmt.string(from: eventDate).dropFirst()
            return "\(dayName)\(timeStr)"
        }
    }

    private func fallbackToMock(for moodLabel: String, city: String) -> [MoodEvent] {
        []
    }

    @discardableResult
    private func cacheAndReturn(_ events: [MoodEvent], key: String) -> [MoodEvent] {
        cachedEventsByKey[key] = (events, Date())
        return events
    }
}
