//
//  Moment.swift
//  one
//
//  v3 çekirdek veri modeli — talimattaki EN KRİTİK KIRILMA.
//
//  v2: bir gün = bir kayıt (`DailySong`), tarihte tekilik.
//  v3: bir gün = **N adet "an"**. Kullanıcı gün içinde istediği kadar kayıt yapar.
//
//  Bu dosya `DailySong` (Core Data) üzerine `Moment` (değer tipi) ve `Day`
//  (koleksiyon) sarmalayıcılarını sağlar. UI ve iş mantığı Moment/Day okur;
//  Core Data ile temas sadece Persistence katmanında kalır.
//
//  Migration:
//  - Şema zaten hazır: `entryIndex: Int16 default 0`, `createdAt: Date`,
//    `shareWithCircle: Bool`. Yeni sütun yok.
//  - Mevcut kayıtlar tek elemanlı `[Moment]` gibi okunuyor (entryIndex=0).
//  - `time` yoksa (eski kayıtta `createdAt` nil): 12:00 varsayılır.
//  - `scope` yoksa: v2'deki `shareWithCircle` bit'ine düşer; false ise `.private`.
//

import Foundation
import SwiftUI

// MARK: - Scope

/// Bu an kimde kalsın? — v3'ün "her an için kapsam" davranışı.
/// `.private` anlar Çevre'de, arkadaş kartlarında ve uyum hesabında
/// **hiç görünmez**. Filtreleme veri katmanında yapılır, UI'da değil.
enum MomentScope: String, Codable, Sendable {
    case friends
    case `private`

    /// v2'deki tek-Bool alanına köprü.
    init(shareWithCircle: Bool) {
        self = shareWithCircle ? .friends : .private
    }

    var shareWithCircle: Bool {
        self == .friends
    }
}

// MARK: - Moment

/// Tek bir "an" — gün içindeki bir kayıt.
///
/// `DailySong`'un salt-okunur değer tipi görüntüsü. Yaratma/güncelleme hâlâ
/// `DailySong` (NSManagedObject) üzerinden gidiyor; okuma yolları bu struct'ı
/// alsın diye.
struct Moment: Identifiable, Hashable, Sendable {
    let id: UUID
    /// Günü normalize edilmiş tarih (00:00). Aynı gün içindeki anlar aynı `date`'i taşır.
    let date: Date
    /// Anın gerçek saati. Aynı gündeki anlar bunun üzerinden sıralanır.
    let time: Date
    /// v3 9-mood ızgarasındaki index (0..8).
    let moodIndex: Int
    /// v2'den gelen legacy hex (v3 renk fromHex ile bridge edilir).
    let moodColorHex: String
    /// ≤ 140 karakter. `nil` = not yazılmadı.
    let note: String?
    /// Fotoğraf referansı — dosya URL veya iCloud asset. Şu an prototip
    /// tarafı `photoData` / `photoURL` kullanıyor; her ikisi olabilir.
    let photoRef: String?
    /// Fotoğraf binary — Core Data'da inline saklanan JPEG. UI okumalarında
    /// bu doğrudan `Image(uiImage: UIImage(data:))` ile çizilir; `photoRef`
    /// bir URL string ise ondan yüklenir. `hasPhoto` ikisini birden görür.
    let photoData: Data?
    /// Şarkı adı + sanatçı birleşik değil — ayrı alanlar. `hasSong` shortcut.
    let songName: String?
    let songArtist: String?
    /// Paylaşım kapsamı — v3'te an başına ayrı.
    let scope: MomentScope
    /// Kaydın gün içindeki sırası (0..N-1). Eski kayıtlar 0.
    let entryIndex: Int
    /// "Pas geçildi" günü. `Persistence.savePassedDay` gri bir hex (`#9E9E9E`)
    /// yazıyor; renk sayımı bunu bir duygu sanıp "Yorgun"a katıyordu.
    /// İstatistik yüzeyleri bunu dışarıda bırakmalı.
    var passed: Bool = false

    var hasSong: Bool {
        let n = songName?.trimmingCharacters(in: .whitespacesAndNewlines)
        let a = songArtist?.trimmingCharacters(in: .whitespacesAndNewlines)
        return !(n?.isEmpty ?? true) || !(a?.isEmpty ?? true)
    }
    var hasPhoto: Bool { photoRef != nil || (photoData?.isEmpty == false) }
    var hasNote: Bool { note?.isEmpty == false }
}

// MARK: - Day

/// Bir günün tüm anları. Boş gün = `moments == []`.
///
/// Mozaik karesi, yıl özeti, widget, hafta şeridi ve poster — hepsi `Day`
/// üzerinden çalışır. Tek renk mi, diyagonal dilim mi karar veren
/// `dayFillColors` yardımcı bilgisi buradan çıkar.
struct Day: Identifiable, Hashable, Sendable {
    var id: Date { date }
    let date: Date
    /// `time` artan sırada.
    let moments: [Moment]

    var isEmpty: Bool { moments.isEmpty }
    var count: Int { moments.count }

    /// Mozaik/widget karesinde kullanılacak renk(ler). Boş gün için `[]`.
    /// 1 an = 1 renk (düz), 2-3+ an = eşit dilimler için renk listesi.
    var fillHexes: [String] {
        moments.map(\.moodColorHex)
    }

