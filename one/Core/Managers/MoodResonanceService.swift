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

        var notifiedIDs = resonanceNotifiedIDs(dateKey: dateKey)
        guard !notifiedIDs.contains(friendUserID) else { return }

        let diff = Color.hsbHueDifference(hex1: myHex, hex2: friendColorHex)
        guard diff <= Self.resonanceHueTolerance else { return }

        scheduleResonanceNotification(friendName: friendName, friendUserID: friendUserID)
        notifiedIDs.insert(friendUserID)
        saveResonanceNotifiedIDs(notifiedIDs, dateKey: dateKey)
    }

    // MARK: - Private helpers

    private func scheduleResonanceNotification(friendName: String, friendUserID: String) {
        scheduleLocalNotification(
            title: "Çevre Yankısı 🎨",
            body:  "Bugün \(friendName) ile aynı tonda hissediyorsunuz.",
            category: "MOOD_RESONANCE",
            userInfo: ["type": "mood_resonance", "friendUserID": friendUserID]
        )
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
