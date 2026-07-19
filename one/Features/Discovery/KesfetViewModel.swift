import SwiftUI
import Combine

enum VenueSheetKind { case venue, featured, week, artist }

struct LineupItem: Identifiable {
    let id = UUID()
    let name: String
    let time: String
}

struct VenueSheetPayload: Identifiable {
    let id = UUID()
    let kind: VenueSheetKind
    let title: String
    let sub: String
    let gradientColors: [Color]
    let kindLabel: String
    let time: String
    let distance: String
    let why: String
    let lineup: [LineupItem]
}

@MainActor
class KesfetViewModel: ObservableObject {
    @Published var selectedMoodId: String? = nil
    @Published var showMoodSwitcher = false
    @Published var venueSheetPayload: VenueSheetPayload? = nil

    func configure(from moodLabel: String?) {
        if let label = moodLabel, !label.isEmpty {
            selectedMoodId = kesfetMoodId(from: label)
        }
    }

    var mood: KesfetMood? { 
        guard let id = selectedMoodId else { return nil }
        return moodFor(id) 
    }
    
    var curation: MoodCuration? { 
        guard let id = selectedMoodId else { return nil }
        return curationFor(id) 
    }

    func orderedSongs() -> [KesfetSong] {
        guard let curation else { return [] }
        return curation.songIds.compactMap { id in KESFET_SONGS.first { $0.id == id } }
    }

    func orderedVenues() -> [KesfetVenue] {
        guard let curation else { return [] }
        return curation.venueIds.compactMap { id in VENUES_TONIGHT.first { $0.id == id } }
    }

    func orderedCollections() -> [KesfetCollection] {
        guard let curation else { return [] }
        return curation.collectionIds.compactMap { id in KESFET_COLLECTIONS.first { $0.id == id } }
    }

    func featuredPayload() -> VenueSheetPayload? {
        guard let f = curation?.featured, let m = mood else { return nil }
        return VenueSheetPayload(
            kind: .featured,
            title: f.title,
            sub: f.sub,
            gradientColors: [m.color, Color(hex: "#112a20")],
            kindLabel: f.tag,
            time: f.time,
            distance: f.distance,
            why: f.why,
            lineup: [LineupItem(name: "Kapı Açılışı", time: "22:00"), LineupItem(name: "Ana Set", time: "23:00"), LineupItem(name: "Kapanış", time: "02:00")]
        )
    }

    func venuePayload(for venue: KesfetVenue) -> VenueSheetPayload? {
        guard let m = mood else { return nil }
        return VenueSheetPayload(
            kind: .venue,
            title: venue.name,
            sub: "\(venue.neighborhood) · \(venue.kind)",
            gradientColors: venue.gradientColors,
            kindLabel: venue.kind,
            time: venue.time,
            distance: venue.distance,
            why: "Bu mekan bu akşam \(m.label.lowercased(with: Locale(identifier: "tr_TR"))) hissinle uyumlu.",
            lineup: [LineupItem(name: "Kapı Açılışı", time: venue.time), LineupItem(name: "Program Başlangıcı", time: venue.time)]
        )
    }

    func weekPayload(for event: KesfetWeekEvent) -> VenueSheetPayload {
        VenueSheetPayload(
            kind: .week,
            title: event.title,
            sub: event.venue,
            gradientColors: [moodFor(event.moodId).color, Color(hex: "#1C1C1F")],
            kindLabel: "KONSER",
            time: "\(event.day) \(event.date) · \(event.time)",
            distance: "",
            why: "Bu etkinlik \(moodFor(event.moodId).label.lowercased(with: Locale(identifier: "tr_TR"))) hissinle eşleşiyor.",
            lineup: [LineupItem(name: "Kapı Açılışı", time: "19:00"), LineupItem(name: "Sahne", time: event.time)]
        )
    }

    func artistPayload() -> VenueSheetPayload? {
        guard let a = curation?.artist else { return nil }
        return VenueSheetPayload(
            kind: .artist,
            title: a.name,
            sub: a.venue,
            gradientColors: a.gradientColors,
            kindLabel: a.intent,
            time: a.date,
            distance: "",
            why: "Bu sanatçı bu hisle mükemmel uyum sağlıyor.",
            lineup: [LineupItem(name: "Kapı Açılışı", time: "19:00"), LineupItem(name: "Sahne", time: "21:00")]
        )
    }
}
