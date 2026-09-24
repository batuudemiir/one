//
//  ProfileStoreTests.swift
//  oneTests
//
//  E12: kişiselleştirme profili (04_arka_plan_motorlari.md).
//

import Testing
import Foundation
@testable import OneDailyBatuhan

@MainActor
struct ProfileStoreTests {

    @Test("Varsayılanlar: günlük mod, seri görünür, geri dönüş açık, TR, tuz üretilmiş ve saklanmış")
    func defaults() throws {
        let cloud = MemoryKeyValueStore(), local = MemoryKeyValueStore()
        let store = ProfileStore(cloud: cloud, local: local)
        let p = store.profile
        #expect(p.ritualMode == .daily)
        #expect(p.streakVisible)
        #expect(p.resurfaceWritten)
        #expect(p.contentLang == "tr")
        #expect(p.quotePaths.isEmpty && p.freeQuotePath == nil)
        #expect(cloud.object(forKey: ProfileStore.Key.userSalt) as? String == p.userSalt.uuidString)
        #expect(local.object(forKey: ProfileStore.Key.userSalt) as? String == p.userSalt.uuidString)
    }

    @Test("Tuz yeniden açılışta aynı kalır ve güncellemeyle değişmez")
    func saltIsStable() {
        let cloud = MemoryKeyValueStore(), local = MemoryKeyValueStore()
        let salt = ProfileStore(cloud: cloud, local: local).profile.userSalt
        let reopened = ProfileStore(cloud: cloud, local: local)
        #expect(reopened.profile.userSalt == salt)
        reopened.update { $0.userSalt = UUID() }
        #expect(reopened.profile.userSalt == salt)
    }

    @Test("Güncelleme bulut ve yerel aynaya yazılır, ikinci cihaz aynı profili okur")
    func roundTrip() throws {
        let cloud = MemoryKeyValueStore()
        let store = ProfileStore(cloud: cloud, local: MemoryKeyValueStore())
        store.update {
            $0.name = "Deniz"
            $0.focusAreas = ["kaygi", "uyku"]
            $0.quotePaths = ["sakin", "filozof"]
            $0.ritualMode = .morningEvening
            $0.morningTime = ReminderTime(hour: 7, minute: 5)!
            $0.eveningTime = ReminderTime("22:40")!
            $0.streakVisible = false
            $0.resurfaceWritten = false
        }
        let other = ProfileStore(cloud: cloud, local: MemoryKeyValueStore())
        #expect(other.profile == store.profile)
        #expect(other.profile.freeQuotePath == "sakin")
        #expect(cloud.object(forKey: ProfileStore.Key.morningTime) as? String == "07:05")
    }

    @Test("Değişiklik revision'ı artırır ve değişen anahtarları yayınlar; değişmeyen güncelleme sessiz")
    func changeNotification() {
        let store = ProfileStore(cloud: MemoryKeyValueStore(), local: MemoryKeyValueStore())
        var keys: Set<String> = []
        let token = NotificationCenter.default.addObserver(forName: ProfileStore.didChange, object: store, queue: nil) { note in
            keys = note.userInfo?["keys"] as? Set<String> ?? []
        }
        defer { NotificationCenter.default.removeObserver(token) }

        store.update { $0.quotePaths = ["cesur"] }
        #expect(store.revision == 1)
        #expect(keys == [ProfileStore.Key.quotePaths])

        store.update { $0.quotePaths = ["cesur"] }
        #expect(store.revision == 1)
    }

    @Test("Bozuk değerler varsayılana düşer")
    func invalidValues() {
        let cloud = MemoryKeyValueStore()
        cloud.set("haftalik", forKey: ProfileStore.Key.ritualMode)
        cloud.set("25:99", forKey: ProfileStore.Key.morningTime)
        cloud.set("tuz-değil", forKey: ProfileStore.Key.userSalt)
        cloud.set(42, forKey: ProfileStore.Key.streakVisible)
        let p = ProfileStore(cloud: cloud, local: MemoryKeyValueStore()).profile
        #expect(p.ritualMode == .daily)
        #expect(p.morningTime == ReminderTime(hour: 8, minute: 30))
        #expect(p.streakVisible)
        #expect(cloud.object(forKey: ProfileStore.Key.userSalt) as? String == p.userSalt.uuidString)
    }

    @Test("Bulut boşsa yerel ayna okunur (iCloud kapalı)")
    func localFallback() {
        let local = MemoryKeyValueStore()
        local.set("morningEvening", forKey: ProfileStore.Key.ritualMode)
        #expect(ProfileStore(cloud: MemoryKeyValueStore(), local: local).profile.ritualMode == .morningEvening)
    }

    @Test("Uzak değişiklik yüklenir; tuz çakışmasında küçük UUID kazanır")
    func remoteChangeAndSaltConflict() {
        let cloud = MemoryKeyValueStore()
        let small = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
        let big = UUID(uuidString: "FFFFFFFF-0000-0000-0000-000000000001")!

        cloud.set(big.uuidString, forKey: ProfileStore.Key.userSalt)
        let store = ProfileStore(cloud: cloud, local: MemoryKeyValueStore())
        #expect(store.profile.userSalt == big)

        // Diğer cihaz kendi tuzunu ve yol seçimini yazdı.
        cloud.set(small.uuidString, forKey: ProfileStore.Key.userSalt)
        cloud.set(["filozof"], forKey: ProfileStore.Key.quotePaths)
        store.reloadFromCloud()
        #expect(store.profile.userSalt == small)
        #expect(store.profile.quotePaths == ["filozof"])
        #expect(store.revision == 1)

        // Ters yönde: gelen tuz büyükse yerel küçük tuz buluta geri yazılır.
        cloud.set(big.uuidString, forKey: ProfileStore.Key.userSalt)
        store.reloadFromCloud()
        #expect(store.profile.userSalt == small)
        #expect(cloud.object(forKey: ProfileStore.Key.userSalt) as? String == small.uuidString)
    }

    @Test("ReminderTime biçimi ve sınırları")
    func reminderTime() {
        #expect(ReminderTime("07:05")?.description == "07:05")
        #expect(ReminderTime("24:00") == nil)
        #expect(ReminderTime("7") == nil)
        #expect(ReminderTime(hour: 8, minute: 0)! < ReminderTime(hour: 21, minute: 0)!)
    }
}
