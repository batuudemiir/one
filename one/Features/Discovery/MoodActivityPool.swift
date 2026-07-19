//
//  MoodActivityPool.swift
//  one
//
//  Mood'a göre çeşitli aktivite havuzu + rotasyon takibi.
//  cityWalkingSpots() yerine kullanılır — her mood için 8 farklı aktivite tipi.
//

import Foundation

// MARK: - ActivityRotationTracker

struct ActivityRotationTracker {
    private static let maxHistory = 24

    private static func storageKey(for mood: String) -> String {
        return "one.shown.activities.\(canonicalMoodLabel(mood))"
    }

    static func shown(for mood: String) -> Set<String> {
        let arr = UserDefaults.standard.stringArray(forKey: storageKey(for: mood)) ?? []
        return Set(arr)
    }

    static func markShown(_ titles: [String], for mood: String) {
        let key = storageKey(for: mood)
        var arr = UserDefaults.standard.stringArray(forKey: key) ?? []
        arr.append(contentsOf: titles)
        if arr.count > maxHistory { arr = Array(arr.suffix(maxHistory)) }
        UserDefaults.standard.set(arr, forKey: key)
    }

    static func clear(for mood: String) {
        UserDefaults.standard.removeObject(forKey: storageKey(for: mood))
    }
}

// MARK: - MoodActivityPool

enum MoodActivityPool {

    static func pickActivities(for moodLabel: String, city: String, count: Int = 6) -> [MoodEvent] {
        let normalized = canonicalMoodLabel(moodLabel)
        let pool = activities(for: normalized, city: city)
        let shown = ActivityRotationTracker.shown(for: normalized)

        var candidates = pool.filter { !shown.contains($0.title) }

        if candidates.count < count {
            ActivityRotationTracker.clear(for: normalized)
            candidates = pool
        }

        let hour = Calendar.current.component(.hour, from: Date())
        let bucket = hour < 12 ? 0 : hour < 18 ? 1 : 2
        let dayOfYear = Calendar.current.ordinality(of: .day, in: .year, for: Date()) ?? 1
        var rng = SeededRNG(seed: UInt64(dayOfYear * 10 + bucket))
        let shuffled = candidates.shuffled(using: &rng)

        let selected = Array(shuffled.prefix(count))
        ActivityRotationTracker.markShown(selected.map(\.title), for: normalized)
        return selected
    }

    // MARK: - Private pool builder

