//
//  ActivityRecommendationEngine.swift
//  one
//
//  Layered activity recommendations for the selected mood.
//

import Foundation
import SwiftUI

struct RecommendationSection: Identifiable {
    let id: String
    let title: String
    let subtitle: String
    let items: [MoodEvent]
}

private enum ActivityTimeBucket: String, CaseIterable {
    case morning
    case afternoon
    case evening
    case night
}

private enum ActivityWeatherCondition {
    case sunny
    case cloudy
    case rainy
    case stormy
    case snowy
    case unknown
}

private enum ActivityLocationStyle {
    case nature
    case coast
    case culture
    case neighborhood
    case motion
    case quiet
}

private struct ActivityContext {
    let moodLabel: String
    let timeBucket: ActivityTimeBucket
    let weather: ActivityWeatherCondition
    let preferredEnergy: Int
    let preferredSocial: Int
}

private struct MicroActivityTemplate {
    let id: String
    let title: String
    let venuePrefix: String
    let timingLabel: String
    let price: String
    let moods: [String]
    let feelings: [FeelingType]
    let energy: Int
    let social: Int
    let isOutdoor: Bool
    let category: EventCategory
    let timeBuckets: [ActivityTimeBucket]
    let preferredWeather: [ActivityWeatherCondition]
    let avoidedWeather: [ActivityWeatherCondition]
    let locationStyle: ActivityLocationStyle
}

final class ActivityRecommendationEngine {
    static let shared = ActivityRecommendationEngine()

    private init() {}

    func fetchRecommendations(for entry: DailyEntry, city: String) async -> [MoodEvent] {
        await fetchSections(for: entry, city: city).flatMap(\.items)
    }

    func fetchSections(for entry: DailyEntry, city: String) async -> [RecommendationSection] {
        let microActivities = buildMicroActivities(for: entry, city: city)
        let liveEvents = (try? await TicketmasterManager.shared.fetchLiveEvents(for: entry, city: city))
            ?? mockEvents(for: entry.moodLabel, city: city)

        let artistConcerts = Array(
            liveEvents
                .filter { [.artistConcert, .similarConcert].contains($0.kind) }
                .sorted { $0.matchPercent > $1.matchPercent }
                .prefix(4)
        )

        let cityEvents = Array(
            liveEvents
                .filter { ![.artistConcert, .similarConcert].contains($0.kind) }
                .sorted { $0.matchPercent > $1.matchPercent }
                .prefix(8)
        )

        var sections: [RecommendationSection] = []

        if !microActivities.isEmpty {
            sections.append(
                RecommendationSection(
                    id: "micro",
                    title: "Hemen iyi gelebilir",
                    subtitle: "Mood'una, saate ve havaya gore kolayca baslayabilecegin seyler.",
                    items: microActivities
                )
            )
        }

        if !artistConcerts.isEmpty {
            sections.append(
                RecommendationSection(
                    id: "music-match",
                    title: "Muzigine yakin konserler",
                    subtitle: "Sectigin sanatciya veya ayni tarza yaslanan canli muzikler.",
                    items: artistConcerts
                )
            )
        }

        if !cityEvents.isEmpty {
            sections.append(
                RecommendationSection(
                    id: "city-events",
                    title: "Sehirde planlayabileceklerin",
                    subtitle: "Sergi, tiyatro, sinema ve diger canli rotalar.",
                    items: cityEvents
                )
            )
        }

        return sections
    }

    private func buildMicroActivities(for entry: DailyEntry, city: String) -> [MoodEvent] {
        let context = buildContext(for: entry)

        return microActivityCatalog
            .map { template in
                let score = score(template: template, context: context, feeling: entry.feeling)
                return MoodEvent(
                    id: template.id,
                    category: template.category,
                    title: template.title,
                    venue: venueHint(for: template, city: city),
                    city: city,
                    timing: template.timingLabel,
                    price: template.price,
                    matchPercent: score,
                    kind: .microActivity,
                    reason: microReason(for: template, context: context, feeling: entry.feeling),
                    sourceLabel: "Bugune ozel"
                )
            }
            .sorted {
                $0.matchPercent != $1.matchPercent
                    ? $0.matchPercent > $1.matchPercent
                    : $0.title < $1.title
            }
            .prefix(4)
            .map { $0 }
    }

    private func buildContext(for entry: DailyEntry) -> ActivityContext {
        ActivityContext(
            moodLabel: canonicalMoodLabel(entry.moodLabel),
            timeBucket: currentTimeBucket(),
            weather: detectWeather(from: entry),
            preferredEnergy: preferredEnergy(for: entry),
            preferredSocial: preferredSocial(for: entry)
        )
    }

