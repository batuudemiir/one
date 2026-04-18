//
//  MoodEventsSheet.swift
//  one
//
//  Mood-matched event recommendations.
//  Ticketmaster (covers Biletix TR) — parallel multi-category fetch with mock fallback.
//

import SwiftUI
import Foundation

func canonicalMoodLabel(_ moodLabel: String) -> String {
    switch moodLabel.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
    case "atesli", "tutkulu", "ateş", "ates":
        return "Ateşli"
    case "enerjik", "coşkulu", "coskulu", "heyecanli", "heyecanlı", "canli", "canlı", "enerji":
        return "Coşkulu"
    case "isikli", "ışıklı", "mutlu", "neşeli", "ışık", "isik":
        return "Mutlu"
    case "taze", "doğal", "dogal":
        return "Doğal"
    case "sakin", "huzurlu", "dingin", "huzur":
        return "Huzurlu"
    case "ozgur", "özgür":
        return "Özgür"
    case "derin":
        return "Derin"
    case "nostaljik", "özlem", "ozlem":
        return "Nostaljik"
    case "gizemli", "büyü", "buyu", "loş", "los":
        return "Gizemli"
    case "hassas", "kırılgan", "kirilgan":
        return "Hassas"
    case "bos", "boş", "sessiz", "boşluk", "bosluk":
        return "Sessiz"
    case "temiz", "sade", "notr", "nötr":
        return "Nötr"
    default:
        return moodLabel
    }
}

// MARK: - Event Category

enum EventCategory: String, CaseIterable, Identifiable, Codable {
    case aktivite = "Aktivite"
    case konser   = "Konser"
    case spor     = "Spor"
    case sinema   = "Sinema"
    case tiyatro  = "Tiyatro"
    case sergi    = "Sergi"

    var id: String { rawValue }

    var accentColor: Color {
        switch self {
        case .aktivite: return Color(hex: "#2D7C68")
        case .konser:  return Color(hex: "#E84040")
        case .spor:    return Color(hex: "#FF8C42")
        case .sinema:  return Color(hex: "#F5C842")
        case .tiyatro: return Color(hex: "#9B7FD4")
        case .sergi:   return Color(hex: "#5B8DEF")
        }
    }
}

enum RecommendationKind: String, Equatable, Codable {
    case microActivity
    case liveEvent
    case artistConcert
    case similarConcert
}

// MARK: - Mood Event Model

struct MoodEvent: Identifiable, Codable {
    let id: String
    let category: EventCategory
    let title: String
    let venue: String
    let city: String
    let timing: String
    let price: String
    let matchPercent: Int
    let sourceURL: URL?
    let kind: RecommendationKind
    let reason: String?
    let sourceLabel: String?
    /// true → event is from a nearby-city API fallback, not the user's preferred city
    let isNearbyCity: Bool
    /// true → sourceURL is a Biletix category search page (never 404s)
    ///         false / nil → direct event page (can 404 for minor cities)
    let isFallbackURL: Bool

    init(
        id: String = UUID().uuidString,
        category: EventCategory,
        title: String,
        venue: String,
        city: String,
        timing: String,
        price: String,
        matchPercent: Int,
        sourceURL: URL? = nil,
        kind: RecommendationKind = .liveEvent,
        reason: String? = nil,
        sourceLabel: String? = nil,
        isNearbyCity: Bool = false,
        isFallbackURL: Bool = false
    ) {
        self.id = id
        self.category = category
        self.title = title
        self.venue = venue
        self.city = city
        self.timing = timing
        self.price = price
        self.matchPercent = matchPercent
        self.sourceURL = sourceURL
        self.kind = kind
        self.reason = reason
        self.sourceLabel = sourceLabel
        self.isNearbyCity = isNearbyCity
        self.isFallbackURL = isFallbackURL
    }
}

// MARK: - Mock Data (fallback only)
// Used when API key is missing or all parallel TM calls return empty.
// Venue names are generic so any Turkish city works.

