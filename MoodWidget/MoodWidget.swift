//
//  MoodWidget.swift
//  MoodWidget
//
//  Unified ONE widget — mood + friends in a single cohesive experience.
//  Small  = sen + arkadaş ipucu
//  Medium = sen + arkadaş özeti
//  Large  = sen + tam çevre listesi
//  Lock Screen = Circular / Rectangular / Inline
//

import WidgetKit
import SwiftUI

// MARK: - App Group

let appGroupID = "group.com.batudemir.ones"

// MARK: - Deep Link

private let widgetDeepLink = URL(string: "ones://today")!

// MARK: - Design Tokens

enum WToken {
    static let cream       = Color(hex: "#F8F7F4")
    static let ink         = Color(hex: "#1C1C1E")
    static let ash         = Color(hex: "#8E8E93")
    static let stone       = Color(hex: "#AEAEB2")
    static let ember       = Color(hex: "#E07A5F")
    static let accent      = Color(hex: "#5B8DEF")
    static let cornerMd: CGFloat = 12
}

// MARK: - Data Models

struct FriendShareItem: Codable, Identifiable {
    let name: String
    let songName: String
    let artistName: String
    let moodColorHex: String
    let moodWord: String

    var id: String { name }
    var hasShared: Bool { !songName.isEmpty }
}

struct MoodEntry: TimelineEntry {
    let date: Date
    let songName: String
    let artistName: String
    let moodLabel: String
    let moodColorHex: String
    let note: String
    let entryCount: Int
    var isYesterday: Bool = false
    let friends: [FriendShareItem]

    var sharedFriends: [FriendShareItem] { friends.filter(\.hasShared) }
    var waitingFriends: [FriendShareItem] { friends.filter { !$0.hasShared } }

    static let empty = MoodEntry(
        date: Date(), songName: "", artistName: "", moodLabel: "",
        moodColorHex: "#5B8DEF", note: "", entryCount: 0,
        friends: []
    )
}

// MARK: - Timeline Provider

struct MoodWidgetProvider: TimelineProvider {

    private var shared: UserDefaults? { UserDefaults(suiteName: appGroupID) }

    func placeholder(in context: Context) -> MoodEntry {
        MoodEntry(
            date: Date(), songName: "Sycamore", artistName: "The National",
            moodLabel: "Nostaljik", moodColorHex: "#8B6FA8",
            note: "bugün biraz böyle hissettim", entryCount: 1,
            friends: [
                FriendShareItem(name: "Elif", songName: "Sycamore", artistName: "The National", moodColorHex: "#8B6FA8", moodWord: "Nostaljik"),
                FriendShareItem(name: "Can", songName: "Redbone", artistName: "Childish Gambino", moodColorHex: "#E07A5F", moodWord: "Enerjik"),
                FriendShareItem(name: "Deniz", songName: "", artistName: "", moodColorHex: "#5B8DEF", moodWord: "")
            ]
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (MoodEntry) -> Void) {
        completion(context.isPreview ? placeholder(in: context) : readEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<MoodEntry>) -> Void) {
        let now = Date()
        let calendar = Calendar.current
        let current = readEntry()

        // policy: .after(date) WidgetKit'e "bu tarihte getTimeline'ı tekrar çağır"
        // der ve o çağrıda UserDefaults'tan taze veri okunur.
        // reloadAllTimelines() ise entry kaydedildiğinde anında tetiklenir.
        // Gün içi checkpoint'ler: 08:00, 13:00, 19:00 → gece yarısına kadar biriktirip
        // bir sonraki checkpoint'e policy ayarlanır.
        let checkHours = [8, 13, 19]
        let nextCheckpoint: Date = checkHours
            .compactMap { hour -> Date? in
                var comps = calendar.dateComponents([.year, .month, .day], from: now)
                comps.hour = hour; comps.minute = 0; comps.second = 0
                return calendar.date(from: comps)
            }
            .first(where: { $0 > now })
            ?? {
                var comps = calendar.dateComponents([.year, .month, .day], from: now)
                comps.day! += 1; comps.hour = 0; comps.minute = 1
                return calendar.date(from: comps) ?? now.addingTimeInterval(86_400)
            }()

        completion(Timeline(entries: [current], policy: .after(nextCheckpoint)))
    }

    private func readEntry() -> MoodEntry {
        let d = shared
        let todaySong = d?.string(forKey: "widget_songName") ?? ""
        let friends = decodeFriends(from: d)

        if !todaySong.isEmpty {
            return MoodEntry(
                date:         (d?.object(forKey: "widget_savedAt") as? Date) ?? Date(),
                songName:     todaySong,
                artistName:   d?.string(forKey: "widget_artistName")   ?? "",
                moodLabel:    d?.string(forKey: "widget_moodLabel")    ?? "",
                moodColorHex: d?.string(forKey: "widget_moodColorHex") ?? "#5B8DEF",
                note:         d?.string(forKey: "widget_note")         ?? "",
                entryCount:   d?.integer(forKey: "widget_entryCount")  ?? 0,
                isYesterday:  false,
                friends:      friends
            )
        }

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
                isYesterday:  true,
                friends:      friends
            )
        }

