//
//  CitySpecialActivities.swift
//  one
//
//  Şehre özel kültürel, tarihi veya yerel genel etkinlik önerileri (Mock Event).
//

import Foundation

struct CitySpecialActivities {
    
    /// Belirtilen şehir için özel (veya genel şablonlu) etkinlik önerileri döndürür.
    static func getSpecialEvents(for city: String) -> [MoodEvent] {
        let normalized = city.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current).trimmingCharacters(in: .whitespacesAndNewlines)
        
        var activities: [MoodEvent] = []
        
        switch normalized {
        case "istanbul":
            activities = [
                mockEvent(city: city, title: "Boğaz'da Vapur Turu", venue: "Eminönü - Kadıköy Hattı", category: .aktivite),
                mockEvent(city: city, title: "Tarihi Yarımada Yürüyüşü", venue: "Sultanahmet Meydanı", category: .aktivite),
                mockEvent(city: city, title: "Galata Sokaklarında Keşif", venue: "Galata Kulesi Çevresi", category: .aktivite),
                mockEvent(city: city, title: "Moda Sahili'nde Gün Batımı", venue: "Moda Sahili", category: .aktivite)
            ]
        case "izmir":
            activities = [
                mockEvent(city: city, title: "Kordon'da Gün Batımı", venue: "Alsancak Kordon", category: .aktivite),
                mockEvent(city: city, title: "Tarihi Asansör Turu", venue: "Tarihi Asansör", category: .aktivite),
                mockEvent(city: city, title: "Kemeraltı Çarşısı Keşfi", venue: "Kemeraltı", category: .aktivite),
                mockEvent(city: city, title: "Bostanlı'da Bisiklet Turu", venue: "Bostanlı Sahili", category: .aktivite)
            ]
        case "ankara":
            activities = [
                mockEvent(city: city, title: "Tarihi Ankara Kalesi Turu", venue: "Ankara Kalesi", category: .aktivite),
                mockEvent(city: city, title: "Eymir Gölü Bisiklet Rotası", venue: "Eymir Gölü", category: .aktivite),
                mockEvent(city: city, title: "Kuğulu Park'ta Mola", venue: "Kuğulu Park", category: .aktivite),
                mockEvent(city: city, title: "Tunalı Hilmi Caddesi Yürüyüşü", venue: "Tunalı", category: .aktivite)
            ]
        case "antalya":
            activities = [
                mockEvent(city: city, title: "Kaleiçi Tarihi Sokaklar", venue: "Kaleiçi", category: .aktivite),
                mockEvent(city: city, title: "Konyaaltı'nda Deniz Havası", venue: "Konyaaltı Sahili", category: .aktivite),
                mockEvent(city: city, title: "Düden Şelalesi Ziyareti", venue: "Düden Şelalesi", category: .aktivite)
            ]
        case "bursa":
            activities = [
                mockEvent(city: city, title: "Cumalıkızık Köyü Kahvaltısı", venue: "Cumalıkızık", category: .aktivite),
                mockEvent(city: city, title: "Ulu Cami ve Hanlar Bölgesi", venue: "Tarihi Çarşı", category: .aktivite),
                mockEvent(city: city, title: "Teleferik ile Uludağ Gezisi", venue: "Uludağ Teleferik", category: .aktivite)
            ]
        case "adana":
            activities = [
                mockEvent(city: city, title: "Seyhan Nehri Kıyısı Yürüyüşü", venue: "Seyhan Merkez Park", category: .aktivite),
                mockEvent(city: city, title: "Tarihi Taş Köprü Fotoğraf Turu", venue: "Taş Köprü", category: .aktivite),
                mockEvent(city: city, title: "Sokak Lezzetleri ve Kebap Tadımı", venue: "Şehir Merkezi", category: .aktivite)
            ]
        case "mardin":
            activities = [
                mockEvent(city: city, title: "Eski Mardin Sokakları Keşfi", venue: "Eski Mardin", category: .aktivite),
                mockEvent(city: city, title: "Taş Evler Fotoğraf Turu", venue: "Tarihi Mardin Evleri", category: .aktivite),
                mockEvent(city: city, title: "Güneşin Doğuşunu İzleme", venue: "Mardin Kalesi Etekleri", category: .aktivite)
            ]
        case "gaziantep":
            activities = [
                mockEvent(city: city, title: "Zeugma Mozaik Müzesi Turu", venue: "Zeugma Müzesi", category: .sergi),
                mockEvent(city: city, title: "Bakırcılar Çarşısı Ziyareti", venue: "Tarihi Bakırcılar Çarşısı", category: .aktivite),
                mockEvent(city: city, title: "Gaziantep Lezzetleri Turu", venue: "Şehir Merkezi", category: .aktivite)
            ]
        case "canakkale", "çanakkale":
            activities = [
                mockEvent(city: city, title: "Kordon'da Akşam Yürüyüşü", venue: "Çanakkale Kordon", category: .aktivite),
                mockEvent(city: city, title: "Truva Atı Fotoğraf Noktası", venue: "Merkez", category: .aktivite),
                mockEvent(city: city, title: "Aynalı Çarşı Ziyareti", venue: "Aynalı Çarşı", category: .aktivite)
            ]
        default:
            // Bilinmeyen veya özel listesi olmayan şehirler için dinamik jenerik şablon
            activities = [
                mockEvent(city: city, title: "\(city) Tarihi ve Kültürel Gezi", venue: "Şehir Merkezi", category: .aktivite),
                mockEvent(city: city, title: "Yöresel Lezzet Keşfi", venue: "\(city) Sokakları", category: .aktivite),
                mockEvent(city: city, title: "Doğa ve Park Yürüyüşü", venue: "Şehir Parkı", category: .aktivite),
                mockEvent(city: city, title: "Şehrin Seyir Noktası", venue: "Panoramik Tepeler", category: .aktivite)
            ]
        }
        
        return activities
    }
    
    private static func mockEvent(city: String, title: String, venue: String, category: EventCategory) -> MoodEvent {
        return MoodEvent(
            id: UUID().uuidString,
            category: category,
            title: title,
            venue: venue,
            city: city,
            timing: "Her zaman planlanabilir",
            price: "Ücretsiz / Şehre Özel",
            matchPercent: 75,
            sourceURL: nil,
            kind: .microActivity,
            reason: "\(city) şehrine özel bir öneri",
            sourceLabel: "Şehre Özel",
            isNearbyCity: false,
            isFallbackURL: false,
            eventDate: nil,
            attendeeCount: nil,
            distanceKm: nil
        )
    }
}