func mockEvents(for moodLabel: String, city: String = "İstanbul") -> [MoodEvent] {
    let normalizedMood = canonicalMoodLabel(moodLabel)
    let base: [MoodEvent] = {
        switch normalizedMood {

    case "Ateşli":
        return [MoodEvent(category: .konser, title: "Rock Gecesi — Yeni Albüm Lansmanı", venue: "Büyük Konser Salonu", city: city, timing: "Bu akşam · 21:00", price: "₺550+", matchPercent: 94)]
            + [
                MoodEvent(category: .sinema,  title: "Aksiyon Filmi Özel Gösterimi", venue: "Sinema Salonu",         city: city, timing: "Bu akşam · 19:30", price: "₺120",  matchPercent: 76),
                MoodEvent(category: .tiyatro, title: "Macbeth — Devlet Tiyatrosu",   venue: "Büyük Tiyatro Sahnesi", city: city, timing: "Cuma · 20:00",      price: "₺280+", matchPercent: 71),
            ]

    case "Coşkulu":
        return [MoodEvent(category: .konser, title: "Pop Festivali — Açık Hava Sahnesi", venue: "Açık Hava Amfitiyatro", city: city, timing: "Bu akşam · 21:30", price: "₺400+", matchPercent: 92)]
            + [
                MoodEvent(category: .tiyatro, title: "Stand-Up Komedi Şovu",           venue: "Kültür Merkezi Sahnesi", city: city, timing: "Cumartesi · 20:30", price: "₺200+", matchPercent: 72),
                MoodEvent(category: .sergi,   title: "Sokak Sanatı & Grafiti Sergisi", venue: "Sanat Galerisi",         city: city, timing: "Hafta sonu açık",   price: "₺80",   matchPercent: 65),
            ]

    case "Mutlu":
        return [
            MoodEvent(category: .sergi,   title: "Empresyonizm — Avrupa Koleksiyonu",   venue: "Şehir Müzesi",       city: city, timing: "Cumartesi · 11:00",  price: "₺120",     matchPercent: 91),
            MoodEvent(category: .konser,  title: "Devlet Senfoni Orkestrası",            venue: "Kültür Merkezi",     city: city, timing: "Pazar · 16:00",      price: "₺250",     matchPercent: 84),
            cityWalkingSpots(for: city).first ?? MoodEvent(category: .spor, title: "Açık Hava Yoga Festivali", venue: "Merkezi Park", city: city, timing: "Yarın · 09:00", price: "Ücretsiz", matchPercent: 78),
            MoodEvent(category: .sinema,  title: "Avrupa Film Festivali",                venue: "Arthouse Sineması",  city: city, timing: "Bu akşam · 18:30",  price: "₺90",      matchPercent: 71),
            MoodEvent(category: .tiyatro, title: "Klasik Bale Gösterisi",                venue: "Opera Sahnesi",      city: city, timing: "Cuma · 20:00",       price: "₺300",     matchPercent: 65),
        ]

    case "Doğal":
        return [
            cityWalkingSpots(for: city).first ?? MoodEvent(category: .spor, title: "Sabah Koşusu — Sahil Yolu", venue: "Sahil Parkuru", city: city, timing: "Yarın · 07:30", price: "Ücretsiz", matchPercent: 90),
            MoodEvent(category: .sergi,   title: "Doğa Fotoğrafçılığı Sergisi",       venue: "Kültür Merkezi",     city: city, timing: "Hafta sonu açık",   price: "₺70",      matchPercent: 83),
            MoodEvent(category: .spor,    title: "Açık Hava Yoga — Sabah Seansı",     venue: "Şehir Parkı",        city: city, timing: "Yarın · 09:00",     price: "Ücretsiz", matchPercent: 76),
            MoodEvent(category: .konser,  title: "Akustik Folk Müzik Günü",           venue: "Açık Hava Sahnesi",  city: city, timing: "Pazar · 17:00",     price: "₺150",     matchPercent: 68),
            MoodEvent(category: .sinema,  title: "Doğa Belgeselleri Festivali",       venue: "Açık Hava Sineması", city: city, timing: "Pazar · 14:00",     price: "₺50",      matchPercent: 61),
        ]

    case "Huzurlu":
        return [
            MoodEvent(category: .tiyatro, title: "Çehov — Üç Kız Kardeş",            venue: "Şehir Tiyatrosu",     city: city, timing: "Perşembe · 20:00",  price: "₺180+",    matchPercent: 93),
            MoodEvent(category: .sergi,   title: "Matisse — Renk ve Işık Sergisi",    venue: "Sanat Müzesi",        city: city, timing: "Hafta sonu açık",   price: "₺110",     matchPercent: 87),
            cityWalkingSpots(for: city).first ?? MoodEvent(category: .spor, title: "Doğa Yürüyüşü — Sabah Turu", venue: "Şehir Ormanı", city: city, timing: "Yarın · 08:00", price: "Ücretsiz", matchPercent: 80),
            MoodEvent(category: .sinema,  title: "Arthouse Sinema — Özel Seçki",      venue: "Küçük Sinema Salonu", city: city, timing: "Bu akşam · 18:00",  price: "₺90",      matchPercent: 73),
            MoodEvent(category: .konser,  title: "Akustik Jazz Gecesi",               venue: "Jazz Kulübü",         city: city, timing: "Cuma · 21:00",       price: "₺350",     matchPercent: 65),
        ]

    case "Özgür":
        return [
            cityWalkingSpots(for: city).first ?? MoodEvent(category: .spor, title: "Bisiklet Turu — Boğaz Hattı", venue: "Sahil Yolu", city: city, timing: "Yarın · 10:00", price: "Ücretsiz", matchPercent: 91),
            MoodEvent(category: .konser,  title: "Açık Hava Müzik Festivali",         venue: "Açık Hava Amfitiyatro", city: city, timing: "Bu akşam · 18:00",  price: "₺300+",    matchPercent: 85),
            MoodEvent(category: .sergi,   title: "Soyut Sanat — Özgürlük ve Form",    venue: "Çağdaş Sanat Merkezi",  city: city, timing: "Hafta sonu açık",   price: "₺100",     matchPercent: 78),
            MoodEvent(category: .spor,    title: "Sörf & Paddle Board Etkinliği",     venue: "Sahil Spor Alanı",      city: city, timing: "Cumartesi · 11:00",  price: "₺200",     matchPercent: 70),
            MoodEvent(category: .sinema,  title: "Yol Filmleri Özel Seçkisi",         venue: "Açık Hava Sineması",    city: city, timing: "Pazar · 20:00",      price: "₺80",      matchPercent: 63),
        ]

    case "Derin":
        return [
            MoodEvent(category: .tiyatro, title: "Hamlet — Devlet Tiyatrosu",         venue: "Büyük Tiyatro Sahnesi", city: city, timing: "Cuma · 20:30",       price: "₺260+",    matchPercent: 94),
            MoodEvent(category: .sergi,   title: "Çağdaş Sanat — Hafıza ve Kimlik",   venue: "Şehir Müzesi",          city: city, timing: "Ay sonuna kadar",    price: "₺140",     matchPercent: 88),
            MoodEvent(category: .konser,  title: "Post-Rock Gece — Enstrümantal",      venue: "Küçük Konser Salonu",   city: city, timing: "Cumartesi · 21:00",  price: "₺300",     matchPercent: 81),
            MoodEvent(category: .sinema,  title: "Bağımsız Film Festivali",            venue: "Arthouse Sineması",     city: city, timing: "Bu akşam · 20:00",  price: "₺80",      matchPercent: 74),
            MoodEvent(category: .spor,    title: "Meditasyon ve Nefes Atölyesi",       venue: "Kültür Merkezi",        city: city, timing: "Pazar · 10:00",      price: "₺120",     matchPercent: 67),
        ]

    case "Nostaljik":
        return [
            MoodEvent(category: .konser,  title: "80'ler & 90'lar — Nostalji Gecesi", venue: "Büyük Konser Salonu",   city: city, timing: "Cumartesi · 21:00",  price: "₺350+",    matchPercent: 95),
            MoodEvent(category: .sinema,  title: "Klasik Film Marathonu",              venue: "Arthouse Sineması",     city: city, timing: "Bu akşam · 19:00",  price: "₺90",      matchPercent: 88),
            MoodEvent(category: .tiyatro, title: "Müzikal — Bir Zamanlar Şehirde",    venue: "Büyük Tiyatro Sahnesi", city: city, timing: "Cuma · 20:00",       price: "₺280+",    matchPercent: 81),
            MoodEvent(category: .sergi,   title: "Fotoğraf Arşivi — Şehrin Belleği",  venue: "Tarih Müzesi",          city: city, timing: "Ay sonuna kadar",    price: "₺80",      matchPercent: 74),
            MoodEvent(category: .spor,    title: "Yavaş Dans Gecesi — Swing Kursu",   venue: "Kültür Merkezi",        city: city, timing: "Perşembe · 20:30",   price: "₺150",     matchPercent: 67),
        ]

    case "Gizemli":
        return [
            MoodEvent(category: .sergi,   title: "Sürrealizm — Rüya Dünyaları",       venue: "Çağdaş Sanat Müzesi",   city: city, timing: "Hafta sonu açık",   price: "₺130",     matchPercent: 95),
            MoodEvent(category: .tiyatro, title: "Karanlık Sahne — Gerilim Tiyatrosu", venue: "Küçük Tiyatro",         city: city, timing: "Perşembe · 20:00",  price: "₺200",     matchPercent: 89),
            MoodEvent(category: .konser,  title: "Gece Yarısı Jazz Seansı",            venue: "Jazz Bar",              city: city, timing: "Bu gece · 23:00",   price: "₺180",     matchPercent: 82),
            MoodEvent(category: .sinema,  title: "Noir Sinema Gecesi",                  venue: "Arthouse Sineması",     city: city, timing: "Cuma · 22:00",      price: "₺70",      matchPercent: 75),
            MoodEvent(category: .spor,    title: "Gece Koşusu — Sahil Yolu",           venue: "Sahil Parkuru",         city: city, timing: "Bu gece · 21:30",   price: "Ücretsiz", matchPercent: 68),
        ]

    case "Hassas":
        return [
            MoodEvent(category: .konser,  title: "Oda Müziği Gecesi — Yaylılar",      venue: "Küçük Konser Salonu",   city: city, timing: "Cuma · 20:00",       price: "₺220",     matchPercent: 93),
            MoodEvent(category: .sergi,   title: "Empresyonizm — Duygu ve Renk",      venue: "Sanat Müzesi",          city: city, timing: "Hafta sonu açık",   price: "₺110",     matchPercent: 86),
            MoodEvent(category: .tiyatro, title: "Virginia Woolf — Dalgalar",         venue: "Şehir Tiyatrosu",       city: city, timing: "Perşembe · 20:00",  price: "₺180+",    matchPercent: 79),
            MoodEvent(category: .sinema,  title: "Romantik Film Özel Seçkisi",        venue: "Küçük Sinema Salonu",   city: city, timing: "Bu akşam · 18:30",  price: "₺90",      matchPercent: 72),
            MoodEvent(category: .spor,    title: "Resim Atölyesi — Serbest Çizim",    venue: "Kültür Merkezi",        city: city, timing: "Cumartesi · 14:00",  price: "₺150",     matchPercent: 65),
        ]

    case "Sessiz":
        return [
            MoodEvent(category: .sinema,  title: "Film Maratonu — Arthouse Seçkisi",  venue: "Sinema Salonu",          city: city, timing: "Bu akşam · 17:00",  price: "₺70",      matchPercent: 88),
            MoodEvent(category: .sergi,   title: "Minimalizm — Az Çoktur Sergisi",    venue: "Sanat Galerisi",         city: city, timing: "Hafta sonu açık",   price: "₺90",      matchPercent: 82),
            MoodEvent(category: .tiyatro, title: "Tek Kişilik Gösteri — Sessizlik",   venue: "Küçük Sahne",            city: city, timing: "Cuma · 20:00",      price: "₺160",     matchPercent: 74),
            MoodEvent(category: .spor,    title: "Tai Chi — Sabah Seansı",            venue: "Şehir Parkı",            city: city, timing: "Yarın · 08:00",     price: "Ücretsiz", matchPercent: 67),
            MoodEvent(category: .konser,  title: "Ambient Music Gecesi",              venue: "Küçük Konser Salonu",    city: city, timing: "Cumartesi · 22:00", price: "₺200",     matchPercent: 60),
        ]

    case "Nötr":
        return Array((cityWalkingSpots(for: city) + [
            MoodEvent(category: .sergi,   title: "Doğa Fotoğrafçılığı Sergisi",  venue: "Kültür Merkezi",     city: city, timing: "Hafta sonu açık",  price: "₺70",  matchPercent: 78),
            MoodEvent(category: .sinema,  title: "Doğa Belgeselleri Festivali",  venue: "Açık Hava Sineması", city: city, timing: "Pazar · 14:00",    price: "₺50",  matchPercent: 71),
            MoodEvent(category: .konser,  title: "Akustik Folk Müzik Günü",      venue: "Açık Hava Sahnesi",  city: city, timing: "Pazar · 17:00",    price: "₺150", matchPercent: 63),
        ]).prefix(5))

    default:
        return [
            MoodEvent(category: .konser,  title: "Müzik Festivali — Açık Hava",        venue: "Açık Hava Sahnesi",      city: city, timing: "Bu hafta sonu",       price: "₺300+",    matchPercent: 80),
            MoodEvent(category: .sergi,   title: "Çağdaş Sanat Sergisi",               venue: "Sanat Galerisi",         city: city, timing: "Hafta sonu açık",     price: "₺100",     matchPercent: 74),
            MoodEvent(category: .sinema,  title: "Film Festivali",                      venue: "Sinema Salonu",          city: city, timing: "Bu akşam",            price: "₺90",      matchPercent: 68),
        ]
        }
    }()
    // Biletix URL'ini SADECE gerçek bilet gerektiren kategorilere (konser, tiyatro, sergi) ekle.
    // Aktivite ve yürüyüş noktaları ücretsiz olduğu için Biletix'e yönlendirilmez —
    // bunlar için EventCardView harita CTA'sı üretir.
    // Gerçek TM API etkinlikleri event.url alanından kendi Biletix linkini zaten taşır.
    let ticketedCategories: Set<EventCategory> = [.konser, .tiyatro, .sergi]
    return base
        .filter { ![.spor, .sinema].contains($0.category) }
        .map { event in
            guard event.sourceURL == nil else { return event }
            guard ticketedCategories.contains(event.category) else { return event }
            return MoodEvent(
                id: event.id,
                category: event.category,
                title: event.title,
                venue: event.venue,
                city: event.city,
                timing: event.timing,
                price: event.price,
                matchPercent: event.matchPercent,
                sourceURL: biletixFallbackURL(city: city, category: event.category),
                kind: event.kind,
                reason: event.reason,
                sourceLabel: event.sourceLabel
            )
        }
}

