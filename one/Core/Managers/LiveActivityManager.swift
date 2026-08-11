//
//  LiveActivityManager.swift
//  one
//

import Foundation
import ActivityKit
import Combine
import UIKit

// DailySongActivityAttributes ve FriendShareActivityAttributes
// ActivityAttributes.swift dosyasında tanımlı — hem bu target hem extension paylaşır.

@available(iOS 16.1, *)
final class LiveActivityManager {
    static let shared = LiveActivityManager()

    /// Foreground'a her geçişte expired activity'leri temizle
    private init() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleForeground),
            name: UIApplication.willEnterForegroundNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleForeground),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
    }

    @objc private func handleForeground() {
        Task { await cleanupExpiredActivities() }
    }

    // MARK: - Daily Song
    // Kutlama arc'ı: 0–5sn kutlama → 5–300sn normal → kapanış

    /// Live Activity'nin başlatıldığı zaman damgası — uygulama kapatılsa
    /// bile UserDefaults üzerinden korunur, tekrar açılınca temizlenir.
    private static let activityStartKey       = "dailySongActivityStartTime"
    private static let friendShareStartKey    = "friendShareActivityStartTime"
    /// Toplam gösterim süresi (saniye): 5 kutlama + 295 normal = 300
    static let activityDuration:    TimeInterval = 300   // 5 dk
    static let friendShareDuration: TimeInterval = 120   // 2 dk

    func startDailySong(
        songName: String,
        artistName: String,
        moodLabel: String,
        moodColorHex: String,
        moodIsDark: Bool,
        moodSFSymbol: String,
        streakCount: Int
    ) async {
        // v3: Live Activity + Dynamic Island şimdilik iptal (Features.liveActivitiesEnabled).
        guard Features.liveActivitiesEnabled else { return }
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            ONELogger.debug("DailySong Live Activity: aktiviteler kapalı.", category: .general)
            return
        }

        for activity in Activity<DailySongActivityAttributes>.activities {
            await activity.end(
                ActivityContent(state: activity.content.state, staleDate: nil),
                dismissalPolicy: .immediate
            )
        }

        let animStyle = Self.animationStyle(forMoodLabel: moodLabel)
        let endDate   = Date().addingTimeInterval(Self.activityDuration)

        // Başlangıç zamanını kaydet — uygulama kapatılırsa cleanup'ta kullanılır
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: Self.activityStartKey)

        // İlk state: kutlama (isCelebrating = true)
        let celebrationState = DailySongActivityAttributes.ContentState(
            songName: songName,
            artistName: artistName,
            moodLabel: moodLabel,
            moodColorHex: moodColorHex,
            moodIsDark: moodIsDark,
            moodSFSymbol: moodSFSymbol,
            streakCount: streakCount,
            isCelebrating: true,
            moodAnimationStyle: animStyle
        )

        let attributes = DailySongActivityAttributes(savedAt: Date())
        let content = ActivityContent(
            state: celebrationState,
            staleDate: endDate
        )

        do {
            let activity = try Activity<DailySongActivityAttributes>.request(
                attributes: attributes,
                content: content,
                pushType: nil
            )
            ONELogger.success("DailySong Live Activity başlatıldı: \(activity.id)", category: .general)

            Task { @MainActor in
                // 5 saniye sonra normal moda geç
                try? await Task.sleep(nanoseconds: 5_000_000_000)
                let normalState = DailySongActivityAttributes.ContentState(
                    songName: songName,
                    artistName: artistName,
                    moodLabel: moodLabel,
                    moodColorHex: moodColorHex,
                    moodIsDark: moodIsDark,
                    moodSFSymbol: moodSFSymbol,
                    streakCount: streakCount,
                    isCelebrating: false,
                    moodAnimationStyle: animStyle
                )
                await activity.update(ActivityContent(state: normalState, staleDate: endDate))

                // 4dk 55sn daha bekle (toplam 5dk) ve kapat
                try? await Task.sleep(nanoseconds: 295_000_000_000)
                await activity.end(
                    ActivityContent(state: normalState, staleDate: nil),
                    dismissalPolicy: .immediate
                )
                UserDefaults.standard.removeObject(forKey: Self.activityStartKey)
                ONELogger.debug("DailySong Live Activity kapandı.", category: .general)
            }
        } catch {
            ONELogger.warning("DailySong Live Activity başlatılamadı: \(error.localizedDescription)", category: .general)
        }
    }

    /// Uygulama her foreground'a geçtiğinde + açılışta çağrılır.
    /// Süresi dolmuş tüm activity'leri (DailySong + FriendShare) kapatır.
    func cleanupExpiredActivities() async {
        // DailySong: 5 dk
        let dailyStart = UserDefaults.standard.double(forKey: Self.activityStartKey)
        if dailyStart > 0 {
            let age = Date().timeIntervalSince1970 - dailyStart
            if age >= Self.activityDuration {
                for activity in Activity<DailySongActivityAttributes>.activities {
                    await activity.end(
                        ActivityContent(state: activity.content.state, staleDate: nil),
                        dismissalPolicy: .immediate
                    )
                }
                UserDefaults.standard.removeObject(forKey: Self.activityStartKey)
                ONELogger.debug("Süresi dolan DailySong Live Activity temizlendi (\(Int(age))sn).", category: .general)
            }
        }

        // FriendShare: 2 dk
        let friendStart = UserDefaults.standard.double(forKey: Self.friendShareStartKey)
        if friendStart > 0 {
            let age = Date().timeIntervalSince1970 - friendStart
            if age >= Self.friendShareDuration {
                for activity in Activity<FriendShareActivityAttributes>.activities {
                    await activity.end(
                        ActivityContent(state: activity.content.state, staleDate: nil),
                        dismissalPolicy: .immediate
                    )
                }
                UserDefaults.standard.removeObject(forKey: Self.friendShareStartKey)
                ONELogger.debug("Süresi dolan FriendShare Live Activity temizlendi (\(Int(age))sn).", category: .general)
            }
        }

        // Güvenlik ağı: UserDefaults yoksa ama orphan activity varsa onları da kapat
        // (örn. eski sürümlerden kalmış activity'ler)
        for activity in Activity<DailySongActivityAttributes>.activities {
            // attributes.savedAt 5 dakikadan eski mi?
            let savedAt = activity.attributes.savedAt
            if Date().timeIntervalSince(savedAt) > Self.activityDuration {
                await activity.end(
                    ActivityContent(state: activity.content.state, staleDate: nil),
                    dismissalPolicy: .immediate
                )
                ONELogger.debug("Orphan DailySong activity kapatıldı (savedAt: \(savedAt)).", category: .general)
            }
        }
    }

    // MARK: - Friend Share (~2 dk)

    func startFriendShare(
        friendName: String,
        songName: String,
        artistName: String,
        moodLabel: String,
        moodColorHex: String,
        moodSFSymbol: String
    ) async {
        // v3: Live Activity + Dynamic Island şimdilik iptal.
        guard Features.liveActivitiesEnabled else { return }
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        for activity in Activity<FriendShareActivityAttributes>.activities {
            await activity.end(
                ActivityContent(state: activity.content.state, staleDate: nil),
                dismissalPolicy: .immediate
            )
        }

        let endDate = Date().addingTimeInterval(Self.friendShareDuration)
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: Self.friendShareStartKey)

        let state = FriendShareActivityAttributes.ContentState(
            friendName: friendName,
            songName: songName,
            artistName: artistName,
            moodLabel: moodLabel,
            moodColorHex: moodColorHex,
            moodSFSymbol: moodSFSymbol
        )
        let content = ActivityContent(state: state, staleDate: endDate)

        do {
            let activity = try Activity<FriendShareActivityAttributes>.request(
                attributes: FriendShareActivityAttributes(receivedAt: Date()),
                content: content,
                pushType: nil
            )
            ONELogger.success("FriendShare Live Activity başlatıldı: \(activity.id)", category: .general)

            Task { @MainActor in
                try? await Task.sleep(nanoseconds: UInt64(Self.friendShareDuration) * 1_000_000_000)
                await activity.end(
                    ActivityContent(state: state, staleDate: nil),
                    dismissalPolicy: .immediate
                )
                UserDefaults.standard.removeObject(forKey: Self.friendShareStartKey)
                ONELogger.debug("FriendShare Live Activity kapandı.", category: .general)
            }
        } catch {
            ONELogger.warning("FriendShare Live Activity başlatılamadı: \(error.localizedDescription)", category: .general)
        }
    }

    // MARK: - End All

    func endAllActivities() async {
        for activity in Activity<DailySongActivityAttributes>.activities {
            await activity.end(
                ActivityContent(state: activity.content.state, staleDate: nil),
                dismissalPolicy: .immediate
            )
        }
        for activity in Activity<FriendShareActivityAttributes>.activities {
            await activity.end(
                ActivityContent(state: activity.content.state, staleDate: nil),
                dismissalPolicy: .immediate
            )
        }
        UserDefaults.standard.removeObject(forKey: Self.activityStartKey)
        UserDefaults.standard.removeObject(forKey: Self.friendShareStartKey)
    }

    // MARK: - Helpers

    /// Mood label → SF Symbol
    static func sfSymbol(forMoodLabel label: String) -> String {
        let map: [String: String] = [
            "ateş":     "flame.fill",
            "enerji":   "bolt.fill",
            "ışık":     "sun.max.fill",
            "taze":     "leaf.fill",
            "huzur":    "water.waves",
            "özgür":    "wind",
            "derin":    "moon.fill",
            "özlem":    "clock.fill",
            "loş":      "sparkles",
            "kırılgan": "heart.fill",
            "boşluk":   "circle.dotted",
            "sessiz":   "snowflake"
        ]
        return map[label] ?? "music.note"
    }

    /// Mood label → animasyon stili ("energetic" | "calm" | "deep")
    static func animationStyle(forMoodLabel label: String) -> String {
        switch label {
        case "ateş", "enerji", "ışık":
            return "energetic"
        case "derin", "özlem", "loş", "kırılgan", "boşluk", "sessiz":
            return "deep"
        default: // taze, huzur, özgür
            return "calm"
        }
    }

    /// Hex → metin rengi koyu mu?
    static func isDark(forHex hex: String) -> Bool {
        let light: Set<String> = ["F5C842", "7CC874", "E8E6E0", "FFF0B3", "B8F0D4", "F0EDE8"]
        return !light.contains(hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted).uppercased())
    }
}
