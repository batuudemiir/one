//
//  MoodResonanceService.swift
//  one
//
//  Çevre Yankısı — Circle Mood Resonance
//  Aynı gün benzer mood rengi seçen Circle arkadaşları için sessiz bir bağlantı bildirimi.
//  Herhangi bir paylaşım veya sosyal baskı yok — sadece sessiz bir rezonans hissi.
//

import Foundation
import CloudKit
import SwiftUI
import Combine
import UserNotifications

// MARK: - Mood Resonance

extension CloudKitManager {

    // ±20° HSB farkı içindeki renkler "rezonant" sayılır.
    private static let resonanceHueTolerance: Double = 20.0

    // UserDefaults key prefixes
    private static let resonanceNotifiedPrefix = "resonance_notified_"
    static let resonanceMoodColorPrefix       = "resonance_myMoodColorHex_"

    // MARK: - Public API

    /// Kullanıcı bugünkü rengini kaydettikten sonra çağrılır.
    /// Arkadaşların DailyShare renklerini çekerek ±20° içinde olanlar için
    /// yerel bildirim gönderir. Her arkadaş için günde en fazla bir bildirim.
    func checkMoodResonance(myMoodColorHex: String, date: Date = Date()) {
        guard !myMoodColorHex.isEmpty else { return }

        let today    = Calendar.current.startOfDay(for: date)
        let dateKey  = Self.dateKey(for: today)

        // Kullanıcının rengini sakla — push handler da buradan okur.
        UserDefaults.standard.set(myMoodColorHex,
                                  forKey: "\(Self.resonanceMoodColorPrefix)\(dateKey)")

        fetchFriendsDailyShares(for: date) { [weak self] result in
            guard let self, case .success(let shares) = result else { return }

            var notifiedIDs = self.resonanceNotifiedIDs(dateKey: dateKey)
            var changed = false

            for friendData in shares {
                guard
                    let share       = friendData.share,
                    let friendHex   = share["moodColor"] as? String,
                    let friendID    = share["userID"]    as? String,
                    !friendID.isEmpty,
                    !notifiedIDs.contains(friendID)
                else { continue }

                let diff = Color.hsbHueDifference(hex1: myMoodColorHex, hex2: friendHex)
                guard diff <= Self.resonanceHueTolerance else { continue }

                let name = friendData.user["displayName"] as? String ?? "Arkadaşın"
                self.scheduleResonanceNotification(friendName: name, friendUserID: friendID)
                notifiedIDs.insert(friendID)
                changed = true
            }

            if changed {
                self.saveResonanceNotifiedIDs(notifiedIDs, dateKey: dateKey)
            }
        }
    }

    /// Arkadaşın paylaşım push'u geldiğinde çağrılır.
    /// Kullanıcı bugün zaten kayıt yaptıysa renk karşılaştırması yapılır.
    func checkResonanceForFriendShare(friendColorHex: String,
                                      friendUserID: String,
                                      friendName: String,
                                      date: Date = Date()) {
        let today   = Calendar.current.startOfDay(for: date)
        let dateKey = Self.dateKey(for: today)

        guard
            let myHex = UserDefaults.standard.string(
                forKey: "\(Self.resonanceMoodColorPrefix)\(dateKey)"),
            !myHex.isEmpty
        else { return }  // Kullanıcı bugün henüz seçim yapmamış

        let notifiedIDs = resonanceNotifiedIDs(dateKey: dateKey)
        guard !notifiedIDs.contains(friendUserID) else { return }

        let diff = Color.hsbHueDifference(hex1: myHex, hex2: friendColorHex)
        guard diff <= Self.resonanceHueTolerance else { return }

        let friendShareID = "friendShare_\(friendUserID)_\(dateKey)"

        UNUserNotificationCenter.current().getDeliveredNotifications { delivered in
            let alreadyDelivered = delivered.contains { $0.request.identifier == friendShareID }
            if alreadyDelivered {
                ONELogger.info("Resonance skipped — friendShare already delivered for \(friendUserID)", category: .notification)
                return
            }
            UNUserNotificationCenter.current().getPendingNotificationRequests { pending in
                let alreadyPending = pending.contains { $0.identifier == friendShareID }
                if alreadyPending {
                    ONELogger.info("Resonance skipped — friendShare pending for \(friendUserID)", category: .notification)
                    return
                }
                DispatchQueue.main.async { [weak self] in
                    guard let self else { return }
                    self.scheduleResonanceNotification(friendName: friendName, friendUserID: friendUserID)
                    var ids = self.resonanceNotifiedIDs(dateKey: dateKey)
                    ids.insert(friendUserID)
                    self.saveResonanceNotifiedIDs(ids, dateKey: dateKey)
                }
            }
        }
    }

    // MARK: - Private helpers

    private func scheduleResonanceNotification(friendName: String, friendUserID: String) {
        // Kullanıcının bugünkü mood rengini al
        let today   = Calendar.current.startOfDay(for: Date())
        let dateKey = Self.dateKey(for: today)
        let myHex   = UserDefaults.standard.string(
            forKey: "\(Self.resonanceMoodColorPrefix)\(dateKey)")

        // v4: başlık kişi, gövde olgu — "Deniz / Bugün senin gibi huzurlu."
        // Duyguyu iki kullanıcı da kendisi seçti; uygulama yalnız örtüşmeyi
        // bildiriyor, yorumlamıyor.
        let msg = NotificationMessageBuilder.social(
            .moodResonance,
            friendName: friendName,
            moodLabel: EngagementTracker.lastMoodLabel
        )

        scheduleLocalNotification(
            title: msg.title,
            body:  msg.body,
            category: "MOOD_RESONANCE",
            userInfo: ["type": "mood_resonance", "friendUserID": friendUserID]
        )

        // Store'a moodResonance bildirimi ekle — birleşik akışta gösterim için
        let notif = CircleNotification(
            id: "moodResonance_\(friendUserID)_\(dateKey)",
            type: .moodResonance,
            title: msg.title,
            body: msg.body,
            date: Date(),
            isRead: false,
            relatedUserID: friendUserID,
            emoji: nil,
            moodColorHex: myHex
        )
        Task { @MainActor in CircleNotificationStore.shared.add(notif) }

        ONELogger.success("Çevre Yankısı: \(friendName) ile rezonans bildirimi gönderildi.",
                          category: .circle)
    }

    private func resonanceNotifiedIDs(dateKey: String) -> Set<String> {
        let arr = UserDefaults.standard.array(
            forKey: "\(Self.resonanceNotifiedPrefix)\(dateKey)") as? [String] ?? []
        return Set(arr)
    }

    private func saveResonanceNotifiedIDs(_ ids: Set<String>, dateKey: String) {
        UserDefaults.standard.set(Array(ids),
                                  forKey: "\(Self.resonanceNotifiedPrefix)\(dateKey)")
    }

    private static func dateKey(for date: Date) -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        return fmt.string(from: date)
    }
}