// MARK: - City-specific walking / outdoor spots
// Real venue names per il — used for Sakin, Işıklı and Temiz moods.
// Provides a genuine local experience regardless of which city is selected.

func cityWalkingSpots(for city: String) -> [MoodEvent] {
    let c = city.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
    switch c {
    case "istanbul":
        return [
            MoodEvent(category: .aktivite, title: "Belgrad Ormanı Doğa Yürüyüşü",    venue: "Belgrad Ormanı",              city: city, timing: "Yarın · 08:00",       price: "Ücretsiz", matchPercent: 91),
            MoodEvent(category: .aktivite, title: "Adalar Bisiklet & Yürüyüş Turu",   venue: "Büyükada",                   city: city, timing: "Hafta sonu · 09:00", price: "₺80+",     matchPercent: 86),
            MoodEvent(category: .aktivite, title: "Boğaz Sahil Koşusu",               venue: "Ortaköy – Arnavutköy Hattı", city: city, timing: "Yarın · 07:30",       price: "Ücretsiz", matchPercent: 82),
        ]
    case "ankara":
        return [
            MoodEvent(category: .aktivite, title: "Eymir Gölü Çevre Yolu Koşusu",    venue: "Eymir Gölü",                 city: city, timing: "Yarın · 07:30",       price: "Ücretsiz", matchPercent: 90),
            MoodEvent(category: .aktivite, title: "AOÇ Sabah Yürüyüşü",              venue: "Atatürk Orman Çiftliği",     city: city, timing: "Yarın · 08:00",       price: "Ücretsiz", matchPercent: 84),
            MoodEvent(category: .aktivite, title: "Soğuksu Milli Parkı Trekking",    venue: "Kızılcahamam",               city: city, timing: "Hafta sonu · 09:00", price: "₺30",      matchPercent: 79),
        ]
    case "izmir":
        return [
            MoodEvent(category: .aktivite, title: "Kordon Sabah Koşusu",             venue: "İzmir Kordon",               city: city, timing: "Yarın · 07:00",       price: "Ücretsiz", matchPercent: 92),
            MoodEvent(category: .aktivite, title: "Yamanlar Dağı Doğa Yürüyüşü",    venue: "Yamanlar",                   city: city, timing: "Hafta sonu · 08:30", price: "Ücretsiz", matchPercent: 87),
            MoodEvent(category: .aktivite, title: "Buca Gölet Çevre Turu",           venue: "Buca Gölet",                 city: city, timing: "Yarın · 08:00",       price: "Ücretsiz", matchPercent: 81),
        ]
    case "bursa":
        return [
            MoodEvent(category: .aktivite, title: "Uludağ Doğa Yürüyüşü",           venue: "Uludağ Milli Parkı",         city: city, timing: "Hafta sonu · 09:00", price: "₺50",      matchPercent: 93),
            MoodEvent(category: .aktivite, title: "Mudanya Sahil Yolu",              venue: "Mudanya Kordon",             city: city, timing: "Yarın · 08:00",       price: "Ücretsiz", matchPercent: 86),
            MoodEvent(category: .aktivite, title: "Cumalıkızık Köy Yürüyüşü",       venue: "Cumalıkızık",                city: city, timing: "Hafta sonu · 10:00", price: "Ücretsiz", matchPercent: 80),
        ]
    case "antalya":
        return [
            MoodEvent(category: .aktivite, title: "Likya Yolu — Olympos Etabı",     venue: "Olympos – Çıralı",           city: city, timing: "Hafta sonu · 08:00", price: "Ücretsiz", matchPercent: 94),
            MoodEvent(category: .aktivite, title: "Düden Şelalesi Doğa Turu",       venue: "Düden Şelalesi Parkı",       city: city, timing: "Yarın · 09:00",       price: "Ücretsiz", matchPercent: 88),
            MoodEvent(category: .aktivite, title: "Konyaaltı Sahil Koşusu",         venue: "Konyaaltı Sahili",           city: city, timing: "Yarın · 07:30",       price: "Ücretsiz", matchPercent: 83),
        ]
    case "adana":
        return [
            MoodEvent(category: .aktivite, title: "Seyhan Barajı Koşu Parkuru",     venue: "Seyhan Baraj Gölü",          city: city, timing: "Yarın · 07:30",       price: "Ücretsiz", matchPercent: 88),
            MoodEvent(category: .aktivite, title: "Toros Dağları Trekking Turu",    venue: "Pozantı Vadisi",             city: city, timing: "Hafta sonu · 08:00", price: "₺60",      matchPercent: 82),
            MoodEvent(category: .aktivite, title: "Karataş Sahil Yürüyüşü",         venue: "Karataş Sahili",             city: city, timing: "Yarın · 08:00",       price: "Ücretsiz", matchPercent: 77),
        ]
    case "gaziantep":
        return [
            MoodEvent(category: .aktivite, title: "Rumkale & Fırat Kıyısı Yürüyüşü", venue: "Halfeti – Birecik",         city: city, timing: "Hafta sonu · 09:00", price: "₺40",      matchPercent: 89),
            MoodEvent(category: .aktivite, title: "Gaziantep Ormanı Sabah Koşusu",  venue: "Gaziantep Ormanı",           city: city, timing: "Yarın · 08:00",       price: "Ücretsiz", matchPercent: 83),
            MoodEvent(category: .aktivite, title: "Alleben Deresi Doğa Yürüyüşü",   venue: "Alleben Vadisi",             city: city, timing: "Hafta sonu · 09:30", price: "Ücretsiz", matchPercent: 78),
        ]
    case "konya":
        return [
            MoodEvent(category: .aktivite, title: "Sille Köyü Tarihi Yürüyüş",      venue: "Sille",                      city: city, timing: "Hafta sonu · 10:00", price: "Ücretsiz", matchPercent: 88),
            MoodEvent(category: .aktivite, title: "Beyşehir Gölü Doğa Yürüyüşü",   venue: "Beyşehir",                   city: city, timing: "Hafta sonu · 09:00", price: "Ücretsiz", matchPercent: 83),
            MoodEvent(category: .aktivite, title: "Mevlana Parkı Sabah Yürüyüşü",   venue: "Mevlana Parkı",              city: city, timing: "Yarın · 08:00",       price: "Ücretsiz", matchPercent: 77),
        ]
    case "mersin":
        return [
            MoodEvent(category: .aktivite, title: "Cennet Mağarası & Obruk Turu",   venue: "Silifke – Cennet Mağarası",  city: city, timing: "Hafta sonu · 09:00", price: "₺50",      matchPercent: 93),
            MoodEvent(category: .aktivite, title: "Kızkalesi Sahil Yürüyüşü",       venue: "Kızkalesi Sahili",           city: city, timing: "Yarın · 08:00",       price: "Ücretsiz", matchPercent: 87),
            MoodEvent(category: .aktivite, title: "Tarsus Şelalesi Doğa Turu",      venue: "Tarsus Şelalesi",            city: city, timing: "Hafta sonu · 09:00", price: "₺30",      matchPercent: 81),
        ]
    case "kocaeli":
        return [
            MoodEvent(category: .aktivite, title: "Ormanya Doğa Rotası",                venue: "Ormanya",                    city: city, timing: "Yarın · 08:30",       price: "Ücretsiz", matchPercent: 93),
            MoodEvent(category: .aktivite, title: "Başiskele Sahil Yürüyüşü",          venue: "Başiskele Sahili",           city: city, timing: "Yarın · 07:30",       price: "Ücretsiz", matchPercent: 90),
            MoodEvent(category: .aktivite, title: "Darıca Sahil ve Kale Çevresi",      venue: "Darıca Sahili",              city: city, timing: "Hafta sonu · 09:00", price: "Ücretsiz", matchPercent: 87),
            MoodEvent(category: .aktivite, title: "Yuvacık Barajı Çevre Rotası",       venue: "Yuvacık Barajı",             city: city, timing: "Hafta sonu · 08:30", price: "Ücretsiz", matchPercent: 85),
            MoodEvent(category: .aktivite, title: "Maşukiye · Sapanca Yakınları Kaçamağı", venue: "Maşukiye",                city: city, timing: "Pazar · 10:00",      price: "₺50",      matchPercent: 82),
        ]
    case "sakarya":
        return [
            MoodEvent(category: .aktivite, title: "Sapanca Gölü Kıyı Yürüyüşü",        venue: "Sapanca Gölü",               city: city, timing: "Yarın · 08:00",       price: "Ücretsiz", matchPercent: 93),
            MoodEvent(category: .aktivite, title: "Acarlar Longozu Doğa Rotası",       venue: "Acarlar Longozu",            city: city, timing: "Hafta sonu · 09:00", price: "Ücretsiz", matchPercent: 89),
            MoodEvent(category: .aktivite, title: "Poyrazlar Gölü Sabah Kaçamağı",     venue: "Poyrazlar Gölü",             city: city, timing: "Yarın · 08:30",       price: "Ücretsiz", matchPercent: 86),
            MoodEvent(category: .aktivite, title: "Karasu Sahil Hattı Yürüyüşü",       venue: "Karasu Sahili",              city: city, timing: "Pazar · 09:30",      price: "Ücretsiz", matchPercent: 84),
            MoodEvent(category: .aktivite, title: "Taraklı · Sessiz Sokaklar Rotası",  venue: "Taraklı",                    city: city, timing: "Hafta sonu · 10:30", price: "₺40",      matchPercent: 80),
        ]
    case "diyarbakir":
        return [
            MoodEvent(category: .aktivite, title: "Hevsel Bahceleri Sabah Turu",    venue: "Hevsel Bahceleri",           city: city, timing: "Yarin · 07:30",       price: "Ucretsiz", matchPercent: 91),
            MoodEvent(category: .aktivite, title: "Dicle Nehri Sahil Yuruyusu",     venue: "Dicle Kenari",               city: city, timing: "Yarin · 08:00",       price: "Ucretsiz", matchPercent: 85),
            MoodEvent(category: .aktivite, title: "Karacadag Trekking Turu",        venue: "Karacadag Volkanik Sahasi",  city: city, timing: "Hafta sonu · 08:00", price: "₺40",      matchPercent: 80),
        ]
    default:
        return [
            MoodEvent(category: .aktivite, title: "Sehir Ormani Doga Yuruyusu",    venue: "Sehir Ormani",               city: city, timing: "Yarin · 08:00",       price: "Ucretsiz", matchPercent: 82),
            MoodEvent(category: .aktivite, title: "Merkezi Park Sabah Kosusu",      venue: "Sehir Merkezi Parki",        city: city, timing: "Yarin · 07:30",       price: "Ucretsiz", matchPercent: 76),
        ]
    }
}