        return MoodEntry(
            date: Date(), songName: "", artistName: "", moodLabel: "",
            moodColorHex: "#5B8DEF", note: "", entryCount: 0, friends: friends
        )
    }

    private func decodeFriends(from defaults: UserDefaults?) -> [FriendShareItem] {
        guard let data = defaults?.data(forKey: "widget_friendShares") else { return [] }
        return (try? JSONDecoder().decode([FriendShareItem].self, from: data)) ?? []
    }
}

// MARK: - Shared Components

struct MoodBubble: View {
    let colorHex: String
    let initial: String
    let size: CGFloat
    let isGhost: Bool

    init(colorHex: String, initial: String, size: CGFloat = 28, isGhost: Bool = false) {
        self.colorHex = colorHex; self.initial = initial; self.size = size; self.isGhost = isGhost
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(isGhost ? Color(hex: colorHex).opacity(0.12) : Color(hex: colorHex))
            if !isGhost {
                Circle()
                    .fill(RadialGradient(
                        colors: [Color.white.opacity(0.18), .clear],
                        center: .topLeading, startRadius: 0, endRadius: size * 0.5
                    ))
            }
            Circle()
                .strokeBorder(
                    isGhost ? Color(hex: colorHex).opacity(0.2) : Color.white.opacity(0.15),
                    lineWidth: isGhost ? 1 : 0.5
                )
            Text(initial)
                .font(.system(size: size * 0.42, weight: .bold, design: .rounded))
                .foregroundStyle(isGhost ? Color(hex: colorHex).opacity(0.4) : .white)
        }
        .frame(width: size, height: size)
    }
}


// MARK: - Lock Screen: Inline

struct InlineView: View {
    let entry: MoodEntry

    var body: some View {
        if entry.songName.isEmpty {
            Label("Bugün ne hissediyorsun?", systemImage: "music.note")
                .widgetAccentable()
        } else {
            Label("\(entry.songName)  ·  \(entry.moodLabel)", systemImage: "music.note")
                .widgetAccentable()
        }
    }
}

// MARK: - Lock Screen: Rectangular

struct RectangularView: View {
    let entry: MoodEntry

    var body: some View {
        if entry.songName.isEmpty {
            HStack(spacing: 4) {
                Image(systemName: "music.note").font(.caption2)
                Text("Bugün şarkını seç").font(.caption2.weight(.medium))
            }
            .widgetAccentable()
        } else {
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 4) {
                    Circle().fill(Color(hex: entry.moodColorHex)).frame(width: 6, height: 6)
                    Text(entry.isYesterday ? "Dün · \(entry.moodLabel)" : entry.moodLabel)
                        .font(.caption2.weight(.semibold)).widgetAccentable()
                }
                Text(entry.songName).font(.caption.weight(.medium)).lineLimit(1)
                Text(entry.artistName).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
            }
        }
    }
}