    private func preferredEnergy(for entry: DailyEntry) -> Int {
        let moodEnergy: Int = switch canonicalMoodLabel(entry.moodLabel) {
        case "Ateşli", "Coşkulu": 5
        case "Mutlu", "Özgür": 4
        case "Doğal", "Nötr": 3
        case "Huzurlu", "Derin", "Gizemli": 2
        case "Hassas", "Sessiz", "Nostaljik": 1
        default: 3
        }

        let feelingDelta: Int = switch entry.feeling {
        case .excited, .happy: 1
        case .angry: 2
        case .tired, .sad: -1
        case .anxious: 0
        case .calm, .peaceful: -1
        }

        return min(max(moodEnergy + feelingDelta, 1), 5)
    }

    private func preferredSocial(for entry: DailyEntry) -> Int {
        let moodSocial: Int = switch canonicalMoodLabel(entry.moodLabel) {
        case "Ateşli", "Coşkulu": 4
        case "Mutlu", "Özgür": 3
        case "Doğal", "Nostaljik": 2
        case "Huzurlu", "Derin", "Gizemli", "Hassas", "Sessiz": 1
        case "Nötr": 2
        default: 2
        }

        let feelingDelta: Int = switch entry.feeling {
        case .happy, .excited: 1
        case .anxious, .sad, .tired: -1
        case .angry, .calm, .peaceful: 0
        }

        return min(max(moodSocial + feelingDelta, 1), 5)
    }