// MARK: - City-specific sports events
// Real venue names per city, differentiated by mood intensity.
// "Ateşli"  → derby/rivalry football + championship basketball
// "Coşkulu" → Süper Lig match + city marathon / sports festival

func citySportsEvents(for city: String, mood: String) -> [MoodEvent] {
    let c = city.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
    let intense = (mood == "Ateşli")

    switch c {

    case "istanbul":
        if intense {
            return [
                MoodEvent(category: .spor, title: "Süper Lig — Kadıköy Derbisi",           venue: "Ülker Stadyumu",                   city: city, timing: "Yarın · 20:00",       price: "₺450+",    matchPercent: 93),
                MoodEvent(category: .spor, title: "Süper Lig — Bej-Siyah Klasiği",          venue: "Vodafone Park",                    city: city, timing: "Cumartesi · 19:00",   price: "₺400+",    matchPercent: 89),
                MoodEvent(category: .spor, title: "BSL Basketbol — Playoff Finali",          venue: "Sinan Erdem Spor Salonu",           city: city, timing: "Cuma · 20:30",        price: "₺220+",    matchPercent: 83),
            ]
        } else {
            return [
                MoodEvent(category: .spor, title: "Süper Lig — Rams Park'ta Maç",           venue: "Rams Park",                        city: city, timing: "Pazar · 19:00",       price: "₺300+",    matchPercent: 88),
                MoodEvent(category: .spor, title: "Başakşehir FK — İç Saha Maçı",           venue: "Başakşehir Fatih Terim Stadyumu",  city: city, timing: "Cumartesi · 19:30",   price: "₺180+",    matchPercent: 80),
                MoodEvent(category: .spor, title: "İstanbul Maratonu — Kayıtlar Açık",       venue: "Boğaz Köprüsü Kalkış Noktası",    city: city, timing: "Önümüzdeki ay",       price: "₺150",     matchPercent: 74),
            ]
        }

    case "ankara":
        if intense {
            return [
                MoodEvent(category: .spor, title: "Süper Lig — Eryaman Stadı Derbisi",      venue: "Eryaman Stadyumu",                 city: city, timing: "Yarın · 19:00",       price: "₺280+",    matchPercent: 91),
                MoodEvent(category: .spor, title: "BSL Basketbol — Türk Telekom Arena",      venue: "Ankara Arena",                     city: city, timing: "Cuma · 20:00",        price: "₺180+",    matchPercent: 84),
            ]
        } else {
            return [
                MoodEvent(category: .spor, title: "Gençlerbirliği — İç Saha Maçı",          venue: "Eryaman Stadyumu",                 city: city, timing: "Hafta sonu · 19:00", price: "₺200+",    matchPercent: 84),
                MoodEvent(category: .spor, title: "Ankara Bisiklet Festivali",               venue: "Atatürk Orman Çiftliği",           city: city, timing: "Pazar · 09:00",       price: "Ücretsiz", matchPercent: 76),
            ]
        }

    case "izmir":
        if intense {
            return [
                MoodEvent(category: .spor, title: "Süper Lig — Alsancak'ta Derbi",          venue: "Alsancak Aziz Kocaoğlu Stadyumu",  city: city, timing: "Yarın · 19:00",       price: "₺250+",    matchPercent: 90),
                MoodEvent(category: .spor, title: "BSL Basketbol — Tınaztepe Playoff",       venue: "Tınaztepe Spor Salonu",            city: city, timing: "Cumartesi · 20:00",   price: "₺160+",    matchPercent: 83),
            ]
        } else {
            return [
                MoodEvent(category: .spor, title: "Altay FK — İç Saha Maçı",                venue: "Alsancak Aziz Kocaoğlu Stadyumu",  city: city, timing: "Hafta sonu · 19:30", price: "₺180+",    matchPercent: 83),
                MoodEvent(category: .spor, title: "İzmir Koşu Festivali",                    venue: "Kordon",                           city: city, timing: "Pazar · 08:30",       price: "₺80",      matchPercent: 77),
            ]
        }

    case "bursa":
        if intense {
            return [
                MoodEvent(category: .spor, title: "Süper Lig — Timsah Arena Maçı",          venue: "Timsah Arena",                     city: city, timing: "Yarın · 19:30",       price: "₺280+",    matchPercent: 92),
                MoodEvent(category: .spor, title: "BSL Basketbol — Uludağ Playoff",          venue: "Bursa Arena",                      city: city, timing: "Cuma · 20:00",        price: "₺150+",    matchPercent: 84),
            ]
        } else {
            return [
                MoodEvent(category: .spor, title: "Bursaspor — İç Saha Maçı",               venue: "Timsah Arena",                     city: city, timing: "Hafta sonu · 19:00", price: "₺200+",    matchPercent: 85),
                MoodEvent(category: .spor, title: "Uludağ Trail Koşusu",                     venue: "Uludağ Milli Parkı",               city: city, timing: "Hafta sonu · 08:00", price: "₺120",     matchPercent: 79),
            ]
        }

    case "antalya":
        if intense {
            return [
                MoodEvent(category: .spor, title: "Süper Lig — Antalya Stadyumunda Derbi",  venue: "Antalya Stadyumu",                 city: city, timing: "Yarın · 19:00",       price: "₺250+",    matchPercent: 89),
            ]
        } else {
            return [
                MoodEvent(category: .spor, title: "Antalyaspor — İç Saha Maçı",             venue: "Antalya Stadyumu",                 city: city, timing: "Hafta sonu · 19:30", price: "₺180+",    matchPercent: 82),
                MoodEvent(category: .spor, title: "Antalya Maratonu",                        venue: "Konyaaltı Sahil Yolu",             city: city, timing: "Pazar · 08:00",       price: "₺100",     matchPercent: 76),
            ]
        }

    case "adana":
        if intense {
            return [
                MoodEvent(category: .spor, title: "Süper Lig — Yeni Adana Stadı Derbisi",   venue: "Yeni Adana Stadyumu",              city: city, timing: "Yarın · 19:30",       price: "₺200+",    matchPercent: 89),
            ]
        } else {
            return [
                MoodEvent(category: .spor, title: "Adana Demirspor — İç Saha Maçı",         venue: "Yeni Adana Stadyumu",              city: city, timing: "Hafta sonu · 19:00", price: "₺150+",    matchPercent: 82),
            ]
        }

    case "gaziantep":
        if intense {
            return [
                MoodEvent(category: .spor, title: "Süper Lig — Kalyon Stadyumu Derbisi",    venue: "Kalyon Stadyumu",                  city: city, timing: "Yarın · 19:00",       price: "₺220+",    matchPercent: 90),
            ]
        } else {
            return [
                MoodEvent(category: .spor, title: "Gaziantep FK — İç Saha Maçı",            venue: "Kalyon Stadyumu",                  city: city, timing: "Hafta sonu · 19:00", price: "₺180+",    matchPercent: 83),
            ]
        }

    case "konya":
        if intense {
            return [
                MoodEvent(category: .spor, title: "Süper Lig — Konya Büyükşehir Derbisi",   venue: "Konya Büyükşehir Stadyumu",        city: city, timing: "Yarın · 19:00",       price: "₺220+",    matchPercent: 88),
            ]
        } else {
            return [
                MoodEvent(category: .spor, title: "Konyaspor — İç Saha Maçı",               venue: "Konya Büyükşehir Stadyumu",        city: city, timing: "Hafta sonu · 19:30", price: "₺160+",    matchPercent: 82),
            ]
        }

    case "mersin":
        return [
            MoodEvent(category: .spor, title: "Mersin İdmanyurdu — İç Saha Maçı",           venue: "Mersin Stadyumu",                  city: city, timing: "Hafta sonu · 19:00", price: "₺120+",    matchPercent: 80),
        ]

    case "diyarbakir":
        return [
            MoodEvent(category: .spor, title: "Diyarbakirspor — İç Saha Maçı",              venue: "Diyarbakır Stadyumu",              city: city, timing: "Hafta sonu · 16:00", price: "₺100+",    matchPercent: 78),
        ]

    default:
        if intense {
            return [
                MoodEvent(category: .spor, title: "Süper Lig — Şehir Derbisi",               venue: "Şehir Stadyumu",                  city: city, timing: "Yarın · 20:00",       price: "₺350+",    matchPercent: 89),
                MoodEvent(category: .spor, title: "BSL Basketbol — Şampiyonluk Maçı",        venue: "Kapalı Spor Salonu",               city: city, timing: "Cumartesi · 19:00",   price: "₺180+",    matchPercent: 83),
            ]
        } else {
            return [
                MoodEvent(category: .spor, title: "Süper Lig Maçı",                          venue: "Şehir Stadyumu",                  city: city, timing: "Yarın · 19:00",       price: "₺250+",    matchPercent: 86),
                MoodEvent(category: .spor, title: "Şehir Bisiklet Maratonu",                  venue: "Merkezi Kalkış Noktası",          city: city, timing: "Pazar · 09:00",       price: "₺50",      matchPercent: 79),
            ]
        }
    }
}