// MARK: - Lock Screen: Circular

struct CircularView: View {
    let entry: MoodEntry

    var body: some View {
        ZStack {
            if entry.songName.isEmpty {
                Circle().strokeBorder(WToken.accent.opacity(0.3), lineWidth: 2)
                Image(systemName: "music.note")
                    .font(.caption).foregroundStyle(WToken.accent.opacity(0.6)).widgetAccentable()
            } else {
                Circle().fill(Color(hex: entry.moodColorHex).opacity(0.15))
                Circle().strokeBorder(Color(hex: entry.moodColorHex), lineWidth: 2.5)
                Image(systemName: "music.note")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(Color(hex: entry.moodColorHex)).widgetAccentable()
            }
        }
    }
}

// MARK: - Widget Configuration

struct MoodWidget: Widget {
    let kind = "MoodWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: MoodWidgetProvider()) { entry in
            MoodWidgetView(entry: entry)
        }
        .configurationDisplayName("ONE")
        .description("Bugünkü ruh halin, şarkın ve arkadaşlarının paylaşımları.")
        .supportedFamilies([
            .accessoryInline, .accessoryRectangular, .accessoryCircular,
            .systemSmall, .systemMedium, .systemLarge
        ])
    }
}

// MARK: - View Router

struct MoodWidgetView: View {
    @Environment(\.widgetFamily) var family
    let entry: MoodEntry

    var body: some View {
        switch family {
        case .accessoryInline:
            InlineView(entry: entry)
                .containerBackground(.clear, for: .widget)
        case .accessoryCircular:
            CircularView(entry: entry)
                .containerBackground(.clear, for: .widget)
        case .accessoryRectangular:
            RectangularView(entry: entry)
                .containerBackground(.clear, for: .widget)
        case .systemSmall:
            SmallView(entry: entry)
                .widgetURL(widgetDeepLink)
                .containerBackground(for: .widget) {
                    if !entry.songName.isEmpty {
                        LinearGradient(
                            stops: [
                                .init(color: Color(hex: entry.moodColorHex), location: 0.0),
                                .init(color: Color(hex: entry.moodColorHex).opacity(0.82), location: 0.55),
                                .init(color: Color(hex: entry.moodColorHex).opacity(0.55), location: 1.0)
                            ],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        )
                    } else { WToken.cream }
                }
        case .systemMedium:
            MediumView(entry: entry)
                .widgetURL(widgetDeepLink)
                .containerBackground(for: .widget) { WToken.cream }
        case .systemLarge:
            LargeView(entry: entry)
                .widgetURL(widgetDeepLink)
                .containerBackground(for: .widget) { WToken.cream }
        default:
            RectangularView(entry: entry)
                .containerBackground(.clear, for: .widget)
        }
    }
}

// MARK: - Small — Just You

struct SmallView: View {
    let entry: MoodEntry

