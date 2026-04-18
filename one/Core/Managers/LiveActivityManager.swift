//
//  LiveActivityManager.swift
//  one
//

import Foundation
import ActivityKit

// DailySongActivityAttributes ve FriendShareActivityAttributes
// ActivityAttributes.swift dosyasında tanımlı — hem bu target hem extension paylaşır.

@available(iOS 16.1, *)
final class LiveActivityManager {
    static let shared = LiveActivityManager()
    private init() {}

    // MARK: - Daily Song
    // Kutlama arc'ı: 0–5sn kutlama → 5–30sn normal → 30sn kapanış

    func startDailySong(
        songName: String,
        artistName: String,
        moodLabel: String,
        moodColorHex: String,
        moodIsDark: Bool,
        moodSFSymbol: String,
        streakCount: Int
    ) async {
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
            staleDate: Date().addingTimeInterval(300) // 5 dakika
        )

        do {
            let activity = try Activity<DailySongActivityAttributes>.request(
                attributes: attributes,
                content: content,
                pushType: nil
            )
            ONELogger.success("DailySong Live Activity başlatıldı: \(activity.id)", category: .general)

            Task {
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
                await activity.update(ActivityContent(state: normalState, staleDate: nil))

                // 4dk 55sn daha bekle (toplam 5dk) ve kapat
                try? await Task.sleep(nanoseconds: 295_000_000_000)
                await activity.end(
                    ActivityContent(state: normalState, staleDate: nil),
                    dismissalPolicy: .immediate
                )
                ONELogger.debug("DailySong Live Activity kapandı.", category: .general)
            }
        } catch {
            ONELogger.warning("DailySong Live Activity başlatılamadı: \(error.localizedDescription)", category: .general)
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
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        for activity in Activity<FriendShareActivityAttributes>.activities {
            await activity.end(
                ActivityContent(state: activity.content.state, staleDate: nil),
                dismissalPolicy: .immediate
            )
        }

        let state = FriendShareActivityAttributes.ContentState(
            friendName: friendName,
            songName: songName,
            artistName: artistName,
            moodLabel: moodLabel,
            moodColorHex: moodColorHex,
            moodSFSymbol: moodSFSymbol
        )
        let content = ActivityContent(state: state, staleDate: Date().addingTimeInterval(120))

        do {
            let activity = try Activity<FriendShareActivityAttributes>.request(
                attributes: FriendShareActivityAttributes(receivedAt: Date()),
                content: content,
                pushType: nil
            )
            ONELogger.success("FriendShare Live Activity başlatıldı: \(activity.id)", category: .general)

            Task {
                try? await Task.sleep(nanoseconds: 120_000_000_000)
                await activity.end(
                    ActivityContent(state: state, staleDate: nil),
                    dismissalPolicy: .immediate
                )
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