// MARK: - Biletix Browse Cards (honest fallback — no fictional event names)
// Used when the Ticketmaster API key is missing or all API calls return empty.
// Returns real cityWalkingSpots + direct Biletix category search links.
// These URLs are always valid and never 404.
func biletixBrowseCards(for moodLabel: String, city: String = "İstanbul") -> [MoodEvent] {
    let normalizedMood = canonicalMoodLabel(moodLabel)

    let preferred: [EventCategory] = {
        switch normalizedMood {
        case "Ateşli", "Coşkulu": return [.konser, .tiyatro, .sergi]
        case "Mutlu":             return [.sergi, .konser, .tiyatro]
        case "Doğal", "Özgür":   return [.konser, .sergi, .tiyatro]
        case "Huzurlu":          return [.tiyatro, .sergi, .konser]
        case "Derin":            return [.tiyatro, .sergi, .konser]
        case "Nostaljik":        return [.konser, .tiyatro, .sergi]
        case "Gizemli":          return [.sergi, .tiyatro, .konser]
        case "Hassas":           return [.konser, .sergi, .tiyatro]
        case "Sessiz":           return [.sergi, .tiyatro, .konser]
        default:                 return [.konser, .sergi, .tiyatro]
        }
    }()

    var cards: [MoodEvent] = []

    // Real outdoor spots for calm/nature moods — Apple Maps links, always work
    if ["Doğal", "Özgür", "Huzurlu", "Nötr"].contains(normalizedMood),
       let walk = cityWalkingSpots(for: city).first {
        cards.append(walk)
    }

    // Biletix category search cards — honest "browse" links, never 404
    for (i, category) in preferred.prefix(3).enumerated() {
        guard let url = biletixFallbackURL(city: city, category: category) else { continue }
        let title: String
        switch category {
        case .konser:  title = "\(city) Konserleri"
        case .tiyatro: title = "\(city) Tiyatro & Sahne"
        case .sergi:   title = "\(city) Sergi & Müze"
        default:       title = "\(city) \(category.rawValue) Etkinlikleri"
        }
        cards.append(MoodEvent(
            category: category,
            title: title,
            venue: "Biletix",
            city: city,
            timing: "Güncel etkinlikleri gör",
            price: "",
            matchPercent: max(80 - i * 10, 55),
            sourceURL: url,
            kind: .liveEvent,
            isFallbackURL: true
        ))
    }

    return cards
}