    var body: some View {
        if !entry.songName.isEmpty {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Spacer()
                    if !entry.sharedFriends.isEmpty {
                        friendHintBadge
                    }
                }
                Spacer()
                VStack(alignment: .leading, spacing: 1) {
                    Text(entry.songName)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.white).lineLimit(2)
                        .shadow(color: .black.opacity(0.15), radius: 2, y: 1)
                    Text(entry.artistName)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.white.opacity(0.7)).lineLimit(1)
                }
                HStack(spacing: 4) {
                    Circle().fill(.white.opacity(0.35)).frame(width: 5, height: 5)
                    Text(entry.isYesterday ? "DÜN" : entry.moodLabel.uppercased())
                        .font(.system(size: 7, weight: .heavy)).tracking(1.0)
                        .foregroundStyle(.white.opacity(0.6))
                }
                .padding(.top, 4)
            }
            .padding(12)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
        } else {
            VStack(spacing: 8) {
                ZStack {
                    Circle().strokeBorder(WToken.accent.opacity(0.2), lineWidth: 1.5).frame(width: 40, height: 40)
                    Image(systemName: "music.note")
                        .font(.system(size: 16, weight: .light)).foregroundStyle(WToken.accent.opacity(0.5))
                }
                VStack(spacing: 2) {
                    Text("Bugün ne hissediyorsun?")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(WToken.ink.opacity(0.5))
                        .multilineTextAlignment(.center)
                    Text("Şarkını seç, ruh halini yansıt")
                        .font(.system(size: 8, weight: .medium))
                        .foregroundStyle(WToken.stone)
                        .multilineTextAlignment(.center)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var friendHintBadge: some View {
        HStack(spacing: 3) {
            ForEach(entry.sharedFriends.prefix(2)) { f in
                Circle()
                    .fill(Color(hex: f.moodColorHex))
                    .frame(width: 6, height: 6)
            }
            if entry.sharedFriends.count > 1 {
                Text("+\(entry.sharedFriends.count - 1)")
                    .font(.system(size: 6, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.7))
            }
        }
        .padding(.horizontal, 5)
        .padding(.vertical, 3)
        .background(Capsule().fill(.white.opacity(0.2)))
    }
}

// MARK: - Medium — You + Friends Preview

struct MediumView: View {
    let entry: MoodEntry

    var body: some View {
        if entry.songName.isEmpty {
            emptyState
        } else {
            filledState
        }
    }

    private var emptyState: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(WToken.accent.opacity(0.08))
                    .frame(width: 52, height: 52)
                Circle()
                    .strokeBorder(WToken.accent.opacity(0.2), lineWidth: 1.5)
                    .frame(width: 52, height: 52)
                Image(systemName: "music.note")
                    .font(.system(size: 22, weight: .light))
                    .foregroundStyle(WToken.accent.opacity(0.5))
            }
            VStack(alignment: .leading, spacing: 4) {
                Text("Bugün ne hissediyorsun?")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(WToken.ink.opacity(0.6))
                Text("Şarkını seç, ruh halini çevrenle paylaş.")
                    .font(.system(size: 11, weight: .regular))
                    .foregroundStyle(WToken.stone)
                    .lineLimit(2)
                if !entry.sharedFriends.isEmpty {
                    HStack(spacing: 4) {
                        ForEach(entry.sharedFriends.prefix(3)) { f in
                            MoodBubble(colorHex: f.moodColorHex,
                                       initial: String(f.name.prefix(1)).uppercased(),
                                       size: 18)
                        }
                        Text("paylaştı")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(WToken.stone)
                    }
                }
            }
            Spacer()
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var filledState: some View {
        HStack(spacing: 0) {
            // Left: Mood color panel
            ZStack {
                Color(hex: entry.moodColorHex)
                RadialGradient(
                    colors: [Color.white.opacity(0.12), .clear],
                    center: .topTrailing, startRadius: 0, endRadius: 80
                )
                VStack(spacing: 6) {
                    Image(systemName: "music.note")
                        .font(.system(size: 22, weight: .semibold)).foregroundStyle(.white)
                    if !entry.moodLabel.isEmpty {
                        Text(entry.moodLabel)
                            .font(.system(size: 9, weight: .heavy)).tracking(0.8)
                            .foregroundStyle(.white.opacity(0.8))
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                    }
                    if entry.isYesterday {
                        Text("DÜN")
                            .font(.system(size: 7, weight: .heavy)).tracking(1)
                            .foregroundStyle(.white.opacity(0.5))
                    }
                }
                .padding(.horizontal, 6)
            }
            .frame(width: 92)
            .clipShape(RoundedRectangle(cornerRadius: WToken.cornerMd, style: .continuous))

            // Right: Song + friends
            VStack(alignment: .leading, spacing: 0) {
                Text(entry.songName)
                    .font(.system(size: 15, weight: .bold)).foregroundStyle(WToken.ink).lineLimit(1)
                Text(entry.artistName)
                    .font(.system(size: 11, weight: .medium)).foregroundStyle(WToken.ash).lineLimit(1)
                    .padding(.top, 1)
                if !entry.note.isEmpty {
                    Text(entry.note)
                        .font(.system(size: 10)).italic()
                        .foregroundStyle(WToken.stone)
                        .lineLimit(1).padding(.top, 3)
                }

                Spacer()

                // Friends orbit row
                if !entry.friends.isEmpty {
                    HStack(spacing: 5) {
                        MoodBubble(colorHex: entry.moodColorHex, initial: "S", size: 22)
                        ForEach(entry.friends.prefix(4)) { friend in
                            MoodBubble(
                                colorHex: friend.moodColorHex,
                                initial: String(friend.name.prefix(1)).uppercased(),
                                size: 22, isGhost: !friend.hasShared
                            )
                        }
                        Spacer()
                    }
                } else {
                    HStack {
                        Spacer()
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

// MARK: - Large — You + Full Circle

struct LargeView: View {
    let entry: MoodEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack(spacing: 0) {
                Text("ONE")
                    .font(.system(size: 12, weight: .heavy))
                    .tracking(1.6)
                    .foregroundStyle(WToken.accent)
                Spacer()
                if !entry.friends.isEmpty {
                    Text("\(entry.sharedFriends.count)/\(entry.friends.count)")
                        .font(.system(size: 9, weight: .medium, design: .rounded))
                        .foregroundStyle(WToken.stone).padding(.leading, 6)
                }
            }

            Rectangle().fill(WToken.ink.opacity(0.06)).frame(height: 0.5)
                .padding(.vertical, 6)

            // Your mood section
            if !entry.songName.isEmpty {
                HStack(spacing: 10) {
                    MoodBubble(colorHex: entry.moodColorHex, initial: "S", size: 36)
                    VStack(alignment: .leading, spacing: 1) {
                        HStack(spacing: 5) {
                            Text("Sen")
                                .font(.system(size: 12, weight: .bold)).foregroundStyle(WToken.ink)
                            if !entry.moodLabel.isEmpty {
                                Text(entry.moodLabel)
                                    .font(.system(size: 7, weight: .heavy)).tracking(0.4)
                                    .foregroundStyle(Color(hex: entry.moodColorHex))
                                    .padding(.horizontal, 5).padding(.vertical, 2)
                                    .background(Capsule().fill(Color(hex: entry.moodColorHex).opacity(0.1)))
                            }
                            if entry.isYesterday {
                                Text("DÜN")
                                    .font(.system(size: 7, weight: .heavy)).tracking(0.4)
                                    .foregroundStyle(WToken.stone)
                                    .padding(.horizontal, 4).padding(.vertical, 2)
                                    .background(Capsule().fill(WToken.stone.opacity(0.1)))
                            }
                        }
                        Text(entry.songName)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(WToken.ink.opacity(0.7)).lineLimit(1)
                        Text(entry.artistName)
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(WToken.stone).lineLimit(1)
                        if !entry.note.isEmpty {
                            Text("\"\(entry.note)\"")
                                .font(.system(size: 9)).italic()
                                .foregroundStyle(WToken.stone.opacity(0.8))
                                .lineLimit(1)
                                .padding(.top, 1)
                        }
                    }
                    Spacer()
                }
                .padding(.bottom, 6)

                Rectangle().fill(WToken.ink.opacity(0.04)).frame(height: 0.5)
                    .padding(.leading, 46)
            }

            // Friends list
            if !entry.sharedFriends.isEmpty {
                let capped = Array(entry.sharedFriends.prefix(5))
                ForEach(capped) { friend in
                    HStack(spacing: 10) {
                        MoodBubble(
                            colorHex: friend.moodColorHex,
                            initial: String(friend.name.prefix(1)).uppercased(),
                            size: 32
                        )
                        VStack(alignment: .leading, spacing: 1) {
                            HStack(spacing: 5) {
                                Text(friend.name)
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(WToken.ink).lineLimit(1)
                                if !friend.moodWord.isEmpty {
                                    Text(friend.moodWord)
                                        .font(.system(size: 7, weight: .heavy)).tracking(0.3)
                                        .foregroundStyle(Color(hex: friend.moodColorHex))
                                        .padding(.horizontal, 4).padding(.vertical, 2)
                                        .background(Capsule().fill(Color(hex: friend.moodColorHex).opacity(0.1)))
                                }
                            }
                            Text(friend.songName)
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(WToken.ink.opacity(0.7)).lineLimit(1)
                            Text(friend.artistName)
                                .font(.system(size: 8, weight: .medium))
                                .foregroundStyle(WToken.stone).lineLimit(1)
                        }
                        Spacer()
                        Circle()
                            .fill(Color(hex: friend.moodColorHex).opacity(0.25))
                            .frame(width: 5, height: 5)
                    }
                    .padding(.vertical, 5)

                    if friend.id != capped.last?.id {
                        Rectangle().fill(WToken.ink.opacity(0.04)).frame(height: 0.5)
                            .padding(.leading, 42)
                    }
                }
            }

            // Waiting friends — ghost row
            if !entry.waitingFriends.isEmpty {
                if !entry.sharedFriends.isEmpty {
                    Rectangle().fill(WToken.ink.opacity(0.04)).frame(height: 0.5)
                        .padding(.top, 3)
                }
                HStack(spacing: 5) {
                    Text("bekleniyor")
                        .font(.system(size: 8, weight: .medium)).tracking(0.3)
                        .foregroundStyle(WToken.stone)
                    ForEach(entry.waitingFriends.prefix(5)) { friend in
                        MoodBubble(
                            colorHex: friend.moodColorHex,
                            initial: String(friend.name.prefix(1)).uppercased(),
                            size: 18, isGhost: true
                        )
                    }
                    if entry.waitingFriends.count > 5 {
                        Text("+\(entry.waitingFriends.count - 5)")
                            .font(.system(size: 8, weight: .medium, design: .rounded))
                            .foregroundStyle(WToken.stone)
                    }
                    Spacer()
                }
                .padding(.top, 5)
            }

            // Full empty state
            if entry.friends.isEmpty && entry.songName.isEmpty {
                Spacer()
                VStack(spacing: 6) {
                    Image(systemName: "music.note")
                        .font(.system(size: 20, weight: .light))
                        .foregroundStyle(WToken.accent.opacity(0.4))
                    Text("Bugün ne hissediyorsun?")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(WToken.ink.opacity(0.4))
                    Text("Şarkını seç, ruh halini yansıt.")
                        .font(.system(size: 10))
                        .foregroundStyle(WToken.stone)
                }
                .frame(maxWidth: .infinity)
                Spacer()
            } else {
                Spacer()
            }
        }
        .padding(14)
    }
}

// MARK: - Color(hex:)

extension Color {
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

#Preview(as: .systemLarge) {
    MoodWidget()
} timeline: {
    MoodEntry(
        date: .now, songName: "Sycamore", artistName: "The National",
        moodLabel: "Nostaljik", moodColorHex: "#8B6FA8",
        note: "bugün biraz böyle hissettim", entryCount: 1,
        friends: [
            FriendShareItem(name: "Elif", songName: "Sycamore", artistName: "The National", moodColorHex: "#8B6FA8", moodWord: "Nostaljik"),
            FriendShareItem(name: "Can", songName: "Redbone", artistName: "Childish Gambino", moodColorHex: "#E07A5F", moodWord: "Enerjik"),
            FriendShareItem(name: "Deniz", songName: "", artistName: "", moodColorHex: "#5B8DEF", moodWord: "")
        ]
    )
    MoodEntry.empty
}
