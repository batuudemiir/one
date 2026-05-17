//
//  MoodEventMockData.swift
//  one
//
//  Mock event lists, city-specific outdoor venues, and Biletix URL builder.
//  Used as fallback when Ticketmaster API key is missing or returns empty.
//  Extracted from MoodEventsSheet.swift in Faz 3.1 (2026-04-26).
//

import SwiftUI
import Foundation

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
func biletixBrowseCards(for moodLabel: String, feelingLabel: String = "", city: String = "İstanbul") -> [MoodEvent] {
    let normalizedMood = canonicalMoodLabel(moodLabel)

    let preferred: [EventCategory] = {
        // Feeling override — yüksek enerji feelings → konser önce
        let concertFeelings: Set<String> = ["Hype", "Dance", "Happier than ever", "Manifest"]
        if concertFeelings.contains(feelingLabel) { return [.konser, .tiyatro, .sergi] }
        let calmFeelings: Set<String> = ["Chill", "Alone", "Sad"]
        if calmFeelings.contains(feelingLabel) { return [.sergi, .tiyatro, .konser] }
        if feelingLabel == "Overthink" { return [.tiyatro, .sergi, .konser] }

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
