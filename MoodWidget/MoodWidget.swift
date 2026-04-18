//
//  MoodWidget.swift
//  MoodWidget
//
//  iOS 16 Lock Screen widget — bugünkü mood rengi + şarkı adı.
//  App Group (group.com.batudemir.ones) üzerinden ana uygulamadan veri okur.
//

import WidgetKit
import SwiftUI

// MARK: - App Group

private let appGroupID = "group.com.batudemir.ones"

// MARK: - Timeline Entry

struct MoodEntry: TimelineEntry {
    let date: Date
    let songName: String
    let artistName: String
    let moodLabel: String
    let moodColorHex: String
    let note: String
    let entryCount: Int
    let isPremium: Bool
    var isYesterday: Bool = false   // true when showing previous day's entry as fallback

    static let empty = MoodEntry(
        date: Date(),
        songName: "",
        artistName: "",
        moodLabel: "",
        moodColorHex: "#5B8DEF",
        note: "",
        entryCount: 0,
        isPremium: false
    )
}

// MARK: - Timeline Provider

struct MoodWidgetProvider: TimelineProvider {

    private var shared: UserDefaults? { UserDefaults(suiteName: appGroupID) }

    func placeholder(in context: Context) -> MoodEntry {
        MoodEntry(date: Date(), songName: "Sycamore", artistName: "The National",
                  moodLabel: "Nostaljik", moodColorHex: "#8B6FA8",
                  note: "", entryCount: 1, isPremium: true)
    }

    func getSnapshot(in context: Context, completion: @escaping (MoodEntry) -> Void) {
        completion(readEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<MoodEntry>) -> Void) {
        let entry = readEntry()
        // Bir sonraki gece yarısı 00:01'de yenile — günlük sıfırlama ile senkron
        var comps = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        comps.day! += 1
        comps.hour = 0; comps.minute = 1
        let nextMidnight = Calendar.current.date(from: comps) ?? Date().addingTimeInterval(86_400)
        completion(Timeline(entries: [entry], policy: .after(nextMidnight)))
    }

    private func readEntry() -> MoodEntry {
        let d = shared
        let todaySong = d?.string(forKey: "widget_songName") ?? ""

        // Today's entry exists — return it normally
        if !todaySong.isEmpty {
            return MoodEntry(
                date:         (d?.object(forKey: "widget_savedAt") as? Date) ?? Date(),
                songName:     todaySong,
                artistName:   d?.string(forKey: "widget_artistName")   ?? "",
                moodLabel:    d?.string(forKey: "widget_moodLabel")    ?? "",
                moodColorHex: d?.string(forKey: "widget_moodColorHex") ?? "#5B8DEF",
                note:         d?.string(forKey: "widget_note")         ?? "",
                entryCount:   d?.integer(forKey: "widget_entryCount")  ?? 0,
                isPremium:    d?.bool(forKey: "widget_isPremium")      ?? false,
                isYesterday:  false
            )
        }

        // Fall back to yesterday's archived entry
        let prevSong = d?.string(forKey: "widget_prev_songName") ?? ""
        if !prevSong.isEmpty {
            return MoodEntry(
                date:         (d?.object(forKey: "widget_prev_savedAt") as? Date) ?? Date(),
                songName:     prevSong,
                artistName:   d?.string(forKey: "widget_prev_artistName")   ?? "",
                moodLabel:    d?.string(forKey: "widget_prev_moodLabel")    ?? "",
                moodColorHex: d?.string(forKey: "widget_prev_moodColorHex") ?? "#5B8DEF",
                note:         "",
                entryCount:   0,
                isPremium:    d?.bool(forKey: "widget_isPremium") ?? false,
                isYesterday:  true
            )
        }

        // Nothing logged at all — return empty
        return .empty
    }
}

// MARK: - Views

/// AccessoryRectangular — kilit ekranındaki geniş bant (iOS 16+)
struct RectangularView: View {
    let entry: MoodEntry

    var body: some View {
        if entry.songName.isEmpty {
            Label("Bugün bir şarkı seç", systemImage: "music.note")
                .font(.caption2)
                .widgetAccentable()
        } else {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 5) {
                    Circle()
                        .fill(Color(hex: entry.moodColorHex))
                        .frame(width: 7, height: 7)
                    Text(entry.moodLabel)
                        .font(.caption2.weight(.semibold))
                        .widgetAccentable()
                }
                Text(entry.songName)
                    .font(.caption.weight(.medium))
                    .lineLimit(1)
                Text(entry.artistName)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
    }
}

/// AccessoryCircular — kilit ekranındaki küçük daire (iOS 16+)
struct CircularView: View {
    let entry: MoodEntry

