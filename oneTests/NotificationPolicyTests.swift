//
//  NotificationPolicyTests.swift
//  oneTests
//
//  Bildirim motorunun kararlarını test eder: sessiz saatler, proaktiflik,
//  öncelik ve v4'te kalan tür kümesi.
//
//  Neden bu üçü: motor bir metin üreticisi değil, bir **karar** motoru.
//  Yanlış kararın belirtisi sessiz — kullanıcıya gece 03:00'te bildirim
//  gider ya da hiç gitmez, ikisi de derlemede görünmez.
//

import Testing
import Foundation
@testable import OneDailyBatuhan

struct NotificationPolicyTests {

    // MARK: - Sessiz saatler

    /// Gece yarısını saran aralık (22 → 09) en kolay yanlış yazılan yer:
    /// `hour >= start && hour < end` yazarsan aralık boş kalır.
    @Test("Sessiz saatler gece yarısını sarar")
    func quietHoursWrapMidnight() {
        let quiet = QuietHours.default          // 22 → 09
        #expect(quiet.start == 22)
        #expect(quiet.end == 9)

        #expect(quiet.contains(at(23)))
        #expect(quiet.contains(at(3)))
        #expect(quiet.contains(at(8)))
        #expect(quiet.contains(at(22)))         // başlangıç dahil

        #expect(!quiet.contains(at(9)))         // bitiş hariç
        #expect(!quiet.contains(at(13)))
        #expect(!quiet.contains(at(21)))
    }

    @Test("Sessiz saat kapalıyken hiçbir saat sessiz değil")
    func quietHoursDisabled() {
        let off = QuietHours(start: 0, end: 0)
        for hour in 0..<24 {
            #expect(!off.contains(at(hour)))
        }
    }

    @Test("nextActiveWindow sessiz saatten sonraki ilk saate taşır")
    func nextActiveWindowMovesForward() {
        let quiet = QuietHours.default
        let deferred = quiet.nextActiveWindow(after: at(2, minute: 30))
        let comps = Calendar.current.dateComponents([.hour, .minute], from: deferred)
        #expect(comps.hour == 9)
        #expect(comps.minute == 0)
    }

    @Test("Sessiz saat dışındaki tarih olduğu gibi kalır")
    func nextActiveWindowKeepsActiveDate() {
        let quiet = QuietHours.default
        let fire = at(14)
        #expect(quiet.nextActiveWindow(after: fire) == fire)
    }

    // MARK: - Tür kümesi (v4)

    /// v4'te 21 tür 13'e indi. Sayı bir "hedef" değil, bir sözleşme: bu test
    /// kırıldıysa ya bir tür geri geldi ya da bilerek kaldırıldı — ikisi de
    /// gözden geçirilmeli.
    @Test("v4'te 13 bildirim türü var")
    func kindCount() {
        #expect(NotificationKind.allCases.count == 13)
    }

    @Test("Silinen seriler geri gelmedi")
    func retiredKindsStayRetired() {
        let retired = ["winBack3", "winBack7", "winBack14", "winBack30",
                       "nurtureDay1", "nurtureDay2", "nurtureDay3",
                       "circleInviteWave"]
        for raw in retired {
            #expect(NotificationKind(rawValue: raw) == nil)
        }
    }

    // MARK: - Proaktiflik

    /// Proaktif = uygulamanın kendi inisiyatifi. v4'te üç tane: günlük ritüel,
    /// haftalık ve aylık portre. Sosyal olaylar bir insanın eylemine yanıt,
    /// bu yüzden bütçeye girmez.
    @Test("Yalnız üç tür proaktif")
    func proactiveKinds() {
        let proactive = NotificationKind.allCases.filter(\.isProactive)
        #expect(Set(proactive) == [.dailyReminder, .weeklySummary, .monthEndSummary])
    }

    @Test("Sosyal olaylar reaktif")
    func socialKindsAreReactive() {
        for kind in [NotificationKind.friendShared, .friendRequest, .friendAccepted,
                     .friendReaction, .moodResonance, .circleActivity] {
            #expect(!kind.isProactive)
        }
    }

    // MARK: - Öncelik

    /// Kritik olanlar sessiz saati delebiliyor (Orchestrator `priority <
    /// .critical` ile kapıyor). Yani bu sıralama bir davranış, süs değil.
    @Test("Arkadaş olayları kritik, portreler normal")
    func priorityOrdering() {
        #expect(NotificationKind.friendRequest.priority == .critical)
        #expect(NotificationKind.friendAccepted.priority == .critical)
        #expect(NotificationKind.friendShared.priority == .critical)
        #expect(NotificationKind.dailyReminder.priority == .normal)
        #expect(NotificationKind.weeklySummary.priority == .normal)
        #expect(NotificationKind.friendReaction.priority > NotificationKind.dailyReminder.priority)
    }

    // MARK: - TimeOfDay

    @Test("TimeOfDay sınırları")
    func timeOfDayBoundaries() {
        #expect(TimeOfDay.from(at(5)) == .morning)
        #expect(TimeOfDay.from(at(11)) == .morning)
        #expect(TimeOfDay.from(at(12)) == .noon)
        #expect(TimeOfDay.from(at(16)) == .noon)
        #expect(TimeOfDay.from(at(17)) == .evening)
        #expect(TimeOfDay.from(at(21)) == .evening)
        #expect(TimeOfDay.from(at(22)) == .night)
        #expect(TimeOfDay.from(at(4)) == .night)
    }

    // MARK: - Helper

    private func at(_ hour: Int, minute: Int = 0) -> Date {
        var comps = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        comps.hour = hour
        comps.minute = minute
        return Calendar.current.date(from: comps)!
    }
}