// MARK: - Biletix URL Builder
// Real TM API events use event.url which is a direct Biletix ticket link.
// Browse cards use category search pages that are always valid.

func biletixFallbackURL(city: String, category: EventCategory) -> URL? {
    let cityCode = biletixCityCode(for: city)
    let categoryParam = biletixCategoryParam(for: category)
    let urlString = "https://www.biletix.com/arama/\(cityCode)/tr#!\(categoryParam)"
    return URL(string: urlString)
}

/// Maps Turkish city names to Biletix city code slugs (uppercase, ASCII).
private func biletixCityCode(for city: String) -> String {
    let normalized = city.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
    switch normalized {
    case "istanbul":   return "ISTANBUL"
    case "ankara":     return "ANKARA"
    case "izmir":      return "IZMIR"
    case "bursa":      return "BURSA"
    case "antalya":    return "ANTALYA"
    case "adana":      return "ADANA"
    case "gaziantep":  return "GAZIANTEP"
    case "konya":      return "KONYA"
    case "mersin":     return "MERSIN"
    case "eskisehir":  return "ESKISEHIR"
    case "kayseri":    return "KAYSERI"
    case "samsun":     return "SAMSUN"
    case "diyarbakir": return "DIYARBAKIR"
    case "trabzon":    return "TRABZON"
    case "kocaeli":    return "KOCAELI"
    case "sakarya":    return "SAKARYA"
    case "alanya":     return "ALANYA"
    case "manisa":     return "MANISA"
    case "mugla":      return "MUGLA"
    case "denizli":    return "DENIZLI"
    case "aydin":      return "AYDIN"
    case "hatay":      return "HATAY"
    case "sanlıurfa", "sanliurfa": return "SANLIURFA"
    case "mardin":     return "MARDIN"
    default:           return "TURKIYE"
    }
}

/// Maps EventCategory to Biletix category filter slug.
private func biletixCategoryParam(for category: EventCategory) -> String {
    switch category {
    case .konser:          return "categoryName=M%C3%BCzik"
    case .tiyatro:         return "categoryName=Tiyatro"
    case .sergi:           return "categoryName=Sergi%20%26%20M%C3%BCze"
    case .aktivite:        return "categoryName=Spor%20%26%20Aktivite"
    case .spor:            return "categoryName=Spor%20%26%20Aktivite"
    case .sinema:          return "categoryName=Festival"
    }
}