    private func currentTimeBucket() -> ActivityTimeBucket {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 6..<12: return .morning
        case 12..<17: return .afternoon
        case 17..<22: return .evening
        default: return .night
        }
    }

    private func detectWeather(from entry: DailyEntry) -> ActivityWeatherCondition {
        let source = "\(entry.weatherIcon) \(entry.weatherDesc)".lowercased()
        if source.contains("fırt") || source.contains("firt") || source.contains("storm") || source.contains("gok gur") {
            return .stormy
        }
        if source.contains("kar") || source.contains("snow") {
            return .snowy
        }
        if source.contains("yağ") || source.contains("yag") || source.contains("rain") || source.contains("sağanak") || source.contains("saganak") {
            return .rainy
        }
        if source.contains("güne") || source.contains("gune") || source.contains("sun") || source.contains("açık") || source.contains("acik") {
            return .sunny
        }
        if source.contains("bulut") || source.contains("cloud") {
            return .cloudy
        }
        return .unknown
    }

    private func score(template: MicroActivityTemplate, context: ActivityContext, feeling: FeelingType) -> Int {
        var score = 45

        if template.moods.contains(context.moodLabel) {
            score += 24
        }

        if template.feelings.contains(feeling) {
            score += 10
        }

        let energyDiff = abs(template.energy - context.preferredEnergy)
        score += max(0, 12 - (energyDiff * 4))

        let socialDiff = abs(template.social - context.preferredSocial)
        score += max(0, 8 - (socialDiff * 2))

        if template.timeBuckets.contains(context.timeBucket) {
            score += 8
        }

        if template.preferredWeather.contains(context.weather) {
            score += 8
        }

        if template.avoidedWeather.contains(context.weather) {
            score -= 14
        }

        if template.isOutdoor, [.sunny, .cloudy].contains(context.weather) {
            score += 4
        }

        if !template.isOutdoor, [.rainy, .stormy, .snowy].contains(context.weather) {
            score += 5
        }

        return min(max(score, 52), 98)
    }

    private func microReason(for template: MicroActivityTemplate, context: ActivityContext, feeling: FeelingType) -> String {
        if template.feelings.contains(feeling) {
            switch feeling {
            case .anxious:
                return "Bugunku tedirginligi daha yumusak bir ritme cekebilir."
            case .tired:
                return "Dusuk eforla modunu tasiyan sakin bir secim."
            case .happy, .excited:
                return "Yuksek enerjini disari tasimak icin iyi bir alan aciyor."
            case .sad:
                return "Baskisiz, yavas ve destekleyici bir akisa uyuyor."
            case .calm, .peaceful:
                return "Icindeki sakinligi bozmadan gunun ritmine eslik ediyor."
            case .angry:
                return "Enerjiyi bedensel bir akisa cevirmen icin secildi."
            }
        }

        if template.isOutdoor, [.sunny, .cloudy].contains(context.weather) {
            return "Mood'una ve disarida olmaya uygun havaya gore onde cikiyor."
        }

        if !template.isOutdoor, [.rainy, .stormy, .snowy].contains(context.weather) {
            return "Hava kosullari kapali ve rahat bir akisi daha mantikli kiliyor."
        }

        return "Bugunku \(context.moodLabel.lowercased()) haliyle uyumlu, kolay baslanabilir bir secim."
    }

    private func venueHint(for template: MicroActivityTemplate, city: String) -> String {
        switch template.locationStyle {
        case .nature:
            return cityWalkingSpots(for: city).first?.venue ?? "Sehirde yesil bir rota"
        case .coast:
            return coastalVenue(for: city)
        case .culture:
            return "\(city) merkezinde kultur rotasi"
        case .neighborhood:
            return "\(city) icinde yakin bir semt"
        case .motion:
            return cityWalkingSpots(for: city).dropFirst().first?.venue ?? "Sehirde hareketli bir rota"
        case .quiet:
            return "Sessiz bir kose, kafe veya kitapci"
        }
    }

    private func coastalVenue(for city: String) -> String {
        let normalized = city.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
        switch normalized {
        case "istanbul": return "Boğaz hattı"
        case "izmir": return "Kordon"
        case "antalya": return "Konyaaltı sahili"
        case "mersin": return "Kızkalesi sahili"
        case "adana": return "Seyhan kıyısı"
        case "kocaeli": return "Başiskele ve Darıca sahil hattı"
        case "sakarya": return "Sapanca Gölü ve Karasu hattı"
        default: return "Şehirde suya yakın bir rota"
        }
    }

    private let microActivityCatalog: [MicroActivityTemplate] = [
        MicroActivityTemplate(
            id: "walk-soft",
            title: "25 dakikalik yavas bir yuruyuse cik",
            venuePrefix: "Yakininda",
            timingLabel: "Bugun icin",
            price: "Ucretsiz",
            moods: ["Huzurlu", "Hassas", "Sessiz", "Derin", "Nötr"],
            feelings: [.calm, .peaceful, .sad, .anxious],
            energy: 1,
            social: 1,
            isOutdoor: true,
            category: .aktivite,
            timeBuckets: [.morning, .afternoon, .evening],
            preferredWeather: [.sunny, .cloudy],
            avoidedWeather: [.stormy, .snowy],
            locationStyle: .nature
        ),
        MicroActivityTemplate(
            id: "bike-ride",
            title: "Bisiklet sur ve ritmini yukari cek",
            venuePrefix: "Rota",
            timingLabel: "Bugun ogleden sonra",
            price: "Ucretsiz",
            moods: ["Özgür", "Coşkulu", "Ateşli", "Doğal"],
            feelings: [.excited, .happy, .angry],
            energy: 4,
            social: 2,
            isOutdoor: true,
            category: .aktivite,
            timeBuckets: [.morning, .afternoon, .evening],
            preferredWeather: [.sunny, .cloudy],
            avoidedWeather: [.rainy, .stormy, .snowy],
            locationStyle: .motion
        ),
        MicroActivityTemplate(
            id: "swim-sea",
            title: "Yuzmeye git ve bedeni sifirla",
            venuePrefix: "Kiyi",
            timingLabel: "Bugun gun batimina yakin",
            price: "Ucretsiz",
            moods: ["Doğal", "Mutlu", "Özgür", "Coşkulu"],
            feelings: [.happy, .excited, .calm],
            energy: 3,
            social: 2,
            isOutdoor: true,
            category: .aktivite,
            timeBuckets: [.afternoon, .evening],
            preferredWeather: [.sunny],
            avoidedWeather: [.rainy, .stormy, .snowy],
            locationStyle: .coast
        ),
        MicroActivityTemplate(
            id: "coffee-break",
            title: "Sessiz bir kahve molasi ver",
            venuePrefix: "Yakininda",
            timingLabel: "Simdi",
            price: "₺",
            moods: ["Hassas", "Derin", "Nostaljik", "Sessiz", "Nötr"],
            feelings: [.tired, .sad, .calm],
            energy: 1,
            social: 1,
            isOutdoor: false,
            category: .aktivite,
            timeBuckets: [.morning, .afternoon, .evening],
            preferredWeather: [.rainy, .cloudy, .snowy],
            avoidedWeather: [],
            locationStyle: .quiet
        ),
        MicroActivityTemplate(
            id: "bookstore",
            title: "Bir kitapciya ya da plakciya ugr",
            venuePrefix: "Rota",
            timingLabel: "Bugun",
            price: "₺",
            moods: ["Nostaljik", "Derin", "Sessiz", "Gizemli"],
            feelings: [.calm, .sad, .peaceful],
            energy: 1,
            social: 1,
            isOutdoor: false,
            category: .aktivite,
            timeBuckets: [.afternoon, .evening],
            preferredWeather: [.rainy, .cloudy, .unknown],
            avoidedWeather: [],
            locationStyle: .culture
        ),
        MicroActivityTemplate(
            id: "museum-hop",
            title: "Kendine kisa bir muze veya sergi rotasi ac",
            venuePrefix: "Merkez",
            timingLabel: "Bugun ogle sonrasi",
            price: "₺₺",
            moods: ["Derin", "Huzurlu", "Gizemli", "Hassas", "Mutlu"],
            feelings: [.peaceful, .calm, .sad],
            energy: 2,
            social: 1,
            isOutdoor: false,
            category: .sergi,
            timeBuckets: [.afternoon, .evening],
            preferredWeather: [.rainy, .cloudy, .snowy],
            avoidedWeather: [],
            locationStyle: .culture
        ),
        MicroActivityTemplate(
            id: "sunset-walk",
            title: "Gunum batarken sahil turu yap",
            venuePrefix: "Sahil",
            timingLabel: "Aksamustu",
            price: "Ucretsiz",
            moods: ["Mutlu", "Özgür", "Nostaljik", "Huzurlu"],
            feelings: [.happy, .calm, .peaceful],
            energy: 2,
            social: 2,
            isOutdoor: true,
            category: .aktivite,
            timeBuckets: [.evening],
            preferredWeather: [.sunny, .cloudy],
            avoidedWeather: [.rainy, .stormy],
            locationStyle: .coast
        ),
        MicroActivityTemplate(
            id: "yoga-breath",
            title: "Yoga ya da nefes calismasi ile tempo dusur",
            venuePrefix: "Alan",
            timingLabel: "Bugun sabah veya aksam",
            price: "Ucretsiz",
            moods: ["Huzurlu", "Sessiz", "Hassas", "Doğal"],
            feelings: [.anxious, .calm, .peaceful, .tired],
            energy: 1,
            social: 1,
            isOutdoor: false,
            category: .aktivite,
            timeBuckets: [.morning, .evening],
            preferredWeather: [.rainy, .cloudy, .unknown],
            avoidedWeather: [],
            locationStyle: .quiet
        ),
        MicroActivityTemplate(
            id: "photo-walk",
            title: "Fotograf yuruyusu yap ve detaya bak",
            venuePrefix: "Semt",
            timingLabel: "Bugun",
            price: "Ucretsiz",
            moods: ["Gizemli", "Doğal", "Derin", "Nostaljik"],
            feelings: [.calm, .peaceful, .happy],
            energy: 2,
            social: 1,
            isOutdoor: true,
            category: .aktivite,
            timeBuckets: [.morning, .afternoon, .evening],
            preferredWeather: [.sunny, .cloudy],
            avoidedWeather: [.stormy, .snowy],
            locationStyle: .neighborhood
        ),
        MicroActivityTemplate(
            id: "night-run",
            title: "Gece kosusu ile enerjiyi bosalt",
            venuePrefix: "Parkur",
            timingLabel: "Bu aksam",
            price: "Ucretsiz",
            moods: ["Ateşli", "Coşkulu", "Gizemli"],
            feelings: [.angry, .excited],
            energy: 5,
            social: 1,
            isOutdoor: true,
            category: .aktivite,
            timeBuckets: [.evening, .night],
            preferredWeather: [.cloudy, .sunny],
            avoidedWeather: [.rainy, .stormy, .snowy],
            locationStyle: .motion
        ),
        MicroActivityTemplate(
            id: "friend-dinner",
            title: "Bir arkadasini cagirip uzun bir aksam yemegi kur",
            venuePrefix: "Masa",
            timingLabel: "Bu aksam",
            price: "₺₺",
            moods: ["Mutlu", "Coşkulu", "Nostaljik"],
            feelings: [.happy, .excited, .peaceful],
            energy: 2,
            social: 4,
            isOutdoor: false,
            category: .aktivite,
            timeBuckets: [.evening, .night],
            preferredWeather: [.rainy, .cloudy, .sunny],
            avoidedWeather: [],
            locationStyle: .neighborhood
        )
    ]
}