    var body: some View {
        ZStack {
            if entry.songName.isEmpty {
                Image(systemName: "music.note")
                    .font(.title3)
                    .widgetAccentable()
            } else {
                Circle().fill(Color(hex: entry.moodColorHex).opacity(0.2))
                Circle().strokeBorder(Color(hex: entry.moodColorHex), lineWidth: 2)
                Image(systemName: "music.note")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(Color(hex: entry.moodColorHex))
                    .widgetAccentable()
            }
        }
    }
}

// MARK: - Widget

struct MoodWidget: Widget {
    let kind = "MoodWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: MoodWidgetProvider()) { entry in
            MoodWidgetView(entry: entry)
        }
        .configurationDisplayName("ONE — Günlük Mood")
        .description("Bugünkü ruh halin ve şarkın. Ana ekranda tam renk.")
        .supportedFamilies([
            .accessoryRectangular, .accessoryCircular,
            .systemSmall, .systemMedium
        ])
    }
}

struct MoodWidgetView: View {
    @Environment(\.widgetFamily) var family
    let entry: MoodEntry

    var body: some View {
        switch family {
        case .accessoryCircular:
            CircularView(entry: entry)
        case .systemSmall:
            SystemSmallView(entry: entry)
        case .systemMedium:
            SystemMediumView(entry: entry)
        default:
            RectangularView(entry: entry)
        }
    }
}

// MARK: - System Small

struct SystemSmallView: View {
    let entry: MoodEntry

    var body: some View {
        if !entry.songName.isEmpty {
            // Gradient background — mood label + footer
            ZStack(alignment: .bottomLeading) {
                LinearGradient(
                    colors: [
                        Color(hex: entry.moodColorHex),
                        Color(hex: entry.moodColorHex).opacity(0.68)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                VStack(alignment: .leading, spacing: 2) {
                    Spacer()

                    Text(entry.songName)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(2)

                    Text(entry.artistName)
                        .font(.system(size: 10))
                        .foregroundStyle(.white.opacity(0.65))
                        .lineLimit(1)
                        .padding(.bottom, 5)

                    // Footer: mood label
                    Text(entry.isYesterday ? "DÜN" : entry.moodLabel.uppercased())
                        .font(.system(size: 7, weight: .bold))
                        .tracking(0.8)
                        .foregroundStyle(.white.opacity(0.55))
                }
                .padding(11)
            }
        } else {
            // Empty state — no song logged today or yesterday
            ZStack {
                Color(hex: "#F7F6F3")
                VStack(spacing: 6) {
                    Image(systemName: "music.note.list")
                        .font(.title2)
                        .foregroundStyle(Color(hex: "#5B8DEF").opacity(0.7))
                    Text("Bugün şarkını\nseç")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
        }
    }
}

// MARK: - System Medium

struct SystemMediumView: View {
    let entry: MoodEntry

    var body: some View {
        if !entry.songName.isEmpty {
            HStack(spacing: 0) {
                // Left: Mood color panel
                ZStack {
                    Color(hex: entry.moodColorHex)

                    VStack(spacing: 6) {
                        Image(systemName: "music.note")
                            .font(.title2.weight(.semibold))
                            .foregroundStyle(.white)

                        Text(entry.moodLabel)
                            .font(.system(size: 10, weight: .bold))
                            .tracking(0.5)
                            .foregroundStyle(.white.opacity(0.8))
                    }
                }
                .frame(width: 90)

                // Right: Song info + note
                VStack(alignment: .leading, spacing: 4) {
                    Text(entry.songName)
                        .font(.system(size: 15, weight: .semibold))
                        .lineLimit(1)

                    Text(entry.artistName)
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)

                    // Not varsa göster, yoksa mood label fallback
                    Text(entry.note.isEmpty ? entry.moodLabel : entry.note)
                        .font(.system(size: 10, weight: .regular))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .padding(.top, 2)

                    Spacer()
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        } else {
            // Empty state
            HStack(spacing: 12) {
                Image(systemName: "music.note")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                Text("Bugün bir şarkı seç")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

// MARK: - Color(hex:) — widget target'ın ana app'e erişimi yok

private extension Color {
    init(hex: String) {
        let h = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var v: UInt64 = 0
        Scanner(string: h).scanHexInt64(&v)
        let r = Double((v >> 16) & 0xFF) / 255
        let g = Double((v >>  8) & 0xFF) / 255
        let b = Double( v        & 0xFF) / 255
        self.init(.sRGB, red: r, green: g, blue: b)
    }
}

// MARK: - Preview

#Preview(as: .accessoryRectangular) {
    MoodWidget()
} timeline: {
    MoodEntry(date: .now, songName: "Sycamore", artistName: "The National",
              moodLabel: "Nostaljik", moodColorHex: "#8B6FA8",
              note: "", entryCount: 1, isPremium: true)
    MoodEntry.empty
}