// MARK: - Main Sheet View

struct MoodEventsSheet: View {
    let entry: DailyEntry
    @Environment(\.dismiss) private var dismiss
    @State private var selectedCategory: EventCategory? = nil
    @AppStorage(ONETokens.cityPreferenceKey) private var preferredCity: String = ONETokens.defaultCity

    @State private var sections: [RecommendationSection] = []
    @State private var isLoading: Bool = true

    private var filteredSections: [RecommendationSection] {
        guard let cat = selectedCategory else { return sections }

        return sections.compactMap { section in
            let items = section.items.filter { $0.category == cat }
            guard !items.isEmpty else { return nil }

            return RecommendationSection(
                id: section.id,
                title: section.title,
                subtitle: section.subtitle,
                items: items
            )
        }
    }

    private var filteredItemCount: Int {
        filteredSections.reduce(0) { $0 + $1.items.count }
    }

    private var visibleCategories: [EventCategory] {
        EventCategory.allCases.filter { ![.spor, .sinema].contains($0) }
    }

    var body: some View {
        ZStack(alignment: .top) {
            ONETokens.oneCream.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {

                    // Header
                    VStack(alignment: .leading, spacing: 14) {
                        // Mood + city pill row
                        HStack(spacing: 0) {
                            // Mood pill (static)
                            HStack(spacing: 7) {
                                Circle()
                                    .fill(entry.moodColor)
                                    .frame(width: 8, height: 8)
                                Text(entry.moodLabel.uppercased())
                                    .monoBase(tracking: 1.5)
                                    .foregroundColor(ONETokens.oneCharcoal)
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(Capsule().fill(entry.moodColor.opacity(0.15)))

                            Text(" · ")
                                .monoBase(tracking: 0.5)
                                .foregroundColor(ONETokens.oneAsh)
                                .padding(.horizontal, 2)

                            // City pill — tappable Menu
                            Menu {
                                ForEach(ONETokens.availableCities, id: \.self) { city in
                                    Button(action: { preferredCity = city }) {
                                        HStack {
                                            Text(city)
                                            if city == preferredCity {
                                                Image(systemName: "checkmark")
                                            }
                                        }
                                    }
                                }
                            } label: {
                                HStack(spacing: 5) {
                                    Text(preferredCity.uppercased())
                                        .monoBase(tracking: 1.5)
                                        .foregroundColor(ONETokens.oneCharcoal)
                                    Image(systemName: "chevron.down")
                                        .font(.system(size: 8, weight: .semibold))
                                        .foregroundColor(ONETokens.oneAsh)
                                }
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(
                                    Capsule()
                                        .fill(ONETokens.oneCreamMid)
                                        .overlay(Capsule().stroke(ONETokens.oneStone, lineWidth: 0.5))
                                )
                            }
                        }

                        // Headline — bold italic serif
                        Text(NSLocalizedString("moodEvents.ourPicks", comment: ""))
                            .font(.system(size: 32, weight: .black, design: .default))
                            .italic()
                            .foregroundColor(ONETokens.oneInk)
                            .lineSpacing(2)
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 32)
                    .padding(.bottom, 22)

                    // Category filter pills
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            EventFilterPill(label: NSLocalizedString("discover.all", comment: ""), isSelected: selectedCategory == nil) {
                                withAnimation(ONEAnimation.micro) { selectedCategory = nil }
                            }
                            ForEach(visibleCategories) { cat in
                                EventFilterPill(label: cat.rawValue, isSelected: selectedCategory == cat) {
                                    withAnimation(ONEAnimation.micro) {
                                        selectedCategory = selectedCategory == cat ? nil : cat
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 24)
                    }
                    .padding(.bottom, 20)

                    // Recommendation cards
                    VStack(spacing: 20) {
                        if isLoading {
                            ProgressView()
                                .padding(.top, 40)
                                .tint(ONETokens.oneInk)
                        } else if filteredItemCount == 0 {
                            Text(NSLocalizedString("moodEvents.noEvents", comment: ""))
                                .font(.system(size: 16, weight: .medium, design: .default))
                                .foregroundColor(ONETokens.oneAsh)
                                .padding(.top, 40)
                        } else {
                            ForEach(filteredSections) { section in
                                VStack(alignment: .leading, spacing: 10) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(section.title)
                                            .font(.system(size: 18, weight: .bold, design: .default))
                                            .foregroundColor(ONETokens.oneInk)
                                        Text(section.subtitle)
                                            .monoSM(tracking: 0.3)
                                            .foregroundColor(ONETokens.oneAsh)
                                    }

                                    ForEach(section.items) { event in
                                        MoodEventCard(event: event)
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 48)
                    .animation(.easeInOut(duration: 0.2), value: selectedCategory)
                    .animation(.easeInOut(duration: 0.2), value: isLoading)
                }
            }
        }
        .presentationDragIndicator(.visible)
        .presentationDetents([.large])
        .task(id: preferredCity) {
            if preferredCity == "İzmit" {
                preferredCity = "Kocaeli"
                return
            }
            isLoading = true
            sections = await ActivityRecommendationEngine.shared.fetchSections(for: entry, city: preferredCity)
            withAnimation(.easeInOut(duration: 0.2)) {
                isLoading = false
            }
        }
    }
}

// MARK: - Filter Pill

private struct EventFilterPill: View {
    let label: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 14, weight: .medium, design: .default))
                .foregroundColor(isSelected ? .white : ONETokens.oneCharcoal)
                .padding(.horizontal, 18)
                .padding(.vertical, 9)
                .background(
                    Capsule().fill(isSelected ? ONETokens.oneInk : ONETokens.onePaper)
                )
                .overlay(
                    isSelected ? nil :
                    Capsule().stroke(ONETokens.oneCreamLow, lineWidth: 1)
                )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Event Card

private struct MoodEventCard: View {
    let event: MoodEvent

    var body: some View {
        HStack(spacing: 0) {
            // Colored left border
            Rectangle()
                .fill(event.category.accentColor)
                .frame(width: 3)
                .cornerRadius(1.5)

            VStack(alignment: .leading, spacing: 6) {
                // Category + match %
                HStack(alignment: .center) {
                    HStack(spacing: 6) {
                        Text(event.category.rawValue.uppercased())
                            .monoLabel(tracking: 1.5)
                            .foregroundColor(ONETokens.oneAsh)

                        if let sourceLabel = event.sourceLabel {
                            Text(sourceLabel.uppercased())
                                .monoLabel(tracking: 1.0)
                                .foregroundColor(event.category.accentColor)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Capsule().fill(event.category.accentColor.opacity(0.10)))
                        }
                    }
                    Spacer()
                    Text(String(format: NSLocalizedString("moodEvents.matchPercent", comment: ""), event.matchPercent))
                        .monoLabel(tracking: 0.8)
                        .foregroundColor(ONETokens.moodOrange)
                }

                // Nearby city badge
                if event.isNearbyCity {
                    HStack(spacing: 4) {
                        Image(systemName: "location.circle.fill")
                            .font(.system(size: 9))
                        Text(String(format: NSLocalizedString("moodEvents.nearbyCity", comment: ""), event.city))
                            .monoLabel(tracking: 0.5)
                    }
                    .foregroundColor(ONETokens.oneStone)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(ONETokens.oneCreamMid))
                }

                // Event title
                Text(event.title)
                    .font(.system(size: 18, weight: .bold, design: .default))
                    .foregroundColor(ONETokens.oneInk)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                // Venue
                Text("\(event.venue), \(event.city)")
                    .monoSM(tracking: 0.5)
                    .foregroundColor(ONETokens.oneAsh)

                if let reason = event.reason {
                    Text(reason)
                        .font(.system(size: 14, weight: .medium, design: .default))
                        .foregroundColor(ONETokens.oneCharcoal)
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer().frame(height: 2)

                // Timing + Price
                HStack(alignment: .center) {
                    Text(event.timing)
                        .monoSM(tracking: 0.5)
                        .foregroundColor(ONETokens.oneCharcoal)
                    Spacer()
                    Text(event.price)
                        .font(.system(size: 16, weight: .bold, design: .default))
                        .foregroundColor(ONETokens.oneInk)
                }

                // Smart CTA: bilet gerektiren → Biletix, aktivite/micro → Harita, diğer → gizle
                eventCTA(for: event)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 16)
        }
        .background(ONETokens.onePaper)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 2)
    }