    /// Filtered view — `.private` anlar dışarıda. Çevre, arkadaş kartları
    /// ve uyum hesabı bunu okumalı.
    var publicDay: Day {
        Day(date: date, moments: moments.filter { $0.scope == .friends })
    }
}

// MARK: - DailySong bridge

extension Moment {

    /// `DailySong` (NSManagedObject) → değer tipi köprüsü. Zorunlu alanlar
    /// yoksa `nil` — okuma yolları defensive olsun.
    ///
    /// - Note: Core Data attribute'larının hepsi optional; runtime'da yoksa
    ///   makul varsayılanlar (12:00, entryIndex=0, scope=.private) uygulanır.
    init?(from song: Any) {
        // Herhangi bir tipi kabul et — Persistence katmanında `DailySong`
        // olarak çağrılacak, KVC ile okunur. Bu dolaylılık `Core/Models/`'de
        // NSManagedObject import etmemek için.
        guard let obj = song as? NSObject else { return nil }
        guard let rawDate = obj.value(forKey: "date") as? Date else { return nil }

        // `id` eskiden zorunluydu ve nil ise satır tamamen düşüyordu. Şarkı
        // akışı (`saveDailySong`) uzun süre id yazmadığı için kullanıcıların
        // mevcut kayıtlarının bir kısmı Profil istatistiklerinde ve renk
        // dağılımında hiç görünmüyordu. Artık gün + sıra numarasından
        // deterministik bir id türetiliyor: aynı satır her okumada aynı
        // kimliği alır (ForEach kimliği kaymaz), veri de kaybolmaz.
        let rawIndex = (obj.value(forKey: "entryIndex") as? Int16).map(Int.init)
            ?? (obj.value(forKey: "entryIndex") as? Int)
            ?? 0
        if let stored = obj.value(forKey: "id") as? UUID {
            self.id = stored
        } else {
            self.id = Moment.derivedID(date: rawDate, entryIndex: rawIndex)
        }
        self.date = Calendar.current.startOfDay(for: rawDate)
        // time: createdAt varsa onu kullan, yoksa 12:00'a düş (talimat).
        if let created = obj.value(forKey: "createdAt") as? Date {
            self.time = created
        } else {
            self.time = Calendar.current.date(bySettingHour: 12, minute: 0, second: 0, of: rawDate) ?? rawDate
        }

        self.moodColorHex = (obj.value(forKey: "moodColorHex") as? String) ?? ""

        // v3 9-mood index — V3Mood.fromHex hex → v3 mood bridge.
        if let v3 = V3Mood.fromHex(self.moodColorHex) {
            self.moodIndex = V3Mood.allCases.firstIndex(of: v3) ?? 0
        } else {
            self.moodIndex = 0
        }

        self.note = obj.value(forKey: "dailyNote") as? String
        self.photoRef = obj.value(forKey: "photoURL") as? String
        self.photoData = obj.value(forKey: "photoData") as? Data
        self.songName = obj.value(forKey: "songName") as? String
        self.songArtist = obj.value(forKey: "artistName") as? String

        // Scope: v3'te `shareWithCircle` (yeni bool alan) tercih; yoksa
        // eski `isSharedWithCircle`. İkisi de false = private.
        let scopeBool = (obj.value(forKey: "shareWithCircle") as? Bool)
            ?? (obj.value(forKey: "isSharedWithCircle") as? Bool)
            ?? false
        self.scope = MomentScope(shareWithCircle: scopeBool)

        // entryIndex: eski kayıtlarda default 0.
        self.entryIndex = rawIndex

        // "Pas geçildi" günleri gerçek bir duygu değil — gri bir yer tutucu.
        self.passed = (obj.value(forKey: "passed") as? Bool) ?? false
    }

    /// `id` taşımayan eski satırlar için deterministik kimlik. Gün + sıra
    /// numarasından UUID v5 benzeri sabit bir değer üretir; rastgele UUID
    /// kullanmak her okumada kimliği değiştirir ve `ForEach`'i sıçratırdı.
    static func derivedID(date: Date, entryIndex: Int) -> UUID {
        let day = Int(Calendar.current.startOfDay(for: date).timeIntervalSince1970)
        var bytes = [UInt8](repeating: 0, count: 16)
        var value = UInt64(bitPattern: Int64(day))
        for i in 0..<8 {
            bytes[i] = UInt8(truncatingIfNeeded: value)
            value >>= 8
        }
        var index = UInt64(bitPattern: Int64(entryIndex))
        for i in 8..<16 {
            bytes[i] = UInt8(truncatingIfNeeded: index)
            index >>= 8
        }
        return UUID(uuid: (bytes[0], bytes[1], bytes[2], bytes[3],
                           bytes[4], bytes[5], bytes[6], bytes[7],
                           bytes[8], bytes[9], bytes[10], bytes[11],
                           bytes[12], bytes[13], bytes[14], bytes[15]))
    }
}

// MARK: - Grouping helpers

extension Array where Element == Moment {

    /// Anları güne göre grupla ve sırala. `[Moment]` → `[Day]`.
    func groupedByDay() -> [Day] {
        let groups = Dictionary(grouping: self) { moment in
            Calendar.current.startOfDay(for: moment.date)
        }
        return groups.map { key, value in
            Day(date: key, moments: value.sorted(by: { $0.time < $1.time }))
        }.sorted(by: { $0.date < $1.date })
    }
}
