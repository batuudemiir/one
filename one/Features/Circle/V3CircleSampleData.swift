//
//  V3CircleSampleData.swift
//  one
//
//  Çevre ekranını gerçek CloudKit verisi olmadan görebilmek için örnek veri.
//  **Yalnızca DEBUG** — release derlemesinde bu dosya hiç derlenmez.
//
//  İki kullanım yolu:
//   1) Xcode Preview — `#Preview` blokları bunu doğrudan çağırıyor.
//   2) Simülatör/cihazda çalışan uygulama — şemaya launch argument ekle:
//        -v3.debug.sampleFriends YES
//      (Xcode › Product › Scheme › Edit Scheme › Run › Arguments)
//      Uygulama açıldığında Çevre sekmesi 5 örnek arkadaşla dolu gelir;
//      CloudKit'e hiç gidilmez.
//
//  Örnekler kasıtlı olarak farklı durumları kapsıyor:
//   - 1 anlı gün (düz şerit), 2 anlı, 3 anlı (çok renkli şerit)
//   - hiç paylaşmamış arkadaş (wash şerit + "Bugün paylaşmadı")
//   - kendi kartın için "paylaşıldı" ve "yalnız sen" kapsamı
//

#if DEBUG
import Foundation
import CloudKit

enum V3CircleSampleData {

    /// Launch argument / UserDefaults anahtarı.
    static var isEnabled: Bool {
        UserDefaults.standard.bool(forKey: "v3.debug.sampleFriends")
    }

    // MARK: - Arkadaşlar

    /// Prototipteki kart ızgarasını dolduran 5 örnek kişi.
    static func friends() -> [CloudKitManager.FriendCircleData] {
        [
            makeFriend(
                name: "Ela", userID: "sample-ela",
                moods: [(.huzurlu, "09:20"), (.mutlu, "14:05"), (.yorgun, "22:10")],
                song: ("Sen Ağlama", "Sezen Aksu")
            ),
            makeFriend(
                name: "Naz", userID: "sample-naz",
                moods: [(.gergin, "08:45"), (.odakli, "18:30")],
                song: ("Kalpsiz", "Sagopa Kajmer")
            ),
            makeFriend(
                name: "Mert", userID: "sample-mert",
                moods: [(.coskulu, "21:15")],
                song: ("Aşk", "Duman")
            ),
            makeFriend(
                name: "Deniz", userID: "sample-deniz",
                moods: [(.atesli, "07:50"), (.enerjik, "12:00"), (.huzunlu, "23:40")],
                song: nil
            ),
            makeFriend(
                name: "Kaan", userID: "sample-kaan",
                moods: [],
                song: nil
            )
        ]
    }

    private static func makeFriend(
        name: String,
        userID: String,
        moods: [(V3Mood, String)],
        song: (String, String)?
    ) -> CloudKitManager.FriendCircleData {
        let user = CKRecord(recordType: "AppUser")
        user["userID"] = userID as CKRecordValue
        user["displayName"] = name as CKRecordValue
        user["avatarColor"] = (moods.first?.0.hex ?? "#6E7482") as CKRecordValue

        let shares = moods.enumerated().map { index, pair -> CKRecord in
            let (mood, time) = pair
            let record = CKRecord(recordType: "DailyShare")
            record["userID"] = userID as CKRecordValue
            record["date"] = Calendar.current.startOfDay(for: Date()) as CKRecordValue
            record["createdAt"] = todayAt(time) as CKRecordValue
            record["entryIndex"] = index as CKRecordValue
            record["moodColor"] = mood.hex as CKRecordValue
            record["moodWord"] = mood.label as CKRecordValue
            if let song, index == 0 {
                record["songName"] = song.0 as CKRecordValue
                record["artistName"] = song.1 as CKRecordValue
            }
            return record
        }

        return CloudKitManager.FriendCircleData(user: user, shares: shares)
    }

    // MARK: - Kendi anların

    /// Kendi kartını dolduran örnek anlar — ikisi paylaşılmış, biri özel.
    static func myMoments() -> [Moment] {
        [
            makeMoment(mood: .odakli, time: "09:10", scope: .friends, index: 0),
            makeMoment(mood: .huzurlu, time: "15:35", scope: .friends, index: 1),
            makeMoment(mood: .huzunlu, time: "23:05", scope: .private, index: 2)
        ]
    }

    private static func makeMoment(mood: V3Mood, time: String, scope: MomentScope, index: Int) -> Moment {
        Moment(
            id: UUID(),
            date: Calendar.current.startOfDay(for: Date()),
            time: todayAt(time),
            moodIndex: V3Mood.allCases.firstIndex(of: mood) ?? 0,
            moodColorHex: mood.hex,
            note: index == 0 ? "Sabah sessizdi, iyi geldi." : nil,
            photoRef: nil,
            photoData: nil,
            songName: index == 0 ? "Sen Ağlama" : nil,
            songArtist: index == 0 ? "Sezen Aksu" : nil,
            scope: scope,
            entryIndex: index
        )
    }

    // MARK: - Yardımcı

    private static func todayAt(_ hhmm: String) -> Date {
        let parts = hhmm.split(separator: ":").compactMap { Int($0) }
        guard parts.count == 2 else { return Date() }
        return Calendar.current.date(
            bySettingHour: parts[0], minute: parts[1], second: 0, of: Date()
        ) ?? Date()
    }
}
#endif