    private static func activities(for normalizedMood: String, city: String) -> [MoodEvent] {
        switch normalizedMood {

        case "Ateşli":
            return [
                MoodEvent(category: .aktivite, title: "Dans Dersi — Salsa & Bachata",     venue: "\(city) Dans Stüdyosu",       city: city, timing: "Bu akşam · 20:00",      price: "₺200+",  matchPercent: 93, kind: .microActivity),
                MoodEvent(category: .aktivite, title: "Escape Room — Acil Kaçış",          venue: "\(city) Kaçış Oyunları",      city: city, timing: "Bu akşam · 19:00",      price: "₺250+",  matchPercent: 88, kind: .microActivity),
                MoodEvent(category: .aktivite, title: "Boks & Kickbox Antrenmanı",         venue: "\(city) Spor Salonu",         city: city, timing: "Yarın · 18:30",         price: "₺150",   matchPercent: 85, kind: .microActivity),
                MoodEvent(category: .aktivite, title: "Laser Tag & Oyun Merkezi",          venue: "\(city) Eğlence Merkezi",     city: city, timing: "Bu akşam · 18:00",      price: "₺180",   matchPercent: 80, kind: .microActivity),
                MoodEvent(category: .aktivite, title: "Tırmanma Duvarı — Bouldering",     venue: "\(city) Tırmanma Merkezi",    city: city, timing: "Yarın · 10:00",         price: "₺200",   matchPercent: 78, kind: .microActivity),
                MoodEvent(category: .aktivite, title: "Satranç Kafede Hızlı Oyun",        venue: "\(city) Satranç Kulübü",      city: city, timing: "Her gün açık",          price: "Ücretsiz", matchPercent: 72, kind: .microActivity),
                MoodEvent(category: .aktivite, title: "Silindir & Paten Pisti",           venue: "\(city) Paten Pisti",         city: city, timing: "Hafta sonu · 14:00",    price: "₺120",   matchPercent: 68, kind: .microActivity),
                MoodEvent(category: .aktivite, title: "Meydan Etkinliği — Sokak Konseri", venue: "\(city) Meydanı",             city: city, timing: "Bu akşam · 19:30",      price: "Ücretsiz", matchPercent: 65, kind: .microActivity),
            ]

        case "Coşkulu":
            return [
                MoodEvent(category: .aktivite, title: "Bisiklet Turu — Şehir Keşfi",      venue: "\(city) Bisiklet Yolu",       city: city, timing: "Yarın · 09:00",         price: "₺80+",   matchPercent: 92, kind: .microActivity),
                MoodEvent(category: .aktivite, title: "Açık Hava Yoga — Sabah Seansı",    venue: "\(city) Şehir Parkı",         city: city, timing: "Yarın · 08:00",         price: "Ücretsiz", matchPercent: 87, kind: .microActivity),
                MoodEvent(category: .aktivite, title: "Beach Volleyball Maçı",             venue: "\(city) Spor Tesisi",         city: city, timing: "Bu akşam · 18:00",      price: "₺100",   matchPercent: 82, kind: .microActivity),
                MoodEvent(category: .aktivite, title: "CrossFit & Fonksiyonel Antrenman", venue: "\(city) CrossFit Kutusu",     city: city, timing: "Yarın · 07:30",         price: "₺180",   matchPercent: 78, kind: .microActivity),
                MoodEvent(category: .aktivite, title: "Skating — Kaykay Parkı",           venue: "\(city) Skate Park",          city: city, timing: "Bu öğleden sonra",      price: "Ücretsiz", matchPercent: 74, kind: .microActivity),
                MoodEvent(category: .aktivite, title: "Yüzme Seansı — Olimpik Havuz",    venue: "\(city) Yüzme Havuzu",        city: city, timing: "Yarın · 07:00",         price: "₺120",   matchPercent: 70, kind: .microActivity),
                MoodEvent(category: .aktivite, title: "Macera Parkı & Zip Line",          venue: "\(city) Macera Parkı",        city: city, timing: "Hafta sonu · 10:00",    price: "₺250+",  matchPercent: 66, kind: .microActivity),
                MoodEvent(category: .aktivite, title: "Sabah Koşu Grubu — 5K",           venue: "\(city) Koşu Parkuru",        city: city, timing: "Yarın · 07:30",         price: "Ücretsiz", matchPercent: 62, kind: .microActivity),
            ]

        case "Mutlu":
            return [
                MoodEvent(category: .aktivite, title: "Kahvaltı Kafe Turu",               venue: "\(city) Tarihi Çarşı",        city: city, timing: "Yarın · 09:00",         price: "₺150+",  matchPercent: 91, kind: .microActivity),
                MoodEvent(category: .aktivite, title: "Hafta Sonu Pazar Yeri",            venue: "\(city) Organik Pazar",       city: city, timing: "Hafta sonu · 08:00",    price: "Ücretsiz", matchPercent: 86, kind: .microActivity),
                MoodEvent(category: .aktivite, title: "Çiçek Düzenleme Atölyesi",         venue: "\(city) Çiçek Atölyesi",      city: city, timing: "Cumartesi · 14:00",     price: "₺300+",  matchPercent: 82, kind: .microActivity),
                MoodEvent(category: .aktivite, title: "Piknik — Şehrin En Güzel Parkı",  venue: "\(city) Milli Parkı",         city: city, timing: "Bu öğleden sonra",      price: "Ücretsiz", matchPercent: 78, kind: .microActivity),
                MoodEvent(category: .aktivite, title: "Galeri Açılışı Turu",              venue: "\(city) Sanat Galerisi",      city: city, timing: "Bu akşam · 18:00",      price: "Ücretsiz", matchPercent: 74, kind: .microActivity),
                MoodEvent(category: .aktivite, title: "Çömlek & Seramik Atölyesi",        venue: "\(city) Seramik Stüdyosu",    city: city, timing: "Pazar · 13:00",         price: "₺280+",  matchPercent: 70, kind: .microActivity),
                MoodEvent(category: .aktivite, title: "Botanik Bahçe Gezisi",             venue: "\(city) Botanik Bahçesi",     city: city, timing: "Yarın · 10:00",         price: "₺60",    matchPercent: 66, kind: .microActivity),
                MoodEvent(category: .aktivite, title: "Sabah Fotoğraf Turu",              venue: "\(city) Tarihi Semt",         city: city, timing: "Yarın · 07:30",         price: "Ücretsiz", matchPercent: 62, kind: .microActivity),
            ]

        case "Doğal":
            return [
                MoodEvent(category: .aktivite, title: "Doğa Yürüyüşü — Sabah Rotası",    venue: "\(city) Şehir Ormanı",        city: city, timing: "Yarın · 08:00",         price: "Ücretsiz", matchPercent: 93, kind: .microActivity),
                MoodEvent(category: .aktivite, title: "Kamp Ateşi Gecesi",                 venue: "\(city) Yakını Kamp Alanı",   city: city, timing: "Bu hafta sonu",         price: "₺200+",  matchPercent: 88, kind: .microActivity),
                MoodEvent(category: .aktivite, title: "Bisiklet Turu — Doğa Hattı",       venue: "\(city) Sahil & Orman Yolu",  city: city, timing: "Yarın · 09:00",         price: "₺80+",   matchPercent: 84, kind: .microActivity),
                MoodEvent(category: .aktivite, title: "Botanik Bahçe — Sabah Erken",      venue: "\(city) Botanik Bahçesi",     city: city, timing: "Yarın · 09:30",         price: "₺60",    matchPercent: 79, kind: .microActivity),
                MoodEvent(category: .aktivite, title: "SUP & Kano — Su Üstü",             venue: "\(city) Su Sporları Merkezi", city: city, timing: "Hafta sonu · 10:00",    price: "₺250+",  matchPercent: 75, kind: .microActivity),
                MoodEvent(category: .aktivite, title: "Yoga Retreati — Doğada",           venue: "\(city) Yakını Retreat",      city: city, timing: "Bu hafta sonu",         price: "₺400+",  matchPercent: 71, kind: .microActivity),
                MoodEvent(category: .aktivite, title: "Sabah Meditasyonu — Parkta",       venue: "\(city) Meditasyon Parkı",    city: city, timing: "Yarın · 07:00",         price: "Ücretsiz", matchPercent: 67, kind: .microActivity),
                MoodEvent(category: .aktivite, title: "Nehir & Göl Kıyısı Yürüyüşü",    venue: "\(city) Su Kenarı Rotası",    city: city, timing: "Yarın · 08:30",         price: "Ücretsiz", matchPercent: 63, kind: .microActivity),
            ]

        case "Huzurlu":
            return [
                MoodEvent(category: .aktivite, title: "Kitabevi Kafe — Saatlerce Oku",    venue: "\(city) Kitap Kafe",          city: city, timing: "Her gün açık",          price: "₺60+",   matchPercent: 94, kind: .microActivity),
                MoodEvent(category: .aktivite, title: "Müze Keyfi — Sabah Sessizliği",    venue: "\(city) Şehir Müzesi",        city: city, timing: "Yarın · 10:00",         price: "₺80+",   matchPercent: 89, kind: .microActivity),
                MoodEvent(category: .aktivite, title: "Meditasyon Merkezi Seansı",         venue: "\(city) Meditasyon Stüdyosu", city: city, timing: "Bu akşam · 19:00",      price: "₺150",   matchPercent: 85, kind: .microActivity),
                MoodEvent(category: .aktivite, title: "Sessiz Kafe — Çalış ya da Dinlen", venue: "\(city) Sessiz Kafe",         city: city, timing: "Her gün açık",          price: "₺80+",   matchPercent: 81, kind: .microActivity),
                MoodEvent(category: .aktivite, title: "Terapötik Yoga — Akşam Seansı",    venue: "\(city) Yoga Stüdyosu",       city: city, timing: "Bu akşam · 19:30",      price: "₺200+",  matchPercent: 77, kind: .microActivity),
                MoodEvent(category: .aktivite, title: "El İşi Atölyesi — Macramé",        venue: "\(city) El Sanatları Merkezi", city: city, timing: "Cumartesi · 14:00",   price: "₺250+",  matchPercent: 73, kind: .microActivity),
                MoodEvent(category: .aktivite, title: "Çay Bahçesi — Sakin Bir Köşe",    venue: "\(city) Tarihi Çay Bahçesi",  city: city, timing: "Her gün açık",          price: "₺50+",   matchPercent: 69, kind: .microActivity),
                MoodEvent(category: .aktivite, title: "Açık Hava Sinema — Sessiz Film",   venue: "\(city) Açık Hava Sineması",  city: city, timing: "Bu akşam · 21:00",      price: "₺90",    matchPercent: 65, kind: .microActivity),
            ]

        case "Özgür":
            return [
                MoodEvent(category: .aktivite, title: "Yamaç Paraşütü — Tandem Uçuş",    venue: "\(city) Yakını Paragliding",  city: city, timing: "Yarın · 10:00",         price: "₺2000+", matchPercent: 96, kind: .microActivity),
                MoodEvent(category: .aktivite, title: "Sörf Dersi — Başlangıç",           venue: "\(city) Sörf Okulu",          city: city, timing: "Hafta sonu · 09:00",    price: "₺400+",  matchPercent: 91, kind: .microActivity),
                MoodEvent(category: .aktivite, title: "Tırmanma Duvarı — Lead Climbing",  venue: "\(city) Tırmanma Merkezi",    city: city, timing: "Yarın · 11:00",         price: "₺220+",  matchPercent: 86, kind: .microActivity),
                MoodEvent(category: .aktivite, title: "Macera Parkı — Yüksek İp Parkuru", venue: "\(city) Macera Parkı",        city: city, timing: "Hafta sonu · 10:00",    price: "₺300+",  matchPercent: 82, kind: .microActivity),
                MoodEvent(category: .aktivite, title: "Kayak & Sandal — Doğa İçinde",    venue: "\(city) Göl veya Nehir",      city: city, timing: "Hafta sonu · 09:00",    price: "₺200+",  matchPercent: 78, kind: .microActivity),
                MoodEvent(category: .aktivite, title: "Bisikletle Şehir Dışı Kaçış",     venue: "\(city) Yolu",                city: city, timing: "Yarın · 08:00",         price: "Ücretsiz", matchPercent: 74, kind: .microActivity),
                MoodEvent(category: .aktivite, title: "Kamp — Çadır Kurma Gecesi",        venue: "\(city) Yakını Kamp Alanı",   city: city, timing: "Bu hafta sonu",         price: "₺150+",  matchPercent: 70, kind: .microActivity),
                MoodEvent(category: .aktivite, title: "Motosiklet & Scooter Turu",        venue: "\(city) Yakınları",           city: city, timing: "Bu öğleden sonra",      price: "₺500+",  matchPercent: 66, kind: .microActivity),
            ]

        case "Derin":
            return [
                MoodEvent(category: .aktivite, title: "Arthouse Sinema Seçkisi",          venue: "\(city) Bağımsız Sinema",     city: city, timing: "Bu akşam · 20:00",      price: "₺90",    matchPercent: 94, kind: .microActivity),
                MoodEvent(category: .aktivite, title: "Felsefe & Okuma Kulübü",           venue: "\(city) Kültür Merkezi",      city: city, timing: "Perşembe · 19:00",      price: "Ücretsiz", matchPercent: 89, kind: .microActivity),
                MoodEvent(category: .aktivite, title: "Yazı Atölyesi — Serbest Kalem",   venue: "\(city) Yazı Stüdyosu",       city: city, timing: "Cumartesi · 14:00",     price: "₺200+",  matchPercent: 84, kind: .microActivity),
                MoodEvent(category: .aktivite, title: "Tarihi Yapı & Sokak Turu",         venue: "\(city) Eski Semt",           city: city, timing: "Yarın · 10:00",         price: "Ücretsiz", matchPercent: 80, kind: .microActivity),
                MoodEvent(category: .aktivite, title: "Sabah Fotoğraf Turu — Işık Peşinde", venue: "\(city) Sokakları",        city: city, timing: "Yarın · 07:00",         price: "Ücretsiz", matchPercent: 76, kind: .microActivity),
                MoodEvent(category: .aktivite, title: "Gece Müze Turu — Özel Etkinlik",   venue: "\(city) Müzesi",              city: city, timing: "Cuma · 21:00",          price: "₺150+",  matchPercent: 72, kind: .microActivity),
                MoodEvent(category: .aktivite, title: "Şiir & Edebiyat Gecesi",           venue: "\(city) Kültür Merkezi",      city: city, timing: "Cuma · 19:30",          price: "₺80+",   matchPercent: 68, kind: .microActivity),
                MoodEvent(category: .aktivite, title: "Meditasyon & Nefes Çalışması",     venue: "\(city) Meditasyon Stüdyosu", city: city, timing: "Bu akşam · 18:30",     price: "₺150",   matchPercent: 64, kind: .microActivity),
            ]

        case "Nostaljik":
            return [
                MoodEvent(category: .aktivite, title: "Antika Çarşısı Turu",              venue: "\(city) Antika Pazarı",       city: city, timing: "Hafta sonu · 10:00",    price: "Ücretsiz", matchPercent: 95, kind: .microActivity),
                MoodEvent(category: .aktivite, title: "Retro Kafe — Eski Plak & Kahve",  venue: "\(city) Retro Kafe",          city: city, timing: "Her gün açık",          price: "₺80+",   matchPercent: 90, kind: .microActivity),
                MoodEvent(category: .aktivite, title: "Eski Semt Yürüyüşü — Fotoğraflı",venue: "\(city) Tarihi Mahalle",      city: city, timing: "Yarın · 10:00",         price: "Ücretsiz", matchPercent: 85, kind: .microActivity),
                MoodEvent(category: .aktivite, title: "Klasik Film Gecesi — Retrospektif",venue: "\(city) Arthouse Sineması",  city: city, timing: "Bu akşam · 20:00",      price: "₺90",    matchPercent: 80, kind: .microActivity),
                MoodEvent(category: .aktivite, title: "Eski Plak Mağazası Keşfi",         venue: "\(city) Plakçılar",           city: city, timing: "Her gün açık",          price: "Ücretsiz", matchPercent: 76, kind: .microActivity),
                MoodEvent(category: .aktivite, title: "Vintage & İkinci El Pazar",        venue: "\(city) Vintage Pazar",       city: city, timing: "Hafta sonu · 09:00",    price: "Ücretsiz", matchPercent: 72, kind: .microActivity),
                MoodEvent(category: .aktivite, title: "Fotoğraf Arşivi Sergisi",          venue: "\(city) Tarih Müzesi",        city: city, timing: "Ay sonuna kadar",       price: "₺60+",   matchPercent: 68, kind: .microActivity),
                MoodEvent(category: .aktivite, title: "Eski Kahvehane — Çay & Tavla",    venue: "\(city) Tarihi Kahvehane",    city: city, timing: "Her gün açık",          price: "₺30+",   matchPercent: 64, kind: .microActivity),
            ]

        case "Gizemli":
            return [
                MoodEvent(category: .aktivite, title: "Escape Room — Karanlık Tema",      venue: "\(city) Kaçış Oyunları",      city: city, timing: "Bu akşam · 20:00",      price: "₺250+",  matchPercent: 96, kind: .microActivity),
                MoodEvent(category: .aktivite, title: "Gece Şehir Turu — Karanlık Sokaklar", venue: "\(city) Gece Turu",       city: city, timing: "Bu gece · 22:00",        price: "₺150+",  matchPercent: 91, kind: .microActivity),
                MoodEvent(category: .aktivite, title: "Tarihi Yapı & Metruk Alan Turu",   venue: "\(city) Eski Semt",           city: city, timing: "Yarın · 17:00",         price: "Ücretsiz", matchPercent: 86, kind: .microActivity),
                MoodEvent(category: .aktivite, title: "Dedektif Oyunu — Canlı Rol",       venue: "\(city) Oyun Merkezi",        city: city, timing: "Bu akşam · 19:00",      price: "₺200+",  matchPercent: 82, kind: .microActivity),
                MoodEvent(category: .aktivite, title: "Gece Müze Turu",                   venue: "\(city) Müzesi",              city: city, timing: "Cuma · 21:00",          price: "₺150+",  matchPercent: 78, kind: .microActivity),
                MoodEvent(category: .aktivite, title: "Underground Müzik Sahnesi",        venue: "\(city) Müzik Sahnesi",       city: city, timing: "Bu gece · 23:00",        price: "₺150+",  matchPercent: 74, kind: .microActivity),
                MoodEvent(category: .aktivite, title: "Gece Fotoğraf Turu — Işık & Gölge", venue: "\(city) Sokakları",         city: city, timing: "Bu gece · 21:00",        price: "Ücretsiz", matchPercent: 70, kind: .microActivity),
                MoodEvent(category: .aktivite, title: "Astroloji & Tarot Atölyesi",       venue: "\(city) Alternatif Kafe",     city: city, timing: "Hafta sonu · 18:00",    price: "₺200+",  matchPercent: 66, kind: .microActivity),
            ]

        case "Hassas":
            return [
                MoodEvent(category: .aktivite, title: "Seramik Atölyesi — Çömlek Çekme", venue: "\(city) Seramik Stüdyosu",   city: city, timing: "Cumartesi · 13:00",     price: "₺280+",  matchPercent: 94, kind: .microActivity),
                MoodEvent(category: .aktivite, title: "Akustik Konser — Küçük Sahne",    venue: "\(city) Küçük Mekan",         city: city, timing: "Bu akşam · 20:00",      price: "₺150+",  matchPercent: 89, kind: .microActivity),
                MoodEvent(category: .aktivite, title: "Şiir Okuma Gecesi",               venue: "\(city) Kültür Merkezi",      city: city, timing: "Cuma · 19:30",          price: "₺60+",   matchPercent: 84, kind: .microActivity),
                MoodEvent(category: .aktivite, title: "Çiçek Düzenleme Atölyesi",        venue: "\(city) Çiçek Atölyesi",      city: city, timing: "Cumartesi · 14:00",     price: "₺300+",  matchPercent: 80, kind: .microActivity),
                MoodEvent(category: .aktivite, title: "İyileştirici Yoga — Gentle Seans", venue: "\(city) Yoga Stüdyosu",     city: city, timing: "Bu akşam · 19:00",      price: "₺200+",  matchPercent: 76, kind: .microActivity),
                MoodEvent(category: .aktivite, title: "Boyama Atölyesi — Serbest",       venue: "\(city) Sanat Atölyesi",      city: city, timing: "Pazar · 13:00",         price: "₺250+",  matchPercent: 72, kind: .microActivity),
                MoodEvent(category: .aktivite, title: "Su Kenarı Yürüyüşü — Sabah Erken", venue: "\(city) Su Kenarı",         city: city, timing: "Yarın · 07:30",         price: "Ücretsiz", matchPercent: 68, kind: .microActivity),
                MoodEvent(category: .aktivite, title: "Terapi Kafe — Sohbet & Çay",      venue: "\(city) Psikoloji Kafe",      city: city, timing: "Her gün açık",          price: "₺100+",  matchPercent: 64, kind: .microActivity),
            ]

        case "Sessiz":
            return [
                MoodEvent(category: .aktivite, title: "Spa & Türk Hamamı",               venue: "\(city) Tarihi Hamam",        city: city, timing: "Her gün açık",          price: "₺400+",  matchPercent: 95, kind: .microActivity),
                MoodEvent(category: .aktivite, title: "Nefes & Meditasyon Seansı",        venue: "\(city) Meditasyon Merkezi",  city: city, timing: "Bu akşam · 19:00",      price: "₺150",   matchPercent: 90, kind: .microActivity),
                MoodEvent(category: .aktivite, title: "Yüzme — Terapi Olarak",            venue: "\(city) Havuz veya Sahil",    city: city, timing: "Yarın · 08:00",         price: "₺80+",   matchPercent: 85, kind: .microActivity),
                MoodEvent(category: .aktivite, title: "Doğa Yürüyüşü — Yavaş Tempo",    venue: "\(city) Şehir Ormanı",        city: city, timing: "Yarın · 09:00",         price: "Ücretsiz", matchPercent: 81, kind: .microActivity),
                MoodEvent(category: .aktivite, title: "Bitki Dikme Atölyesi",             venue: "\(city) Botanik Merkezi",     city: city, timing: "Hafta sonu · 11:00",    price: "₺200+",  matchPercent: 77, kind: .microActivity),
                MoodEvent(category: .aktivite, title: "Sessiz Okuma Kafe",                venue: "\(city) Kitap Kafe",          city: city, timing: "Her gün açık",          price: "₺50+",   matchPercent: 73, kind: .microActivity),
                MoodEvent(category: .aktivite, title: "Tai Chi — Açık Hava Seansı",      venue: "\(city) Şehir Parkı",         city: city, timing: "Yarın · 08:00",         price: "Ücretsiz", matchPercent: 69, kind: .microActivity),
                MoodEvent(category: .aktivite, title: "Uyku Dostu Dinlenme Kafe",         venue: "\(city) Dinlenme Kafe",       city: city, timing: "Her gün açık",          price: "₺120+",  matchPercent: 65, kind: .microActivity),
            ]

        default: // "Nötr", "Temiz", ve bilinmeyen moodlar
            return [
                MoodEvent(category: .aktivite, title: "Pazar Yeri Sabah Turu",            venue: "\(city) Organik Pazar",       city: city, timing: "Hafta sonu · 08:00",    price: "Ücretsiz", matchPercent: 85, kind: .microActivity),
                MoodEvent(category: .aktivite, title: "Sabah Koşusu — 30 Dakika",        venue: "\(city) Koşu Parkuru",        city: city, timing: "Yarın · 07:30",         price: "Ücretsiz", matchPercent: 80, kind: .microActivity),
                MoodEvent(category: .aktivite, title: "Hafif Yürüyüş — Semt Keşfi",      venue: "\(city) Yürüyüş Rotası",      city: city, timing: "Yarın · 09:00",         price: "Ücretsiz", matchPercent: 76, kind: .microActivity),
                MoodEvent(category: .aktivite, title: "Kahvaltı Salonu — Klasik",         venue: "\(city) Kahvaltı Yeri",       city: city, timing: "Yarın · 09:00",         price: "₺100+",  matchPercent: 72, kind: .microActivity),
                MoodEvent(category: .aktivite, title: "Güneş Doğumu Seyri",               venue: "\(city) Seyir Tepesi",        city: city, timing: "Yarın · 06:30",         price: "Ücretsiz", matchPercent: 68, kind: .microActivity),
                MoodEvent(category: .aktivite, title: "Kısa Meditasyon — Park Köşesi",   venue: "\(city) Şehir Parkı",         city: city, timing: "Yarın · 08:00",         price: "Ücretsiz", matchPercent: 64, kind: .microActivity),
                MoodEvent(category: .aktivite, title: "Sağlıklı Kafe — Temiz Yeme",      venue: "\(city) Organik Restoran",    city: city, timing: "Her gün açık",          price: "₺150+",  matchPercent: 60, kind: .microActivity),
                MoodEvent(category: .aktivite, title: "Akşam Yürüyüşü — Günü Bitir",     venue: "\(city) Sahil veya Park",     city: city, timing: "Bu akşam · 19:00",      price: "Ücretsiz", matchPercent: 56, kind: .microActivity),
            ]
        }
    }
}

// MARK: - Seeded RNG (hour-bucket deterministic shuffle)

private struct SeededRNG: RandomNumberGenerator {
    private var state: UInt64
    init(seed: UInt64) { state = seed == 0 ? 1 : seed }
    mutating func next() -> UInt64 {
        state ^= state << 13
        state ^= state >> 7
        state ^= state << 17
        return state
    }
}