    // MARK: - Smart CTA
    // Bilet gerektiren (konser/tiyatro/sergi) → Biletix butonu
    // Aktivite / micro-activity → Apple Haritalar butonu
    // sourceURL yoksa ve harita da üretilemiyorsa → hiçbir şey

    @ViewBuilder
    private func eventCTA(for event: MoodEvent) -> some View {
        let isTicketed = event.kind != .microActivity && event.category != .aktivite

        if isTicketed, let url = event.sourceURL {
            HStack {
                Spacer()
                Link(destination: url) {
                    HStack(spacing: 5) {
                        Image(systemName: "ticket.fill")
                            .font(.system(size: 10, weight: .semibold))
                        // "Ara" for search pages (never 404), "Bak" for direct event pages
                        Text(event.isFallbackURL ? NSLocalizedString("discover.buyOnBiletix", comment: "") : NSLocalizedString("discover.viewOnBiletix", comment: ""))
                            .monoSM(tracking: 0.6)
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Capsule().fill(Color(hex: "#E63946")))
                }
            }
        } else if !isTicketed, let url = appleMapsURL(venue: event.venue, city: event.city) {
            HStack {
                Spacer()
                Link(destination: url) {
                    HStack(spacing: 5) {
                        Image(systemName: "map.fill")
                            .font(.system(size: 10, weight: .semibold))
                        Text(NSLocalizedString("discover.showOnMap", comment: ""))
                            .monoSM(tracking: 0.6)
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Capsule().fill(ONETokens.oneBlue))
                }
            }
        }
    }

    private func appleMapsURL(venue: String, city: String) -> URL? {
        let parts = [venue, city].filter { !$0.isEmpty }
        guard !parts.isEmpty,
              let encoded = parts.joined(separator: ", ")
                .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else { return nil }
        return URL(string: "https://maps.apple.com/?q=\(encoded)")
    }
}

// MARK: - Ticketmaster API Manager & Models

class TicketmasterManager {
    static let shared = TicketmasterManager()

    private let apiKey: String
    private let baseURL = "https://app.ticketmaster.com/discovery/v2/events.json"

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
        let cacheKey = "\(entry.moodLabel)|\(entry.artistName)|\(entry.genre)|\(city)|\(todayString)"
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

        async let tmMusic = fetchMusicMatches(entry: entry, city: city)
        async let tmArts  = fetchForSegment(entry: entry, city: city, category: .tiyatro, size: 6)
        async let tmExpo  = fetchForSegment(entry: entry, city: city, category: .sergi,   size: 6)
        async let tmSport = fetchForSegment(entry: entry, city: city, category: .spor,    size: 5)

        let e1 = (try? await tmMusic) ?? []
        let e2 = (try? await tmArts) ?? []
        let e3 = (try? await tmExpo) ?? []
        let e4 = (try? await tmSport) ?? []
        var apiEvents = e1 + e2 + e3 + e4

        // If primary city returned nothing, try nearby cities before falling to mock.
        // Events from nearby cities are marked with isNearbyCity=true so the UI can
        // label them clearly (e.g. "Yakın şehir: İstanbul").
        if apiEvents.isEmpty {
            for altCity in nearbyCities(for: city) {
                async let alt1 = fetchMusicMatches(entry: entry, city: altCity)
                async let alt2 = fetchForSegment(entry: entry, city: altCity, category: .tiyatro, size: 5)
                async let alt3 = fetchForSegment(entry: entry, city: altCity, category: .sergi, size: 4)
                let altMusic = (try? await alt1) ?? []
                let altArts  = (try? await alt2) ?? []
                let altExpo  = (try? await alt3) ?? []
                let altEvents = altMusic + altArts + altExpo
                if !altEvents.isEmpty {
                    // Tag every event so the card layer can show "Yakın şehir: X"
                    apiEvents = altEvents.map { markNearby($0) }
                    ONELogger.info("No TM events in \(city) — showing nearby \(altCity) (\(altEvents.count) events).", category: .general)
                    break
                }
            }
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
            matchPercent: max(event.matchPercent - 8, 50), // slight penalty for nearby
            sourceURL: event.sourceURL,
            kind: event.kind,
            reason: event.reason,
            sourceLabel: event.sourceLabel,
            isNearbyCity: true,
            isFallbackURL: event.isFallbackURL
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
        let date      = event.dates?.start?.localDate ?? ""
        let time      = event.dates?.start?.localTime
        let timing    = timingLabel(date: date, time: time)

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
            isFallbackURL: isFallback
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
    private func preferredCategories(for moodLabel: String) -> [EventCategory] {
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
            keyword: moodGenreKeywords(for: entry.moodLabel).first,
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
            return "Bugünkü \(canonicalMoodLabel(entry.moodLabel).lowercased()) moduna ve seçtiğin müziğe yakın bir konser."
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
        let preferred = preferredCategories(for: entry.moodLabel)
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
        if moodGenreKeywords(for: entry.moodLabel).contains(where: { searchableText.contains(normalize($0)) }) {
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

// MARK: - Ticketmaster API Models

struct TMResponse: Decodable {
    let _embedded: TMEmbedded?
}
struct TMEmbedded: Decodable {
    let events: [TMEvent]?
}
struct TMEvent: Decodable {
    let id: String
    let name: String
    let url: String?
    let dates: TMDates?
    let classifications: [TMClassification]?
    let priceRanges: [TMPriceRange]?
    let _embedded: TMEventEmbedded?
}
struct TMDates: Decodable {
    let start: TMStart?
}
struct TMStart: Decodable {
    let localDate: String?
    let localTime: String?
}
struct TMClassification: Decodable {
    let segment: TMSegment?
    let genre: TMSegment?
    let subGenre: TMSegment?
}
struct TMSegment: Decodable {
    let name: String?
}
struct TMPriceRange: Decodable {
    let min: Double?
    let max: Double?
    let currency: String?
}
struct TMEventEmbedded: Decodable {
    let venues: [TMVenue]?
}
struct TMVenue: Decodable {
    let name: String?
    let city: TMCity?
}
struct TMCity: Decodable {
    let name: String?
}
